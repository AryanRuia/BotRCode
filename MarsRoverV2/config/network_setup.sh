#!/bin/bash

# NetworkManager WiFi Hotspot Configuration for Raspberry Pi (Bookworm/Pi 5 Optimized)
# Configures an OPEN WiFi access point (no password) using nmcli (NetworkManager)

set -e

echo "Configuring OPEN WiFi hotspot with NetworkManager..."
echo ""

# Get interface name (usually wlan0)
WLAN_INTERFACE=$(nmcli device | grep wifi | awk '{print $1}' | head -1)

if [ -z "$WLAN_INTERFACE" ]; then
    echo "Error: No WiFi interface found!"
    echo "Available devices:"
    nmcli device
    exit 1
fi

echo "Using interface: $WLAN_INTERFACE"

# Network configuration variables
HOTSPOT_SSID="MarsRover"
HOTSPOT_IP="192.168.4.1"

# Create hotspot connection with NetworkManager
echo "Creating hotspot connection..."

# Delete existing hotspot connection if it exists
nmcli connection delete "$HOTSPOT_SSID" 2>/dev/null || true

# Create new OPEN hotspot connection
# Security is set to 'none' to remove password requirements for better Mac compatibility
nmcli connection add \
    type wifi \
    ifname "$WLAN_INTERFACE" \
    con-name "$HOTSPOT_SSID" \
    autoconnect yes \
    ssid "$HOTSPOT_SSID" \
    802-11-wireless.mode ap \
    wifi-sec.key-mgmt none \
    ipv4.method shared \
    ipv4.addresses "$HOTSPOT_IP/24"

# Force the WiFi band to 2.4GHz for maximum device compatibility
nmcli connection modify "$HOTSPOT_SSID" 802-11-wireless.band bg

# Activate the connection
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
