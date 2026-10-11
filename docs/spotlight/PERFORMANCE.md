# Spotlight performance on macOS 27: what sets it, what changes it, how to measure it

**TL;DR.** On this Mac (M4, 24 GB, macOS 27.0.1, index of about 7,100 items),
a metadata-store query costs about 20 ms. That is a fixed cost: a query with
no match takes as long as one with 17 matches, so it does not depend on index
size. Index size is not the bottleneck, and more exclusions or a rebuild will
not make ⌘Space faster. The ⌘Space window's latency comes from the
multi-source ranking pipeline in the UI process. One logged query took 870 ms
end to end, against 30 ms for its Apps source. The only way to see that
number is `log stream --info` on that process. Every lever with a documented
effect is already set: result-source toggles, no internet results, and
exclusions of churny trees. No third-party importers are installed. Rebuilding
the index fixes missing or wrong results, not speed.

Scope: query latency and indexing load for the local Spotlight index and the
⌘Space window. Which folders are excluded and why is owned by the header of
`mac/spotlight.sh`. Which result sources are shown is owned by the Spotlight
section of `mac/defaults.sh`. The internet-results block is owned by
`mac/profiles/privacy-restrictions.mobileconfig`.

Measurements were taken on 2026-10-11, on AC power, with the indexer idle.
Every number below gives the command that produced it, so re-running that
command replaces it.

## 1. What determines latency and time to first result

### The pieces

| Component | Role | Source |
|---|---|---|
| `mds` | "the metadata server. It serves all clients of the metadata APIs, including Spotlight." | `man 8 mds` |
| `mds_stores` | Holds the per-volume stores. The `mds_stores` log lines carry the query handling (`[com.apple.spotlightindex:Query]`) and the vector index (`IVFVectorIndex`). | `log show --predicate 'process == "mds_stores"'` |
| `mdworker_shared` / `mdbulkimport` | "used by mds to scan and index files as a volume is mounted or a file changes" | `man 8 mdworker`; `ps -axo command` |
| `corespotlightd` | The Core Spotlight index that apps donate to (Mail, Notes, Reminders, Contacts, System Settings, Podcasts, Voice Memos extensions here). | `pluginkit -mv -p com.apple.spotlight.index` |
| `spotlightknowledged.updater` | Runs embedding jobs over the index journals (`Embedding.JournalProcessing.ClassC`). | `log show`, category `com.apple.spotlightknowledge:Scheduler` |
| ⌘Space UI | On this Mac the window is hosted by `/System/Applications/Siri AI.app`, not `Spotlight.app`. | see below |

**Which process is the UI.** `/System/Library/LaunchAgents/com.apple.Spotlight.plist`
is `Disabled` when the feature flag `IntelligenceFlow/Campo` is on.
`com.apple.campo.plist` is disabled when that flag is off, and it runs
`Siri AI.app` with `RunAtLoad`. `launchctl list` shows `com.apple.campo`
running as PID 1732 and no `com.apple.Spotlight` job. That PID logs the
Spotlight UI categories (`com.apple.spotlight.ui:QueryController`). On a Mac
where the flag is off, the same log lines come from `process == "Spotlight"`.

### Costs measured with `mdfind`

Each query below ran 7 times. The table gives the median, with min–max in
parentheses. The bench recorded the time to the first output line and the
time to exit. Overhead calibration: `/usr/bin/true` takes 1.7 ms and
`mdls -name kMDItemContentType /etc/hosts` takes 19.1 ms (20-run average).

| Query | Results | First result (ms) | Total (ms) |
|---|---:|---:|---:|
| `mdfind -name zqxjvwkp_nomatch` | 0 | 23 (22–29) | 23 (22–29) |
| `mdfind -name zshrc` | 3 | 22 (22–27) | 22 (22–28) |
| `mdfind -name README` | 17 | 23 (23–23) | 23 (22–23) |
| `mdfind -onlyin ~ -name README` | 7 | 22 (22–23) | 23 (22–24) |
| `mdfind -interpret invoice` | 46 | 45 (45–50) | 46 (46–51) |
| `mdfind -interpret spotlight` | 18 | 49 (46–55) | 50 (46–55) |
| `mdfind 'kMDItemTextContent == "spotlight*"cdw'` | 9 | 20 (19–23) | 20 (19–24) |
| `mdfind 'kMDItemContentType == "com.adobe.pdf"'` | 372 | 21 (21–24) | 31 (31–34) |
| `mdfind 'kMDItemContentType == "com.apple.application-bundle"'` | 342 | 20 (20–23) | 25 (24–27) |
| `mdfind 'kMDItemContentType != ""'` | 7,131 | 22 (21–23) | 268 (264–306) |

What the table shows:

- **A fixed floor of about 20 ms per client.** A query with no match costs
  the same as `mdls` on one file, which runs no query at all. The floor is
  process start plus the XPC connection to `mds`. Each connection also
  triggers TCC checks: 3,429 `TCCAccessRequest() IPC` lines from `mds` in 2 h
  (`log show --last 2h --predicate 'process == "mds"'`).
- **Index lookup is not the cost at this index size.** Full-text
  (`kMDItemTextContent`), name, and attribute queries all land on the same
  ~20 ms. There is no cold/warm gap either: run 1 is within the min–max of
  the later runs on every row.
- **Total time scales with results returned, not with index size.** 7,131
  results take 268 ms, about 35 µs per path delivered. The first result
  still arrives at 22 ms.
- **Natural-language parsing adds about 25 ms.** `-interpret` "force[s] the
  provided query string to be interpreted as if the user had typed the string
  into the Spotlight menu" (`man 1 mdfind`). On each call `mdfind` logs
  `[UserQueryParser] Loading keywords and predicates for locale "en_US"` to
  stderr.

### What the ⌘Space window adds

The UI runs a multi-source pipeline per keystroke. Here is one query (qid
710/711, a 4-character string) taken from the in-memory info log of PID 1732:

```
[qid=710][SpotlightPlusRanking][Response][CoreSpotlight][complete] Sending update with 3 section(s) and 0 result(s). fastResponseQuality
[qid=710][SpotlightPlusRanking] Query latency: 870.42403 milliseconds
[qid=6818] Apps query finished in 30.146 milliseconds
[QPNLU][qid=711] ... totalLatency: 0.0414  loadLatency: 0.0259
[QPNLU][qid=711] Semantic search is supported for keyboard language "<private>"
SPSearchQueryContext (711 ... queryKind: SPQueryKindAsYouTypeTopHitSearch ... disabledDomains ... disabledBundles ...
[automatic cooldown] cooling down QP after 120s of idle time
```

(`log show --last 6h --info --predicate 'process == "Siri AI" AND subsystem BEGINSWITH "com.apple.spotlight"'`.)

- The end-to-end latency (870 ms) is about 30× the Apps source (30 ms) and
  about 40× the CLI floor. The extra time sits in ranking and in merging the
  Core Spotlight sources, not in the file index. This is one sample. Section
  4 gives the command that collects more.
- Each query's context carries `disabledDomains` and `disabledBundles`. These
  are the off-switches from Spotlight settings, so the result-source toggles
  reach the query itself, not only the display.
- The query-understanding model unloads after 120 s idle, so the first query
  after a pause reloads it. Measured `loadLatency` was 4–26 ms, which is
  small next to the 870 ms total.
- Apple says the on-device semantic models "may be loaded or unloaded at any
  time" and should be warmed "just before your search interface appears" (WWDC24
  [Support semantic search with Core Spotlight](https://developer.apple.com/videos/play/wwdc2024/10131/)).
  That is guidance for app developers, and no user setting controls it.
- Info-level lines are not persisted. A 10-day `log show --info` search for
  `Query latency` returned nothing, so UI latency has to be captured live
  with `log stream`.

### What determines indexing speed

- "Depending on the amount of data on your device, Spotlight indexing can
  take hours or even days. Incremental updates after that are much faster."
  Indexing "happens when you first set up your device, after you install a
  software update or upgrade", and as data changes
  ([Apple 102321](https://support.apple.com/en-us/102321)).
- It "completes more quickly when" the device is not in use, is "connected to
  power", and is on Wi-Fi or Ethernet, so mail and other data can download
  ([Apple 102321](https://support.apple.com/en-us/102321)).
- "indexing may be delayed due to low disk space or other conditions"
  (`man 1 mdutil`, `-i`). This Mac has 529 GiB free (`df -h /System/Volumes/Data`).
- While indexing runs, results are incomplete, and "an indexing progress
  indicator appears at the top of the Spotlight window"
  ([If searching your Mac returns unexpected results](https://support.apple.com/guide/mac-help/searching-mac-returns-unexpected-results-mchlp2962/mac)).
- Importers do the per-file extraction (`man 1 mdimport`: `-p` prints
  "performance information gathered during the run" for a test import). A slow
  importer slows only the file types it claims.

## 2. What a user can legitimately change

| Lever | Supported mechanism | Effect | On this Mac |
|---|---|---|---|
| Result sources | System Settings › Spotlight › Results from Apps / System. "Turn on the apps if you want them and their content to appear in Spotlight search results" ([Spotlight settings](https://support.apple.com/guide/mac-help/spotlight-settings-on-mac-mchl54d95e8a/mac)) | Removes whole domains from each query (`disabledDomains`/`disabledBundles` above). Apple documents no latency effect, so it is unmeasured. | Set by `mac/defaults.sh` (`EnabledPreferenceRules`, `DisabledUTTypes`). Reminders is off in both the script and the live list. System Settings is off live but on in the script (`defaults read com.apple.Spotlight EnabledPreferenceRules`). |
| Show Related Content | Same pane: "Allow content from Apple partners to be shown…" | Removes partner content from the query | Off (`Custom.relatedContents` in the off-list) |
| Internet results | Restrictions payload `allowSpotlightInternetResults` | No web, Wikipedia, or news rows | `false` in `/Library/Managed Preferences/yossidoctor/com.apple.applicationaccess.plist`. `parsecEnabled = false` in `…/com.apple.Spotlight.plist` |
| Exclusions | System Settings › Spotlight › Search Privacy: "Exclude specific files and folders from Spotlight searches" ([Prevent Spotlight searches](https://support.apple.com/guide/mac-help/prevent-spotlight-searches-in-files-mchl1bb43b84/mac)) | Fewer files imported on every change, so less `mdworker`/`mds_stores` work. Query floor unchanged (§1). | Done. List and reasons are in `mac/spotlight.sh`. |
| Index size | Follows from exclusions | 7,131 items on `/` (`mdfind -onlyin / -count 'kMDItemContentType != ""'`). The largest remaining groups are `~/Library/Mobile Documents` (665), `/Library/WebServer/share` (1,159), and `/Library/Ruby/Gems` (422). | Small. Trimming further does not move the 20 ms floor. |
| Rebuild | Apple's method: add the disk or folder to Search Privacy, wait, then remove it. "rebuilding part of the Spotlight index can help resolve stubborn search issues" ([Apple 102321](https://support.apple.com/en-us/102321)). CLI: `sudo mdutil -E <volume>` ("each local store … erased. The stores will be rebuilt if appropriate", `man 1 mdutil`) | Fixes missing or wrong results. Costs "hours or even days" of indexing, with incomplete results until done. | Rebuilt once on 2026-10-11 after the exclusion list changed; the index is erased and re-filled |
| Importers | `mdimport -L` lists them. App importers live in `MyApp.app/Contents/Library/Spotlight`, standalone ones in `~/Library/Spotlight` or `/Library/Spotlight` ([Troubleshooting Spotlight Importers](https://developer.apple.com/library/archive/documentation/Carbon/Conceptual/MDImporters/Concepts/Troubleshooting.html)). `mdimport -r <importer>` re-imports one importer's types. | Removing a third-party importer stops its per-file work | Clean: `mdimport -L` lists only the 18 `/System/Library/Spotlight/*.mdimporter`. `/Library/Spotlight` does not exist, `~/Library/Spotlight` holds only `ExtensionsCache`, `fd -u -g '*.mdimporter'` over `/Applications` and `/Library` finds none, and `pluginkit -mv -p com.apple.spotlight.import` lists only two Apple extensions. |
| Full Disk Access / TCC | System Settings › Privacy & Security | Decides what a client may read, not how fast. `mds` runs a TCC check for each client connection (log above). That results are filtered per client is an inference from those checks; no Apple page states it. | Not a speed lever |
| Power and idle | Leave the Mac on power and idle after an update ([Apple 102321](https://support.apple.com/en-us/102321)) | First index or reindex finishes sooner | Situational |

## 3. What does not help, and what is unsupported or risky

- **Rebuilding for speed.** Apple's only stated purpose for a rebuild is
  "stubborn search issues" ([102321](https://support.apple.com/en-us/102321)).
  At this index size the query floor is client overhead (§1), and a rebuild
  buys hours of indexing load and incomplete results.
- **Turning indexing off** (`sudo mdutil -i off`, or excluding the whole
  disk). Finder, Mail, and Open/Save search all read this index (header of
  `mac/spotlight.sh`). "If you exclude your entire internal disk, you won't
  be notified about any updates"
  ([Prevent Spotlight searches](https://support.apple.com/guide/mac-help/prevent-spotlight-searches-in-files-mchl1bb43b84/mac)).
- **More exclusions to speed up queries.** They cut indexing work, not query
  latency: a no-match query costs the same as a match (§1).
- **Tuning `mds`.** "There are no configurations to mds, and users should not
  run mds manually" (`man 8 mds`). The same holds for `mdworker`
  (`man 8 mdworker`). The launchd jobs are system jobs and SIP is enabled
  (`csrutil status`). Unloading or killing them is unsupported.
- **Editing the volume's `VolumeConfiguration.plist`, or dropping a
  `.metadata_never_index` marker.** Both have no effect on this macOS. The
  indexer restores the plist from its master copy, and the marker is ignored
  (header of `mac/spotlight.sh`, observed on this Mac).
- **Removing system importers.** They live on the sealed system volume under
  `/System/Library/Spotlight`, which cannot be modified with SIP on.
- **The embedding and vector work** (`spotlightknowledged.updater`,
  `IVFVectorIndex` in `mds_stores`). No Apple page and no setting found in
  the Spotlight pane controls it. Its measured average cost is small (§4).
  Unverified: there may be no user-facing switch at all.
- **Secondary-source tips** (Terminal one-liners that delete
  `/.Spotlight-V100`, `launchctl unload` of `com.apple.metadata.mds`). No
  primary source backs them, and on macOS 27 they need root and run into SIP.
  Unverified, and not recommended.

## 4. Measuring before and after on this Mac

**Index size.** No sudo:
```zsh
mdfind -onlyin / -count 'kMDItemContentType != ""'     # 7131 on 2026-10-11
mdfind -onlyin ~ 'kMDItemContentType != ""' | awk -F/ '{print "/"$2"/"$3"/"$4"/"$5}' | sort | uniq -c | sort -rn | head
```
Pitfalls:
- `kMDItemFSName == "*"` returns 0 here, so use `kMDItemContentType` or
  `kMDItemDisplayName`.
- `-onlyin ~/Library/Containers` returns 0, even though `-onlyin ~` lists 468
  items under that path, so scope to a parent directory.
- The count was about 14,330 before `~/Library/Application Support` and
  `Application Scripts` were excluded. Re-sample before comparing.

**CLI query latency.** No sudo. Run each query several times and compare
medians:
```zsh
zmodload zsh/datetime
qs=('-name README' '-interpret invoice' "'kMDItemContentType == \"com.adobe.pdf\"'")
for q in $qs; do
  s=(); for i in {1..7}; do t=$EPOCHREALTIME; eval "mdfind $q" >/dev/null 2>&1; s+=$(printf '%.0f' $(( (EPOCHREALTIME-t)*1000 ))); done
  print -r -- "$q  ms sorted: ${(on)s}"
done
```

**⌘Space latency.** This is the number that matches the felt experience. No
sudo. Start the stream, use Spotlight for a minute, then read the `Query
latency` lines:
```zsh
/usr/bin/log stream --info --style compact --predicate 'process == "Siri AI" AND (eventMessage CONTAINS "Query latency" OR eventMessage CONTAINS "query finished in" OR eventMessage CONTAINS "cooling down")'
```
Use `/usr/bin/log`: zsh has a `log` builtin that shadows it. Use
`process == "Spotlight"` on a Mac without the Campo flag. Baseline: one
sample, 870 ms for a 4-character query. Collect at least 20 queries, and
include some after more than 120 s idle, before calling anything a change.

**Daemon CPU.** No sudo:
```zsh
ps -axo pid,user,%cpu,rss,time,etime,comm | grep -E 'mds|mdworker|mdbulkimport|corespotlightd|spotlightknowledged|Siri AI' | grep -v grep
top -l 3 -s 2 -o cpu -stats pid,command,cpu,time,mem,pageins | awk '/^PID/{n++} n==3' | grep -E 'PID|mds|corespotlight|spotlightknow'
```
Baseline: idle, with the average computed as CPU time over elapsed time.

| Process | CPU time / elapsed | Average of one core | `top` now |
|---|---|---:|---:|
| `mds` | 31:08 / 9 d 23 h | 0.22 % | 1.1 % |
| `mds_stores` | 25:50 / 5 d 23 h | 0.30 % | 0.4 % |
| `corespotlightd` | 53:08 / 9 d 23 h | 0.37 % | 0.6 % |
| `spotlightknowledged.updater` | 31:52 / 4 d 19 h | 0.46 % | 0.2 % |

**Client load on `mds`.** No sudo. In 2 h, 1,206 distinct client processes
connected. Most of them came in bursts: 947 in the single minute at 12:25,
and 131 at 12:18. Outside bursts the rate was 2–4 a minute, and a 40 s live
watch saw none. The bursts were not attributed; they are short-lived clients
such as scripted `mdfind`/`mdls` loops. Count them with:
```zsh
/usr/bin/log show --last 2h --style compact --predicate 'process == "mds" AND eventMessage CONTAINS "mds.peer["' | grep -c 'activating connection'
```

**Needs sudo.** These were not run here.
- `sudo fs_usage -w -f filesys mds mds_stores mdworker_shared` shows file
  activity per indexer process. `fs_usage` "requires root" (`man 1 fs_usage`).
- `sudo powermetrics --samplers tasks --show-process-io -n 1` gives
  per-process I/O.
- `sudo mdutil -L /System/Volumes/Data` lists the index directory, and
  `sudo mdutil -P /System/Volumes/Data` prints `VolumeConfiguration.plist`.
  Both print "Must be root to run this command" without sudo.
- `sudo du -sh /System/Volumes/Data/.Spotlight-V100` gives the on-disk index
  size. Without sudo it fails with Permission denied.
- Activity Monitor › ⋯ › Spotlight Diagnostics "Creates a report based on all
  the processes running on your Mac"
  ([Activity Monitor](https://support.apple.com/guide/activity-monitor/run-system-diagnostics-actmntr2225/mac)).

## 5. Recommended actions for this Mac, ranked

1. **Capture ⌘Space latency with the `log stream` command in §4.** Worth
   doing. It is the only metric that reflects the felt speed, and it decides
   whether anything below matters.
2. **Result-source off-list.** Already done (`mac/defaults.sh`). It is the
   one documented lever that reaches the query (`disabledDomains`). The open
   item: System Settings is off live but on in `defaults.sh`; this is a
   correctness fix, not a speed fix.
3. **Internet results and Related Content off.** Already done (profile plus
   `Custom.relatedContents`).
4. **Exclusions of churny trees** (work tree, Homebrew, Application Support,
   SDK headers). Already done (`mac/spotlight.sh`). Each extra candidate
   (`/Library/WebServer`, `/Library/Ruby`) holds about 1k static items. Not
   worth it, because the query floor does not move.
5. **Third-party importer audit.** Already clean, with none installed.
   Re-check with `mdimport -L` after installing apps that ship document
   types.
6. **Leave the Mac on power and idle after a macOS update** so reindexing
   finishes. Worth doing, situationally.
7. **Rebuilding the index** (Search Privacy add/remove, or
   `sudo mdutil -E /System/Volumes/Data`). Not worth it: do it only when
   files are missing from results.
8. **Disabling indexing, tuning `mds`, deleting `.Spotlight-V100`.** Not
   worth it, and unsupported or harmful (§3).
