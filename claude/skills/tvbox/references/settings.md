# Settings

The `settings` command and the keys that matter on a TV. Meanings come from AOSP [Settings.java](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android14-release/core/java/android/provider/Settings.java) unless marked OEM. The box's full key lists: `settings list global`, `settings list secure`, `settings list system` (they include identifiers such as `android_id` and `bluetooth_address`).

## The command

```
settings get    [--user N|current] <global|secure|system> <key>
settings put    [--user N|current] <global|secure|system> <key> <value> [tag] [default]
settings delete [--user N|current] <global|secure|system> <key>
settings list   [--user N|current] <global|secure|system>
settings reset  [--user N|current] <global|secure> <package | untrusted_defaults | untrusted_clear | trusted_defaults>
```

([SettingsService.java](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android14-release/packages/SettingsProvider/src/com/android/providers/settings/SettingsService.java)). `get` prints `null` for a key that has no row. A key no component reads can still be written and read back; whether a key is live is shown by the component that owns it (its `dumpsys` or `cmd … get-…`).

## Sleep, screensaver, power

```
KEY                                   NS       MEANING
-----------------------------------   ------   ----------------------------------------------------------------
screen_off_timeout                    system   ms of inactivity before the screen sleeps or the screensaver starts
sleep_timeout                         secure   ms before full sleep (upper bound while dreaming); -1 = never
attentive_timeout                     secure   sleep even while wakelocks are held; -1 = never
stay_on_while_plugged_in              global   0 = off; else bitmask of power sources that keep it awake
screensaver_enabled                   secure   1/0
screensaver_components                secure   component(s) used as screensaver
screensaver_default_component         secure   default screensaver component
screensaver_activate_on_sleep         secure   1 = start the screensaver instead of sleeping
screensaver_activate_on_dock          secure   1 = start when docked/charging (dumpsys dreams reports
                                               mIsCharging=true on mains power)
```

Live values: `dumpsys power | grep -E 'mScreenOffTimeoutSetting|mSleepTimeoutSetting|mAttentiveTimeoutSetting|mDreams|mStayOn'` and `dumpsys dreams`. Google TV's screensaver is "Ambient mode" (`com.google.android.apps.tv.dreamx`), with sources chosen in Settings › System › Ambient mode ([Google TV Help](https://support.google.com/googletv/answer/10070821)). OEM keys on this box: `ambient_enabled`, `ambient_plugged_timeout_min`, `screen_off_control`, `mi_screen_off_from_settings` *(read on MiTV-AFMU0; no public definition)*.

## Display and HDR

```
KEY                                     NS       MEANING
-------------------------------------   ------   -------------------------------------------------------
user_preferred_resolution_width/height  global   user-chosen output resolution
user_preferred_refresh_rate             global   user-chosen refresh rate
match_content_frame_rate                secure   0 never, 1 seamless only (default), 2 always
hdr_conversion_mode                     global   0 unsupported, 1 passthrough, 2 system, 3 force
hdr_force_conversion_type               global   with mode 3: -1 SDR, 1 Dolby Vision, 2 HDR10, 3 HLG, 4 HDR10+
user_disabled_hdr_formats               global   HDR types hidden from apps
are_user_disabled_hdr_formats_allowed   global   1 = the disabled list is ignored
minimal_post_processing_allowed         secure   1 = apps may request the TV's low-latency mode (ALLM)
```

The display service owns these; they are set through `cmd display` ([commands.md § display](commands.md#display)) and read back from `dumpsys display`. HDR enum values: [HdrConversionMode.java](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android14-release/core/java/android/hardware/display/HdrConversionMode.java), [Display.java](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android14-release/core/java/android/view/Display.java). OEM key: `display_scale_factor_1080p` (overscan percentage) *(read on MiTV-AFMU0)*.

## Audio

```
KEY                                       NS       MEANING
---------------------------------------   ------   -------------------------------------------------
encoded_surround_output                   global   0 auto, 1 never, 2 always, 3 manual
encoded_surround_output_enabled_formats   global   with 3: comma list of AudioFormat encodings
```

AudioFormat encodings: AC3 = 5, E_AC3 = 6, DTS = 7, DTS_HD = 8, DOLBY_TRUEHD = 14, AC4 = 17, E_AC3_JOC = 18, DOLBY_MAT = 19, DTS_UHD_P1 = 27, DTS_HD_MA = 29, DTS_UHD_P2 = 30 ([AudioFormat.java](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android14-release/media/java/android/media/AudioFormat.java)). The audio service applies them; `cmd audio get-encoded-surround-mode` reads the live mode ([av.md § Audio](av.md#audio)).

## HDMI-CEC

Android 14 keeps CEC configuration in the HDMI service's own store (`HdmiCecConfig`), not in `settings` ([HdmiCecConfig.java](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android14-release/services/core/java/com/android/server/hdmi/HdmiCecConfig.java)); it is read and written with `cmd hdmi_control cec_setting get|set <name>` ([av.md § HDMI-CEC](av.md#hdmi-cec)). Keys named `hdmi_control_*` in the global table (`hdmi_control_auto_device_off_enabled`, `hdmi_control_one_touch_play_enabled`, `hdmi_control_volume_control_enabled`, `hdmi_control_auto_language_change_enabled`) and `droidlogic_cec_support` exist on this box *(read on MiTV-AFMU0)* but are not defined in Android 14's Settings.java; whether the Amlogic/Xiaomi framework reads them is not established. `hdmi_cec_set_menu_language_denylist` (secure) is AOSP.

## Network and Wi-Fi settings

```
KEY                        NS       MEANING
------------------------   ------   ---------------------------------------------------------------
private_dns_mode           global   off, opportunistic, hostname
private_dns_specifier      global   DoT hostname used when mode = hostname
wifi_on                    global   1/0
wifi_scan_always_enabled   global   deprecated in favour of WifiManager; scanning while Wi‑Fi is off
wifi_sleep_policy          global   deprecated: "no longer used or set by the platform"
wifi_wakeup_enabled        global   deprecated
```

Private DNS mode strings: [ConnectivitySettingsUtils.java](https://android.googlesource.com/platform/frameworks/libs/net/+/refs/heads/android14-release/common/framework/com/android/net/module/util/ConnectivitySettingsUtils.java). The live state is the `UsePrivateDns` / `ValidatedPrivateDnsAddresses` fields of `dumpsys connectivity` ([network.md § Private DNS](network.md#private-dns)). Wi‑Fi detail: [network.md](network.md).

## Debugging, installs, setup

```
KEY                            NS       MEANING
----------------------------   ------   ---------------------------------------------------------
adb_enabled                    global   ADB over USB / network listener on
adb_wifi_enabled               global   Wireless debugging (pairing) on
adb_allowed_connection_time    global   ms an "Always allow" key stays trusted since last use
development_settings_enabled   global   Developer options shown
verifier_verify_adb_installs   global   1 = verify ADB installs (default), 0 = skip
verifier_timeout               global   ms for package verification
install_non_market_apps        secure   deprecated since Android 8 (per-app "install unknown apps" replaces it)
user_setup_complete            secure   setup wizard finished
tv_user_setup_complete         secure   TV setup finished
device_provisioned             global   device provisioned
```

## Time, location, accessibility, animation

```
KEY                                   NS       MEANING
-----------------------------------   ------   ------------------------------------------------------
auto_time, auto_time_zone             global   network time / time zone (the time_detector services own them)
location_mode                         secure   deprecated: 0 off, 1 sensors, 2 battery saving, 3 high accuracy
accessibility_enabled                 secure   1/0
enabled_accessibility_services        secure   enabled services
window_animation_scale                global   float; 0 = off
transition_animation_scale            global   float; 0 = off
animator_duration_scale               global   float; 0 = off
```

The time zone is the property `persist.sys.timezone` (`getprop`); `cmd time_zone_detector get_time_zone_state` shows how it was chosen ([commands.md § time](commands.md#time)). No `time_zone` key is defined in Android 14.

## Telemetry and error reporting

```
KEY                              NS                MEANING
------------------------------   ---------------   ---------------------------------------------------
send_action_app_error            global            1 = send ACTION_APP_ERROR when an app crashes (AOSP;
                                                   listed in Secure's MOVED_TO_GLOBAL; a secure row
                                                   can still exist)
activity_starts_logging_enabled  global            1 = log activity starts to the events buffer (AOSP)
upload_log_pref                  secure            OEM log upload preference (no public definition)
```

Telemetry also runs inside packages (analytics and feedback apps); their state is in [packages.md](packages.md). Whether a written value survives is confirmed by reading it again after a reboot.
