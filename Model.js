.pragma library

var PLUGIN_ID = "kaduxo.omatick"
var USER_AGENT = "omatick/1.0"
var LAYER_NAMESPACE = "kaduxo-omatick"
var MAX_TOKENS = 10
var REFRESH_MS = 60000
var REFRESH_MAX_MS = 900000
var PAPRIKA_GAP_MS = 300000

var TEMPLATES = [
  { value: "symbol-price-change", label: "BTC $97k +1.2%" },
  { value: "symbol-price", label: "BTC $97,432" },
  { value: "compact", label: "BTC 97.4k" },
  { value: "name-price", label: "Bitcoin $97,432" },
  { value: "change", label: "BTC +1.2%" }
]

function defaultTokens() {
  return [
    { id: "bitcoin", symbol: "BTC", name: "Bitcoin" }
  ]
}

function isSafeId(value) {
  return /^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(String(value || ""))
}

function isSafeSymbol(value) {
  return /^[A-Z0-9][A-Z0-9-]{0,19}$/.test(String(value || ""))
}

function normalizeToken(raw) {
  if (!raw || typeof raw !== "object") return null
  var id = String(raw.id || "").trim().toLowerCase()
  var symbol = String(raw.symbol || "").trim().toUpperCase()
  var name = String(raw.name || symbol || id).trim()
  if (!isSafeId(id) || !isSafeSymbol(symbol)) return null
  if (!name) return null
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

function geckoIdCandidates(token) {
  var ids = []
  function add(value) {
    var id = String(value || "").trim().toLowerCase()
    if (!isSafeId(id) || ids.indexOf(id) >= 0) return
    ids.push(id)
  }
  if (!token) return ids
  add(token.id)
  add(String(token.symbol || "").toLowerCase())
  var prefix = String(token.symbol || "").toLowerCase() + "-"
  var id = String(token.id || "")
  if (prefix.length > 1 && id.indexOf(prefix) === 0) add(id.slice(prefix.length))
  return ids
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
    var coins = []
    if (parsed && Array.isArray(parsed.coins)) coins = parsed.coins
    else if (parsed && Array.isArray(parsed.currencies)) coins = parsed.currencies
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

function parseGeckoPrices(raw, tokens) {
  try {
    var parsed = JSON.parse(String(raw || ""))
    if (!parsed || typeof parsed !== "object" || parsed.error || parsed.status) return null
    var list = normalizeTokens(tokens)
    var out = {}
    for (var i = 0; i < list.length; i++) {
      var cands = geckoIdCandidates(list[i])
      for (var j = 0; j < cands.length; j++) {
        var row = parsed[cands[j]]
        if (!row || typeof row !== "object") continue
        var price = Number(row.usd)
        if (!isFinite(price)) continue
        out[list[i].id] = { usd: price, usd_24h_change: Number(row.usd_24h_change) }
        break
      }
    }
    return out
  } catch (e) {
    return null
  }
}

function parseBinance(raw, tokens) {
  try {
    var parsed = JSON.parse(String(raw || ""))
    var rows = Array.isArray(parsed) ? parsed : (parsed && parsed.symbol ? [parsed] : [])
    var byPair = {}
    for (var i = 0; i < rows.length; i++) {
      var pair = String(rows[i].symbol || "")
      var price = Number(rows[i].lastPrice)
      var change = Number(rows[i].priceChangePercent)
      if (!pair || !isFinite(price)) continue
      byPair[pair] = { usd: price, usd_24h_change: change }
    }
    var list = normalizeTokens(tokens)
    var out = {}
    for (var j = 0; j < list.length; j++) {
      var quote = byPair[binancePair(list[j].symbol)]
      if (quote) out[list[j].id] = quote
    }
    return out
  } catch (e) {
    return null
  }
}

function parsePaprikaTicker(raw) {
  try {
    var parsed = JSON.parse(String(raw || ""))
    if (!parsed || typeof parsed !== "object" || parsed.error) return null
    if (!isSafeId(parsed.id) || !parsed.quotes || !parsed.quotes.USD) return null
    var price = Number(parsed.quotes.USD.price)
    var change = Number(parsed.quotes.USD.percent_change_24h)
    if (!isFinite(price)) return null
    var mapped = {}
    mapped[parsed.id] = { usd: price, usd_24h_change: change }
    return mapped
  } catch (e) {
    return null
  }
}

function mergeQuotes(base, extra) {
  var out = {}
  var key
  if (base && typeof base === "object") {
    for (key in base) out[key] = base[key]
  }
  if (extra && typeof extra === "object") {
    for (key in extra) out[key] = extra[key]
  }
  return out
}

function missingQuoteIds(tokens, quotes) {
  var list = normalizeTokens(tokens)
  var missing = []
  for (var i = 0; i < list.length; i++) {
    if (!quoteFor(quotes, list[i].id)) missing.push(list[i].id)
  }
  return missing
}

function parseSettings(raw) {
  try {
    var parsed = JSON.parse(String(raw || ""))
    if (!parsed || typeof parsed !== "object") return null
    return {
      tokens: normalizeTokens(parsed.tokens),
      template: normalizeTemplate(parsed.template)
    }
  } catch (e) {
    return null
  }
}

function searchUrl(query) {
  var q = String(query || "").trim()
  if (q.length < 1) return ""
  return "https://api.coingecko.com/api/v3/search?query=" + encodeURIComponent(q)
}

function geckoPriceUrl(tokens) {
  var list = normalizeTokens(tokens)
  var ids = []
  var seen = {}
  for (var i = 0; i < list.length; i++) {
    var cands = geckoIdCandidates(list[i])
    for (var j = 0; j < cands.length; j++) {
      if (seen[cands[j]]) continue
      seen[cands[j]] = true
      ids.push(cands[j])
    }
  }
  if (ids.length === 0) return ""
  return "https://api.coingecko.com/api/v3/simple/price?ids=" + ids.join(",") + "&vs_currencies=usd&include_24hr_change=true"
}

function binancePair(symbol) {
  var match = String(symbol || "").toUpperCase().match(/^[A-Z0-9]{2,12}/)
  return match ? match[0] + "USDT" : ""
}

function compactJsonStrings(values) {
  var parts = []
  for (var i = 0; i < values.length; i++) parts.push('"' + values[i] + '"')
  return "[" + parts.join(",") + "]"
}

function binanceUrl(tokens) {
  var list = normalizeTokens(tokens)
  var pairs = []
  var seen = {}
  for (var i = 0; i < list.length; i++) {
    var pair = binancePair(list[i].symbol)
    if (!pair || seen[pair]) continue
    seen[pair] = true
    pairs.push(pair)
  }
  if (pairs.length === 0) return ""
  return "https://api.binance.com/api/v3/ticker/24hr?symbols=" + encodeURIComponent(compactJsonStrings(pairs))
}

function paprikaTickerUrl(id) {
  if (!isSafeId(id)) return ""
  return "https://api.coinpaprika.com/v1/tickers/" + id
}

function curlCommand(url) {
  if (!url) return []
  return ["curl", "-fsSL", "--max-time", "8", "-A", USER_AGENT, url]
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

function moveToken(tokens, from, to) {
  var list = normalizeTokens(tokens)
  var src = Number(from)
  var dst = Number(to)
  if (isNaN(src) || src < 0 || src >= list.length) return list
  if (isNaN(dst)) return list
  if (dst < 0) dst = 0
  if (dst >= list.length) dst = list.length - 1
  if (src === dst) return list
  var item = list.splice(src, 1)[0]
  list.splice(dst, 0, item)
  return list
}

function nextBackoff(current) {
  var value = Number(current)
  if (!isFinite(value) || value < REFRESH_MS) value = REFRESH_MS
  return Math.min(value * 2, REFRESH_MAX_MS)
}
