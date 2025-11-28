# Automatic Screen Rotation for Wayland

This program provides automatic screen rotation for laptops with accelerometers, specifically optimized for Wayland/KDE environments. Originally written for the Lenovo Flex 5, it has been updated to work with ASUS ROG Flow X13 and other modern laptops.

## Features

- Automatic screen rotation based on device orientation
- Wayland/KDE compatibility using `kscreen-doctor`
- Systemd service integration for automatic startup
- Optional input device management (keyboard/touchpad disable when rotated)
- Robust error handling and logging
- Initial orientation detection on service start

## Requirements

### System Dependencies
- `iio-sensor-proxy` - for accelerometer data
- `kscreen-doctor` - for screen rotation on KDE/Wayland
- `jq` - for JSON parsing
- `systemd` - for service management

In order to disable keyboard+touchpad, you need to have sudo-permissions. Automatic rotation runs on user-level and does not need sudo.

### Installation of Dependencies

**Ubuntu/Debian:**
```bash
sudo apt install iio-sensor-proxy kde-cli-tools jq
```

**Arch Linux:**
```bash
sudo pacman -S iio-sensor-proxy kde-cli-tools jq
```

**Fedora:**
```bash
sudo dnf install iio-sensor-proxy kde-cli-tools jq
```

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/dennorske/x13-flow-screenrotate-wayland.git
   cd x13-flow-screenrotate-wayland
   ```

2. Run the installation script:
   ```bash
   ./install.sh
   ```

3. The service will be enabled and can be started immediately or will start at next login.

## Usage

### Automatic Mode (Recommended)
The systemd service runs automatically and rotates the screen based on device orientation.

**Service Management:**
```bash
# Start service
systemctl --user start autoscreenrotation.service

# Stop service
systemctl --user stop autoscreenrotation.service

# Check status
systemctl --user status autoscreenrotation.service

# View logs
journalctl --user -u autoscreenrotation.service -f
```

### Manual Rotation
For manual control, use the `screenrotation.sh` script:

```bash
# Basic rotations
./screenrotation.sh normal
./screenrotation.sh left
./screenrotation.sh right
./screenrotation.sh inverted

# Advanced rotations
./screenrotation.sh cycle_left    # Cycle through orientations
./screenrotation.sh cycle_right   # Cycle in reverse
./screenrotation.sh swap          # Toggle between normal/inverted or left/right
```

## Input Device Management

For tablet mode usage, you can manually disable/enable the internal keyboard and touchpad:

```bash
# Disable internal keyboard and touchpad (useful for tablet mode)
./disableInput.sh

# Re-enable internal keyboard and touchpad
./enableInput.sh

# Toggle between tablet/laptop mode (smart toggle)
./toggleInput.sh
```

### Touch-Friendly Tablet Mode Control

**Creating Panel/Taskbar Shortcuts for Touch Access:**

Since disabled keyboards cannot trigger their own re-enable commands, the recommended approach is to create **touch-accessible shortcuts** for tablet mode control.


**Creating Desktop Entries for Touch Access:**
```bash
# Create .desktop files for easy access
mkdir -p ~/.local/share/applications

# Toggle tablet mode (recommended)
cat > ~/.local/share/applications/toggle-tablet-mode.desktop << 'EOF'
[Desktop Entry]
Name=Toggle Tablet Mode
Comment=Toggle between tablet and laptop input modes  
Exec=/home/USERNAME/path/to/x13-flow-screenrotate-wayland/toggleInput.sh
Icon=input-tablet
Type=Application
Categories=System;
EOF
```

**Why Hardware Keys Don't Work:**
- **Fn+F10 limitation**: Once internal keyboard is disabled, it cannot send the key press to re-enable itself
- **Chicken-and-egg problem**: Disabled input devices cannot trigger their own re-activation  


### Quality of Life Improvement - Passwordless Sudo

For seamless .desktop file operation (no password prompts), run the included setup script:

```bash
./setup-passwordless-sudo.sh
```

This configures sudo to allow tablet mode scripts to run without password prompts, enabling:
- **Touch-friendly access** - .desktop file works without needing sudo password
- **No interruption** - No password dialogs during tablet mode switching
- **Secure configuration** - Principle of least privilege - it only interferes with the necessary commands that are needed to disable/enable hardware devices.
- **Easy removal** - Can be removed with `sudo rm /etc/sudoers.d/tablet-mode-scripts`

**Note**: This step is optional but highly recommended for the best user experience, especially coming out of tablet mode (e.g. re-enabling keyboard and touchpad).

## Configuration

Configuration files are stored in `~/.config/`:

- `~/.config/autoscreenrotate` - Enable/disable auto rotation (`true`/`false`)
- `~/.config/disableinput` - Enable/disable input management (`true`/`false`)

**Examples:**
```bash
# Disable auto rotation
echo "false" > ~/.config/autoscreenrotate

# Enable input device management (disable keyboard/touchpad when rotated)
echo "true" > ~/.config/disableinput
```

## Uninstallation

To remove the systemd service:

```bash
./uninstall.sh
```

## Troubleshooting

### Check if accelerometer is detected:
```bash
monitor-sensor
```

### Check current screen orientation:
```bash
kscreen-doctor -j | jq -r '.outputs[] | select(.name | startswith("eDP")) | .rotation'
```

### View service logs:
```bash
journalctl --user -u autoscreenrotation.service --since "1 hour ago"
```

### Common Issues

1. **Service fails to start**: Check that all dependencies are installed
2. **No rotation detected**: Ensure `iio-sensor-proxy` is running and accelerometer is supported
3. **Screen doesn't rotate**: Verify `kscreen-doctor` works manually

## Technical Details

- Uses `kscreen-doctor` instead of `xrandr` for Wayland compatibility
- Implements graceful error handling and automatic restarts
- Performs initial orientation check on startup
- Supports both X11 (legacy) and Wayland input device management
- Runs as a user service for proper session integration

## Original Credits

Originally written by Luca Leon Happel for the Lenovo Flex 5, adapted for ASUS ROG Flow X13 and modern Wayland systems.
