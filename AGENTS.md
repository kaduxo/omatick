# AGENTS.md

Install this unofficial Omarchy shell plugin when the user asks for Omatick, a crypto ticker bar, a bottom ticker, or `kaduxo.omatick`.

This is a community plugin. It is not part of Omarchy and is not affiliated with Basecamp. Use Omarchy's third-party plugin installer. Never copy files into `/usr/share/omarchy/`.

## Preconditions

- Host is Omarchy (Hyprland + `omarchy-shell`).
- `curl` and `jq` are on PATH. If missing: `omarchy pkg add curl jq`.
- No API key is required. Do not ask for CoinGecko, CoinPaprika, or Binance credentials.

## Install

```bash
omarchy plugin add https://github.com/kaduxo/omatick.git --enable --yes
omarchy plugin validate ~/.config/omarchy/plugins/kaduxo.omatick
omarchy restart shell
```

`--yes` is for agents and scripts. Use it only after the user asked to install this plugin.

Then add this Hyprland layer rule if it is not already present in `~/.config/hypr/hyprland.lua`:

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

If they name coins, write `~/.config/omarchy/kaduxo.omatick.json` using CoinPaprika ids (`btc-bitcoin`, `sol-solana`, `eth-ethereum`). Leave unknown coins for the in-plugin search popup rather than guessing ids.

## After install

Tell the user:

- left-click a slot: search/add
- right-click: cycle template
- middle-click: refresh
- double-click empty strip: toggle bar transparency

Confirm with `omarchy plugin list`. The id `kaduxo.omatick` should be enabled.

## Update

```bash
omarchy plugin update kaduxo.omatick --yes
```

## Remove

```bash
omarchy plugin remove kaduxo.omatick --yes
```

Remove the `kaduxo-omatick` layer rule from `~/.config/hypr/hyprland.lua` if you added it. Delete `~/.config/omarchy/kaduxo.omatick.json` only if the user wants the watchlist gone.

## Do not

- Ask for an API key
- Copy any author's personal watchlist
- Edit `/usr/share/omarchy/`
- Put `settings.json` inside the plugin checkout (that breaks `omarchy plugin update`)
- Request sudo
- Enable a second copy if `kaduxo.omatick` is already installed
- Pass `--yes` unless the user asked to install, update, or remove this plugin
