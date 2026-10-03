#!/bin/bash
# Runs Claude Code from one fixed path so macOS privacy grants survive upgrades.
#
# TCC keys a bare Mach-O by its resolved path, and the cask installs each
# version into its own Caskroom/<version>/ folder, so every upgrade is a new
# app to Full Disk Access and the folder prompts. A background session (the
# `claude daemon` and its children, which re-exec their own path) has no GUI
# parent to inherit a grant from, so it prompts as `claude` itself.
# https://github.com/anthropics/claude-code/issues/87144
#
# Linked ahead of /opt/homebrew/bin on PATH. The copy is refreshed when the
# cask's symlink points somewhere new; a running copy keeps its old inode.
set -euo pipefail

src="$(readlink -f /opt/homebrew/bin/claude)"
dir="$HOME/.local/share/claude-stable"
bin="$dir/claude"

if [ ! -x "$bin" ] || [ "$(cat "$dir/source" 2>/dev/null)" != "$src" ]; then
  mkdir -p "$dir"
  cp -X "$src" "$bin.$$"
  mv -f "$bin.$$" "$bin"
  printf '%s' "$src" > "$dir/source"
fi

exec "$bin" "$@"
