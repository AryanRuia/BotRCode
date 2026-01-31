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
pip install -r "$BACKEND_DIR/requirements.txt"

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
