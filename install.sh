#!/usr/bin/env bash
#
# Installation script for Auto Screen Rotation Service
# This script sets up the systemd user service for automatic screen rotation
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_NAME="autoscreenrotation.service"
USER_SERVICE_DIR="$HOME/.config/systemd/user"

echo "=== Auto Screen Rotation Service Installation ==="
echo "Installing from: $SCRIPT_DIR"
echo

# Check prerequisites
echo "Checking prerequisites..."

# Check if running on a supported system
if ! systemctl --version >/dev/null 2>&1; then
    echo "ERROR: systemd not found. This installation requires systemd."
    exit 1
fi

# Check if monitor-sensor is available
if ! command -v monitor-sensor >/dev/null 2>&1; then
    echo "WARNING: monitor-sensor not found."
    echo "Please install iio-sensor-proxy:"
    echo "  Ubuntu/Debian: sudo apt install iio-sensor-proxy"
    echo "  Arch Linux: sudo pacman -S iio-sensor-proxy"
    echo "  Fedora: sudo dnf install iio-sensor-proxy"
    echo
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check if kscreen-doctor is available
if ! command -v kscreen-doctor >/dev/null 2>&1; then
    echo "WARNING: kscreen-doctor not found."
    echo "This is required by this script for screen rotation on KDE/Wayland."
    echo "Please install it through your package manager."
    echo
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "Prerequisites check completed."
echo

# Make scripts executable
echo "Making scripts executable..."
chmod +x "$SCRIPT_DIR/autoscreenrotation.sh"
chmod +x "$SCRIPT_DIR/screenrotation.sh"
[ -f "$SCRIPT_DIR/enableInput.sh" ] && chmod +x "$SCRIPT_DIR/enableInput.sh"
[ -f "$SCRIPT_DIR/disableInput.sh" ] && chmod +x "$SCRIPT_DIR/disableInput.sh"
[ -f "$SCRIPT_DIR/toggleInput.sh" ] && chmod +x "$SCRIPT_DIR/toggleInput.sh"
[ -f "$SCRIPT_DIR/setup-passwordless-sudo.sh" ] && chmod +x "$SCRIPT_DIR/setup-passwordless-sudo.sh"

# Create user systemd directory
echo "Setting up systemd user service..."
mkdir -p "$USER_SERVICE_DIR"

# Update service file with correct paths
SERVICE_FILE="$USER_SERVICE_DIR/$SERVICE_NAME"
sed "s|SCRIPT_DIR_PLACEHOLDER|$SCRIPT_DIR|g" \
    "$SCRIPT_DIR/$SERVICE_NAME" > "$SERVICE_FILE"

# Initialize config files
echo "Initializing configuration..."
mkdir -p ~/.config
[ ! -f ~/.config/autoscreenrotate ] && echo "true" > ~/.config/autoscreenrotate
[ ! -f ~/.config/disableinput ] && echo "false" > ~/.config/disableinput

echo "Configuration files created:"
echo "  ~/.config/autoscreenrotate ($(cat ~/.config/autoscreenrotate))"
echo "  ~/.config/disableinput ($(cat ~/.config/disableinput))"
echo

# Reload systemd and enable service
echo "Enabling systemd service..."
systemctl --user daemon-reload
systemctl --user enable "$SERVICE_NAME"

echo
echo "=== Installation Complete ==="
echo
echo "The auto screen rotation service has been installed and enabled."
echo
echo "Available commands:"
echo "  Start service:    systemctl --user start $SERVICE_NAME"
echo "  Stop service:     systemctl --user stop $SERVICE_NAME"
echo "  Service status:   systemctl --user status $SERVICE_NAME"
echo "  View logs:        journalctl --user -u $SERVICE_NAME -f"
echo "  Disable service:  systemctl --user disable $SERVICE_NAME"
echo
echo "Configuration:"
echo "  Enable/disable auto rotation: echo 'true/false' > ~/.config/autoscreenrotate"
echo "  Enable/disable input control: echo 'true/false' > ~/.config/disableinput"
echo
echo "The service will start automatically at your next login."
echo "To start it now, run: systemctl --user start $SERVICE_NAME"
echo

# Ask if user wants to start the service now
read -p "Start the service now? (Y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
    echo "Starting service..."
    systemctl --user start "$SERVICE_NAME"
    sleep 2
    echo "Service status:"
    systemctl --user status "$SERVICE_NAME" --no-pager -l
fi

echo
echo "=== Optional Quality of Life Setup ==="
echo

# Ask about desktop file creation
if [ -f "$SCRIPT_DIR/toggleInput.sh" ]; then
    echo "For touch-friendly tablet mode control:"
    read -p "Create .desktop file for Toggle Tablet Mode? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Creating .desktop file..."
        mkdir -p ~/.local/share/applications
        cat > ~/.local/share/applications/toggle-tablet-mode.desktop << EOF
[Desktop Entry]
Name=Toggle Tablet Mode
Comment=Toggle between tablet and laptop input modes
Exec=konsole -e bash -c "sudo $SCRIPT_DIR/toggleInput.sh; sleep 2"
Icon=input-tablet
Type=Application
Categories=System;
Terminal=false
StartupNotify=true
EOF
        # Update desktop database
        if command -v update-desktop-database >/dev/null 2>&1; then
            update-desktop-database ~/.local/share/applications
        fi
        echo "✅ Desktop file created: ~/.local/share/applications/toggle-tablet-mode.desktop"
        echo "You can now find 'Toggle Tablet Mode' in your application launcher!"
        echo "The toggle will briefly show a terminal window with feedback."
    else
        echo "Skipped. See README.md for manual .desktop file creation."
    fi
    echo
fi

# Ask about passwordless sudo setup
if [ -f "$SCRIPT_DIR/setup-passwordless-sudo.sh" ]; then
    echo "For seamless tablet mode operation (no password prompts for hw disable/enable):"
    read -p "Set up passwordless sudo for input device control? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Running passwordless sudo setup..."
        "$SCRIPT_DIR/setup-passwordless-sudo.sh"
    else
        echo "Skipped. You can run './setup-passwordless-sudo.sh' later."
    fi
    echo
fi

echo
echo "Installation complete!"