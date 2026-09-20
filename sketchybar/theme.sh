#!/usr/bin/env bash
# theme.sh — every color and font the bar draws with, sourced by sketchybarrc
# and by each plugin that recolors an item.
#
# Palette is macOS system color, read from NSColor on this machine rather than
# transcribed: ACCENT is controlAccentColor, and the status hues are systemGreen
# / systemOrange / systemRed / systemGray in their dark-appearance variants.
# Format is sketchybar's 0xAARRGGBB, so every literal carries its own alpha.
#
# BAR_BG is OPAQUE, and must stay opaque. The native menu bar is a Window
# Server window at layer 24 and sketchybar draws at 25 — one above it, but only
# one — so any alpha below 0xff lets the real menu bar read through the bar as a
# washed-out band of its text. That is not fixable from sketchybar's side:
#
#   * hiding the menu bar via SLSSetMenuBarInsetAndAlpha(cid, 0, 1, 0.0) returns
#     success and changes NOTHING on macOS 27 — screenshots at alpha 1.0 and 0.0
#     are byte-identical. Do not reach for it again.
#   * turning OFF menu-bar auto-hide makes macOS reserve the band (measured: the
#     external went 0 -> 31pt) but the menu bar still DRAWS there, so the bleed
#     remains.
#
# The popup is a separate window with nothing behind it to bleed through, so it
# keeps its translucency and its own blur.
#
# Text sits directly on the bar with no chip behind it, so legibility rests on
# TEXT_SHADOW; the shadow is load-bearing here, not decoration.

BAR_BG=0xff1c1c1e
POPUP_BG=0xa61c1c1e

# The focused workspace is the one filled shape in the bar. Everything else
# draws as bare text, so fill alone marks focus and no border is needed.
#
# The fill is white rather than the system accent: over a translucent bar the
# accent competes with whatever the wallpaper is doing behind it, where white
# reads as a lit surface at any hue. ON_ACCENT below is therefore dark, so the
# focused chip inverts — dark glyphs on a white pill — which is also how macOS
# marks a selected menu bar item.
ACCENT=0xffffffff
ACCENT_FILL=0xf2ffffff

# labelColor / secondaryLabelColor / tertiaryLabelColor, dark appearance.
TEXT=0xf2ffffff
SUBTEXT=0xbfffffff
OVERLAY=0x8cffffff
# An empty workspace chip: present enough to click, quiet enough that the eye
# skips it. Deliberately fainter than SUBTEXT, which still has to be readable.
IDLE=0x66ffffff
# What an item takes on hover — a faint fill under the text, the same cue macOS
# uses for a menu bar item the pointer is over.
HOVER_BG=0x26ffffff
# The hairline between item groups. Faint enough to separate without becoming a
# third thing the eye has to read.
DIVIDER=0x40ffffff
# What text takes ON the focused chip's white fill: near-black, matching
# labelColor in macOS's light appearance.
ON_ACCENT=0xd8000000

GREEN=0xff30d158
YELLOW=0xffffd60a
PEACH=0xffff9230
RED=0xffff4245
BLUE=0xff0a84ff
SKY=0xff64d2ff

# A playing source is tinted in its own app's brand color rather than a single
# status green, so the pill says WHICH player is making noise at a glance. A
# player with no entry here falls back to BRAND_DEFAULT.
BRAND_SPOTIFY=0xff1db954
BRAND_VLC=0xffff8800
BRAND_SAFARI=0xff0a84ff
BRAND_MUSIC=0xfffa2d48
BRAND_CHROME=0xff4285f4
BRAND_TV=0xffffffff
BRAND_DEFAULT=0xff30d158

# Distance from the top of the screen past which the pointer is no longer over
# the bar or an open popup. Bar height 38 + popup y_offset 4 + at most three
# rows at background.height 26 comes to ~120; this rounds well past that.
# Generous on purpose: overshooting only keeps a menu open slightly below its
# own bottom edge, while falling short closes it under the pointer. Read by both
# plugins/media.sh and plugins/media-row.sh, which is why it lives here rather
# than in either.
POPUP_BOTTOM=190

# Shadow behind every glyph and label. sketchybar takes a polar offset and
# computes y as -distance*sin(angle) (src/shadow.c), in a space where y grows
# upward — so the shadow falls BELOW the text at angle 90, and 270 would lift it
# above.
TEXT_SHADOW=0xa6000000
SHADOW_ANGLE=90
SHADOW_DISTANCE=2

# SF Pro carries both the text and the SF Symbols used below; the symbols live
# in it as Private Use Area codepoints, and .SF NS (the system font that ships
# with macOS) does NOT contain them — verified with CTFontGetGlyphsForCharacters.
# Installed to ~/Library/Fonts from Apple's SFProFonts.pkg.
#
# "SF Pro" alone resolves to SFPro-Black, the variable font's heaviest instance,
# so the optical-size families are named explicitly instead.
FONT_TEXT="SF Pro Text"
FONT_NUM="SF Pro Text"
# sketchybar-app-font is a separate ligature font of per-app icons; its
# icon_map.sh is what turns an app name into the ligature that renders as that
# app's glyph.
FONT_APP="sketchybar-app-font"

# SF Symbols, as UTF-8 byte escapes. These run under macOS /bin/bash 3.2
# (README § Script conventions), which expands neither $'\Uxxxxxxxx' nor
# printf '\U' — both yield the literal text — so each glyph is spelled as the
# bytes of its codepoint, which 3.2 does expand. Codepoints and SF Symbols names
# are in the comment beside each.
ICON_BATT_FULL=$'\xF4\x80\x9B\xA8'  # U+1006E8 battery.100
ICON_BATT_75=$'\xF4\x80\xBA\xB8'  # U+100EB8 battery.75
ICON_BATT_50=$'\xF4\x80\xBA\xB6'  # U+100EB6 battery.50
ICON_BATT_25=$'\xF4\x80\x9B\xA9'  # U+1006E9 battery.25
ICON_BATT_EMPTY=$'\xF4\x80\x9B\xAA'  # U+1006EA battery.0
ICON_BATT_CHARGING=$'\xF4\x80\xA2\x8B'  # U+10088B battery.100.bolt

ICON_VOL_HIGH=$'\xF4\x80\x8A\xA9'  # U+1002A9 speaker.wave.3
ICON_VOL_MID=$'\xF4\x80\x8A\xA7'  # U+1002A7 speaker.wave.2
ICON_VOL_LOW=$'\xF4\x80\x8A\xA5'  # U+1002A5 speaker.wave.1
ICON_VOL_MUTE=$'\xF4\x80\x8A\xA3'  # U+1002A3 speaker.slash

ICON_MUSIC=$'\xF4\x80\x91\xAA'  # U+10046A music.note
ICON_PREV=$'\xF4\x80\x8A\x8A'  # U+10028A backward.fill
ICON_PLAY=$'\xF4\x80\x8A\x84'  # U+100284 play.fill
ICON_PAUSE=$'\xF4\x80\x8A\x86'  # U+100286 pause.fill
ICON_NEXT=$'\xF4\x80\x8A\x8C'  # U+10028C forward.fill
