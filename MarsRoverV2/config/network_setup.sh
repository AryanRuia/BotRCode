#!/bin/bash
set -e

echo "Configuring TRUE OPEN WiFi hotspot..."

WLAN_INTERFACE=$(nmcli device | grep wifi | awk '{print $1}' | head -1)
HOTSPOT_SSID="MarsRover"
HOTSPOT_IP="192.168.4.1"

# 1. Delete old connection
nmcli connection delete "$HOTSPOT_SSID" 2>/dev/null || true

# 2. Add the connection without security parameters
nmcli connection add \
    type wifi \
    ifname "$WLAN_INTERFACE" \
    con-name "$HOTSPOT_SSID" \
    autoconnect yes \
    ssid "$HOTSPOT_SSID" \
    802-11-wireless.mode ap \
    ipv4.method shared \
    ipv4.addresses "$HOTSPOT_IP/24"

# 3. CRITICAL: Explicitly remove the security section to prevent WEP fallback
nmcli connection modify "$HOTSPOT_SSID" remove 802-11-wireless-security

# 4. Force 2.4GHz for compatibility
nmcli connection modify "$HOTSPOT_SSID" 802-11-wireless.band bg

# 5. Activate
echo "Activating hotspot..."
nmcli connection up "$HOTSPOT_SSID"

echo ""
echo "================================"
echo "Hotspot Configuration Complete!"
echo "================================"
echo ""
echo "WiFi Details:"
echo "  SSID: $HOTSPOT_SSID"
echo "  Security: NONE (Open Network)"
echo "  IP Address: $HOTSPOT_IP"
echo "  Interface: $WLAN_INTERFACE"
echo ""
echo "Access at: http://$HOTSPOT_IP:5000"
