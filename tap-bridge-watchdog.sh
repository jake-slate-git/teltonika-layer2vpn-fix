#!/bin/sh
# Teltonika Layer-2 VPN Fix - watchdog
# Periodically:
#  - finds TAP/OVPN interfaces (tap*, ovpn*)
#  - strips any IP addresses
#  - ensures they are added to br-lan

LOGTAG="layer2vpn-watchdog"

while true; do
  IFACES=$(ip -o link show 2>/dev/null | awk -F': ' '{print $2}' | grep -E '^(tap|ovpn)' || true)

  for IF in $IFACES; do
    brctl show br-lan >/dev/null 2>&1 || continue

    ip addr flush dev "$IF" 2>/dev/null || true

    if ! brctl show br-lan 2>/dev/null | grep -qw "$IF"; then
      logger -t "$LOGTAG" "Adding $IF to br-lan"
      brctl addif br-lan "$IF" 2>/dev/null || \
        logger -t "$LOGTAG" "Failed to add $IF to br-lan"
    fi
  done

  sleep 5
done
