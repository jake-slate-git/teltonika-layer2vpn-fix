#!/bin/sh
# Teltonika Layer-2 VPN Fix - hotplug script

case "$ACTION:$INTERFACE" in
  ifup:tap*|ifupdate:tap*|ifup:ovpn*|ifupdate:ovpn*)
    logger -t layer2vpn "Fixing $INTERFACE (flush IP + attach to br-lan)"
    ip addr flush dev "$INTERFACE" 2>/dev/null || true

    if brctl show br-lan 2>/dev/null | grep -qw "$INTERFACE"; then
      :
    else
      brctl addif br-lan "$INTERFACE" 2>/dev/null || true
    fi
    ;;
esac
