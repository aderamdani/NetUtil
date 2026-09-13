# References & Prior Art


NetUtil revives the spirit of Apple's discontinued Network Utility. The apps below
are the comparable Mac tools we looked at for feature and UX inspiration. All are
independent projects — nothing here is derived from their code; this is design prior
art and attribution.


## Comparable macOS apps


| App | Author | Notable features | Link |
|-----|--------|------------------|------|
| Network Utility X | DoubleREW | Network Info, LAN Scanner, Ping (packet size/timeout/interval, IPv6, live graph), Geo IP on a map, Dig, Notification Center widget, Whois, NSLookup | https://networkutility.app |
| Neo Network Utility | DEVONtechnologies | Netstat, Ping, Lookup, Traceroute, Whois, Finger, Port Scan, Network Speed; clean SwiftUI UI | https://www.devontechnologies.com/apps/freeware |
| NetUtil | Aaron Hampton | Ping, Traceroute, DNS, Netstat, Whois, Port Scan; in-app how-to guides | https://netutil.app |
| WhatRoute | Bryan Christianson | Enhanced traceroute + visualisation, networkQuality via GUI (responsiveness/RPM, idle latency, Private Relay, per-interface) | https://www.whatroute.net |


Background reading — "Where have the network tools gone?", Eclectic Light Company:
https://eclecticlight.co/2023/12/09/where-have-the-network-tools-gone/


## Ideas worth borrowing


- **Notification Center widget** (Network Utility X) — glanceable network info outside the app.
- **In-app how-to guides** (NetUtil.app) — e.g. change DNS, flush DNS cache, check open ports; pairs with the beginner-friendly (P1-9) and guided-troubleshooting (P2-7) goals.
- **Deeper networkQuality** (WhatRoute) — responsiveness/RPM, idle latency, Private Relay (`-p`) comparison, per-interface (`-I`).
- **Advanced ping options** (Network Utility X) — expose packet size, interval, timeout, and IPv6.
- **Interface-name canonicalization / protocol number-to-name** (Network to Code `netutils`, a Python automation library — not a GUI app) — small quality-of-life helpers.


## Naming note


The name "NetUtil" is shared with a shipping macOS app (netutil.app) and sits near
"Network Utility X" and "Neo Network Utility". For now the project keeps the NetUtil
name (GitHub / open-source); a rename would mainly matter for public Mac App Store
distribution, where the crowded "net-" naming space is worth revisiting.
