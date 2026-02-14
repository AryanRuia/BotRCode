#!/bin/bash

# NetworkManager WiFi Hotspot Configuration for Raspberry Pi
# Configures WiFi access point using nmcli (NetworkManager)

set -e

echo "Configuring WiFi hotspot with NetworkManager..."
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
HOTSPOT_PASSWORD="password123"
HOTSPOT_IP="192.168.4.1"
HOTSPOT_NETMASK="255.255.255.0"

# Create hotspot connection with NetworkManager
echo "Creating hotspot connection..."

# Delete existing hotspot connection if it exists
nmcli connection delete "$HOTSPOT_SSID" 2>/dev/null || true

# Create new hotspot connection
nmcli connection add \
    type wifi \
    ifname "$WLAN_INTERFACE" \
    con-name "$HOTSPOT_SSID" \
    autoconnect yes \
    ssid "$HOTSPOT_SSID"

# Set WiFi mode to AP (Access Point)
nmcli connection modify "$HOTSPOT_SSID" \
    wifi.mode ap \
    ipv4.method shared \
    ipv4.addresses "$HOTSPOT_IP/24" \
    wifi-sec.key-mgmt wpa-psk \
    wifi-sec.psk "$HOTSPOT_PASSWORD"

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
echo "  Password: $HOTSPOT_PASSWORD"
echo "  IP Address: $HOTSPOT_IP"
echo "  Interface: $WLAN_INTERFACE"
echo ""
echo "Access at: http://$HOTSPOT_IP:5000"
echo ""
echo "To change WiFi credentials, edit this script and re-run it."
