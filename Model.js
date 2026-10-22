.pragma library

var PLUGIN_ID = "kaduxo.omatick"
var USER_AGENT = "omatick/1.0"
var LAYER_NAMESPACE = "kaduxo-omatick"
var MAX_TOKENS = 10

var TEMPLATES = [
  { value: "symbol-price-change", label: "BTC $97k +1.2%" },
  { value: "symbol-price", label: "BTC $97,432" },
  { value: "compact", label: "BTC 97.4k" },
  { value: "name-price", label: "Bitcoin $97,432" },
  { value: "change", label: "BTC +1.2%" }
]

function defaultTokens() {
  return [
    { id: "btc-bitcoin", symbol: "BTC", name: "Bitcoin" }
  ]
}

function paprikaIdFromGecko(id, symbol) {
  var slug = String(id || "").trim()
  var ticker = String(symbol || "").trim().toLowerCase()
  if (!slug) return ""
  if (slug.indexOf("-") >= 0) return slug
  return ticker ? ticker + "-" + slug : slug
}

function normalizeToken(raw) {
  if (!raw || typeof raw !== "object") return null
  var id = paprikaIdFromGecko(raw.id, raw.symbol)
  var symbol = String(raw.symbol || "").trim().toUpperCase()
  var name = String(raw.name || symbol || id).trim()
  if (!id || !symbol) return null
  return { id: id, symbol: symbol, name: name }
}

function normalizeTokens(raw) {
  var source = Array.isArray(raw) ? raw : []
  var out = []
  var seen = {}
  for (var i = 0; i < source.length && out.length < MAX_TOKENS; i++) {
    var token = normalizeToken(source[i])
    if (!token || seen[token.id]) continue
    seen[token.id] = true
    out.push(token)
  }
  return out
}

function templateIds() {
  var ids = []
  for (var i = 0; i < TEMPLATES.length; i++) ids.push(TEMPLATES[i].value)
  return ids
}

function normalizeTemplate(value) {
  var id = String(value || "")
  var ids = templateIds()
  return ids.indexOf(id) >= 0 ? id : "symbol-price-change"
}

function nextTemplate(value) {
  var ids = templateIds()
  var current = normalizeTemplate(value)
  var index = ids.indexOf(current)
  return ids[(index + 1) % ids.length]
}

function withCommas(n) {
  var s = String(Math.round(Number(n) || 0))
  var out = ""
  var count = 0
  for (var i = s.length - 1; i >= 0; i--) {
    out = s.charAt(i) + out
    count++
    if (count === 3 && i > 0 && s.charAt(i - 1) !== "-") {
      out = "," + out
      count = 0
    }
  }
  return out
}

function formatPrice(n) {
  var value = Number(n)
  if (!isFinite(value)) return "—"
  if (Math.abs(value) >= 1000) return "$" + withCommas(value)
  if (Math.abs(value) >= 1) return "$" + value.toFixed(2)
  if (Math.abs(value) >= 0.01) return "$" + value.toFixed(4)
  return "$" + value.toPrecision(3)
}

function formatCompact(n) {
  var value = Number(n)
  if (!isFinite(value)) return "—"
  var abs = Math.abs(value)
  if (abs >= 1e9) return (value / 1e9).toFixed(2) + "B"
  if (abs >= 1e6) return (value / 1e6).toFixed(2) + "M"
  if (abs >= 1e3) return (value / 1e3).toFixed(1) + "k"
  if (abs >= 1) return value.toFixed(2)
  return value.toPrecision(3)
}

function formatChange(n) {
  var value = Number(n)
  if (!isFinite(value)) return "—"
  var sign = value > 0 ? "+" : ""
  return sign + value.toFixed(1) + "%"
}

function quoteFor(quotes, id) {
  if (!quotes || typeof quotes !== "object") return null
  return quotes[id] || null
}

function formatToken(token, quotes, template) {
  if (!token) return ""
  var quote = quoteFor(quotes, token.id)
  var price = quote ? quote.usd : NaN
  var change = quote ? quote.usd_24h_change : NaN
  var kind = normalizeTemplate(template)

  if (kind === "symbol-price") return token.symbol + " " + formatPrice(price)
  if (kind === "compact") return token.symbol + " " + formatCompact(price)
  if (kind === "name-price") return token.name + " " + formatPrice(price)
  if (kind === "change") return token.symbol + " " + formatChange(change)
  return token.symbol + " " + formatPrice(price) + " " + formatChange(change)
}

function changeValue(token, quotes) {
  var quote = quoteFor(quotes, token && token.id)
  if (!quote) return NaN
  return Number(quote.usd_24h_change)
}

function parseSearch(raw) {
  try {
    var parsed = JSON.parse(String(raw || ""))
    var coins = parsed && parsed.coins ? parsed.coins : (parsed && parsed.currencies ? parsed.currencies : [])
    var out = []
    var seen = {}
    for (var i = 0; i < coins.length && out.length < 12; i++) {
      var token = normalizeToken(coins[i])
      if (!token || seen[token.id]) continue
      seen[token.id] = true
      out.push(token)
    }
    return out
  } catch (e) {
    return []
  }
}

function parsePrices(raw) {
  try {
    var parsed = JSON.parse(String(raw || ""))
    if (!parsed || typeof parsed !== "object") return {}
    if (parsed.error) return null
    if (parsed.quotes && parsed.quotes.USD) {
      var mapped = {}
      mapped[parsed.id || ""] = {
        usd: parsed.quotes.USD.price,
        usd_24h_change: parsed.quotes.USD.percent_change_24h
      }
      return mapped
    }
    return parsed
  } catch (e) {
    return null
  }
}

function parseSettings(raw) {
  try {
    var parsed = JSON.parse(String(raw || ""))
    if (!parsed || typeof parsed !== "object") return { tokens: defaultTokens(), template: "symbol-price-change" }
    var tokens = normalizeTokens(parsed.tokens)
    return {
      tokens: tokens.length > 0 ? tokens : defaultTokens(),
      template: normalizeTemplate(parsed.template)
    }
  } catch (e) {
    return { tokens: defaultTokens(), template: "symbol-price-change" }
  }
}

function searchUrl(query) {
  var q = String(query || "").trim()
  if (q.length < 1) return ""
  return "https://api.coinpaprika.com/v1/search/?q=" + encodeURIComponent(q) + "&c=currencies&limit=12"
}

function applySelection(tokens, incoming, replaceIndex) {
  var list = normalizeTokens(tokens)
  var token = normalizeToken(incoming)
  if (!token) return list

  for (var i = 0; i < list.length; i++) {
    if (list[i].id === token.id) return list
  }

  if (list.length < MAX_TOKENS && !(replaceIndex >= 0 && replaceIndex < list.length)) {
    list.push(token)
    return list
  }

  var index = replaceIndex
  if (!(index >= 0 && index < list.length)) index = list.length - 1
  if (index < 0) list.push(token)
  else list[index] = token
  return normalizeTokens(list)
}

function removeAt(tokens, index) {
  var list = normalizeTokens(tokens)
  var i = Number(index)
  if (isNaN(i) || i < 0 || i >= list.length) return list
  list.splice(i, 1)
  return list
}

function priceCommand(tokens) {
  var list = normalizeTokens(tokens)
  if (list.length === 0) return []
  var ua = USER_AGENT
  var args = [
    "bash",
    "-c",
    "files=(); trap 'rm -f \"${files[@]}\"' EXIT; " +
      "for spec in \"$@\"; do " +
      "id=\"${spec%%|*}\"; symbol=\"${spec#*|}\"; f=$(mktemp); files+=(\"$f\"); " +
      "( " +
      "if curl -fsSL --max-time 8 -A '" + ua + "' \"https://api.coinpaprika.com/v1/tickers/${id}\" > \"$f\"; then :; " +
      "elif [ -n \"$symbol\" ] && [ \"$symbol\" != \"$id\" ]; then " +
      "curl -fsSL --max-time 8 -A '" + ua + "' \"https://api.binance.com/api/v3/ticker/24hr?symbol=${symbol}USDT\" " +
      "| jq --arg id \"$id\" '{id:$id, quotes:{USD:{price:(.lastPrice|tonumber), percent_change_24h:(.priceChangePercent|tonumber)}}}' > \"$f\" || echo '{}' > \"$f\"; " +
      "else echo '{}' > \"$f\"; fi; " +
      ") & done; wait; " +
      "jq -s 'map(select(.quotes.USD != null) | {(.id): {usd: .quotes.USD.price, usd_24h_change: .quotes.USD.percent_change_24h}}) | add // {}' \"${files[@]}\"",
    "omatick"
  ]
  for (var i = 0; i < list.length; i++) args.push(list[i].id + "|" + list[i].symbol)
  return args
}
