# WAN, LAN and traffic services

LAN, DHCP, routes, IPTV, switch, WAN and PPPoE, dual WAN, NAT features, UPnP, IPv6, VPN, firewall, AiProtection, parental controls, QoS and traffic statistics. Facts marked *(unit)* were read on RT-BE90U 3.0.0.6.102_58500; source facts cite asuswrt-merlin.ng at commit [b053ba7](https://github.com/RMerl/asuswrt-merlin.ng/tree/b053ba701af02e46a86d465d82cc2a7891a288a7) (generic rc and httpd code; the QCA-specific parts of the stock build are not public). `merlin:` below abbreviates `https://github.com/RMerl/asuswrt-merlin.ng/blob/b053ba701af02e46a86d465d82cc2a7891a288a7/release/src/router/`.

Each page's Apply runs the action in its hidden `action_script` field or the `rc_service` its JS posts; what each action stops and starts is [platform.md § Apply actions](platform.md#apply-actions). A select's values and labels come from the page itself: `grep -n '<key>' /www/<page>.asp`, with `<#N#>` resolved as line N+1 of `/www/EN.dict` (`sed -n "$((N+1))p" /www/EN.dict`). Values below list `value = label` from those pages *(unit)*.

Credentials live in this area's keys (`wan0_pppoe_username`/`_passwd`, `ddns_passwd_x`, `vpn_crt_*`, `wgs_priv`, `ipsec_preshared_key`, …): list key names with `nvram show 2>/dev/null | cut -d= -f1 | grep …` and read values only through a filter such as `grep -viE 'passw|psk|key|priv|secret|token|user'`.

## LAN

LAN › LAN IP (`Advanced_LAN_Content.asp`, Apply `restart_net_and_phy`) sets the router's own address on `br0`, the bridge of `eth1.1` (wired LAN) and the Wi‑Fi VAPs (`brctl show br0`; `nvram get lan_ifnames`) *(unit)*.

```
KEY                      VALUES / MEANING
-----------------------  -----------------------------------------------------------------
lan_ipaddr, lan_netmask  router address and mask (also posted as lan_ipaddr_rt / lan_netmask_rt)
lan_proto                static / dhcp; the proto, gateway and DNS rows (lan_proto_radio,
lan_dnsenable_x          lan_dnsenable_x 1 = automatic DNS, 0 = lan_dns1_x/2_x) are hidden
                         when sw_mode=1 (router mode)
lan_hostname             router hostname
lan_domain               local domain name (empty on this unit)
redirect_dname           "Redirect DNS"; row shown only with rc_support redirect_dname (absent here)
lan_stp                  STP on br0 (1; brctl shows "STP enabled yes")
lan_hwaddr, lan_ifname(s), lan_*_t, lan_unit    runtime / derived
```

A LAN address change moves the DHCP pool with it: the page recomputes and posts `dhcp_start`/`dhcp_end` when the pool falls outside the new subnet. Read: `ip -br addr show br0; brctl show`. Verify after Apply: `ip -br addr show br0` and `grep dhcp-range /etc/dnsmasq.conf`.

Keys: `nvram show 2>/dev/null | cut -d= -f1 | grep -xE 'local_domain|record_lanaddr|lld2d_hostname|lan1?_(auxstate_t|dns|dns[12]_x|dnsenable_x(_radio)?|domain|gateway|hostname|hw(addr|names)|ifnames?|ipaddr(_rt)?|lease|netmask(_rt)?|proto(_radio)?|sbstate_t|state_t|stp|trunk_type|unit|wins)|redirect_dname'`

## DHCP

LAN › DHCP Server (`Advanced_DHCP_Content.asp`, `Advanced_MultiSubnet_Content.asp`; Apply `restart_net_and_phy`). dnsmasq serves DHCP and DNS; rc writes `/etc/dnsmasq.conf` (RAM) from nvram at each start *(unit)*: `dhcp-range=lan,<dhcp_start>,<dhcp_end>,<mask>,<dhcp_lease>s`, `dhcp-option=lan,3,<router>`, `dhcp-authoritative`, `dhcp-script=/sbin/dhcpc_lease`, upstream servers from `servers-file=/tmp/resolv.dnsmasq`, `cache-size=1500`.

```
KEY                    VALUES / MEANING
---------------------  ----------------------------------------------------------------------
dhcp_enable_x          1 = DHCP server on
dhcp_start, dhcp_end   pool, inside the LAN subnet (nvram get dhcp_start; nvram get dhcp_end)
dhcp_lease             lease seconds; page accepts 120–604800; 86400 on this unit   [trade-off](tradeoffs.md#dhcp-lease-time)
dhcp_gateway_x         gateway handed out (empty = router)
dhcp_dns1_x/2_x        DNS handed out (empty = router)
dhcpd_dns_router       1 = also advertise the router as DNS
dhcp_wins_x, sip_server   WINS / SIP server options
dhcp_static_x          1 = manual assignment on
dhcp_staticlist        <MAC>IP>DNS>hostname, repeated (built by the page's applyRule)
vpnc_dev_policy_list   posted by the same page: per-client VPN Fusion policy (§ VPN Fusion)
subnet_rulelist(_ext), t* fields   Advanced_MultiSubnet_Content.asp editor
```

A reservation matches the MAC the client presents, so a client using a private Wi‑Fi address is matched by that address. Leases: `cat /var/lib/misc/dnsmasq.leases`. Verify: `grep -E 'dhcp-(range|host|option)' /etc/dnsmasq.conf`.

Keys: `nvram show 2>/dev/null | cut -d= -f1 | grep -xE 'dhcp[0-9]*_.*|dhcpd_.*|dhcpres_rl|sip_server|subnet_rulelist(_ext)?|t(DHCPStart|DHCPEnd|GatewayIP|Lan_domain|LeaseTime|SubnetMask)|radioDHCPEnable'`

## Routes

LAN › Route (`Advanced_GWStaticRoute_Content.asp`, Apply `restart_net`). `sr_enable_x` (1/0) enables `sr_rulelist`, rows of network, mask, gateway, metric and interface (`sr_if_x`: `LAN`, `MAN`, `WAN`). `dr_enable_x` (LAN › IPTV page) accepts routes pushed by the ISP's DHCP: `0` Disable, `1` Microsoft (option 249), `2` RFC3442 (option 121), `3` both; the WAN DHCP client requests both options (`udhcpc … -O33 -O249`, `ps w`) *(unit)*. `lan_route` / `wanN_route` / `wanN_mroute` hold routes rc derived. Read: `ip route; ip rule`.

Keys: `nvram show 2>/dev/null | cut -d= -f1 | grep -xE 'sr_.*|dr_enable_x|quagga_enable|rip_hostname|(lan1?|wan[0-9]*)_m?route'`

## IPTV

LAN › IPTV (`Advanced_IPTV_Content.asp`, Apply `restart_net`).

```
KEY                       VALUES / MEANING
------------------------  ---------------------------------------------------------------------
switch_wantag             ISP VLAN profile; none = untagged WAN (current), manual = switch_wan0tagid
                          (Internet VID, 2–4094) / switch_wan0prio, switch_wan1*/wan2* = the
                          IPTV (LAN port 4) / VoIP (LAN port 3) VIDs
switch_stb_x              LAN ports bridged to the IPTV/VoIP VLANs (0 = none)
iptv_port_settings        12 = LAN1/LAN2, 56 = LAN5/LAN6 (which ports switch_stb_x refers to)
wan10_*, wan11_*          separate IP settings for the IPTV (wan10) and VoIP (wan11) VLAN WANs;
                          the page edits them through the wan_*_now fields
mr_enable_x               IGMP proxy 1/0; mr_igmp_ver 1/2/3, mr_mld_ver 1/2, mr_qleave_x "Enable Fast Leave"
emf_enable                "Enable efficient multicast forwarding (IGMP Snooping)" 1/0
udpxy_enable_x            udpxy multicast→HTTP port (0 = off, else 1024–65535); udpxy_clients max
```

With the `movistar` profile httpd writes the posted IPTV and VoIP copies to `wan10_*` and `wan11_*` ([merlin: httpd/web.c](https://github.com/RMerl/asuswrt-merlin.ng/blob/b053ba701af02e46a86d465d82cc2a7891a288a7/release/src/router/httpd/web.c#L3920-L3936)). VLANs present: `cat /proc/net/vlan/config` (only `eth1.1`, the LAN, on this unit) *(unit)*. Multicast daemons: `ps w | grep -E 'igmpproxy|udpxy'`.

Keys: `nvram show 2>/dev/null | cut -d= -f1 | grep -xE 'iptv_.*|udpxy_.*|mr_.*|emf_.*|switch_(stb_x0?|wantag|upstream|wan[0-3](prio|tagid))|wan1[01]_.*|wan_[a-z0-9_]+_now|wan_pppoe_idletime_check'`

## Switch control

LAN › Switch Control (`Advanced_SwitchCtrl_Content.asp`). Apply runs `reboot` by default and `restart_net_and_phy` when only the bonding policy changed. On TUF-BE9400-based units the page shows WAN link speed and NAT acceleration type; the QCA row shows when `sw_mode=1` and `wifison_ready≠1` *(unit, page JS)*.

```
KEY                  VALUES = LABEL
-------------------  -----------------------------------------------------------------------------
qca_sfe              0 = Disable, 1 = Enable   NAT acceleration (ECM with SFE/PPE front ends)
qca_hwnat_type       0 = Auto, 2 = SFE, 3 = PPE, 5 = PPE+SFE   which ECM front end forwards flows
wan_link_speed       0 = Auto, 10/100/1000/2500 Mbit/s   forced WAN PHY speed
jumbo_frame_enable   0 = Disable, 1 = Enable
lacp_enabled         0/1 link aggregation; bonding_policy 0 Default, 1 Source, 2 Destination
ctf_*, hwnat, aqr_*, sfpp_*, gro_disable_force   rows for other platforms (CTF, MediaTek HW NAT,
                     AQR / SFP+ ports)
```

The banner under the setting reads "NAT acceleration is enabled." only when `qca_sfe=1` and the httpd's `nat_accel_status` is 1, otherwise "NAT traffic is processed by CPU." *(unit)*. ECM's live state and what turns it off: [diagnostics.md § Hardware acceleration](diagnostics.md#hardware-acceleration).

Keys: `nvram show 2>/dev/null | cut -d= -f1 | grep -xE 'jumbo_frame_enable|ctf_.*|gvlan_rulelist|et_txq_thresh|lfp_disable|eth_priority|lb_skip_port|hwnat|qca_(sfe|hwnat_type)|aqr_.*|sfpp_.*|gro_disable_force|lacp_.*|bonding_policy|wan_link_speed|lanports_mask|vlan_(enable|pvid_list|rulelist|trunk_iso_rl|trunk_rl|trunklist)'`

## WAN

WAN › Internet Connection (`Advanced_WAN_Content.asp`, Apply `restart_wan_if <unit>`, with `;restart_stubby` when DoT settings change, `;restart_dnsmasq` when DNSSEC/rebind settings change, `;restart_net` for some IPv6/softwire changes).

**The `wan_` working copy.** The page edits unprefixed `wan_*` keys; httpd writes each posted `wan_<name>` to `wan<wan_unit>_<name>` ([merlin: httpd/web.c](https://github.com/RMerl/asuswrt-merlin.ng/blob/b053ba701af02e46a86d465d82cc2a7891a288a7/release/src/router/httpd/web.c#L3938-L3950)). rc reads `wan0_*`; `wan_*` keeps whatever was last saved through it and can disagree (on this unit `wan0_proto=pppoe` while `wan_proto=dhcp`) *(unit)*. Read and write `wan0_*`.

```
KEY                       VALUES / MEANING
------------------------  ----------------------------------------------------------------------
wan0_proto                dhcp = Automatic IP, static = Static IP, pppoe, pptp, l2tp,
                          lw4o6, map-e, v6plus, ocnvc = OCN Virtual Connect, dslite, v6opt
wan0_enable, wan0_nat_x   WAN on / NAT on (1/0)
wan0_dhcpenable_x         1 = get the WAN-side IP automatically (under PPPoE: the physical
                          eth0 runs udhcpc and holds a 169.254.x link-local address here)
wan0_dnsenable_x          1 = use the DNS the ISP/PPP hands out (wan0_dns), 0 = wan0_dns1_x/2_x
wan0_pppoe_mtu / _mru     1492 default (PPPoE ceiling on a 1500 link)   [trade-off](tradeoffs.md#pppoe-mtu)
wan0_pppoe_idletime       0 = always on
wan0_pppoe_auth           "" Auto, pap, chap
wan0_pppoe_service/_ac/_hostuniq/_options_x   optional PPPoE service name, AC, extra pppd options
wan0_ppp_echo             0 Disable, 1 PPP Echo (LCP), 2 DNS Probe; _interval 6 s, _failure 10
wan0_dhcp_qry             DHCP query frequency: 0 Normal, 1 Aggressive, 2 Continuous
wan0_hwaddr_x             cloned MAC (empty = own)
wan0_vpndhcp              "Enable VPN + DHCP Connection" 1/0
wan_dot1q, wan_vid        802.1Q tag on the WAN port
nat_type                  0 Symmetric, 1 Fullcone (row shown only on bcm_kf_netfilter+fullcone)
ttl_inc_enable, ttl_spoof_enable   TTL handling on WAN (1/0)
dnspriv_enable            0 None, 1 DNS-over-TLS; servers in dnspriv_rulelist; dnspriv_profile
                          1 Strict / 0 Opportunistic                [trade-off](tradeoffs.md#wan-dns)
dns_priv_override         0 Auto, 1 Yes, 2 No
dnssec_enable             DNSSEC validation in dnsmasq; dnssec_check_unsigned_x
dns_norebind              "Enable DNS Rebind protection" 1/0
dns_fwd_local             "Forward local domain queries to upstream DNS" 1/0
dns_probe*, dns_ping_*    Internet-detection probe settings (dns_probe_host = dns.msftncsi.com)
nat_redirect_enable       1 = while the WAN is down rc loads /tmp/redirect_rules, which DNATs LAN
                          HTTP to <router>:18017 and DNS to <router>:18018 (stop_nat_rules,
                          merlin: rc/services.c L23622-L23640)
wan0_ipaddr/_gateway/_dns/_uptime/_state_t/_realip_*   runtime (written by rc)
```

PPPoE runs as `pppd file /tmp/ppp/options.wan0` on `ppp0`; the options file carries `plugin rp-pppoe.so nic-eth0`, `mtu/mru 1492`, `persist`, `holdoff 10`, `maxfail 0`, `lcp-echo-interval 6`, `lcp-echo-failure 10`, `lcp-echo-adaptive` and the login *(unit)*; read it with `grep -viE 'user|pass|name|secret' /tmp/ppp/options.wan0`. RFC 4638 defines the PPP-Max-Payload tag that both ends must signal before an MRU above 1492 is negotiated ([RFC 4638](https://www.rfc-editor.org/rfc/rfc4638)). DoT runs `/usr/sbin/stubby -C /etc/stubby/stubby-0.yml` (rc writes it from `dnspriv_rulelist`, rows `<server>port>hostname>spkipin`, with `tls_authentication: GETDNS_AUTHENTICATION_REQUIRED` under the Strict profile) and `/tmp/resolv.dnsmasq` then reads `server=127.0.1.1`, stubby's listener; DoT uses TCP 853 by default ([RFC 7858](https://www.rfc-editor.org/rfc/rfc7858)). Verify the encrypted path with `netstat -tn | grep :853` and a lookup through the router (`nslookup example.com 127.0.0.1`). A name the upstream blocks with `0.0.0.0` answers `REFUSED` to LAN clients (`dig @<router> <name>` on the Mac) while `nslookup` on the router shows `0.0.0.0`; both mean blocked, and what rewrites the code is not established *(unit)*.

Read: `ip -br addr show ppp0; ip route; cat /tmp/resolv.dnsmasq; ps w | grep -E 'pppd|udhcpc|wanduck|stubby'`. Verify: `ifconfig ppp0` (MTU), `nvram get wan0_state_t` (2 = connected *(unit)*), `grep -iE 'pppd|WAN\(0\)' /jffs/syslog.log | tail`.

Keys: `nvram show 2>/dev/null | cut -d= -f1 | grep -xE 'autodet_(state|auxstate|proceeding)|isp_user_ctrl_ts|web_redirect|dot_rl|old_resolve|wan[0-9]?_(auth_x|auxstate_t|clientid(_type)?|desc|dhcp_qry|dhcpenable_x|dhcpfilter_enable|dns|dns_r|dns[12]_x|dnsenable_x|dot1q|enable|force_link|gateway(_x)?|gw_ifname|gw_mac|heartbeat_x|hostname|hwaddr(_x)?|hwname|ifnames?|ipaddr(_x)?|is_usb_modem_ready|mtu|nat_x|netmask(_x)?|PADI_num|phy_uptime|phytype|ppp_conn|ppp_echo(_failure|_interval)?|pppoe_(ac|auth|demand|hostuniq|idletime|ifname|mru|mtu|options_x|passwd|relay|service|username)|pptp_options_x|primary|proto(_t)?|realip_(ip|state)|s46_.*|sbstate_t|state_t|unit|uptime|vendorid|vid|vpndhcp|wins|x(dns|gateway|ipaddr|netmask))|dns_(delay_round|fwd_local|norebind|ping_.*|priv_override|probe.*)|dnspriv_.*|dnssec_.*|dhcpc_mode|nat_(redirect_enable|state|type)|ttl_(inc|spoof)_enable|autowan_enable|wanports_(bond|mask)|bond_wan(_radio)?|wanduck_.*|wan46det_proceeding|ewan_dot1q|DNS_service_opt|tmp_dhcp_clientid_type'`

## Dual WAN

WAN › Dual WAN (`Advanced_WANPort_Content.asp`, Apply `reboot`). `wans_dualwan` lists primary and secondary (`wan none` = single WAN *(unit)*); `wans_cap` lists what this unit offers (`wan usb lan`). `wans_mode`: `fo` Fail Over, `fb` Fail Over with Fail Back ticked (`wandog_fb_count` checks before returning), `lb` Load Balance (`wans_lb_ratio`); `wans_standby` keeps the secondary up; `wans_lanport` picks the LAN port used as WAN; `wans_usb_bk` USB backup; `wans_routing_enable` + `wans_routing_rulelist` route by source/destination. Network monitoring: `wandog_enable`, `wandog_target`, `wandog_interval`, `wandog_maxfail`, `wandog_delay`, `wandog_fb_count`.

Keys: `nvram show 2>/dev/null | cut -d= -f1 | grep -xE 'wans_([^n].*|n[^t].*)|wandog_.*|link_wan1?|wan[0-9]_isp_(country|list)|wan[0-9]?_routing_isp(_enable)?'`

## Port forwarding, port trigger and DMZ

All three are DNAT rules rc writes into the `nat` table and apply with `restart_firewall` (WAN › Virtual Server, Port Trigger, DMZ; Open NAT = `GameProfile.asp`, writing `game_vts_rulelist` into the `GAME_VSERVER` chain) *(unit)*.

```
KEY                   VALUES / MEANING
--------------------  -----------------------------------------------------------------------
vts_enable_x          port forwarding 1/0
vts_rulelist          <name>extPort>intIP>intPort>proto>srcIP, repeated; proto TCP, UDP, BOTH,
                      OTHER; at most 64 rules (page profileMaxNum); vts1_rulelist = 2nd WAN
vts_ftpport           external port of the FTP-server preset
autofw_enable_x       port trigger 1/0; rules in autofw_rulelist
dmz_ip                DMZ host (empty = off): a catch-all "-A VSERVER … -j DNAT --to <ip>"
```

The rules land in `VSERVER` (and `GAME_VSERVER`), hooked from `PREROUTING -d <WAN IP>` on every interface, and `POSTROUTING -o br0 -s <LAN> -d <LAN> -j MASQUERADE` is present, so LAN hosts reach forwarded ports by the public address too *(unit)*; the DMZ line is appended last ([merlin: rc/firewall.c](https://github.com/RMerl/asuswrt-merlin.ng/blob/b053ba701af02e46a86d465d82cc2a7891a288a7/release/src/router/rc/firewall.c#L2094-L2111)). Verify: `iptables -t nat -S VSERVER`; reachability is tested from outside while a program listens on the target port.

Keys: `nvram show 2>/dev/null | cut -d= -f1 | grep -xE 'vts.*|autofw_.*|dmz1?_(enable|ip)|game_vts_rulelist|sp_battle_ips|(Trigger|LW)?KnownApps|KnownGames'`

## DDNS

WAN › DDNS (`Advanced_ASUSDDNS_Content.asp`, Apply `restart_ddns`; with Let's Encrypt `restart_ddns_le;prepare_cert`). `ddns_enable_x` 1/0; `ddns_server_x` provider (`WWW.ASUS.COM` = ASUS's `asuscomm.com` names, `WWW.DYNDNS.ORG`, `DOMAINS.GOOGLE.COM`, …); `ddns_hostname_x`; `ddns_username_x`/`ddns_passwd_x` for third-party providers; `ddns_wildcard_x`; `ddns_regular_check` + `ddns_regular_period` periodic re-registration; `ddns_ipv6_update`; `ddns_wan_unit` −1 Auto / 0 / 1; `le_enable` 1 "Free Certificate from Let's Encrypt", 2 "Import Your Own Certificate", 0 "Auto". State: `ddns_status`, `ddns_return_code`, `ddns_ipaddr`, `le_state`. Under PPPoE the registered address is `wan0_ipaddr`; `wan0_realip_ip` / `wan0_realip_state` record the public address seen from outside (2 = checked) *(unit)*.

Keys: `nvram show 2>/dev/null | cut -d= -f1 | grep -xE 'ddns_.*|le_.*|last_cert_wan[0-9]_ipaddr|asusddns_.*|DDNSName|DDNSStatus|LANHostConfig_x_DDNSStatus_button'`

## NAT passthrough

WAN › NAT Passthrough (`Advanced_NATPassThrough_Content.asp`, Apply `restart_firewall;restart_pppoe_relay`; `restart_net_and_phy` when SIP goes from off to on). Each item lets that protocol cross the NAT through a conntrack/NAT helper module or a firewall rule.

```
KEY               VALUES = LABEL                 ON THIS UNIT
----------------  -----------------------------  -------------------------------------------------
fw_pt_pptp        0 Disable, 1 Enable            nf_conntrack_pptp / nf_nat_pptp loaded
fw_pt_l2tp        0/1                            —
fw_pt_ipsec       0/1                            —
fw_pt_rtsp        0/1                            no rtsp module exists in /lib/modules
fw_pt_h323        0/1                            nf_conntrack_h323 / nf_nat_h323 loaded
fw_pt_sip         0/1  (SIP ALG)                 nf_conntrack_sip / nf_nat_sip loaded   [trade-off](tradeoffs.md#sip-alg)
fw_pt_sip_mode    0 Original, 1 Cisco
fw_pt_pppoerelay  0/1 PPPoE relay (LAN PPPoE clients to the ISP); pppoerelay_unit 0 primary / 1 secondary
```

Values default to 1 except PPPoE relay *(unit)*. Verify: `lsmod | grep -E 'nf_(conntrack|nat)_'`; `find /lib/modules -name 'nf_*'` lists what the kernel can load *(unit)*.

Keys: `nvram show 2>/dev/null | cut -d= -f1 | grep -xE 'fw_pt_.*|pppoerelay_unit'`

## UPnP

`wan0_upnp_enable` (WAN page "Enable UPnP", 1/0) is the switch rc reads per WAN; `start_upnp` writes `/etc/upnp/config` and starts `miniupnpd`, with `upnp_secure` mapping to `secure_mode` (a client may map ports only to itself), `upnp_mnp` enabling NAT-PMP/PCP, and `upnp_min_port_ext`/`upnp_max_port_ext` bounding external ports ([merlin: rc/services.c start_upnp](https://github.com/RMerl/asuswrt-merlin.ng/blob/b053ba701af02e46a86d465d82cc2a7891a288a7/release/src/router/rc/services.c#L7590-L7745)). `upnp_clean*` expire idle mappings. The firewall hooks the mapping chains in (`-A VSERVER -j VUPNP`) only when the unprefixed `upnp_enable` is 1 ([merlin: rc/firewall.c nat_setting](https://github.com/RMerl/asuswrt-merlin.ng/blob/b053ba701af02e46a86d465d82cc2a7891a288a7/release/src/router/rc/firewall.c), gate `is_nat_enabled() && nvram_get_int("upnp_enable")`); with `wan0_upnp_enable=1` alone `miniupnpd` runs and writes mappings into `VUPNP`, but nothing reaches that chain and an external port test reads closed. Which rc step copies the per-WAN key into `upnp_enable` on the page's `restart_wan_if` path is not established, so over SSH write both keys and apply with `restart_firewall` (drops nothing; it flushes `VUPNP`/`FUPNP`, and the client re-requests its mapping within its renewal interval or on restart) *(unit)*. [trade-off](tradeoffs.md#upnp). Mappings when on: the `VUPNP` nat chain (`iptables -t nat -S VUPNP`) and its `FUPNP` accept twin; DNAT-ed flows pass `FORWARD` through `-m conntrack --ctstate DNAT -j ACCEPT`.

Keys: `nvram show 2>/dev/null | cut -d= -f1 | grep -xE 'upnp_.*|(wan|dsl)[0-9]*_upnp_enable'`

## IPv6

IPv6 (`Advanced_IPv6_Content.asp`; `Advanced_IPv61_Content.asp` for the second WAN with `ipv61_*` keys; Apply `restart_net`).

```
KEY                   VALUES / MEANING
--------------------  ---------------------------------------------------------------------
ipv6_service          disabled, dhcp6 = Native, other = Static IPv6, ipv6pt = Passthrough,
                      flets, 6to4, 6in4, 6rd                  [trade-off](tradeoffs.md#ipv6)
ipv6_ifdev            ppp = run IPv6 over the PPPoE session, eth = over the Ethernet WAN
ipv6_dhcp_pd          1 = request a delegated prefix (DHCPv6-PD); ipv6_prefix_length when static
ipv6_autoconf_type    0 Stateless (SLAAC), 1 Stateful (DHCPv6 pool ipv6_dhcp_start/_end)
ipv6_dnsenable        1 = DNS from the ISP, else ipv6_dns1–3
ipv6_radvd            1 = send router advertisements on LAN
ipv6_6rd_*, ipv6_tun_*, ipv6_s46_*   tunnel and softwire (MAP-E/v6plus/DS-Lite) parameters
ipv6_prefix, ipv6_rtr_addr, ipv6_*_t  runtime, keep their last value after IPv6 is off
```

Live state: `cat /proc/sys/net/ipv6/conf/all/disable_ipv6` (1 = off) and `ip -6 addr show scope global` *(unit)*. With `ipv6_service=dhcp6` over `ipv6_ifdev=ppp`, `ipv6-up` starts `dhcp6c`, which logs `bound prefix <prefix>/56` to the syslog and restarts dnsmasq; `br0` then carries `<prefix>::1/56`, `ppp0` a global address, and dnsmasq advertises the router's own address as the clients' resolver (`enable-ra`, `ra-param=br0`, `dhcp-range=lan,::,constructor:br0,ra-stateless` in `/etc/dnsmasq.conf`), so IPv6 lookups still pass through stubby and the WAN DNS choice; with DoT on, `/tmp/resolv.dnsmasq` kept `server=127.0.1.1` and stubby's upstream list stayed the DoT servers, so `ipv6_dns1..3` were not consulted (where they land with DoT off is not established). `ip6tables -S FORWARD` ends in `DROP` and `INPUT` accepts only `br0`, established flows, DHCPv6 replies and ICMPv6 with `ipv6_fw_enable=1` *(read on RT-BE90U 3.0.0.6.102_58500, ISP prefix delegated within 15 s of the PPP session)*. The IPv6 firewall keys belong to § Firewall.

Keys: `nvram show 2>/dev/null | cut -d= -f1 | grep -xE '_?ipv61?_([^f].*|f[^w].*)|wan[0-9]?_6rd_.*|wan_selection'`

## VPN server

VPN › VPN Server (`Advanced_VPNServer_Content.asp` loads `/VPN/vpns.html` with `vpns_{openvpn,wireguard,ipsec,pptp}.js`; the standalone `Advanced_VPN_*.asp` / `Advanced_Wireguard*.asp` pages edit the same keys). Actions: OpenVPN `restart_openvpnd` / `stop_openvpnd`, WireGuard `restart_wgs` (`restart_wgsc <n>` per client), IPsec `ipsec_start` / `ipsec_stop`, PPTP `restart_vpnd` / `stop_vpnd` *(unit)*.

```
SERVER        ENABLE KEY                         MAIN KEYS
------------  ---------------------------------  ----------------------------------------------------
OpenVPN       VPNServer_enable, vpn_server_unit  vpn_server_{proto,port,if,crypt,cipher,digest,
              (state vpn_server1_state)          comp,sn,nm,dhcp,r1,r2,plan,client_access,pdns,ip6}
                                                 certs vpn_crt_server*; per-client routes vpn_clientlist_*
WireGuard     wgs_enable                         wgs_{addr,port,dns,alive,lanaccess,nat6}; peers wgsc_*
IPsec         ipsec_server_enable                ipsec_profile_1..5, ipsec_preshared_key, ipsec_clients_start,
                                                 ipsec_dns1/2; Instant Guard = ipsec_ig_enable + ig_*
PPTP          pptpd_enable                       pptpd_{clients,mppe,dns1,dns2,mtu,mru,clientlist}
```

Firewall hooks: `OVPNSI`/`OVPNSF`, `WGSI`/`WGSF`, `IPSEC_STRONGSWAN` chains in `iptables -S` *(unit)*. All servers are off on this unit. Running: `ps w | grep -E 'openvpn|charon|pptpd'; wg show 2>/dev/null`.

Keys: `nvram show 2>/dev/null | cut -d= -f1 | grep -xE 'vpn_server.*|vpn_crt_server.*|vpn_clientlist.*|vpns_rl|VPNServer_.*|vpn_(debug|loglevel)|pptpd_.*|ipsec_(profile_[0-9].*|profile_item|preshared_key|[^p].*)|wgs.*|ig_.*'`

## VPN Fusion

VPN › VPN Fusion (`Advanced_VPNClient_Content.asp` → `/VPN/vpnc.html`; actions `restart_vpnc`, `restart_vpncall`, `restart_vpnc_dev_policy`, `restart_default_wan`, `stop_vpnc` *(unit)*). Profiles of any client type (OpenVPN `vpn_client*`, WireGuard `wgc*`, PPTP/L2TP `vpnc*`, IPsec `ipsec_profile_client_*`, provider presets `tpvpn_*`, `surfshark_*`, `nordvpn_*`) are listed in `vpnc_clientlist` (`vpnc_max_conn` = 2 on this unit). `vpnc_default_wan` is the profile index whose tunnel becomes the default route for the LAN (0 = WAN); `vpnc_dev_policy_list` holds per-device policies `activate>ip>dest_ip>vpnc_idx>brifname` (written by the DHCP page too). rc builds one routing table per profile and `ip rule` entries per policy ([merlin: rc/vpnc_fusion.c](https://github.com/RMerl/asuswrt-merlin.ng/blob/b053ba701af02e46a86d465d82cc2a7891a288a7/release/src/router/rc/vpnc_fusion.c#L196-L252)). No profile exists on this unit (`vpnc_clientlist` empty, `vpnc_proto=disable`) *(unit)*. Verify: `ip rule; ip route show table all | grep -v '^local'`; chains `VPNCF`/`VPNCI`, `WGCF`/`WGCI`, `OVPNCF`/`OVPNCI`, nat `VPN_FUSION`.

Keys: `nvram show 2>/dev/null | cut -d= -f1 | grep -xE 'vpnc.*|VPNClient_.*|vpn_client(([0-9]|_|x_).*)?|vpn_crt_client_.*|vpn_upload_.*|wgc.*|tpvpn_.*|surfshark_.*|nordvpn_.*|ipsec_profile_client_.*'`

## Firewall

Firewall pages (`Advanced_BasicFirewall_Content.asp`, `Advanced_URLFilter_Content.asp`, `Advanced_KeywordFilter_Content.asp`, `Advanced_Firewall_Content.asp`), all Apply `restart_firewall`. rc builds `iptables` from nvram on every firewall restart; the default `INPUT` policy ends in `-j DROP` for anything not from `br0`/`lo` or established *(unit)*.

```
KEY                VALUES = LABEL / MECHANISM
-----------------  -------------------------------------------------------------------------
fw_enable_x        firewall 1/0
fw_dos_x           DoS protection: SYN/RST/ping rate limit 1/s (SECURITY chain, hooked only when 1)
misc_ping_x        respond to WAN ping; 0 = INPUT_PING drops ICMP on ppp0/eth0
fw_log_x           none, drop = Dropped, accept = Accepted, both (logdrop/logaccept chains)
fw_wl_enable_x     "Enable IPv4 inbound firewall rules" 1/0; rows (ipv4_fw_* fields) in filter_wllist
ipv6_fw_enable     "Enable IPv6 Firewall" 1/0; ipv6_fw_rulelist rows: name, remote IP, local IP,
                   port, protocol (ipv6_fw_*_x_0 fields)
url_enable_x       URL filter 1/0; url_mode_x 0 Deny List, 1 Allow List; url_rulelist (URLFF/URLFI)
keyword_enable_x   keyword filter 1/0; keyword_rulelist
fw_lw_enable_x     Network Services Filter 1/0; filter_lw_default_x DROP = Allow List,
                   ACCEPT = Deny List; filter_lwlist rows of source IP, source port,
                   destination IP, destination port, protocol (filter_lw_*_x_0 fields);
                   active days filter_lw_date_x (Sun..Sat bitmap), times filter_lw_time(2)_x
```

Source: URL and keyword filters return early unless enabled, DoS rules are written only when both `fw_enable_x` and `fw_dos_x` are 1 ([merlin: rc/firewall.c](https://github.com/RMerl/asuswrt-merlin.ng/blob/b053ba701af02e46a86d465d82cc2a7891a288a7/release/src/router/rc/firewall.c#L5753-L5766)). Verify: `iptables -S INPUT; iptables -S FORWARD; iptables -S <chain>`; `ip6tables -S` for IPv6.

Keys: `nvram show 2>/dev/null | cut -d= -f1 | grep -xE 'fw_(enable_x|dos_x|log_x|lw_enable_x|wl_enable_x)|filter_.*|url_.*|urlf_.*|keyword_.*|nwf_.*|misc_ping_x|ipv[46]_fw_.*'`

## AiProtection

AiProtection pages (Network Protection, Malicious Sites Blocking, Two-Way IPS, Infected Device Prevention; Apply `restart_wrs;restart_firewall`). The engine is Trend Micro's DPI (`bwdpi`); accepting its EULA in a page's `eula_confirm` sets `TM_EULA=1` (and on Network Protection also `wrs_protect_enable=1`) *(unit, page JS)* [trade-off](tradeoffs.md#aiprotection).

```
KEY                     MEANING
----------------------  ----------------------------------------------------------------
wrs_protect_enable      AiProtection on (0 on this unit); the three features below act
                        only while it is 1 (Network Protection page JS)
wrs_mals_enable         Malicious Sites Blocking; wrs_mals_t
wrs_vp_enable           Two-Way IPS; wrs_vp_t
wrs_cc_enable           Infected Device Prevention and Blocking; wrs_cc_t
wrs_mail_bit            hidden field the AiProtection pages post (7 on this unit)
bwdpi_sig_ver, bwdpi_rsa_check, bwdpi_alive   engine signature / status keys
```

The Network Protection page's router security scan reads other areas' keys (WAN ping, DMZ, port forwarding, UPnP, web access from WAN, WPS) and links to their pages. Running: `ps w | grep -E 'wrs|dpi|bwdpi'`; signature: `nvram get bwdpi_sig_ver`. Whether enabling the engine stops ECM acceleration on this platform is not established; check `cat /sys/kernel/debug/ecm/front_end_ipv4_stop` before and after *(unverified)*.

Keys: `nvram show 2>/dev/null | cut -d= -f1 | grep -xE 'wrs_(protect_enable|mals_enable|mals_t|vp_enable|vp_t|cc_enable|cc_t|mail_bit)|bwdpi_(alive|rsa_check|sig_ver)|TM_EULA'`

## Parental controls

Parental Controls › Web & Apps Filters (`AiProtection_WebProtector.asp`, DPI-based, Apply `restart_wrs;restart_firewall`): `wrs_enable` 1/0, client rules in `wrs_rulelist`, `wrs_app_enable`/`wrs_app_rulelist`. Time Scheduling (`ParentalControl.asp`, firewall-based, Apply `restart_firewall`, chain `PControls` *(unit)*): `MULTIFILTER_ALL` page switch 1/0, `MULTIFILTER_BLOCK_ALL` block-all switch; per-client `>`-separated parallel lists `MULTIFILTER_ENABLE` (0 Disable, 1 Time, 2 Block), `MULTIFILTER_MAC`, `MULTIFILTER_DEVICENAME`, `MULTIFILTER_MACFILTER_DAYTIME_V2` (schedule). AdGuard (`adGuard_DNS.asp`, Apply `restart_wan_if 0;restart_stubby`) posts `dnspriv_enable` / `dnspriv_rulelist` (§ WAN). DNS filter keys `dnsfilter_*` (`dnsfilter_enable_x=0`; its page `DNSFilter.asp` is absent on this unit) hook LAN port-53 traffic into the nat `DNSFILTER` chain ([merlin: rc/dnsfilter.c](https://github.com/RMerl/asuswrt-merlin.ng/blob/b053ba701af02e46a86d465d82cc2a7891a288a7/release/src/router/rc/dnsfilter.c#L183-L184)).

Keys: `nvram show 2>/dev/null | cut -d= -f1 | grep -xE 'MULTIFILTER_.*|OPTUS_MULTIFILTER_.*|PC_.*|wrs_(enable|enable_ori|rulelist|app_enable|app_rulelist)|dnsfilter_.*|yadns_.*'`

## Adaptive QoS

Adaptive QoS › QoS (`QoS_EZQoS.asp`) plus the Traditional QoS rule pages (`Advanced_QOSUserRules_Content.asp`, `Advanced_QOSUserPrio_Content.asp`).

```
KEY                VALUES / MEANING
-----------------  ---------------------------------------------------------------------------
qos_enable         QoS on 1/0
qos_type           1 Adaptive QoS (DPI app categories), 0 Traditional QoS (port/size rules into
                   5 classes), 2 Bandwidth Limiter (per-client caps), 3 GeForce NOW (nvgfn)
qos_obw, qos_ibw   upload / download line rate in kbit/s (Traditional, GeForce NOW, Adaptive manual);
                   _1 suffix = second WAN
bwdpi_app_rulelist Adaptive priority order of category groups; the page presets end in
                   game / media / web / eLearning / videoConference
qos_rulelist       Traditional rules <name>>addr>port>proto>size>class
qos_orates, qos_irates   per-class min-max % of the line rate
qos_ack/syn/fin/rst/icmp prioritise those packets (on/off); qos_default = default class
qos_bw_rulelist    Bandwidth Limiter rules
```

Apply (page `determineActionScript`, this unit has no `router_boost`): `restart_qos;restart_firewall` when QoS is turned off, its type is unchanged, or Adaptive is turned on; `reboot` when Traditional or Bandwidth Limiter is turned on; Adaptive also requires `TM_EULA` *(unit)*. Shaping uses `tc` on the WAN device: `tc qdisc show dev ppp0` (`noqueue` with QoS off *(unit)*). [trade-off](tradeoffs.md#qos) QoS against NAT acceleration: whether each type stops ECM on this platform is not established; compare `cat /sys/kernel/debug/ecm/front_end_ipv4_stop` and the Switch Control banner before and after *(unverified)*. The Internet Speed tab runs Ookla (`ookla_state`, `ookla_start_time`).

Keys: `nvram show 2>/dev/null | cut -d= -f1 | grep -xE 'qos_.*|bwdpi_app_rulelist(_edit)?|ookla_.*|nvgfn_enable|ispctrl_desc|eth_monitor_threshold|(upload|download)_bw_(min|max)_[0-9]'`

## Traffic analyzer and Game

Traffic Analyzer › Statistic (`TrafficAnalyzer_Statistic.asp`): `bwdpi_db_enable` 1/0 records per-client/app traffic into a database (needs `TM_EULA`); `dns_dpi_trf_analysis` is the DNS-based variant. Web History (`AdaptiveQoS_WebHistory.asp`): `bwdpi_wh_enable`. Traffic Monitor (`Main_TrafficMonitor_*.asp`) reads the `rstats` daemon's counters: `rstats_enable`; `rstats_path` save location (a trailing `/` appends `tomato_rstats_<MAC>.gz`); `rstats_stime` save interval in hours (1–8760); `rstats_offset` day of month the monthly total starts (1–31) ([merlin: rstats/rstats.c](https://github.com/RMerl/asuswrt-merlin.ng/blob/b053ba701af02e46a86d465d82cc2a7891a288a7/release/src/router/rstats/rstats.c#L294-L302)). Game Boost (`GameBoost.asp`): turning on game device prioritization sets `qos_enable=1`, `qos_type=1` (Adaptive QoS) and posts the chosen devices in `bwdpi_game_list`, Apply `restart_qos;restart_firewall` *(unit, page JS)*; `gearup_*` is the GearUP booster; `rog_*` the gaming-device list. Running: `ps w | grep -E 'rstats|bwdpi|dpi'`.

Keys: `nvram show 2>/dev/null | cut -d= -f1 | grep -xE 'rstats_.*|cstats_.*|data_usage.*|ex_db_backup_.*|bwdpi_(db_enable|wh_enable|wh_stamp|game_list|stream_list|wfh_list)|apps_analysis|dns_dpi_.*|gearup_.*|rog_.*|outfox_code'`
