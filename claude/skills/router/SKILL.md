---
name: router
description: Reference for the home router (ASUS RT-BE90U, stock ASUSWRT on Qualcomm IPQ5332, Wi‑Fi 7) — reading, tracing, changing and verifying any setting over SSH, nvram keys, Wi‑Fi channels, MLO, AiMesh, port forwarding, DFS and regulatory rules, logs and diagnostics, trade-offs between setting values, and the macOS tools that measure the link. Fires on "router", "Wi‑Fi", "channel", "nvram", "port forward", "DFS", "MLO", "AiMesh", "SSID", "PPPoE", "QoS".
---

# router

Documentation for the ASUS RT-BE90U (build target TUF-BE9400) running stock ASUSWRT on a Qualcomm IPQ5332 with three radios (2.4, 5, 6 GHz), and for measuring Wi‑Fi from a Mac. It says how each setting works and how to read, change and verify it. It carries no preferred values: where a value is contestable, [tradeoffs.md](references/tradeoffs.md) gives the conditions under which each value wins, and the choice belongs to the user.

## Reaching the router

Access is `ssh router '<commands>'`. Host alias, address, admin user and key live in `~/.ssh/config` under `Host router`; `ssh -G router | grep -E '^(hostname|user|identityfile) '` prints them. The router side is [platform.md § SSH](references/platform.md#ssh).

The router runs BusyBox: no `id`, `ping` takes `-c`/`-W`/`-w`; `nvram get` reads one key per call, so several keys are read with a loop: `for k in a b c; do echo "$k=$(nvram get $k)"; done`. Wi‑Fi tools are Qualcomm's: `iw dev`, `iwconfig athN`, `wlanconfig athN list sta`, `cfg80211tool <if> g<param>`; there is no `wl`. `nvram show`, the hostapd configs and `/tmp/ppp` hold credentials, so read them filtered ([platform.md § Configuration model](references/platform.md#configuration-model)).

## How the router holds state

Three layers hold the same setting, and they can disagree:

```
LAYER                         READ WITH                                     WRITTEN BY
---------------------------   -------------------------------------------   ------------------------------
nvram (persistent config)     nvram get <key>                               web UI Apply, nvram set + commit
generated config (RAM)        /etc/Wireless/conf/hostapd_<vap>.conf,        rc, at each service restart
                              /etc/Wireless/sh/prewifi_*.sh, /tmp/*.conf,
                              /etc/dnsmasq.conf, iptables
live state                    iw dev, cfg80211tool, wlanconfig, ip,         drivers and daemons, at runtime
                              iptables -S, /proc
```

A value in nvram is a request; the generated config is what rc derived from it; the live state is what the router does. A change is confirmed when the live layer shows it. Which nvram key a UI field writes, and the unit prefixes (`wl0_`, `wl0.1_`, `2g1_`), are in [platform.md § Configuration model](references/platform.md#configuration-model).

## Making a change

1. Read every key about to be written and record the values; together they are the restore command.
2. `nvram set k=v` for each key, then `nvram commit`.
3. Ask the user to approve the restart, naming the action and what it drops ([platform.md § Apply actions](references/platform.md#apply-actions)), and wait for an explicit yes in their reply to that question. Every `service` action and every `reboot` takes this approval, each time, including when the user earlier approved the setting itself or said to do whatever is best; an approval covers the one restart it was given for.
4. Run the action the setting's section names (`service <action>`), the one the web UI page runs on Apply.
5. Read back the keys, the generated config they feed, and the live state they control.

An action that restarts the radios, the network, sshd or the router drops the SSH session or the Mac's Wi‑Fi link (which one, per action: the DROPS column of [platform.md § Apply actions](references/platform.md#apply-actions)). The write, the restart, the wait loop and the read-back therefore run as one Bash call with `run_in_background: true`, whose exit notification is the signal that the router is back; the wait loop and the markers that mean each part is up are in [diagnostics.md § Restart safety](references/diagnostics.md#restart-safety). The hook `~/.claude/hooks/enforce-foreground-polling.sh` refuses foreground sleep loops.

Completion: each written key reads its new value, the generated config and live state agree with it, `uptime` matches the restart that was run, and the old values are reported to the user as the restore command and appended as a decision row (factory value, chosen value, reason, restore command) to `~/.config/router/decisions.md`, the user's local log of every choice made on this unit, which also holds the factory baseline.

## Reference files

Read the file whose branch the task is on:

- **Platform** — [platform.md](references/platform.md): identity, hardware, every interface, nvram and unit prefixes, how Apply lands, `service` actions and what each drops, persistence, firmware, reset and rescue, SSH, Administration, USB applications.
- **Wireless** — [wireless.md](references/wireless.md): radios, VAPs and where the SSID is stored; General, Professional, MLO, Smart Connect, Guest Network Pro, MAC filter, WPS, roaming, WDS/proxy/RADIUS, AiMesh.
- **WAN/LAN** — [wan-lan.md](references/wan-lan.md): LAN, DHCP, routes, IPTV, switch, WAN and PPPoE, dual WAN, port forwarding, DDNS, NAT passthrough, UPnP, IPv6, VPN server and Fusion, firewall, AiProtection, parental controls, QoS, traffic analyzer.
- **Regulatory** — [regulatory.md](references/regulatory.md): channel numbering, the channels this unit lists and the rule behind each, how it derives its region, DFS, Israel and other regions, 6 GHz security and power, how clients choose their country.
- **Diagnostics** — [diagnostics.md](references/diagnostics.md): logs and boot markers, client table, radio statistics, CPU/memory/conntrack, hardware acceleration, temperature, restart safety, network tools.
- **Trade-offs** — [tradeoffs.md](references/tradeoffs.md): per contestable setting, what each value costs and the conditions under which it wins.
- **macOS tools** — [macos.md](references/macos.md): Mac-side link fields, scans, latency and throughput tools, private Wi‑Fi address, AWDL, Apple's router recommendations.

To identify any key not covered by name: `grep -l '<key>' /www/*.asp` finds its page, the page's `<th>` text and `<option>`s give its label and values (`<#N#>` is line N+1 of `/www/EN.dict`), and each reference section ends with the `nvram show | cut -d= -f1 | grep -xE` filter that lists the keys it owns.
