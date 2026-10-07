# Diagnostics

Where the router records what happened, and how to read its live state. Paths and formats *(read on RT-AX53U 3.0.0.4.386_69196)*; re-check on another unit with the command shown.

## Logs

```
LOG               PATH                                     NOTES
---------------   --------------------------------------   ------------------------------------------------
syslog            /jffs/syslog.log (+ /jffs/syslog.log-1)   /tmp/syslog.log* are symlinks to these; on flash,
                                                           so it survives reboots
kernel ring       dmesg                                    RAM only, about 128 KiB, lost at reboot
firmware check    /jffs/webs_upgrade.log (+ -1)            see platform.md § Firmware
AiMesh / config   /tmp/asusdebuglog/                       RAM
```

`ps w | grep -E 'syslogd|klogd'` shows the logger settings: `syslogd -m 0 -S -O /jffs/syslog.log -s 256 -l 6` rotates at 256 KB into a single `.log-1` file and keeps priority 6 (info) and above; `klogd -c 5`. nvram: `log_level` (6), `log_size` (256), `log_ipaddr` / `log_port` (remote syslog, empty = off), `console_loglevel`. The retained window is the time it takes to write about 512 KB, so a high-volume message stream shortens it to hours; `wc -l /jffs/syslog.log*` and the first timestamp of `syslog.log-1` show the current window, and `grep -c '<pattern>' /jffs/syslog.log*` finds the dominant message.

Two read commands also write into the dmesg ring and push older lines out: `iwpriv <if> show stainfo` and `cat /sys/kernel/debug/hnat/hnat_setting`.

**Reading the log by time.** Until NTP syncs after a boot, the router clock starts at a fixed default (`May  5 08:05` on this build), so post-boot lines carry that date until `ntp: start NTP update` and cron's `time disparity of … minutes detected` mark the jump to real time.

## Boots, restarts and crashes

```
QUESTION                         READ
------------------------------   -------------------------------------------------------------------------
when did it last boot            uptime
where boots are in the log       grep -n '\[    0\.000000\] Primary instruction cache' /jffs/syslog.log*
lines before a given boot        L=<line number from that match>; sed -n "$((L-40)),$((L-1))p" <file>
```

An orderly restart (`reboot`, `service reboot`, a UI Apply that reboots) logs the radios shutting down just before the boot: `RTMP_AllTimerListRelease` lines, `pci_fw_own_by_port`, `mt_service_close: wlan service closes successfully!`. A boot whose preceding lines are ordinary traffic with none of these, and a gap in timestamps before it, is a restart without a shutdown: a hang followed by a watchdog reset, a kernel panic, or a power loss. A boot begins with kernel lines stamped `[    0.000000]` (one `Primary instruction cache` line at `0.000000` per boot; the same text repeats at later timestamps for the other CPUs); the Wi‑Fi driver is up at `mt_service_init: wlan service inits successfully!` (about 47 s) and the WAN at `WAN(0) Connection: WAN was restored.`

Crash-related settings: `/proc/sys/kernel/panic` = 3 (reboot 3 s after a panic), `panic_on_oops` = 3; the `watchdog` process and `/tmp/watchdog_heartbeat`; nvram `dev_fail_reboot`. There is no pstore, so a panic message survives only if syslog wrote it to flash before the reset: `grep -nE 'Oops|panic|Call Trace|watchdog' /jffs/syslog.log*`. Scheduled reboots: `reboot_schedule_enable`, `reboot_schedule`.

## Clients

**Summary list.** `cat /tmp/clientlist.json` → `{"<router MAC>":{"2G":{"<client MAC>":{"ip":"…","rssi":"…"}},"5G":{…}}}`, rewritten periodically by `networkmap`; it can lag behind roams.

**Live station table.** `iwpriv rai0 show stainfo; dmesg | tail -60` prints both bands' stations (one DBDC chip), one row per client plus a `MaxCap:` continuation line:

```
MAC  MODE AID WCID BSS PSM WMM MIMOPS RSSI0/1/2/3 PhMd BW MCS SGI STBC Idle Rate QosMap
```

```
COLUMN        MEANING
-----------   ---------------------------------------------------------------------------
BSS / wdevN   which SSID/radio: wdev0 = ra0 (2.4 GHz main), wdev6 = rai0 (5 GHz main) on this unit
PSM           1 = client in power save
RSSI0/1/2/3   per-antenna-chain signal in dBm; −127 = chain unused
PhMd          PHY mode pair, e.g. HE/HE_SU (Wi‑Fi 6), HT_MM (Wi‑Fi 4), OFDM, CCK
BW            channel width pair, e.g. 80M/80M
MCS           pair, "<streams>S-M<mcs>" for VHT/HE (2S-M9 = 2 streams, MCS 9), plain number for HT
Rate          last rate pair in Mbit/s
Idle          seconds left before idle timeout
MaxCap line   client's maximum mode, width, MCS and rate; wdev; connected time hh:mm:ss
```

The pairs are TX/RX per the MT7915 driver's column headers `PhMd(T/R)`, `BW(T/R)`, `MCS(T/R)`, `Rate(T/R)` ([cmm_info.c dump_mac_table](https://github.com/hanwckf/rt-n56u/tree/master/trunk/proprietary/rt_wifi/rtpci/7.3.0.1/mt7915)), i.e. router→client first. A one-liner that extracts MAC, signal, mode, width and MCS: `dmesg | tail -80 | grep -E '^\[[ 0-9.]+\] [0-9A-F]{2}:'`.

**Which band and channel a client is on** = its `wdev` in the station table plus `iwconfig ra0` / `iwconfig rai0`.

## Radio

```
READ                                   COMMAND
------------------------------------   -------------------------------------------------------------
live channel and bitrate               iwconfig ra0 ; iwconfig rai0
allowed channels                       cat /tmp/chanspec_avbl.json   (regulatory.md)
driver profile in effect               grep -viE 'psk|key|pass' /etc/Wireless/iNIC/iNIC_ap.dat
counters, temperature, last rates      iwpriv rai0 stat | grep -v PinCode
driver / firmware / chip               iwpriv rai0 get_driverinfo
radar / CAC history                    dmesg | grep -iE 'CAC|radar|RadarStateCheck'
deauth / kick events                   dmesg | grep -iE 'deauth|kick|disassoc'
```

`iwpriv <if> stat` prints the WPS PINs on `PinCode` lines, hence the filter. Its `CurrentTemperature` is the Wi‑Fi chip temperature in °C, the only temperature sensor exposed (no `/sys/class/thermal`). Other read-only `iwpriv` sub-commands: `get_driverinfo`, `get_mac_table`, `get_ba_table`, `show <item>` (`stainfo`, `channelinfo`, `DfsNOP`, `DfsChInfo`). `iwpriv <if> set …`, `e2p`, `bbp`, `mac`, `rf` change driver or hardware state ([MT7915 ap_cfg.c](https://github.com/hanwckf/rt-n56u/tree/master/trunk/proprietary/rt_wifi/rtpci/7.3.0.1/mt7915)).

## CPU, memory, connections

```
READ                         COMMAND                                         NOTES
--------------------------   ---------------------------------------------   -----------------------------------
overall CPU                  top -bn1 | sed -n 2,3p                          sirq = softirq (packet processing)
per-core load                grep '^cpu[0-9]' /proc/stat, twice, 2 s apart   columns: user nice system idle
                                                                             iowait irq softirq; busy % = 100 −
                                                                             Δidle/Δtotal
load average                 cat /proc/loadavg
memory                       free
tracked connections          cat /proc/sys/net/netfilter/nf_conntrack_count
                             cat /proc/sys/net/netfilter/nf_conntrack_max
```

The MT7621 has 2 cores × 2 hardware threads (VPEs), shown as cpu0–cpu3; `grep -E '^processor|^core|^VPE' /proc/cpuinfo` maps them (cpu0+cpu1 = core 0, cpu2+cpu3 = core 1 on this unit), and two threads of one core share its pipeline. Measuring under load means running the traffic (e.g. `networkQuality -u` on the Mac, in the background) while sampling `/proc/stat`.

## Hardware NAT

The MT7621 packet engine (`mtkhnat` module, `nvram get hwnat`) forwards established NAT flows without the CPU. State: `cat /sys/kernel/debug/hnat/hook_toggle` (1 = on). Bound flows: `tail -1 /sys/kernel/debug/hnat/hnat_entry` (`Total State = BIND cnt = N`); each `NAPT(…)` line names the LAN host and port, so `grep -c '<client IP>:' /sys/kernel/debug/hnat/hnat_entry` counts one client's bound flows. `cat /sys/kernel/debug/hnat/external_interface` lists the Wi‑Fi interfaces registered with the engine as "ext devices" (ra0, rai0 on this unit), and flows of Wi‑Fi clients appear as bound entries. Packets to and from those ext devices still pass through the CPU and the Wi‑Fi driver; the MT7621 has no Wireless Ethernet Dispatch, the block that moves Wi‑Fi traffic without the CPU on later MediaTek SoCs ([openwrt/mt76 #868](https://github.com/openwrt/mt76/issues/868), which also reports higher Wi‑Fi throughput with MediaTek's proprietary driver than with the open-source one). What switches hardware NAT off: [wan-lan.md § QoS](wan-lan.md#qos).
