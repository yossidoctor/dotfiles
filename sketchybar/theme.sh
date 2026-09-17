#!/usr/bin/env bash
# theme.sh — every color and font the bar draws with, sourced by sketchybarrc
# and by each plugin that recolors an item.
#
# Palette is Catppuccin Mocha, the same theme ghostty/config sets and
# starship/starship.toml's [palettes.main] draws from; the hex values there are
# the reference for anything added here. Format is sketchybar's 0xAARRGGBB, so
# every literal carries its own alpha.
#
# The bar reads BAR_BG at 0xf0 rather than opaque: a fully opaque strip against
# a wallpaper reads as a black band, and blur is not an option here (open
# renderer bugs #839/#827 make blur_radius unreliable on this OS).

BAR_BG=0xf01e1e2e
ITEM_BG=0xff313244
GROUP_BG=0xff181825
ITEM_BORDER=0xff45475a
POPUP_BG=0xf0181825

TEXT=0xffcdd6f4
SUBTEXT=0xffa6adc8
OVERLAY=0xff6c7086

ACCENT=0xffcba6f7
# The focused workspace's fill: the accent at low alpha, so the chip reads as
# tinted rather than filled and the label stays legible over it.
ACCENT_FILL=0x30cba6f7
BLUE=0xff89b4fa
SKY=0xff89dceb
GREEN=0xffa6e3a1
YELLOW=0xfff9e2af
PEACH=0xfffab387
RED=0xfff38ba8

# JetBrainsMono Nerd Font is installed by brew/Brewfile
# (cask font-jetbrains-mono-nerd-font) and is what ghostty renders in.
FONT_TEXT="JetBrainsMono Nerd Font"
FONT_NUM="JetBrainsMono Nerd Font"
# sketchybar-app-font is a separate ligature font of per-app icons; its
# icon_map.sh is what turns an app name into the ligature that renders as that
# app's glyph.
FONT_APP="sketchybar-app-font"

# Nerd Font glyphs, as UTF-8 byte escapes. These run under macOS /bin/bash 3.2
# (README § Script conventions), which expands neither $'\Uxxxxxxxx' nor
# printf '\U' — both yield the literal text — so each glyph is spelled as the
# bytes of its codepoint, which 3.2 does expand. Codepoints are in the comment
# beside each name.
ICON_BATT_FULL=$'\xEF\x89\x80'  # U+F240
ICON_BATT_75=$'\xEF\x89\x81'  # U+F241
ICON_BATT_50=$'\xEF\x89\x82'  # U+F242
ICON_BATT_25=$'\xEF\x89\x83'  # U+F243
ICON_BATT_EMPTY=$'\xEF\x89\x84'  # U+F244
ICON_BATT_CHARGING=$'\xEF\x83\xA7'  # U+F0E7

ICON_VOL_HIGH=$'\xEF\x80\xA8'  # U+F028
ICON_VOL_MID=$'\xEF\x80\xA7'  # U+F027
ICON_VOL_LOW=$'\xEF\x80\xA7'  # U+F027
ICON_VOL_MUTE=$'\xEF\x80\xA6'  # U+F026

ICON_MUSIC=$'\xEF\x80\x81'  # U+F001
ICON_PREV=$'\xEF\x81\x88'  # U+F048
ICON_PLAY=$'\xEF\x81\x8B'  # U+F04B
ICON_PAUSE=$'\xEF\x81\x8C'  # U+F04C
ICON_NEXT=$'\xEF\x81\x91'  # U+F051
