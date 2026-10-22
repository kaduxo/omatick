import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

Item {
  id: root

  property var shell: null
  property var manifest: null
  property string omarchyPath: ""

  property var quotes: ({})
  property int replaceIndex: -1
  property string statusText: ""
  property bool refreshing: false
  property var storedTokens: Model.defaultTokens()
  property string storedTemplate: "symbol-price-change"
  property Item panelAnchor: defaultAnchor
  property var clickTargets: []
  property real lastLeftClickAt: 0
  property bool writingSettings: false
  property bool localTransparent: true

  Item {
    id: defaultAnchor
    width: 1
    height: 1
    visible: false
  }

  readonly property string pluginId: (manifest && manifest.id) ? String(manifest.id) : Model.PLUGIN_ID
  readonly property string home: Quickshell.env("HOME")
  readonly property string settingsPath: home + "/.config/omarchy/" + pluginId + ".json"
  readonly property var tokens: Model.normalizeTokens(storedTokens)
  readonly property string template: Model.normalizeTemplate(storedTemplate)
  readonly property bool barTransparent: shell && shell.barConfig ? !!shell.barConfig.transparent : true
  readonly property int stripSize: Style.bar.sizeHorizontal
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  onBarTransparentChanged: localTransparent = barTransparent
  Component.onCompleted: localTransparent = barTransparent

  QtObject {
    id: barFacade
    property color foreground: Commons.Color.bar.text
    property color barForeground: Commons.Color.bar.text
    property color background: Commons.Color.bar.background
    property color urgent: Commons.Color.bar.active
    property string fontFamily: Style.font.family
    property string position: "bottom"
    property bool vertical: false
    property int barSize: root.stripSize
    property bool transparent: root.localTransparent
    property bool foregroundAnimationEnabled: true
    property var activePopout: null
    property var clickTargets: root.clickTargets

    function showTooltip(target, text) {}
    function hideTooltip(target) {}
    function registerClickTarget(target) {
      if (!target) return
      var next = root.clickTargets.slice()
      if (next.indexOf(target) !== -1) return
      next.push(target)
      root.clickTargets = next
    }
    function unregisterClickTarget(target) {
      var next = []
      for (var i = 0; i < root.clickTargets.length; i++) {
        if (root.clickTargets[i] !== target) next.push(root.clickTargets[i])
      }
      root.clickTargets = next
    }
    function requestPopout(owner) { activePopout = owner }
    function releasePopout(owner) { if (activePopout === owner) activePopout = null }
    function switchPanelFrom(owner, direction) { return false }
    function targetBelongsToWindow(target, window) { return true }
    function run(command) {}
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = barFacade
    if ("anchorItem" in target) target.anchorItem = root.panelAnchor
    if ("hostWidget" in target) target.hostWidget = root
  }

  function persist(values) {
    if (values && values.tokens) storedTokens = Model.normalizeTokens(values.tokens)
    if (values && values.template) storedTemplate = Model.normalizeTemplate(values.template)
    var payload = { tokens: storedTokens, template: storedTemplate }
    writingSettings = true
    settingsFile.setText(JSON.stringify(payload, null, 2) + "\n")
    if (root.shell && typeof root.shell.updateEntryInline === "function")
      root.shell.updateEntryInline(root.pluginId, { id: root.pluginId, tokens: storedTokens, template: storedTemplate })
  }

  function setTokens(next) {
    persist({ tokens: Model.normalizeTokens(next) })
    Qt.callLater(root.refresh)
  }

  function selectToken(token) {
    setTokens(Model.applySelection(root.tokens, token, root.replaceIndex))
    root.replaceIndex = -1
  }

  function removeToken(index) {
    setTokens(Model.removeAt(root.tokens, index))
    root.replaceIndex = -1
  }

  function cycleTemplate() {
    persist({ template: Model.nextTemplate(root.template) })
  }

  function setTemplate(value) {
    persist({ template: Model.normalizeTemplate(value) })
  }

  function refresh() {
    var command = Model.priceCommand(root.tokens)
    if (command.length === 0) return
    if (priceProc.running) return
    root.refreshing = true
    root.statusText = "Refreshing…"
    priceProc.command = command
    priceProc.running = true
  }

  function closePanel() {
    pendingClick.stop()
    if (panelLoader.item && panelLoader.item.close) panelLoader.item.close()
  }

  function openFrom(anchor, index) {
    root.panelAnchor = anchor || defaultAnchor
    if (index !== undefined) root.replaceIndex = index
    injectPanel()
    if (panelLoader.item && panelLoader.item.openFromHotkey) panelLoader.item.openFromHotkey()
  }

  function activateFrom(anchor, index) {
    if (root.opened) {
      if (index >= 0 && index !== root.replaceIndex) {
        openFrom(anchor, index)
        return
      }
      closePanel()
      return
    }
    openFrom(anchor, index)
  }

  function handleLeftClick(anchor, index) {
    var now = Date.now()
    if (now - root.lastLeftClickAt < 280) {
      root.lastLeftClickAt = 0
      pendingClick.stop()
      toggleTransparency()
      return
    }
    root.lastLeftClickAt = now
    pendingClick.anchor = anchor
    pendingClick.index = index
    pendingClick.restart()
  }

  function toggleTransparency() {
    closePanel()
    var next = !root.localTransparent
    root.localTransparent = next
    Util.execArgv(["omarchy", "bar", "transparent", next ? "true" : "false"])
  }

  FileView {
    id: settingsFile
    path: root.settingsPath
    watchChanges: true
    printErrors: false
    onLoaded: {
      if (root.writingSettings) {
        root.writingSettings = false
        return
      }
      var parsed = Model.parseSettings(text())
      root.storedTokens = parsed.tokens
      root.storedTemplate = parsed.template
    }
    onLoadFailed: {
      root.storedTokens = Model.defaultTokens()
      root.storedTemplate = "symbol-price-change"
    }
  }

  Process {
    id: priceProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = Model.parsePrices(text)
        if (parsed) {
          root.quotes = parsed
          root.statusText = ""
        }
      }
    }
    onExited: function(code) {
      root.refreshing = false
      if (code !== 0) root.statusText = "Price fetch failed"
    }
  }

  Timer {
    interval: 60000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Timer {
    id: pendingClick
    interval: 280
    repeat: false
    property var anchor: null
    property int index: -1
    onTriggered: root.activateFrom(anchor, index)
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  Variants {
    model: Quickshell.screens

    delegate: Component {
      PanelWindow {
        id: strip
        required property var modelData

        screen: modelData
        visible: !remapGuard.remapping
        exclusionMode: ExclusionMode.Auto
        implicitHeight: Math.max(root.stripSize, tickerFlow.implicitHeight)
        color: root.localTransparent ? "transparent" : Commons.Color.bar.background
        surfaceFormat.opaque: false
        WlrLayershell.namespace: "kaduxo-omatick"
        WlrLayershell.layer: WlrLayer.Top

        anchors {
          bottom: true
          left: true
          right: true
        }

        ScreenMoveRemap {
          id: remapGuard
          window: strip
        }

        Component.onCompleted: {
          if (!root.panelAnchor || root.panelAnchor === defaultAnchor)
            root.panelAnchor = tickerFlow
          root.injectPanel()
        }

        MouseArea {
          anchors.fill: parent
          acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
          onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) root.cycleTemplate()
            else if (mouse.button === Qt.MiddleButton) root.refresh()
            else root.handleLeftClick(tickerFlow, -1)
          }
        }

        Flow {
          id: tickerFlow
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width
          spacing: Style.space(2)

          Repeater {
            model: root.tokens.length > 0 ? root.tokens : [{ id: "", symbol: "₿", name: "Add tickers" }]

            WidgetButton {
              required property var modelData
              required property int index
              bar: barFacade
              text: modelData.id
                ? Model.formatToken(modelData, root.quotes, root.template)
                : (root.statusText !== "" ? root.statusText : "Add tickers")
              tooltipText: root.statusText !== "" ? root.statusText : text
              labelVisible: true
              hasVisualContent: text !== ""
              horizontalMargin: 8.75
              verticalPadding: 8.75
              fontSize: Style.font.caption
              useActiveColor: false
              foreground: {
                if (!modelData.id) return Commons.Color.muted
                var change = Model.changeValue(modelData, root.quotes)
                if (isFinite(change) && change < 0) return Commons.Color.urgent
                return Commons.Color.bar.text
              }

              onPressed: function(b) {
                if (b === Qt.RightButton) root.cycleTemplate()
                else if (b === Qt.MiddleButton) root.refresh()
                else root.handleLeftClick(this, modelData.id ? index : -1)
              }
            }
          }
        }
      }
    }
  }
}
