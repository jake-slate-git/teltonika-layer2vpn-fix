#!/bin/sh
# Teltonika Layer-2 VPN Fix - hotplug + OpenVPN "up" script
# Ensures TAP/OVPN interfaces behave as pure L2 bridge ports:
#  - no local IP
#  - always attached to br-lan

# Try to determine interface name from various contexts
IF="${INTERFACE:-}"
[ -z "$IF" ] && IF="${dev:-}"
[ -z "$IF" ] && IF="$1"

# If we still don't know the interface, bail out
[ -z "$IF" ] && exit 0

# Only act on TAP / OVPN-style interfaces
case "$IF" in
  tap*|ovpn*) ;;
  *) exit 0 ;;
esac

# Ensure br-lan exists before touching it
if ! brctl show br-lan >/dev/null 2>&1; then
  logger -t layer2vpn "bridge-fix: br-lan not found, skipping for $IF"
  exit 0
fi

logger -t layer2vpn "bridge-fix: fixing $IF (flush IP + attach to br-lan)"

# Ensure it has no IP (pure L2 port)
ip addr flush dev "$IF" 2>/dev/null || true

# Attach to br-lan if not already present
if ! brctl show br-lan 2>/dev/null | grep -qw "$IF"; then
  brctl addif br-lan "$IF" 2>/dev/null || \
    logger -t layer2vpn "bridge-fix: failed to add $IF to br-lan"
fi
