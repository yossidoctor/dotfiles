# cmd services

`cmd -l` lists every service that accepts shell commands, and `cmd <service> help` prints its syntax on the box; `cmd audio help` prints nothing, and `cmd audio` alone prints the usage. This file keeps what the help output does not say: which subcommands only read, and each service's gotchas *(read on MiTV-AFMU0, Android 14, and the AOSP sources cited)*. Every subcommand not listed as a read changes state.

## package (pm)

Reads: `pm list packages` (`-s` system, `-3` third-party, `-d` disabled, `-e` enabled, `-u` incl. uninstalled), `pm list users`, `pm path`, `pm dump`, `cmd package query-activities`, `cmd package resolve-activity --brief`. Without `--user`, `-e` and `-d` count a package enabled or disabled in any user, and the box has a second, stopped user (`10`, `new_user`) where packages disabled for user 0 stay enabled *(read on MiTV-AFMU0)*, so a state read takes `--user 0`. Which states the shell can set and how each is reversed: [packages.md](packages.md). `pm clear <pkg>` deletes the app's data, which no command restores. `pm trim-caches 100G` empties every app's cache (apps rebuild it); `dumpsys diskstats` gives per-package cache sizes, though its `App Cache Size` total refreshes on its own schedule while `Data-Free` shows the gain at once. `pm grant` / `revoke` reach runtime (dangerous) permissions only. Source: [PackageManagerShellCommand.java](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android14-release/services/core/java/com/android/server/pm/PackageManagerShellCommand.java).

## activity (am)

Reads: `am get-current-user`, `am get-config`, `am get-standby-bucket <pkg>`. Source: [ActivityManagerShellCommand.java](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android14-release/services/core/java/com/android/server/am/ActivityManagerShellCommand.java).

## wifi

The commands open to the shell are the `NON_PRIVILEGED_COMMANDS` set of [WifiShellCommand.java](https://android.googlesource.com/platform/packages/modules/Wifi/+/refs/heads/android14-release/service/java/com/android/server/wifi/WifiShellCommand.java). Reads: `status`, `get-country-code`, `list-networks`, `list-scan-results`, `list-suggestions`, `is-verbose-logging`, `query-interface`. `add-network`, `connect-network` and `force-country-code` require root on Android 14 (same source), and `get-allowed-channel` fails for the shell with a SecurityException *(read on MiTV-AFMU0)*. `set-wifi-enabled disabled` ends the ADB session ([platform.md § ADB](platform.md#adb)).

## display

Reads: `get-displays`, `get-user-preferred-display-mode`, `get-active-display-mode-at-start <id>`, `get-match-content-frame-rate-pref`, `get-user-disabled-hdr-types`; each `get-` has a `set-` (and the preferred mode a `clear-`) that writes. Frame-rate values: [settings.md § Display](settings.md#display-and-hdr). Android 14's display shell has no HDR-conversion command; the conversion mode is the `hdr_conversion_mode` setting (same section). Modes the TV accepts: [av.md § Display](av.md#display). Source: [DisplayManagerShellCommand.java](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android14-release/services/core/java/com/android/server/display/DisplayManagerShellCommand.java).

## hdmi_control

Reads: `cec_setting get <name>`, `history_size get`. Writes include `onetouchplay`, `setsystemaudiomode`, `setarc`, `deviceselect` and `vendorcommand`, each of which sends CEC messages to the TV or soundbar. Setting names, values, and what `onetouchplay` sends: [av.md § HDMI-CEC](av.md#hdmi-cec). Source: [HdmiControlShellCommand.java](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android14-release/services/core/java/com/android/server/hdmi/HdmiControlShellCommand.java).

## audio and media

Reads: `cmd audio get-encoded-surround-mode`, `cmd audio get-is-surround-format-enabled <format>`, `cmd media_session list-sessions`, `cmd media_session volume --stream 3 --get`. `cmd media_session dispatch …` acts on the playing session. Surround mode values: [av.md § Audio](av.md#audio); format numbers: [settings.md § Audio](settings.md#audio). Sources: [AudioManagerShellCommand.java](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android14-release/services/core/java/com/android/server/audio/AudioManagerShellCommand.java), [MediaShellCommand.java](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android14-release/services/core/java/com/android/server/media/MediaShellCommand.java).

## power, role, appops, device_config, overlay

Reads: `cmd power list-ambient-display-suppression-tokens`, `cmd role get-role-holders <role>`, `cmd appops get <pkg> [op]`, `cmd device_config list [namespace]` and `get <ns> <key>`, `cmd overlay list`. The power shell has no sleep/wake subcommand; the `SLEEP`, `WAKEUP` and `POWER` key events (§ input) cover sleep and wake. The HOME role: [packages.md § The home app](packages.md#the-home-app). Sources: [PowerManagerShellCommand.java](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android14-release/services/core/java/com/android/server/power/PowerManagerShellCommand.java), [RoleShellCommand.java](https://android.googlesource.com/platform/packages/modules/Permission/+/refs/heads/android14-release/service/java/com/android/role/RoleShellCommand.java), [AppOpsService.java](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android14-release/services/core/java/com/android/server/appop/AppOpsService.java), [DeviceConfigService.java](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android14-release/packages/SettingsProvider/src/com/android/providers/settings/DeviceConfigService.java).

## time

Reads: `cmd time_zone_detector get_time_zone_state`, `is_auto_detection_enabled`; `cmd time_detector` has the matching time commands ([TimeZoneDetectorShellCommand.java](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android14-release/services/core/java/com/android/server/timezonedetector/TimeZoneDetectorShellCommand.java)).

## input (key events)

`input keyevent [--longpress|--doubletap] <code|name>`, plus `text`, `tap`, `swipe`, `keycombination` ([InputShellCommand.java](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android14-release/services/core/java/com/android/server/input/InputShellCommand.java)). The key names worth knowing on a TV: `HOME`, `BACK`, `DPAD_UP|DOWN|LEFT|RIGHT|CENTER`, `ENTER`, `MENU`, `SETTINGS`, `GUIDE`, `INFO`, `CAPTIONS`, `SEARCH`, `ALL_APPS`, `MEDIA_PLAY_PAUSE` and its siblings, `VOLUME_UP|DOWN|MUTE`, `TV_INPUT`, `TV_POWER`, `POWER`, `SLEEP`, `WAKEUP`; every name and number: [KeyEvent.java](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android14-release/core/java/android/view/KeyEvent.java). `SLEEP` does nothing if already asleep and `WAKEUP` nothing if awake; what `TV_POWER` does over CEC: [av.md § HDMI-CEC](av.md#hdmi-cec).
