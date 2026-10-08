# Network

Wi‑Fi hardware, how the box chooses its regulatory channels, and where its connection state is read. Device facts *(read on MiTV-AFMU0)*.

## Hardware and interfaces

The Wi‑Fi/Bluetooth chip is Amlogic W2 (`getprop vendor.wlan.wifi_chip` → `aml_w2`; kernel modules `w2`, `w2_comm`, `cfg80211` in `/proc/modules`). Interfaces (`ls /sys/class/net`, `ip link`): `wlan0` (client), `p2p0` (Wi‑Fi Direct), `ap0` (hotspot), `eth0` (exists, no carrier; the box has no Ethernet port per [Xiaomi FAQ](https://www.mi.com/global/support/faq/details/KA-567165/)). Xiaomi lists Wi‑Fi 6 on 2.4 and 5 GHz with OFDMA and MU-MIMO, and no 6 GHz ([hardware.md](hardware.md)). `ip addr show wlan0` (its `link/ether` line) shows the MAC in use; `ip link show <if>` and `/sys/class/net/wlan0/address` are denied to the shell.

## Connection state

```
READ                                                        SHOWS
---------------------------------------------------------   ---------------------------------------------------------
cmd wifi status                                             enabled, connected SSID, TX/RX counters
dumpsys wifi | grep -m1 'Wi-Fi standard'                    the live connection: Security type, Wi-Fi standard,
                                                            RSSI, Link speed (TX), Rx Link speed, Frequency, IP
dumpsys wifi | grep -iE 'NetworkSelectionStatus|TransitionDisable'   saved-network selection state, WPA3
                                                                     transition-disable events
cmd wifi list-scan-results                                  nearby networks (BSSID, frequency, RSSI, SSID)
cmd wifi is-verbose-logging                                 verbose Wi‑Fi logging state
```

`Security type` numbers follow `WifiConfiguration.SECURITY_TYPE_*` (0 open, 1 WEP, 2 PSK/WPA2, 4 SAE/WPA3, …) ([WifiConfiguration.java](https://android.googlesource.com/platform/packages/modules/Wifi/+/refs/heads/android14-release/framework/java/android/net/wifi/WifiConfiguration.java)). `Wi-Fi standard: 6` is 802.11ax. The frequency converts to a channel n by its band's centre formula: 2.4 GHz = 2407 + 5n MHz (channel 14 = 2484 MHz), 5 GHz = 5000 + 5n MHz, 6 GHz = 5950 + 5n MHz ([List of WLAN channels](https://en.wikipedia.org/wiki/List_of_WLAN_channels)). `cmd wifi set-verbose-logging enabled|disabled` switches verbose Wi‑Fi logging; `dumpsys wifi | grep -i 'verbose logging'` shows the state.

`cmd wifi list-networks` lists saved networks with their ids; adding one is not open to the shell on Android 14 ([commands.md § wifi](commands.md#wifi)), so networks are added on the TV, and `forget-network <id>` takes an id from that list.

## Country code and channels

The Wi‑Fi country code decides which channels the box scans and joins. Android's `pickCountryCode()` order: override → mobile-network country → driver country (from nearby AP beacons, used only without a mobile country) → framework-generic code → the default stored in the Wi‑Fi config store, which starts from `ro.boot.wificountrycode` ([WifiCountryCode.java](https://android.googlesource.com/platform/packages/modules/Wifi/+/refs/heads/android14-release/service/java/com/android/server/wifi/WifiCountryCode.java)). On a wifi-only box (`getprop ro.carrier` → `wifi-only`) there is no mobile country.

```
READ                                                          SHOWS
-----------------------------------------------------------   --------------------------------------------
cmd wifi get-country-code                                     active code
dumpsys wifi | grep -E 'DefaultCountryCode|mDriverCountryCode|mOverrideCountryCode|mTelephonyCountryCode|wifi_last_country_code'
                                                              where the code came from
dumpsys wifi | grep -oE 'SupportedChannelListIn(24g|5g|6g)[^]]*\]'
                                                              channels allowed for the box's own hotspot
                                                              under the active code
getprop persist.sys.country                                   UI region
```

The station-side scan list is not printed by `dumpsys wifi`; the hotspot channel lists follow the same regulatory table. With country IL the lists read 2.4 GHz 1–11 and 5 GHz 36–48, 149–165 *(read on MiTV-AFMU0)*. `cmd wifi list-scan-results` shows which frequencies the box actually scanned and found networks on.

## Private DNS

Android 14 supports DNS-over-TLS system-wide: `settings put global private_dns_mode hostname` with `private_dns_specifier <host>`, or `opportunistic`, or `off` ([settings.md § Network](settings.md#network-and-wi-fi-settings)). `dumpsys connectivity | grep -oE 'UsePrivateDns: [a-z]+ ValidatedPrivateDnsAddresses: \[[^]]*\]'` shows whether DNS-over-TLS is in use on the active network and which servers validated. Google: devices "automatically upgrade to DNS over TLS if a network's DNS server supports it", and with a configured hostname that can't be reached Android "marks the network as 'No internet access'" ([Android Developers blog, DNS over TLS](https://android-developers.googleblog.com/2018/04/dns-over-tls-support-in-android-p.html)).
