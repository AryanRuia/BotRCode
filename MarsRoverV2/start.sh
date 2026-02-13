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
    print_status "Starting hotspot services..."
    
    # Check if already running
    if sudo systemctl is-active --quiet hostapd; then
        print_warning "hostapd is already running"
    else
        sudo systemctl start hostapd
        print_success "hostapd started"
    fi
    
    if sudo systemctl is-active --quiet dnsmasq; then
        print_warning "dnsmasq is already running"
    else
        sudo systemctl start dnsmasq
        print_success "dnsmasq started"
    fi
    
    sleep 2
    print_status "Hotspot should be available now"
}

stop_hotspot() {
    print_status "Stopping hotspot services..."
    sudo systemctl stop hostapd || true
    sudo systemctl stop dnsmasq || true
    print_success "Hotspot services stopped"
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
    
    echo "Hotspot Services:"
    sudo systemctl status hostapd --no-pager | head -3
    echo ""
    sudo systemctl status dnsmasq --no-pager | head -3
    echo ""
    
    echo "Network Configuration:"
    ip addr show wlan0 2>/dev/null | grep "inet " || print_warning "wlan0 not found"
    echo ""
    
    echo "Connected Clients:"
    sudo iw dev wlan0 station dump 2>/dev/null | grep -E "Station|signal|tx.*bitrate" || print_warning "No clients connected"
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
