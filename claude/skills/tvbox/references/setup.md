# The living room

The user's own setup: which device connects to which, and which remote controls what. Cabling comes from the user's wiring diagram (August 2026); the control paths were read from the box on 2026-10-07. Re-read the control paths with the commands in [§ Checking it](#checking-it).

## Devices

```
DEVICE                 ROLE                       NOTES
--------------------   ------------------------   ----------------------------------------------------
Xiaomi TV Box S        source, everything daily   HDMI out; Bluetooth remote
Mac                    occasional source          native HDMI out, shares the box's cable
Yamaha YAS-209         soundbar, HDMI repeater    decodes PCM, Dolby Digital 5.1, DTS 5.1;
                                                  HDMI IN, HDMI OUT (ARC), TV optical in
Samsung UA40F5000      display only               2012/2013 model, 1080p, no HDR; ports HDMI (STB),
                                                  HDMI (DVI), optical out, RF, USB
```

## Wiring

One HDMI cable stays seated in the soundbar's HDMI IN; its other end plugs into whichever source is in use. All audio goes into the soundbar, and the TV receives picture only.

```
 ┌──────────────────┐  in use
 │ Xiaomi TV Box S  │─────────●╮
 │ HDMI out         │          │   Monoprice Ultra Slim, 8 ft, 36 AWG
 └──────────────────┘          │   (stays in the soundbar)
                               ├──────────────────────────────────┐
 ┌──────────────────┐          │                                  ▼
 │ Mac              │─ ─ ─ ─ ─○╯ swap the plug here      ┌──────────────────────┐
 │ HDMI out         │                                    │ Yamaha YAS-209       │
 └──────────────────┘                                    │ ● HDMI IN            │
                                                         │ ● HDMI OUT (ARC)     │
                                                         │ ○ TV optical (unused)│
                                                         └──────────┬───────────┘
                                                                    │ Club3D CAC-1311
                                                                    │ 1 m, 30 AWG, video only
                                                                    ▼
                                                         ┌──────────────────────┐
                                                         │ Samsung UA40F5000    │
                                                         │ ● HDMI (STB)         │
                                                         │ ○ HDMI (DVI) free    │
                                                         │ ○ optical out unused │
                                                         └──────────────────────┘
```

## Remotes

```
 ┌──────────────────────────┐   Bluetooth       ┌──────────────────────┐
 │ Xiaomi remote            │══════════════════▶│ Xiaomi TV Box S      │
 │ navigation, apps, voice  │                   │ (HDMI-CEC address 4) │
 │ YouTube button           │                   └──────────┬───────────┘
 │ volume                   │                              │ HDMI-CEC: volume keys,
 └──────────────────────────┘                              │ standby broadcast on sleep
                                                           ▼
 ┌──────────────────────────┐   rare            ┌──────────────────────┐
 │ Yamaha remote            │─ ─ ─ ─ ─ ─ ─ ─ ─ ▶│ Yamaha YAS-209       │
 │ input, sound modes,      │                   │ (HDMI-CEC address 5) │
 │ subwoofer level, bass    │                   └──────────────────────┘
 └──────────────────────────┘
 ┌──────────────────────────┐   power           ┌──────────────────────┐
 │ Samsung remote           │─ ─ ─ ─ ─ ─ ─ ─ ─ ▶│ Samsung TV           │
 │ TV power, picture        │                   │ (not on the CEC bus) │
 └──────────────────────────┘                   └──────────────────────┘
```

- The Xiaomi remote is paired over Bluetooth (bonded device "Xiaomi RC").
- Volume reaches the soundbar over HDMI-CEC: CEC volume control is on and the YAS-209 is the audio system at logical address 5.
- The TV does not appear on the CEC bus, and the box's `<Text View On>` messages to it go unanswered (`NACK`), so TV power is on the Samsung remote.
- The Netflix (`com.netflix.ninja`) and Prime Video (`com.amazon.amazonvideo.livingroom`) apps are disabled on the box; YouTube (`com.google.android.youtube.tv`) is enabled. The remote has Netflix, Prime Video and YouTube buttons (user diagram); its key layout (`/vendor/usr/keylayout/Vendor_2717_Product_32b9.kl`) maps the app buttons to generic `BUTTON_n` codes, and which app each one opens is handled by the box's software.

## Checking it

```
WHAT                              COMMAND (on the box)
-------------------------------   -----------------------------------------------------------------------
remote paired                     dumpsys bluetooth_manager | grep -A3 'Bonded devices'
CEC devices on the bus            dumpsys hdmi_control | grep -E 'logical_address|display_name|physical'
CEC volume / power settings       cmd hdmi_control cec_setting get volume_control_enabled
                                  cmd hdmi_control cec_setting get power_control_mode
TV answering CEC                  dumpsys hdmi_control | grep -E '40:0D|40:8F'   (ACK = answered)
streaming apps enabled            pm list packages -e | grep -iE 'youtube|netflix|amazon'
what the chain reports            cat /sys/class/amhdmitx/amhdmitx0/edid ; …/aud_cap ; …/disp_cap
```
