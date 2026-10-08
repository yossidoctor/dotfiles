# Channels and regulatory rules

How the RT-BE90U decides which channels and power it may use on each band, how DFS behaves on its Qualcomm driver, what Israeli rules allow, and how clients pick their own country. Unit facts are *(read on RT-BE90U 3.0.0.6.102_58500)* unless a source is cited; re-read them with the command given. Applying any key below: [platform.md § Apply actions](platform.md#apply-actions).

## Channel numbering

Centre frequency per band, each formula matching the unit's `iw phy` list (`2412 MHz [1]`, `5180 MHz [36]`, `5955 MHz [1]`):

```
BAND      CENTRE (MHz)     CHANNELS ARE
-------   --------------   -----------------------------------------------
2.4 GHz   2407 + 5n        5 MHz apart, 20 MHz wide: neighbours overlap
5 GHz     5000 + 5n        20 MHz apart; wider channels are fixed groups
6 GHz     5950 + 5n        20 MHz apart (1, 5, 9, ...); fixed groups as 5 GHz
```

A 40/80/160/320 MHz channel is a fixed group of adjacent 20 MHz channels with one *primary* 20 MHz channel. Under ETSI EN 301 893 V2.2.1 §4.2.7.3.2 (Option 2) the full channel-access procedure runs on the primary, and each other 20 MHz channel only gets a ≥23 µs clear-channel check before a transmission ([ETSI EN 301 893 V2.2.1](https://www.etsi.org/deliver/etsi_en/301800_301899/301893/02.02.01_60/en_301893v020201p.pdf)). Two networks whose wide channels overlap therefore share airtime even when their primaries differ.

The live channel, width and centre per radio: `iw dev | grep -E 'Interface|channel'` (`center1` is the centre of the whole group), or `cfg80211tool wifiN g_oper_reg_info`, which prints channel, width, country and operating class in one line.

## Channels on this unit

The radios are self-managed by the Qualcomm driver: each `phy` carries its own regulatory table, separate from the kernel's global domain (`iw reg get` shows `global country 00` and one `phy#N (self-managed) country GB: DFS-ETSI` block per radio). The per-channel list with its power cap is `iw phy | grep -E '^Wiphy|MHz \['`; the list the web UI offers is `cat /tmp/chanspec_avbl.json` (written by the AiMesh config daemon, path defined in [cfg_mnt/cfg_chanspec.h](https://github.com/RMerl/asuswrt-merlin.ng/blob/b053ba701af02e46a86d465d82cc2a7891a288a7/release/src/router/cfg_mnt/cfg_chanspec.h)); `chanspec_avbl.txt`, `chanspec_private.json` and `chanspec_all.json` hold the same list in other forms. Their `bandwidth` field is a bitmask of the widths the radio offers; no source read documents its bit assignment. `iwlist athN channel` prints the same 20 MHz list per VAP.

Every channel the unit lists, and the rule behind it (GB table from `iw reg get`):

```
BAND / RANGE        LISTED CHANNELS        RULE                                        CAP (iw)
-----------------   --------------------   -----------------------------------------   --------
2.4 GHz 2402–2482   1–13                   GB 2402–2482 MHz, max 40 MHz                20 dBm
5 GHz   5170–5330   36–48 (no DFS)         GB 5170–5330, max 160, NO-OUTDOOR           23 dBm
                    52–64 (DFS)            same range; 5250–5350 is radar band
5 GHz   5490–5710   100–140 (DFS)          GB 5490–5710, max 160; 144 (5710–5730) and  30 dBm
                                           149–165 (5735–5835) are outside the table
6 GHz   5945–6425   1–93 (every 4th)       GB 5945–6425, max 320, NO-OUTDOOR           24 dBm
```

Wide groups follow from the list. 5 GHz: 40 MHz pairs 36+40 … 132+136 (140 has no partner without 144), 80 MHz groups 36–48, 52–64, 100–112, 116–128 (132–140 has none), 160 MHz groups 36–64 and 100–128. 6 GHz: 40/80/160 MHz groups start at channel 1 and tile up to 93 (24, 12, 6, 3 groups); the two 320 MHz groups that fit 5945–6425 MHz are 1–61 (centre 31) and 33–93 (centre 63). `iw dev` reads `channel 69 … width: 320 MHz, center1: 6265 MHz` on this unit, i.e. the 33–93 group.

**Auto channel.** With Control Channel on Auto (`wlX_chanspec`/`wlX_channel` = 0, [wireless.md](wireless.md)) the driver's ACS picks the channel at radio start, skipping a block list rc writes into `/etc/Wireless/sh/prewifi_athN.sh` (`wifitool athN block_acs_channel …`) on each radio start. `wifitool athN block_acs_channel_get` prints the list in effect. rc derives it from the checkboxes: ath0 blocks `12,13` while `acs_ch13=0`; ath1 blocks `36` always and, with `acs_dfs=1`, the weather-band group `116,120,124,128` (the 80 MHz group overlapping 5600–5650 MHz, [§ DFS](#dfs)), or with `acs_dfs=0` every DFS channel `52–64,100–140`, so Auto then chooses among 40, 44 and 48 *(both lists read on RT-BE90U 3.0.0.6.102_58500)*; no source read states why 36 is blocked. Blocked channels stay selectable by hand. The Wireless › General checkboxes:

```
KEY         UI LABEL (EN.dict)                                   SHOWN WHEN
---------   --------------------------------------------------   -----------------------------------
acs_ch13    Auto select channel including channel 12, 13         2.4 GHz list longer than 11 channels
acs_unii4   Auto select channel including U-NII-4 band           5 GHz list contains 173 or 177;
                                                                 never on this unit's GB list
```

[Trade-off](tradeoffs.md#auto-channel-12-13) for `acs_ch13`.

Keys: `nvram show 2>/dev/null | cut -d= -f1 | grep -xE 'acs_ch13|acs_unii4|channel_plan'`

## How the router derives its region

The country reaches the radios in four steps, each readable:

```
STEP                         WHERE                                     READ WITH
--------------------------   ---------------------------------------   ----------------------------------------
1. factory region            Factory flash partition                   ATE Get_TerritoryCode      (EU/01)
                                                                       ATE Get_RegulationDomain_2G (GB)
2. nvram copy                territory_code, wl/wl0/wl1/wl2_           nvram get territory_code ;
                             country_code                              nvram get wl2_country_code
3. driver country            setCountryID per radio, at radio start    cfg80211tool wifiN getCountry  (GB4)
                                                                       iwpriv athN get_countrycode    (826)
4. resulting channels        per-phy table and UI list                 iw reg get ; cat /tmp/chanspec_avbl.json
```

`826` is the ISO 3166-1 numeric code for GB. `ATE Get_*` reads the factory partition; the `ATE Set_*` commands write it and are outside a read-only session. In ASUS's QCA boot code (`init_syspara` in [init-qca.c of the RT-AX89X GPL tree, SWRT-dev/rtax89x](https://github.com/SWRT-dev/rtax89x/blob/95e6d406af54e6a88eb79203ba667044300429bd/release/src/router/rc/sysdeps/init-qca.c)) every boot copies the factory country code into `wl_country_code` and each `wlX_country_code` (`DB` when unreadable) and the factory territory code into `territory_code`, and the radio-start code passes `wlX_country_code` to `cfg80211tool <radio> setCountryID`; the unit's `rc` binary carries the same `cfg80211tool %s setCountryID %s` string. That tree is an older QCA model, so on this build a country written to nvram is confirmed to survive only by reading `wl0_country_code` and `iw reg get` after a reboot *(unverified)*.

**Region selector.** Wireless › Professional builds a Region dropdown (`ui_location_code`, saved to `location_code`; changing it runs `reboot`) only when `rc_support` contains `loclist` (`/www/Advanced_WAdvanced_Content.asp`, `generate_country_selection`), and the list itself comes from httpd's `get_support_region_list`. This unit's `rc_support` has no `loclist` (`nvram get rc_support | tr ' ' '\n' | grep -x loclist` prints nothing), so the row is hidden and `location_code`/`ui_location_code` are empty; the country is the factory one. `cfg_ui_region_disable` lets an AiMesh router hide the row, `EG_mode` forces the Egypt variant, and `x_RegulatoryDomain` is a read-only hidden field on the WDS and old guest pages; none is set on this unit.

Keys: `nvram show 2>/dev/null | cut -d= -f1 | grep -xE 'wl[0-9.]*_country_code|territory_code|location_code|ui_location_code|cfg_ui_region_disable|EG_mode|x_RegulatoryDomain'`

## DFS

Channels 52–64 (5250–5350 MHz) and 100–144 (5470–5725 MHz) share spectrum with radar. A radio must listen before using one and leave when it hears radar:

```
PARAMETER                       ETSI EN 301 893 V2.2.1 Table D.1        FCC 47 CFR 15.407(h)(2)
-----------------------------   -------------------------------------   ------------------------------
Channel availability check      60 s; 10 min if the channel touches     60 s
                                5600–5650 MHz
Off-channel CAC                 6 min – 4 h; 1 h – 24 h for 5600–5650   —
Channel move time               10 s                                    10 s
Channel closing transmission    1 s                                     200 ms of normal traffic
Non-occupancy period            30 min                                  ≥ 30 min, from detection
```

Sources: [ETSI EN 301 893 V2.2.1](https://www.etsi.org/deliver/etsi_en/301800_301899/301893/02.02.01_60/en_301893v020201p.pdf), [47 CFR 15.407](https://www.law.cornell.edu/cfr/text/47/15.407). Under GB/ETSI on this unit, channels 120, 124, 128 at 20 MHz and any wider channel containing them fall in the 10-minute class.

**How the driver shows it.** The kernel log carries `ieee80211_dfs_deliver_event: dfs CAC_START event delivered on chan freq <MHz>` (one line per 20 MHz member), then `dfs_process_cac_completion: CAC timer on channel <n> (<MHz> MHz) expired;no radar detected` and `CAC_COMPLETED` lines; on this unit 62 s passed between them for channel 100 at 80 MHz. `grep -E 'CAC_START|CAC_COMPLETED|cac_completion|RADAR' /jffs/syslog.log` lists them; reading the log in general: [diagnostics.md § Logs](diagnostics.md#logs). Radar hits: `radartool -i wifi1 numdetects` (`Radar: detected 0 radars`); channels in non-occupancy: `radartool -i wifi1 getnol` (prints nothing when the list is empty). `radartool` sub-commands without `get`/`numdetects` change detection thresholds or the NOL. `/etc/Wireless/ini/global.ini` sets `dfs_retain_nol_across_driver_reload=1` and `enable_mloadvert_degrade_on_cac=0`.

**Keys.** `acs_dfs` (Wireless › General "Auto select channel including DFS channels", shown when Control Channel is Auto and the 5 GHz list contains 56 or 100; forced on and greyed when the 5 GHz width is 240 MHz, bandwidth value `6`) lets ACS use 52–144; `acs_band3` is the same checkbox for a second 5 GHz radio, which this unit lacks (`/www/Advanced_Wireless_Content.asp`, `js/asus.js`). `acs_band1` exists in nvram (0) and no page or script under `/www` reads it; its effect is not established. [Trade-off](tradeoffs.md#auto-channel-dfs). `wl_precacen` / `wlX_precacen` is the Professional row "Agile DFS" (ETSI off-channel CAC, so a DFS channel is pre-cleared while the radio serves another), shown only with `rc_support` `agile_dfs`, which this unit lacks; `cfg80211tool wifi1 get_preCACEn` reads the driver's value (0). `wl1_80211h` / `wl1_80211h_orig` belong to an EU RT-AC87U branch of the same page and do not exist in this unit's nvram. `has_dfs_channel` is written by firmware (reads 26); no source read defines it.

Keys: `nvram show 2>/dev/null | cut -d= -f1 | grep -xE 'acs_dfs|acs_band1|acs_band3|wl[0-9.]*_precacen|wl1_80211h(_orig)?|has_dfs_channel'`

## Israel

Wireless Telegraph Regulations (Conformity Approvals), 2021, First Schedule, Part B ([consolidated text, Nevo](https://www.nevo.co.il/law_html/law01/502_483.htm)):

```
BAND (MHz)     ITEM        LIMIT (EIRP)                              CONDITIONS
------------   ---------   ---------------------------------------   ---------------------------
2400–2483.5    49          100 mW                                    EN 300 328; covers ch 1–13
5150–5250      55          200 mW, 10 dBm/MHz                        EN 301 893; indoors only
5250–5350      60 / 61     200 mW, 10 dBm/MHz with TPC /             EN 301 893; indoors only
                           100 mW, 7 dBm/MHz without
5470–5725      62 / 63     1 W, 17 dBm/MHz with TPC /                EN 301 893; indoors only
                           500 mW, 14 dBm/MHz without
5725–5875      64, 68      deleted; remaining items 68א–70 are       no RLAN entry, so ch 149–165
                           SRD, industrial and fixed links           have none
5945–6425      71א         200 mW, 10 dBm/MHz (−22 dBm/MHz below     EN 303 687; indoors only
                           5935 MHz)
```

Against this unit's GB table: the channel sets match (1–13; 36–64 and 100–140; nothing in 5725–5875; 6 GHz 1–93). The caps differ in two places: 6 GHz is capped at 24 dBm where item 71א allows 200 mW (23 dBm), and 5 GHz 100–140 at 30 dBm is the with-TPC limit of item 62. Whether the radiated EIRP actually exceeds 23 dBm depends on antenna gain, which no shell command reports; whether the driver runs TPC is not established (the generated `hostapd_athN.conf` files carry no `ieee80211h` or `local_pwr_constraint` line). The live transmit power per VAP is `iw dev | grep -E 'Interface|txpower'`. A device's channel list is not evidence of legal status: the regulation text is.

## Other regions

```
REGION           5 GHz                                         6 GHz                                SOURCE
--------------   -------------------------------------------   ----------------------------------   ------------------------------------
EU (ETSI)        sub-band 1 5150–5250: 23/23 dBm               5945–6425: LPI 23 dBm, 10 dBm/MHz,   ETSI EN 301 893 V2.2.1 Table 2;
                 sub-band 2 5250–5350: 23/20 dBm (DFS)         indoors; VLP 14 dBm, 1 dBm/MHz,      ECC/DEC/(20)01 amended 8 Nov 2024
                 sub-band 3 5470–5725: 30/27 dBm (DFS)         portable, no drones                  (docdb.cept.org/download/4567)
                 (with / without TPC)
US (FCC)         5.15–5.25 AP 1 W, 17 dBm/MHz; 5.25–5.35 and   LPI AP 30 dBm EIRP, 5 dBm/MHz        47 CFR 15.407(a)
                 5.47–5.725: lesser of 250 mW or 11 dBm +       (5.925–7.125 GHz)
                 10 log B; 5.725–5.85: 1 W
GB (this unit)   the driver's GB table in § Channels on this unit                                   iw reg get
```

ETSI figures are mean EIRP; FCC 5 GHz figures are conducted output. The Ofcom texts for GB did not load (HTTP 403), so GB is described only by the driver's table.

## 6 GHz security and power

WPA3 Specification v3.5 §11.2: an AP running a BSS in 6 GHz allows no TKIP, no WPA3-Personal transition mode, no 802.1X SHA-1 AKM, no SAE hunting-and-pecking, no Enhanced Open transition mode, and sets PMF Required; §11.3 adds that an association using EHT or MLO (Wi‑Fi 7) uses no PSK AKM ([Wi‑Fi Alliance](https://www.wi-fi.org/system/files/WPA3%20Specification%20v3.5.pdf)). On this unit the 6 GHz fronthaul reads `wl2.1_auth_mode_x=sae`, `wl2.1_mfp=2`, and its generated hostapd file `wpa_key_mgmt=SAE`, `sae_pwe=1` (hash-to-element only), `ieee80211w=2`, `op_class=137`: `grep -E '^(wpa_key_mgmt|sae_pwe|ieee80211w|op_class)=' /etc/Wireless/conf/hostapd_ath201.conf` (the file also holds `ap_pin` and the passphrase, so read it filtered). The security keys themselves are in [wireless.md](wireless.md).

**Power class.** The GB table marks 5945–6425 MHz `NO-OUTDOOR`, i.e. low-power-indoor operation; nothing on the unit offers VLP or standard power. Standard-power 6 GHz with AFC is a US/Canada mechanism; the Wireless › General AFC switch (`httpApi.get_afc_enable`) is drawn only with `rc_support` `bcm_afc`, absent here, and no nvram key holds AFC state.

**PSC.** Preferred Scanning Channels are the 6 GHz channels clients probe for 6 GHz-only APs (5, 21, 37, … every 16th, [Apple Wi‑Fi specifications](https://support.apple.com/guide/deployment/dep268652e6c/web)). `psc6g=1` (Wireless › General "enable PSC (Preferred Scanning Channel) to ensure the 6GHz devices connectivity") limits the 6 GHz Control Channel list to PSCs; with it set, rc's radio-start script carries `cfg80211tool wifi2 acs_6g_only_psc 1` (`/etc/Wireless/sh/prewifi_wifi2.sh`), and `cfg80211tool wifi2 get_acs_6g_only_psc` reads the driver's value. [Trade-off](tradeoffs.md#6-ghz-psc-only). 320 MHz on 6 GHz: [trade-off](tradeoffs.md#6-ghz-320-mhz).

Keys: `nvram show 2>/dev/null | cut -d= -f1 | grep -xE 'psc6g'`

## How clients choose their country

A client's channel list and power come from its own regulatory setting, not the router's:

- **Android:** `WifiCountryCode.pickCountryCode()` takes, in order, a test override, the mobile-network country, then the country derived from scan results (beacons), then the build default ([AOSP WifiCountryCode.java, main, read 2026-10-08](https://android.googlesource.com/platform/packages/modules/Wifi/+/refs/heads/main/service/java/com/android/server/wifi/WifiCountryCode.java)). Its documentation limits the scan-derived country to a disconnected device; the code shown does not check that. A network on a channel outside the active code's list can be missing from scans while a connect by name still succeeds; `dumpsys wifi` shows the active code.
- **Apple:** regulations define the allowed channels and signal strength, and Location Services stays on for Wi‑Fi networking ([Apple 102766](https://support.apple.com/en-us/102766)). The Mac-side reading of country and supported channels: [macos.md](macos.md).
- **Linux:** observing an AP with country information is a regulatory-domain change, and the kernel loads that domain's rules from its regulatory database to enforce on drivers; mac80211 uses this for 802.11d ([kernel regulatory docs](https://wireless.docs.kernel.org/en/latest/en/developers/regulatory.html)).

`cfg80211tool wifiN getCountry` prints the code the unit's radios use (`GB4`); whether that code reaches clients in the beacon's Country element is read from a client-side capture, not from the router shell.
