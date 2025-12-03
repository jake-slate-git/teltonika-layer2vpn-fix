#!/bin/sh
# Teltonika Layer-2 VPN Fix Installer
# - Installs hotplug script for TAP/OVPN interfaces
# - Installs watchdog to continuously enforce L2 behaviour
# - Patches OpenVPN UCI for TAP clients (ifconfig_noexec, up script)
# - Fixes rc.local to start watchdog on boot

set -e

HOTPLUG="/etc/hotplug.d/iface/99-vpn-bridge"
WATCHDOG="/root/tap-bridge-watchdog.sh"
LOGTAG="layer2vpn-install"

echo ">>> Installing Teltonika Layer-2 VPN Fix (hotplug + watchdog + UCI)..."

###############################################################################
# 1) Install hotplug script
###############################################################################

cat > "$HOTPLUG" <<'EOF'
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
EOF

chmod +x "$HOTPLUG"
echo "✓ Hotplug fix installed at $HOTPLUG"

###############################################################################
# 2) Install watchdog script
###############################################################################

cat > "$WATCHDOG" <<'EOF'
#!/bin/sh
# Teltonika Layer-2 VPN Fix - watchdog
# Periodically:
#  - finds TAP/OVPN interfaces (tap*, ovpn*)
#  - strips any IP addresses
#  - ensures they are added to br-lan

LOGTAG="layer2vpn-watchdog"

while true; do
  # Find TAP/OVPN-style interfaces
  IFACES=$(ip -o link show 2>/dev/null | awk -F': ' '{print $2}' | grep -E '^(tap|ovpn)' || true)

  for IF in $IFACES; do
    # Skip if br-lan doesn't exist
    brctl show br-lan >/dev/null 2>&1 || continue

    # Flush any IPs (keep it pure L2)
    ip addr flush dev "$IF" 2>/dev/null || true

    # Attach to br-lan if not already present
    if ! brctl show br-lan 2>/dev/null | grep -qw "$IF"; then
      logger -t "$LOGTAG" "Adding $IF to br-lan"
      brctl addif br-lan "$IF" 2>/dev/null || \
        logger -t "$LOGTAG" "Failed to add $IF to br-lan"
    fi
  done

  sleep 5
done
EOF

chmod +x "$WATCHDOG"
echo "✓ Watchdog installed at $WATCHDOG"

###############################################################################
# 3) Ensure watchdog runs at boot via /etc/rc.local
###############################################################################

RCLOCAL="/etc/rc.local"

# If rc.local doesn't exist, create a minimal one
if [ ! -f "$RCLOCAL" ]; then
  cat >"$RCLOCAL" <<'EOF'
#!/bin/sh

/root/tap-bridge-watchdog.sh &

exit 0
EOF
  chmod +x "$RCLOCAL"
  echo "✓ Created new $RCLOCAL with watchdog"
else
  # Strip any existing watchdog line and any existing 'exit 0'
  sed -i '/tap-bridge-watchdog\.sh/d' "$RCLOCAL"
  sed -i '/^exit 0$/d' "$RCLOCAL"

  # Append watchdog + exit 0 in correct order
  {
    echo ""
    echo "/root/tap-bridge-watchdog.sh &"
    echo ""
    echo "exit 0"
  } >> "$RCLOCAL"

  chmod +x "$RCLOCAL"
  echo "✓ Updated $RCLOCAL to start watchdog on boot"
fi

# Start watchdog immediately (if not already running)
if ! pgrep -f "tap-bridge-watchdog.sh" >/dev/null 2>&1; then
  "$WATCHDOG" &
  echo "✓ Watchdog started in background"
else
  echo "ℹ Watchdog already running"
fi

###############################################################################
# 4) Patch OpenVPN UCI config for TAP clients
###############################################################################

echo ">>> Updating OpenVPN UCI config for TAP clients..."

SECTIONS=$(uci show openvpn 2>/dev/null | sed -n 's/^openvpn\.\([^=]*\)=openvpn.*/\1/p' || true)

for s in $SECTIONS; do
  enabled=$(uci -q get openvpn."$s".enabled || echo "1")   # default enabled if missing
  [ "$enabled" = "1" ] || continue

  dev=$(uci -q get openvpn."$s".dev || echo "")
  dev_type=$(uci -q get openvpn."$s".dev_type || echo "")

  is_tap=0
  case "$dev_type" in
      tap|tap-*) is_tap=1 ;;
  esac
  case "$dev" in
      tap|tap*) is_tap=1 ;;
  esac

  [ "$is_tap" -eq 1 ] || continue

  # Apply safe defaults for TAP clients
  uci set openvpn."$s".script_security='2'
  uci set openvpn."$s".up='/etc/hotplug.d/iface/99-vpn-bridge'
  uci set openvpn."$s".up_restart='1'
  uci set openvpn."$s".ifconfig_noexec='1'

  echo "  - patched openvpn.$s (TAP client)"
done

uci commit openvpn || true
/etc/init.d/openvpn restart 2>/dev/null || true

echo ">>> Teltonika Layer-2 VPN Fix installation complete."
echo "    - Hotplug keeps TAP/OVPN bridged to br-lan on events"
echo "    - Watchdog enforces L2 behavior continuously"
echo "    - OpenVPN TAP clients patched via UCI (no IP on TAP)"
