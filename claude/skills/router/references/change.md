# Applying a change

The one background call of [SKILL.md § Making a change](../SKILL.md#making-a-change) step 3, and the markers that tell a restart has finished.

## The call

`service` returns before the restart begins, so for a few seconds after it SSH still answers and `wlready` still reads 1; a wait that checks only those exits at once, before the Wi‑Fi link drops *(unit: `restart_wireless` issued at uptime 4355, VAPs back up at 4390–4394)*. The wait therefore keys on a marker newer than the call. The first SSH records the router's uptime and its count of `notify_rc` lines for the first action of the sequence, then writes and applies; both numbers come back to the Mac, where the wait loop compares against them:

```
read T0 N0 <<<"$(ssh router 'echo "$(cut -d. -f1 /proc/uptime) $(grep -c "notify_rc <first action>" /jffs/syslog.log)"
  nvram set <key>=<value>; nvram commit
  <any extra step the section names, e.g. rc sync_apgx_to_wlunit>
  service "<action;action>" >/dev/null 2>&1 </dev/null &')"
n=0; until ssh -o ConnectTimeout=3 router "<marker test from § Markers, using $T0 or $N0>"; do
  [ $((n+=1)) -lt 100 ] || { echo "no marker after 300 s; the router did not come back the way the marker expects"; break; }; sleep 3; done
ssh router '<read-back: the keys, the generated config they feed, the live state they control>'
```

`$T0` and `$N0` expand on the Mac, inside the double-quoted marker test. The loop gives up after 300 s, past the longest measured restart (§ Measured durations), so a router that never comes back, or a log rotation that resets the `notify_rc` count mid-wait, ends the call with that message instead of hanging it. `rc` logs each call as `rc_service: <caller> <pid>:notify_rc <action>` in `/jffs/syslog.log` (`service` as the caller for an SSH call) *(unit)*.

## Markers

```
ACTION                         WAIT UNTIL (inside the double-quoted ssh argument)
----------------------------   ----------------------------------------------------------------
reboot, restart_all            test \$(cut -d. -f1 /proc/uptime) -lt $T0
radio restart                  dmesg | grep 'mlme_ext_vap_up: VAP (ath201)' | tail -1 |
(restart_wireless, _net*)        awk -F'[][]' '{exit !(\$2 > $T0)}'     (likewise ath001, ath101)
any other service action       test \$(grep -c 'notify_rc <first action>' /jffs/syslog.log) -gt $N0
```

After the loop returns, each part is up when:

```
CHECK                              COMMAND                                                 DONE WHEN
--------------------------------   -----------------------------------------------------   ------------------------------
rc finished starting services      nvram get svc_ready; nvram get success_start_service     1 and 1
Wi‑Fi init finished                nvram get wlready                                        1 (rc sets 0 while it starts
                                                                                            the radios)
each VAP is up                     dmesg | grep -E 'is up, vdev' | tail                     a line for ath001, ath101,
                                                                                            ath201 after the restart
a DFS channel finished its wait    dmesg | grep CAC_COMPLETED | tail -1                     present after the last
                                                                                            CAC_START
WAN is back                        grep -E 'WAN\(0\) Connection: WAN was restored' \        newest line after the restart
                                   /jffs/syslog.log | tail -1
```

`wlready` gates the watchdog's Wi‑Fi checks ([watchdog.c](https://github.com/RMerl/asuswrt-merlin.ng/blob/b053ba701af02e46a86d465d82cc2a7891a288a7/release/src/router/rc/watchdog.c#L5582)); it reads 1 between restarts.

## Measured durations

Kernel timestamps of restarts in the log *(unit)*:

```
EVENT                                   2.4 GHz up   6 GHz up   5 GHz up (ch 100, DFS)   WAN restored
-------------------------------------   ----------   --------   ----------------------   ------------
boot (after a firmware flash)           47 s         52 s       113 s (CAC 50.8–112.9)   ~48 s
restart_wireless (from VAPs down)       34 s         38 s       99 s (CAC 62 s)          not dropped
```

A 5 GHz channel outside the DFS range skips the CAC, so 5 GHz then comes up with the other bands; a DFS channel adds the 60‑second-class wait that [regulatory.md § DFS](regulatory.md#dfs) defines. During the CAC the 5 GHz VAPs are down while 2.4 and 6 GHz serve clients.

Keys: `nvram show 2>/dev/null | cut -d= -f1 | grep -xE 'wlready|svc_ready|success_start_service'`
