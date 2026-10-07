# Platform

How the box identifies itself, what the ADB shell user can do, and the read-only diagnostic tools. Values marked *(read on MiTV-AFMU0, build UKG3.250826.001.V816.0.11.0.UZFAABX)* come from the box; re-read them with the command shown. AOSP references are to the `android14-release` branch.

## Identity

```
WHAT                    COMMAND                                                   EXAMPLE
---------------------   -------------------------------------------------------   ------------------------------
model / device          getprop ro.product.model ; getprop ro.product.device      MiTV-AFMU0 / twilight
Android version / SDK   getprop ro.build.version.release ; …version.sdk           14 / 34
build                   getprop ro.build.display.id
security patch          getprop ro.build.version.security_patch
SoC                     getprop ro.soc.manufacturer ; getprop ro.soc.model        Amlogic / AMLS905X5M
platform                getprop ro.board.platform ; getprop ro.hardware            s7d / amlogic
CPU ABIs                getprop ro.product.cpu.abilist                            armeabi-v7a (32-bit userspace)
kernel                  uname -a
memory / storage        cat /proc/meminfo | head ; df -h /data
uptime                  uptime
```

Property meanings: [Build.java](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android14-release/core/java/android/os/Build.java), [SocProperties.sysprop](https://android.googlesource.com/platform/system/libsysprop/+/refs/heads/android14-release/srcs/android/sysprop/SocProperties.sysprop). `getprop` with no argument lists every property.

## The shell user

`adb shell` runs as uid 2000 (`shell`), SELinux domain `u:r:shell:s0`, with SELinux enforcing (`id`, `getenforce`). `getprop ro.build.type`, `ro.build.tags` and `ro.debuggable` read `user`, `release-keys` and `0` *(read on MiTV-AFMU0)*; `adb root` works only on debuggable builds ([adb docs](https://developer.android.com/tools/adb)).

The shell holds, among others ([Shell AndroidManifest.xml](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android14-release/packages/Shell/AndroidManifest.xml)): WRITE_SETTINGS, WRITE_SECURE_SETTINGS, WRITE_DEVICE_CONFIG, DUMP, READ_LOGS, INJECT_EVENTS, INSTALL_PACKAGES, DELETE_PACKAGES, CHANGE_COMPONENT_ENABLED_STATE, FORCE_STOP_PACKAGES, GRANT/REVOKE_RUNTIME_PERMISSIONS, MANAGE_APP_OPS_MODES, MANAGE_ROLE_HOLDERS, NETWORK_SETTINGS, CHANGE_WIFI_STATE, SET_TIME_ZONE, HDMI_CEC, MODIFY_USER_PREFERRED_DISPLAY_MODE, MODIFY_HDR_CONVERSION_MODE, SET_ANIMATION_SCALE, READ_FRAME_BUFFER.

Limits:
- Package state: shell can set a whole package to enabled, default or `disabled-user`, not `disabled`, and cannot change single components ([PackageManagerService.java](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android14-release/services/core/java/com/android/server/pm/PackageManagerService.java)). Details: [packages.md](packages.md).
- Files: shell writes to `/data/local/tmp` ([sepolicy shell.te](https://android.googlesource.com/platform/system/sepolicy/+/refs/heads/android14-release/public/shell.te)) and to shared storage `/sdcard` (group `sdcard_rw` in `id`; [adb docs](https://developer.android.com/tools/adb) use `/sdcard`); app data under `/data/data` and `/data/misc/adb` are denied.
- sysfs: platform policy allows reading, not writing; Amlogic HDMI nodes are partly readable on this box ([av.md § HDMI sysfs](av.md#hdmi-sysfs-and-edid)).

## ADB

**Ports and persistence.** adbd listens on TCP when `service.adb.tcp.port` is set, falling back to `persist.adb.tcp.port` ([adb daemon/main.cpp](https://android.googlesource.com/platform/packages/modules/adb/+/refs/heads/android14-release/daemon/main.cpp)). `adb tcpip <port>` sets `service.adb.tcp.port` and restarts adbd; `adb usb` sets it to 0. `service.*` properties live in memory only and are not written to `/data/property` (that holds `persist.*`) ([Android properties](https://source.android.com/docs/core/architecture/configuration/add-system-properties)). On this box network ADB does not come back after a reboot: the user re-enables Wireless debugging on the TV (Developer options › Wireless debugging), after which `adb connect <ip>:5555` succeeds again *(observed on MiTV-AFMU0 by the owner)*. A reboot started over ADB therefore ends with the user re-enabling Wireless debugging before anything can be read back. Read the state with `getprop service.adb.tcp.port`, `getprop persist.adb.tcp.port`, `settings get global adb_enabled`, `settings get global adb_wifi_enabled`, and on the Mac `nc -z -G 3 <ip> 5555`. From an authorized session, `adb tcpip 5555` starts a listener.

**Wireless debugging (pairing).** Android 13+ on TV supports Wireless debugging: the TV shows an IP, a pairing port and a code; `adb pair <ip>:<pairing port>` with the code, then `adb connect <ip>:<port shown>` ([developer.android.com/tools/adb](https://developer.android.com/tools/adb)). adbd turns Wireless debugging off when Wi‑Fi turns off or the network changes ([AdbDebuggingManager.java](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android14-release/services/core/java/com/android/server/adb/AdbDebuggingManager.java)).

**Authorization.** `ro.adb.secure=1`: each new host key must be accepted on the TV. The Mac's key is `~/.android/adbkey` (+ `.pub`); the box keeps accepted keys in `/data/misc/adb/adb_keys` (not readable by shell). A key accepted with "Always allow" reconnects without a prompt within `settings get global adb_allowed_connection_time` ms of its last use (default 604800000, 7 days, when the key is unset: `DEFAULT_ADB_ALLOWED_CONNECTION_TIME` in [Settings.java](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android14-release/core/java/android/provider/Settings.java)). Developer options › Revoke USB debugging authorizations clears all keys. `dumpsys adb` shows whether a host is connected.

**Developer options.** `settings get global development_settings_enabled` (1 = shown). They are revealed by selecting the build entry under About repeatedly, then found under Preferences/System › Developer options › Debugging ([developer.android.com TV setup](https://developer.android.com/training/tv/get-started/create)); AOSP TV Settings lists "USB debugging", "Wireless debugging" and "Revoke USB debugging authorizations" there ([development_prefs.xml](https://android.googlesource.com/platform/packages/apps/TvSettings/+/refs/heads/android14-release/Settings/res/xml/development_prefs.xml)).

## Logs and diagnostics

```
TOOL                         USE
--------------------------   --------------------------------------------------------------------------
logcat -d -t 500             last 500 lines; -b main|system|crash|events|all; -s TAG:PRIO; -g buffer sizes
logcat -d -b crash           native/Java crashes since the buffer last wrapped
dumpsys -l                   list of services; dumpsys <service> for one
dumpsys dropbox              system crash/ANR/boot entries kept across restarts (add --print for content)
dumpsys meminfo              per-process memory, totals, ZRAM; dumpsys meminfo <pkg> for one app
dumpsys cpuinfo ; top -n 1 -b   CPU per process
adb bugreport <path>         zip of dumpstate, dumpsys and logs
adb exec-out screencap -p > x.png         screenshot (secure/DRM windows are blacked out)
adb shell screenrecord /sdcard/x.mp4      video, no audio, max 180 s
```

Sources: [logcat](https://developer.android.com/tools/logcat), [dumpsys](https://developer.android.com/tools/dumpsys), [bug report](https://developer.android.com/studio/debug/bug-report), [adb screencap/screenrecord](https://developer.android.com/tools/adb). Logcat buffers are 256 KiB each on this box *(read on MiTV-AFMU0)*, so `logcat -d` covers minutes to hours depending on activity. CPU temperatures appear in logcat lines from `ThermalService` (`logcat -d | grep -i 'CPU temperatures'`).

The non-AOSP services on the box (`cmd -l`): `TvService`, `mitv.refresh.service`, `tvqs.TVQSService`, Amlogic `droidaudio`, `droidmdnsoffload`, `miracast_hdcp2`, Dolby `IMs12` (audio), and the PlayReady and Widevine DRM factories (alongside AOSP's ClearKey) *(read on MiTV-AFMU0)*.
