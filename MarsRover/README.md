# MarsRover

MarsRover is a small full-stack project intended to run on a Raspberry Pi (Pi 5) to collect telemetry from an LSM6DSOX IMU, BMP388 barometer, Arducam camera and an XBee radio.

Structure
- `backend/` - FastAPI backend that exposes REST and WebSocket endpoints and communicates with hardware drivers.
- `frontend/` - React UI that connects to the backend APIs and WebSocket to show live telemetry and snapshots.
- `setup.sh` - Consolidated setup script that installs dependencies, optionally configures and enables a Wi-Fi hotspot (hostapd/dnsmasq), enables Pi interfaces (I2C/Serial/Camera), creates venv and builds the frontend.

See `backend/README.md` and `frontend/README.md` for usage notes. For hotspot setup details see `HOTSPOT.md`.

