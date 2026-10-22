# AGENTS.md

Install this unofficial Omarchy shell plugin when the user asks for Omatick, Omatick Crypto, a crypto ticker bar, a bottom ticker, or `kaduxo.omatick`.

This is a community plugin. It is not part of Omarchy and is not affiliated with Basecamp. Use Omarchy's third-party plugin installer. Never copy files into `/usr/share/omarchy/`.

## Preconditions

- Host is Omarchy (Hyprland + `omarchy-shell`).
- `curl` is on PATH (stock Omarchy).
- No credentials are required. Do not ask for CoinGecko, Binance, or CoinPaprika accounts.

## Install

```bash
omarchy plugin add https://github.com/kaduxo/omatick.git --enable --yes
omarchy plugin validate ~/.config/omarchy/plugins/kaduxo.omatick
omarchy restart shell
```

`--yes` is for agents and scripts. Use it only after the user asked to install this plugin.

Then add this Hyprland layer rule if it is not already present in `~/.config/hypr/hyprland.lua`. The strip animates on map without it after a compositor restart.

```lua
hl.layer_rule({ match = { namespace = "kaduxo-omatick" }, no_anim = true, animation = "none" })
```

Backup the file first. After editing, run `hyprctl reload` and `hyprctl configerrors`.

Do not write the watchlist into the plugin git checkout. User settings live at:

```
~/.config/omarchy/kaduxo.omatick.json
```

If that file does not exist, the plugin defaults to Bitcoin.

## Ask the user only for

1. Which coins to show (default: BTC). Max 10.
2. Display template if they care: `symbol-price-change` (default), `symbol-price`, `compact`, `name-price`, `change`.

If they name coins, write `~/.config/omarchy/kaduxo.omatick.json` using CoinPaprika ids you are sure of (`btc-bitcoin`, `sol-solana`, `eth-ethereum`). Leave unknown coins for the in-plugin search popup rather than guessing ids.

## After install

Tell the user:

- left-click a coin: search/add/replace
- left-click empty strip: open picker
- double-click empty strip: toggle strip transparency
- right-click: cycle template
- middle-click: refresh
- drag ⠿ in the picker: reorder
- Markets tab: paged CoinGecko list with charts; Add puts a coin on the strip

Confirm with `omarchy plugin list`. The id `kaduxo.omatick` should be enabled.

## Update

```bash
omarchy plugin update kaduxo.omatick --yes
```

## Remove

```bash
omarchy plugin remove kaduxo.omatick --yes
```

`omarchy plugin remove` does not edit Hyprland. Remove the `kaduxo-omatick` layer rule from `~/.config/hypr/hyprland.lua` if you added it. Delete `~/.config/omarchy/kaduxo.omatick.json` only if the user wants the watchlist gone.

## Change workflow

After editing this plugin, test on the user's machine before pushing:

1. Copy `Model.js`, `Panel.qml`, `TickerBar.qml`, and `Sparkline.qml` into `~/.config/omarchy/plugins/kaduxo.omatick/`
2. `omarchy plugin validate ~/.config/omarchy/plugins/kaduxo.omatick`
3. `omarchy restart shell`
4. Confirm the strip still shows prices, then open the picker and the Markets tab
5. Only then commit and `git push`, then `omarchy plugin update kaduxo.omatick --yes`

## Do not

- Ask for credentials
- Copy any author's personal watchlist
- Edit `/usr/share/omarchy/`
- Put `settings.json` inside the plugin checkout (that breaks `omarchy plugin update`)
- Enable a second copy if `kaduxo.omatick` is already installed
- Pass `--yes` unless the user asked to install, update, or remove this plugin
