# Backend (FastAPI)

This backend provides:
- /api/sensors - IMU + barometer readings
- /api/camera/snapshot - JPEG snapshot
- /api/xbee/send - send a command string to XBee
- /ws/telemetry - WebSocket pushing live telemetry

Quick start (on Raspberry Pi):

1. Copy `.env.example` to `.env` and edit if needed.
2. Run `./setup.sh` from project root to create a venv and install dependencies.
3. Start locally: `./backend/venv/bin/uvicorn app.main:app --reload --host 0.0.0.0 --port 8000`

Hardware notes:
- IMU (LSM6DSOX) and BMP388 use I2C (pins SDA/SCL). The top-level `setup.sh` can enable I2C via `raspi-config nonint` when run on a Raspberry Pi.
- Arducam camera (IMX519): your IMX519 sensor may require Arducam's custom kernel module or firmware and specific libcamera bindings. If your camera does not appear as a V4L2 or libcamera device after enabling the camera interface, follow Arducam's IMX519 installation steps (drivers and libcamera integration) — see https://www.arducam.com/docs/camera-for-raspberry-pi/ for the official instructions. After installing drivers, verify with: `libcamera-hello --list-cameras` and `v4l2-ctl --list-formats-ext -d /dev/video0`.
- The `setup.sh` installs `libcamera-apps` and the Python `picamera2` package (0.3.x series) but it cannot automatically install 3rd-party kernel modules—install IMX519 drivers manually if required.
- XBee connected via UART; the script will enable serial (UART) if run on a Raspberry Pi and you should set `SERIAL_PORT` correctly in `.env`.

The driver modules (`backend/drivers/*.py`) include software fallbacks so you can develop without hardware attached.

Hotspot
- For automated hotspot creation, run `sudo ./setup.sh` and accept the hotspot configuration prompts. To undo the hotspot, run `sudo ./setup.sh hotspot-teardown`.

