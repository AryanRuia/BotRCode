# Mars Rover Streaming System - Getting Started Guide

## Quick Start (5 Minutes)

### Step 1: Initial Setup (First Time Only)

Copy all files to your Raspberry Pi and run the setup script:

```bash
# On your Raspberry Pi
cd ~/mars_rover_stream
chmod +x setup.sh
./setup.sh
```

This will:
- Update system packages
- Install required dependencies (hostapd, dnsmasq, Flask, picamera2)
- Create a Python virtual environment
- Configure basic hostapd/dnsmasq files

### Step 2: Configure Network

```bash
chmod +x config/network_setup.sh
sudo config/network_setup.sh
```

This configures your WiFi interface for hotspot mode.

### Step 3: Test Camera (Optional)

```bash
chmod +x test_camera.sh
./test_camera.sh
```

This verifies your camera is properly connected and detected.

### Step 4: Customize WiFi Hotspot (Optional)

Edit the WiFi settings:

```bash
sudo nano config/hostapd.conf
```

Change these lines:
```
ssid=MarsRover              # Your network name
wpa_passphrase=password123  # Your WiFi password
```

### Step 5: Start the System

```bash
chmod +x start.sh
./start.sh start
```

### Step 6: Access the Stream

1. From your phone/laptop, connect to the WiFi network (default: `MarsRover`)
2. Open your browser to: **http://192.168.4.1:5000**
3. You should see the live camera feed!

---

## System Commands

### Start Everything
```bash
./start.sh start
```

### Stop Everything
```bash
./start.sh stop
```

### Check Status
```bash
./start.sh status
```

### Start Just the Server
```bash
./start.sh server
```

### Start Just the Hotspot
```bash
./start.sh hotspot
```

---

## Adjusting Performance

### For Lower Latency
Edit `mars_rover_stream/main.py`:
```python
CAMERA_FPS = 15              # Lower FPS = less latency
JPEG_QUALITY = 70            # Lower = faster encoding
```

### For Better Quality
```python
CAMERA_RESOLUTION = (1920, 1080)  # Higher resolution
JPEG_QUALITY = 95                  # Better quality
```

### For Lower CPU Usage
```python
CAMERA_RESOLUTION = (960, 540)    # Lower resolution
CAMERA_FPS = 20                    # Fewer frames per second
```

---

## Common Issues

### "Camera not found" error
```bash
vcgencmd get_camera
```
Should output `supported=1 detected=1`

### WiFi hotspot not showing up
```bash
sudo systemctl restart hostapd
```

### Stream is very laggy
- Lower the resolution
- Reduce JPEG quality
- Lower the frame rate

### "Permission denied" when running scripts
```bash
chmod +x *.sh
chmod +x config/*.sh
```

---

## Useful Commands

### View camera info
```bash
libcamera-hello --list-cameras
```

### Monitor CPU usage while streaming
```bash
htop
```

### Check hotspot clients
```bash
sudo iw dev wlan0 station dump
```

### View streaming server logs
```bash
sudo journalctl -u mars-rover.service -f
```

---

## Setting Up Auto-Start (Optional)

To automatically start the system on boot:

```bash
sudo cp config/mars-rover.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable mars-rover.service

# Test it
sudo systemctl stop mars-rover.service
sudo systemctl start mars-rover.service
sudo systemctl status mars-rover.service
```

Now the system will start automatically when your Pi boots up!

---

## File Locations

```
~/mars_rover_stream/
├── setup.sh                 ← Initial setup
├── start.sh                 ← Start/stop system
├── test_camera.sh           ← Test hardware
├── requirements.txt         ← Python dependencies
├── README.md                ← Full documentation
├── QUICKSTART.md            ← This file
├── mars_rover_stream/
│   └── main.py              ← Main application (edit for settings)
├── templates/
│   └── index.html           ← Web interface
└── config/
    ├── hostapd.conf         ← WiFi settings (edit)
    ├── dnsmasq.conf         ← DHCP settings
    ├── network_setup.sh     ← Network configuration
    └── mars-rover.service   ← Auto-start service file
```

---

## Technical Details

**Architecture**: Python Flask web server + picamera2 + MJPEG streaming

**Network**: WiFi hotspot at 192.168.4.1 using standard 802.11g (2.4 GHz)

**Latency**: ~100-200ms (typical for MJPEG)

**CPU**: ~25-30% of one core on RPi 5 at 720p30

**Bandwidth**: ~15 Mbps at 720p30, ~25 Mbps at 1080p30

---

## Support

For detailed information, see **README.md**

For troubleshooting, run:
```bash
./test_camera.sh
./start.sh status
```

---

**Enjoy your Mars Rover streaming system!** 🚀
