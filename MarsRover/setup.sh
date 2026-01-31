#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$ROOT_DIR/backend"
FRONTEND_DIR="$ROOT_DIR/frontend"

echo "== MarsRover setup script =="

if [[ "$EUID" -ne 0 ]]; then
  SUDO=sudo
else
  SUDO=""
fi

# CLI flags for streamlined / non-interactive runs
AUTO_YES=0
SKIP_HOTSPOT=0
NONINTERACTIVE=0
# hotspot defaults via CLI
HOTSPOT_SSID_ARG=""
HOTSPOT_PSK_ARG=""
HOTSPOT_IFACE_ARG=""
HOTSPOT_IP_ARG=""
HOTSPOT_DHCP_START_ARG=""
HOTSPOT_DHCP_END_ARG=""
HOTSPOT_SHARE_IFACE_ARG=""

while [[ ${#} -gt 0 ]]; do
  case "$1" in
    -y|--yes)
      AUTO_YES=1; shift;;
    --no-hotspot)
      SKIP_HOTSPOT=1; shift;;
    --noninteractive)
      NONINTERACTIVE=1; shift;;
    --hotspot-ssid)
      HOTSPOT_SSID_ARG="$2"; shift 2;;
    --hotspot-psk)
      HOTSPOT_PSK_ARG="$2"; shift 2;;
    --hotspot-iface)
      HOTSPOT_IFACE_ARG="$2"; shift 2;;
    --hotspot-ip)
      HOTSPOT_IP_ARG="$2"; shift 2;;
    --hotspot-dhcp-start)
      HOTSPOT_DHCP_START_ARG="$2"; shift 2;;
    --hotspot-dhcp-end)
      HOTSPOT_DHCP_END_ARG="$2"; shift 2;;
    --hotspot-share)
      HOTSPOT_SHARE_IFACE_ARG="$2"; shift 2;;
    -h|--help)
      echo "Usage: $0 [--yes] [--no-hotspot] [--noninteractive] [--hotspot-ssid SSID] [--hotspot-psk PSK] [--hotspot-iface IFACE] [--hotspot-ip IP] [--hotspot-dhcp-start IP] [--hotspot-dhcp-end IP] [--hotspot-share IFACE]"
      exit 0;;
    *)
      echo "Unknown option: $1"; shift;;
  esac
done

# If in noninteractive mode, preseed iptables-persistent to avoid prompts
if [[ "$NONINTERACTIVE" -eq 1 || "$AUTO_YES" -eq 1 ]]; then
  export DEBIAN_FRONTEND=noninteractive
  # auto-save IPv4 rules, don't autosave IPv6 by default
  echo "iptables-persistent iptables-persistent/autosave_v4 boolean true" | sudo debconf-set-selections || true
  echo "iptables-persistent iptables-persistent/autosave_v6 boolean false" | sudo debconf-set-selections || true
fi

# Detect OS and install required packages
OS="$(uname -s)"
if [[ "$OS" == "Linux" ]]; then
  # Basic apt-based install for Raspberry Pi OS / Debian
  echo "Detected Linux. Installing system packages (requires sudo)."
  $SUDO apt-get update

  # Prepare package list and detect libgpiod variant to avoid 'Unable to locate package' errors
  PKGS=(python3 python3-venv python3-pip i2c-tools libatlas3-base libffi-dev build-essential libcamera-apps hostapd dnsmasq iptables-persistent nodejs npm)
  if apt-cache show libgpiod2 >/dev/null 2>&1; then
    PKGS+=(libgpiod2)
  elif apt-cache show libgpiod1 >/dev/null 2>&1; then
    PKGS+=(libgpiod1)
  elif apt-cache show libgpiod >/dev/null 2>&1; then
    PKGS+=(libgpiod)
  else
    echo "Warning: no libgpiod package found in repositories; GPIO access may require manual installation (e.g., libgpiod-dev) or a kernel package. Continuing without it."
  fi

  echo "Installing packages: ${PKGS[*]}"
  $SUDO apt-get install -y "${PKGS[@]}" || {
    echo "Some packages failed to install. You can try running 'sudo apt-get update' and retrying, or install missing packages manually."
  }

  echo "Note: For camera support ensure libcamera is installed and camera is enabled in raspi-config if using Raspberry Pi OS."
else
  echo "Detected non-Linux OS ($OS). Please install Python 3.11+, Node.js, and system deps manually."
fi

# Raspberry Pi specific helpers
is_raspberry_pi() {
  # Check for /proc/device-tree/model containing 'Raspberry'
  if [[ -f /proc/device-tree/model ]] && grep -qi 'raspberry' /proc/device-tree/model; then
    return 0
  fi
  return 1
}

enable_pi_interfaces() {
  if ! command -v raspi-config >/dev/null 2>&1; then
    echo "raspi-config not found; please enable I2C/Serial/Camera manually or install raspi-config."
    return
  fi
  echo "Enabling I2C, Serial (UART) and Camera via raspi-config (non-interactive)."
  # 0 means disable/enable prompts? use 1 for enable
  sudo raspi-config nonint do_i2c 0 || true
  sudo raspi-config nonint do_serial 0 || true
  sudo raspi-config nonint do_camera 0 || true
  echo "Interfaces enabled (may require a reboot)."
}

# Hotspot configuration
backup_file() {
  local f="$1"
  if [[ -f "$f" ]]; then
    local ts
    ts=$(date +%Y%m%dT%H%M%S)
    sudo cp -a "$f" "${f}.marsrover.bak.${ts}"
    echo "Backed up $f -> ${f}.marsrover.bak.${ts}"
  fi
}

setup_hotspot() {
  # Honor CLI flags to allow non-interactive setup
  if [[ "${SKIP_HOTSPOT:-0}" == "1" ]]; then
    echo "Skipping hotspot setup due to --no-hotspot flag."
    return
  fi

  if [[ "$AUTO_YES" -eq 1 ]] || [[ -n "${HOTSPOT_SSID_ARG:-}" ]]; then
    echo "Auto-accepting hotspot setup (defaults may be used or overridden via --hotspot-* args)."
    SSID_DEFAULT="MarsRover"
    HOT_SSID="${HOTSPOT_SSID_ARG:-$SSID_DEFAULT}"
    HOT_PSK="${HOTSPOT_PSK_ARG:-}"
    HOT_IFACE="${HOTSPOT_IFACE_ARG:-wlan0}"
    HOT_IP="${HOTSPOT_IP_ARG:-192.168.50.1}"
    DHCP_START="${HOTSPOT_DHCP_START_ARG:-192.168.50.10}"
    DHCP_END="${HOTSPOT_DHCP_END_ARG:-192.168.50.100}"
    SHARE_IFACE="${HOTSPOT_SHARE_IFACE_ARG:-}"
    if [[ -n "$HOT_PSK" && ${#HOT_PSK} -lt 8 ]]; then
      echo "Provided hotspot passphrase is too short (min 8 chars). Aborting hotspot setup."
      return
    fi
  else
    read -rp "Would you like to configure this Pi as a Wi-Fi hotspot? [y/N]: " ans
    if [[ ! "$ans" =~ ^[Yy] ]]; then
      echo "Skipping hotspot setup."
      return
    fi

    # defaults
    SSID_DEFAULT="MarsRover"
    read -rp "Enter hotspot SSID [${SSID_DEFAULT}]: " HOT_SSID
    HOT_SSID="${HOT_SSID:-$SSID_DEFAULT}"

    while true; do
      read -rsp "Enter hotspot passphrase (min 8 chars): " HOT_PSK
      echo
      if [[ -z "$HOT_PSK" ]]; then
        echo "No passphrase entered; creating open hotspot (not recommended)."
        break
      elif [[ ${#HOT_PSK} -ge 8 ]]; then
        break
      else
        echo "Passphrase too short; must be at least 8 characters."
      fi
    done

    read -rp "Hotspot interface (default wlan0): " HOT_IFACE
    HOT_IFACE="${HOT_IFACE:-wlan0}"
    read -rp "Hotspot IP (default 192.168.50.1): " HOT_IP
    HOT_IP="${HOT_IP:-192.168.50.1}"
    read -rp "DHCP range start (default 192.168.50.10): " DHCP_START
    DHCP_START="${DHCP_START:-192.168.50.10}"
    read -rp "DHCP range end (default 192.168.50.100): " DHCP_END
    DHCP_END="${DHCP_END:-192.168.50.100}"
    read -rp "Share internet from interface (leave blank for none, e.g. eth0): " SHARE_IFACE
  fi

  echo "Configuring hotspot: SSID=$HOT_SSID IFACE=$HOT_IFACE IP=$HOT_IP"

  # Backup important files
  backup_file /etc/dhcpcd.conf
  backup_file /etc/dnsmasq.conf
  backup_file /etc/hostapd/hostapd.conf
  backup_file /etc/default/hostapd

  # Configure static IP for hotspot interface in dhcpcd.conf
  echo "Configuring static IP in /etc/dhcpcd.conf"
  # Remove any existing blocks for this interface to keep idempotent
  sudo sed -i "/^interface $HOT_IFACE$/,/^$/d" /etc/dhcpcd.conf || true
  sudo bash -c "cat >> /etc/dhcpcd.conf" <<EOF
interface $HOT_IFACE
static ip_address=$HOT_IP/24
nohook wpa_supplicant
EOF

  # Configure dnsmasq (use a site-specific conf in /etc/dnsmasq.d)
  echo "Configuring dnsmasq for DHCP"
  sudo bash -c "cat > /etc/dnsmasq.d/marsrover.conf" <<EOF
interface=$HOT_IFACE
bind-interfaces
server=8.8.8.8
dhcp-range=$DHCP_START,$DHCP_END,12h
EOF

  # Configure hostapd
  echo "Configuring hostapd"
  HOSTAPD_CONF="/etc/hostapd/hostapd.conf"
  sudo bash -c "cat > $HOSTAPD_CONF" <<EOF
interface=$HOT_IFACE
driver=nl80211
ssid=$HOT_SSID
hw_mode=g
channel=6
ieee80211n=1
wmm_enabled=1
ht_capab=[HT40+]
EOF
  if [[ -n "$HOT_PSK" ]]; then
    sudo bash -c "cat >> $HOSTAPD_CONF" <<EOF
wpa=2
wpa_passphrase=$HOT_PSK
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
EOF
  else
    echo "Configured open hotspot (no WPA)."
  fi

  # Point hostapd default to our conf
  if grep -q "DAEMON_CONF" /etc/default/hostapd 2>/dev/null; then
    sudo sed -i.bak -E "s|#?DAEMON_CONF=.*|DAEMON_CONF=\"$HOSTAPD_CONF\"|" /etc/default/hostapd
  else
    sudo bash -c "echo DAEMON_CONF=\"$HOSTAPD_CONF\" >> /etc/default/hostapd"
  fi

  # Enable IP forwarding
  echo "Enabling net.ipv4.ip_forward"
  # Ensure /etc/sysctl.conf exists before using sed
  if [[ ! -f /etc/sysctl.conf ]]; then
    echo "/etc/sysctl.conf not found — creating a new one"
    sudo bash -c "echo '# sysctl settings managed by MarsRover setup' > /etc/sysctl.conf"
  fi
  sudo sed -i.bak -E "s|#?net.ipv4.ip_forward=.*|net.ipv4.ip_forward=1|" /etc/sysctl.conf || true
  sudo sysctl -w net.ipv4.ip_forward=1 || true

  # Setup NAT if requested
  if [[ -n "$SHARE_IFACE" ]]; then
    echo "Setting up NAT from $SHARE_IFACE -> $HOT_IFACE"
    sudo iptables -t nat -A POSTROUTING -o "$SHARE_IFACE" -j MASQUERADE || true
    sudo iptables -A FORWARD -i "$SHARE_IFACE" -o "$HOT_IFACE" -m state --state RELATED,ESTABLISHED -j ACCEPT || true
    sudo iptables -A FORWARD -i "$HOT_IFACE" -o "$SHARE_IFACE" -j ACCEPT || true
    # Persist iptables rules
    sudo netfilter-persistent save || true
  fi

  echo "Enabling and restarting services: hostapd and dnsmasq"
  sudo systemctl unmask hostapd
  sudo systemctl enable hostapd
  sudo systemctl enable dnsmasq

  # Only try to restart dhcpcd if the service exists on this distro
  if systemctl list-unit-files | grep -q '^dhcpcd.service'; then
    sudo systemctl restart dhcpcd || true
  else
    echo "dhcpcd.service not present on this system; skipping restart"
  fi

  sudo systemctl restart dnsmasq || true
  sudo systemctl restart hostapd || true

  echo "Hotspot configuration complete. Your Pi should be advertising Wi-Fi SSID: $HOT_SSID"
  if [[ -n "$SHARE_IFACE" ]]; then
    echo "Internet is shared from $SHARE_IFACE."
  fi
  echo "Backups were made for modified system files with the suffix .marsrover.bak.*"
}

teardown_hotspot() {
  read -rp "This will attempt to restore backups and remove MarsRover hotspot configs. Proceed? [y/N]: " ans
  if [[ ! "$ans" =~ ^[Yy] ]]; then
    echo "Teardown cancelled."
    return
  fi

  echo "Attempting to restore backups..."
  for f in /etc/dhcpcd.conf /etc/dnsmasq.conf /etc/hostapd/hostapd.conf /etc/default/hostapd /etc/sysctl.conf; do
    latest=$(ls -1t ${f}.marsrover.bak.* 2>/dev/null | head -n1 || true)
    if [[ -n "$latest" ]]; then
      echo "Restoring $latest -> $f"
      sudo cp "$latest" "$f"
    else
      echo "No backup found for $f; attempting best-effort cleanup."
    fi
  done
  # Remove our optional dnsmasq drop-in
  if [[ -f /etc/dnsmasq.d/marsrover.conf ]]; then
    sudo rm -f /etc/dnsmasq.d/marsrover.conf
    echo "Removed /etc/dnsmasq.d/marsrover.conf"
  fi
  # Remove any interface block for typical hotspot iface names (wlan0 or as configured previously)
  sudo sed -i "/^interface wlan0$/,/^$/d" /etc/dhcpcd.conf || true

  sudo systemctl disable --now hostapd dnsmasq || true
  sudo netfilter-persistent reload || true
  echo "Teardown complete. Please reboot to ensure clean network state."
}

# Provide a simple CLI for hotspot management
if [[ "${1:-}" == "hotspot-teardown" ]]; then
  teardown_hotspot
  exit 0
fi

if is_raspberry_pi; then
  echo "Running Raspberry Pi specific configuration."
  enable_pi_interfaces
  setup_hotspot
else
  echo "Non-Pi Linux detected; skipping raspi-config and automated hotspot steps."
fi

# Backend venv and pip deps
python3 -m venv "$BACKEND_DIR/venv"
source "$BACKEND_DIR/venv/bin/activate"
python -m pip install --upgrade pip
if ! pip install -r "$BACKEND_DIR/requirements.txt"; then
  echo "\nERROR: pip failed to install some backend packages. Attempting automatic fallback for known packages..."

  # List of packages to attempt automatic resolution for (try latest available on index)
  FALLBACK_PKGS=("adafruit-circuitpython-lsm6ds" "adafruit-circuitpython-bmp3xx")
  for pkg in "${FALLBACK_PKGS[@]}"; do
    echo "Checking available versions for $pkg..."
    # Use 'pip index versions' output to obtain available versions; skip if it fails
    versions=$(pip index versions "$pkg" 2>/dev/null | sed -n 's/^Available versions: //p' | head -n1 || true)
    if [[ -n "$versions" ]]; then
      latest=$(echo "$versions" | awk -F',' '{print $1}' | tr -d '[:space:]')
      if [[ -n "$latest" ]]; then
        echo "Trying to install $pkg==$latest"
        if pip install "$pkg==$latest"; then
          echo "Installed $pkg==$latest"
        else
          echo "Failed to install $pkg==$latest"
        fi
      fi
    else
      echo "No available versions found via pip index for $pkg; skipping automatic fallback for this package."
    fi
  done

  echo "Retrying pip install -r $BACKEND_DIR/requirements.txt ..."
  if pip install -r "$BACKEND_DIR/requirements.txt"; then
    echo "pip install succeeded after fallback."
  else
    echo "Automatic fallback did not resolve all issues.\nCommon fixes: run 'pip index versions <package>' (e.g. adafruit-circuitpython-bmp3xx) to see available versions." 
    echo "Try installing problem packages manually, then re-run: pip install -r backend/requirements.txt"
    echo "If you're on Raspberry Pi, make sure piwheels is available and up-to-date."
    exit 1
  fi
fi

# Run camera diagnostics (helpful on Pi with IMX519/Arducam)
if is_raspberry_pi; then
  echo "\nRunning camera diagnostic (backend/tools/check_camera.py)..."
  if python3 "$BACKEND_DIR/tools/check_camera.py"; then
    echo "Camera diagnostic completed (see output above)."
  else
    echo "Camera diagnostic completed with errors (see output above). If your IMX519 requires Arducam drivers, follow instructions in backend/README.md."
  fi
fi

# Frontend deps and build
if command -v npm >/dev/null 2>&1; then
  (cd "$FRONTEND_DIR" && npm ci)
  (cd "$FRONTEND_DIR" && npm run build)
  # Copy build to backend/static for serving
  mkdir -p "$BACKEND_DIR/static"
  cp -r "$FRONTEND_DIR/dist/." "$BACKEND_DIR/static/" || true
else
  echo "npm not found; skip frontend build. Install Node.js and run 'npm ci' in /frontend then 'npm run build'."
fi

# Install systemd service if running on systemd/Linux
if [[ -d /run/systemd/system ]]; then
  echo "Installing systemd service (requires sudo)."
  SERVICE_PATH="/etc/systemd/system/marsrover-backend.service"
  $SUDO cp "$BACKEND_DIR/systemd/marsrover-backend.service" "$SERVICE_PATH"
  $SUDO systemctl daemon-reload
  echo "Service installed. Enable it with: sudo systemctl enable --now marsrover-backend"
fi

echo "Setup complete. Reboot if you enabled camera/serial interfaces or changed system configs."

cat <<EOF
Next manual steps (if on Raspberry Pi if needed):
 - If you prefer not to use raspi-config nonint, enable I2C/Serial/Camera via: sudo raspi-config -> Interface Options
 - If you changed camera/uart settings you may need to reboot: sudo reboot
 - To teardown the hotspot and restore backups run: sudo ./setup.sh hotspot-teardown
EOF
