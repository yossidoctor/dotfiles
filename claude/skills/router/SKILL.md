---
name: router
description: Reference for the home ASUS router (stock ASUSWRT on MediaTek) and the Wi‑Fi around it — reading and changing its settings over SSH, nvram keys, channels and regulatory rules, logs and diagnostics, and the macOS client tools that measure the link. Fires on "router", "Wi‑Fi", "channel", "country code", "DFS", "Smart Connect", "port forward", "nvram".
---

# router

Documentation for a stock ASUSWRT router built on a MediaTek Wi‑Fi platform, and for measuring Wi‑Fi from a Mac. It describes how the router works and how to read, change and verify it. It carries no preferred settings: every setting here is described by what it does, and the choice belongs to the user.

## Reaching the router

Access is `ssh router '<commands>'`. The host alias, key and admin user live in `~/.ssh/config` under `Host router`; `ssh -G router | grep -E '^(hostname|user|identityfile) '` prints them. The router side is enabled in Administration › System › Enable SSH, with the public key pasted into Authorized Keys (stored in nvram `sshd_authkeys`). Details: [platform.md § SSH](references/platform.md#ssh).

The router runs BusyBox: `ping` takes `-c`/`-W`/`-w` and has no `-i`; `nvram get` reads one key per call, so several keys are read with a loop: `for k in a b c; do echo "$k=$(nvram get $k)"; done`.

A command that restarts the radios or the router (`service restart_wireless`, `service restart_net`, `reboot`) ends the SSH session mid-output, and on a Wi‑Fi‑connected Mac it also drops the Mac's link. The write, the restart, a wait loop (`until ssh -o ConnectTimeout=3 router true; do sleep 3; done`) and the read-back therefore run as one Bash call with `run_in_background: true`; its exit notification is the signal that the router is back. The hook `~/.claude/hooks/enforce-foreground-polling.sh` refuses foreground sleep loops and foreground sleeps of 10 s or more.

## How the router holds state

Three layers hold the same setting, and they can disagree:

```
LAYER                        READ WITH                                  WRITTEN BY
--------------------------   ----------------------------------------   ---------------------------
nvram (persistent config)    nvram get <key>                            nvram set + nvram commit
generated driver config      cat /etc/Wireless/RT2860/RT2860.dat        rc, on every radio restart
                             cat /etc/Wireless/iNIC/iNIC_ap.dat
live radio / kernel state    iwconfig ra0 | rai0, /proc, dmesg          the driver, at runtime
```

A value in nvram is a request; the driver config is what rc derived from it; the live state is what the radio does. The web UI shows nvram (through the `wl_` working copy). A change is confirmed when the live layer shows it. [platform.md § Configuration model](references/platform.md#configuration-model) has the full model.

## Making a change

1. Read every key about to be written, and record the values; together they are the restore command.
2. `nvram set k=v` for each key, then `nvram commit`.
3. Ask the user for approval of the restart, naming the action and what it drops (from [platform.md § Apply actions](references/platform.md#apply-actions)), and wait for an explicit yes in their reply to that question. Every `service` action and every `reboot` takes this approval, each time, including when the user earlier approved the setting itself or said to do whatever is best; an approval covers the one restart it was given for.
4. Run the approved action (`service <action>`, the one the web UI page for that setting runs on Apply).
5. Read back the same keys, the generated driver config line they feed, and the live state they control.

Completion: each written key reads its new value, the driver config and live state agree with it, `uptime` matches the restart that was run, and the old values are reported to the user as the restore command.

## Reference files

Read the file whose branch the task is on:

- [platform.md](references/platform.md) — identity, interfaces, nvram and the `wl_` working copy, rc and `service` actions, which action each UI page runs, files and persistence, firmware, reset and rescue, SSH.
- [wireless.md](references/wireless.md) — every Wireless › General / Professional / MAC filter / Smart Connect key: values, UI labels, the driver parameter each feeds; security modes and PMF; guest networks.
- [regulatory.md](references/regulatory.md) — channel numbering and groupings for 2.4/5/6 GHz, DFS timings, per-country rules (Israel, EU, UK, US), how the router derives its region and channel list, how clients choose their country.
- [diagnostics.md](references/diagnostics.md) — logs and boot markers, crash evidence, connected-client table, radio statistics, CPU/memory/conntrack, hardware NAT, temperature.
- [wan-lan.md](references/wan-lan.md) — WAN and PPPoE, DNS and dnsmasq, IPv6, UPnP, QoS and its effect on hardware NAT, LAN/DHCP, firewall and port forwarding formats.
- [macos.md](references/macos.md) — Mac-side measurement: Wi‑Fi link fields, scans, latency and throughput tools, private Wi‑Fi address, AWDL, Apple's router guidance and device capability tables.
