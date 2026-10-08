# Trade-offs

Per setting whose value is contestable: what each value costs and gains, and the conditions under which another value wins. No value here is a recommendation; the choice belongs to the user. Each entry links the section that owns the setting's keys, values and commands; facts stated there are not repeated here.

## Country code

Decided by the user: the radios keep the factory country GB (`territory_code` EU/01), and no switch to IL is pursued. The GB channel and power table, and how it compares with Israel's rules, are in [regulatory.md § Israel](regulatory.md#israel).

## Wireless

### Auto channel DFS

[regulatory.md § DFS](regulatory.md#dfs) (`acs_dfs`). On: Auto may use 52–64 and 100–140, which leaves room for 160 MHz outside 36–64, at the cost of the channel-availability wait (60 s, 10 min in the weather band) during which the 5 GHz VAPs carry nothing, and a forced move when radar is heard. Off wins near radar sources (repeated radar events in the log), with clients that cannot use DFS channels, or where a minute-long 5 GHz outage on each radio start matters; on wins where 36–48 is crowded by neighbours and the wider channel matters.

### Auto channel 12, 13

[regulatory.md § Channels on this unit](regulatory.md#channels-on-this-unit) (`acs_ch13`). On: Auto may pick 2.4 GHz channels 12–13, two more places to avoid neighbours. A client applying a US-style 1–11 country does not see them ([regulatory.md § How clients choose their country](regulatory.md#how-clients-choose-their-country)). On wins when every client applies an EU/IL-style country; off wins when any client may scan 1–11 only.

### 6 GHz PSC only

[regulatory.md § 6 GHz security and power](regulatory.md#6-ghz-security-and-power) (`psc6g`). On: the 6 GHz channel stays on a Preferred Scanning Channel, where clients look for 6 GHz-only APs; off gives Auto every 6 GHz channel. Off wins when every client discovers the 6 GHz BSS through the 2.4/5 GHz SSID on the same unit (one SSID on all bands); on wins when a client joins 6 GHz without first seeing the AP on another band.

### 6 GHz 320 MHz

[wireless.md § General](wireless.md#general) (`bw`, `bw_320`). 320 MHz doubles the channel width of 160 MHz for clients that support it. Under a total EIRP cap ([regulatory.md § Other regions](regulatory.md#other-regions)) a doubled width halves the power per MHz, which shortens reach at the edge, and 5945–6425 MHz holds only two 320 MHz groups, which overlap each other ([regulatory.md § Channels on this unit](regulatory.md#channels-on-this-unit)), so a neighbour on 6 GHz shares airtime. 160 MHz or less wins with 6 GHz neighbours on the same groups, or when no client supports 320 MHz; 320 MHz wins for a close-range Wi‑Fi 7 client on a quiet band.

### WiFi 7 Mode

[wireless.md § General](wireless.md#general) (`11be`). On: the radio advertises 802.11be, the prerequisite for 320 MHz and MLO for Wi‑Fi 7 clients; turning it on from the Professional page also sets the band's authentication to WPA2/WPA3 (WPA3 on 6 GHz) (`wl_11be` handler and EN.dict line 4423 in `/www/Advanced_WAdvanced_Content.asp`). Off wins when a client joins the band only with it off; on wins otherwise.

### Channel bandwidth

[wireless.md § General](wireless.md#general) (`bw`, `bw_160`). A wider channel raises a client's peak rate and spans more 20 MHz channels, so it overlaps more neighbours and, on 5 GHz, more DFS channels ([regulatory.md § Channel numbering](regulatory.md#channel-numbering), [§ DFS](regulatory.md#dfs)). Narrower wins with dense neighbours, recurring radar events, or at long range; wider wins on a quiet band with close clients. Apple's widths are in [macos.md § Apple's router recommendations](macos.md#apples-router-recommendations).

### Authentication method

[wireless.md § General](wireless.md#general) and [§ Guest Network Pro](wireless.md#guest-network-pro) (`auth_mode_x`, the profile's `security`). WPA3-Personal (`sae`) is the stronger handshake; WPA2/WPA3 (`psk2sae`) also admits WPA2-only clients ([Apple 102766](https://support.apple.com/en-us/102766)); 6 GHz admits WPA3 only ([regulatory.md § 6 GHz security and power](regulatory.md#6-ghz-security-and-power)). `sae` wins when every client supports WPA3; `psk2sae` wins while any WPA2-only client must join.

### WPA encryption

[wireless.md § General](wireless.md#general) (`crypto`). `aes` offers CCMP; `aes+gcmp256` adds GCMP-256 and SAE-EXT-KEY in the generated hostapd config. `aes+gcmp256` wins when every client negotiates GCMP-256; `aes` wins when a client fails to associate with the extra suites offered.

### Protected Management Frames

[wireless.md § General](wireless.md#general) (`mfp`). Required protects deauthentication and disassociation frames for every client and refuses clients without PMF; Capable protects PMF clients and still admits others; 6 GHz forces Required ([regulatory.md § 6 GHz security and power](regulatory.md#6-ghz-security-and-power)). Required wins when all clients support PMF; Capable wins with older WPA2 clients.

### Agile Multiband

[wireless.md § Professional](wireless.md#professional) (`mbo_enable`). On: the AP sends MBO band and AP steering hints that MBO-aware clients act on. Off wins when a client misbehaves with the hints; on wins with MBO-aware clients and several bands or APs.

### Target Wake Time

[wireless.md § Professional](wireless.md#professional) (`twt`). On: clients negotiate scheduled wake times and sleep between them, saving battery at the cost of added latency for their traffic. On wins with battery-powered Wi‑Fi 6+ IoT devices; off wins when a client's TWT implementation drops connections or latency matters more than battery.

### OFDMA and MU-MIMO

[wireless.md § Professional](wireless.md#professional) (`ofdma`). Each step up lets the radio serve several clients in one transmission (OFDMA by sub-channel, MU-MIMO by spatial stream), which raises efficiency with many simultaneous clients. A lower step wins when a client misbehaves with uplink OFDMA or MU-MIMO; the higher steps win with many Wi‑Fi 6+ clients active at once.

### Airtime fairness

[wireless.md § Professional](wireless.md#professional) (`atf`). On: the scheduler shares airtime rather than packets, so a slow client cannot consume most of the radio's time; a single slow client's throughput falls. On wins when slow legacy or distant clients share a radio with fast ones; off wins when one client's peak throughput matters most.

### Transmit power

[wireless.md § Professional](wireless.md#professional) (`txpower`). Higher power extends reach and raises interference with neighbours, and it keeps distant clients attached instead of roaming to a nearer AP. Lower wins in a small space, in dense housing, or with mesh nodes; higher wins for a single AP covering a large space.

### Smart Connect

[wireless.md § Smart Connect](wireless.md#smart-connect) (`smart_connect_x`; on this unit the MAINFH profile is one SSID on all bands). One SSID lets `lbd` steer clients between bands and matches Apple's single-name recommendation ([Apple 102766](https://support.apple.com/en-us/102766)); separate per-band SSIDs let a device be pinned to one band. Separate SSIDs win when a device must stay on one band (an IoT device on 2.4 GHz, a test on 6 GHz); one SSID wins otherwise.

### MLO

[wireless.md § MLO](wireless.md#mlo) (`apgN_mlo`/`apmN_mlo`). Fronthaul MLO lets a Wi‑Fi 7 MLO client use several bands at once for throughput and resilience; it applies only to clients with MLO support ([Apple 148165](https://support.apple.com/en-us/148165) lists Apple's Wi‑Fi 7 devices) and needs WPA3 settings MLO accepts ([regulatory.md § 6 GHz security and power](regulatory.md#6-ghz-security-and-power)). On wins when MLO clients are present; off wins when none are, or a non-MLO client fails to join the MLO network.

### Roaming assistant

[wireless.md § Roaming](wireless.md#roaming) (`user_rssi`). On: a client whose signal stays below the threshold is disconnected so it reassociates elsewhere. With a single AP there is nowhere better, so the kick is only a disconnect. On wins with several APs or AiMesh nodes and clients that roam late (Apple's own triggers are in [macos.md § Apple's router recommendations](macos.md#apples-router-recommendations)); off wins with one AP.

### WPS

[wireless.md § WPS](wireless.md#wps) (`wps_enable`). On: devices join by push button or PIN without typing the passphrase; the PIN method is an attack surface on the network key. Off wins unless a device can join no other way.

### Ethernet backhaul mode

[wireless.md § AiMesh](wireless.md#aimesh) (`amas_eap_bhmode`). On: nodes use only wired backhaul, freeing the radios from backhaul traffic; a node whose cable fails loses its uplink. On wins when every node is cabled; off wins when any node relies on, or should fall back to, Wi‑Fi backhaul.

## WAN and LAN

### PPPoE MTU

[wan-lan.md § WAN](wan-lan.md#wan) (`wan0_pppoe_mtu`/`_mru`). 1492 fits PPPoE's 8-byte header inside a 1500-byte Ethernet frame, so nothing fragments on a standard access path. A larger MTU is possible only when the ISP supports RFC 4638 (PPP-Max-Payload over baby-jumbo frames) ([RFC 4638](https://www.rfc-editor.org/rfc/rfc4638)); it wins then, by restoring a 1500-byte path MTU.

### WAN DNS

[wan-lan.md § WAN](wan-lan.md#wan) (`wan0_dnsenable_x`, `dnspriv_enable`, `dnspriv_profile`). The ISP's resolvers are near and need no settings; manual resolvers choose the operator; DNS-over-TLS encrypts the router's upstream queries on TCP 853 ([RFC 7858](https://www.rfc-editor.org/rfc/rfc7858)). Strict DoT fails rather than send a query unauthenticated, Opportunistic falls back to cleartext ([RFC 8310 § 5](https://www.rfc-editor.org/rfc/rfc8310#section-5)). DoT wins when the on-path ISP should not see queries; the ISP resolver wins when its answers are tuned for the ISP's own services or when the extra TLS hop's latency matters.

### DHCP lease time

[wan-lan.md § DHCP](wan-lan.md#dhcp) (`dhcp_lease`). A short lease returns addresses of departed clients to the pool sooner and makes clients renew more often; a long lease keeps addresses stable across short absences. Short wins with many transient clients and a small pool; long wins with a fixed set of devices. Apple's value is in [macos.md § Apple's router recommendations](macos.md#apples-router-recommendations).

### IPv6

[wan-lan.md § IPv6](wan-lan.md#ipv6) (`ipv6_service`). Native IPv6 with a delegated prefix gives every client a global address and lets dual-stack clients prefer IPv6 ([RFC 8305](https://www.rfc-editor.org/rfc/rfc8305)); it adds a second address family to firewall and troubleshoot. On wins when the ISP offers DHCPv6-PD and a service or client needs IPv6 reachability; off wins when the ISP's IPv6 path performs worse than IPv4 (a full-size-packet test over each family shows it).

### UPnP

[wan-lan.md § UPnP](wan-lan.md#upnp) (`wan0_upnp_enable`, `upnp_secure`). On: LAN programs open inbound ports themselves (consoles, P2P, some VoIP), with `upnp_secure` limiting each client to mappings for itself; any LAN program, including malware, can open a port. Off wins when inbound needs are few and can be forwarded by hand ([wan-lan.md § Port forwarding, port trigger and DMZ](wan-lan.md#port-forwarding-port-trigger-and-dmz)); on wins with devices whose inbound ports change.

### SIP ALG

[wan-lan.md § NAT passthrough](wan-lan.md#nat-passthrough) (`fw_pt_sip`). On: the router rewrites addresses inside SIP/SDP so a SIP phone behind NAT works without its own NAT handling. Off wins when the VoIP client or provider handles NAT itself (STUN/ICE, a session border controller), since a second rewrite then breaks registration or audio; on wins for a plain SIP device with no NAT support.

### QoS

[wan-lan.md § Adaptive QoS](wan-lan.md#adaptive-qos) (`qos_enable`, `qos_type`). Shaping below the line rate keeps latency low when the uplink saturates (bufferbloat), at the cost of the headroom between the shaped rate and the line rate and of per-packet CPU work; Adaptive needs Trend Micro's DPI and its EULA. Whether a QoS type stops ECM acceleration on this platform is open; the counters in [diagnostics.md § Hardware acceleration](diagnostics.md#hardware-acceleration) settle it. QoS wins when latency under load is the problem (`networkQuality` Responsiveness low with normal idle latency, [macos.md § Latency and throughput](macos.md#latency-and-throughput)); off wins when peak throughput matters and the line is rarely saturated.

### AiProtection

[wan-lan.md § AiProtection](wan-lan.md#aiprotection) (`wrs_protect_enable`, `wrs_*_enable`). On: Trend Micro's DPI blocks known-malicious sites, scans for intrusion patterns and isolates infected clients, under its EULA with cloud lookups; it adds per-flow inspection. On wins with unmanaged or IoT clients that run no protection of their own; off wins when clients are managed and the inspection's privacy terms or CPU cost are unwanted.

## Diagnostics

### Log level and remote syslog

[diagnostics.md § Logs](diagnostics.md#logs) (`log_level`, `log_size`, `log_ipaddr`). A larger `log_size` or lower `log_level` threshold keeps a longer window at the cost of more flash writes to `/jffs`; a remote syslog server keeps every line beyond the local window and survives a reset or crash. Remote wins when the events under investigation are older than the local window or precede a crash; local-only wins when no host listens continuously.

### Conntrack timeouts

[diagnostics.md § CPU, memory, connections](diagnostics.md#cpu-memory-connections) (`ct_tcp_timeout`, `ct_udp_timeout`, `ct_timeout`). Longer timeouts keep idle NAT mappings alive for long-idle sessions and fill the table with stale entries; shorter ones free the table and drop idle sessions sooner. Shorter wins when `nf_conntrack_count` approaches `nf_conntrack_max`; longer wins when long-idle connections (SSH, push channels) drop.
