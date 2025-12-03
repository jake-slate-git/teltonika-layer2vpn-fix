📘 README.md — Teltonika Layer-2 TAP Bridge Fix
🔧 Overview

curl -fsSL https://raw.githubusercontent.com/jake-slate-git/teltonika-layer2vpn-fix/main/install.sh | sh


Teltonika RUT routers (RUT241, RUT240, RUT200, TRB2xx, etc.) support OpenVPN TAP clients, but they do not reliably attach the TAP interface to the LAN bridge (br-lan).
When TAP isn’t bridged, Layer-2 traffic breaks, including:

multicast (224.x.x.x / 239.x.x.x)

broadcast

DHCP relay

ARP propagation

device discovery

cross-site service announcements

L2 TAK / ATAK multicast plugins

camera feeds using multicast

This repository installs a simple background watchdog on the Teltonika router that:

constantly checks for TAP interfaces (tap*)

automatically adds them into br-lan if missing

keeps them bridged through reconnects, reboots, OpenVPN renegotiations, and firmware quirks

No hotplug rules.
No UCI hacks.
No modifying .ovpn files.
No IP flushing.
No race conditions.

Just pure Layer-2 reliability.
