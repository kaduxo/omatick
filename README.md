# CryptoTickBar

Unofficial community plugin for [Omarchy](https://omarchy.org/). It is a crypto ticker, not affiliated with Basecamp or the Omarchy project. Plugin id `kaduxo.cryptotickbar`. Source lives at [kaduxo/omatick](https://github.com/kaduxo/omatick).

CryptoTickBar adds a bottom crypto ticker strip. Omarchy has one native bar, so this plugin is a `keepLoaded` panel that occupies an exclusive zone at the bottom of each screen and follows the active Omarchy theme.

Prices come from CoinGecko `simple/price` in one request. If CoinGecko is unavailable, Binance USDT 24hr is the fallback. CoinPaprika fills coins those two do not list. Search and Markets use CoinGecko. No credentials are required.

## Requirements

- [Omarchy](https://omarchy.org/) (Hyprland + `omarchy-shell`)
- `curl` (stock Omarchy)

## Install

```sh
omarchy plugin add https://github.com/kaduxo/omatick.git --enable
```

That is the Omarchy plugin installer. It clones this repo into `~/.config/omarchy/plugins/kaduxo.cryptotickbar/`, validates `manifest.json`, and enables the plugin. It does not run plugin code or install hooks.

`keepLoaded` panels usually need a shell restart after first enable:

```sh
omarchy restart shell
```

Required so Hyprland does not animate the strip after a compositor restart. Add this to `~/.config/hypr/hyprland.lua`, then `hyprctl reload`:

```lua
hl.layer_rule({ match = { namespace = "kaduxo-cryptotickbar" }, no_anim = true, animation = "none" })
```

The plugin also applies that rule for the current Hyprland session when it loads.

Confirm it loaded:

```sh
omarchy plugin list
omarchy plugin validate ~/.config/omarchy/plugins/kaduxo.cryptotickbar
```

## AI agents

If you are a coding agent installing this for a user, follow [`AGENTS.md`](AGENTS.md).

## Usage

| Input | Action |
| --- | --- |
| Left-click a coin | Search / add / replace |
| Left-click empty strip | Open the picker |
| Double-click empty strip | Toggle strip transparency |
| Right-click | Cycle display template |
| Middle-click | Refresh prices |
| Drag ⠿ in the picker | Reorder coins |
| Watchlist / Markets | Switch picker tabs |
| Markets row | Chart (1D / 7D / 30D) and Add |

Default display is `symbol-price-change` (`BTC $97,432 +1.2%`). Other templates: `symbol-price`, `compact`, `name-price`, `change`. Gains are green, losses are red. Long watchlists scroll horizontally on one row.

The Markets tab loads CoinGecko's top coins by market cap, 25 per page, with a themed sparkline and a larger chart for the selected coin. It does not download every CoinGecko listing at once. `omarchy-shell kaduxo.cryptotickbar browse` opens that tab.

Watchlist is stored only in `~/.config/omarchy/kaduxo.cryptotickbar.json`, outside the git checkout, so `omarchy plugin update` stays clean. See [`settings.example.json`](settings.example.json). Prices are USD.

## Update

```sh
omarchy plugin update kaduxo.cryptotickbar
```

## Remove

```sh
omarchy plugin remove kaduxo.cryptotickbar --yes
```

That removes the plugin checkout and disables it. It does not edit Hyprland. If you added the layer rule, delete that line from `~/.config/hypr/hyprland.lua`. Delete the watchlist only if you want it gone:

```sh
rm -f ~/.config/omarchy/kaduxo.cryptotickbar.json
```

## Security

This is a third-party plugin. It runs unsandboxed inside `omarchy-shell` with your user account. Read the code before you enable it. Outbound HTTPS goes only to `api.coingecko.com`, `api.binance.com`, and `api.coinpaprika.com`. Coin ids are allowlisted before they are used in URLs. There is no install hook. The only extra write is `~/.config/omarchy/kaduxo.cryptotickbar.json`.

## License

MIT. See [LICENSE](LICENSE).
