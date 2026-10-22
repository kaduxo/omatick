import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "kaduxo.omatick"
  ipcTarget: "kaduxo.omatick"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  property var suggestions: []
  property int suggestionIndex: 0
  property string searchQuery: ""
  property string searchStatus: ""

  readonly property var tokens: hostWidget && hostWidget.tokens ? hostWidget.tokens : []
  readonly property var quotes: hostWidget && hostWidget.quotes ? hostWidget.quotes : ({})
  readonly property string template: hostWidget && hostWidget.template ? hostWidget.template : "symbol-price-change"
  readonly property int replaceIndex: hostWidget && "replaceIndex" in hostWidget ? hostWidget.replaceIndex : -1

  function open() {
    root.controller.show()
    Qt.callLater(root.focusSearch)
  }

  function openFromHotkey() {
    root.controller.show()
    Qt.callLater(root.focusSearch)
  }

  function close() {
    root.controller.hide()
    root.clearSearch()
  }

  function focusSearch() {
    if (!root.opened || !searchField) return
    searchField.forceActiveFocus()
  }

  function clearSearch() {
    if (searchField) searchField.text = ""
    suggestions = []
    suggestionIndex = 0
    searchStatus = ""
    searchDebounce.stop()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.openFromHotkey()
  }

  function requestSearch() {
    var query = searchField.text.trim()
    searchQuery = query
    if (query.length < 1) {
      suggestions = []
      searchStatus = ""
      return
    }
    if (!searchProc.running) startSearch()
  }

  function startSearch() {
    var url = Model.searchUrl(searchQuery)
    if (url === "") return
    searchStatus = "Searching…"
    searchProc.command = ["curl", "-fsSL", "--max-time", "8", "-A", "omatick/1.0", url]
    searchProc.running = true
  }

  function pickSuggestion(token) {
    if (!hostWidget || !hostWidget.selectToken) return
    hostWidget.selectToken(token)
    searchField.text = ""
    suggestions = []
    searchStatus = ""
  }

  function removeToken(index) {
    if (hostWidget && hostWidget.removeToken) hostWidget.removeToken(index)
  }

  function setReplaceIndex(index) {
    if (hostWidget) hostWidget.replaceIndex = index
  }

  function setTemplate(value) {
    if (hostWidget && hostWidget.setTemplate) hostWidget.setTemplate(value)
  }

  Process {
    id: searchProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.suggestions = Model.parseSearch(text)
        root.suggestionIndex = 0
        root.searchStatus = root.suggestions.length === 0 ? "No coins found" : ""
      }
    }
    onExited: function(code) {
      if (code !== 0) root.searchStatus = "Search failed"
    }
  }

  Timer {
    id: searchDebounce
    interval: 350
    onTriggered: root.requestSearch()
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.openFromHotkey() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: searchField
    contentWidth: panel.fittedContentWidth ? panel.fittedContentWidth(Style.space(420)) : Style.space(420)
    contentHeight: panel.fittedContentHeight ? panel.fittedContentHeight(body.implicitHeight) : Style.space(420)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: searchField.activeFocus
      onCloseRequested: root.close()
      onReturnRequested: {
        if (root.suggestions.length > 0) root.pickSuggestion(root.suggestions[Math.max(0, root.suggestionIndex)])
      }
      onMoveRequested: function(dx, dy) {
        if (root.suggestions.length === 0) return
        var next = root.suggestionIndex + dy
        if (next < 0) next = 0
        if (next >= root.suggestions.length) next = root.suggestions.length - 1
        root.suggestionIndex = next
      }

      Column {
        id: body
        width: parent.width
        spacing: Style.space(12)

        Text {
          width: parent.width
          text: "Omatick"
          color: root.bar ? root.bar.foreground : Color.foreground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.heading
        }

        Text {
          width: parent.width
          wrapMode: Text.WordWrap
          text: tokens.length >= Model.MAX_TOKENS
            ? "Ten coins on the bar. Click one below, then pick a search result to replace it."
            : "Search a coin to add it. Up to ten on the bottom bar."
          color: Color.muted
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
        }

        Repeater {
          model: tokens

          Rectangle {
            required property var modelData
            required property int index
            width: body.width
            height: Style.space(36)
            radius: Style.cornerRadius
            color: root.replaceIndex === index ? Color.menu.selectedBackground : "transparent"
            border.width: 1
            border.color: root.replaceIndex === index ? Color.accent : Color.popups.border

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.setReplaceIndex(index)
            }

            Row {
              anchors.fill: parent
              anchors.leftMargin: Style.space(10)
              anchors.rightMargin: Style.space(8)
              spacing: Style.space(10)

              Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - Style.space(70)
                elide: Text.ElideRight
                text: Model.formatToken(modelData, root.quotes, root.template)
                color: {
                  var change = Model.changeValue(modelData, root.quotes)
                  if (isFinite(change) && change < 0) return Color.urgent
                  return root.bar ? root.bar.foreground : Color.foreground
                }
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.body
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "✕"
                color: Color.muted
                font.pixelSize: Style.font.body
                MouseArea {
                  anchors.fill: parent
                  anchors.margins: -6
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.removeToken(index)
                }
              }
            }
          }
        }

        TextField {
          id: searchField
          width: parent.width
          placeholderText: "Search bitcoin, solana, pepe…"
          foreground: root.bar ? root.bar.foreground : Color.foreground
          onTextChanged: searchDebounce.restart()
          Keys.priority: Keys.BeforeItem
          Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
              root.close()
              event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
              if (root.suggestions.length > 0) root.pickSuggestion(root.suggestions[Math.max(0, root.suggestionIndex)])
              event.accepted = true
            } else if (event.key === Qt.Key_Down) {
              if (root.suggestionIndex < root.suggestions.length - 1) root.suggestionIndex++
              event.accepted = true
            } else if (event.key === Qt.Key_Up) {
              if (root.suggestionIndex > 0) root.suggestionIndex--
              event.accepted = true
            }
          }
        }

        Text {
          visible: root.searchStatus !== ""
          width: parent.width
          text: root.searchStatus
          color: Color.muted
          font.pixelSize: Style.font.caption
        }

        Repeater {
          model: suggestions

          Rectangle {
            required property var modelData
            required property int index
            width: body.width
            height: Style.space(32)
            radius: Style.cornerRadius
            color: root.suggestionIndex === index ? Color.menu.selectedBackground : "transparent"

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onEntered: root.suggestionIndex = index
              onClicked: root.pickSuggestion(modelData)
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              anchors.left: parent.left
              anchors.leftMargin: Style.space(10)
              anchors.right: parent.right
              anchors.rightMargin: Style.space(10)
              elide: Text.ElideRight
              text: modelData.symbol + "  " + modelData.name
              color: root.bar ? root.bar.foreground : Color.foreground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.body
            }
          }
        }

        Text {
          width: parent.width
          text: "Display"
          color: Color.muted
          font.pixelSize: Style.font.caption
        }

        ButtonGroup {
          width: parent.width
          foreground: root.bar ? root.bar.foreground : Color.foreground
          accent: Color.accent
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
          fontSize: Style.font.caption
          value: root.template
          options: Model.TEMPLATES
          onChanged: function(value) { root.setTemplate(value) }
        }
      }
    }
  }
}
