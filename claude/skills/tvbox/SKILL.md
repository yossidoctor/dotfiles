---
name: tvbox
description: TV box (Xiaomi TV Box S, Google TV on Android 14) — reading or changing its settings, apps, picture, sound or Wi‑Fi over ADB without root, and the living-room wiring and remotes around it. Fires on "TV box", "ADB", "CEC", "soundbar", "remote".
---

# tvbox

This skill carries no preferred settings; the choice belongs to the user.

## Reaching the box

The box's LAN address is its DHCP reservation on the router: `ssh router 'nvram get dhcp_staticlist'` prints each reservation's MAC, IP and hostname ([router skill, wan-lan.md § DHCP](../router/references/wan-lan.md#dhcp)). ADB runs over the network on TCP 5555:

```
adb connect <ip>:5555
adb -s <ip>:5555 shell '<command>' </dev/null
```

`adb connect` and `adb shell` block for minutes when nothing listens on the port, so `nc -z -G 3 <ip> 5555`, which answers within 3 seconds, runs before the first adb call of a session or task and again after anything that ends the session. The box has no Ethernet port ([hardware.md](references/hardware.md)), so ADB rides its Wi‑Fi, and a reboot, a Wi‑Fi change or a router Wi‑Fi restart ends it until the user re-enables Wireless debugging on the TV ([platform.md § ADB](references/platform.md#adb)). An open port means the adb calls that follow run plain; a closed port has three causes, told apart by `ssh router 'ping -c 2 -W 2 <ip>'`: the box is off (the router gets no reply), Wireless debugging needs re-enabling (both the router's ping and the Mac's ping get replies), or the Mac cannot reach the box (the router's ping gets replies while the Mac's does not). In the third case asking the user to re-enable debugging changes nothing; the router's client tables locate the break ([router skill, diagnostics.md](../router/references/diagnostics.md)).

`adb shell` forwards the caller's stdin to the box (`adb --help`: `-n: don't read from stdin`), so a call inside a loop or script takes `</dev/null` or `-n`, or it swallows the loop's remaining input. The host key is `~/.android/adbkey`; the box shows an "Allow USB debugging?" prompt the first time a key connects, and the user accepts it on the TV. ADB setup, ports, persistence and what the shell user may do: [platform.md](references/platform.md).

## Making a change

1. Read the current value of everything about to change (`settings get`, `cmd <svc> get-…`, `pm list packages -d`); together the values are the restore command.
2. Tell the user the exact command, what it changes, what it interrupts (playback, Wi‑Fi, ADB, the home screen), and the restore command. Each state-changing adb call can interrupt the living room, so it runs only after the user's explicit yes to that command; one yes covers one command, a reboot included.
3. Run the approved command.
4. Read the value back the same way it was read in step 1, plus the live effect where one exists (`dumpsys display`, `dumpsys hdmi_control`, `dumpsys wifi`).

Done when each changed value reads back as set, its live effect is visible where the reference names one, and the user has the restore command.

## Reference files

- [platform.md](references/platform.md) — identity properties, the shell user's permissions, ADB (network, pairing, keys, persistence), logs, dumpsys, bugreport, screenshots.
- [settings.md](references/settings.md) — the `settings` command and every TV-relevant key in global / secure / system, with AOSP meaning and values.
- [commands.md](references/commands.md) — `cmd` services: which subcommands only read, and each service's gotchas; `cmd <svc> help` prints the syntax.
- [av.md](references/av.md) — display modes, HDR, frame-rate matching, surround audio formats, HDMI-CEC settings and bus, readable HDMI sysfs and EDID.
- [network.md](references/network.md) — Wi‑Fi chip, country code and channel lists, connection fields, verbose logging, Private DNS.
- [packages.md](references/packages.md) — package states and how to restore them, the home app and HOME role, overlays, Google TV packages.
- [hardware.md](references/hardware.md) — Xiaomi TV Box S (3rd Gen) specifications and where sources disagree.
- [setup.md](references/setup.md) — the user's living room: wiring, the remotes and what each controls, the Mac's Movies share in VLC.
