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
  property bool settingsReady: false
  property bool localTransparent: true
  property bool userToggledTransparent: false
  property int refreshInterval: Model.REFRESH_MS
  property var paprikaQueue: []
  property real lastPaprikaAt: 0
  property string priceSource: "gecko"
  property color upColor: "#7d9a78"

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

  onBarTransparentChanged: {
    if (!userToggledTransparent) localTransparent = barTransparent
  }
  Component.onCompleted: {
    localTransparent = barTransparent
    layerRuleProc.running = true
  }

  function open(arg) {
    openFrom(root.panelAnchor, -1)
  }

  function close() {
    closePanel()
  }

  function toggle() {
    if (root.opened) closePanel()
    else openFrom(root.panelAnchor, -1)
  }

  QtObject {
    id: barFacade
    property color foreground: Commons.Color.bar.text
    property color barForeground: Commons.Color.bar.text
    property color background: Commons.Color.bar.background
    property color urgent: Commons.Color.urgent
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

  function moveToken(from, to) {
    setTokens(Model.moveToken(root.tokens, from, to))
  }

  function cycleTemplate() {
    persist({ template: Model.nextTemplate(root.template) })
  }

  function setTemplate(value) {
    persist({ template: Model.normalizeTemplate(value) })
  }

  function tokenColor(token) {
    var change = Model.changeValue(token, root.quotes)
    if (isFinite(change) && change < 0) return Commons.Color.urgent
    if (isFinite(change) && change > 0) return root.upColor
    return Commons.Color.bar.text
  }

  function refresh() {
    if (!root.settingsReady) return
    if (priceProc.running) return
    var url = Model.geckoPriceUrl(root.tokens)
    if (url === "") return
    root.priceSource = "gecko"
    root.refreshing = true
    root.statusText = "Refreshing…"
    priceProc.command = Model.curlCommand(url)
    priceProc.running = true
  }

  function refreshBinance() {
    var url = Model.binanceUrl(root.tokens)
    if (url === "") return false
    root.priceSource = "binance"
    root.refreshing = true
    root.statusText = "Refreshing…"
    priceProc.command = Model.curlCommand(url)
    priceProc.running = true
    return true
  }

  function queuePaprikaFallbacks(quotes) {
    var missing = Model.missingQuoteIds(root.tokens, quotes)
    root.paprikaQueue = missing
    drainPaprika()
  }

  function drainPaprika() {
    if (paprikaProc.running) return
    if (!root.paprikaQueue || root.paprikaQueue.length === 0) return
    var now = Date.now()
    if (root.lastPaprikaAt && now - root.lastPaprikaAt < Model.PAPRIKA_GAP_MS) return
    var id = root.paprikaQueue[0]
    var url = Model.paprikaTickerUrl(id)
    if (url === "") {
      root.paprikaQueue = root.paprikaQueue.slice(1)
      drainPaprika()
      return
    }
    root.lastPaprikaAt = now
    paprikaProc.command = Model.curlCommand(url)
    paprikaProc.running = true
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

  function handleEmptyClick(anchor) {
    var now = Date.now()
    if (now - root.lastLeftClickAt < 280) {
      root.lastLeftClickAt = 0
      pendingClick.stop()
      toggleStripTransparency()
      return
    }
    root.lastLeftClickAt = now
    pendingClick.anchor = anchor
    pendingClick.restart()
  }

  function toggleStripTransparency() {
    closePanel()
    userToggledTransparent = true
    localTransparent = !localTransparent
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
      if (!parsed) {
        root.settingsReady = true
        return
      }
      if (parsed.tokens.length > 0) root.storedTokens = parsed.tokens
      else root.storedTokens = []
      root.storedTemplate = parsed.template
      root.settingsReady = true
      Qt.callLater(root.refresh)
    }
    onLoadFailed: {
      root.settingsReady = true
      Qt.callLater(root.refresh)
    }
  }

  Process {
    id: priceProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = root.priceSource === "binance"
          ? Model.parseBinance(text, root.tokens)
          : Model.parseGeckoPrices(text, root.tokens)
        if (!parsed) return
        var merged = Model.mergeQuotes(root.quotes, parsed)
        var next = {}
        var list = root.tokens
        for (var i = 0; i < list.length; i++) {
          if (merged[list[i].id]) next[list[i].id] = merged[list[i].id]
        }
        root.quotes = next
        root.statusText = ""
        root.refreshInterval = Model.REFRESH_MS
        root.queuePaprikaFallbacks(next)
      }
    }
    onExited: function(code) {
      root.refreshing = false
      if (code === 0) return
      if (root.priceSource === "gecko" && root.refreshBinance()) return
      root.statusText = "Price fetch failed"
      root.refreshInterval = Model.nextBackoff(root.refreshInterval)
    }
  }

  Process {
    id: paprikaProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = Model.parsePaprikaTicker(text)
        if (parsed) {
          root.quotes = Model.mergeQuotes(root.quotes, parsed)
          root.statusText = ""
        }
      }
    }
    onExited: function(code) {
      root.paprikaQueue = root.paprikaQueue.slice(1)
      if (code !== 0) root.lastPaprikaAt = Date.now()
      Qt.callLater(root.drainPaprika)
    }
  }

  Process {
    id: layerRuleProc
    command: [
      "hyprctl",
      "eval",
      "hl.layer_rule({ match = { namespace = \"kaduxo-omatick\" }, no_anim = true, animation = \"none\" })"
    ]
  }

  Timer {
    interval: root.refreshInterval
    running: root.settingsReady
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Timer {
    interval: 2000
    running: !root.settingsReady
    repeat: false
    onTriggered: {
      if (root.settingsReady) return
      root.settingsReady = true
      root.refresh()
    }
  }

  Timer {
    id: pendingClick
    interval: 280
    repeat: false
    property var anchor: null
    onTriggered: root.activateFrom(anchor, -1)
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
        implicitHeight: root.stripSize
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

        MouseArea {
          anchors.fill: parent
          acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
          onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) root.cycleTemplate()
            else if (mouse.button === Qt.MiddleButton) root.refresh()
            else root.handleEmptyClick(tickerRow)
          }
        }

        Flickable {
          id: tickerFlick
          anchors.fill: parent
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          flickableDirection: Flickable.HorizontalFlick
          contentHeight: height
          contentWidth: Math.max(width, tickerRow.implicitWidth)
          interactive: tickerRow.implicitWidth > width

          Row {
            id: tickerRow
            height: tickerFlick.height
            spacing: Style.space(2)
            x: tickerRow.implicitWidth >= tickerFlick.width ? 0 : Math.round((tickerFlick.width - tickerRow.implicitWidth) / 2)

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
                horizontalMargin: Style.space(9)
                verticalPadding: Style.space(9)
                fontSize: Style.font.caption
                useActiveColor: false
                foreground: modelData.id ? root.tokenColor(modelData) : Commons.Color.muted

                onPressed: function(b) {
                  if (b === Qt.RightButton) root.cycleTemplate()
                  else if (b === Qt.MiddleButton) root.refresh()
                  else root.activateFrom(this, modelData.id ? index : -1)
                }
              }
            }
          }
        }
      }
    }
  }
}
