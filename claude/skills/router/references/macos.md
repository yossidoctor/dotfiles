# Measuring from a Mac

macOS commands that read the Wi‑Fi link, the neighbourhood, latency and throughput, and what their output means. Commands run as the logged-in user unless marked `sudo`. Every command here exists on macOS 27 (`command -v <cmd>`); the Wi‑Fi device is the one `networksetup -listallhardwareports` lists under "Hardware Port: Wi-Fi" (en0 on this Mac), and a Mac on Ethernet routes through another device (`route -n get default | grep interface`).

## The Wi‑Fi link

`system_profiler SPAirPortDataType` prints the card, the current network and the nearby networks. The current-network fields:

```
system_profiler SPAirPortDataType | sed -n '/Current Network Information/,/Other Local/p' \
  | grep -E 'PHY Mode|Channel|Country Code|Security|Signal|Transmit Rate|MCS'
```

```
FIELD            MEANING
--------------   ------------------------------------------------------------------------
PHY Mode         802.11 generation in use (802.11ax = Wi‑Fi 6, 802.11be = Wi‑Fi 7)
Channel          primary channel, band and width, e.g. "37 (6GHz, 160MHz)"
Country Code     regulatory country the card is applying
Signal / Noise   received signal and noise floor in dBm; the gap is the SNR
Transmit Rate    PHY rate of the Mac's transmit direction, Mbit/s (per the field name)
MCS Index        modulation and coding step behind that rate (higher = denser encoding)
```

*(read on this Mac with Wi‑Fi on; with Wi‑Fi off `system_profiler` prints `Status: Off` and omits the section.)* `Country Code` is the Mac's own choice, which can differ from the router's (IL here against the router's GB). These are instantaneous values; sampling several times a few seconds apart shows how much they move. The router's view of the same link (its rate to the Mac, the signal it receives) is in its station table ([diagnostics.md § Clients](diagnostics.md#clients)); the two directions can differ.

Card-level fields, printed with Wi‑Fi off too: `Card Type`, `Firmware Version`, `MAC Address`, `Supported PHY Modes`; with Wi‑Fi on also `Supported Channels` (the channels the card allows under its current country code) and `Country Code`. Apple documents none of these fields; units are as printed.

**Nearby networks.** The `Other Local Wi-Fi Networks` section lists each network's PHY mode, channel (band, width) and security. Channel occupancy:

```
system_profiler SPAirPortDataType | sed -n '/Other Local/,$p' | grep 'Channel:' | sed 's/^ *//' | sort | uniq -c | sort -rn
```

A neighbour occupies every 20 MHz channel its width covers ([regulatory.md § Channel numbering](regulatory.md#channel-numbering)), so overlap is judged by width groups, not by primary channel alone.

## Other link and address tools

```
COMMAND                                              OUTPUT
--------------------------------------------------   ------------------------------------------------------------
route -n get default | awk '/gateway/{print $NF}'    the router's LAN address
route -n get default | grep interface                which device carries the default route
ipconfig getifaddr <dev>                             the Mac's IPv4 address on that device
ipconfig getsummary <dev>                            DHCP lease, router, and for Wi‑Fi the security type and BSSID
ifconfig <dev>                                       the MAC in use (ether), IPv6 addresses, status
networksetup -listallhardwareports                   each port's device name and hardware MAC
scutil --dns                                         the DNS resolvers in effect
sudo wdutil info                                     detailed Wi‑Fi state; sudo wdutil diagnose writes a bundle
```

macOS prints the SSID as `<redacted>` in several of these outputs when the calling app lacks Location permission. The `airport` command-line tool is absent from current macOS (`command -v airport` prints nothing); `wdutil` and the Wireless Diagnostics app replace it ([intuitibits](https://www.intuitibits.com/2024/03/14/goodbye-airport/)).

## Latency and throughput

**ping.** `ping -c 100 -i 0.1 <router>` measures the Wi‑Fi hop; `ping -c 20 1.1.1.1` the whole path. The summary line gives min/avg/max/stddev; the spread of individual replies is counted with `ping … | awk -F'time=' '/time=/{if(($NF+0)>30)n++} END{print n+0}'`. Comparing the Mac's replies with those of another client on the same channel (`ssh router 'ping -c 30 <client IP>'`) separates the channel from the Mac itself; the Mac's firewall may drop pings sent to it.

**networkQuality.** Apple's built-in test against Apple's servers (`man networkQuality`, `networkQuality -h`; [Apple HT212313](https://support.apple.com/kb/HT212313)):

```
FLAG       MEANING
--------   ------------------------------------------------------------
-s         upload and download one after the other (default: together)
-u         no upload test (implies -s)       -d   no download test (implies -s)
-v         verbose                           -I   bind to an interface (en0, …)
-c         computer-readable (JSON) output   -M   maximum runtime in seconds
-f         protocol selection: h1, h2, h3, L4S, noL4S
```

Output: `Uplink/Downlink capacity` in Mbit/s; `Responsiveness` in RPM (round trips per minute under load) and ms; `Idle Latency`. Low responsiveness with normal idle latency means latency rises under load (queueing). JSON fields include `dl_throughput`/`ul_throughput` (bit/s), `base_rtt`, `responsiveness`.

**Units.** Mbit/s ÷ 8 = MB/s: a 600 Mbit/s line is 75 MB/s. Speed tests and ISP plans use Mbit/s; browsers and download managers usually show MB/s.

## Private Wi-Fi address

Per network, macOS and iOS use the hardware MAC (Off), a fixed private address, or a rotating one; the default is Fixed on WPA2-or-better networks. Set in System Settings › Wi‑Fi › network › Details (Mac) or Settings › Wi‑Fi › network › More Info (iPhone). Erasing the device or resetting network settings generates a new private address; forgetting the network does too, unless the network was last forgotten less than 24 hours earlier (iOS 18 / macOS 15 and later) ([Apple 102509](https://support.apple.com/en-us/102509)). The router sees, and DHCP reservations and MAC filters match, the address in use: `ifconfig <dev> | awk '/ether/{print $NF}'`.

## AWDL

`awdl0` is Apple Wireless Direct Link, the peer-to-peer Wi‑Fi used by AirDrop and AirPlay; `ifconfig awdl0` shows whether it is active. Measured behaviour (Stute et al., MobiCom 2018, [arXiv 1808.03156](https://arxiv.org/abs/1808.03156)): AWDL uses fixed "social" channels 6, 44 and 149 in short availability windows (16 TU each, about 1 s sequence); while connected to an AP the radio spends part of each sequence on AWDL channels and at least 25% on the AP's channel; with the AP on channel 44 combined throughput matched AP-only, with the AP on channel 36 it was about 13% lower. `sudo ifconfig awdl0 down` turns it off until re-enabled (`up`) or reboot, which also stops AirDrop and AirPlay.

## Apple's router recommendations

[Apple 102766](https://support.apple.com/en-us/102766) lists the settings Apple recommends for routers used with Apple devices:

```
SETTING                  APPLE'S VALUE
----------------------   -----------------------------------------------------
Security                 WPA3 Personal, or WPA2/WPA3 Transitional
Network name             one name across all bands (a different 6 GHz name
                         makes Wi‑Fi 6E devices flag limited compatibility)
Hidden network           disabled
MAC address filtering    disabled
Firmware updates         automatic
Radio mode               all modes, per band
Bands                    all enabled
Channel                  Auto
Channel width            2.4 GHz: 20 MHz; 5 and 6 GHz: Auto or all widths
DHCP lease               8 hours (home/office), 1 hour (hotspot/guest)
NAT                      on, only on the one device providing NAT
WMM                      enabled
Location Services        on, with Networking & Wireless enabled
```

Apple's roaming trigger thresholds: −75 dBm on Mac, −70 dBm on iPhone/iPad ([Optimize your Wi‑Fi networks](https://support.apple.com/guide/deployment/optimize-your-wi-fi-networks-dep2af1caf35/web)).

## Apple device capabilities

[Wi‑Fi and Ethernet specifications for Apple devices](https://support.apple.com/guide/deployment/dep268652e6c/web) lists, per model, each supported standard and band with maximum PHY rate, channel width, MCS and spatial streams. [Apple 102285](https://support.apple.com/en-us/102285) lists the models that join 6 GHz, and [Apple 148165](https://support.apple.com/en-us/148165) the models with Wi‑Fi 7 support. A Mac's own capabilities are its `Supported PHY Modes` and `Supported Channels` in `system_profiler`; the model is `system_profiler SPHardwareDataType | grep -E 'Model (Name|Identifier)|Chip'`.
