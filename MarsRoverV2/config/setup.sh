#!/bin/bash
set -e

echo "================================"
echo "Mars Rover Streaming Setup"
echo "================================"

# Install system dependencies
echo "[1/6] Installing system dependencies..."
sudo apt-get update
sudo apt-get install -y python3-pip python3-venv network-manager net-tools

# Fix service name (Bookworm is case-sensitive)
echo "[2/6] Starting NetworkManager..."
sudo systemctl enable NetworkManager
sudo systemctl start NetworkManager

# Setup Virtual Environment
echo "[3/6] Creating Python virtual environment..."
python3 -m venv ~/mars_rover_venv
source ~/mars_rover_venv/bin/activate

echo "[4/6] Installing Python dependencies..."
pip install --upgrade pip
# Explicitly install picamera2 and flask inside the venv
pip install flask==3.0.0 Pillow==11.0.0 picamera2

# Configure hotspot
echo "[5/6] Configuring WiFi hotspot..."
# Note: Fixed path to network_setup.sh (it's in your current folder)
chmod +x config/network_setup.sh
./config/network_setup.sh

echo "[6/6] Setup Complete!"