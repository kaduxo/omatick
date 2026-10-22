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
  property string viewMode: "watch"
  property var markets: []
  property int marketsPage: 0
  property string marketsStatus: ""
  property bool marketsLoading: false
  property var selectedMarket: null
  property var chartPoints: []
  property string chartDays: "7"
  property string chartStatus: ""

  readonly property var tokens: hostWidget && hostWidget.tokens ? hostWidget.tokens : []
  readonly property var quotes: hostWidget && hostWidget.quotes ? hostWidget.quotes : ({})
  readonly property string template: hostWidget && hostWidget.template ? hostWidget.template : "symbol-price-change"
  readonly property int replaceIndex: hostWidget && "replaceIndex" in hostWidget ? hostWidget.replaceIndex : -1
  readonly property color upColor: hostWidget && hostWidget.upColor ? hostWidget.upColor : "#7d9a78"
  readonly property color chartColor: {
    if (!selectedMarket) return Color.accent
    return Model.marketChangeColor(selectedMarket.usd_24h_change, upColor, Color.urgent, Color.accent)
  }

  function open() {
    root.controller.show()
    Qt.callLater(root.focusSearch)
  }

  function openFromHotkey() {
    root.controller.show()
    Qt.callLater(root.focusSearch)
  }

  function applyPayload(raw) {
    try {
      var parsed = typeof raw === "string" && raw !== "" ? JSON.parse(raw) : raw
      if (parsed && parsed.view === "markets") {
        root.viewMode = "markets"
        root.ensureMarkets()
      }
    } catch (e) {}
  }

  function close() {
    root.controller.hide()
    root.clearSearch()
    draggingIndex = -1
    dropIndex = -1
  }

  function focusSearch() {
    if (!root.opened || root.viewMode !== "watch" || !searchField) return
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

  function setViewMode(value) {
    root.viewMode = value === "markets" ? "markets" : "watch"
    if (root.viewMode === "markets") root.ensureMarkets()
    else Qt.callLater(root.focusSearch)
  }

  function ensureMarkets() {
    if (root.markets.length > 0 || marketsProc.running) return
    root.marketsPage = 0
    loadMarketsPage(1)
  }

  function loadMarketsPage(page) {
    var url = Model.marketsUrl(page)
    if (url === "") return
    root.marketsLoading = true
    root.marketsStatus = root.markets.length === 0 ? "Loading markets…" : "Loading more…"
    root.marketsPage = page
    marketsProc.command = Model.curlCommand(url)
    marketsProc.running = true
  }

  function loadMoreMarkets() {
    if (marketsProc.running) return
    loadMarketsPage(root.marketsPage + 1)
  }

  function selectMarket(row) {
    root.selectedMarket = row
    root.chartDays = "7"
    root.showSparkline()
  }

  function showSparkline() {
    var spark = root.selectedMarket && root.selectedMarket.sparkline ? root.selectedMarket.sparkline : []
    root.chartPoints = spark
    root.chartStatus = spark.length > 1 ? "" : "Chart unavailable"
  }

  function setChartRange(days) {
    if (!root.selectedMarket) return
    root.chartDays = days
    if (days === "7") {
      root.showSparkline()
      return
    }
    root.loadChart(root.selectedMarket.id, days)
  }

  function loadChart(id, days) {
    var url = Model.chartUrl(id, days)
    if (url === "") return
    root.chartDays = days
    root.chartStatus = root.chartPoints.length > 1 ? "" : "Loading chart…"
    chartProc.command = Model.curlCommand(url)
    chartProc.running = true
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

  Process {
    id: marketsProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = Model.parseMarkets(text)
        if (!parsed) {
          root.marketsStatus = "Markets failed"
          return
        }
        root.markets = root.marketsPage <= 1 ? parsed : root.markets.concat(parsed)
        root.marketsStatus = parsed.length === 0 ? "No more markets" : ""
        if (!root.selectedMarket && parsed.length > 0) root.selectMarket(parsed[0])
      }
    }
    onExited: function(code) {
      root.marketsLoading = false
      if (code !== 0) root.marketsStatus = "Markets failed"
    }
  }

  Process {
    id: chartProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = Model.parseChart(text)
        if (parsed) {
          root.chartPoints = parsed
          root.chartStatus = ""
        } else if (root.chartPoints.length < 2) {
          root.chartStatus = "Chart unavailable"
        } else {
          root.chartStatus = ""
        }
      }
    }
    onExited: function(code) {
      if (code !== 0 && root.chartPoints.length < 2) root.chartStatus = "Chart unavailable"
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
    function browse(): void {
      root.viewMode = "markets"
      root.ensureMarkets()
      root.openFromHotkey()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: searchField
    contentWidth: panel.fittedContentWidth ? panel.fittedContentWidth(Style.space(460)) : Style.space(460)
    contentHeight: panel.fittedContentHeight ? panel.fittedContentHeight(body.implicitHeight) : Style.space(460)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: searchField.activeFocus
      onCloseRequested: root.close()
      onReturnRequested: {
        if (root.viewMode === "watch" && root.suggestions.length > 0)
          root.pickSuggestion(root.suggestions[Math.max(0, root.suggestionIndex)])
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

        ButtonGroup {
          width: parent.width
          foreground: root.bar ? root.bar.foreground : Color.foreground
          accent: Color.accent
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
          fontSize: Style.font.caption
          value: root.viewMode
          options: [
            { value: "watch", label: "Watchlist" },
            { value: "markets", label: "Markets" }
          ]
          onChanged: function(value) { root.setViewMode(value) }
        }

        Text {
          visible: root.viewMode === "watch"
          width: parent.width
          wrapMode: Text.WordWrap
          text: tokens.length >= Model.MAX_TOKENS
            ? "Ten coins on the strip. Drag the handle to reorder, or click a coin and pick a search result to replace it."
            : "Search a coin to add it, or open Markets for CoinGecko charts. Up to ten on the strip."
          color: Color.muted
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
        }

        Repeater {
          model: root.viewMode === "watch" ? tokens : []

          Rectangle {
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
          visible: root.viewMode === "watch"
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
          visible: root.viewMode === "watch" && root.searchStatus !== ""
          width: parent.width
          text: root.searchStatus
          color: Color.muted
          font.pixelSize: Style.font.caption
        }

        Repeater {
          model: root.viewMode === "watch" ? suggestions : []

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

        Column {
          visible: root.viewMode === "markets"
          width: parent.width
          spacing: Style.space(10)

          Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Top CoinGecko markets by cap, 25 per page. Click a row for a chart."
            color: Color.muted
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
          }

          Text {
            visible: root.marketsStatus !== ""
            width: parent.width
            text: root.marketsStatus
            color: Color.muted
            font.pixelSize: Style.font.caption
          }

          Sparkline {
            width: parent.width
            height: Style.space(88)
            visible: root.chartPoints.length > 1
            points: root.chartPoints
            lineColor: root.chartColor
          }

          Row {
            visible: root.selectedMarket !== null
            width: parent.width
            spacing: Style.space(10)

            Text {
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width - Style.space(120)
              elide: Text.ElideRight
              text: root.selectedMarket
                ? root.selectedMarket.symbol + "  " + root.selectedMarket.name + "  " + Model.formatPrice(root.selectedMarket.usd)
                : ""
              color: root.chartColor
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.body
            }

            Button {
              text: "Add"
              bordered: true
              foreground: root.bar ? root.bar.foreground : Color.foreground
              accent: Color.accent
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
              fontSize: Style.font.caption
              onClicked: if (root.selectedMarket) root.pickSuggestion(root.selectedMarket)
            }
          }

          ButtonGroup {
            visible: root.selectedMarket !== null
            width: parent.width
            foreground: root.bar ? root.bar.foreground : Color.foreground
            accent: Color.accent
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            fontSize: Style.font.caption
            value: root.chartDays
            options: [
              { value: "1", label: "1D" },
              { value: "7", label: "7D" },
              { value: "30", label: "30D" }
            ]
            onChanged: function(value) { root.setChartRange(value) }
          }

          Text {
            visible: root.chartStatus !== ""
            width: parent.width
            text: root.chartStatus
            color: Color.muted
            font.pixelSize: Style.font.caption
          }

          Flickable {
            width: parent.width
            height: Style.space(40) * 7 + Style.space(4) * 6
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            contentWidth: width
            contentHeight: marketList.implicitHeight
            flickableDirection: Flickable.VerticalFlick

            Column {
              id: marketList
              width: parent.width
              spacing: Style.space(4)

              Repeater {
                model: root.markets

                Rectangle {
                  required property var modelData
                  required property int index
                  width: marketList.width
                  height: Style.space(40)
                  radius: Style.cornerRadius
                  color: root.selectedMarket && root.selectedMarket.id === modelData.id
                    ? Color.menu.selectedBackground
                    : "transparent"

                  MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selectMarket(modelData)
                  }

                  Row {
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(8)
                    anchors.rightMargin: Style.space(8)
                    spacing: Style.space(8)

                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      width: Style.space(70)
                      elide: Text.ElideRight
                      text: modelData.symbol
                      color: root.bar ? root.bar.foreground : Color.foreground
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.caption
                    }

                    Sparkline {
                      anchors.verticalCenter: parent.verticalCenter
                      width: Style.space(72)
                      height: Style.space(22)
                      points: modelData.sparkline
                      lineColor: Model.marketChangeColor(modelData.usd_24h_change, root.upColor, Color.urgent, Color.accent)
                    }

                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      width: parent.width - Style.space(200)
                      elide: Text.ElideRight
                      text: Model.formatPrice(modelData.usd) + "  " + Model.formatChange(modelData.usd_24h_change)
                      color: Model.marketChangeColor(modelData.usd_24h_change, root.upColor, Color.urgent, Color.muted)
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.caption
                    }
                  }
                }
              }
            }
          }

          Button {
            text: root.marketsLoading ? "Loading…" : "More markets"
            enabled: !root.marketsLoading
            bordered: true
            foreground: root.bar ? root.bar.foreground : Color.foreground
            accent: Color.accent
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            fontSize: Style.font.caption
            onClicked: root.loadMoreMarkets()
          }
        }

        Text {
          visible: root.viewMode === "watch"
          width: parent.width
          text: "Display"
          color: Color.muted
          font.pixelSize: Style.font.caption
        }

        ButtonGroup {
          visible: root.viewMode === "watch"
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
