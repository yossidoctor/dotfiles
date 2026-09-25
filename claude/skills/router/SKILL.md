---
name: router
description: Diagnose and change the home ASUS router (ASUSWRT) from its shell — fires on "router", "Wi‑Fi slow / unstable / dropping", "port closed / port forward", "devices on my network are slow", "torrent port", "channel", "DFS", "Smart Connect". Reads the Mac side first, then the router's nvram and kernel log, and writes settings through nvram with a verified read-back. NOT for the ISP line itself or for VPN clients.
---

# router

The router's web UI is a **view** over `nvram`; the shell is the truth. A UI toggle can commit nothing, an "Apply" can skip the reboot it implies, and a channel the UI shows can be one the radio left an hour ago. Every verdict here comes from a value read this session, on the Mac or over SSH.

## 1 · Reach the shell

Setup once per machine, and the skill assumes it holds:

```
KEY        ~/.ssh/router            ssh-keygen -q -t ed25519 -N "" -C router -f ~/.ssh/router
HOST       ~/.ssh/config            Host router / HostName <gateway> / User <admin user> / IdentityFile ~/.ssh/router
ROUTER     Administration › System  Enable SSH: LAN Only · Authorized Keys: contents of ~/.ssh/router.pub
```

`<gateway>` is `route -n get default | awk '/gateway/{print $2}'` at setup time; `~/.ssh/config` is the one place the admin user and that address are written, and this skill writes neither.

Every call is `ssh router '<commands>'`. A command that restarts the radios (`service restart_wireless`, `reboot`) kills the session mid-output; that is expected, and the result is read with a fresh `ssh` afterwards. When the permission classifier refuses a remote write, hand the exact `ssh router '…'` line to the user to run with the `!` prefix, since it lands in the transcript either way.

Completion: `ssh router uptime` returns a line.

## 2 · Read the Mac side first

Half of "the router is slow" is the client. In one Bash call:

```
system_profiler SPAirPortDataType | sed -n '/Current Network Information/,/Other Local/p' | grep -E 'PHY|Channel|Signal|Transmit Rate|MCS'
ipconfig getifaddr en0; ifconfig en0 | awk '/ether/{print $2}'; networksetup -listallhardwareports | grep -A2 'Wi-Fi' | grep Ethernet
ping -c 10 -i 0.2 $(route -n get default | awk '/gateway/{print $2}') | tail -1; ping -c 10 -i 0.2 1.1.1.1 | tail -1
ifconfig en0 | grep inet6 | grep -v fe80
```

What each line decides:

- **Signal / MCS / rate**: below -67 dBm or MCS under 5 is distance, not the router. Every knob after this is second-order.
- **Two MACs that differ**: the `ifconfig` MAC is what the router sees; the `networksetup` one is hardware. A mismatch means Private Wi‑Fi Address is on, so a DHCP reservation keyed to the hardware MAC never matches and the Mac lands on a random lease. Fix on the Mac: System Settings › Wi‑Fi › ⓘ › Private Wi‑Fi address › Off.
- **Gateway ping jitter with a calm WAN ping**: airtime contention on the Wi‑Fi hop. A calm gateway with a jittery WAN is the line or bufferbloat.
- **A global inet6 that works** (`curl -6 https://api64.ipify.org`) means IPv6 is fine; Safari hanging on some sites with one present is IPv6 that is up but unrouted.

Completion: link quality, MAC identity, and where the latency lives are each written down before any router call.

## 3 · Read the router

One call, whole picture:

```
ssh router '
uptime; grep -c ^processor /proc/cpuinfo; top -bn1 | sed -n 2,3p
cat /proc/sys/net/netfilter/nf_conntrack_count /proc/sys/net/netfilter/nf_conntrack_max
for k in smart_connect_x wl0_ssid wl1_ssid wl0_channel wl1_channel wl1_nctrlsb acs_dfs wl0_mfp wl1_mfp \
         wl1_country_code wan0_upnp_enable buildno extendno; do echo "$k=$(nvram get $k)"; done
for i in 0.1 0.2 0.3 1.1 1.2 1.3; do echo "wl$i bss=$(nvram get wl${i}_bss_enabled)"; done
dmesg | grep -ciE "CAC .* start"; dmesg | grep -c NOT_ROBUST; dmesg | grep -iE "radar|deauth|kick" | tail -5
cat /tmp/clientlist.json'
```

How to read it, in the order that finds root causes fastest:

- **`uptime`** is the only proof a reboot happened. A user who "restarted the router" and an uptime of days did not.
- **`wl1_channel=0`** is Auto on 5 GHz. With `acs_dfs=1` the radio can land on any DFS channel its region list allows, and each landing runs a **CAC**: `[DfsCacNormalStart] CAC 65 seconds start . Disable MAC TX` in `dmesg`. The whole 5 GHz network is silent for that minute, every device drops, and it recurs on every hop. This is the outage that looks like "slow Wi‑Fi".
- **`smart_connect_x=1`** forces `wl1_channel=0` regardless of what the UI shows, and its band steering (`roamast`) pushes phones to 2.4 GHz. Turning it off keeps one SSID as long as `wl0_ssid` and `wl1_ssid` already match.
- **`NOT_ROBUST_UNICAST_FRAME` spam** with `wl*_mfp=1` (Protected Management Frames "Capable") is the MediaTek driver fighting Apple clients; hundreds of lines mean drops. `mfp=0` ends it.
- **`nf_conntrack_count`** near `max`, or `top` idle under 30%, is a saturated router; a torrent client with an open port and hundreds of peers is the usual writer. Below a few thousand entries the router is not the bottleneck.
- **`wan0_upnp_enable`** is the live UPnP flag; the bare `upnp_enable` key is legacy and reads 0 either way.
- **`wl*_bss_enabled`** for `.1 .2 .3` are guest networks; each enabled one is a second beacon on the same radio.
- **`clientlist.json`** groups clients by band with RSSI, so a "slow phone" is placed on 2.4 or 5 GHz with its signal in one read.

Completion: one named root cause with the `dmesg` line or nvram value that proves it, or "router is clean" with the values that say so.

## 4 · Change with read-back

Writes are `nvram set k=v` … `nvram commit`, then the restart the change needs, then a fresh read of the same keys. Anything less is an unverified claim.

```
CHANGE                            KEYS                                        THEN
-------------------------------   -----------------------------------------   ------------------------
fixed non-DFS 5 GHz channel       wl1_channel=36  wl1_nctrlsb=lower           service restart_wireless
                                  acs_dfs=0
Smart Connect off                 smart_connect_x=0                           reboot
PMF off (Apple drop fix)          wl0_mfp=0  wl1_mfp=0                        service restart_wireless
2.4 GHz channel                   wl0_channel=1|6|11                          service restart_wireless
firmware check                    /usr/sbin/webs_update.sh; sleep 8;          none
                                  nvram get webs_state_info  (latest build;
                                  `nvram get` reads one key per call)
```

The channel choice is a scan, not a memory: `system_profiler SPAirPortDataType | sed -n '/Other Local/,$p' | grep 'Channel:' | sort | uniq -c | sort -rn`. Neighbours on Auto migrate, so a fixed channel is re-checked when phones slow down again, and it stays non-DFS: congestion costs throughput, a CAC costs the network. The legal list is the router's, not the country's: `wl1_country_code` names the region it enforces, and the Control Channel dropdown in Wireless › General is the live list for that region, since the MediaTek driver exposes none over the shell. 36–48 is the non-DFS block in every region; 2.4 GHz is 1, 6 or 11 and nothing between.

Firmware flashes from the web UI only (Administration › Firmware Upgrade). The router's own shell upgrader over an SSH session that drops mid-write is a bricked router.

Port forwards and DHCP reservations stay in the UI (WAN › Virtual Server, LAN › DHCP Server): their nvram encoding is a packed list that is easy to corrupt by hand. A forward is verified from the outside, not from the rule: `curl -s https://portcheck.transmissionbt.com/<port>` returns `1` open, `0` closed, and only while something on the Mac listens on that port.

Completion: every changed key read back with its new value, `uptime` consistent with the restart performed, and the Mac-side read from § 2 repeated and improved.

## 5 · Leave it clean

Router changes are per-device state and live nowhere but the router, so the final message lists each key with old and new value; that message is the only record. The SSH key and host entry persist for the next run. A user who wants SSH off again turns it off in Administration › System; the key in `~/.ssh` is harmless without it.
