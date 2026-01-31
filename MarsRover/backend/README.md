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
- Arducam/Pi camera: the `setup.sh` can enable the camera interface and will install `libcamera` tools. You may still need to reboot if prompted.
- XBee connected via UART; the script will enable serial (UART) if run on a Raspberry Pi and you should set `SERIAL_PORT` correctly in `.env`.

The driver modules (`backend/drivers/*.py`) include software fallbacks so you can develop without hardware attached.

Hotspot
- For automated hotspot creation, run `sudo ./setup.sh` and accept the hotspot configuration prompts. To undo the hotspot, run `sudo ./setup.sh hotspot-teardown`.

