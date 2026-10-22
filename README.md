# Omatick

Unofficial community plugin for [Omarchy](https://omarchy.org/). It is not affiliated with Basecamp or the Omarchy project. Plugin id `kaduxo.omatick`. This is a crypto ticker, not the OmaTick checklist widget.

Omatick adds a bottom crypto ticker strip. Omarchy has one native bar, so this plugin is a `keepLoaded` panel that occupies an exclusive zone at the bottom of the screen and follows the active Omarchy theme.

Prices come from [CoinPaprika](https://coinpaprika.com/), with Binance USDT 24hr as fallback. No API key is required.

Plugin id: `kaduxo.omatick`

## Requirements

- [Omarchy](https://omarchy.org/) (Hyprland + `omarchy-shell`)
- `curl` and `jq` (already present on a stock Omarchy install)

## Install

```sh
omarchy plugin add https://github.com/kaduxo/omatick.git --enable
```

That is the Omarchy plugin installer. It clones this repo into `~/.config/omarchy/plugins/kaduxo.omatick/`, validates `manifest.json`, and enables the plugin. It does not run plugin code, install hooks, or sudo.

`keepLoaded` panels usually need a shell restart after first enable:

```sh
omarchy restart shell
```

Optional: stop Hyprland from animating the strip on map. Add this to `~/.config/hypr/hyprland.lua`, then `hyprctl reload`:

```lua
hl.layer_rule({ match = { namespace = "kaduxo-omatick" }, no_anim = true, animation = "none" })
```

Confirm it loaded:

```sh
omarchy plugin list
omarchy plugin validate ~/.config/omarchy/plugins/kaduxo.omatick
```

## AI agents

If you are a coding agent installing this for a user, follow [`AGENTS.md`](AGENTS.md). The short version:

```sh
omarchy pkg add curl jq
omarchy plugin add https://github.com/kaduxo/omatick.git --enable --yes
omarchy restart shell
```

Do not ask for an API key. Ask which coins to watch (default: Bitcoin). Max 10.

## Usage

| Input | Action |
| --- | --- |
| Left-click a coin | Search / add / replace |
| Right-click | Cycle display template |
| Middle-click | Refresh prices |
| Double-click empty strip | Toggle bar transparency |

Default display is `symbol-price-change` (`BTC $97,432 +1.2%`). Other templates: `symbol-price`, `compact`, `name-price`, `change`.

Watchlist is stored in `~/.config/omarchy/kaduxo.omatick.json`, outside the git checkout, so `omarchy plugin update` stays clean. See [`settings.example.json`](settings.example.json).

## Update

```sh
omarchy plugin update kaduxo.omatick
```

## Remove

```sh
omarchy plugin remove kaduxo.omatick --yes
```

Then delete the optional Hyprland layer rule if you added it, and the watchlist file if you want it gone:

```sh
rm -f ~/.config/omarchy/kaduxo.omatick.json
```

Removal leaves nothing else behind.

## Security

This is a third-party plugin. It runs unsandboxed inside `omarchy-shell` with your user account. Read the code before you enable it. Outbound HTTPS goes only to `api.coinpaprika.com` and `api.binance.com`. There is no sudo, no install hook, and no write outside `~/.config/omarchy/kaduxo.omatick.json` plus the plugin's own `shell.json` entry.

## License

MIT. See [LICENSE](LICENSE).
