#!/bin/bash

# Mars Rover Streaming System - Setup Script for Raspberry Pi 5
# This script configures the system for hotspot + camera streaming

set -e  # Exit on error

echo "================================"
echo "Mars Rover Streaming Setup"
echo "================================"

# Check if running on Raspberry Pi
if ! grep -q "Raspberry Pi" /proc/device-tree/model 2>/dev/null; then
    echo "Warning: This script is designed for Raspberry Pi"
fi

# Update system
echo "[1/6] Updating system packages..."
sudo apt-get update
sudo apt-get upgrade -y

# Install system dependencies
echo "[2/6] Installing system dependencies..."
sudo apt-get install -y \
    python3-pip \
    python3-venv \
    hostapd \
    dnsmasq \
    rfkill \
    net-tools

# Install Python packages
echo "[3/6] Creating Python virtual environment..."
python3 -m venv /home/$(whoami)/mars_rover_venv
source /home/$(whoami)/mars_rover_venv/bin/activate

echo "[4/6] Installing Python dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

# Copy configuration files
echo "[5/6] Setting up configuration files..."
CONFIG_DIR="/home/$(whoami)/mars_rover_stream/config"
sudo cp config/hostapd.conf /etc/hostapd/hostapd.conf || true
sudo cp config/dnsmasq.conf /etc/dnsmasq.conf || true

# Enable services
echo "[6/6] Enabling services..."
sudo systemctl enable hostapd 2>/dev/null || true
sudo systemctl enable dnsmasq 2>/dev/null || true

echo ""
echo "================================"
echo "Setup Complete!"
echo "================================"
echo ""
echo "Next steps:"
echo "1. Edit /etc/hostapd/hostapd.conf to change WiFi name/password"
echo "2. Configure network interface in config/network_setup.sh"
echo "3. Run: source /home/$(whoami)/mars_rover_venv/bin/activate"
echo "4. Start the server: python3 mars_rover_stream/main.py"
echo ""
echo "Access the camera stream at: http://192.168.4.1:5000"
echo ""
