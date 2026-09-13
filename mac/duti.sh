#!/usr/bin/env bash
# Default app bindings via LaunchServices. Idempotent — safe to re-run.
# No `set -e`: a single unknown UTI shouldn't abort the rest of the bindings.

command -v duti >/dev/null 2>&1 || {
  echo "duti.sh: duti not installed (brew bundle installs it) — skipping bindings; re-run ./install after brew bundle"
  exit 0
}

VSCODE="com.microsoft.VSCode"
GHOSTTY="com.mitchellh.ghostty"
VLC="org.videolan.vlc"

# role defaults to editor (read+save, implies viewer) — the right role for a
# document handler. `all` additionally claims URL-scheme roles.
#
# HTML is deliberately unbound: an `.html`/`public.html` binding lets
# LaunchServices cross-promote that app into the http(s) slot, taking the default
# browser with it. Unbound, HTML opens in the system browser and is edited via
# Open-With — never add it to the VS Code lists below.
bind() { duti -s "$1" "$2" "${3:-editor}" || echo "  skip: $2 (no LaunchServices entry)"; }

# ── VS Code: code ──
for ext in py js ts tsx jsx go rs rb lua zsh sh; do
  bind "$VSCODE" ".$ext"
done

# ── VS Code: config ──
for ext in json yaml yml toml ini conf env; do
  bind "$VSCODE" ".$ext"
done

# ── VS Code: markup ──
for ext in md css scss xml; do
  bind "$VSCODE" ".$ext"
done

# ── VS Code: data ──
for ext in txt log csv tsv sql; do
  bind "$VSCODE" ".$ext"
done

# ── VS Code: plain-text UTI (catches extensionless: Brewfile, Makefile) ──
bind "$VSCODE" public.plain-text

# ── Ghostty: terminal-launcher files (shell role = executes the item) ──
for ext in command tool; do
  bind "$GHOSTTY" ".$ext" shell
done

# ── VLC: video (viewer role = plays, doesn't save) ──
for ext in mp4 mkv mov avi webm flv wmv; do
  bind "$VLC" ".$ext" viewer
done

# ── VLC: audio ──
for ext in mp3 flac wav ogg m4a opus; do
  bind "$VLC" ".$ext" viewer
done

echo "duti bindings applied."
