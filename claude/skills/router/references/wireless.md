# Wireless

Every Wi‑Fi setting on the RT-BE90U: radios and VAPs, the per-page settings, MLO, Smart Connect, Guest Network Pro (SDN), MAC filter, WPS, roaming, WDS/RADIUS, AiMesh, and the hidden per-radio keys. Facts marked *(read on RT-BE90U 3.0.0.6.102_58500)* come from that unit's shell, its `/www` pages and the files rc generates; page option values resolve through `/www/EN.dict` (`<#N#>` = line N+1); help text is `helpcontent[a][b]` in `/www/help_content.js`, shown by `openHint(a,b)`. Unit prefixes (`wlX_`, `wlX.Y_`, the UI's `2g1_/5g1/6g1_`) and the `wl_` working copy are explained in [platform.md § Configuration model](platform.md#configuration-model); what each `service` action restarts is [platform.md § Apply actions](platform.md#apply-actions). Channel lists, country, DFS and Auto-channel inclusion flags (`acs_*`, `*_country_code`, `*_80211h`, `wl_precacen`) are in [regulatory.md](regulatory.md#how-the-router-derives-its-region); client tables and radio counters in [diagnostics.md § Clients](diagnostics.md#clients) and [§ Radio](diagnostics.md#radio).

The radio stack is Qualcomm qcawifi: rc writes `/etc/Wireless/sh/prewifi_<if>.sh` (radio and VAP mode), `/etc/Wireless/sh/postwifi_<if>.sh` (per-VAP `cfg80211tool` parameters, then `wpa_cli ... ADD bss_config=<if>:/etc/Wireless/conf/hostapd_<if>.conf`), `/tmp/prewifi.sh` and `/tmp/postwifi.sh` (which run them, set `mcast_rate`, start `mcsd` and `lbd`) on each wireless restart; one `hostapd -g /var/run/hostapd/global` serves every BSS *(read on RT-BE90U 3.0.0.6.102_58500)*. These files are RAM and carry the passphrase and WPS PIN, so read them filtered: `grep -viE 'psk|pass|key|secret|pin' <file>`. A driver parameter set with `cfg80211tool <if> <param> <v>` reads back with `cfg80211tool <if> get_<param>` for most parameters (`get_mode`, `get_hide_ssid`, `get_shortgi`, `get_he_ul_ofdma`, `get_he_dl_ofdma`, `get_twt_responder`, `get_implicitbf`, `get_ap_bridge`, `get_rrm`, `get_puren`, `get_protmode`, `get_dtim_period`, `get_bintval`, `get_mcast_rate`, `get_maxsta`, `get_chwidth` answer; `get_mbo`, `get_he_mubfer`, `get_11ngvhtintop` do not).

## Radios, VAPs and SSID storage

```
RADIO   BAND     UNIT  nband  PRIMARY VAP (wlX)            OTHER VAPS
------  -------  ----  -----  ---------------------------  ------------------------------------------------
wifi0   2.4 GHz  wl0   2      ath0  MAINBH, hidden          ath001 = wl0.1 MAINFH (user SSID)
                                                            ath002 = wl0.4 AiMesh onboarding (obvif_cap_subunit=4)
wifi1   5 GHz    wl1   1      ath1  MAINBH, hidden          ath101 = wl1.1 MAINFH
wifi2   6 GHz    wl2   4      ath2  MAINBH, hidden          ath201 = wl2.1 MAINFH
—       MLO      —     —      mld-wifi0 (MLD netdev, down while mld_enable=0)
```

*(read on RT-BE90U 3.0.0.6.102_58500: `nvram get wl_ifnames`, `wlX_nband`, `wlX.Y_ifname`, `wlX_vifs`, `iw dev`.)* `athNMM` is `wlN.M` (`ath001` = `wl0.1`). `wlX_vifnames` lists the seven configurable sub-units `wlX.1`–`wlX.7`; `wlX_vifs` the ones rc created. Per-radio MAC: `wlX_hwaddr`; `band_type`, `restwifi_qis` are rc state flags whose writers are not exposed.

**Why `wl0_ssid` is a 32-hex string.** This firmware runs ASUS's multi-LAN (SDN) model, and its UI support list carries `sdn_mainfh` and `sdn_mwl` (`strings /usr/lib/libwebapi.so | grep -x 'sdn_mainfh\|sdn_mwl'`). `sdn_rl` lists the networks as `<idx>name>enable>vlan_idx>subnet_idx>apg_idx>vpnc_idx>…>createby>…` (field order: `sdn_rl_attr` in `/www/SDN/sdn.js`). Index 0 `DEFAULT` is the LAN bridge, `MAINFH` is the main fronthaul network the user sees, `MAINBH` is the AiMesh backhaul. Each network's SSID and security live in an AP-group profile: `apm<apg_idx>_*` for MAINFH and MAINBH, `apg<apg_idx>_*` for every other profile (`ap_prefix` in `sdn.js`). The MAINFH values appear on the `wlX.1` VAPs and the MAINBH values on the primary `wlX` VAPs: `/tmp/apg_ifnames_used.json` maps `sdn_idx` 1 to `wl0.1`/`wl1.1`/`wl2.1`, `wl0.1_ssid` equals `apm1_ssid`, `wl0_ssid` equals `apm2_ssid` (a generated hex name, `apm2_hide_ssid=1`), and `postwifi_ath0.sh` sets `hide_ssid 1` *(read on RT-BE90U 3.0.0.6.102_58500)*. `wl0.4` is the AiMesh onboarding VAP (`obvif_set=1`, `obvif_cap_subunit=4`, `lanaccess=on`, its own hex SSID).

Read the user SSID from the profile, the unit copy, or the air:

```
idx=$(nvram get sdn_rl | tr '<' '\n' | awk -F'>' '$2=="MAINFH"{print $6}'); nvram get apm${idx}_ssid
nvram get wl0.1_ssid ; iw dev ath001 info | grep ssid
```

`apmN_security` / `apgN_security` is `<band>auth>crypto>passphrase>radius_idx` repeated per band code (`3` = 2.4+5 GHz, `13` = 2.4+5‑1+5‑2, `16` = 6 GHz, `96` = 6‑1+6‑2; bits from `bands_bit_mapping` in `/www/state.js`); it holds the passphrase, so print only fields 1–3: `nvram get apm1_security | tr '<' '\n' | cut -d'>' -f1-3`. Changing the SSID or passphrase means writing `apmN_ssid` / `apmN_security` and running `restart_wireless;restart_sdn <idx>` (the action `SDN.asp` posts) *(unverified on this unit: rc's copy into `wlX.1_*` is inferred from the values agreeing)*.

Keys: `nvram show 2>/dev/null | cut -d= -f1 | grep -xE '(wl[0-9]*(\.[0-9]+)?|2g1|5g1|6g1)_(ifname|vifs|vifnames|nband|nband_type|hwaddr|mode|guest_num|mbss|mssid|unit|subunit)|wl|wifison_ready|restwifi_qis|band_type|wifi_psk'`

## General

Page `Advanced_Wireless_Content.asp` (Wireless › General), built by `system.wlBandSeq` in `/www/js/asus.js`; Apply posts through `httpApi.nvramSet` and runs `restart_wireless`. With `sdn_mainfh` the page hides the fronthaul rows and drops `ssid`, `closed`, `auth_mode_x`, `wpa_psk`, `crypto`, `wpa_gtk_rekey`, `mfp`, `11be` and the Smart Connect keys from its post (the `isSupport("sdn_mainfh")` block in `apply()`), so on this unit it sets bandwidth and channel only; the other values belong to the MAINFH profile ([§ Guest Network Pro](#guest-network-pro)) *(read on RT-BE90U 3.0.0.6.102_58500)*.

```
KEY (per unit)    UI LABEL / VALUES                                          LANDS IN (live check)
----------------  ---------------------------------------------------------  ------------------------------------------
ssid, closed      Network Name; Hide SSID 1/0                                hostapd ssid / cfg80211tool hide_ssid
                                                                             (iw dev athN info; get_hide_ssid)
nmode_x           Wireless Mode: 0 Auto, 1 N only, 2 Legacy, 8 N/AC/AX       with 11be and bw: prewifi mode 11GEHT20 /
                  mixed, 9 AX only (per band subset)                         11AEHT80 / 11AEHT320 (cfg80211tool athN get_mode)
11be              WiFi 7 Mode 1/0 [trade-off](tradeoffs.md#wifi-7-mode)       hostapd ieee80211be; mode string EHT
bw                Channel bandwidth (non-Broadcom table): 1 Auto, 0 20 MHz,  mode suffix, hostapd eht_oper_chwidth/op_class
                  2 40, 3 80, 5 160, 6 320 MHz                               (iw dev athN info: width; get_chwidth)
                  [trade-off](tradeoffs.md#channel-bandwidth)
bw_160            "Enable 160 MHz" checkbox (5 GHz; 0 caps Auto at 80)       wl1 Auto + bw_160=0 → 11AEHT80
bw_320, bw_240    320 MHz enable (6 GHz, not posted by the page, 1 here);    wl2 Auto + bw_320=1 → 11AEHT320
                  240 MHz (Broadcom 5 GHz only, 0 here)
channel           Control Channel: 0 Auto, else channel number               iw dev athN info: channel
nctrlsb           Extension channel: lower/upper (Above/Below); on 6 GHz     —
                  at 320 MHz the 320-1 / 320-2 channel range
chanspec          Broadcom chanspec; unused on this platform (empty)         —
auth_mode_x       open, openowe, owe, shared, psk, psk2, sae, pskpsk2,       hostapd wpa_key_mgmt
                  psk2sae, wpa, wpa2, wpa3, suite-b, wpawpa2, wpa2wpa3,       (psk2sae → WPA-PSK WPA-PSK-SHA256 SAE)
                  radius; 6 GHz offers only sae, owe, wpa3, suite-b
                  [trade-off](tradeoffs.md#authentication-method)
crypto            aes, aes+gcmp256, tkip, tkip+aes, suite-b                  hostapd wpa_pairwise (aes → CCMP;
                  [trade-off](tradeoffs.md#wpa-encryption)                    aes+gcmp256 → CCMP GCMP-256 + SAE-EXT-KEY)
wpa_psk           WPA pre-shared key                                         hostapd (filtered)
wpa_gtk_rekey     Group key rotation interval, s, 0–2592000 (3600 here)      hostapd wpa_group_rekey
mfp               PMF: 0 Disable, 1 Capable, 2 Required; 6 GHz forced 2      hostapd ieee80211w
                  [trade-off](tradeoffs.md#protected-management-frames)
wep_x, key,       WEP 0 off / 1 64-bit / 2 128-bit, key index, keys,         —
key1–4, phrase_x  passphrase generator
```

*(read on RT-BE90U 3.0.0.6.102_58500: option maps `wlModeObject`, `authMethodObj`, `channelBandwidthObject` (`!isBRCMplatform` branch), `wpaEncryptObject`, `mfpObject` in `/www/js/asus.js`; the generated files above.)* On this unit the MAINFH VAPs run `aes` (CCMP only, SAE without SAE-EXT-KEY) while the MAINBH VAPs run `aes+gcmp256`, because `Get_Wizard_MAINFH` in `sdn.js` writes a fixed `psk2sae` (2.4/5 GHz) / `sae` (6 GHz) with `aes` and `mlo=0` into the MAINFH security string. `hostapd` `sae_pwe` is 2 (hunting-and-pecking and hash-to-element) on 2.4/5 GHz and 1 (hash-to-element only) on 6 GHz ([hostapd.conf, hostap_2_11](https://w1.fi/cgit/hostap/tree/hostapd/hostapd.conf?h=hostap_2_11)). Every 5/6 GHz BSS carries `punct_bitmap=0xffff`; upstream hostapd reads that field as a bitmap of punctured 20 MHz subchannels (same source), and no nvram key or UI field sets it, so preamble puncturing is a driver default here; `iw phy` lists the receive capability (`Punctured Preamble RX`). Auto channel picks at radio start; `wlX_channel` stays `0` and the channel in use is read from `iw dev`. `wifitool athN block_acs_channel` lines in `prewifi_athN.sh` are the Auto exclusions ([regulatory.md](regulatory.md#how-the-router-derives-its-region)).

Keys: `nvram show 2>/dev/null | cut -d= -f1 | grep -xE '(wl[0-9]*(\.[0-9]+)?|2g1|5g1|6g1)_(ssid|ssid_org|closed|nmode_x|11be|bw|bw_160|bw_240|bw_320|channel|channel_orig|chanspec|nctrlsb|nctrlsb_old|auth_mode_x|crypto|wpa_psk|wpa_psk_org|wpa_gtk_rekey|mfp|wep_x|key|key[1-4]|key[1-4]_org|key_type|phrase_x|phrase_x_org)'`

## Professional

Page `Advanced_WAdvanced_Content.asp` (Wireless › Professional) edits the `wl_*` working copy for the band in `wl_unit` and runs `restart_wireless`; a changed `ui_location_code` turns the action into `reboot` ([regulatory.md](regulatory.md#how-the-router-derives-its-region)). The QCA branch of its `initial()` hides or disables WMM DLS, Packet Aggregation, AMPDU RTS, ACK ratio and noise mitigation; its `wifi7_support` branch hides Wireless Mode, 802.11ax mode, Bluetooth coexistence, multicast rate, AMPDU, Turbo QAM, both beamforming rows, and MU-MIMO when `hide_mumimo` is supported; with `sdn_mainfh` the `mainBH` rows (AP Isolated, Hide SSID, WiFi 7 Mode) hide too *(read on RT-BE90U 3.0.0.6.102_58500)*. The roaming-assistant row is [§ Roaming](#roaming). Help texts quoted are `helpcontent[3][n]`.

```
KEY              VALUES (UI)                               WHAT IT DOES / WHERE IT LANDS
---------------  ----------------------------------------  -----------------------------------------------------------
radio            1/0 Enable Radio                           radio on/off for the unit
timesched,       scheduler on/off; weekly off-times         powers the radio off on schedule (needs NTP); the page saves
sched_v2         string                                     them via nvramSet with restart_wireless; sched, radio_*_x,
                                                            sched_v2_converted are the older formats
ap_isolate       1/0 Set AP Isolated                        cfg80211tool ap_bridge (1 = clients may talk = not isolated)
bss_maxassoc     1–128 max clients                          unset here; hostapd max_num_sta=255, get_maxsta 128
                                                            (which one it drives is not established)
11ax             1/0 802.11ax mode (hidden on Wi-Fi 7 UI)   ieee80211ax in hostapd
mbo_enable       1/0 WiFi Agile Multiband                   observed 0 → cfg80211tool mbo 0, hostapd mbo=0
                 [trade-off](tradeoffs.md#agile-multiband)
twt              1/0 Target Wake Time                       cfg80211tool twt_responder (get_twt_responder)
                 [trade-off](tradeoffs.md#target-wake-time)
igs              1/0 IGMP Snooping                          multicast snooping; postwifi.sh runs mcsctl/mcsd (/tmp/mcs.conf)
mrate_x          0 Auto, else fixed multicast rate          postwifi.sh: mcast_rate 1000 (2.4) / 6000 (5, 6) kbps on Auto
plcphdr          long / short / auto preamble               observed long → cfg80211tool shpreamble 0
frag, rts        256–2346, 0–2347                           fragmentation / RTS thresholds
dtim, bcn        DTIM 1–255; beacon 100–1000 ms (QCA        hostapd dtim_period; get_bintval
                 Wi-Fi 7 minimum 100)
frameburst       on/off TX bursting                         per band (wl1 off here); cache_frameburst mirrors it
wme, wme_no_ack, auto/on/off; off/on; off/on                hostapd wmm_enabled; WMM No-Ack; APSD
wme_apsd
ofdma            0 off, 1 DL OFDMA, 2 DL/UL OFDMA,          observed: 1 → he_ul_ofdma 0, he_ul_mimo 0, he_mubfer 0;
                 3 DL/UL OFDMA + DL/UL MU-MIMO              2 → he_ul_mimo 0, he_mubfer 0; 3 → none of them
                 [trade-off](tradeoffs.md#ofdma-and-mu-mimo)
mumimo           1/0 Multi-User MIMO                        —
txbf, itxbf      explicit / universal beamforming 1/0       cfg80211tool implicitbf (itxbf)
atf              1/0 Airtime Fairness                       airtime scheduler; atf_mode/atf_ssid/atf_sta hidden
                 [trade-off](tradeoffs.md#airtime-fairness)
txpower          0, 25, 50, 88, 100 (% slider)              Tx power adjustment; iw dev shows txpower dBm per VAP
                 [trade-off](tradeoffs.md#transmit-power)
hwol             1/0 Hardware WiFi Offloading               acceleration path: [diagnostics.md](diagnostics.md#hardware-acceleration)
turbo_qam,       256/1024-QAM, Broadcom interop             hidden on this unit
turbo_qam_brcm_intop
btc_mode,        Bluetooth coexistence, AMPDU RTS, ack      hidden on QCA/Wi-Fi 7 (see above)
ampdu_rts, ampdu_mpdu, ack_ratio, noisemitigation, DLSCapable, PktAggregate, ext_nss, optimizexbox, rateset, gmode_*
mlr_enable       Xtra Range 2.0 (row shown when mlr is supported; absent from nvram here)
traffic_5g       page helper field, not an nvram key on this unit
```

Values per band: `for k in twt mbo_enable ofdma atf txpower frameburst; do echo "$k: $(nvram get wl0_$k) $(nvram get wl1_$k) $(nvram get wl2_$k)"; done`. Help: AP isolation stops Wi‑Fi clients reaching each other; beacon interval "lower… to improve transmission performance in unstable environment or for roaming clients, but it will be power consuming"; WMM No-Ack "more efficient throughput but higher error rates in a noisy RF environment"; explicit beamforming needs client support, universal beamforming serves clients without it *(help_content.js 3_5, 3_12, 3_15, 3_24, 3_25)*.

Keys: `nvram show 2>/dev/null | cut -d= -f1 | grep -xE '(wl[0-9]*(\.[0-9]+)?|2g1|5g1|6g1)_(radio|timesched|sched|sched_v2|sched_v2_converted|radio_date_x|radio_time_x|radio_time2_x|ap_isolate|bss_maxassoc|11ax|mbo_enable|twt|btc_mode|igs|mrate_x|plcphdr|frag|ampdu_rts|rts|dtim|bcn|frameburst|PktAggregate|wme|wme_no_ack|wme_apsd|DLSCapable|noisemitigation|ampdu_mpdu|ack_ratio|turbo_qam|turbo_qam_brcm_intop|atf|mumimo|ofdma|txbf|itxbf|ext_nss|hwol|txpower|TxPower|rateset|rateset_ckb|gmode_check|gmode_protection|gmode_protection_x|optimizexbox|optimizexbox_ckb|HW_switch|amsdu)|_sched_v2|mlr_enable|traffic_5g'`

## MLO

Page `MLO.asp` (Wireless › MLO) frames `/www/SDN/mlo.html` + `mlo.js`; it lists the SDN profiles whose AP-group `mlo` is set and saves with `restart_wireless;restart_sdn <idx>`. A profile's `apgN_mlo` / `apmN_mlo`: `0` off, `1` backhaul MLO (AiMesh links; the MLO page edits only its SSID and hidden flag, and the profile editor offers no apply or delete for it), `2` fronthaul MLO (an MLO client network; the profile editors that carry an MLO switch write `2` and `apgN_11be=1`) (`mlo.js`, `sdn.js` `Update_Setting_Profile`). On this unit `apm2_mlo=1` (MAINBH) and `apm1_mlo=0` (MAINFH), `mld_enable=0`, `mld-wifi0` is down and every VAP reports `mld_addr 00:00:00:00:00:00` in `iw dev`, so no multi-link device is active *(read on RT-BE90U 3.0.0.6.102_58500)* [trade-off](tradeoffs.md#mlo).

```
KEY                     MEANING (as the unit holds it)
---------------------   -------------------------------------------------------------------
mld_enable              1 = MLD active (0 here); mld_ifnames lists its member VAPs
mld_ap_addr, _sdn_addr, MLD MAC addresses for the AP, SDN and station roles
 _sta_addr
mlo_cap_mssid_subunit,  sub-unit for MLO/onboarding VAPs on the router (4) and on a node (5); meaning
                        read from the names, values match obvif_cap_subunit / obvif_re_subunit
 mlo_dwb_mssid_subunit,
 mlo_re_mssid_subunit
mlo_rl, mlo_bh_band     MLO rule list and backhaul band (empty / absent here)
wlX_mlo                 per-unit flag the MLO page reads
```

`/etc/Wireless/ini/mlo_config.ini` groups chips 0 and 1 into one MLO group of up to 256 peers. Live state: `iw dev | grep -E 'Interface|mld_addr'`, `ip link show mld-wifi0`.

Keys: `nvram show 2>/dev/null | cut -d= -f1 | grep -xE '(wl[0-9]*(\.[0-9]+)?|2g1|5g1|6g1)_mlo|mld[0-9]*_.*|mlo_.*'`

## Smart Connect

`smart_connect_x` (0 off, 1 = Smart Connect including 2.4 GHz, 2 = without 2.4 GHz) and `smart_connect_selif_x`, a bitmask of the joined bands (2.4 = 1, 5‑1 = 2, 5‑2 = 4, 6‑1 = 8, 6‑2 = 16; `11` here = 2.4+5+6), as `asus.js`/`mlo.js` `getSelifValue()` define them. With `sdn_mainfh` the UI treats every band as joined and does not post either key (`asus.js` line `object.smartConnectEnable = isSupport("sdn_mainfh") ? "1" …`), so MAINFH is one SSID on all three bands *(read on RT-BE90U 3.0.0.6.102_58500)* [trade-off](tradeoffs.md#smart-connect).

Steering runs in Qualcomm's `lbd` (`lbd -C /tmp/lbd.conf -cfg80211`, restarted by `rc rc_service restart_qca_lbd` from `/tmp/postwifi.sh`), configured over the fronthaul VAPs (`WlanInterfaces=wifi0:ath001,wifi1:ath101,wifi2:ath201`) with per-band RSSI and utilisation thresholds (`[WLANIF2G]`, `[BANDMON] MUOverloadThreshold_W5=100`, …): `grep -vE '^\s*(;|$)' /tmp/lbd.conf`. rc generates the file ("Automatically generated lbd config file" header) and no page exposes its thresholds; the Smart Connect Rule page (`Advanced_Smart_Connect.asp`, Broadcom `bsd_*` / `wlX_bsd_*` keys, Window/Dwell Time fields) is removed from the menu when `Qcawifi_support` (`menuTree.js` exclusion), and `bsd_*` keys are absent from nvram here.

Keys: `nvram show 2>/dev/null | cut -d= -f1 | grep -xE 'smart_connect_.*|bsd_.*|(wl[0-9]*(\.[0-9]+)?)_bsd_.*|enableSmartConbtn|windows_time_sec|dwell_time_sec'`

## Guest Network Pro

Page `SDN.asp` (menu "Network" when `sdn_mwl`, else Guest Network Pro) frames `/www/SDN/sdn.html` + `sdn.js`. Every network, including MAINFH, is an SDN profile: one `sdn_rl` entry tying together a VLAN (`vlan_rl`: `vlan_idx>vid>port_isolation`), a subnet (`subnet_rl`: interface, address, mask, DHCP range/lease, DNS, IPv6, DoT), an AP group (`apgN_*` / `apmN_*`), and optional VPN, DNS filter, URL/network filter, captive portal, firewall and WAN bindings (`sdn_rl_attr`, `vlan_rl_attr`, `subnet_rl_attr`, `apg_rl_attr` in `sdn.js`). Profiles beyond MAINFH/MAINBH are capped by `MaxRule_SDN` − 1 (6 when unset). Saves run `restart_wireless;restart_sdn <idx>` (deletes: `start_sdn_del;restart_wireless;…`) *(read on RT-BE90U 3.0.0.6.102_58500)*. The per-VAP guest keys `wlX.Y_bss_enabled`, `lanaccess`, `expire*`, `bw_*`, `sync_node` hold the state of each VAP; for the VAPs a profile occupies they agree with the profile (the MAINFH copies in § Radios), and rc's copy step is not visible on this unit.

```
AP-GROUP FIELD     MEANING
-----------------  -------------------------------------------------------------------
enable, disabled   profile Wi‑Fi on; disabled=1 when the band has no free VAP
ssid, hide_ssid    SSID and hidden flag
security           <band>auth>crypto>passphrase>radius_idx per band code (§ Radios)
dut_list           <MAC or *>band bitmask> list: which nodes and bands carry it (87, 127 here)
bw_limit           <enable>ul>dl> per-network bandwidth limit
timesched, sched   schedule on/off and string; expiretime = access time limit
ap_isolate         client isolation; macmode/maclist = per-network MAC filter
mlo, 11be          § MLO; iot_max_cmpt = IoT compatibility level
```

`cp_type_rl`, `cpN_profile`, `fbwifi_*` belong to captive portals, which `menuTree.js` removes when `mtlancfg` is supported. Profiles and their VAPs: `nvram get sdn_rl | tr '<' '\n'`, `cat /tmp/apg_ifnames_used.json`, `brctl show`, `ls /tmp/resolv.dnsmasq.sdn*`. Help and profile types: the wizard offers the types `get_sdn_rwd_cap_array` returns ([webapi.c L653](https://github.com/RMerl/asuswrt-merlin.ng/blob/b053ba701af02e46a86d465d82cc2a7891a288a7/release/src/router/libwebapi/webapi.c#L653)).

Keys: `nvram show 2>/dev/null | cut -d= -f1 | grep -xE 'sdn_rl|sdn_rl_x|ap_(lanif|wifi)_rl|max_guest_index|sdn_access_rl|ap[gm][0-9]*_.*|vlan_rl|vlan_rl_x|subnet_rl|subnet_rl_x|mtlan.*|cp|cp_type_rl|fbwifi_.*|ledg_sdn|_(11be|ap_isolate|bw_limit|disabled|dut_list|enable|expiretime|hide_ssid|iot_max_cmpt|local_auth_profile|maclist|macmode|mlo|profile|radius_profile|rl|sched|security|ssid|timesched)|(wl[0-9]*(\.[0-9]+)?)_(bss_enabled|lanaccess|expire|expire_day|expire_hr|expire_min|expire_radio|expiretime|bw_dl|bw_dl_x|bw_ul|bw_ul_x|bw_enabled|sync_node|enable|dut_list|hide_ssid|iot_max_cmpt)'`

## MAC filter

`wlX_macmode`: `allow` (Accept: only listed MACs), `deny` (Reject: listed MACs refused), `disabled`; `wlX_maclist_x` holds the MACs separated by `<` (`helpcontent[18][1]`). Page `Advanced_ACL_Content.asp` (`restart_wireless`) is removed from the menu when `sdn_mwl` is supported, which it is here, so the filter is set per network in the profile's `macmode`/`maclist` (§ Guest Network Pro). The driver side is `cfg80211tool athN maccmd_sec` (each postwifi script writes `3` then `0`; `get_maccmd` reads the active policy, `2` here) *(read on RT-BE90U 3.0.0.6.102_58500)*. A filter is confirmed by the client table, since a client's band and MAC are only visible there ([diagnostics.md § Clients](diagnostics.md#clients)).

Keys: `nvram show 2>/dev/null | cut -d= -f1 | grep -xE '(wl[0-9]*(\.[0-9]+)?|2g1|5g1|6g1)_(macmode|macmode_show|maclist_x|maclist_x_0)|enable_mac'`

## WPS

Page `Advanced_WWPS_Content.asp` (Wireless › WPS): `wps_enable` (1/0) is the field the page posts, and `wps_enable_x` is the key rc reads: a radio restart copies `wps_enable_x` back over `wps_enable`, so a write over SSH that sets only `wps_enable` reverts at the next `restart_wireless`; write both. Other keys: `wps_unit`/`wps_band_x` (band), `wps_multiband` (1 = all bands), `wps_method` (0/1 radio choosing PIN or PBC), `wps_sta_pin` (client PIN to enrol). The page's `enableWPS()` applies the switch with `restart_wpsie` on this platform (`Qcawifi_support && amesh_support`; `restart_wireless` elsewhere). What "off" means here: rc's `postwifi_athN.sh` runs `hostapd_cli -i <vap> wps_ap_pin disable` for the fronthaul VAPs, so the PIN method (the attack surface) is closed and `hostapd_cli -i ath001 wps_ap_pin get` answers `FAIL`; this persists across reboots. The generated hostapd conf keeps `wps_state=2`, `ap_setup_locked=1` and `config_methods=push_button …` on the 2.4/5 GHz VAPs (`wps_state=0` on 6 GHz), `hostapd_cli -i ath001 get_config` keeps `wps_state=configured`, and a client scan keeps showing the `[WPS]` flag on the fronthaul BSSs after `restart_wpsie` and after a reboot, so push-button pairing stays possible while the physical button is pressed; `cfg80211tool <vap> hide_wpsie 1` is applied by the generated `prewifi_athN.sh` to the backhaul VAPs `ath0`/`ath1`/`ath2` only *(read on RT-BE90U 3.0.0.6.102_58500 with `wps_enable_x=0`; scan from the TV box)*. The AP PIN is in nvram and in each hostapd conf (`ap_pin`), so read it only on request. WPS supports Open and WPA/WPA2-Personal, not Shared Key, Enterprise or RADIUS (`helpcontent[13][1]`) [trade-off](tradeoffs.md#wps). Live: `grep -E '^(wps_state|ap_setup_locked)=' /etc/Wireless/conf/hostapd_ath001.conf`.

Keys: `nvram show 2>/dev/null | cut -d= -f1 | grep -xE 'wps_.*|wsc_config_state|lan1?_wps_(oob|reg)|(wl[0-9]*(\.[0-9]+)?)_wps_mode|enableWPSbtn|switchWPSbtn|Reset_OOB|devicePIN|addEnrolleebtn'`

## Roaming

**Roaming assistant** (Professional page, `wlX_user_rssi`): `0` off, otherwise −90…−40 dBm (the page validates that range); the `roamast` daemon disconnects a client whose signal stays below the threshold so it can join a stronger AP (`helpcontent[3][31]`) [trade-off](tradeoffs.md#roaming-assistant). Its tuning keys: `rast_idlrt` (idle-rate threshold), `rast_aclist_timeout`, `rast_weak_rssi_diff` (10; `RAST_DFT_WEAK_RSSI_DIFF`, the RSSI margin allowed when the target is not better than the trigger), `wlX_rast_mode`, `wlX_rast_sens_level` ([rc/roamast.h](https://github.com/RMerl/asuswrt-merlin.ng/blob/b053ba701af02e46a86d465d82cc2a7891a288a7/release/src/router/rc/roamast.h) defines sensitive / normal / lazy profiles: RSSI samples 2/3/6, idle period 10/15/20 s, idle rate 100/20/10 kbit/s; which `sens_level` value selects which is not established). `user_rssi=0` on all bands here *(read on RT-BE90U 3.0.0.6.102_58500)*.

**Roaming Block List** (`Advanced_Roaming_Block_Content.asp`, shown in router/AP mode with AiMesh): `rast_static_cli_enable` (1/0 "Enable roaming deny list") and `wlX_rast_static_client` (MACs the roaming logic leaves alone); saves with `restart_wireless`. Running: `pidof roamast`.

Keys: `nvram show 2>/dev/null | cut -d= -f1 | grep -xE 'rast_.*|(wl[0-9]*(\.[0-9]+)?)_(rast_mode|rast_sens_level|rast_static_client|user_rssi)|wlX_rast_static_client|enable_roaming'`

## WDS, WiFi Proxy and RADIUS

**WDS** (`Advanced_WMode_Content.asp`, `restart_wireless`): `wlX_mode_x` 0 AP Only, 1 WDS Only, 2 Hybrid; `wlX_wdsapply_x` 1 = connect only to APs in `wlX_wdslist` (`helpcontent[1][1]`, `[1][3]`). All three units are `mode_x=0` and every postwifi script runs `wlanconfig athN nawds mode 0` *(read on RT-BE90U 3.0.0.6.102_58500)*.

**WiFi Proxy** (`Advanced_WProxy_Content.asp`, `wifipxy_enable_2`, `wlcN_wifipxy`) applies to media-bridge/repeater client links and is removed from the menu on QCA. The `wlc*` keys (`wlc_band`, `wlcN_ssid`, `wlcN_auth_mode`, …; the operation-mode flags `wlc_psta`/`wlc_express` are in [platform.md § Administration](platform.md#administration)) and `sta_*` hold the station-side (repeater/AiMesh node uplink) configuration; `wpa_supplicant` logs to `/jffs/wpa_supplicant_sta0.log`.

**RADIUS** (`Advanced_WSecurity_Content.asp`): `wlX_radius_ipaddr`, `_port`, `_key` for WPA-Enterprise; the page is removed with `sdn_mwl`, and SDN profiles carry RADIUS in `radius_list` via the security string's `radius_idx`. `radius2_*` and `radius_acct_*` are the secondary and accounting servers.

Keys: `nvram show 2>/dev/null | cut -d= -f1 | grep -xE '(wl[0-9]*(\.[0-9]+)?|2g1|5g1|6g1)_(mode_x|wdsapply_x|wdslist|wdslist_0|wdsnum_x|wdsnum_x_0|radius_ipaddr|radius_port|radius_key|radius2_ipaddr|radius2_port|radius2_key|radius_acct_ipaddr|radius_acct_port|radius_acct_key|radius2_acct_ipaddr|radius2_acct_port|radius2_acct_key)|radius_list|radius_list_x|wifipxy_enable_2|wlc[0-9]+_.*|wlc_(11be|auth_mode|band|crypto|key|list|nbw_cap|sbstate|scan_state|ssid|state|ure_ssid|wep|wep_key|wpa_psk)|sta_(ifnames|phy_ifnames|priority|ssid)|ure_disable'`

## AiMesh

Page `AiMesh.asp` frames `/www/aimesh/aimesh_topology.html` and `aimesh_system_settings.html`. Daemons: `cfg_server` (configuration sync to nodes, `cfg_*` keys, `/tmp/cfg_mnt`, `/tmp/cfgmnt_log.txt`), `amas_lanctrl`, `amas_ssd_cd`, `amas_portstatus`, `amas_lib` *(read on RT-BE90U 3.0.0.6.102_58500)*.

```
KEY                       MEANING / VALUES
------------------------  -----------------------------------------------------------------------
cfg_master                1 = this unit is the AiMesh router (re_mode=0: not a node)
cfg_relist, cfg_recount,  joined nodes (empty / 0 here), node limit 16; /tmp/relist.json
 cfg_re_maxnum
cfg_group, cfg_ver        mesh group id and config version (synced to nodes)
amas_eap_bhmode           Ethernet Backhaul Mode: 0 off, 3100 on (aimesh_system_settings.html;
                          saves with restart_wireless) [trade-off](tradeoffs.md#ethernet-backhaul-mode)
amas_wifi_bhmode,         backhaul selection bitmasks (48 / 11 here; bit meanings not established)
 amas_eth_bhmode, amas_costmode
sta_binding_list          client-to-node bindings from the topology page (rc_service update_sta_binding)
dwb_mode, dwb_band        dedicated Wi‑Fi backhaul band (dwb_band=2 → 6 GHz unit)
obvif_*                   onboarding VAP: cap sub-unit 4 (wl0.4), node sub-unit 5
fh_ap_enabled             node fronthaul AP flag read by the AiMesh page
aimesh_newob_auto_notify  notify when a new node is available (system settings)
```

Node list and links: `cat /tmp/relist.json`, the topology page, and `iw dev` on the MAINBH VAPs (`ath0`/`ath1`/`ath2`).

Keys: `nvram show 2>/dev/null | cut -d= -f1 | grep -xE 'amas_.*|amascli_dbg|plk_.*|prelink_pap_status|brclist|cfg_(alias|check|cost|device_list|fwstatus|group|key|master|maxlevel|note|obre|obstatus|pause|re_maxnum|recount|rejoin|rekeylist|relist|relist_x|rssiscore|tbrelist|tcso|upgrade|ver|wifi_quality)|re_mode|re_rb_enable|dwb_.*|obvif_.*|sta_binding_list|fh_ap_enabled|aimesh_.*'`

## Radio internals

Per-unit keys no page edits. Each is copied into every `wlX` / `wlX.Y` unit; rc reads them when it writes the files above. Where the generated file shows the target, the right column names it *(read on RT-BE90U 3.0.0.6.102_58500)*; otherwise the effect is not established.

```
KEY                                   VALUE HERE   SEEN IN GENERATED CONFIG
------------------------------------  -----------  ----------------------------------------------------
HT_GI, HT_STBC                        1, 1         cfg80211tool shortgi 1; hostapd ht_capab [TX-STBC]
HT_RxStream, HT_TxStream              2, 2         —
mimo_preamble, nmode_protection       mm, auto     cfg80211tool protmode 0 on 5/6 GHz VAPs
be_ofdma, be_mumimo, eht_features     3, 3, -1     — (802.11be feature masks)
assoc_retry_max, pmk_cache            3, 60        —
lrc, qca_sched, psr_mrpt              2, 1, 0      —
txq_thresh                            1024 (wl_)   —
set_bw, set_channel, set_nctrlsb      0, 0, 0      —
txbf_en                               0 (wl1)      —
frameburst_override, cache_frameburst on, per band  cache_* hold the last Professional values
 cache_atf, cache_twt                 0, 0
atf_mode, atf_ssid, atf_sta           0, "", ""    airtime-fairness policy detail
auth, akm, infra, bridge, preauth,    wl0.1: 0, "",  802.1X/NAS per-VAP keys of the Broadcom heritage
 net_reauth                           1, "", "", 36000
chansps                               ""           not established
auth_mode                             none         Broadcom NAS auth mode (the UI key is auth_mode_x)
hapd_dbg                              0            hostapd debug
```

Radio-wide parameters with no nvram key, from `prewifi_wifiN.sh`: `dcs_enable 0` (no dynamic channel change on interference), `obss_rssi_th 35`, `txbf_snd_int 100`, `thermaltool` throttling steps (2.4 GHz: 50/80/90/100 % off-time from 100–118 °C bands; 5/6 GHz: 40/50/60 % from 95–115 °C), and on 6 GHz `acs_6g_only_psc 1` and `samessid_disable 1`. `/etc/Wireless/ini/global.ini` holds driver load parameters (`max_vaps=16`, `max_clients=124`, `twt_enable=0`, spatial-reuse thresholds).

Keys: `nvram show 2>/dev/null | cut -d= -f1 | grep -xE '(wl[0-9]*(\.[0-9]+)?)_(akm|assoc_retry_max|atf_mode|atf_ssid|atf_sta|auth|be_mumimo|be_ofdma|bridge|cache_atf|cache_frameburst|cache_twt|eht_features|frameburst_override|HT_GI|HT_RxStream|HT_STBC|HT_TxStream|infra|lrc|mimo_preamble|net_reauth|nmode_protection|pmk_cache|preauth|psr_mrpt|qca_sched|set_bw|set_channel|set_nctrlsb|txbf_en|txq_thresh|chansps|auth_mode)|hapd_dbg'`
