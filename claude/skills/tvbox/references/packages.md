# Packages and the home app

Package states, how each is reversed, which app is the home screen, and runtime resource overlays. AOSP references are to `android14-release`.

## Package states

```
STATE              SET WITH                                SEEN IN                      REVERSED WITH
----------------   -------------------------------------   --------------------------   ---------------------------------
disabled-user      pm disable-user --user 0 <pkg>          pm list packages -d          pm enable <pkg>
uninstalled for    pm uninstall -k --user 0 <pkg>          pm list packages -u, absent  pm install-existing --user 0 <pkg>
 user 0 (system)                                           from plain list
suspended          pm suspend <pkg>                        pm dump <pkg> | grep -i      pm unsuspend <pkg>
                                                           suspended
hidden             pm hide <pkg>                           pm dump <pkg> | grep hidden  pm unhide <pkg>
updated system     (Play Store / install)                  pm dump <pkg> | grep         pm uninstall-system-updates <pkg>
 app                                                       versionName (two entries)    (back to the /system version)
background-        cmd appops set <pkg>                    cmd appops get <pkg>         cmd appops set <pkg>
 restricted          RUN_ANY_IN_BACKGROUND ignore;         RUN_ANY_IN_BACKGROUND        RUN_ANY_IN_BACKGROUND allow;
                   cmd appops write-settings                                            cmd appops write-settings
```

A background-restricted app runs normally while it is on screen and gets no background jobs, alarms or services otherwise, so it is the lever for a third-party app that should stay usable. App-op changes are held in memory and written to `/data/system/appops.xml` later; `cmd appops write-settings` writes them now (its `help` text: "Immediately write pending changes to storage"). Reboots go through the framework, which saves pending state ([platform.md § ADB](platform.md#adb)).

A process name is not always a package: `com.google.android.youtube.tv.recommendations` is a process of `com.google.android.youtube.tv`, and `pm disable-user` on it fails with `Unknown package`. The owner is found by uid: `ps -A -o USER,NAME` gives `u0_a82`, which is uid 10082, and `pm list packages -U | grep uid:10082` names the package.

The shell user can set a whole package to enabled, default or disabled-user only; per-component changes and `pm disable` are refused, and some packages are protected from any change ([PackageManagerService.java](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android14-release/services/core/java/com/android/server/pm/PackageManagerService.java)). `pm uninstall --user 0` on a system app removes it for that user only; the APK stays on the read-only system partition, which is why `install-existing` brings it back ([PackageManagerShellCommand.java](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android14-release/services/core/java/com/android/server/pm/PackageManagerShellCommand.java)). `pm dump <pkg>` prints the per-user state fields `installed=`, `hidden=`, `suspended=` and `enabled=` (0 default, 1 enabled, 2 disabled, 3 disabled-user).

Counts: `pm list packages | wc -l`, with `-s` (system), `-3` (third-party), `-e` (enabled), `-d` (disabled). What a package is: `pm path <pkg>` (where its APK lives: `/system`, `/product`, `/vendor` or `/data/app`), `pm dump <pkg> | grep -E 'versionName|enabled=|installerPackageName'`, `cmd package query-activities` for its entry points, and `dumpsys package <pkg> | grep -A20 'declared permissions\|requested permissions'`.

## The home app

The home screen is whichever app holds the `android.app.role.HOME` role, chosen among activities with `MAIN` + `HOME` intent filters:

```
cmd role get-role-holders android.app.role.HOME                                   current holder
cmd package query-activities -a android.intent.action.MAIN -c android.intent.category.HOME
                                                                                   every candidate with its priority
cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME
                                                                                   the one that resolves now
```

When no holder is set, the fallback is the single highest-priority HOME activity, and a tie produces no fallback ([HomeRoleBehavior.java](https://android.googlesource.com/platform/packages/modules/Permission/+/refs/heads/android14-release/PermissionController/role-controller/java/com/android/role/controller/behavior/HomeRoleBehavior.java)). Only privileged (system) apps may declare an intent-filter priority above 0 ([ComponentResolver.java](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android14-release/services/core/java/com/android/server/pm/resolution/ComponentResolver.java)), so a system launcher with priority above 0 outranks any installed launcher. On this box an enabled `launcherx` takes the HOME key whatever else is set: with the role held by another launcher and `cmd package set-home-activity` pointing at it, `resolve-activity` and the HOME key both still land on `launcherx/.home.HomeActivity` *(observed on MiTV-AFMU0)*, so another launcher becomes home only with `launcherx` disabled, or through an accessibility service of the launcher's own that catches the Home key: LtvLauncher's `.LauncherAccessibilityService`, enabled with `settings put secure enabled_accessibility_services <pkg>/<service>` and `accessibility_enabled 1`, opens LtvLauncher on a Home press from the remote, while an injected `input keyevent HOME` still reaches `launcherx` *(observed on MiTV-AFMU0)*. Button Mapper (`flar2.homebutton`) never recorded the remote's Home key, with `launcherx` enabled or disabled. On Google TV the candidates are `com.google.android.apps.tv.launcherx` (Google TV home), `com.google.android.tungsten.setupwraith` (setup/recovery) and `com.android.tv.settings/.system.FallbackHome` *(read on MiTV-AFMU0: priorities 2, 1, −1000)*.

Replacing the home screen with an installed launcher takes three commands, in this order, so a home screen exists at every step:

1. `cmd role add-role-holder android.app.role.HOME <pkg>`; HOME reaches the new launcher once step 2 disables `launcherx`.
2. `pm disable-user --user 0 com.google.android.apps.tv.launcherx`, which stops both of its processes (`launcherx` and `launcherx:coreservices`, about 160 MB PSS together *(read on MiTV-AFMU0)*). The Google screensaver (`dreamx`) depends on three packages for Google Photos *(observed on MiTV-AFMU0, from `dreamx`'s log)*:
   - `launcherx`: the account for choosing albums, from `launcherx.coreservices.account.AccountModeContentProvider`; without it "Select albums" closes at once (`Failed to find provider info`). An album already chosen keeps playing with `launcherx` disabled, across a reboot, so an album change takes `launcherx` enabled for its duration.
   - `com.google.android.tungsten.setupwraith`: the device's cast setup info, from its `CastInfoProvider`; without it the sign-in token never arrives (`JWT token not available`) and the album list reads "Unable to load content".
   - `com.google.android.apps.mediashell` (Chromecast built-in): the cast device ID, from `localhost:8008`; without it `Getting device settings needs cast device ID`. After `pm enable` it serves 8008 only from the next boot.
3. `pm disable-user --user 0 com.google.android.tungsten.setupwraith`, because setupwraith is reported to re-enable the stock launcher ([gist](https://gist.github.com/SMUsamaShah/25a1c4958fcdfe87db49da18f66dbf7a)). Disabling it is reported to drop the saved Wi‑Fi network on some devices ([XDA](https://xdaforums.com/t/how-to-disable-google-tv-launcher-install-3rd-party-launcher.4601397/)), which ends ADB until Wi‑Fi is rejoined with the remote; on this box Wi‑Fi stayed connected *(observed on MiTV-AFMU0)*.

Reversed by `pm enable` on both packages and `cmd role remove-role-holder android.app.role.HOME <pkg>`.

A launcher's "Continue Watching" / Watch Next row comes from the TV provider (`com.android.providers.tv`), where each app publishes its own programs, so clearing an app's own history leaves its cards there. Reading or deleting another app's rows takes `ACCESS_ALL_EPG_DATA` / `ACCESS_WATCHED_PROGRAMS`, both `signature|privileged` (`dumpsys package com.android.providers.tv`), so `content query --uri content://android.media.tv/watch_next_program` returns nothing to the shell. `pm clear com.android.providers.tv` empties the provider for every app; apps republish their rows when they next run.

Google TV "Apps only mode" (Settings › Accounts & Sign In › profile › Apps only mode) removes personalized recommendations from the home screen (sponsored content stays); while it is on, Search and the Google Assistant don't work, likes/dislikes, the Watchlist and marking things watched are unavailable, and the Library moves off the home screen into the YouTube app ([Google TV Help](https://support.google.com/googletv/answer/10070784)).

## Installing apps

- **Play Store:** `am start -a android.intent.action.VIEW -d market://details?id=<pkg>` opens the app's listing with Install focused, `input keyevent DPAD_CENTER` presses it, and `pm path <pkg>` prints the APK once the install finishes *(observed on MiTV-AFMU0)*. A screenshot (`exec-out screencap -p`) confirms the focus before the key press.
- **APK file:** `adb install <apk>`. Userspace is 32-bit ([platform.md § Identity](platform.md#identity)), so a release offered per ABI takes its `armeabi-v7a` build. Without `aapt2` on the Mac, the new package name is the line added to `pm list packages -3` between a read before and after the install.

## Runtime resource overlays

Overlays change another package's resources (strings, layouts, config) without changing its code. `cmd overlay list` shows each overlay under its target with `[x]` enabled, `[ ]` disabled, `---` not changeable; `cmd overlay enable|disable <overlay>` toggles one; static overlays cannot be disabled ([OverlayManagerShellCommand](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android14-release/services/core/java/com/android/server/om/OverlayManagerShellCommand.java), [RRO docs](https://source.android.com/docs/core/runtime/rros)). `cmd overlay list` also prints the box's vendor overlays and the packages they target.

## Packages by vendor

`pm list packages | grep -E '<prefix>'` groups them:

```
PREFIX                    VENDOR / ROLE (by package name)
-----------------------   ---------------------------------------------------------------
com.google.android.*      Google: TV home (apps.tv.launcherx), setup (tungsten.setupwraith),
                          Play services (gms), Play Store (com.android.vending), feedback
com.android.*             AOSP platform; com.android.tv.settings = TV Settings
com.mitv.*, com.xiaomi.*, Xiaomi: PatchWall home, media apps, analytics, quick settings,
com.miui.*, mitv.*        system services
com.droidlogic.*,         Amlogic platform services and overlays
com.amlogic.*
com.dolby.*               Dolby audio service
```

A package's purpose is confirmed from what it declares (`dumpsys package <pkg>` activities, services, receivers, permissions) and, for third-party apps, its Play Store listing.
