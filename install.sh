#!/bin/sh
# Teltonika Layer-2 VPN Fix Installer (UCI-based)
# - Installs a hotplug script to keep TAP/OVPN interfaces bridged to br-lan
# - Updates OpenVPN UCI config (option extra) for TAP clients:
#     ifconfig-noexec
#     script-security 2
#     up /etc/hotplug.d/iface/99-vpn-bridge
#     up-restart
# - Applies the fix immediately to any existing TAP/OVPN interfaces

set -e

HOTPLUG="/etc/hotplug.d/iface/99-vpn-bridge"

echo ">>> Installing Teltonika Layer-2 VPN Fix (hotplug + UCI)..."

###############################################################################
# 1) Install hotplug script
###############################################################################

cat > "$HOTPLUG" <<'EOF'
#!/bin/sh
# Teltonika Layer-2 VPN Fix - hotplug
# Ensures OpenVPN TAP/OVPN interfaces behave as pure bridge ports:
#  - no local IP
#  - always attached to br-lan

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

###############################################################################
# 2) Patch OpenVPN UCI config (option extra) for TAP clients
###############################################################################

echo ">>> Updating OpenVPN UCI config for TAP clients..."

# Collect all openvpn section names (e.g. 'layer2vpn', 'custom_client', etc.)
SECTIONS=$(uci show openvpn 2>/dev/null | sed -n 's/^openvpn\.\([^=]*\)=openvpn.*/\1/p' || true)

ADD_SNIPPET="ifconfig-noexec
script-security 2
up /etc/hotplug.d/iface/99-vpn-bridge
up-restart"

for s in $SECTIONS; do
    enabled=$(uci -q get openvpn."$s".enabled || echo "1")   # default enabled if missing
    [ "$enabled" = "1" ] || continue

    dev=$(uci -q get openvpn."$s".dev || echo "")
    dev_type=$(uci -q get openvpn."$s".dev_type || echo "")

    # Determine if this section is a TAP client
    is_tap=0
    case "$dev_type" in
        tap|tap-*) is_tap=1 ;;
    esac
    case "$dev" in
        tap|tap*) is_tap=1 ;;
    esac

    [ "$is_tap" -eq 1 ] || continue

    extra=$(uci -q get openvpn."$s".extra || echo "")

    echo "$extra" | grep -q "ifconfig-noexec" && {
        echo "  - openvpn.$s already contains snippet, skipping"
        continue
    }

    # Append our snippet (with a leading newline if extra is non-empty)
    if [ -n "$extra" ]; then
        new_extra=$(printf "%s\n%s\n" "$extra" "$ADD_SNIPPET")
    else
        new_extra=$(printf "%s\n" "$ADD_SNIPPET")
    fi

    uci set openvpn."$s".extra="$new_extra"
    echo "  - patched openvpn.$s (TAP client)"
done

uci commit openvpn || true
/etc/init.d/openvpn restart 2>/dev/null || true

###############################################################################
# 3) Immediate apply to currently existing TAP/OVPN interfaces
###############################################################################

echo ">>> Applying fix to current TAP/OVPN interfaces..."

for IF in $(ip -o link show | awk -F': ' '{print $2}' | grep -E '^(tap|ovpn)' || true); do
  logger -t layer2vpn "Immediate fix for $IF"
  ip addr flush dev "$IF" 2>/dev/null || true
  if ! brctl show br-lan 2>/dev/null | grep -qw "$IF"; then
    brctl addif br-lan "$IF" 2>/dev/null || true
  fi
done

echo ">>> Teltonika Layer-2 VPN Fix installation complete."
echo "    - Hotplug keeps TAP/OVPN bridged to br-lan"
echo "    - OpenVPN TAP clients patched via UCI (option extra)"
