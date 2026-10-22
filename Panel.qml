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
  property string inflightQuery: ""
  property bool searchRestart: false
  property int draggingIndex: -1
  property int dropIndex: -1

  readonly property var tokens: hostWidget && hostWidget.tokens ? hostWidget.tokens : []
  readonly property var quotes: hostWidget && hostWidget.quotes ? hostWidget.quotes : ({})
  readonly property string template: hostWidget && hostWidget.template ? hostWidget.template : "symbol-price-change"
  readonly property int replaceIndex: hostWidget && "replaceIndex" in hostWidget ? hostWidget.replaceIndex : -1
  readonly property color upColor: hostWidget && hostWidget.upColor ? hostWidget.upColor : "#7d9a78"

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
    draggingIndex = -1
    dropIndex = -1
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
    inflightQuery = ""
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
      inflightQuery = ""
      return
    }
    startSearch()
  }

  function startSearch() {
    var url = Model.searchUrl(searchQuery)
    if (url === "") return
    if (searchProc.running) {
      searchRestart = true
      searchProc.running = false
      return
    }
    inflightQuery = searchQuery
    searchStatus = "Searching…"
    searchProc.command = Model.curlCommand(url)
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

  function moveToken(from, to) {
    if (hostWidget && hostWidget.moveToken) hostWidget.moveToken(from, to)
  }

  function tokenColor(token) {
    var change = Model.changeValue(token, root.quotes)
    if (isFinite(change) && change < 0) return Color.urgent
    if (isFinite(change) && change > 0) return root.upColor
    return root.bar ? root.bar.foreground : Color.foreground
  }

  function finishDrag() {
    if (draggingIndex >= 0 && dropIndex >= 0 && draggingIndex !== dropIndex)
      root.moveToken(draggingIndex, dropIndex)
    draggingIndex = -1
    dropIndex = -1
  }

  Process {
    id: searchProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (root.inflightQuery !== root.searchQuery) return
        root.suggestions = Model.parseSearch(text)
        root.suggestionIndex = 0
        root.searchStatus = root.suggestions.length === 0 ? "No coins found" : ""
      }
    }
    onExited: function(code) {
      if (root.searchRestart) {
        root.searchRestart = false
        root.startSearch()
        return
      }
      if (code !== 0 && root.inflightQuery === root.searchQuery)
        root.searchStatus = "Search failed"
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
          text: "Omatick Crypto"
          color: root.bar ? root.bar.foreground : Color.foreground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.heading
        }

        Text {
          width: parent.width
          wrapMode: Text.WordWrap
          text: tokens.length >= Model.MAX_TOKENS
            ? "Ten coins on the strip. Drag the handle to reorder, or click a coin and pick a search result to replace it."
            : "Search a coin to add it. Drag the handle to reorder. Up to ten on the bottom strip."
          color: Color.muted
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
        }

        Repeater {
          model: tokens

          Rectangle {
            id: tokenRow
            required property var modelData
            required property int index
            width: body.width
            height: Style.space(36)
            radius: Style.cornerRadius
            color: {
              if (root.dropIndex === index && root.draggingIndex >= 0) return Color.menu.selectedBackground
              if (root.replaceIndex === index) return Color.menu.selectedBackground
              return "transparent"
            }
            border.width: 1
            border.color: root.replaceIndex === index ? Color.accent : Color.popups.border

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.setReplaceIndex(index)
              onEntered: {
                if (root.draggingIndex >= 0) root.dropIndex = index
              }
            }

            Row {
              anchors.fill: parent
              anchors.leftMargin: Style.space(8)
              anchors.rightMargin: Style.space(8)
              spacing: Style.space(8)

              Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(16)
                text: "⠿"
                color: Color.muted
                font.pixelSize: Style.font.body
                MouseArea {
                  anchors.fill: parent
                  anchors.margins: -6
                  cursorShape: Qt.SizeAllCursor
                  onPressed: {
                    root.draggingIndex = index
                    root.dropIndex = index
                  }
                  onReleased: root.finishDrag()
                  onCanceled: root.finishDrag()
                }
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - Style.space(90)
                elide: Text.ElideRight
                text: Model.formatToken(modelData, root.quotes, root.template)
                color: root.tokenColor(modelData)
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
