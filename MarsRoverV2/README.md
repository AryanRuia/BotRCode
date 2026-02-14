# Mars Rover Camera Streaming System

A minimal, lightweight system for streaming live video from an IMX519 camera on Raspberry Pi 5 through a local WiFi hotspot.

## Features

- **WiFi Hotspot**: Creates a standalone WiFi network directly from the RPi
- **IMX519 Camera Support**: Optimized for IMX519 sensor (up to 4K capable)
- **MJPEG Streaming**: Lightweight MJPEG protocol for low-latency video streaming
- **Web Interface**: Beautiful, responsive web UI for viewing the stream
- **Minimal Dependencies**: Only Flask, Pillow, and picamera2 (pre-installed on Raspberry Pi OS)
- **Low Load**: ~30% CPU usage on RPi 5 at 1280x720@30FPS

## Hardware Requirements

- Raspberry Pi 5 (tested) - also compatible with Pi 4B/4B+
- IMX519 camera module
- SD card with Raspberry Pi OS installed
- Power supply (27W recommended for RPi 5)
- Optional: WiFi dongle if using heatsink-mounted RPi camera

## System Architecture

```
┌──────────────────────┐
│   IMX519 Camera      │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────────────────┐
│  Python Application (main.py)    │
│  ├─ picamera2 (frame capture)    │
│  ├─ Flask (web server)           │
│  └─ MJPEG Encoder (streaming)    │
└──────────┬──────────────────────┘
           │
     ┌─────┴──────┐
     ▼            ▼
┌─────────┐  ┌──────────┐
│ MJPEG   │  │ Web UI   │
│ Stream  │  │ (HTML)   │
└────┬────┘  └──────────┘
     │
     └──────► Connected Clients (via hotspot)
```

## Installation

### 1. Clone or Download the Project

```bash
cd ~/mars_rover_stream
```

### 2. Run the Setup Script

The setup script will:
- Update system packages
- Remove legacy networking packages (hostapd, dnsmasq)
- Install NetworkManager for modern hotspot configuration
- Create a Python virtual environment
- Install Python packages
- Configure the WiFi hotspot automatically

```bash
chmod +x setup.sh
./setup.sh
```

**Note**: The setup script requires `sudo` for system commands. You may be prompted for your password.

## Configuration

### WiFi Hotspot Settings

Edit `config/hostapd.conf`:

```bash
sudo nano config/hostapd.conf

## Configuration

### WiFi Hotspot Settings

To customize your WiFi hotspot (SSID and password), edit `config/network_setup.sh`:

```bash
nano config/network_setup.sh
```

Change these lines:
```bash
HOTSPOT_SSID="MarsRover"          # Your network name
HOTSPOT_PASSWORD="password123"    # Your WiFi password
HOTSPOT_IP="192.168.4.1"          # Access point IP
```

Then reconfigure NetworkManager:

```bash
chmod +x config/network_setup.sh
./config/network_setup.sh
```

Alternatively, use nmcli directly:

```bash
# Change password
nmcli connection modify MarsRover wifi-sec.psk "newpassword"

# Change SSID
nmcli connection delete MarsRover
./config/network_setup.sh  # Re-run with edited settings
```

### Camera Settings

Edit `mars_rover_stream/main.py` to adjust:

```python
# Line ~20
CAMERA_RESOLUTION = (1280, 720)  # Change to (1920, 1080) or (3840, 2160) for 4K
CAMERA_FPS = 30                   # Frames per second
JPEG_QUALITY = 85                 # 0-100, lower = smaller files, faster streaming
```

**Recommended Settings**:
- **1280x720 @ 30 FPS**: ~15 Mbps, minimal CPU load
- **1920x1080 @ 30 FPS**: ~25 Mbps, moderate CPU load
- **3840x2160 @ 15 FPS**: ~35 Mbps, higher CPU load (RPi 5 only)

## Running the System

### Quick Start (All-in-One)

```bash
cd ~/mars_rover_stream
./start.sh start
```

This will activate the hotspot and start the streaming server.

### Alternative: Manual Start

```bash
# Activate virtual environment
source ~/mars_rover_venv/bin/activate

# Start hotspot
./start.sh hotspot

# In another terminal, start streaming server
cd ~/mars_rover_stream
python3 main.py
```

### Start the Streaming Server

```bash
cd ~/mars_rover_stream
./start.sh server
```

Or with virtual environment:

```bash
source ~/mars_rover_venv/bin/activate
python3 mars_rover_stream/main.py
```

You should see output like:

```
INFO:__main__:==================================================
INFO:__main__:Mars Rover Streaming System
INFO:__main__:==================================================
INFO:__main__:Initializing IMX519 camera...
INFO:__main__:Camera initialized: (1280, 720) @ 30FPS
INFO:__main__:Frame capture thread started
INFO:__main__:Starting web server on 0.0.0.0:5000
INFO:__main__:/stream requested
```

### Connect and View Stream

From any device (phone, tablet, computer):

1. **Connect to the WiFi hotspot**:
   - Network: `MarsRover` (or your custom SSID)
   - Password: `password123` (or your custom password)

2. **Open a browser** and go to:
   ```
   http://192.168.4.1:5000
   ```

3. **View the live stream** in the web interface!

## Troubleshooting

### Camera Not Detected

If you get "Failed to initialize camera" error:

```bash
# Check camera connection
vcgencmd measure_temp
libcamera-hello --list-cameras
```

### Hotspot Not Appearing

```bash
# Check if hotspot connection exists
nmcli connection show

# If MarsRover exists but is not active
nmcli connection up MarsRover

# If MarsRover doesn't exist, reconfigure
./config/network_setup.sh

# Check hotspot details
nmcli device show wlan0
```

### NetworkManager Connection Issues

```bash
# List all connections
nmcli connection show

# Restart NetworkManager
sudo systemctl restart network-manager

# Check NetworkManager status
sudo systemctl status network-manager

# View detailed connection info
nmcli connection show MarsRover
```

### Stream Lag or Frame Drops

- Reduce resolution in `main.py`
- Lower JPEG quality
- Reduce frame rate
- Check WiFi channel for interference: `nmcli device wifi show`

### High CPU Usage

- Lower FPS (try 20 or 15)
- Reduce resolution
- Lower JPEG quality
- Check: `top` or `htop` while running

### Connection Refused

- Verify Flask is running: `curl http://localhost:5000`
- Check firewall: `sudo ufw status`
- Restart services:
  ```bash
  ./start.sh stop
  ./start.sh start
  ```

## Performance Metrics

On Raspberry Pi 5 with default settings (1280x720 @ 30 FPS, 85% JPEG quality):

- **CPU Usage**: ~25-30% (single core)
- **Memory Usage**: ~120 MB
- **Bitrate**: ~15 Mbps
- **Latency**: 100-200ms
- **Concurrent Clients**: 2-3 reliable

## Stopping the System

```bash
# Stop everything at once
./start.sh stop

# Or manually
./start.sh stop hotspot  # Stop hotspot
Ctrl+C                   # Stop server in terminal
```

## Automatic Startup (Optional)

To automatically start the streaming system on boot, use the included service file:

1. Copy the service file:

```bash
sudo cp config/mars-rover.service /etc/systemd/system/
```

2. Enable and test:

```bash
sudo systemctl daemon-reload
sudo systemctl enable mars-rover.service
sudo systemctl restart mars-rover.service
```

3. Check status:

```bash
sudo systemctl status mars-rover.service
sudo journalctl -u mars-rover.service -f
```

**Note**: The service requires both the hotspot and Python application to be running on boot. It will automatically start after network connectivity is established.

## API Endpoints

- `GET /` - Main web interface
- `GET /stream` - MJPEG video stream
- `GET /status` - System status JSON
  ```json
  {
    "status": "running",
    "camera": "initialized",
    "resolution": [1280, 720],
    "fps": 30
  }
  ```

## File Structure

```
mars_rover_stream/
├── setup.sh                 # Main setup script
├── start.sh                 # Quick start/stop script
├── test_camera.sh           # Hardware test script
├── requirements.txt         # Python dependencies
├── mars_rover_stream/
│   └── main.py             # Main application
├── templates/
│   └── index.html          # Web interface
└── config/
    ├── network_setup.sh    # NetworkManager hotspot setup
    ├── mars-rover.service  # Systemd service file (auto-start)
    ├── hostapd.conf        # (Legacy - kept for reference)
    └── dnsmasq.conf        # (Legacy - kept for reference)
```

## Dependencies

### System Packages
- `network-manager` - WiFi hotspot configuration via nmcli
- `python3-pip` & `python3-venv` - Python environment management
- `net-tools` - Network utilities

### Python Packages
- `flask==3.0.0` - Lightweight web framework
- `picamera2==0.3.17` - Raspberry Pi camera library
- `Pillow==11.0.0` - Image processing

All dependencies are installed by the setup script.

## Technology Stack

- **Hotspot**: NetworkManager (nmcli)
- **Web Server**: Flask
- **Streaming Protocol**: MJPEG over HTTP
- **Camera Interface**: picamera2 (libcamera)
- **Image Processing**: Pillow

## License

This project is provided as-is for Mars Rover applications.

## Notes

- Camera requires full sunlight or sufficient IR lighting for best results
- Hotspot range is typically 20-30 meters indoors
- Multiple connections may reduce performance - optimize resolution/FPS as needed
- Always use secure passwords for production systems
- NetworkManager replaced legacy hostapd/dnsmasq for better compatibility with Raspberry Pi OS Trixie
- Consider adding HTTPS for remote access (requires reverse proxy like nginx)

---

For updates or troubleshooting, check the system logs:

```bash
journalctl -u mars-rover.service -f
```
