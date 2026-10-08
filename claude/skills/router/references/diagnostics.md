# Diagnostics

Where the router records what happened, how to read its live state, and what a normal reading looks like. Paths, formats and readings are *(read on RT-BE90U 3.0.0.6.102_58500)* unless a source is cited; a "now" reading was taken at about 20 minutes uptime, idle, with two Wi‑Fi clients, so a reading under load or with more clients is compared against the conditions, not the number. Every command here is a read; the commands that change state live in [platform.md § Apply actions](platform.md#apply-actions).

## Logs

```
LOG                 PATH / COMMAND                              NOTES
-----------------   -----------------------------------------   ----------------------------------------------
syslog              /jffs/syslog.log (+ /jffs/syslog.log-1)     /tmp/syslog.log* are symlinks to these; on
                                                                flash, so it survives reboots
kernel ring         dmesg                                       RAM only; holds about the last 1,400 lines, so
                                                                boot lines are gone within minutes of a boot
boot kernel log     /tmp/boot_dmesg.log                         the first ~280 kernel lines of this boot (RAM)
hostapd             /jffs/hostapd.log                           association, 4-way handshake, AP-STA-CONNECTED
service calls       grep rc_service /jffs/syslog.log            "notify_rc <action>" with the caller (httpds,
                                                                cfg_server, rc, ntp, watchdog)
AiMesh / roaming    /tmp/asusdebuglog/{cfg_abl,nbr,roamfb}.log  RAM
firmware check      /jffs/webs_upgrade.log                      see platform.md § Firmware
```

The logger is BusyBox `syslogd -m 0 -S -O /jffs/syslog.log -s 768 -b 1 -l 6` plus `klogd -c 5` (`ps w | grep -E 'syslogd|klogd'`): it rotates at `-s` KB into one `-b 1` older file and keeps priority `-l` and above. rc builds those arguments from nvram at each `restart_logger`: `log_size` → `-s`, `log_level` → `-l`, and a non-empty `log_ipaddr` adds `-R <log_ipaddr>:<log_port> -L`, which sends every line to a remote syslog server and keeps the local copy ([merlin.ng rc/services.c start_syslogd](https://github.com/RMerl/asuswrt-merlin.ng/blob/b053ba701af02e46a86d465d82cc2a7891a288a7/release/src/router/rc/services.c#L5905)). `log_path` (`/jffs`) is the directory, `log_rotate` the rotation switch, `console_loglevel` the serial-console level. System Log › General Log exposes only the remote server (`log_ipaddr`, `log_port`, applied with `restart_logger`); `log_level` and `log_size` have no page. Choosing them: [trade-off](tradeoffs.md#log-level-and-remote-syslog).

**Retention window.** The kernel's `wlan:` driver lines are most of the log (`ssh router 'cat /jffs/syslog.log' | awk '{print $4}' | sort | uniq -c | sort -rn | head` counts lines per source; `kernel` dominates, then `dropbear`, one line per SSH login, so every `ssh router` call adds a line). The window is the time to write about 2 × `log_size` KB: `head -1 /jffs/syslog.log-1; tail -1 /jffs/syslog.log` brackets it.

**Clock.** Until NTP syncs after a boot, lines carry a `Jan  1` date; `ntp: start NTP update` is the last pre-sync line, and cron then logs `time disparity of <n> minutes detected`. Ordering across a boot therefore follows line order and the kernel's `[seconds]` stamps, not the date column.

**Debug log capture** (Administration › Feedback, `dblog_*`): the page starts a timed capture of selected services (`dblog_service`, `dblog_duration`) to USB or for upload with the feedback report; `dblog_state` and `dblog_remaining` track a running capture. The page's Apply runs `restart_sendfeedback` or `stop_dblog` (`grep -n action_script /www/Advanced_Feedback.asp`).

Keys: `nvram show 2>/dev/null | cut -d= -f1 | grep -xE 'log_(ipaddr|port|level|size|path|rotate)|console_loglevel|dblog_.*'`

## Boots, restarts and crashes

```
QUESTION                           READ                                              NORMAL / TROUBLE
--------------------------------   -----------------------------------------------   ------------------------------
uptime now                         cat /proc/uptime                                  seconds since boot
how long the previous boot ran     nvram get sys_uptime_prev                         uptime sampled every 60 s, so
                                                                                     ±60 s
where boots are in the log         grep -n 'INIT: firmware version' /jffs/syslog.log*  one line per boot, names the
                                                                                     firmware that booted
why the previous boot ended        grep -A3 'Reboot message' /tmp/boot_dmesg.log     see below
service restarts since boot        grep -n 'notify_rc' /jffs/syslog.log              each Apply / daemon request
```

**Reboot cause.** The kernel prints a preserved `_ Reboot message ..._` block at `[    0.000000]` of the next boot (in `/tmp/boot_dmesg.log` and the syslog). `crash_log: __do_sys_reboot: cmd 0x1234567` is an orderly `reboot()` call, `0x01234567` being `LINUX_REBOOT_CMD_RESTART` ([linux v5.4 include/uapi/linux/reboot.h](https://github.com/torvalds/linux/blob/219d54332a09e8d8741c1e1982f5eae56099de85/include/uapi/linux/reboot.h#L29)): Reboot, a firmware flash, or an Apply that reboots. A boot with no `Reboot message` block followed a power cycle or a hardware reset. A panic's text in that block is the crash marker; its exact wording on this unit is not established. The line `qti_scm_restart_reason ... reset_reason : Power on Reset [0x20]` appears after an orderly reboot too, so it does not distinguish the causes. There is no pstore (`/sys/fs/pstore` is absent).

`/proc/sys/kernel/panic` and `panic_on_oops` read `3` and `3` (reboot 3 s after a panic). `sys_reboot_reason` is empty after an ordinary reboot; ASUS's watchdog writes `rbt_scheduler` for a scheduled reboot and `wdg_gone` when it restarts the router itself, and init writes `restore_default` after a reset ([merlin.ng rc/watchdog.c](https://github.com/RMerl/asuswrt-merlin.ng/blob/b053ba701af02e46a86d465d82cc2a7891a288a7/release/src/router/rc/watchdog.c#L5390), [rc/init.c](https://github.com/RMerl/asuswrt-merlin.ng/blob/b053ba701af02e46a86d465d82cc2a7891a288a7/release/src/router/rc/init.c#L2917)). `sys_uptime_now` is that 60‑second uptime sample ([watchdog.c record_current_sys_uptime](https://github.com/RMerl/asuswrt-merlin.ng/blob/b053ba701af02e46a86d465d82cc2a7891a288a7/release/src/router/rc/watchdog.c#L11308)), copied to `sys_uptime_prev` at boot ([init.c](https://github.com/RMerl/asuswrt-merlin.ng/blob/b053ba701af02e46a86d465d82cc2a7891a288a7/release/src/router/rc/init.c#L4113)). `dev_fail_reboot` (3) is the retry count of an ATE device check that the merlin source applies to RT-N66U/RT-AC66U only ([init.c](https://github.com/RMerl/asuswrt-merlin.ng/blob/b053ba701af02e46a86d465d82cc2a7891a288a7/release/src/router/rc/init.c#L27251)); its use on this unit is not established. `sys_update_ts` and `sysstate_msqid_to_d` belong to the `sysstate` daemon; their meaning is not established. Scheduled reboots are set on Administration › System ([platform.md § Administration](platform.md#administration)).

Keys: `nvram show 2>/dev/null | cut -d= -f1 | grep -xE 'sys_(reboot_reason|update_ts|uptime_now|uptime_prev)|dev_fail_reboot|sysstate_msqid_to_d'`

## Clients

**Live station table, per VAP.** `wlanconfig <vap> list sta` prints one row per associated client; the fronthaul VAPs carrying the user's SSID are `ath001` (2.4 GHz), `ath101` (5 GHz) and `ath201` (6 GHz), and `for i in ath001 ath101 ath201; do echo "== $i"; wlanconfig $i list sta; done` reads all three ([wireless.md](wireless.md) maps every VAP).

```
COLUMN            MEANING
---------------   ----------------------------------------------------------------------
TXRATE / RXRATE   last PHY rate router→client / client→router
RSSI              signal received from the client, combined over chains, dBm (the tool
                  prints this note); MINRSSI / MAXRSSI since association
IDLE              seconds since the last frame from the client
CHAN              the client's channel
MODE              PHY mode and width, e.g. IEEE80211_MODE_11AXA_HE80 (Wi‑Fi 6, 5 GHz,
                  80 MHz), IEEE80211_MODE_11NG_HT20 (Wi‑Fi 4, 2.4 GHz, 20 MHz)
RXNSS / TXNSS     spatial streams in each direction
ASSOCTIME         time since association, hh:mm:ss
PSMODE            1 = client in power save
```

Per-client counters (packets per access category, success counts, per-MCS histograms): `apstats -s -m <client MAC>`, whose header names the VAP the client is on now. Association history: `grep -E 'AP-STA-(CONNECTED|DISCONNECTED)' /jffs/hostapd.log` and the kernel's `station associated` / `_ieee80211_node_leave ... rssi=` lines (`grep -E 'node_leave|station associated' /jffs/syslog.log`), which carry the reason and the signal at the moment of leaving.

**UI client lists.** `/tmp/clientlist.json` is `{"<router MAC>":{"2G_1":{"<client MAC>":{"ip":…,"rssi":…}},"5G_1":{…},"wired_mac":{…}}}`, rewritten periodically by `networkmap`; it lags roams, so a client can appear under two bands at once. `/tmp/allwclientlist.json` adds per-client `ifname`, `sdn_idx` and `wifi_auth`. Leases: `cat /var/lib/misc/dnsmasq.leases` (System Log › DHCP leases shows the same through `leases.log`). The station table is the authority for which band a client is on.

`networkmap_enable`, `networkmap_fullscan` and `networkmap_scan_status` drive and report the `networkmap` scan behind the client list (`update_clients.asp` sets `networkmap_fullscan`). `chksta_band` / `chksta_mac` are inputs to the httpd `act_chksta()` station check behind `ajax_trigger_chk_sta.asp`; its output format is not established.

Keys: `nvram show 2>/dev/null | cut -d= -f1 | grep -xE 'networkmap_.*|chksta_(band|mac)|custom_clientlist|custom_usericon(_del)?|custom_card_list'`

## Radio

```
READ                                 COMMAND                                        NOTES
----------------------------------   --------------------------------------------   ---------------------------------
channel, width, centre, tx power     iw dev <vap> info                              per VAP; wifi0/1/2 are the radios
PHY mode, bit rate, retries          iwconfig <vap> | grep -viE 'key|encryption'    "Link Quality/Signal" are not
                                                                                    meaningful on an AP VAP
radio counters                       apstats -r -i wifi<N>                          Rx PHY/CRC/MIC/decrypt errors,
                                                                                    Tx failures, Tx dropped, self-BSS
                                                                                    channel utilisation
VAP counters                         apstats -v -i <vap>
auto-channel decision                dmesg | grep 'ACS result'                      PCH = primary, chwidth, puncture
                                                                                    pattern, per VAP, at each start
CAC / radar / NOL events             dmesg | grep -E 'CAC_START|CAC_COMPLETED|      CAC_START … CAC_COMPLETED brackets
                                     RADAR|NOL'                                     a 5 GHz DFS wait; rules in
                                                                                    regulatory.md § DFS
VAP up / down                        dmesg | grep -E 'is (up|down), vdev'           mlme_ext_vap_up / _down lines
radio temperature and throttling     thermaltool -i wifi<N> -get                    § Temperature
```

A healthy radio reads zero or near-zero in `Rx PHY errors`, `Rx CRC errors`, `Rx MIC errors`, `Rx Decryption errors`, `Tx failures` and `Tx Dropped` relative to its data packet counts; a MIC or decryption error count that grows with one client points at that client's key state. `Connections refuse Radio limit` / `Vap limit` above zero means the radio refused associations. `wifi0` is the 2.4 GHz radio (`psoc_id:0`); `wifi1` (5 GHz) and `wifi2` (6 GHz) are two pdevs of one second chip (`psoc_id:1`), visible in the `mlme_ext_vap_up` lines. The per-radio DFS lines `Do not allocate DFS object for 2G` / `for 6G` at boot are normal: only the 5 GHz radio runs DFS.

## CPU, memory, connections

```
READ                        COMMAND                                                  NOW (idle, 2 clients)
-------------------------   ------------------------------------------------------   -----------------------------
overall CPU                 top -bn1 | sed -n 2,3p                                   ~93 % idle; sirq = softirq
                                                                                     (packet processing)
per-core busy %             grep '^cpu[0-3]' /proc/stat; sleep 2; grep '^cpu[0-3]'   4 cores (cpu0–cpu3, ARMv8);
                            /proc/stat   (one ssh call)                              busy % = 100 − Δidle/Δtotal
                                                                                     (4th field is idle)
load average                cat /proc/loadavg                                        ~2 while idle: kernel worker
                                                                                     threads count toward it, so it
                                                                                     is no CPU-saturation signal
CPU clock                   cat /sys/devices/system/cpu/cpu0/cpufreq/                1,500,000 kHz, governor
                            {scaling_cur_freq,scaling_governor}                      performance
memory                      free                                                     881,604 KB total; ~420 MB free
                                                                                     after buffers/cache
swap                        cat /proc/swaps                                          /dev/zram0, 256 MB, 0 used; use
                                                                                     above 0 means memory pressure
tracked connections         cat /proc/sys/net/netfilter/nf_conntrack_{count,max}     ~500 / 300,000
```

Conntrack sizing comes from nvram at boot: `ct_max` → `nf_conntrack_max`, `ct_hashsize` → the bucket count, `ct_expect_max`; `ct_tcp_timeout` is ten space-separated values of which fields 2–9 are the established, syn_sent, syn_recv, fin_wait, time_wait, close, close_wait and last_ack timeouts in seconds (established = 2400 here), `ct_udp_timeout` is "unreplied stream" (30 180), and `ct_timeout` is "generic icmp" (600 30); a key reading all zeros is replaced by the kernel's current values ([merlin.ng rc/common.c setup_conntrack](https://github.com/RMerl/asuswrt-merlin.ng/blob/b053ba701af02e46a86d465d82cc2a7891a288a7/release/src/router/rc/common.c#L682)). The live values are `/proc/sys/net/netfilter/nf_conntrack_tcp_timeout_*` and `nf_conntrack_udp_timeout*`. A count near `nf_conntrack_max` makes new connections fail; `/proc/net/nf_conntrack` lists the entries. Choosing timeouts: [trade-off](tradeoffs.md#conntrack-timeouts).

Keys: `nvram show 2>/dev/null | cut -d= -f1 | grep -xE 'ct_(max|hashsize|expect_max|tcp_timeout|udp_timeout|timeout)'`

## Hardware acceleration

Forwarded flows bypass the Linux network stack through Qualcomm's ECM (Enhanced Connection Manager), which watches conntrack and pushes each eligible connection to a front end: PPE, the SoC's packet-processing engine, or SFE, the software fast path (modules `ecm`, `qca_nss_ppe*`, `qca_nss_sfe` in `lsmod`). `cat /sys/module/ecm/parameters/front_end_selection` reads `0 (Auto)`; the front-end indices are 0 Auto, 1 NSS, 2 SFE, 3 PPE ([qca-nss-ecm ecm_front_end_common.c](https://git.codelinaro.org/clo/qsdk/oss/lklm/qca-nss-ecm/-/blob/30fbfa493d700270ac6c14685290f340b6ead28c/frontends/ecm_front_end_common.c#L155)), and in Auto the unit uses PPE and SFE side by side.

```
READ                                    COMMAND                                                NOW
-------------------------------------   ----------------------------------------------------   -----------------------
connections ECM tracks                  cat /sys/kernel/debug/ecm/ecm_db/                      tcp 107 udp 269
                                        connection_count_simple
accelerated by PPE (hardware)           cat /sys/kernel/debug/ecm/ecm_ppe_ipv4/                282 (44 tcp, 238 udp)
                                        {accelerated_count,tcp_accelerated_count,
                                        udp_accelerated_count}   (ecm_ppe_ipv6 likewise)
accelerated by SFE (software)           same files under ecm_sfe_ipv4 / ecm_sfe_ipv6           20
front end stopped                       cat /sys/kernel/debug/ecm/front_end_ipv4_stop          0 (1 = no new flows are
                                        (front_end_ipv6_stop)                                  accelerated)
default classifier mode                 cat /sys/kernel/debug/ecm/ecm_classifier_default/      2 = may accelerate
                                        accel_mode                                             (0 don't care, 1 never)
why a packet was not accelerated        cat /sys/kernel/debug/ecm/stats/ecm_v4_exception_      counters by reason
                                        stats | grep -v ': 0 *$'
PPE flow table and failures             cat /sys/kernel/debug/qca-nss-ppe/stats/common_stats   v4_l3_flows,
                                                                                               v4_vp_wifi_flows,
                                                                                               fail_*_full
```

Classifier modes: [ecm_classifier.h](https://git.codelinaro.org/clo/qsdk/oss/lklm/qca-nss-ecm/-/blob/30fbfa493d700270ac6c14685290f340b6ead28c/ecm_classifier.h#L79). Acceleration is working when `accelerated_count` (PPE + SFE) is a large share of `connection_count` under traffic, `pending_accel_count` stays near 0, and the PPE `fail_*_full` counters stay 0; the `_vp_wifi_flows` and `_ds_flows` counters show flows accelerated to and from Wi‑Fi VAPs. A `front_end_ipv4_stop` of 1, or accelerated counts that stop growing while traffic flows, means flows run through the CPU, which shows as softirq load in `top`. `/usr/bin/ecm_dump.sh` prints the full per-connection state but first creates a device node under `/dev/ecm`, so it is a write *(not run here)*. The NAT-acceleration switch and front-end choice are on [wan-lan.md § Switch control](wan-lan.md#switch-control); whether a QoS type or AiProtection stops acceleration on this platform is open ([wan-lan.md § Adaptive QoS](wan-lan.md#adaptive-qos)), and the counters above are how to settle it for a given setting.

## Temperature

```
SENSOR                      COMMAND                                                     NOW (idle)   LIMIT
-------------------------   ---------------------------------------------------------   ----------   -------------------------
SoC (5 tsens zones)         for z in /sys/class/thermal/thermal_zone*; do echo          47–48 °C     thermald: shutdown at
                            "$(cat $z/type) $(cat $z/temp)"; done   (millidegrees)                   120 °C on tsens_tz_sensor14,
                                                                                                     clear at 110 °C
Wi‑Fi radios                for w in wifi0 wifi1 wifi2; do thermaltool -i $w -get |    47 / 51 /    throttle levels from
                            grep -E 'sensor temperature|level:'; done                   52 °C        ~95 °C (see below)
```

`thermald -c /etc/thermal/thermald.conf` samples every 5 s and shuts the router down at the threshold in that file (`cat /etc/thermal/thermald.conf`). Each radio's firmware throttles itself: `thermaltool -i wifi<N> -get` prints its levels (on wifi1: level 1 from 95 °C switches the radio off 40 % of the time, level 2 from 100 °C 50 %, level 3 from 105 °C 60 %), the current level and the time spent in each; `current level` above 0 or a non-zero `entry count` above level 0 means the radio has been duty-cycling for heat. The web UI's temperature readout comes from httpd's `get_cpu_temperature()` and `get_fanctrl_info()` (`/www/ajax_coretmp.asp`); which sensor it reports is not established. `fan_gpio` names a fan control GPIO; whether this board has a fan is not established.

Keys: `nvram show 2>/dev/null | cut -d= -f1 | grep -xE '(have_)?fan_gpio'`

## Restart safety

A restart is confirmed by the router answering, by a fresh uptime or a new `notify_rc` line, and by each radio reporting its VAPs up. `service` returns before the restart begins, so for a few seconds after it SSH still answers and `wlready` still reads 1, and a loop that only checks those exits at once, before the Wi‑Fi link drops *(read on RT-BE90U 3.0.0.6.102_58500: `restart_wireless` issued at uptime 4355, VAPs back up at 4390–4394)*. The wait therefore keys on a marker newer than the call: record `T0=$(cut -d. -f1 /proc/uptime)` in the same SSH call as the `service`, then loop until the marker's kernel timestamp exceeds it, e.g. for a radio restart `until ssh -o ConnectTimeout=3 router "dmesg | grep 'mlme_ext_vap_up: VAP (ath201)' | tail -1 | awk -F'[][]' '{exit !(\$2 > $T0)}'"; do sleep 3; done`, and for a reboot `until ssh -o ConnectTimeout=3 router "test \$(cut -d. -f1 /proc/uptime) -lt $T0"; do sleep 3; done`, run inside the background call that SKILL.md describes. After it returns:

```
CHECK                              COMMAND                                                 DONE WHEN
--------------------------------   -----------------------------------------------------   ------------------------------
the router rebooted                cat /proc/uptime                                         smaller than before the write
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

**Measured durations** (kernel timestamps of restarts already in the log):

```
EVENT                                   2.4 GHz up   6 GHz up   5 GHz up (ch 100, DFS)   WAN restored
-------------------------------------   ----------   --------   ----------------------   ------------
boot (after a firmware flash)           47 s         52 s       113 s (CAC 50.8–112.9)   ~48 s
restart_wireless (from VAPs down)       34 s         38 s       99 s (CAC 62 s)          not dropped
```

A 5 GHz channel outside the DFS range skips the CAC, so 5 GHz then comes up with the other bands; a DFS channel adds the 60‑second-class wait that [regulatory.md § DFS](regulatory.md#dfs) defines. During the CAC the 5 GHz VAPs are down while 2.4 and 6 GHz serve clients.

Keys: `nvram show 2>/dev/null | cut -d= -f1 | grep -xE 'wlready|svc_ready|success_start_service'`

## Network tools and status pages

The System Log and Network Tools pages are views over files httpd writes on request; the same data is one SSH command away, which is the faster read:

```
PAGE                                    SHOWS                                 SSH EQUIVALENT
-------------------------------------   -----------------------------------   ---------------------------------------
System Log › General Log                syslog, uptime, remote syslog         cat /jffs/syslog.log
System Log › Wireless Log               per-band client tables                wlanconfig <vap> list sta
                                        (wlan11b_2g.log via wl_log.asp)
System Log › DHCP leases                leases.log                            cat /var/lib/misc/dnsmasq.leases
System Log › IPv6                       ipv6_network.log                      ip -6 addr; ip -6 route
System Log › Routing Table              route.log                             ip route; ip -6 route
System Log › Port Forwarding            iptable.log                           iptables -t nat -S
System Log › Connections                connect.log                           cat /proc/net/nf_conntrack
Security Update Notification            security_recored.log                  cat /jffs/security_recored.log
Network Tools › Network Analysis        ping / ping6 / traceroute(6) /        same binaries on the router, e.g.
                                        nslookup from the router              ping -c 4 -W 2 1.1.1.1
Network Tools › Netstat                 netstat / netstat-nat                 netstat -tun; netstat-nat -n
Network Tools › Wake on LAN             ether-wake -i br0 <MAC>               (sends a packet: a write)
CPU / RAM widget (cpu_ram_status.asp)   httpd cpu_usage() / memory_usage()   § CPU, memory, connections
```

The pages run their command by posting `SystemCmd` built from their form fields (`cmdMethod`, `destIP`, `pingCNT`, `targetip`, `NetOption`, `ExtOption`, `ResolveName`; `wans_ntool_unit` picks the WAN for dual WAN), and httpd runs it through `syscmd.sh` into `/tmp/syscmd.log` (`grep -n SystemCmd /www/Main_Analysis_Content.asp`). Wake on LAN keeps its saved targets in `wollist` (`wollist_macAddr` is the form field). The router has no `tcpdump`.

The router also carries `iperf3` (`/usr/bin/iperf3`); `iperf3_svr_enable` / `iperf3_svr_port` (0 / 5201) and the `iperf3_cli_*` keys configure a server and client that no `/www/*.asp` page exposes; which daemon reads them is not established, and starting either is a state change *(unverified: `ps w | grep iperf3` after setting `iperf3_svr_enable=1`)*. `conn_diag` is ASUS's connection-diagnostic daemon (`ps w | grep conn_diag`); `conn_diag_ready` reads 1 when it runs, and `diag_interval` (60) is a connection-diagnostic parameter AiMesh syncs to nodes ([merlin.ng cfg_mnt/cfg_param.h](https://github.com/RMerl/asuswrt-merlin.ng/blob/b053ba701af02e46a86d465d82cc2a7891a288a7/release/src/router/cfg_mnt/cfg_param.h#L3397)); the other `diag_*` keys' meanings are not established. The `ahs` daemon logs to `/tmp/ahs.log` and keeps records in `ahs_*` keys (`ahs_bhc_log`, `ahs_dhcp_log`); its purpose is not established.

Keys: `nvram show 2>/dev/null | cut -d= -f1 | grep -xE 'net_log_ifnames|enable_diag|cmdMethod|destIP|pingCNT|targetip|NetOption|ExtOption|ResolveName|wans_ntool_unit|wollist(_macAddr)?|iperf3_.*|conn_diag_ready|diag_(db_path|dbg|interval|local_data|ss_act|syslog2)|ahs_.*'`
