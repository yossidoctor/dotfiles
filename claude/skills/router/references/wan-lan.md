# WAN, LAN and services

Internet connection, DNS, IPv6, UPnP, QoS, LAN/DHCP, firewall and port forwarding. Keys and file paths *(read on RT-AX53U 3.0.0.4.386_69196)*; the Apply action for each page is in [platform.md § Apply actions](platform.md#apply-actions).

## WAN

```
KEY                       VALUES / MEANING
-----------------------   --------------------------------------------------------------------
wan0_proto                dhcp (Automatic IP), static, pppoe, pptp, l2tp, lw4o6, map-e,
                          v6plus, ocnvc
wan0_enable, wan0_nat_x   1/0
wan0_pppoe_mtu / _mru     PPPoE MTU/MRU (1492 is the PPPoE maximum on a 1500 link)
wan0_pppoe_idletime       0 = always on
wan0_pppoe_service, _ac   optional service name / access concentrator
wan0_ppp_echo*            LCP echo (link keep-alive) settings
switch_wantag             ISP VLAN profile; "none" = untagged WAN
wan0_ipaddr, wan0_gateway current public address and gateway (runtime)
```

The PPPoE daemon runs as `pppd file /tmp/ppp/options.wan0`; the options file holds the session parameters (`mtu`, `mru`, `lcp-echo-interval`, `persist`) and the login, so read it filtered: `grep -viE 'user|pass|name|secret' /tmp/ppp/options.wan0`. Link state: `ifconfig ppp0`; session events: `grep -iE 'pppd|WAN\(0\)' /jffs/syslog.log`.

## DNS and dnsmasq

```
KEY                           MEANING
---------------------------   ----------------------------------------------------------
wan0_dnsenable_x              1 = use the ISP's DNS, 0 = use wan0_dns1_x / wan0_dns2_x
wan0_dns1_x, wan0_dns2_x      DNS servers the router itself forwards to
dhcp_dns1_x, dhcp_dns2_x      DNS servers handed to LAN clients by DHCP (empty = router)
dhcpd_dns_router              1 = also advertise the router as DNS
dnspriv_enable                DNS-over-TLS (1/0), servers in dnspriv_rulelist
```

dnsmasq serves DNS and DHCP; its generated config is `/etc/dnsmasq.conf` (RAM, rewritten on restart), upstream servers in `/tmp/resolv.dnsmasq`, leases in `/var/lib/misc/dnsmasq.leases`. A client's DNS servers come from DHCP: `dhcp_dns*` when set, otherwise the router; clients configured with their own DNS bypass both.

## IPv6

`ipv6_service`: `disabled`, `dhcp6` (Native), `other` (Static), `ipv6pt` (Passthrough), `flets`, `6to4`, `6in4`, `6rd` ([ASUS FAQ 113990](https://www.asus.com/support/faq/113990/)). Native over a PPPoE WAN runs IPv6 on the PPP link when `ipv6_ifdev=ppp` and requests a delegated prefix when `ipv6_dhcp_pd=1` (`ipv6_prefix_length`, e.g. 56). LAN side: `ipv6_radvd` (router advertisements), `ipv6_autoconf_type` (0 = SLAAC), `ipv6_dnsenable`, `ipv6_fw_enable` (IPv6 firewall). Runtime values (`ipv6_prefix`, `ipv6_rtr_addr`) keep their last value after IPv6 is turned off.

The kernel switch `/proc/sys/net/ipv6/conf/all/disable_ipv6` (1 = IPv6 off) is set from `ipv6_service`; `cat /proc/sys/net/ipv6/conf/{all,ppp0,br0}/disable_ipv6` and `ip -6 addr show scope global` show the live state. The IPv6 page applies with `restart_net`.

**Testing IPv6 end to end** (from a client): a global address (`ifconfig en0 | grep inet6 | grep -v fe80`), a small fetch (`curl -6 -s https://api64.ipify.org` prints an address with colons), and full-size packets: `ping6 -c 3 -s 1400 2001:4860:4860::8888` plus a bulk transfer over each family, `curl -4` and `curl -6` of `https://speed.cloudflare.com/__down?bytes=50000000` with `-o /dev/null -w '%{speed_download}'`. A path that passes small replies and drops full-size packets passes the first two and fails the last two. Clients that implement Happy Eyeballs try IPv6 first when both families are available ([RFC 8305](https://www.rfc-editor.org/rfc/rfc8305)).

## UPnP and NAT-PMP

`wan0_upnp_enable` / `wan_upnp_enable` (1/0) is the live switch; the unprefixed `upnp_enable` is unused. Related: `upnp_secure` (1 = a client may map ports only to itself), `upnp_min_port_ext` / `upnp_max_port_ext`, `upnp_mnp` (NAT-PMP). The daemon is miniupnpd 2.2.0 with NAT-PMP/PCP, config `/etc/upnp/config`, leases `/tmp/upnp.leases` ([rc/services.c start_upnp](https://github.com/RMerl/asuswrt-merlin.ng/blob/1f00a27b78c681abcdacc4d361e3a700c16c734a/release/src/router/rc/services.c); [ASUS FAQ 1011715](https://www.asus.com/us/support/faq/1011715/)). Running: `pidof miniupnpd`; current mappings: `cat /tmp/upnp.leases` and the `VUPNP` chain in `iptables -t nat -S`. Applied with `restart_upnp` (also run by the WAN page).

## QoS

`qos_enable` (1/0) and `qos_type`: `0` Traditional, `1` Adaptive, `2` Bandwidth Limiter, `3` GeForce NOW (`/www/QoS_EZQoS.asp` on the unit); one type at a time ([ASUS FAQ 1010935](https://www.asus.com/support/faq/1010935/)). The types a unit offers depend on `rc_support` (`adaptive_qos` for Adaptive; Traditional and Bandwidth Limiter otherwise). Bandwidths: `qos_ibw` / `qos_obw` (kbit/s). Applied on MediaTek models with `restart_qos;restart_firewall`.

```
TYPE                WHAT IT DOES                                                    SOURCE
-----------------   -------------------------------------------------------------   ------------------------------------------
Traditional         rules by port/protocol/size into priority classes with           https://www.asus.com/support/faq/1010951/
                    min/max bandwidth; shapes total traffic to the set line speed
Adaptive            priority by application category (DPI, TrendMicro EULA)          https://www.asus.com/support/faq/1010935/
Bandwidth Limiter   per-device up/down caps (up to 32 devices: FAQ 1010935);         https://www.asus.com/support/faq/1013333/
                    IPv4 only
```

**QoS and hardware NAT.** ASUS's `reinit_hwnat()` turns hardware NAT off when any QoS type is enabled (`qos_enable=1`), when `hwnat=0`, when NAT is off on the WAN, for USB WAN, and for some dual-WAN/IPTV setups; LAN › Switch Control then reads "NAT traffic is processed by CPU." (`/www/EN.dict` on the unit) (`rc/sysdeps/init-ralink.c` in the ASUS GPL mirror [stkuroneko/asuswrt-modx-next](https://github.com/stkuroneko/asuswrt-modx-next); [ASUS FAQ 1011711](https://www.asus.com/support/faq/1011711/) says enabling certain features turns NAT acceleration off; [FAQ 1013333](https://www.asus.com/support/faq/1013333/) says the Bandwidth Limiter and NAT acceleration cannot run together). The unit's UI also carries "NAT accelerator is turned off because of bandwidth limiter of Guest Network enabled." (`/www/EN.dict`). With hardware NAT off, every forwarded packet costs CPU time; [diagnostics.md § CPU](diagnostics.md#cpu-memory-connections) shows how to measure the load.

## LAN and DHCP

```
KEY                     MEANING
---------------------   --------------------------------------------------------------
lan_ipaddr, lan_netmask router address and mask
dhcp_enable_x           DHCP server 1/0
dhcp_start, dhcp_end    pool range
dhcp_lease              lease time in seconds
dhcp_staticlist         reservations: <MAC>IP>DNS>hostname, repeated (fields after IP optional)
dhcp_static_x           reservations on/off
```

A reservation matches the MAC the client presents; a client with a private (randomised) Wi‑Fi address presents that address, not its hardware MAC ([macos.md § Private Wi-Fi address](macos.md#private-wi-fi-address)). Current leases: `cat /var/lib/misc/dnsmasq.leases`.

## Firewall and port forwarding

```
KEY                     MEANING
---------------------   --------------------------------------------------------------
fw_enable_x             firewall 1/0
fw_dos_x                DoS protection 1/0
misc_ping_x             answer WAN ping 1/0
fw_log_x                none / drop / accept / both
vts_enable_x            port forwarding 1/0
vts_rulelist            <name>externalPort>internalIP>internalPort>protocol>sourceIP, repeated;
                        protocol TCP, UDP, BOTH or OTHER
```

The rules land in the NAT table's `VSERVER` chain: `iptables -t nat -S VSERVER` shows one DNAT line per protocol (two for BOTH). Whether a port is reachable from the internet is tested from outside, while a program on the target host is listening: `curl -s https://portcheck.transmissionbt.com/<port>` prints `1` (open) or `0` (closed). The packed list formats are generated by the UI's JS on WAN › Virtual Server and LAN › DHCP Server (`parseNvramToArray` / `applyRule` in those pages).
