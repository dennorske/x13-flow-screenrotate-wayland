# File Structure

## Core Scripts

### Main System Scripts
- **`autoscreenrotation.sh`** - Main daemon service for automatic screen rotation
- **`screenrotation.sh`** - Manual screen rotation control script
- **`autoscreenrotation.service`** - Systemd service configuration

### Input Device Management
- **`disableInput.sh`** - Disable internal keyboard and touchpad (tablet mode)
- **`enableInput.sh`** - Re-enable internal keyboard and touchpad (laptop mode)  
- **`toggleInput.sh`** - Smart toggle between tablet/laptop modes

### Setup and Management
- **`install.sh`** - Installation script for systemd service
- **`uninstall.sh`** - Removal script for systemd service
- **`setup-passwordless-sudo.sh`** - Configure passwordless sudo for .desktop file compatibility

## Documentation
- **`readme.md`** - Complete project documentation and usage instructions
- **`FILES.md`** - Project structure reference

## Usage Workflow

1. **Installation**: Run `./install.sh` to set up the systemd service
2. **Quality of Life**: Run `./setup-passwordless-sudo.sh` for seamless .desktop operation
3. **Tablet Mode**: Use `./toggleInput.sh` or create .desktop shortcuts for touch access
4. **Manual Control**: Use `./screenrotation.sh` for direct rotation commands
5. **Uninstallation**: Run `./uninstall.sh` to remove the service

## File Dependencies

```
autoscreenrotation.service → autoscreenrotation.sh → screenrotation.sh
toggleInput.sh → {disableInput.sh, enableInput.sh}
install.sh → autoscreenrotation.service
setup-passwordless-sudo.sh → {disableInput.sh, enableInput.sh, toggleInput.sh}
```