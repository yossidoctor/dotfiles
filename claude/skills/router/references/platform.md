# Platform

How the router is built, configured and maintained, and the Administration and USB pages. Facts marked *(read on RT-BE90U 3.0.0.6.102_58500)* come from this unit's shell; re-read them with the command given after a firmware change. Code facts cite [asuswrt-merlin.ng](https://github.com/RMerl/asuswrt-merlin.ng/tree/b053ba701af02e46a86d465d82cc2a7891a288a7) at commit b053ba7, whose generic `rc`, `httpd` and `libwebapi` code is shared with stock firmware; that tree carries no Qualcomm `sysdeps`, so Qualcomm-specific behaviour rests on the unit.

## Identity

```
WHAT                     COMMAND
----------------------   ----------------------------------------------------------------
model                    nvram get odmpid      (RT-BE90U, the name on the box)
                         nvram get productid   (TUF-BE9400, the build target; ASUS sources
                                               and downloads for TUF-BE9400 apply)
firmware                 for k in firmver buildno extendno; do nvram get $k; done
                         (string: <firmver>.<buildno>_<extendno>)
board                    cat /proc/device-tree/model ; cat /proc/device-tree/compatible
kernel                   uname -a
feature flags            nvram get rc_support   (space-separated; the web UI's isSupport())
```

`rc_support` containing `qca` and `qcawifi` marks the Qualcomm platform; `wifi7`, `mlo`, `amas`, `bwdpi`, `wireguard`, `vpn_fusion` are other flags the UI branches on *(read on RT-BE90U 3.0.0.6.102_58500)*.

Keys: `nvram show 2>/dev/null | cut -d= -f1 | grep -xE '(HwId|asus_mfg|asus_mfg_flash|odmpid|productid|firmver|buildno|extendno|rc_support|model|modelname|hardware_version|HwVer|HwBom|DCode|CoBrand|boardnum|boardflags|blver|bl_version|buildinfo|build_name|build_time|nvramver|serial_no|secret_code|label_mac|et[0-9]macaddr|wl[0-9]macaddr|uuid|asus_device_list|innerver|swpjverno|cpurev|cpu_model)'`

## Hardware

*(read on RT-BE90U 3.0.0.6.102_58500)*

```
PART          WHAT THE UNIT REPORTS                                  READ WITH
-----------   ----------------------------------------------------   ------------------------------------------
SoC           Qualcomm IPQ5332 ("qcom,ipq5332-asus-be6500")           cat /proc/device-tree/compatible
CPU           4 × ARMv8 (implementer 0x51, part 0x801),               grep -c ^processor /proc/cpuinfo
              1.1 / 1.5 GHz steps, governor performance              cat /sys/devices/system/cpu/cpu0/cpufreq/
                                                                     scaling_available_frequencies scaling_governor
RAM           ~860 MiB to Linux, 256 MiB zram swap                    free ; cat /proc/swaps
flash         NAND, mtd partitions below                             cat /proc/mtd
2.4 GHz       wifi0, IPQ5332's own radio (driver cnss2), 2×2          readlink /sys/class/net/wifi0/device
5 GHz         wifi1 ┐ one PCIe chip, ID 17cb:1109 = QCN9274           cat /sys/bus/pci/devices/0001:01:00.0/device
6 GHz         wifi2 ┘ (ath12k pci.c), driver cnss_pci, 2×2 each       cfg80211tool wifiN get_txchainmask
WAN port      eth0, 2.5 GbE                                          cat /tmp/diag_port_status.json
LAN ports     3 × 2.5 GbE behind eth1 (switch uplink at 2500)         cat /sys/class/net/eth1/speed
USB           1 port, USB 3 (5 Gbit/s), xHCI                          cat /tmp/diag_port_status.json ; lsusb
```

QCN9274 is the device ID `0x1109` in Linux's ath12k driver ([pci.c](https://github.com/torvalds/linux/blob/ffc253263a1375a65fa6c9f62a893e9767fbebfa/drivers/net/wireless/ath/ath12k/pci.c#L39)); the stock firmware drives it with Qualcomm's proprietary `qca_ol`/`wifi_3_0`/`umac` modules (`lsmod`), not ath12k. Port names, maximum and current link rates per port: `/tmp/diag_port_status.json` (`ui_display`, `max_rate`, `link_rate`, `is_on`). The radio modes, widths and MLO the radios run are in [wireless.md](wireless.md#radios-vaps-and-ssid-storage); the channels and power they may use in [regulatory.md](regulatory.md#channels-on-this-unit).

## Interfaces

Every interface in `ip -br link` *(read on RT-BE90U 3.0.0.6.102_58500)*:

```
INTERFACE                    ROLE                                                   PROOF
--------------------------   ----------------------------------------------------   ----------------------------------
eth0                         WAN port                                               nvram get wan_ifnames
eth1                         CPU link to the LAN switch (3 LAN ports)               /tmp/diag_port_status.json ifname
eth1.1                       LAN VLAN 1 on eth1, member of br0                      cat /proc/net/vlan/config
br0                          LAN bridge: eth1.1 + every Wi‑Fi VAP                   brctl show ; nvram get lan_ifnames
ppp0                         PPPoE session on eth0                                  nvram get wan0_pppoe_ifname
wifi0 / wifi1 / wifi2        radio devices: 2.4 / 5 / 6 GHz                         nvram get wl0_nband (2=2.4, 1=5, 4=6)
ath0 / ath1 / ath2           main VAP of each radio (wlX); carries the AiMesh       cat /sys/class/net/athN/parent
                             backhaul SSID, hidden                                  nvram get wl_ifnames
ath001 / ath101 / ath201     wlX.1 VAPs: the SSID shown in the UI                   nvram get wlX.1_ifname
ath002                       wl0.4 VAP on 2.4 GHz                                   nvram get wl0.4_ifname
mld-wifi0                    MLO multi-link device, DOWN while no MLO network      ip -br link ; nvram get mlo_rl
soc0 / soc1                  Wi‑Fi SoC control devices (cnss2 / cnss_pci), DOWN     readlink /sys/class/net/socN/device
bond0                        bonding master, round-robin, no slaves, DOWN           cat /proc/net/bonding/bond0
imq0–imq7                    IMQ queueing devices, DOWN                             ip -br link
gre0 gretap0 erspan0         fallback devices of the tunnel drivers, DOWN           see note
ip6tnl0 ip_vti0 ip6_vti0
miireg                       driver-internal device, DOWN, no traffic               ip -br link
lo                           loopback
```

What each VAP serves and why `ath0`–`ath2` carry a hashed SSID is in [wireless.md § Radios, VAPs and SSID storage](wireless.md#radios-vaps-and-ssid-storage). The kernel creates fallback tunnel devices (`gre0`, `gretap0`, `erspan0`, `ip6tnl0`, …) whenever the matching tunnel driver is present ([net.rst `fb_tunnels_only_for_init_net`](https://github.com/torvalds/linux/blob/219d54332a09e8d8741c1e1982f5eae56099de85/Documentation/admin-guide/sysctl/net.rst)). `ls /sys/class/net` lists every interface; `ip -br link` shows which are UP.

## Configuration model

**nvram.** All persistent settings are nvram key=value pairs (`nvram show 2>/dev/null | wc -l`; `nvram show 2>&1 >/dev/null` prints used and free bytes). `nvram get <key>` reads one key per call, so several keys are read with a loop. `nvram set k=v` changes the running copy; `nvram commit` writes it to the `nvram` mtd partition (`cat /proc/mtd`). `/bin/nvram` accepts `commit` although its usage text omits it (`strings /bin/nvram | grep -x commit`) *(read on RT-BE90U 3.0.0.6.102_58500; the write itself unverified)*. `nvram show` prints credentials (PSKs, PPPoE, VPN keys), so list names with `nvram show 2>/dev/null | cut -d= -f1` and read values filtered: `nvram show 2>/dev/null | grep -viE 'psk|passw|key|secret|token|pin|phrase'`.

**Unit prefixes.** Per-instance settings carry a unit in their prefix: `wl0_`/`wl1_`/`wl2_` (2.4/5/6 GHz radio), `wl0.1_`… (VAP 1… of radio 0), `wan0_`/`wan1_` (WAN units), `apg1_`… (Guest Network Pro profiles), `vpn_client1_`… The unprefixed `wl_`, `wan_` forms are working copies the older pages edit (with `wl_unit`/`wl_subunit`, `wan_unit` naming the instance). The newer pages name bands as `2g1_`/`5g1_`/`6g1_`; httpd rewrites the Nth entry of `wlnband_list` (`2g1<5g1<6g1` on this unit) to `wlN_`, so `6g1_ssid` is `wl2_ssid` ([libwebapi webapi.c `wl_nband_to_wlx`](https://github.com/RMerl/asuswrt-merlin.ng/blob/b053ba701af02e46a86d465d82cc2a7891a288a7/release/src/router/libwebapi/webapi.c#L622); the function is in the unit's `/usr/sbin/httpd`: `strings /usr/sbin/httpd | grep -x wl_nband_to_wlx`).

**How a UI Apply lands.** A page posts its fields plus `action_mode=apply` and `action_script` (older pages, via `start_apply.htm`) or `rc_service` (pages using `httpApi.nvramSet`, which posts to `applyapp.cgi`). httpd stores the fields, then: `saveNvram` stores only; with AiMesh config sync running (`pidof cfg_server`, `cfg_master=1` on this unit) a changed setting signals `cfg_server`, which syncs it to nodes and runs the action; otherwise httpd sets `freeze_duck=15` (pauses WAN monitoring for 15 s) and runs the action ([httpd/web.c L6209–6235](https://github.com/RMerl/asuswrt-merlin.ng/blob/b053ba701af02e46a86d465d82cc2a7891a288a7/release/src/router/httpd/web.c#L6209)). A change made over SSH skips httpd's page logic (field coercions, cfg_server sync), so it lands exactly as written and only on this unit.

**rc and service.** `/sbin/rc` is a multi-call binary; `/sbin/init` and `/sbin/service` are symlinks to it (`ls -l /sbin/service /sbin/init`). `service <action>` hands the action to init ([rc/services.c `service_main`](https://github.com/RMerl/asuswrt-merlin.ng/blob/b053ba701af02e46a86d465d82cc2a7891a288a7/release/src/router/rc/services.c#L24518)), which reads it from nvram `rc_service`, splits it on `;`, and runs each part: `start_X`, `stop_X`, `restart_X` (stop then start), or a bare name ([`handle_notifications`](https://github.com/RMerl/asuswrt-merlin.ng/blob/b053ba701af02e46a86d465d82cc2a7891a288a7/release/src/router/rc/services.c#L15845)). Several actions run in sequence from one argument: `service 'restart_qos;restart_firewall'`.

Keys: `nvram show 2>/dev/null | cut -d= -f1 | grep -xE '(p_Setting|w_apply|setting_update_time|rcno_org|eth_ifnames|wired_ifnames|w2_ifnames|rc_service|rc_service_pid|freeze_duck|wlnband_list|wl_ifnames|w_Setting|x_Setting|r_Setting|uiFlag|reboot_.*_hint|restart_.*|rcno|init_.*|invoke_.*|wait_.*|start_.*|stop_.*|reload_.*|fetch_.*|script_.*)'`

## Apply actions

A page's action: `ssh router "grep -ohE '(action_script\"? *(value=|\.value *=|:) *\"|rc_service\"?: *\")[A-Za-z_][A-Za-z0-9_ ;]*' /www/<page>.asp | sort -u"`. Several values mean the page's JavaScript picks one by what changed; the section for that page says which. What the actions the UI uses stop and start ([rc/services.c `handle_notifications`](https://github.com/RMerl/asuswrt-merlin.ng/blob/b053ba701af02e46a86d465d82cc2a7891a288a7/release/src/router/rc/services.c#L15845), generic code; the Qualcomm radio bring-up inside `restart_wireless` is not in that tree):

```
ACTION                  STOPS AND STARTS                                              DROPS
---------------------   -----------------------------------------------------------   ------------------------------
restart_wireless        networkmap, hardware-acceleration re-init, every radio         all Wi‑Fi clients
                        and VAP, AiMesh bandwidth helpers
restart_sdn [idx]       per-network (SDN) WAN rules, routing, dnsmasq, stubby;        clients of those networks
                        all networks without an index
restart_net             httpd, sshd, dnsmasq, UPnP, WAN, LAN, VLANs, wireless          web UI, SSH, internet, LAN
                        daemons                                                        while it restarts
restart_net_and_phy     restart_net + file sharing + Wi‑Fi interfaces down/up          everything incl. wired links
restart_wan_if <n>      WAN unit n, LAN IPv6, IPv6 dnsmasq                              internet
restart_wan             all WANs, UPnP                                                 internet
restart_firewall        acceleration re-init, default filter, parental block,         nothing persistent
                        iptables rebuild
restart_qos             iQoS and its rules, DPI engine, acceleration re-init           —
restart_wrs             AiProtection/DPI engine                                        —
restart_dnsmasq         DNS and DHCP server                                            DNS/DHCP while restarting
restart_upnp            miniupnpd                                                      UPnP mappings
restart_time            cron, NTP, telnetd, sshd, logger, httpd, firewall              SSH session, web UI
restart_logger          syslogd/klogd                                                  —
restart_ddns            DDNS client                                                    —
restart_ftpsamba        FTP and Samba                                                  file-share sessions
restart_media           DLNA and iTunes servers                                        media sessions
restart_webdav          WebDAV (AiCloud), UPnP, firewall                               AiCloud sessions
restart_openvpnd / _wgs / _wgc   OpenVPN server / WireGuard server / client           tunnels of that service
restart_all             sets sys_reboot_reason=rc_all and terminates init: reboot    everything
reboot                  WAN stop, full reboot                                         everything
```

`restart_time` and `restart_net` kill the SSH session that ran them; `restart_wireless`, `restart_net*` and `reboot` drop a Wi‑Fi‑connected Mac. The UI countdown (`action_wait`) is a fixed timer, not a measurement; measured recovery markers are in [diagnostics.md § Restart safety](diagnostics.md#restart-safety).

## Files and persistence

*(read on RT-BE90U 3.0.0.6.102_58500)* `/` is a read-only squashfs (`/dev/mtdblock6`, the `rootfs` partition named in `/proc/cmdline`); `/www` is a read-only overlay of it; `/tmp` is RAM, and `/etc`, `/root` and `/home` are symlinks into it (`ls -ld /etc /root /home`), so anything written there is gone after a reboot. `/jffs` is a UBIFS volume on flash (`mount | grep jffs`, about 64 MB) that survives reboots: SSH host keys (`/jffs/.ssh`), the syslog (`/jffs/syslog.log`, `-1`), `hostapd.log`, firmware-check log (`webs_upgrade.log`), AiMesh and speed-test data (`/jffs/.sys`), AiProtection data (`/jffs/asd*`, `aae.log`). `ls -la /jffs` lists it.

Stock firmware runs no user scripts: `/jffs/scripts` and the `service-event` hook are Asuswrt-Merlin features ([README-merlin.txt](https://github.com/RMerl/asuswrt-merlin.ng/blob/b053ba701af02e46a86d465d82cc2a7891a288a7/README-merlin.txt)), and the unit's rc carries no `jffs/scripts` string (`strings /sbin/rc | grep -c jffs/scripts` prints 0). A change made outside nvram lasts until the file's owner rewrites it: the next service restart for generated files under `/tmp` and `/etc`, the next reboot at the latest.

## Firmware

**Version and check.** The running build is `<firmver>.<buildno>_<extendno>` ([§ Identity](#identity)). The nightly check and the Check button write their result to nvram *(read on RT-BE90U 3.0.0.6.102_58500)*:

```
KEY                        MEANING
------------------------   -----------------------------------------------------------
webs_state_info            newest build ASUS offers, e.g. 3006_102_58500-g482542d_…
webs_state_flag            0 = up to date; 1 or 2 = newer firmware available (2 offers
                           "Upgrade At Night"; do_show_confirm in the page)
webs_state_update          1 = last check finished
webs_state_error           0 = no error
webs_update_enable         1 = Auto Firmware Upgrade on (installs at webs_update_time)
webs_update_time           HH:MM for the automatic upgrade
webs_update_beta           1 = include beta builds
firmver_org, buildno_org,  the build the page's "Revert" downloads from ASUS
extendno_org
```

`/usr/sbin/webs_update.sh` runs a check; its log is `/jffs/webs_upgrade.log`. `webs_update_ts` holds the last check as `<epoch>><trigger>`.

**Installing.** Administration › Firmware Upgrade takes a manual upload or installs ASUS's newest build; the page's actions are `start_webs_upgrade`, `start_sig_check` (security signature update) and `stop_upgrade;start_revert_fw` (Revert, which downloads the `_org` build: `revert_link` in `/www/Advanced_FirmwareUpgrade_Content.asp`). With AiMesh nodes, the same page lists and upgrades each node. The flash holds two kernel/rootfs pairs (`linux`/`rootfs`, `linux2`/`rootfs2` in `/proc/mtd`); `/proc/cmdline` names the one running.

Keys: `nvram show 2>/dev/null | cut -d= -f1 | grep -xE '(upgrade_fw_status|auto_upgrade|[a-z]+_sigver|enc_sp_extendno|rsasign_check|ateUpgrade_flag|webs_.*|firmver_org|buildno_org|extendno_org|fwpath|firmware_.*|afwupg_.*|betaupg_.*|sig_.*|ateUpgrade|asdfile_.*|apps_.*_ver|live_update_.*|sw_ver)'`

## Reset and rescue

```
METHOD                                         ERASES                                    SOURCE
--------------------------------------------   ---------------------------------------   ----------------------------------------
Administration › Restore/Save/Upload ›          nvram (all settings)                      https://www.asus.com/support/faq/1000925/
 Factory default › Restore
same, with the "clear all content and data      + data logs of each function              EN.dict lines 3621–3622 on the unit
 logs" option
Reset button, hold 5–10 s until the power       nvram                                     https://www.asus.com/support/faq/1000925/
 LED flashes
Save setting                                    nothing: downloads Settings_<productid>   /www/Advanced_SettingBackup_Content.asp
                                                .CFG, which Restore setting re-uploads
```

**Rescue (Firmware Restoration).** Power off; hold Reset while powering on until the power LED flashes slowly; give a wired computer the static address the FAQ names; upload the unzipped firmware with ASUS's Firmware Restoration utility (Windows) ([ASUS FAQ 1000814](https://www.asus.com/support/faq/1000814/); the FAQ's example is another model and notes steps may differ per model).

Keys: `nvram show 2>/dev/null | cut -d= -f1 | grep -xE 'restore_defaults'`

## SSH

*(read on RT-BE90U 3.0.0.6.102_58500)* Administration › System › Service sets:

```
KEY             VALUES = UI LABEL                                   EFFECT
-------------   ------------------------------------------------   ------------------------------------------------
sshd_enable     0 = No, 2 = LAN only, 1 = LAN & WAN                 1 adds an INPUT accept for the port on WAN
sshd_port       1–65535, default 22                                 dropbear -p
sshd_pass       1 = password login allowed, 0 = keys only           0 adds dropbear -s
sshd_authkeys   public keys, one per line in the UI                 written to /root/.ssh/authorized_keys (RAM)
                                                                    at each sshd start
```

The server is dropbear (`dropbear -V`), running as `dropbear -p 22 -a -s` on this unit (`ps w | grep dropbear`); `-a` lets any host connect to forwarded ports. The firewall opens the SSH port on WAN only when `sshd_enable=1` ([rc/firewall.c L5135](https://github.com/RMerl/asuswrt-merlin.ng/blob/b053ba701af02e46a86d465d82cc2a7891a288a7/release/src/router/rc/firewall.c#L5135)); `iptables -S INPUT | grep -- '--dport 22'` prints nothing when SSH is LAN-only. Host keys are generated once into `/jffs/.ssh` and linked into `/etc/dropbear`, keys from `sshd_authkeys` are rewritten at every sshd start ([rc/ssh.c](https://github.com/RMerl/asuswrt-merlin.ng/blob/b053ba701af02e46a86d465d82cc2a7891a288a7/release/src/router/rc/ssh.c#L17-L92)). The login name is the web admin account (`nvram get http_username`) with root rights. Saving the System page runs `restart_time`, which restarts sshd and ends open sessions. BusyBox lacks `id`; `ping` takes `-c`/`-W`/`-w`.

Keys: `nvram show 2>/dev/null | cut -d= -f1 | grep -xE '(sshd_.*|telnetd_.*|shell_timeout(_x)?|access_(ssh|telnet|webui)|dropbear_.*)'`

## Administration

**Operation mode** (`Advanced_OperationMode_Content.asp`, action `restart_all`, which reboots):

```
UI LABEL                                         sw_mode   wlc_express   wlc_psta
----------------------------------------------   -------   -----------   --------
Wireless router mode / AiMesh Router (Default)   1         0             0
Repeater mode                                    2         0             0
Express Way 2.4GHz / 5GHz                        2         1 / 2         0
Access Point (AP) mode / AiMesh Router in AP     3         0             0
Media Bridge                                     4         0             0
AiMesh Node                                      5         —             —
Public WiFi Mode (WISP)                          6         0             0
```

The page also offers the SSID and key per band for the new mode. What each mode keeps and turns off is the description the page shows for it (`EN.dict` strings set into `mode_desc`: `grep -n -B8 'mode_desc' /www/Advanced_OperationMode_Content.asp`).

**System** (`Advanced_System_Content.asp`). The action is built from what changed: always `restart_time;restart_upnp;`, plus `restart_usb_idle;` (HDD hibernation), `restart_httpd;` (web access ports/protocol, with `restart_ftpd;` when FTP-over-TLS is on), `restart_firewall;` (WAN access, access restriction), `restart_bhblock;` (backhaul client block), `restart_chg_swmode;` (operation-mode radio), `pwrsave;`, `pagecache_ratio;`, `chgntfsdrv;` (NTFS driver), or `reboot` alone when the USB mode changes (`grep -n action_script_tmp /www/Advanced_System_Content.asp`).

```
GROUP                 KEYS                                                       VALUES / MEANING
-------------------   --------------------------------------------------------   ---------------------------------------------
login                 http_username, http_passwd                                 admin account (also the SSH login)
local access          http_enable, http_lanport, https_lanport                   0 HTTP, 1 HTTPS, 2 both; ports
remote access         misc_http_x, misc_httpport_x, misc_httpsport_x             web UI from WAN 1/0 and its ports
access restriction    http_client, http_clientlist, enable_acc_restriction,      allow-list of LAN/WAN addresses per service
                      restrict_rulelist
session               http_autologout (minutes, 0 = never), captcha_enable,      UI logout, login captcha, SSH idle (s)
                      shell_timeout
time                  time_zone, time_zone_dst, time_zone_dstoff, ntp_server0    TZ string, DST rule, NTP server
USB                   usb_usb3 (0 USB 2.0 / 1 USB 3.0, reboots), usb_idle_enable,  USB mode, HDD spin-down, NTFS driver
                      usb_idle_timeout, usb_ntfs_mod (ntfs3 / open = ntfs-3g)
network monitoring    dns_probe, dns_probe_host, dns_probe_content,              "Network Monitoring": DNS query (resolve
                      wandog_enable, wandog_target                               hostname, expected content) / ping target
reboot schedule       reboot_schedule_enable, reboot_schedule_type,              periodic reboot; packed day/time strings
                      reboot_schedule, reboot_schedule_month
buttons, power        btn_ez_radiotoggle, btn_ez_mode, pwrsave_mode              WPS Button behavior; 0 Performance,
                      (0/1/2), pagecache_ratio                                   1 Auto, 2 Power Save; page-cache cap %
redirect              nat_redirect_enable                                        WAN-down browser redirect notice
backhaul clients      ncb_enable_option (0/1/2)                                  "Allow 5GHZ backhaul client connections":
                                                                                 do not / limited / completely block
```

**Privacy, feedback, notifications, account binding, Alexa/IFTTT.** `Advanced_Privacy.asp` (`TM_EULA`, the Trend Micro end-user agreement state), `Advanced_Feedback.asp` and `Feedback_Info.asp` (`fb_*` feedback form, action `restart_sendfeedback`; its debug-log capture is in [diagnostics.md § Logs](diagnostics.md#logs)), `Advanced_Notification_Content.asp` (`nc_*`, `PM_*` e-mail settings), `Advanced_Web_Account_Binding.asp` (`oauth_*`, ASUS account), `Advanced_Smart_Home_Alexa.asp` (`alexa_*`, `ifttt_*`, `aae_*`, `awsiot*`).

Keys: `nvram show 2>/dev/null | cut -d= -f1 | grep -xE '(reboot_time|AllLED_brightness|httpds?_.*|shell_username|force_change|app_access|app_cnonce_list|aws_ca_.*|sw_mode|wlc_express|wlc_psta|http_.*|https_.*|misc_http.*|enable_acc_restriction|restrict_rulelist|captcha_enable|time_zone.*|ntp_.*|dst_.*|reboot_schedule.*|reboot_date_x|reboot_time_x|btn_.*|pwrsave_mode|pagecache_ratio|ncb_enable.*|link_internet|fb_.*|nc_.*|NOTIFY_.*|PM_.*|pushnotify_.*|oauth_.*|alexa_.*|ifttt_.*|aae_.*|awsiot.*|amazon_.*|asusctrl_.*|ASUS_.*|led_.*|AllLED|lp55xx_.*|login_.*|account.*|computer_name|preferred_lang)'`

## USB applications

Pages under USB Application, each applying its own service ([§ Apply actions](#apply-actions)):

```
PAGE                                  FUNCTION                        KEYS (prefix)                      ACTION
-----------------------------------   -----------------------------   --------------------------------   -----------------------------
Advanced_AiDisk_samba.asp             Samba share                     enable_samba, st_samba_*, smbd_*,  restart_ftpsamba
                                                                      st_max_user, computer_name
Advanced_AiDisk_ftp.asp               FTP share                       enable_ftp, ftp_*, st_ftp_*        restart_ftpsamba (+firewall)
mediaserver.asp                       DLNA / iTunes server            dms_*, daapd_*                     restart_media
PrinterServer.asp                     network printer                 usb_printer, u2ec_*, printer_*     restart_lpd;restart_u2ec
Advanced_Modem_Content.asp            3G/4G/5G USB modem as WAN        modem_*, Dev3G, ttl_*              reboot
Advanced_TimeMachine.asp              Time Machine target             timemachine_enable, tm_*           restart_timemachine
cloud_*.asp, aicloud_qis.asp          AiCloud (WebDAV, sync)          webdav_*, enable_webdav*,          restart_webdav,
                                                                      cloud_*, enable_cloudsync,         restart_cloudsync
                                                                      share_link_*
APP_Installation.asp, aidisk.asp      app list, AiDisk wizard         apps_*                             —
```

Attached storage: `mount | grep /tmp/mnt` and `cat /proc/scsi/scsi`; `lsusb` lists only the root hubs when nothing is plugged in.

Keys: `nvram show 2>/dev/null | cut -d= -f1 | grep -xE '(MFP_busy|mfp_ip_.*|misc_lpr_x|acc_num|acc_webdavproxy|app_mnt(_ts)?|enable_samba_tuxera|tencent_download_.*|enable_samba|enable_ftp|st_.*|smbd_.*|ftp_.*|dms_.*|daapd_.*|usb_printer|u2ec_.*|printer_.*|modem_.*|Dev3G|timemachine_enable|tm_.*|webdav_.*|enable_webdav.*|cloud_.*|enable_cloudsync|share_link_.*|apps_(action|flag|name|path|depend_.*|dev|download_.*|install_folder|ipkg_.*|local_space|mounted_path|new_arm|state_.*|swap_.*|wget_timeout)|usb_.*|diskmon_.*|diskformat_.*|diskremove_.*|xhci_.*|ehci_.*|ohci_.*|usbctrlver|ss_support|mt_daapd_.*|hdspindown.*)'`

## Internal keys

`coordinate` (latitude, longitude, country) and `asn_name` (the ISP's AS name) are the router's own geolocation lookup; they locate the household, so read them only when the task needs them.

Keys no page sets and no other section owns: bookkeeping that daemons write at runtime (`*_state`, `*_ready`, `*_pid`, timestamps), factory test (`Ate*`), and helpers of features this unit does not run. Read them for diagnosis; their writers are the daemons named by the prefix (`strings /sbin/rc | grep -w <key>` finds rc's uses).

Keys: `nvram show 2>/dev/null | cut -d= -f1 | grep -xE '(atcover_.*|asn_name|coordinate|3rd-party|disiosdet|enable_cloudcheck|guard_mode|link_ap|wsup_dbg|Ate.*|ate_.*|env_.*|shell|freeze|noconsole|monitorproc|chknvram|nvram_.*|temp_.*|pwr_.*|asd_.*|asdfile|ubifs_.*|sd_.*|[0-9a-f]{8}.*)'`

## Page-only fields

Names the pages use as form controls, JavaScript template fragments (`_addr`, `_psk`… joined to a unit prefix at runtime) or fields of features this unit lacks (DSL, captive portal, Quantenna, Broadcom runner). None is an nvram key on this unit, so the filter below prints nothing; a name that starts to print has become a stored key, and `grep -l '<name>' /www/*.asp` finds the page that writes it.

Keys: `nvram show 2>/dev/null | cut -d= -f1 | grep -xE 'ATEMODE|_(addr|aips|alive|dns|ep_addr|ep_port|errno|mtu|nat|ppub|priv|proto|psk|state)|_pptpd_clients_(start|end)|applybutton|attach_(cfgfile|iptables|modemlog|syslog|wlanlog)|autodet1_(auxstate|state)|autodet_plc_state|button|bw_enabled_x|bw_setting_name|captcha_text|captive_portal(_enable|_adv_enable|_adv_profile)?|casignedcert|changePermissionBtn|check_beta|chilli_(lease|net)|clientList|client_name|cnonce|cp_(lease|net)|d3g|detect_(count|interval)|dm_http_port|dot|dotPresets|dsllog_.*|dsltmp_transmode|dslx_.*|dual_wan_flag|dummyShareway|edit_vpn_crt_server1_.*|eula_checkbox|ewan_(dot1p|vid)|fc_disable|feedbackresponse|file|file_(cert|key)|foilautofill|folder|force_chgpass|fw_upload_interrupted|g3err_pin|gen_tarball|gwlu|hndwr|[io]bw1?|id|ikev2_cert_state|import_cert_file|layer_order|letsEncryptTerm_check|mobile_upgrade_.*|mode|motion|msglength|nt_action_(email|webapp)|passwd1|password|permission1?|plc_sleep_enabled|pool|prev_page|protocol|qtn_ready|rb_(enable|enable_orig|toggle)|rbk_opt|reboot_time_x_(hour|min)|router_sync_(desc|rule)|runner_disable|sambaclient_.*|service_region|show_pass_1|support_cdma|sw_mode_radio|sync_with_[25]ghz|system_time|test_flag|type_[APV]_(audio|image|video)|update|upload|usbclient_.*|usericon_mac|version|wan|wave_ready|web_svg|wpas[01]_reason|zoom|wl[0-9]_(dns|mtu|proto)'`
