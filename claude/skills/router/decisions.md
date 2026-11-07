# Router setup

How this home's ASUS RT-BE90U is set up, in the order to apply it on a fresh or reset unit. Each step gives the setting, the nvram keys, the apply action, and one line of why. How each setting works is in the [skill](SKILL.md) and its references; what this file may carry is [SKILL.md § Making a change](SKILL.md#making-a-change) step 5.

## Factory baseline

Firmware 3.0.0.6.102_58500, read right after Quick Internet Setup (PPPoE login, Wi‑Fi name and password).

```
AREA         KEY                   FACTORY VALUE
----------   -------------------   ------------------------------------
WAN          wan0_proto            pppoe
WAN DNS      wan0_dnsenable_x      1 (ISP resolvers)
DoT          dnspriv_enable        0
DHCP         dhcp_start / end      the whole subnet
DHCP         dhcp_static_x         0
UPnP         wan0_upnp_enable      0
SSH          sshd_enable           0
WPS          wps_enable            1
Web UI       http_enable           2 (HTTP + HTTPS)
Samba        enable_samba          1
Wi‑Fi        smart_connect_x       1 (one name on 2.4/5/6 GHz)
Wi‑Fi        acs_dfs               1
Wi‑Fi        wl0_bw                1 (2.4 GHz auto 20/40)
Wi‑Fi        wl2_ofdma             1 (6 GHz download only)
Region       wlN_country_code      GB (territory EU/01)
IPv6         ipv6_service          disabled
```

## Steps

1. **SSH, LAN only, keys only.** Administration › System: `sshd_enable=2`, `sshd_pass=0`, your public key in `sshd_authkeys`. Action `restart_time`. Lets Claude do the rest.
2. **WAN DNS → AdGuard.** `wan0_dnsenable_x=0`, `wan0_dns1_x=94.140.14.14`, `wan0_dns2_x=94.140.15.15`. Blocks ads and trackers on every device.
3. **DNS-over-TLS, Opportunistic.** `dnspriv_enable=1`, `dnspriv_profile=0`, AdGuard in `dnspriv_rulelist`. Action `"restart_wan_if 0;restart_stubby"` (re-dials PPPoE, ~20 s). The ISP can't read lookups; Opportunistic falls back to plain DNS instead of failing.
4. **Smaller DHCP pool, a fixed address per device.** Raise `dhcp_start` to leave room below the pool, set `dhcp_static_x=1`, and reserve one address below the pool for each device. Action `restart_dnsmasq`. Take each MAC from the client list once the device has joined. The DHCP name takes hyphens, the app name (`custom_clientlist`) takes spaces:

   ```
   DEVICE                     NOTE
   ------------------------   ----------------------------------
   Mac-Wired
   Mac-WiFi
   ThinkPad
   iPhone-15                  Private Wi‑Fi Address: Fixed
   Poco-X3-Pro                device MAC, not randomized
   Samsung-TV
   Yamaha-YAS209-Soundbar
   Switcher-Breeze
   Switcher-Long-V4
   Xiaomi-MOVA-L600-Vacuum
   ```
5. **UPnP on, secure mode.** `wan0_upnp_enable=1`, `upnp_enable=1`, `upnp_secure=1`, `upnp_mnp=1`. Action `"restart_upnp;restart_firewall"`. Transmission opens its own port, so nothing needs a manual forward.
6. **Band plan: main network on 5 + 6 GHz, IoT network on 2.4 GHz.** On the Network page, set the main network to 5 + 6 GHz. Then add an IoT network on 2.4 GHz only, WPA2-Personal, same password, same subnet, not isolated. Re-pair the 2.4 GHz-only devices to it: the Switchers, the vacuum and the soundbar. This keeps the Samsung TV off 2.4 GHz, and the shared subnet keeps Spotify Connect, AirPlay and MusicCast working. Over SSH, the steps are in [wireless.md § Guest Network Pro](references/wireless.md#guest-network-pro).
7. **Main network WPA3 only.** Every band code of the main network's `apm1_security` carries `sae` (2.4/5 GHz codes `3`, `13`; 6 GHz codes `16`, `96`), which makes PMF required (`wl1.1_mfp=2`). Quick Internet Setup writes `psk2sae` for `3` and `13` ([wireless.md § General](references/wireless.md#general)); rewrite those two in place: `nvram set apm1_security="$(nvram get apm1_security | sed -e 's/<3>psk2sae>/<3>sae>/' -e 's/<13>psk2sae>/<13>sae>/')"`, then `rc sync_apgx_to_wlunit`. Action `"restart_wireless;restart_sdn 1"`. A device without WPA3 can't join the main network; the Samsung TV (5 GHz) and the Mac (6 GHz) join on SAE (2026-11-06). The IoT network stays WPA2 (step 6).
8. **5 GHz auto-channel off DFS.** `acs_dfs=0`. Action `restart_wireless` (drops Wi‑Fi ~40 s). Keeps 5 GHz on 36–48, so a radar hit can't cut a stream.
9. **2.4 GHz at 20 MHz.** `wl0_bw=0`. Action `restart_wireless`. Apple's guidance; fewer collisions.
10. **6 GHz OFDMA both directions.** `wl2_ofdma=3`. Action `restart_wireless`.
11. **5 GHz group key every 10 minutes.** `wl1_wpa_gtk_rekey=600`. Action `restart_wireless`. When the Mac joins 5 GHz and moves to 6 GHz, the router keeps a dead 5 GHz entry for it until the next group-key change, and 5 GHz devices (the TV, the phones) can't reach the Mac while it lasts; 600 caps that at 10 minutes.
12. **WPS off.** `wps_enable_x=0`, `wps_enable=0`. Action `restart_wpsie`.
13. **Router Samba off.** `enable_samba=0`. Action `restart_ftpsamba`. No USB drive.
14. **Web UI HTTPS only.** `http_enable=1`. Action `restart_httpd`. UI at `https://<router>:8443`.
15. **Every device's DNS goes through the router.** Field 9 of each `sdn_rl` entry = `11`, `dnsfilter_enable_x=1`, `dnsfilter_mode=11` ([wan-lan.md § Parental controls](references/wan-lan.md#parental-controls)). Action `restart_firewall`. A device with a hard-coded resolver such as 8.8.8.8 still gets AdGuard's answers, and the URL filter's drops (step 16). Proof: `dig tracking.miui.com @8.8.8.8` from a LAN client returns `0.0.0.0`.
16. **Block Samsung TV telemetry.** Firewall › URL Filter: `url_enable_x=1`, `url_mode_x=0`, `url_rulelist` = one `<1>ALL>host` row per Samsung host in the default tier of [Okazakee/tv-dns-blocklist](https://github.com/Okazakee/tv-dns-blocklist) `pihole/block.txt`, minus `infolink.pavv.co.kr` and `tvx.adgrx.com`, which their parents cover (44 rows). Write it with `ssh router 'nvram set url_rulelist="$(cat)"' < rows.txt`, since several hosts exceed the page's 32-character field. Action `restart_firewall`. The upstream DNS blocks none of these hosts, so the filter is the TV's only DNS block; [wan-lan.md § Samsung TV hosts](references/wan-lan.md#samsung-tv-hosts) lists what must stay open.
17. **Block Xiaomi phone and vacuum telemetry.** The same `url_rulelist` gets 18 more rows after step 16's: `sys.intl.xiaomi.com`, `api.collect.data.intl.miui.com`, `ad.mi.com`, `ad.xiaomi.com`, `ad.intl.xiaomi.com`, `tracking.intl.miui.com`, `mistat.intl.xiaomi.com`, `adv.sec.intl.miui.com`, `mistat.xiaomi.com`, `tracking.miui.com`, `adv.sec.miui.com`, `data.sec.intl.miui.com`, `feedback.intl.miui.com`, `a.union.mi.com`, `e.mi.com`, `tracking.eu.miui.com`, `collect.dreame.com`, `ad.dreame.com`. Action `restart_firewall`. The Poco-X3-Pro and the Xiaomi-MOVA-L600-Vacuum (a Mi Home device on the `sg` region) keep working only while `*.io.mi.com`, `fds.api.xiaomi.com`, `mi-img.com`, `home.mi.com`, `account.xiaomi.com`, `update(.intl).miui.com`, `connect.rom.miui.com`, `sdkconfig(.intl).xiaomi.com` and `xmpush` / `msg.global.xiaomi.*` resolve, so no row is a parent of those; whole public Xiaomi lists (HaGeZi native.xiaomi, 1Hosts Xtra) block some of them. `sys.intl.xiaomi.com` (MIUI cloud control) is the row to drop first if a MIUI feature misbehaves.
18. **Back up the settings.** `ssh router 'nvram save /tmp/settings.CFG && cat /tmp/settings.CFG' > ~/Settings_RT-BE90U_<date>.CFG` (scp fails: no sftp-server). The file holds passwords, so it never goes in git.

## Kept at factory

Country GB (its 5 GHz table matches Israel's), transmit power 100, roaming assistant off, IPv6 off (slower than IPv4 on this ISP, and nothing needs it), firmware auto-update, remote WAN access off, WAN ping off, firewall on, DoS protection off, DNS rebind off, DNSSEC off, QoS off, AiProtection off, MLO off, 320 MHz auto, PSC on, beamforming, MU-MIMO, frame bursting, airtime fairness and TWT as shipped.

## Outside the router

- **Mac:** Transmission upload cap 11000 KB/s, about 85% of the 104 Mb/s uplink, so seeding doesn't lag the other devices. `mac/defaults.sh` applies it.

## Restore to factory

```
DNS + DoT:     ssh router 'nvram set wan0_dnsenable_x=1; nvram set wan0_dns1_x=; nvram set wan0_dns2_x=; nvram set wan_dnsenable_x=1; nvram set wan_dns1_x=; nvram set wan_dns2_x=; nvram set dnspriv_enable=0; nvram set dnspriv_profile=1; nvram set dnspriv_rulelist=; nvram commit; service "restart_wan_if 0;restart_stubby"'
DHCP:          ssh router 'nvram set dhcp_start=$(nvram get lan_ipaddr | sed "s/\.1$/.2/"); nvram set dhcp_static_x=0; nvram set dhcp_staticlist=; nvram commit; service restart_dnsmasq'
UPnP:          ssh router 'nvram set wan0_upnp_enable=0; nvram set upnp_enable=0; nvram commit; service "restart_upnp;restart_firewall"'
Band plan:     ssh router 'nvram set apm1_dut_list="<*>87>"; nvram set "sdn_rl=$(nvram get sdn_rl | sed "s/<3>IoT>[^<]*//")"; nvram set apg1_enable=0; nvram commit; rc sync_apgx_to_wlunit; service "restart_wireless;restart_sdn"'
Wi‑Fi sec.:    ssh router 'nvram set apm1_security="$(nvram get apm1_security | sed -e "s/<3>sae>/<3>psk2sae>/" -e "s/<13>sae>/<13>psk2sae>/")"; nvram commit; rc sync_apgx_to_wlunit; service "restart_wireless;restart_sdn 1"'
DFS:           ssh router 'nvram set acs_dfs=1; nvram commit; service restart_wireless'
2.4 GHz width: ssh router 'nvram set wl0_bw=1; nvram commit; service restart_wireless'
6 GHz OFDMA:   ssh router 'nvram set wl2_ofdma=1; nvram commit; service restart_wireless'
5 GHz rekey:   ssh router 'nvram set wl1_wpa_gtk_rekey=3600; nvram commit; service restart_wireless'
WPS:           ssh router 'nvram set wps_enable_x=1; nvram set wps_enable=1; nvram commit; service restart_wpsie'
Samba:         ssh router 'nvram set enable_samba=1; nvram commit; service restart_ftpsamba'
Web UI:        ssh router 'nvram set http_enable=2; nvram commit; service restart_httpd'
DNS redirect:  ssh router 'nvram set "sdn_rl=$(nvram get sdn_rl | awk "BEGIN{RS=\"<\";ORS=\"\"} NF{sub(/\n$/,\"\"); n=split(\$0,f,\">\"); f[9]=0; s=f[1]; for(i=2;i<=n;i++) s=s\">\"f[i]; print \"<\"s}")"; nvram set dnsfilter_enable_x=0; nvram set dnsfilter_mode=0; nvram commit; service restart_firewall'
URL filter:    ssh router 'nvram set url_enable_x=0; nvram set url_rulelist=; nvram commit; service restart_firewall'
SSH:           Administration › System › Enable SSH: No
```
