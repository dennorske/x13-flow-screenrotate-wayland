#!/usr/bin/env bash
#
# Uninstallation script for Auto Screen Rotation Service
#

set -euo pipefail

SERVICE_NAME="autoscreenrotation.service"
USER_SERVICE_DIR="$HOME/.config/systemd/user"
SERVICE_FILE="$USER_SERVICE_DIR/$SERVICE_NAME"

echo "=== Auto Screen Rotation Service Uninstallation ==="
echo

# Stop and disable the service
if systemctl --user is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
    echo "Stopping service..."
    systemctl --user stop "$SERVICE_NAME"
fi

if systemctl --user is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
    echo "Disabling service..."
    systemctl --user disable "$SERVICE_NAME"
fi

# Remove service file
if [ -f "$SERVICE_FILE" ]; then
    echo "Removing service file..."
    rm -f "$SERVICE_FILE"
fi

# Reload systemd
systemctl --user daemon-reload

echo
echo "Auto screen rotation service has been uninstalled."
echo

# Ask about removing desktop file
DESKTOP_FILE="$HOME/.local/share/applications/toggle-tablet-mode.desktop"
if [ -f "$DESKTOP_FILE" ]; then
    echo "Found desktop file for tablet mode toggle."
    read -p "Remove desktop file? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -f "$DESKTOP_FILE"
        # Update desktop database if available
        if command -v update-desktop-database >/dev/null 2>&1; then
            update-desktop-database ~/.local/share/applications
        fi
        echo "✅ Desktop file removed."
    else
        echo "Desktop file preserved: $DESKTOP_FILE"
    fi
    echo
fi

# Ask about removing sudoers file
SUDOERS_FILE="/etc/sudoers.d/tablet-mode-scripts"
if [ -f "$SUDOERS_FILE" ]; then
    echo "Found passwordless sudo configuration for tablet mode scripts."
    read -p "Remove sudoers configuration? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo rm -f "$SUDOERS_FILE"
        echo "✅ Sudoers configuration removed."
    else
        echo "Sudoers configuration preserved: $SUDOERS_FILE"
    fi
    echo
fi

echo "Note: Configuration files in ~/.config/ have been preserved."
echo "To remove them manually:"
echo "  rm ~/.config/autoscreenrotate"
echo "  rm ~/.config/disableinput"
echo
echo "Uninstallation complete!"