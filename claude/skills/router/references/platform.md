# Platform

How a stock ASUSWRT router on a MediaTek Wi‑Fi platform is built, configured and maintained. Facts marked *(read on RT-AX53U 3.0.0.4.386_69196)* come from that unit's shell; on another unit re-read them with the command given. Code facts cite the source they were read from.

## Identity

```
WHAT                    COMMAND
---------------------   -------------------------------------------------------------
model                   nvram get productid ; nvram get odmpid
firmware                for k in firmver buildno extendno; do nvram get $k; done
                        (full string: <firmver>.<buildno>_<extendno>)
factory region          nvram get territory_code         (e.g. EU/01, US/01)
SoC                     grep -E 'system type|cpu model' /proc/cpuinfo
kernel                  uname -a
Wi‑Fi chip and driver   iwpriv rai0 get_driverinfo       (driver, FW, HW, CHIP ID)
feature flags           nvram get rc_support             (space-separated list)
```

`rc_support` containing `rawifi` and `mtk` marks the MediaTek platform; the web UI's `Rawifi_support` branch (`/www/state.js`: `isSupport("rawifi")`) is the one that applies. On the RT-AX53U the Wi‑Fi driver is built into the kernel (no wireless module in `lsmod`), runs one MT7915-family chip in DBDC mode (`DBDC_MODE=1` in the driver config: one chip serving both bands), and reports itself as `RTWIFI SoftAP` in `iwconfig` *(read on RT-AX53U 3.0.0.4.386_69196)*.

## Interfaces

```
INTERFACE          ROLE                                   PROOF
----------------   ------------------------------------   -----------------------------------
ra0                2.4 GHz main SSID                      nvram get wl0_ifname ; wl0_nband=2
rai0               5 GHz main SSID                        nvram get wl1_ifname ; wl1_nband=1
ra1–ra5, rai1–5    extra SSIDs (guest wlX.1–wlX.4, …)     .dat SSID<N+1> = ra<N> / rai<N>
apcli0, apclii0    2.4 / 5 GHz client (repeater) links    .dat ApCliEnable
br0                LAN bridge (wired + Wi‑Fi)             brctl show
eth1               WAN port                               nvram get wan0_ifname
eth0, vlan1        LAN switch link / wired LAN            cat /proc/net/vlan/config
ppp0               PPPoE session, when WAN is PPPoE       nvram get wan0_pppoe_ifname
```

`wlX_nband`: `1` = 5 GHz, `2` = 2.4 GHz. Guest SSID `wlX.Y` maps to driver slot `SSID<Y+1>`, interface `ra<Y>` (2.4 GHz) or `rai<Y>` (5 GHz). `ls /sys/class/net` lists every interface; `ifconfig -a` shows which are UP.

## Configuration model

**nvram.** All persistent configuration is nvram, roughly 2,000 keys (`nvram show 2>/dev/null | wc -l`; `nvram show 2>&1 >/dev/null` prints the used and free bytes). `nvram set k=v` changes the running copy; `nvram commit` writes it to flash. `nvram show` lists all keys and values, including credentials, so filter it: `nvram show 2>/dev/null | grep -viE 'passw|psk|key|secret|token|pin'`.

**Per-band keys and the `wl_` working copy.** Wireless settings exist per band as `wl0_<name>` (2.4 GHz) and `wl1_<name>` (5 GHz), per guest SSID as `wl0.1_<name>`…, and once more as an unprefixed `wl_<name>`. The web UI edits `wl_*` together with `wl_unit` (0 = 2.4 GHz, 1 = 5 GHz) and `wl_subunit`, and on Apply copies them to the band keys. `wl_*` holds whatever band the UI last opened, so it can differ from both band keys. The band keys (`wl0_`, `wl1_`) are what rc reads to build the driver config.

**rc and service.** `/sbin/rc` is a multi-call binary; `/sbin/service` and many other applets are symlinks to it (`ls -l /sbin/service`). `service <action>` stores the action in nvram `rc_service` and signals init, which runs it; `restart_X` means stop X then start X ([asuswrt-merlin.ng rc/services.c handle_notifications](https://github.com/RMerl/asuswrt-merlin.ng/blob/1f00a27b78c681abcdacc4d361e3a700c16c734a/release/src/router/rc/services.c), the stock dispatcher, verified by the matching strings in the stock binary). Several actions run in sequence when separated by `;` inside one argument: `service 'restart_qos;restart_firewall'`.

**Generated driver config.** On every radio start rc writes the MediaTek driver profiles from nvram: `/etc/Wireless/RT2860/RT2860.dat` (2.4 GHz), `/etc/Wireless/iNIC/iNIC_ap.dat` (5 GHz) and `/etc/Wireless/RT2860/DBDC_card0.dat` (merged). They live in RAM and are rewritten on each `restart_wireless`, so editing them by hand lasts until the next radio restart. The nvram key that feeds each driver parameter is listed in [wireless.md](wireless.md). The profiles include the Wi‑Fi passphrase; read them filtered: `grep -viE 'psk|key|pass' <file>`.

## Apply actions

The action each web UI page runs on Apply, from the page's hidden `action_script` field (`grep -n 'action_script\|action_mode\|action_wait' /www/<page>.asp`) *(read on RT-AX53U 3.0.0.4.386_69196)*:

```
SETTING AREA                       PAGE                                ACTION
--------------------------------   ---------------------------------   -------------------------------
Wireless › General                 Advanced_Wireless_Content.asp       restart_wireless
Wireless › Professional            Advanced_WAdvanced_Content.asp      restart_wireless
Wireless › MAC filter              Advanced_ACL_Content.asp            restart_wireless
Smart Connect rules                Advanced_Smart_Connect.asp          restart_wireless
Guest network                      Guest_network.asp                   restart_wireless;restart_qos;
                                                                       restart_firewall
WAN                                Advanced_WAN_Content.asp            restart_wan_if <unit>
IPv6                               Advanced_IPv6_Content.asp           restart_net
LAN                                Advanced_LAN_Content.asp            restart_net_and_phy
DHCP server                        Advanced_DHCP_Content.asp           restart_net_and_phy
Firewall                           Advanced_BasicFirewall_Content.asp  restart_firewall
Port forwarding                    Advanced_VirtualServer_Content.asp  restart_firewall
QoS                                QoS_EZQoS.asp                       static saveNvram; JS sets
                                                                       restart_qos;restart_firewall (Rawifi),
                                                                       restart_upnp, or reboot, and may
                                                                       prepend restart_wireless
Administration › System            Advanced_System_Content.asp         restart_time;restart_upnp; JS adds
                                                                       restart_usb_idle, restart_httpd,
                                                                       restart_ftpd, restart_firewall,
                                                                       restart_bhblock, restart_chg_swmode,
                                                                       pwrsave, pagecache_ratio, or replaces
                                                                       all with reboot, depending on fields
Operation mode                     Advanced_OperationMode_Content.asp  restart_all
```

The full set of actions the UI uses: `cd /www && grep -ohE 'action_script.{0,4}=.{0,3}"[a-z_;]+' *.asp *.js js/*.js | sort | uniq -c`. The rc binary also names its handlers (`strings /sbin/rc | grep -E '^(restart|start|stop)_'`), though short names are merged into longer strings there, so that list is incomplete.

What each action stops and starts ([rc/services.c](https://github.com/RMerl/asuswrt-merlin.ng/blob/1f00a27b78c681abcdacc4d361e3a700c16c734a/release/src/router/rc/services.c), [rc/lan.c](https://github.com/RMerl/asuswrt-merlin.ng/blob/1f00a27b78c681abcdacc4d361e3a700c16c734a/release/src/router/rc/lan.c), Merlin source shared with stock):

```
ACTION                 EFFECT                                                     DROPS
--------------------   --------------------------------------------------------   -------------------------
restart_wireless       regenerates the .dat files, restarts both radios,          all Wi‑Fi clients
                       firewall, NAT rules, dnsmasq, roaming daemon, HW NAT
restart_net            restarts httpd, sshd, dnsmasq, UPnP, WAN, LAN, VLANs       web UI, SSH, internet
restart_net_and_phy    restart_net + file sharing + restart_wireless +            everything incl. wired
                       switch PHY re-init
restart_wan_if <n>     stops and starts WAN unit n, LAN IPv6, IPv6 dnsmasq        internet
restart_firewall       rebuilds iptables, HW NAT re-init                          nothing persistent
restart_dnsmasq        restarts DNS/DHCP server                                   DNS and DHCP while it restarts
restart_upnp           restarts miniupnpd                                         UPnP mappings
restart_qos            stops QoS and the DPI engine, re-applies QoS rules         —
restart_time           restarts cron, NTP, telnetd, sshd, logger, httpd            SSH session
reboot                 full shutdown and boot                                     everything
```

No measured downtime figures are published; the UI countdown (`action_wait`) is a fixed timer, not a measurement.

## Files and persistence

`/tmp` is RAM, and `/etc`, `/var`, `/root`, `/home`, `/mnt`, `/opt` are symlinks into it, so anything written there is gone after a reboot ([captn3m0/RT-AX53U rootfs](https://github.com/captn3m0/RT-AX53U/tree/3b8c2d2ca5509e2207e2bb1ff593d36d389a3c7d/)). `/jffs` is a flash partition that survives reboots; stock firmware keeps there the SSH host keys (`/jffs/.ssh`), the syslog (`/jffs/syslog.log`, `syslog.log-1`), firmware-check logs (`webs_upgrade.log`) and AiProtection/AiMesh data (`/jffs/.sys`). `ls -la /jffs` lists it.

Stock firmware runs no user scripts: `/jffs/scripts` and the `service-event` hook are Asuswrt-Merlin features ([README-merlin.txt](https://github.com/RMerl/asuswrt-merlin.ng/blob/1f00a27b78c681abcdacc4d361e3a700c16c734a/README-merlin.txt)), and the stock RT-AX53U image contains no `jffs/scripts` string. Changes made outside nvram therefore last until the next reboot or service restart. Asuswrt-Merlin does not support the RT-AX53U ([supported devices](https://github.com/RMerl/asuswrt-merlin.ng/wiki/Supported-Devices)).

## Firmware

**Checking.** `/usr/sbin/webs_update.sh` runs the rc applet `firmware_check_update`, which fetches ASUS's control file from `dlcdnets.asus.com`, compares versions, and writes the result to nvram:

```
KEY                   MEANING
-------------------   ------------------------------------------------------
webs_state_info       newest build available, e.g. 3004_386_69196-g13d8e95
webs_state_update     1 = check finished
webs_state_error      0 = no error
webs_state_flag       non-zero = newer firmware available
webs_update_enable    1 = automatic nightly check
webs_update_time      HH:MM of the automatic check
```

`/usr/sbin/webs_update.sh; sleep 8; nvram get webs_state_info` runs a check; repeated calls within about a minute return the previous result (`webs_update_ts`). The log is `/jffs/webs_upgrade.log` (rotated to `webs_upgrade.log-1`).

**Installing.** Firmware is installed from the web UI (Administration › Firmware Upgrade, manual upload or the update button), from the ASUS Router app, or automatically when Auto Firmware Upgrade is on ([ASUS FAQ 1008000](https://www.asus.com/support/faq/1008000/)). An interrupted flash is recovered with Firmware Restoration: set the computer to 192.168.1.10/255.255.255.0, hold Reset while powering on until the power LED flashes slowly, upload the image with ASUS's Firmware Restoration utility ([ASUS FAQ 1000814](https://www.asus.com/us/support/faq/1000814/)). Release history: [ASUS support API](https://www.asus.com/support/api/product.asmx/GetPDBIOS?website=global&model=RT-AX53U).

## Reset

```
METHOD                                    ERASES                               SOURCE
---------------------------------------   ----------------------------------   ---------------------------------------------
Administration › Restore/Save/Upload      nvram and log                        https://www.asus.com/support/faq/1000925/
 › Restore
same, with "Initialize all settings"      + AiProtection, Traffic Analyzer,    https://www.asus.com/support/faq/1035717/
                                          Web History databases
Reset button, hold 5–10 s                 nvram (same as Restore)              https://www.asus.com/support/faq/1000925/
Hard reset (RT-AX53U): power off,         everything                           https://www.asus.com/us/support/faq/1039077/
 hold WPS, power on, release when
 power LED flashes
```

Administration › Restore/Save/Upload › Save setting downloads an nvram backup (`.CFG`) that the same page restores.

## SSH

Administration › System › Service sets `sshd_enable` (`0` = No, `2` = LAN only, `1` = LAN & WAN), `sshd_port` (default 22), `sshd_pass` (`1` allows password login, `0` keys only) and `sshd_authkeys` (public keys, up to 2,999 characters) (`/www/Advanced_System_Content.asp` on the unit, [ASUS FAQ 1048201](https://www.asus.com/support/faq/1048201/)). The server is dropbear; "LAN only" is enforced by the firewall, which opens the WAN port only when `sshd_enable=1` ([rc/firewall.c](https://github.com/RMerl/asuswrt-merlin.ng/blob/1f00a27b78c681abcdacc4d361e3a700c16c734a/release/src/router/rc/firewall.c)). The login user is the web admin account (`nvram get http_username`), uid 0. Keys from `sshd_authkeys` are written to `/root/.ssh/authorized_keys` in RAM at each sshd start; host keys persist in `/jffs/.ssh`. Saving the System page runs `restart_time`, which restarts sshd and ends open sessions.

Related access settings on the same page: `telnetd_enable` (1/0), `http_enable` (`0` HTTP, `1` HTTPS, `2` both), `http_lanport`, `https_lanport`, `misc_http_x` (web access from WAN, 1/0) with `misc_httpport_x` / `misc_httpsport_x`.
