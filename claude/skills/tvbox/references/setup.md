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
