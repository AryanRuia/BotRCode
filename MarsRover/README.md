# MarsRover

MarsRover is a small full-stack project intended to run on a Raspberry Pi (Pi 5) to collect telemetry from an LSM6DSOX IMU, BMP388 barometer, Arducam camera and an XBee radio.

Structure
- `backend/` - FastAPI backend that exposes REST and WebSocket endpoints and communicates with hardware drivers.
- `frontend/` - React UI that connects to the backend APIs and WebSocket to show live telemetry and snapshots.
- `setup.sh` - Consolidated setup script that installs dependencies, optionally configures and enables a Wi-Fi hotspot (hostapd/dnsmasq), enables Pi interfaces (I2C/Serial/Camera), creates venv and builds the frontend.

See `backend/README.md` and `frontend/README.md` for usage notes. For hotspot setup details see `HOTSPOT.md`.

## Quick setup on Raspberry Pi 5

This project includes helper scripts to streamline provisioning. Recommended minimal sequence to update the repo, install build dependencies, and start the services:

```bash
# 1) Update the repository
cd ~/BotRCode/MarsRover
git fetch origin
git pull origin main

# 2) Make scripts executable (run once)
chmod +x ./setup.sh
chmod +x backend/scripts/install-build-deps.sh

# 3) Install system build deps, create/activate venv, and install Python requirements
# Use the helper script below to set up the Python venv and build deps (preferred):
cd backend
./scripts/install-build-deps.sh

# (Optional) If you need the hotspot/system configuration or to run the full provisioning
# flow, run the consolidated setup script instead:
cd ..
./setup.sh

# 4) (Optional) Build frontend and copy into backend/static
cd ../frontend
npm ci
npm run build
cp -r dist/. ../backend/static/

# 5) Run backend directly for testing
cd ../backend
./venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000

# 6) (Optional) Enable systemd service
sudo systemctl daemon-reload
sudo systemctl enable --now marsrover-backend
sudo systemctl status marsrover-backend -l
```

Notes:
- The `./setup.sh` script performs system package installs (using `sudo`), enables services, creates/activates a `venv` under `backend/`, installs Python requirements, and optionally builds the frontend. Use the script unless you need a custom manual workflow.
- If a package still fails to build (for example `python-prctl`), see the "Troubleshooting wheel-build failures" section below for the manual apt/pip commands.
- If you want to discard local edits and force the repo to match `origin/main`, run:

```bash
git fetch origin
git reset --hard origin/main
git clean -fd
```

Troubleshooting wheel-build failures on Raspberry Pi
-----------------------------------------------

Some Python packages (for example `python-prctl`) require system C headers and libraries to build wheels. If you see errors like:

```
You need to install libcap development headers to build this module
ERROR: Failed to build 'python-prctl' when getting requirements to build wheel
```

Run these commands on the Pi to install common build dependencies and retry:

```bash
sudo apt update
sudo apt install -y libcap-dev build-essential python3-dev pkg-config

# activate project venv (if used)
cd ~/BotRCode/MarsRover/backend
source venv/bin/activate

# upgrade packaging tools and reinstall
pip install --upgrade pip setuptools wheel
pip install python-prctl
# or reinstall all requirements
pip install -r requirements.txt
```

Alternative: install the OS package (if available) to avoid building from source:

```bash
sudo apt install -y python3-prctl
pip install -r requirements.txt
```

If installation still fails, run `pip install python-prctl -v` and paste the output here for further diagnosis.

<!-- The separate helper script was removed in favor of using the single `./setup.sh` entrypoint. -->

5) Camera check (IMX519 / Arducam)

```bash
python backend/tools/check_camera.py
```
Expected outputs (one of):
- `Picamera2 import OK` and `Capture OK` (camera working)
- `libcamera-hello not found in PATH` but `rpicam-still --list-cameras` shows your IMX519 — Arducam drivers are present and you can either use Arducam tools or install `picamera2` into the project's venv to use the standard Picamera2 API (see `backend/README.md`).

If `picamera2` is missing, install it inside the venv:

```bash
source backend/venv/bin/activate
pip install 'picamera2>=0.3.30,<0.4'
```

If libcamera tools are missing entirely, install system package:

```bash
sudo apt install libcamera-apps
```

6) Build frontend (if not done by setup)

```bash
cd frontend
npm ci
npm run build
cp -r dist/. ../backend/static/
```
Expected output: Vite build completes and `dist/` files copied.

7) Start backend / enable service

- Run directly:
```bash
backend/venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000
```
Expected output: `INFO:     Started server` and logs for requests.

- Or enable systemd service (created by setup):
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now marsrover-backend
sudo systemctl status marsrover-backend -l
```
Expected output: `Active: active (running)` in the service status.

8) Smoke test endpoints

```bash
curl http://localhost:8000/api/sensors
curl http://localhost:8000/api/camera/snapshot --output snap.jpg
```
Expected output: JSON for sensors and a downloaded `snap.jpg` with image data.

9) If you need to undo hotspot changes:

```bash
sudo ./setup.sh hotspot-teardown
```
Expected output: backups restored and services stopped.

---

If anything fails, paste the command output here and I’ll help diagnose (ownership issues, pip package availability, or missing kernel modules for IMX519).

