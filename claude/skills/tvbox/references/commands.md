# cmd services

`cmd -l` lists every service that accepts shell commands; `cmd <service> help` prints its usage on the box; `cmd audio help` prints nothing, and `cmd audio` alone prints the usage. Below, the subcommands that matter on a TV, from the box's own help output *(read on MiTV-AFMU0, Android 14)* and the AOSP sources cited. "read" marks commands that change nothing.

## package (pm)

```
pm list packages [-s system | -3 third-party | -d disabled | -e enabled | -u incl. uninstalled] [-f path] [-i installer]   read
pm path <pkg> ; pm dump <pkg>                                                                                          read
cmd package query-activities -a <action> -c <category>                                                                  read
cmd package resolve-activity --brief -a <action> -c <category>                                                          read
pm disable-user --user 0 <pkg>          package off for user 0; data kept
pm enable <pkg>                         back to enabled
pm default-state --user 0 <pkg>         back to the manifest default
pm uninstall -k --user 0 <pkg>          removed for user 0, APK stays on the system image
pm install-existing --user 0 <pkg>      restores a package removed with --user 0
pm suspend / unsuspend <pkg>            "Suspends the specified package(s)"
pm hide / unhide <pkg>
pm clear <pkg>                          deletes the app's data
pm grant / revoke <pkg> <permission>    runtime (dangerous) permissions only
cmd package set-home-activity <component>
cmd package compile -m speed-profile -f <pkg> ; cmd package bg-dexopt-job
pm uninstall-system-updates <pkg>       removes updates, falls back to the /system version
```

Source: [PackageManagerShellCommand.java](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android14-release/services/core/java/com/android/server/pm/PackageManagerShellCommand.java). Shell limits and states: [packages.md](packages.md).

## activity (am)

```
am start -n <pkg>/<activity> | -a <action> [-d <uri>]
am force-stop <pkg> ; am kill <pkg> ; am stop-app <pkg>
am broadcast -a <action>
am get-current-user ; am get-config                                read
am set-standby-bucket <pkg> active|working_set|frequent|rare|restricted ; am get-standby-bucket <pkg>
am send-trim-memory <pkg> <level>
```

Source: [ActivityManagerShellCommand.java](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android14-release/services/core/java/com/android/server/am/ActivityManagerShellCommand.java).

## wifi

The commands open to the shell are the `NON_PRIVILEGED_COMMANDS` set of [WifiShellCommand.java](https://android.googlesource.com/platform/packages/modules/Wifi/+/refs/heads/android14-release/service/java/com/android/server/wifi/WifiShellCommand.java); `cmd wifi help` on the box lists what its Wi‑Fi module offers. Among them: `status`, `get-country-code`, `list-networks`, `list-scan-results`, `start-scan`, `forget-network <id>`, `set-wifi-enabled enabled|disabled`, `set-scan-always-available`, `set-verbose-logging enabled|disabled`, `is-verbose-logging`, `add-suggestion` / `list-suggestions` / `remove-suggestion`, `start-softap` / `stop-softap`, `query-interface`, `take-bugreport`. `add-network`, `connect-network` and `force-country-code` require root on Android 14 (same source). `get-allowed-channel` fails for the shell with a SecurityException *(read on MiTV-AFMU0)*. With ADB running over Wi‑Fi, `set-wifi-enabled disabled` also removes the network the ADB session uses.

## display

```
cmd display get-displays                                         read
cmd display get-user-preferred-display-mode                      read
cmd display set-user-preferred-display-mode <w> <h> <rate>
cmd display clear-user-preferred-display-mode
cmd display get-active-display-mode-at-start <id>                read
cmd display get-match-content-frame-rate-pref                    read  (0 never, 1 seamless, 2 always)
cmd display set-match-content-frame-rate-pref <0|1|2>
cmd display get-user-disabled-hdr-types                          read
cmd display set-user-disabled-hdr-types <types…>
```

Source: [DisplayManagerShellCommand.java](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android14-release/services/core/java/com/android/server/display/DisplayManagerShellCommand.java). Android 14's display shell has no HDR-conversion command; the conversion mode is the `hdr_conversion_mode` setting ([settings.md § Display](settings.md#display-and-hdr)). Modes the TV accepts: [av.md § Display](av.md#display).

## hdmi_control

```
cmd hdmi_control cec_setting get <name>                          read
cmd hdmi_control cec_setting set <name> <value>
cmd hdmi_control onetouchplay                                    wake the TV and switch it to this source
cmd hdmi_control setsystemaudiomode on|off                       route audio control to the audio system
cmd hdmi_control setarc on|off
cmd hdmi_control deviceselect <id>
cmd hdmi_control vendorcommand --device_type <t> --destination <addr> --args <hex> [--id]
cmd hdmi_control history_size get|set <n>
```

Source: [HdmiControlShellCommand.java](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android14-release/services/core/java/com/android/server/hdmi/HdmiControlShellCommand.java). Setting names and values: [av.md § HDMI-CEC](av.md#hdmi-cec).

## audio and media

```
cmd audio get-encoded-surround-mode                              read
cmd audio set-encoded-surround-mode <0 auto|1 never|2 always|3 manual>
cmd audio get-is-surround-format-enabled <format>                read
cmd audio set-surround-format-enabled <format> true|false
cmd media_session list-sessions                                  read
cmd media_session dispatch play|pause|play-pause|stop|next|previous|rewind|fast-forward|mute
cmd media_session volume --stream 3 --get | --set <n> | --adj raise|lower|same
```

Sources: [AudioManagerShellCommand.java](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android14-release/services/core/java/com/android/server/audio/AudioManagerShellCommand.java), [MediaShellCommand.java](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android14-release/services/core/java/com/android/server/media/MediaShellCommand.java). Format numbers: [settings.md § Audio](settings.md#audio).

## power, role, appops, device_config, overlay

```
cmd power suppress-ambient-display <token> true|false ; list-ambient-display-suppression-tokens
cmd role get-role-holders android.app.role.HOME                  read
cmd role add-role-holder android.app.role.HOME <pkg> ; remove-role-holder ; clear-role-holders
cmd appops get <pkg> [op]                                        read
cmd appops set <pkg> <op> allow|ignore|deny|default
cmd device_config list [namespace] ; get <ns> <key>              read
cmd device_config put <ns> <key> <value>
cmd overlay list                                                 read
cmd overlay enable|disable <overlay pkg>
```

Sources: [PowerManagerShellCommand.java](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android14-release/services/core/java/com/android/server/power/PowerManagerShellCommand.java), [RoleShellCommand.java](https://android.googlesource.com/platform/packages/modules/Permission/+/refs/heads/android14-release/service/java/com/android/role/RoleShellCommand.java), [AppOpsService.java](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android14-release/services/core/java/com/android/server/appop/AppOpsService.java), [DeviceConfigService.java](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android14-release/packages/SettingsProvider/src/com/android/providers/settings/DeviceConfigService.java). The power shell has no sleep/wake subcommand; the `SLEEP`, `WAKEUP` and `POWER` key events below cover sleep and wake.

## time

`cmd time_zone_detector get_time_zone_state` (read), `is_auto_detection_enabled`, `set_auto_detection_enabled true|false`, `suggest_manual_time_zone …`; `cmd time_detector` has the matching time commands ([TimeZoneDetectorShellCommand.java](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android14-release/services/core/java/com/android/server/timezonedetector/TimeZoneDetectorShellCommand.java)).

## input (key events)

`input keyevent [--longpress|--doubletap] <code|name>`, plus `text`, `tap`, `swipe`, `keycombination` ([InputShellCommand.java](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android14-release/services/core/java/com/android/server/input/InputShellCommand.java)). TV keycodes ([KeyEvent.java](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android14-release/core/java/android/view/KeyEvent.java)):

```
HOME 3        DPAD_UP 19       VOLUME_UP 24        MEDIA_PLAY_PAUSE 85   MEDIA_PLAY 126    SETTINGS 176
BACK 4        DPAD_DOWN 20     VOLUME_DOWN 25      MEDIA_STOP 86         MEDIA_PAUSE 127   TV_POWER 177
              DPAD_LEFT 21     POWER 26            MEDIA_NEXT 87         VOLUME_MUTE 164   TV_INPUT 178
              DPAD_RIGHT 22    ENTER 66            MEDIA_PREVIOUS 88     INFO 165          SLEEP 223
              DPAD_CENTER 23   MENU 82             MEDIA_REWIND 89       GUIDE 172         WAKEUP 224
                               SEARCH 84           MEDIA_FAST_FORWARD 90 CAPTIONS 175      ALL_APPS 284
```

`SLEEP` does nothing if already asleep and `WAKEUP` nothing if awake; `TV_POWER` on an HDMI source toggles the TV over CEC and the source follows (KeyEvent.java).
