# Hardware: Xiaomi TV Box S (3rd Gen)

Sources: Xiaomi specifications ([S](https://www.mi.com/global/product/xiaomi-tv-box-s-3rd-gen/specs/)), Xiaomi FAQ ([F](https://www.mi.com/global/support/faq/details/KA-567165/)), AndroidPCTV review ([R](https://androidpctv.com/xiaomi-tv-box-s-3rd-gen-review/)), CNX Software SoC comparison ([C](https://www.cnx-software.com/2024/07/01/amlogic-s905x5m-vs-s905x4-features-and-benchmarks-comparison/)). On-device reads are marked *(read on MiTV-AFMU0)*.

```
ITEM            VALUE                                                              SOURCE
-------------   ----------------------------------------------------------------   ---------------------------
Model           MiTV-AFMU0, codename twilight                                      R; getprop ro.product.*
SoC             Amlogic S905X5M, 4× Cortex-A55 up to 2.5 GHz, 6 nm                 S (quad-core 2.5 GHz), F, R
                                                                                   (6 nm); getprop ro.soc.model
GPU             ARM Mali-G310 V2                                                   S, R
RAM             2 GB (DDR4 per R)                                                  S; /proc/meminfo
Storage         32 GB eMMC                                                         S, R; df -h /data
OS              Google TV, Android 14, 32-bit userspace                            R; getprop
Wi‑Fi           Wi‑Fi 6, 2.4 + 5 GHz, OFDMA, MU-MIMO; no 6 GHz listed;             F; getprop vendor.wlan.wifi_chip
                chip Amlogic W2
Bluetooth       5.2                                                                S, F
Ports           HDMI out ×1, USB 2.0 ×1, DC in; no Ethernet, no S/PDIF,            S, F
                no microSD
Video           up to 4K60; VP9 Profile-2 4K60, HEVC Main10 L5.1 4K60,             S, F; AV1 per R and C
                H.264 L5.1 4K30; AV1 (SoC)
HDR             Dolby Vision, HDR10+; HLG at SoC level                             S, F; C
Audio           Dolby Audio, DTS:X (S); Dolby Atmos (R)                            S, R
Remote          Bluetooth voice remote with IR (FAQ package list)                  F
Other           AirPlay, AISR (AI super-resolution)                                F
```

Where sources disagree:
- HDMI version: 2.1 (S), 2.1a (F, R), 2.1b at SoC level (C).
- IR: F says the box "doesn't support IR" and lists an "infrared + Bluetooth voice remote" in the package contents. The box's input devices include `ir_keypad` and the remote's Bluetooth HID (`dumpsys input`) *(read on MiTV-AFMU0)*.
- Size and weight: 97 × 97 × 17 mm, 91.2 g (S) vs 93 × 93 × 14 mm, 40 g measured (R).
- AV1 is not named on S or F; R and the SoC data (C) list it.

The output formats the box actually uses depend on the connected sink, read from its EDID ([av.md § HDMI sysfs](av.md#hdmi-sysfs-and-edid)).
