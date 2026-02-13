#!/bin/bash

# Network Interface Setup for Raspberry Pi Hotspot
# Configures wlan0 for hotspot mode

echo "Configuring network interfaces..."

# Set up wlan0 with static IP for hotspot
sudo tee /etc/network/interfaces.d/wlan0 > /dev/null <<EOF
auto wlan0
iface wlan0 inet static
    address 192.168.4.1
    netmask 255.255.255.0
    broadcast 192.168.4.255
EOF

# Disable IPv6 for simplicity (optional)
sudo sysctl -w net.ipv6.conf.wlan0.disable_ipv6=1

# Enable IP forwarding for internet sharing (if needed)
sudo sysctl -w net.ipv4.ip_forward=1

# Restart networking
sudo systemctl restart networking || sudo ifconfig wlan0 192.168.4.1 netmask 255.255.255.0

echo "Network configuration complete!"
echo "wlan0 is now configured for hotspot at 192.168.4.1"
