#!/bin/bash

# Quick start script for Mars Rover Streaming System
# This script handles startup and shutdown operations

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
VENV_PATH="$HOME/mars_rover_venv"
PYTHON_APP="$PROJECT_DIR/mars_rover_stream/main.py"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_venv() {
    if [ ! -d "$VENV_PATH" ]; then
        print_error "Virtual environment not found at $VENV_PATH"
        print_status "Please run setup.sh first"
        exit 1
    fi
}

start_hotspot() {
    print_status "Starting hotspot with NetworkManager..."
    
    # Get WiFi interface
    WLAN_INTERFACE=$(nmcli device | grep wifi | awk '{print $1}' | head -1)
    
    if [ -z "$WLAN_INTERFACE" ]; then
        print_error "No WiFi interface found!"
        return 1
    fi
    
    # Activate the hotspot connection
    if nmcli connection show "MarsRover" &>/dev/null; then
        nmcli connection up "MarsRover"
        print_success "Hotspot activated on $WLAN_INTERFACE"
    else
        print_error "MarsRover connection not found. Run setup.sh first."
        return 1
    fi
    
    sleep 2
    print_status "Hotspot is now active"
}

stop_hotspot() {
    print_status "Stopping hotspot..."
    
    if nmcli connection show "MarsRover" &>/dev/null; then
        nmcli connection down "MarsRover" || true
        print_success "Hotspot deactivated"
    else
        print_warning "MarsRover connection not found"
    fi
}

start_server() {
    check_venv
    print_status "Starting streaming server..."
    
    # Activate virtual environment and run
    source "$VENV_PATH/bin/activate"
    python3 "$PYTHON_APP"
}

stop_server() {
    print_status "Stopping streaming server..."
    pkill -f "python3 $PYTHON_APP" || print_warning "Server not running"
    print_success "Server stopped"
}

start_all() {
    print_status "Starting Mars Rover Streaming System..."
    echo ""
    start_hotspot
    echo ""
    start_server
}

stop_all() {
    print_status "Stopping Mars Rover Streaming System..."
    echo ""
    stop_server
    echo ""
    stop_hotspot
    print_success "System stopped"
}

show_status() {
    print_status "System Status:"
    echo ""
    
    echo "NetworkManager Connections:"
    nmcli connection show --active | grep -E "NAME|wifi" || print_warning "No active connections"
    echo ""
    
    echo "Hotspot Status:"
    if nmcli connection show "MarsRover" &>/dev/null; then
        if nmcli connection show --active | grep -q "MarsRover"; then
            echo "✓ MarsRover hotspot is ACTIVE"
            HOTSPOT_IP=$(nmcli device show | grep "wlan" -A 10 | grep "IP4.ADDRESS" | awk '{print $2}' | cut -d'/' -f1)
            echo "  IP Address: ${HOTSPOT_IP:-192.168.4.1}"
        else
            echo "✗ MarsRover hotspot is INACTIVE"
        fi
    else
        echo "✗ MarsRover connection not configured. Run setup.sh"
    fi
    echo ""
    
    echo "Connected Clients:"
    nmcli device wifi list 2>/dev/null | head -5 || print_warning "WiFi unavailable"
}

show_help() {
    cat << EOF
Mars Rover Streaming System - Quick Start

Usage: $0 {command}

Commands:
    start       Start both hotspot and streaming server
    stop        Stop both hotspot and streaming server
    server      Start only the streaming server
    hotspot     Start only the hotspot services
    status      Show system status
    help        Show this help message

Examples:
    $0 start        # Start everything
    $0 stop         # Stop everything
    $0 status       # Check if services are running

Access the stream at: http://192.168.4.1:5000
Default hotspot SSID: MarsRover
EOF
}

case "${1:-help}" in
    start)
        start_all
        ;;
    stop)
        stop_all
        ;;
    server)
        start_server
        ;;
    hotspot)
        start_hotspot
        ;;
    status)
        show_status
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        print_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
