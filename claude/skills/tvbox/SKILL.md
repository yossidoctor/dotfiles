---
name: tvbox
description: Reference for the Android TV / Google TV streaming box (Xiaomi TV Box S, Android 14) — reaching it over ADB, settings keys, cmd and dumpsys services, packages and the home app, display/HDR/audio/HDMI-CEC, Wi‑Fi, and the living-room wiring and remotes. Fires on "TV box", "Google TV", "Android TV", "ADB", "CEC", "soundbar", "remote".
---

# tvbox

Documentation for an Android 14 Google TV box controlled over ADB without root, and for the living-room setup it sits in. It describes what each setting, command and service does and how to read and verify it. It carries no preferred settings; the choice belongs to the user.

## Reaching the box

The box's LAN address comes from the router's DHCP client list. ADB runs over the network on TCP 5555:

```
adb connect <ip>:5555
adb -s <ip>:5555 shell '<command>' </dev/null
```

`adb shell` forwards the caller's stdin to the box (`adb --help`: `-n: don't read from stdin`), so a call inside a loop or script takes `</dev/null` or `-n`. The host key is `~/.android/adbkey`; the box shows an "Allow USB debugging?" prompt the first time a key connects, and the user accepts it on the TV. ADB setup, ports, persistence and what the shell user may do: [platform.md](references/platform.md).

The box has no Ethernet port ([hardware.md](references/hardware.md)), so network ADB runs over its Wi‑Fi: turning Wi‑Fi off, changing network or rebooting ends the ADB session. After a reboot the user re-enables Wireless debugging on the TV before `adb connect` works again ([platform.md § ADB](references/platform.md#adb)).

## Making a change

1. Read the current value of everything about to change (`settings get`, `cmd <svc> get-…`, `pm list packages -d`); together the values are the restore command.
2. Ask the user for approval, naming the exact command, what it changes, what it interrupts (playback, Wi‑Fi, ADB, the home screen), and the restore command; wait for an explicit yes in their reply to that question. Each state-changing command takes its own approval, including a reboot.
3. Run the approved command.
4. Read the value back the same way it was read in step 1, plus the live effect where one exists (`dumpsys display`, `dumpsys hdmi_control`, `dumpsys wifi`).

Completion: each changed value reads back as set, its live effect is visible where the reference names one, and the user has the restore command.

## Reference files

- [platform.md](references/platform.md) — identity properties, the shell user's permissions, ADB (network, pairing, keys, persistence), logs, dumpsys, bugreport, screenshots.
- [settings.md](references/settings.md) — the `settings` command and every TV-relevant key in global / secure / system, with AOSP meaning and values.
- [commands.md](references/commands.md) — `cmd` services: package, activity, wifi, display, hdmi_control, audio, media_session, power, role, appops, device_config, overlay, input keycodes, time.
- [av.md](references/av.md) — display modes, HDR, frame-rate matching, surround audio formats, HDMI-CEC settings and bus, readable HDMI sysfs and EDID.
- [network.md](references/network.md) — Wi‑Fi chip, country code and channel lists, connection fields, verbose logging, Private DNS.
- [packages.md](references/packages.md) — package states and how to restore them, the home app and HOME role, overlays, Google TV packages.
- [hardware.md](references/hardware.md) — Xiaomi TV Box S (3rd Gen) specifications and where sources disagree.
- [setup.md](references/setup.md) — the user's living room: wiring, the remotes and what each controls.
