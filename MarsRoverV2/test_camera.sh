#!/bin/bash

# Mars Rover IMX519 Camera Test Script
# Tests camera connectivity and basic functionality

echo "================================"
echo "Mars Rover Camera Test Suite"
echo "================================"
echo ""

# Check if running on Raspberry Pi
echo "[1/5] Checking hardware..."
if grep -q "Raspberry Pi" /proc/device-tree/model 2>/dev/null; then
    MODEL=$(cat /proc/device-tree/model)
    echo "✓ Hardware: $MODEL"
else
    echo "✗ Not running on Raspberry Pi"
    exit 1
fi

# Check camera detection
echo ""
echo "[2/5] Checking camera detection..."
if command -v libcamera-hello &> /dev/null; then
    libcamera-hello --list-cameras
    echo "✓ libcamera tools available"
else
    echo "✗ libcamera tools not found"
fi

# Check Python environment
echo ""
echo "[3/5] Checking Python environment..."
python3 --version
if python3 -c "import picamera2" 2>/dev/null; then
    echo "✓ picamera2 installed"
else
    echo "⚠ picamera2 not installed (run setup.sh)"
fi

# Test Flask
echo ""
echo "[4/5] Checking Flask..."
if python3 -c "import flask" 2>/dev/null; then
    FLASK_VERSION=$(python3 -c "import flask; print(flask.__version__)")
    echo "✓ Flask $FLASK_VERSION installed"
else
    echo "⚠ Flask not installed (run setup.sh)"
fi

# Check network configuration
echo ""
echo "[5/5] Checking network configuration..."
if ip addr show wlan0 &>/dev/null; then
    WLAN0_IP=$(ip addr show wlan0 | grep "inet " | awk '{print $2}')
    echo "✓ wlan0 found: $WLAN0_IP"
else
    echo "⚠ wlan0 not configured"
fi

# Check hostapd and dnsmasq
if sudo systemctl is-active --quiet hostapd; then
    echo "✓ hostapd running"
else
    echo "⚠ hostapd not running (run: sudo systemctl start hostapd)"
fi

if sudo systemctl is-active --quiet dnsmasq; then
    echo "✓ dnsmasq running"
else
    echo "⚠ dnsmasq not running (run: sudo systemctl start dnsmasq)"
fi

echo ""
echo "================================"
echo "Test Complete"
echo "================================"
echo ""
echo "Next steps:"
echo "1. If all checks pass, run: ./start.sh start"
echo "2. Connect to MarsRover WiFi network"
echo "3. Open browser to http://192.168.4.1:5000"
