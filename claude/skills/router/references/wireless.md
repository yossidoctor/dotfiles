# Wireless settings

Every wireless key, what it does, and where it lands in the driver. Values and labels are derived from the web UI files on the router (`/www/Advanced_Wireless_Content.asp`, `/www/Advanced_WAdvanced_Content.asp`, `/www/Advanced_ACL_Content.asp`, `/www/Advanced_Smart_Connect.asp`, MediaTek `Rawifi_support` branches) *(read on RT-AX53U 3.0.0.4.386_69196)*. Re-derive a key's options with `grep -n '<name>' /www/<page>.asp`; a UI token `<#N#>` resolves to line N+1 of `/www/EN.dict`. Driver mappings come from ASUS's `gen_ralink_config` as built for MT7915D in `ralink.c` of [SWRT-dev/swrt-gpl](https://github.com/SWRT-dev/swrt-gpl) at commit 604466e (stock source is not public; confirm against the generated `.dat` on the unit).

Every key below exists as `wl0_<key>` (2.4 GHz), `wl1_<key>` (5 GHz) and the `wl_<key>` working copy ([platform.md § Configuration model](platform.md#configuration-model)). Read both bands: `for b in 0 1; do echo "wl$b: $(nvram get wl${b}_<key>)"; done`. All are applied by `service restart_wireless`.

## Wireless › General

```
KEY            VALUES = UI LABEL                                         DRIVER (.dat)
------------   -------------------------------------------------------   ---------------------------
ssid           text, up to 32 bytes                                      SSID1
closed         1 = Hide SSID, 0 = broadcast                              HideSSID
nmode_x        0 = Auto, 1 = N only, 2 = Legacy,                         WirelessMode
               8 = N/AC(/AX) mixed (5 GHz)                               (with 11ax, see below)
11ax           1 = 802.11ax / Wi‑Fi 6 mode on, 0 = off                   WirelessMode 16 (2.4) / 17 (5)
bw             2.4 GHz: 1 = 20/40, 0 = 20, 2 = 40                        HT_BW, VHT_BW
               5 GHz:   1 = 20/40/80, 0 = 20, 2 = 40, 3 = 80
               (5 = 160 only on models with vht160 support)
channel        0 = Auto, otherwise the control channel number            Channel, AutoChannelSelect
nctrlsb        lower / upper: side of the 40 MHz extension channel       HT_EXTCHA
auth_mode_x    open, shared, psk = WPA, psk2 = WPA2-Personal,            AuthMode
               sae = WPA3-Personal, pskpsk2 = WPA/WPA2,
               psk2sae = WPA2/WPA3-Personal, wpa, wpa2, wpawpa2,
               radius
crypto         aes, tkip+aes                                             EncrypType
mfp            0 = Disable, 1 = Capable, 2 = Required (PMF)              PMFMFPC / PMFMFPR
```

**Auto channel keys** (global, not per band):

```
KEY           MEANING                                                   UI
-----------   -------------------------------------------------------   --------------------------------------
acs_dfs       1 = Auto may pick DFS (radar) channels                    "Auto select channel including DFS
                                                                         channels", shown when Channel = Auto
acs_ch13      1 = Auto may pick 2.4 GHz channels 12 and 13              "Auto select channel including
                                                                         channel 12, 13"
acs_band1,    sub-band skip flags used in building the skip list        —
acs_band3
```

rc turns these into `AutoChannelSkipList` in the `.dat` (with `acs_dfs=0` the 5 GHz list holds 52–64 and 100–140). `AutoChannelSelect=3` means the driver picks by channel busy time (`ralink.c` in [SWRT-dev/swrt-gpl](https://github.com/SWRT-dev/swrt-gpl) at commit 604466e). Auto picks the channel when the radio starts; the result is visible only in the live state (`iwconfig rai0`), never in nvram, which keeps `0`.

## Security modes and PMF

PMF (Protected Management Frames, 802.11w) is coerced by the Wireless › General page when it is saved (`/www/Advanced_Wireless_Content.asp`, the block after `var mbo = document.form.wl_mbo_enable.value`) *(read on RT-AX53U 3.0.0.4.386_69196)*:

```
AUTH MODE                       PMF WRITTEN ON SAVE
-----------------------------   ------------------------------------------------
sae (WPA3-Personal)             2 (Required), always
psk2sae (WPA2/WPA3)             1 (Capable) if it was 0
psk2, pskpsk2, wpa2, wpawpa2    1 (Capable) if it was 0 and mbo_enable=1
```

A save of that page therefore leaves `mfp` at 2 for `sae`, at 1 or 2 for `psk2sae`, and at 1 or 2 for the `psk2` family whenever `mbo_enable=1`; a value written through nvram outside these combinations stays until the page is saved. ASUS: WPA3 forces PMF on; WPA3 does not support WPS ([FAQ 1042472](https://www.asus.com/us/support/faq/1042472/), [FAQ 1042478](https://www.asus.com/support/faq/1042478/)). WPA2/WPA3 mixed mode (`psk2sae`) lets a WPA3 client connect with SAE; the AP may send a WPA3 *Transition Disable* indication, after which the client stops using WPA2 for that network (WPA3 spec v3.5, [Wi‑Fi Alliance](https://www.wi-fi.org/system/files/WPA3%20Specification%20v3.5.pdf)). ASUS publishes nothing about how its firmware uses that indication.

The MediaTek driver's PMF code logs `[PMF]PMF_PerformRxFrameAction: NOT_ROBUST_UNICAST_FRAME, FC->SubType=<n> (wcid=<n>)` to the kernel log when it receives an unprotected management frame from a PMF station; the line names the station-table index (`wcid`, the `WCID` column in [diagnostics.md § Clients](diagnostics.md#clients)) and is not itself a disconnect. Count them with `grep -c NOT_ROBUST /jffs/syslog.log*`; their share of the log decides how far back the log reaches ([diagnostics.md § Logs](diagnostics.md#logs)).

## Wireless › Professional

```
KEY          VALUES = UI LABEL                                        WHAT IT DOES                                    DRIVER
----------   ------------------------------------------------------   ---------------------------------------------   ------------------------
radio        1 = Yes, 0 = No                                          radio on/off                                    —
timesched,   timesched 1/0; sched = schedule string                   Wireless scheduler; needs NTP time               —
sched
ap_isolate   1 = Yes, 0 = No                                          Wi‑Fi clients can't reach each other;            NoForwarding
                                                                      wired unaffected
user_rssi    0 = off, otherwise −90…−40 dBm (UI default −70)          Roaming assistant: disconnects clients below     roamast daemon
                                                                      the threshold
igs          1/0                                                      IGMP snooping (multicast to Wi‑Fi)               IgmpSnEnable
mrate_x      0 = Auto, else a fixed multicast rate (CCK/OFDM/HTMIX)   Multicast rate                                   —
plcphdr      long / short / auto                                      Preamble type (2.4 GHz)                          TxPreamble
rts          0–2347                                                   RTS threshold                                    RTSThreshold
frag         256–2346                                                 Fragmentation threshold                          FragThreshold
dtim         1–255 (beacons)                                          DTIM interval                                    DtimPeriod
bcn          20–1000 (ms, default 100)                                Beacon interval                                  BeaconPeriod
frameburst   off / on                                                 TX bursting                                      —
wme          auto / on / off                                          WMM                                              WmmCapable
wme_no_ack   off / on                                                 WMM No-Acknowledgement                           AckPolicy
wme_apsd     off / on                                                 WMM APSD (power save delivery)                   APSDCapable
atf          1/0                                                      Airtime fairness                                 VOW_Airtime_Fairness_En
ofdma        0 = Disable, 1 = DL OFDMA only, 4 = DL OFDMA + MU-MIMO,  OFDMA and MU-MIMO directions                    MuOfdmaDl/UlEnable,
             2 = DL/UL OFDMA, 3 = DL/UL OFDMA + MU-MIMO                                                               MuMimoDl/UlEnable
txbf         1/0                                                      Explicit beamforming (802.11ax/ac)              ETxBfEnCond
itxbf        1/0                                                      Universal (implicit) beamforming, downlink      ITxBfEn
turbo_qam    1/0                                                      256-QAM on 2.4 GHz / 1024-QAM on 5 GHz           —
twt          1/0                                                      Target Wake Time                                 TWTSupport
mbo_enable   1/0                                                      Wi‑Fi Agile Multiband                            MboSupport
txpower      0 Power Saving, 25 Fair, 50 Balance, 88 Good,            Tx power adjustment                              TxPower
             100 Performance
rateset      ofdm = "Disable 11b"                                     basic rate set                                   —
```

`ofdma` driver mapping (DL OFDMA / UL OFDMA / DL MU-MIMO / UL MU-MIMO): 0 → 0/0/0/0, 1 → 1/0/0/0, 2 → 1/1/0/0, 3 → 1/1/1/1, 4 → 1/0/1/0; all off when `11ax=0`. Disabling beamforming also disables MU-MIMO (UI note). Descriptions: [ASUS FAQ 1011438](https://www.asus.com/support/faq/1011438/) (Professional tab), [FAQ 1036730](https://www.asus.com/support/faq/1036730/) (roaming assistant), [FAQ 1044821](https://www.asus.com/us/support/faq/1044821/) (AP isolation), [FAQ 1043425](https://www.asus.com/support/faq/1043425/) (scheduler), [FAQ 1042759](https://www.asus.com/support/faq/1042759/) (OFDMA).

Hidden on the MediaTek UI: noise mitigation, AMPDU MPDU, ACK ratio, Bluetooth coexistence.

## Wireless MAC filter

`macmode` per band: `allow` = Accept (allow-list), `deny` = Reject (deny-list), `disabled`. `maclist_x` holds the list as `<MAC<MAC…` (entries separated by `<`). The driver receives them as `AccessPolicy0` (`0` off, `1` allow, `2` deny) and `AccessControlList0` ([FAQ 1000904](https://www.asus.com/us/support/faq/1000904/)). Applying the filter restarts Wi‑Fi. Whether a station is actually on the filtered band is visible only in the live client table ([diagnostics.md § Clients](diagnostics.md#clients)), so a filter is confirmed there, not by its keys.

## Smart Connect and band steering

`smart_connect_x=1` runs one SSID across both bands and lets the router place each client on a band ([FAQ 1012132](https://www.asus.com/us/support/faq/1012132/)). On the MediaTek platform the steering runs in the daemons `roamast`, `wapp` and `bs20` (`ps w`), configured from `/etc/map/mapd_cfg` and `/etc/mapd_strng.conf` (`SteerEnable`, `CentralizedSteering`, `ChPlanningEnable`, channel-utilisation thresholds); the `.dat` carries `BndStrgBssIdx`. The Smart Connect rule page writes Broadcom `bsd_*` keys, which do not exist on this platform (`nvram show | grep ^bsd_` is empty), and the UI hides the rule link on MediaTek. With Smart Connect on, the band each client ends up on, the channel each radio runs, and whether per-band settings such as the MAC filter still hold, are read from the live state (`iwconfig`, the client table), since the steering daemons act outside nvram.

With Smart Connect off, each band keeps its own channel and filter settings. Apple treats one SSID shared across bands as a single network and flags different names per band as limited compatibility ([Apple 102285](https://support.apple.com/en-us/102285)).

## Guest networks

`wlX.Y_bss_enabled` (1/0) turns guest SSID `Y` on band `X` on; each has its own `ssid`, `auth_mode_x`, `crypto`, `closed`, `macmode`. Guest networks use a separate subnet and, by default, cannot reach the LAN ("Access Intranet" off) ([FAQ 1042732](https://www.asus.com/support/faq/1042732/)). Applied with `restart_wireless;restart_qos;restart_firewall`. Each enabled guest SSID transmits its own beacons on that radio.

## Region-related wireless keys

`wlX_country_code`, `territory_code`, `reg_spec`, `location_code`, `wl_reg_2g`, `wl_reg_5g`, `wlX_RDRegion`, `wlX_IEEE80211H` decide which channels the radio may use. They are covered with the channel tables in [regulatory.md § How the router derives its region](regulatory.md#how-the-router-derives-its-region).
