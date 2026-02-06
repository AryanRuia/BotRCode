# MarsRover

MarsRover is a small full-stack project intended to run on a Raspberry Pi (Pi 5) to collect telemetry from an LSM6DSOX IMU, BMP388 barometer, Arducam camera and an XBee radio.

Structure
- `backend/` - FastAPI backend that exposes REST and WebSocket endpoints and communicates with hardware drivers.
- `frontend/` - React UI that connects to the backend APIs and WebSocket to show live telemetry and snapshots.
- `setup.sh` - Consolidated setup script that installs dependencies, optionally configures and enables a Wi-Fi hotspot (hostapd/dnsmasq), enables Pi interfaces (I2C/Serial/Camera), creates venv and builds the frontend.

See `backend/README.md` and `frontend/README.md` for usage notes. For hotspot setup details see `HOTSPOT.md`.

## Setup on Raspberry Pi 5 (recommended command order) ✅

Follow these steps on the Pi **as your normal user** (do NOT run the whole script with sudo; the script will call sudo when needed):

1) Update repo and inspect local changes

```bash
cd ~/BotRCode/MarsRover
git status
git fetch origin
# If you have local edits you want to keep:
# git add -A && git commit -m "WIP: save local changes"
# Or temporarily stash: git stash push -m "wip"

git pull origin main
```
Expected output: "Updating <old>..<new>" or "Already up to date." If there are conflicts, git will prompt to resolve them.

2) Make setup script executable

```bash
chmod +x ./setup.sh
```
Expected output: no output on success.

3) Run consolidated setup (interactive)

```bash
./setup.sh
```
Expected output highlights:
- "== MarsRover setup script =="
- Apt installs and service enable messages (may prompt for iptables-persistent)
- "Hotspot configuration complete. Your Pi should be advertising Wi-Fi SSID: <your-SSID>" (if chosen)
- "Running camera diagnostic..." followed by camera detection output
- "pip install -r backend/requirements.txt" success messages

If you prefer non-interactive provisioning (headless), run:

```bash
./setup.sh --yes --noninteractive --hotspot-ssid MarsSensor --hotspot-psk hunter2
```
This will pre-seed iptables and accept defaults.

4) Activate the Python venv and verify packages

```bash
source backend/venv/bin/activate
pip -V
pip list | grep -E "picamera2|adafruit|pytest"
```
Expected output: pip pointing to `backend/venv` and the listed packages present. Example: `pip X.Y.Z from /home/pi/MarsRover/backend/venv/lib/pythonX.X/site-packages (python X.X)`

Troubleshooting common pip errors
- If you see a permission error (OSError: Permission denied) when installing into the venv, it usually means the venv was created as root. Fix by:

```bash
# (recommended) change ownership back to your user
sudo chown -R "$(id -u):$(id -g)" backend/venv
# re-activate and retry
source backend/venv/bin/activate
pip install -r backend/requirements.txt
```
Expected output: no permission errors and packages installed.

- If pip reports a missing / incompatible package version (e.g. pytest==8.4.3 not found), try installing a flexible compatible version:

```bash
pip install 'pytest>=8.4.0,<9.0'
pip install -r backend/requirements.txt
```
Expected output: pytest wheel installed (e.g. `Successfully installed pytest-8.4.2`) and the final requirements command completes.

- To inspect available versions:

```bash
pip index versions <package>
# Example
pip index versions adafruit-circuitpython-bmp3xx
```

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

