# Teltonika Layer-2 VPN Fix

Automatically repairs OpenVPN TAP interface behavior on RUTOS-based routers (RUT241, RUT240, RUT200, TRB2xx).

When using **OpenVPN TAP (bridged)** mode, Teltonika routers sometimes:
- assign an unwanted IP to the TAP interface
- fail to keep TAP correctly attached to `br-lan`
- break multicast, broadcast, and full L2 extension across the VPN

This fix ensures:
- TAP interfaces **never hold a local IP** (pure L2 ports)
- TAP interfaces are **automatically added to `br-lan`**
- multicast, broadcast, DHCP, ARP, IGMP all flow normally
- the fix persists across reboots and reconnects

## 🚀 Install (on the router)

SSH into the router and run:

```sh
curl -fsSL https://raw.githubusercontent.com/jake-slate-git/teltonika-layer2vpn-fix/main/install.sh | sh
