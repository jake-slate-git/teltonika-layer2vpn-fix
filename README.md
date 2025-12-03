# Teltonika Layer-2 VPN Fix

Make OpenVPN TAP clients on Teltonika RUTOS routers behave like **real Layer-2 VPN bridges**:

- TAP interfaces never keep a local IP
- TAP interfaces are always part of `br-lan`
- Multicast, broadcast, DHCP, ARP, IGMP all flow across LAN ↔ VPN
- Behavior survives reboots and reconnects

Tested on:

- RUT241 (RUT2M_R_00.07.17.x / 00.07.18.x)
- Should also work on RUT240 / RUT200 / TRB2xx with OpenVPN TAP

## 🔧 Problem

On RUTOS with OpenVPN TAP (bridged) clients:

- The TAP interface (`tap_c_1`) gets its own IP
- It is not always added to `br-lan`
- Multicast and broadcast often fail between LANs over the VPN
- Reconnects can leave TAP detached or re-IP’d

## ✅ What this fix does

When you run the installer on the router:

1. Installs `/etc/hotplug.d/iface/99-vpn-bridge`  
   - Flushes any IP on `tap*` / `ovpn*`  
   - Adds them to `br-lan`

2. Installs `/root/tap-bridge-watchdog.sh`  
   - Every 5 seconds:
     - Finds all `tap*` / `ovpn*`
     - Flushes IPs
     - Ensures they are attached to `br-lan`

3. Updates `/etc/rc.local`  
   - Starts the watchdog automatically at boot

4. Patches OpenVPN UCI TAP clients (e.g. `openvpn.inst1`)  
   - `ifconfig_noexec = 1` (OpenVPN does not assign IP to TAP)  
   - `script_security = 2`  
   - `up = /etc/hotplug.d/iface/99-vpn-bridge`  
   - `up_restart = 1`

5. Restarts OpenVPN.

## 🚀 Install (on the router)

SSH into the RUT241 and run:

```sh
curl -fsSL https://raw.githubusercontent.com/jake-slate-git/teltonika-layer2vpn-fix/main/install.sh | sh
