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

Camera diagnostic helper
- A small helper is provided at `backend/tools/check_camera.py` that runs quick checks (libcamera presence, /dev/videoX, and a Picamera2 import + capture). Run it with:

  python backend/tools/check_camera.py

If `pip` fails installing `adafruit-circuitpython-lsm6ds` or `adafruit-circuitpython-bmp3xx`, try:
- pip index versions <package>  # e.g. pip index versions adafruit-circuitpython-bmp3xx
- pip install '<packageName>>=<min>,<max'  # e.g. pip install 'adafruit-circuitpython-bmp3xx>=1.3.0,<2.0'
- Ensure `piwheels` is available and up-to-date on Raspberry Pi (it provides prebuilt wheels for many CircuitPython libraries).

If you prefer, I can add an automatic camera check into `setup.sh` that runs `backend/tools/check_camera.py` and reports results after the installs. Would you like that added?- XBee connected via UART; the script will enable serial (UART) if run on a Raspberry Pi and you should set `SERIAL_PORT` correctly in `.env`.

The driver modules (`backend/drivers/*.py`) include software fallbacks so you can develop without hardware attached.

Hotspot
- For automated hotspot creation, run `sudo ./setup.sh` and accept the hotspot configuration prompts. To undo the hotspot, run `sudo ./setup.sh hotspot-teardown`.

