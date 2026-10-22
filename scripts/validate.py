#!/usr/bin/env python3
"""Static checks for the Omatick plugin repo. No host Omarchy install required."""

from __future__ import annotations

import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

REQUIRED_FILES = (
    "manifest.json",
    "TickerBar.qml",
    "Panel.qml",
    "Model.js",
    "LICENSE",
    "README.md",
    "AGENTS.md",
    "preview.png",
    "settings.example.json",
)

SCAN_GLOBS = (
    "manifest.json",
    "TickerBar.qml",
    "Panel.qml",
    "Model.js",
    "README.md",
    "AGENTS.md",
    "settings.example.json",
    "LICENSE",
)


def fail(message: str) -> None:
    print(f"validate: {message}", file=sys.stderr)
    sys.exit(1)


def read(path: str) -> str:
    with open(os.path.join(ROOT, path), encoding="utf-8") as fh:
        return fh.read()


def main() -> None:
    os.chdir(ROOT)

    for name in REQUIRED_FILES:
        if not os.path.isfile(os.path.join(ROOT, name)):
            fail(f"missing {name}")

    if os.path.isfile(os.path.join(ROOT, "settings.json")):
        fail("settings.json must not be committed")

    manifest = json.loads(read("manifest.json"))
    if manifest.get("schemaVersion") != 1:
        fail("schemaVersion must be 1")
    if manifest.get("id") != "kaduxo.omatick":
        fail("id must be kaduxo.omatick")
    if str(manifest.get("id", "")).startswith("omarchy."):
        fail("id must not use the reserved omarchy. prefix")
    if manifest.get("kinds") != ["panel"]:
        fail("kinds must be [panel]")
    if manifest.get("entryPoints", {}).get("panel") != "TickerBar.qml":
        fail("entryPoints.panel must be TickerBar.qml")

    example = json.loads(read("settings.example.json"))
    tokens = example.get("tokens") or []
    if len(tokens) != 1 or tokens[0].get("id") != "btc-bitcoin":
        fail("settings.example.json must only contain Bitcoin")

    blob = "\n".join(read(name) for name in SCAN_GLOBS).lower()
    if "protonmail" in blob:
        fail("personal mailbox string found in plugin files")

    print("ok", manifest["id"], manifest.get("version"))


if __name__ == "__main__":
    main()
