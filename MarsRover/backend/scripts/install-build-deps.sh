#!/usr/bin/env bash
set -euo pipefail

# Script to install common C build dependencies and Python packaging tools
# Run from the repository: `cd backend && ./scripts/install-build-deps.sh`

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$BASE_DIR"

echo "Updating apt and installing build dependencies (sudo will be used)..."
sudo apt update
sudo apt install -y libcap-dev build-essential python3-dev pkg-config

if [ -d "venv" ]; then
  echo "Activating existing venv at $BASE_DIR/venv"
  # shellcheck disable=SC1091
  . venv/bin/activate
else
  echo "No venv found — creating venv at $BASE_DIR/venv"
  python3 -m venv venv
  . venv/bin/activate
fi

pip install --upgrade pip setuptools wheel

echo "Attempting to install python-prctl (may build from source)..."
pip install python-prctl || echo "python-prctl install failed; continuing to install remaining requirements"

echo "Installing remaining Python requirements from requirements.txt..."
pip install -r requirements.txt

echo "Done. If any package failed to build, run 'pip install <package> -v' for verbose logs."
