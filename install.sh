#!/bin/sh
# Simple TAP-to-br-lan Bridge Watchdog installer

WATCHDOG="/root/tap-watchdog.sh"
RCLOCAL="/etc/rc.local"

echo ">>> Installing TAP-to-LAN watchdog..."

# Install watchdog script
cat > "$WATCHDOG" <<'EOF'
#!/bin/sh
LOGTAG="tap-watchdog"

while true; do
    for IF in $(ip -o link show | awk -F': ' '{print $2}' | grep "^tap"); do
        brctl show br-lan >/dev/null 2>&1 || continue

        if ! brctl show br-lan | grep -qw "$IF"; then
            logger -t "$LOGTAG" "Adding $IF to br-lan"
            brctl addif br-lan "$IF" 2>/dev/null
        fi
    done
    sleep 3
done
EOF

chmod +x "$WATCHDOG"
echo "✓ Watchdog installed at $WATCHDOG"

# Update rc.local to start watchdog at boot
sed -i '/tap-watchdog/d' "$RCLOCAL"
sed -i '/^exit 0$/d' "$RCLOCAL"

{
    echo "/root/tap-watchdog.sh &"
    echo "exit 0"
} >> "$RCLOCAL"

chmod +x "$RCLOCAL"
echo "✓ Watchdog added to rc.local"

# Start immediately
"$WATCHDOG" &
echo "✓ Watchdog started"

echo ">>> TAP watchdog setup complete."
