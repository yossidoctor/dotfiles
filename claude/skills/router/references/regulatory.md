# Channels and regulatory rules

Channel numbering, DFS, per-country rules, and how the router and its clients each decide which channels they may use. Regulatory facts cite the regulation or standard; where a primary text could not be read, the entry says so.

## Channel numbering

**2.4 GHz.** Centre = 2407 + 5n MHz; channel 1 = 2412 MHz, 13 = 2472 MHz, 14 = 2484 MHz. Channels are 5 MHz apart and 20 MHz wide, so 1, 6 and 11 are the non-overlapping set in North America and 1, 5, 9, 13 where 13 is allowed ([Apple, Optimize your Wi‑Fi networks](https://support.apple.com/guide/deployment/optimize-your-wi-fi-networks-dep2af1caf35/web); [List of WLAN channels](https://en.wikipedia.org/wiki/List_of_WLAN_channels)).

**5 GHz.** Centre = 5000 + 5n MHz; channel 36 = 5180 MHz. Wider channels are fixed groups of 20 MHz channels:

```
WIDTH     GROUPS (centre channel = member channels)
-------   ------------------------------------------------------------------------
40 MHz    36+40, 44+48, 52+56, 60+64, 100+104, 108+112, 116+120, 124+128,
          132+136, 140+144, 149+153, 157+161
80 MHz    42 = 36–48     58 = 52–64     106 = 100–112   122 = 116–128
          138 = 132–144  155 = 149–161
160 MHz   50 = 36–64     114 = 100–128  (163 = 149–177, needs U‑NII‑4)
```

A 40/80/160 MHz channel has one *primary* 20 MHz channel where the full channel-access procedure runs; the others get a short clear-channel check before each transmission ([ETSI EN 301 893 V2.2.1 §4.2.7.3](https://www.etsi.org/deliver/etsi_en/301800_301899/301893/02.02.01_60/en_301893v020201p.pdf)). Two networks whose wide channels overlap therefore share airtime even when their primary channels differ.

**6 GHz.** Centre = 5950 + 5n MHz, 20 MHz channels 1–233. Preferred Scanning Channels (PSC) are 5, 21, 37, … (every 16th), where 6 GHz‑only discovery happens ([Apple Wi‑Fi specifications](https://support.apple.com/guide/deployment/dep268652e6c/web)).

## US band names and limits (FCC 47 CFR 15.407)

```
BAND        RANGE (GHz)      LIMIT                                            DFS
---------   --------------   ----------------------------------------------   ---
U‑NII‑1     5.150–5.250      AP 1 W conducted, 17 dBm/MHz                     no
U‑NII‑2A    5.250–5.350      lesser of 250 mW or 11 dBm + 10 log B            yes
U‑NII‑2C    5.470–5.725      same as 2A                                       yes
U‑NII‑3     5.725–5.850      1 W                                              no
U‑NII‑4     5.850–5.895      indoor AP 36 dBm EIRP                            no
```

Source: [47 CFR 15.407](https://www.law.cornell.edu/cfr/text/47/15.407). The DFS ranges 5250–5350 and 5470–5725 MHz (FCC U‑NII‑2A/2C, ETSI sub-bands 2 and 3) contain channels 52–64 and 100–144 by the 5 GHz channel formula above.

## DFS (radar channels)

Channels in 5250–5350 and 5470–5725 MHz share spectrum with radar. A device must listen before transmitting and leave when it hears radar:

```
PARAMETER                        ETSI EN 301 893           FCC 15.407(h)
------------------------------   -----------------------   --------------
Channel availability check       60 s; 10 min for          60 s
(CAC, silent listen first)       channels in 5600–5650
Channel move time                10 s                      10 s
Channel closing transmission     1 s                       200 ms
Non-occupancy after radar        30 min                    ≥ 30 min
```

Sources: [ETSI EN 301 893 V2.2.1 Table D.1](https://www.etsi.org/deliver/etsi_en/301800_301899/301893/02.02.01_60/en_301893v020201p.pdf), [47 CFR 15.407(h)](https://www.law.cornell.edu/cfr/text/47/15.407). During a CAC the 5 GHz radio transmits nothing, so every 5 GHz client is disconnected; 2.4 GHz keeps working ([ASUS FAQ 1045936](https://www.asus.com/us/support/faq/1045936/)). The MediaTek driver logs `[DfsCacNormalStart] CAC <n> seconds start . Disable MAC TX` and `[DfsCacEndUpdate] CAC end. Enable MAC TX.` in dmesg; its constants are 65 s normal CAC, 605 s weather-band CAC (channels 120–128 at 20 MHz, 116–128 at 40 MHz and wider) and 1800 s non-occupancy ([MT7915 driver mt_rdm.h](https://github.com/hanwckf/rt-n56u/tree/master/trunk/proprietary/rt_wifi/rtpci/7.3.0.1/mt7915)). ASUS: with Control Channel on Auto the router may return to the original channel after the non-occupancy period; on a fixed channel it does not switch back; on 160 MHz a radar hit drops it to 80 MHz (FAQ 1045936).

## Rules by country

### Israel

Wireless Telegraph Regulations (Conformity Approvals), 2021, First Schedule, as amended 4 July 2022 ([consolidated text, Nevo](https://www.nevo.co.il/law_html/law01/502_483.htm); amendment in [gazette 10247, 7.7.2022](https://www.chamber.org.il/media/166545/)):

```
BAND (MHz)     ITEM   LIMIT                                    CONDITIONS
------------   ----   --------------------------------------   ---------------------------
2400–2483.5    49     100 mW EIRP, EN 300 328                  covers channels 1–13
5150–5250      55     200 mW EIRP, 10 dBm/MHz                  indoors
5250–5350      60     200 mW with TPC / 100 mW without (61)    indoors; DFS channels
5470–5725      62     1 W with TPC / 500 mW without (63)       indoors; DFS channels
5725–5875      —      no Wi‑Fi/RLAN entry since the 2022       entries 68א–70 cover SRDs,
                      amendment (items 64–68 deleted)          industrial and fixed links
5945–6425      71א    200 mW EIRP, 10 dBm/MHz, EN 303 687      indoors (LPI); since 7.2022
```

Channels 149–165 therefore have no current Wi‑Fi entry in the regulation text. The Ministry's English FAQ ([gov.il 10052018_2](https://www.gov.il/en/pages/10052018_2)) refers to the band but could not be fetched to confirm its wording. Devices set to country IL still list 149–165 (a Mac with country code IL lists them; see [§ How clients choose](#how-clients-choose-their-country)), so a device's channel list is not evidence of the legal status. The Wi‑Fi Alliance lists Israel's 6 GHz band as adopted ([6 GHz regulations](https://www.wi-fi.org/regulations-enabling-6-ghz-wi-fi)).

### European Union (ETSI)

EN 301 893 V2.2.1 harmonised sub-bands, EU Decision 2022/179 as amended by 2022/2307 ([ETSI text](https://www.etsi.org/deliver/etsi_en/301800_301899/301893/02.02.01_60/en_301893v020201p.pdf)):

```
SUB-BAND   RANGE (MHz)   MEAN EIRP WITH / WITHOUT TPC
--------   -----------   ----------------------------
1          5150–5250     23 / 23 dBm
2          5250–5350     23 / 20 dBm   (DFS)
3          5470–5725     30 / 27 dBm   (DFS)
4          5725–5850     national conditions (Annex B)
```

6 GHz: 5945–6425 MHz, LPI indoors at 23 dBm EIRP, VLP portable at 14 dBm ([ECC/DEC/(20)01](https://docdb.cept.org/download/4567)). 2.4 GHz channels 1–13.

### United Kingdom

5725–5850 MHz at 200 mW EIRP indoors without DFS; 6 GHz 5925–6425 MHz at 250 mW LPI and 25 mW VLP ([Ofcom 5 GHz information sheet](https://www.ofcom.org.uk/siteassets/resources/documents/spectrum/spectrum-information/ofcom-information-sheet-5-ghz-rlans.pdf); read via search extracts, the PDF refused direct fetch).

### United States

5 GHz as in the FCC table above; 6 GHz 5925–7125 MHz: LPI AP 30 dBm EIRP indoors, standard power 36 dBm with AFC in 5.925–6.425 and 6.525–6.875 GHz ([FCC 20-51](https://docs.fcc.gov/public/attachments/FCC-20-51A1.pdf)).

### 6 GHz security (all regions)

WPA3 specification v3.5 §11.2: on 6 GHz an AP allows only WPA3 (SAE with hash-to-element, or Enhanced Open / Enterprise), sets PMF Required, and allows no WPA2 or WPA3 transition mode ([Wi‑Fi Alliance](https://www.wi-fi.org/system/files/WPA3%20Specification%20v3.5.pdf)). A router that offers one SSID across 2.4/5/6 GHz therefore runs WPA3 at least on 6 GHz.

## How the router derives its region

The region reaches the radio in four steps, and each step can be read:

```
STEP                         WHERE                                         READ WITH
--------------------------   -------------------------------------------   ------------------------------------------
1. factory region            flash, copied to nvram at every boot          nvram get territory_code ; nvram get reg_spec
                                                                           nvram get wl_reg_2g ; nvram get wl_reg_5g
2. per-band country code     nvram wlX_country_code                         nvram get wl0_country_code ; … wl1_…
3. driver channel set        .dat CountryRegion (2.4 GHz),                 grep -h '^Country' /etc/Wireless/RT2860/RT2860.dat
                             CountryRegionABand (5 GHz), CountryCode        /etc/Wireless/iNIC/iNIC_ap.dat
4. resulting channel list    /tmp/chanspec_avbl.json, written at radio     cat /tmp/chanspec_avbl.json
                             start; the Control Channel dropdown reads it
```

`/tmp/chanspec_avbl.json` lists the channels the radio accepts, per band, e.g. `"5G":{"bandwidth":7,"channel":"36,40,44,48,149,153,157,161,165"}`; `/tmp/chanspec_avbl.txt` holds the same as text *(read on RT-AX53U 3.0.0.4.386_69196)*. `iwlist <if> channel` returns no list on this driver. A `Channel` value outside this list is accepted into nvram and the radio starts on another channel; `iwconfig rai0` / `iwconfig ra0` shows the channel actually in use.

**Country code → driver channel set.** ASUS's `gen_ralink_config` maps `wlX_country_code` to the driver region values (`ralink.c` in [SWRT-dev/swrt-gpl](https://github.com/SWRT-dev/swrt-gpl) at commit 604466e, a third-party build of ASUS's GPL code): 2.4 GHz `CountryRegion` = 0 for US, CA, MX, TW and a few others, 5 for DB or empty, 1 for every other code; 5 GHz `CountryRegionABand` = 18 for GB with 802.11h on, 13 for US/TW, 14 for CA, 23 for JP, 0 for CN, and a per-country value otherwise. The stock build's own result for any code is what the unit writes: `wlX_country_code` and the `.dat` `CountryRegionABand` read side by side, with the region table below giving the channel set. `CountryCode` in the `.dat` follows `territory_code` / `reg_spec` rather than `wlX_country_code`; the three read side by side show it.

**Persistence.** ASUS's boot code (`init_syspara`) rewrites `wlX_country_code` from the factory flash at every boot (`release/src/router/rc/sysdeps/init-ralink.c` in [RMerl/asuswrt-merlin](https://github.com/RMerl/asuswrt-merlin), commit 263449f); whether the stock RT-AX53U build does so is not established. A country code set through nvram is confirmed to survive by reading `wlX_country_code` and `/tmp/chanspec_avbl.json` after a reboot. RMerlin states the region is fixed in the bootloader on Broadcom models ([SNBForums thread](https://www.snbforums.com/threads/asus-ax88u-missing-control-channels.80425/), read via search extracts).

**MediaTek region tables** (MT7915 driver 7.3.0.1, [rt_channel.c](https://github.com/hanwckf/rt-n56u/tree/master/trunk/proprietary/rt_wifi/rtpci/7.3.0.1/mt7915); tables differ between driver versions, so the unit's `chanspec_avbl.json` is the authority):

```
CountryRegion (2.4 GHz)          CountryRegionABand (5 GHz)
-----------------------------    ---------------------------------------------
0  = 1–11                        0  = 36–64, 149–165      13 = 36–64, 100–144, 149–165
1  = 1–13                        1  = 36–64, 100–140      14 = 36–64, 100–116, 132–144, 149–165
2  = 10–11                       2  = 36–64               15 = 149–173
3  = 10–13                       3  = 52–64, 149–161      16 = 52–64, 149–165
4  = 14                          4  = 149–165             17 = 36–48, 149–161
5  = 1–14                        5  = 149–161             18 = 36–64, 100–116, 132–140
6  = 3–9                         6  = 36–48               19 = 56–64, 100–140, 149–161
7  = 5–13                        7  = 36–64, 100–140,     20 = 36–64, 100–124, 149–161
31 = 1–11 + 12–14 passive             149–165             21 = 36–64, 100–140, 149–161
32 = 1–11 + 12–13 passive        8  = 52–64               22 = 100–140
33 = 1–14                        9  = 36–64, 100–116,     23 = 36–64, 100–116, 132–144
                                      132–140, 149–165    24 = 100–144
                                 10 = 36–48, 149–165
                                 11 = 36–64, 100–120,
                                      149–161
                                 12 = 36–64, 100–144
```

## How clients choose their country

A client's legal channel list comes from its own regulatory setting, not the router's:

- **Android:** priority order override → mobile-network country → country from the driver or nearby AP beacons (only with no mobile country and while disconnected) → build default → world mode `00` ([AOSP WifiCountryCode.java](https://android.googlesource.com/platform/packages/modules/Wifi/+/refs/heads/main/service/java/com/android/server/wifi/WifiCountryCode.java)). Which channels a device scans follows its active country code, so a network on a channel outside that code's list can be missing from its scan results while a connect-by-name still succeeds; `dumpsys wifi` shows both the active code and the scan results.
- **Apple:** regulatory channels and power come from the device's location (Location Services must be on for Wi‑Fi networking) ([Apple, Recommended settings for Wi‑Fi routers](https://support.apple.com/en-us/102766)). `system_profiler SPAirPortDataType` shows the card's `Country Code` and `Supported Channels`.
- **Linux:** on seeing an AP's country information the kernel requests the regulatory rules for that domain ([kernel regulatory docs](https://wireless.docs.kernel.org/en/latest/en/developers/regulatory.html)).
