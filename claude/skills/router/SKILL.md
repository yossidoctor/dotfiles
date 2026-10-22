---
name: router
description: Home router (ASUS RT-BE90U) — read, change and verify any setting over SSH; diagnose slow or dropping Wi‑Fi or internet; set up a fresh or reset unit, or undo a past change. Fires on "router", "Wi‑Fi", "SSID", "Wi‑Fi channel", "DFS", "MLO", "AiMesh", "nvram", "port forward", "PPPoE", "DHCP reservation", "QoS", "Wi‑Fi from the Mac".
---

# router

Documentation for the ASUS RT-BE90U (build target TUF-BE9400) running stock ASUSWRT on a Qualcomm IPQ5332 with three radios (2.4, 5, 6 GHz), and for measuring Wi‑Fi from a Mac. It says how each setting works and how to read, change and verify it. It carries no preferred values: where a value is contestable, [tradeoffs.md](references/tradeoffs.md) gives the conditions under which each value wins, and the choice belongs to the user. A fact marked *(unit)* was read on this unit's shell at firmware 3.0.0.6.102_58500; after a firmware change, re-read it with the command beside it.

## Reaching the router

Access is `ssh router '<commands>'`. Host alias, address, admin user and key live in `~/.ssh/config` under `Host router`; `ssh -G router | grep -E '^(hostname|user|identityfile) '` prints them. The router side is [platform.md § SSH](references/platform.md#ssh).

The router runs BusyBox: no `id`, `ping` takes `-c`/`-W`/`-w`; `nvram get` reads one key per call, so several keys are read with a loop: `for k in a b c; do echo "$k=$(nvram get $k)"; done`. Wi‑Fi tools are Qualcomm's: `iw dev`, `iwconfig athN`, `wlanconfig athN list sta`, `cfg80211tool <if> g<param>`; there is no `wl`.

`nvram show`, the hostapd configs under `/etc/Wireless/conf/` and `/tmp/ppp/options*` hold credentials (PSKs, the PPPoE login, VPN keys). *Redact* them: list key names with `cut -d= -f1`, and read values through `grep -viE 'psk|pass|key|secret|token|pin|phrase|priv|user|name'`. A credential printed lands in the transcript.

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

1. **Record the restore values.** Read every key the change will write. Done when each of those keys has its current value recorded; together they are the restore command.
2. **Name the restart.** Take the apply sequence from the setting's section: usually one `service <action>`, and any extra step the section names (an applet, a second key) belongs to the sequence. Tell the user the action and what it drops (the DROPS column of [platform.md § Apply actions](references/platform.md#apply-actions)). A restart cuts whatever the household is using at that moment (a call, a stream on the TV box, the Mac's own link), and only the user knows whether now is the time, so every restart waits for the user's explicit yes in reply to the question that named it; one yes covers the one restart it was given for, even after an earlier "do whatever is best". Done when the user has said yes to this restart.
3. **Apply in one background call.** Write, commit, apply, wait and read back as one Bash call with `run_in_background: true`, built from the template in [references/change.md](references/change.md). An action that restarts the radios, the network, sshd or the router drops the SSH session or the Mac's Wi‑Fi link, so the call's exit notification is the signal that the router is back. Done when the call has exited.
4. **Verify.** Done when each written key reads its new value, the generated config and live state agree with it, the restart marker is newer than the call ([change.md § Markers](references/change.md#markers)), and the old values are reported to the user as the restore command.
5. **Record it.** [decisions.md](decisions.md) is a replay recipe for this unit: it records only settings a change wrote, each as a step (keys, action, one-line why) plus its line in § Restore to factory. The file is public: a device appears by its DHCP name, a network by its role (main, IoT), and a password, a MAC address or a public IP not at all. Done when decisions.md holds the step and its restore line.

Setting up a fresh or reset unit, or undoing a past change → [decisions.md](decisions.md) (steps in order; § Restore to factory).

## Reference files

Read the file whose branch the task is on:

- **Platform** — [platform.md](references/platform.md): identity, hardware, every interface, nvram and unit prefixes, how Apply lands, `service` actions and what each drops, persistence, firmware, reset and rescue, SSH, Administration, USB applications.
- **Wireless** — [wireless.md](references/wireless.md): radios, VAPs and where the SSID is stored; General, Professional, MLO, Smart Connect, Guest Network Pro, MAC filter, WPS, roaming, WDS/proxy/RADIUS, AiMesh.
- **WAN/LAN** — [wan-lan.md](references/wan-lan.md): LAN, DHCP, routes, IPTV, switch, WAN and PPPoE, dual WAN, port forwarding, DDNS, NAT passthrough, UPnP, IPv6, VPN server and Fusion, firewall, AiProtection, parental controls, QoS, traffic analyzer.
- **Regulatory** — [regulatory.md](references/regulatory.md): channel numbering, the channels this unit lists and the rule behind each, how it derives its region, DFS, Israel and other regions, 6 GHz security and power, how clients choose their country.
- **Diagnostics** — [diagnostics.md](references/diagnostics.md): logs and boot markers, client table, radio statistics, CPU/memory/conntrack, hardware acceleration, temperature, network tools.
- **Trade-offs** — [tradeoffs.md](references/tradeoffs.md): per contestable setting, what each value costs and the conditions under which it wins.
- **macOS tools** — [macos.md](references/macos.md): Mac-side link fields, scans, latency and throughput tools, private Wi‑Fi address, AWDL, Apple's router recommendations.

To identify any key not covered by name: `grep -l '<key>' /www/*.asp` finds its page, the page's `<th>` text and `<option>`s give its label and values (`<#N#>` labels decode per [platform.md § Configuration model](references/platform.md#configuration-model)), and each reference section ends with the `nvram show | cut -d= -f1 | grep -xE` filter that lists the keys it owns.
