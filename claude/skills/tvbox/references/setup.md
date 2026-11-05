# The living room

The user's own setup: which device connects to which, and which remote controls what. Cabling comes from the user's wiring diagram (August 2026); the control paths were read from the box on 2026-10-07. Re-read the control paths with the commands in [§ Checking it](#checking-it).

## Devices

```
DEVICE                 ROLE                       NOTES
--------------------   ------------------------   ----------------------------------------------------
Xiaomi TV Box S        unplugged; the TV's own    HDMI out; Bluetooth remote
                       apps are the daily source
Mac                    occasional source          native HDMI out, shares the box's cable; AirPlay
                                                  to the TV
Yamaha YAS-209         soundbar, HDMI repeater    decodes PCM, Dolby Digital 5.1, DTS 5.1;
                                                  HDMI IN, HDMI OUT (ARC), TV optical in
Samsung UA65AU7700KXXT display                    2021 AU7700, 65" 4K60 VA, HDR10 / HDR10+ / HLG, no
                                                  Dolby Vision; HDMI 1–3 (HDMI 3 eARC), USB, LAN,
                                                  optical out, ANT IN; Wi‑Fi 5, BT 4.2; Tizen 6.0;
                                                  remotes TM2180A Smart Control + TM1240A (Samsung TH)
```

## The TV

Samsung UA65AU7700KXXT (Thai-market SKU), bought second-hand in November 2026 and factory reset. Settings › Support › About This TV (user photo, 2026-11-04) reads software `T-KSU2EUABC-2310.0`, Sub-micom `T-KUEINTV-1107`; the same screen shows the serial number. Its QR code encodes `MN` model, `PD` production date (blank on this unit), `SN` serial, `FW` firmware, `FC` firmware package (`SWU-OU_T-KSU2EUABC_2310_260721`), `MI` firmware line (`T-KSU2EUABC`), `LS` region (`ED_THAI`), `DI` a device ID, `MA` a MAC address that differs from the Wi‑Fi one in the router's lease table, and `SC` the status code; serial, device ID and MAC are kept out of this public file. Specs: [Samsung TH business page](https://www.samsung.com/th/business/tvs/uhd-4k-tv/tv-65-uhd-series-au7700-ua65au7700kxxt/) (VESA 400 × 300) and retailer listings ([IRIS](https://iristechworld.com/product/samsung-tv-65-uhd-series-au7700-ua65au7700kxxt/): 1449.4 × 830.3 × 59.9 mm and 20.6 kg without stand, 1449.4 × 906.6 × 282.1 mm and 20.9 kg with it, stand footprint 1185.5 × 282.1 mm, 200 W max, 20 W 2-channel speakers). Reviews of the AU7700 line describe a VA panel with no local dimming ([Tecnoblog](https://tecnoblog.net/testamos/tv-4k-samsung-au7700-review/), [Canaltech](https://canaltech.com.br/produtos/review-samsung-au7700-195855/)); neither tested the 65". Model years map to Tizen versions in [Samsung's general specifications](https://developer.samsung.com/smarttv/develop/specifications/general-specifications.html) (2021: Tizen 6.0).

What reaches the TV through the soundbar: 4K60 with HDR10 or HLG. The YAS-209 passes neither HDR10+ nor Dolby Vision ([Yamaha specs](https://usa.yamaha.com/products/audio_visual/sound_bar/yas-209/specs.html)), and Samsung TVs have no Dolby Vision. Over ARC the TV sends Dolby Digital or DD+ and never DTS; multichannel PCM needs eARC, which the YAS-209 lacks ([Samsung ARC/eARC table](https://www.samsung.com/ph/support/tv-audio-video/what-is-earc-and-how-to-set-on-samsung-smart-tv/)); the YAS-209 decodes Dolby Digital but not DD+. Settings › Sound › Expert Settings (user photos, Hebrew menu) holds Balance and Equalizer (greyed out while sound goes to the soundbar), HDMI-eARC Mode, Digital Output Audio Format with PCM / Auto / Pass-through and no Dolby Digital entry, Digital Output Audio Delay (lip-sync offset, offered only with a device on HDMI-ARC or eARC), Dolby Atmos and Auto Volume. Auto picks a format from what the soundbar reports it accepts; PCM is stereo; Pass-through forwards an HDMI source's audio unprocessed and, per the menu's own help text, only to a receiver on HDMI-eARC, which the YAS-209 is not.

Tizen has no ADB or other owner shell. Its settings are changed in its menus; what can be driven from outside it:

```
CHANNEL                 REACHES                                   NEEDS
---------------------   ---------------------------------------   -------------------------------------
HDMI-CEC via the box    power on/off, switch to the box's input   Anynet+ on; box ADB (av.md § HDMI-CEC)
local WebSocket API     remote keys, app list/launch, browser     TV on LAN; approve once on screen;
 (wss://<ip>:8002)                                                token (samsungtvws)
REST info               model, firmware, network details          http://<ip>:8001/api/v2/
SmartThings API         input, picture mode, volume, apps         Samsung account + cloud token
Wake-on-LAN             power on                                  wired LAN only
Developer Mode          install own Tizen apps (removed on        Apps › 12345, Tizen Studio
                        power-off)
```

Sources: [samsungtvws](https://github.com/xchwarze/samsung-tv-ws-api) (WebSocket and REST), [ioBroker.samsung_tizen](https://github.com/iobroker-community-adapters/ioBroker.samsung_tizen) (Wake-on-LAN wired only), [SmartThings example](https://knowledgebase.grenton.com/en/sterowanie-telewizorem-poprzez-smarthings), [Samsung Developer Mode guide](https://developer.samsung.com/smarttv/develop/getting-started/using-sdk/tv-device.html).

Privacy on a networked Samsung: Terms & Privacy › Privacy Choices (under Settings › Support on 2020–2021 menus, Settings › General & Privacy on later ones) holds Viewing Information Services (ACR, the on-screen content recognition) and Interest-Based Ads; firmware updates and new terms can switch them back on ([SmartTVs.org](https://smarttvs.org/stop-smart-tv-ads/)). DNS blocklists for Samsung ACR, ads and analytics that leave updates and apps working: [Okazakee/tv-dns-blocklist](https://github.com/Okazakee/tv-dns-blocklist).

## Wiring

One HDMI cable stays seated in the soundbar's HDMI IN; its other end plugs into whichever source is in use. The source's audio stays in the soundbar and its picture passes on to the TV; the TV's own apps and AirPlay send their sound back to the soundbar over ARC on the same cable that carries the picture to HDMI 3.

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
                                                                    │ 1 m, 30 AWG, video down, ARC up
                                                                    ▼
                                                         ┌──────────────────────┐
                                                         │ Samsung UA65AU7700   │
                                                         │ ● HDMI 3 (eARC)      │
                                                         │ ○ HDMI 1, 2 free     │
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
 │ TV power, picture,       │                   │ (Anynet+ = HDMI-CEC) │
 │ soundbar volume (CEC)    │                   │                      │
 └──────────────────────────┘                   └──────────────────────┘
```

- The Xiaomi remote is paired over Bluetooth (bonded device "Xiaomi RC").
- Volume reaches the soundbar over HDMI-CEC: CEC volume control is on and the YAS-209 is the audio system at logical address 5.
- The TV joins the CEC bus when Anynet+ is on (Settings › General › External Device Manager), and the Samsung remote's volume keys then move the soundbar's volume (user, 2026-11-04). Whether the TV answers the box's `<Text View On>` is read with [§ Checking it](#checking-it). While it answers, the box turns it on and off; otherwise TV power is on the Samsung remote.
- The remote has Netflix, Prime Video and YouTube buttons (user diagram); which of those apps are installed and enabled is in [§ Apps on the box](#apps-on-the-box). Its key layout (`/vendor/usr/keylayout/Vendor_2717_Product_32b9.kl`) maps the app buttons to generic `BUTTON_n` codes, and which app each one opens is handled by the box's software.

## Apps on the box

What the user chose to switch off and why. The box holds the live state, `pm list packages -d --user 0`, `pm list packages -u` minus `pm list packages --user 0` for the uninstalled, and `cmd appops get <pkg> RUN_ANY_IN_BACKGROUND`; a package below that reads enabled again was turned back on by an update or a reset, and the user decides whether it goes again. How each state is set and reversed: [packages.md](packages.md).

**Home screen.** LtvLauncher (`com.leanbitlab.ltvL`, GPL-3, `armeabi-v7a` build from [its GitHub releases](https://github.com/leanbitlab-org/LtvLauncher/releases)) answers the Home key through its accessibility service `com.leanbitlab.ltvL/.LauncherAccessibilityService` ("Home Button Fix"), and holds the HOME role, with Google TV's home (`launcherx`) disabled. The setup wizard stays enabled for the screensaver, so its `RecoveryActivity` (HOME priority 1) is what Android opens at boot: about 10 s of black screen, then LtvLauncher. Choosing a different screensaver album takes `launcherx` enabled for the duration ([packages.md § The home app](packages.md#the-home-app)). Projectivy (closed source, 175–265 MB PSS here) and Arc Launcher (no accessibility service of its own) were weighed and are not installed.

```
DISABLED (pm disable-user --user 0)            WHY
--------------------------------------------   -------------------------------------------------
com.google.android.apps.tv.launcherx           replaced by LtvLauncher (above)
com.xiaomi.mi_connect_service                  Xiaomi phone link: unused
com.xiaomi.android.tvsetup.partnercustomizer   Xiaomi setup tweaks: unused after setup
com.xiaomi.wfdsinkhelperservice                Miracast: unused
com.xiaomo.tv.milegal, com.xm.webcontent       Xiaomi legal pages, Xiaomi web viewer
com.android.printspooler                       printing
com.android.dynsystem                          installing test system images
com.android.healthconnect.controller,          Health Connect: no use on a TV
 com.android.health.connect.backuprestore
com.android.adservices.api,                    ad targeting and personalization
 com.android.ondevicepersonalization.services,
 com.android.federatedcompute.services
com.google.android.marvin.talkback             screen reader: unused
android.autoinstalls.config.soc.amlogic        Play Auto Install config: installs partner apps
com.google.android.syncadapters.calendar       calendar sync: nothing on the TV reads it
other Xiaomi, Google, Amazon and Netflix       disabled by an earlier debloat; reasons
 packages in pm list packages -d --user 0       not recorded
```

```
UNINSTALLED FOR USER 0 (pm uninstall --user 0)   WHY
----------------------------------------------   -----------------------------------------------
com.netflix.ninja                                Netflix: not wanted
```

```
BACKGROUND-RESTRICTED                WHY
----------------------------------   -------------------------------------------------------
com.google.android.youtube.tv        stops its home-screen recommendations process
org.videolan.vlc                     plays only with the app open
```

Telemetry settings the user turned off ([settings.md § Telemetry](settings.md#telemetry-and-error-reporting)): `send_action_app_error` 0 in global and secure (crash reports), `upload_log_pref` 0 in secure (Xiaomi's log-upload preference; whether `mitv.service` honours it is not established). On the TV itself: Settings › Privacy › Usage & Diagnostics off, and Ads › Delete advertising ID; those live in Play services, out of the shell's reach.

Kept on purpose: the Google Photos screensaver (`com.google.android.apps.tv.dreamx`) and the two packages its album playback needs, the setup wizard (`com.google.android.tungsten.setupwraith`) and Chromecast built-in (`com.google.android.apps.mediashell`) ([packages.md § The home app](packages.md#the-home-app)). Offered and not chosen: the Assistant (`com.google.android.katniss`), the phone-remote service (`com.google.android.tv.remote.service`), Xiaomi system updates (`com.xiaomi.mitv.updateservice`) and Spotify's background (Spotify Connect).

## Movies share

VLC on the box (`org.videolan.vlc`) plays from the Mac's `~/Movies`, which macOS File Sharing serves over SMB as share `Movies`. The VLC favorite names the Mac by IP (`smb://<Mac IP>/Movies`), which the router's DHCP reservation holds fixed ([router skill, wan-lan.md § DHCP](../../router/references/wan-lan.md#dhcp)); read it back by long-pressing the favorite. VLC's SMB2/3 client resolves only DNS names and IPs: a NetBIOS name such as the Mac's `NetBIOSName` fails with `smb2_connect_share_async failed: -5, Invalid address:<name>  Can not resolv into IPv4/v6.`

- Whether VLC asks for a login depends on two Mac settings: the share's own `guest access` (`sharing -l`) and Mac-wide SMB guest access (`sysadminctl -smbGuestAccess status`). Guests get in only when both are on; otherwise VLC prompts and the login is the Mac account name and its login password.
- VLC caches the login it was given and logs it (`Creds: username = '…', domain = '…'`), with no password. A rejected login logs `Unable to login`.
- `VLC is unable to open the MRL 'smb://…/<folder>'` also appears for folders on a share VLC is logged into and streaming from; on its own it is not an access failure.
- `SMB 2/3 disabled by the user, using *unsafe* SMB 1` means VLC › Settings › Advanced › Prefer SMB 1 is ticked.
- Driving VLC over ADB: `uiautomator dump` lists on-screen text, bounds and checkbox state; `input keyevent --longpress KEYCODE_DPAD_CENTER` opens a favorite's actions (Browse, Remove, Edit) and its URL. In the add-server dialog the fields move after the protocol is chosen, so re-dump before tapping; `input text` types regardless of the on-screen keyboard's language.

## Checking it

```
WHAT                              COMMAND (on the box)
-------------------------------   -----------------------------------------------------------------------
remote paired                     dumpsys bluetooth_manager | grep -A3 'Bonded devices'
CEC devices on the bus            dumpsys hdmi_control | grep -E 'logical_address|display_name|physical'
CEC volume / power settings       cmd hdmi_control cec_setting get volume_control_enabled
                                  cmd hdmi_control cec_setting get power_control_mode
TV answering CEC                  dumpsys hdmi_control | grep -E '40:0D|40:8F'   (ACK = answered)
streaming apps enabled            pm list packages -e --user 0 | grep -iE 'youtube|netflix|amazon'
what the chain reports            cat /sys/class/amhdmitx/amhdmitx0/edid ; …/aud_cap ; …/disp_cap
VLC's SMB logins and errors       logcat -d | grep ' VLC ' | grep -iE 'creds|login|unable'
```

```
WHAT                              COMMAND (on the Mac)
-------------------------------   -----------------------------------------------------------------------
share and its guest flag          sharing -l
Mac-wide SMB guest access         sysadminctl -smbGuestAccess status
Mac's NetBIOS name                defaults read /Library/Preferences/SystemConfiguration/com.apple.smb.server NetBIOSName
box connected to the share        netstat -an -p tcp | grep '\.445 '
```
