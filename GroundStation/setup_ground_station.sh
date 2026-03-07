#!/bin/bash

# Exit on any error
set -e

echo "--- Starting Ground Station Dependency Installation ---"

# 1. Update System Packages
echo "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# 2. Install System Dependencies
# python3-venv: For the virtual environment
# i2c-tools: To verify XBee/Sensors
# python3-pip: Package manager
echo "Installing system dependencies..."
sudo apt install -y python3-venv python3-pip i2c-tools network-manager

# 3. Enable UART (Required for XBee)
# This ensures the serial port /dev/ttyAMA0 is available
echo "Enabling UART for XBee communication..."
if ! grep -q "enable_uart=1" /boot/firmware/config.txt; then
    echo "enable_uart=1" | sudo tee -a /boot/firmware/config.txt
fi

# 4. Set up Python Virtual Environment
echo "Setting up Python virtual environment..."
python3 -m venv ~/mars_rover_venv
source ~/mars_rover_venv/bin/activate

# 5. Install Python Libraries
# flask: For the web dashboard
# pyserial: For XBee communication
# adafruit-circuitpython: Base for sensor libraries
echo "Installing Python libraries..."
pip install --upgrade pip
pip install flask pyserial adafruit-circuitpython-bmp3xx adafruit-circuitpython-lsm6ds pillow

# 6. Set Permissions
# Add user to 'dialout' group to access Serial without sudo
echo "Setting user permissions for Serial..."
sudo usermod -aG dialout $USER

echo "--- Setup Complete! ---"
echo "Please REBOOT your Pi now to apply UART and group permission changes."