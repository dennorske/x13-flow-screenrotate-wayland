#!/usr/bin/env bash
#
# Setup passwordless sudo for tablet mode scripts
# This enables .desktop files to work without password prompts
#

set -euo pipefail

SUDOERS_FILE="/etc/sudoers.d/tablet-mode-scripts"

echo "Setting up passwordless sudo for tablet mode scripts..."

# Get the directory where this script is located (repository root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Create sudoers configuration with repository-relative paths
sudo tee "$SUDOERS_FILE" > /dev/null << EOF
# Tablet Mode Scripts - Passwordless sudo configuration
# This allows tablet mode toggle scripts to work from .desktop files
# Created by x13-flow-screenrotate-wayland project

# Allow execution of our specific tablet mode scripts
%sudo ALL=(ALL) NOPASSWD: $SCRIPT_DIR/disableInput.sh
%sudo ALL=(ALL) NOPASSWD: $SCRIPT_DIR/enableInput.sh
%sudo ALL=(ALL) NOPASSWD: $SCRIPT_DIR/toggleInput.sh
EOF

# Set proper permissions
sudo chmod 440 "$SUDOERS_FILE"

# Validate the sudoers file
if sudo visudo -c -f "$SUDOERS_FILE"; then
    echo "✅ Sudoers configuration created successfully: $SUDOERS_FILE"
    echo "Tablet mode scripts can now run without password prompts"
    echo ".desktop files will work seamlessly for touch access"
else
    echo "❌ Error: Invalid sudoers configuration"
    sudo rm -f "$SUDOERS_FILE"
    exit 1
fi

echo
echo "To remove this configuration later, run:"
echo "sudo rm $SUDOERS_FILE"