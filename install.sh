#!/bin/sh
# Teltonika Layer-2 VPN Fix Installer
# Ensures OpenVPN TAP interfaces are treated as bridge ports (no IP, bridged to br-lan)

set -e

HOTPLUG="/etc/hotplug.d/iface/99-vpn-bridge"

echo ">>> Installing Teltonika Layer-2 VPN Fix..."

# --- Write hotplug script ---
cat > "$HOTPLUG" <<'EOF'
#!/bin/sh
# Auto-fix for OpenVPN TAP/OVPN interfaces on Teltonika RUTOS
# Ensures TAP ports act as true bridge members (L2 only)

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
EOF

chmod +x "$HOTPLUG"
echo "✓ Hotplug fix installed at $HOTPLUG"

# --- Apply immediately ---
echo ">>> Applying fix to current TAP interfaces..."
for IF in $(ip -o link show | awk -F': ' '{print $2}' | grep -E '^(tap|ovpn)'); do
  logger -t layer2vpn "Immediate fix for $IF"
  ip addr flush dev "$IF" 2>/dev/null || true
  if ! brctl show br-lan 2>/dev/null | grep -qw "$IF"; then
    brctl addif br-lan "$IF" 2>/dev/null || true
  fi
done

echo ">>> Done."
echo "Add this to your OpenVPN Additional config:"
echo "  ifconfig-noexec"
echo "  script-security 2"
echo "  up /etc/hotplug.d/iface/99-vpn-bridge"
echo "  up-restart"
