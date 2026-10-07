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
```

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

When no holder is set, the fallback is the single highest-priority HOME activity, and a tie produces no fallback ([HomeRoleBehavior.java](https://android.googlesource.com/platform/packages/modules/Permission/+/refs/heads/android14-release/PermissionController/role-controller/java/com/android/role/controller/behavior/HomeRoleBehavior.java)). Only privileged (system) apps may declare an intent-filter priority above 0 ([ComponentResolver.java](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android14-release/services/core/java/com/android/server/pm/resolution/ComponentResolver.java)), so a system launcher with priority above 0 outranks any installed launcher until it is disabled or the role is assigned with `cmd role add-role-holder android.app.role.HOME <pkg>`. On Google TV the candidates are `com.google.android.apps.tv.launcherx` (Google TV home), `com.google.android.tungsten.setupwraith` (setup/recovery) and `com.android.tv.settings/.system.FallbackHome` *(read on MiTV-AFMU0: priorities 2, 1, −1000)*.

Google TV "Apps only mode" (Settings › Accounts & Sign In › profile › Apps only mode) removes personalized recommendations from the home screen (sponsored content stays); while it is on, Search and the Google Assistant don't work, likes/dislikes, the Watchlist and marking things watched are unavailable, and the Library moves off the home screen into the YouTube app ([Google TV Help](https://support.google.com/googletv/answer/10070784)).

## Runtime resource overlays

Overlays change another package's resources (strings, layouts, config) without changing its code. `cmd overlay list` shows each overlay under its target with `[x]` enabled, `[ ]` disabled, `---` not changeable; `cmd overlay enable|disable <overlay>` toggles one; static overlays cannot be disabled ([OverlayManagerShellCommand](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android14-release/services/core/java/com/android/server/om/OverlayManagerShellCommand.java), [RRO docs](https://source.android.com/docs/core/runtime/rros)). Vendor overlays on this box target, among others, `android`, `com.android.tv.settings`, `com.android.providers.settings`, `com.android.systemui`, `com.android.wifi.resources`, `com.android.networkstack.tethering`, `com.android.providers.tv` and `com.android.tv.mdnsoffloadmanager` *(read on MiTV-AFMU0; `cmd overlay list` gives the full set)*.

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
