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
    MODEL=$(cat /proc/device-tree/model | tr -d '\0')
    echo "✓ Hardware: $MODEL"
else
    echo "✗ Not running on Raspberry Pi"
    exit 1
fi

# Check camera detection
echo ""
echo "[2/5] Checking camera detection..."
if command -v rpicam-hello &> /dev/null; then
    rpicam-hello --list-cameras
    echo "✓ rpicam tools available"
elif command -v libcamera-hello &> /dev/null; then
    libcamera-hello --list-cameras
    echo "✓ libcamera tools available"
else
    echo "✗ Camera tools (rpicam/libcamera) not found"
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
WLAN_INTERFACE=$(nmcli device | grep wifi | awk '{print $1}' | head -1)

if [ -n "$WLAN_INTERFACE" ]; then
    WLAN_IP=$(nmcli device show "$WLAN_INTERFACE" | grep "IP4.ADDRESS" | awk '{print $2}' | cut -d'/' -f1)
    echo "✓ WiFi interface found: $WLAN_INTERFACE"
    [ -n "$WLAN_IP" ] && echo "  IP Address: $WLAN_IP"
else
    echo "⚠ No WiFi interface detected"
fi

# Check NetworkManager and hotspot
echo ""
echo "Checking NetworkManager status..."
if nmcli connection show "MarsRover" &>/dev/null; then
    if nmcli connection show --active | grep -q "MarsRover"; then
        echo "✓ MarsRover hotspot is ACTIVE"
        HOTSPOT_IP=$(nmcli -t device show | grep DHCP4.OPTION | grep "routers = " | awk '{print $NF}' || echo "192.168.4.1")
        echo "  Access at: http://$HOTSPOT_IP:5000"
    else
        echo "⚠ MarsRover hotspot configured but not active"
        echo "  Run: nmcli connection up MarsRover"
    fi
else
    echo "⚠ MarsRover hotspot not configured"
    echo "  Run: ./setup.sh to configure"
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
