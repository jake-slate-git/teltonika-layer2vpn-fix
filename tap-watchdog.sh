#!/bin/sh
# Teltonika TAP-to-LAN Bridge Watchdog
# Ensures all TAP interfaces remain attached to br-lan.

LOGTAG="tap-watchdog"

while true; do
    # Find TAP interfaces (tap_c_1, tap_s_1, tap0, etc)
    for IF in $(ip -o link show | awk -F': ' '{print $2}' | grep '^tap'); do

        # Skip if br-lan doesn't exist yet
        brctl show br-lan >/dev/null 2>&1 || continue

        # Add TAP to br-lan if missing
        if ! brctl show br-lan 2>/dev/null | grep -qw "$IF"; then
            logger -t "$LOGTAG" "Adding $IF to br-lan"
            brctl addif br-lan "$IF" 2>/dev/null || \
                logger -t "$LO
