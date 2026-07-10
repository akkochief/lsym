# LSYM - Linux System Management Center

<div align="center">

**The Ultimate All-in-One Linux System Administration Tool**

[![Version](https://img.shields.io/badge/version-3.0-blue.svg)](https://github.com/yourusername/lsym)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Bash](https://img.shields.io/badge/bash-4.0+-yellow.svg)](https://www.gnu.org/software/bash/)
[![Dialog](https://img.shields.io/badge/dialog-required-orange.svg)](https://invisible-island.net/dialog/)
[![Platform](https://img.shields.io/badge/platform-Linux-lightgrey.svg)](https://www.linux.org/)

</div>

---

## Table of Contents
- [Overview](#overview)
- [Features](#features)
- [Screenshots](#screenshots)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Modules](#modules)
- [Configuration](#configuration)
- [Requirements](#requirements)
- [Usage Guide](#usage-guide)
- [FAQ](#faq)
- [Contributing](#contributing)
- [License](#license)

---

## Overview

**LSYM (Linux System Management Center)** is a powerful, terminal-based system administration tool that transforms complex Linux management tasks into an intuitive menu-driven interface.

Inspired by Windows' `diskpart` but infinitely more powerful, LSYM provides a unified interface for managing every aspect of your Linux system - from disk partitioning to network configuration, user management to system monitoring.

**Key Philosophy:** *"Everything in one place, every action with confidence"*

---

## Features

### System Information
- Complete system overview with hardware inventory
- CPU, memory, and hardware details
- Temperature monitoring and system benchmarks

### Disk Management (diskpart+++)
- List all disks and partitions with detailed information
- Create, delete, and format partitions
- Mount/Unmount file systems
- Disk cloning and imaging (with compression)
- LVM (Logical Volume Management) support
- RAID 0/1/5/10 management
- Disk encryption (LUKS)
- SMART health monitoring
- Secure erase functionality

### Network Management
- Interface configuration (static/DHCP)
- WiFi management (scan, connect, hotspot)
- DNS management
- Routing table management
- VPN support (OpenVPN/WireGuard)
- Port forwarding (iptables/nftables)
- Network scanning and speed testing

### User Management
- User and group creation/deletion
- Password management
- Sudo access control
- Disk quotas
- SSH key management
- User modification

### Service & Process Management
- systemd service control (start/stop/restart)
- Service enable/disable
- Process monitoring and killing
- Process priority management
- System resource monitoring

### Package Management
- Multi-distro support (APT, DNF, YUM, Pacman, Zypper, APK)
- Package search, install, remove, purge
- System upgrade and distribution upgrade
- Repository management
- Broken package fixing

### Security & Firewall
- UFW/iptables/nftables management
- Port scanning and vulnerability checks
- SSL certificate checking
- Password policy enforcement
- SSH security hardening
- Failed login monitoring
- System auditing (Lynis integration)
- Malware scanning (ClamAV)

### Backup & Maintenance
- Full system backup
- Home directory backup
- Database backup (MySQL/PostgreSQL)
- Scheduled backups with cron
- Backup encryption and compression
- System cleanup
- Log rotation
- Temp file management

### Monitoring & Alerts
- Real-time system dashboard
- CPU, memory, disk, network monitoring
- Resource threshold alerts
- Performance graphs (ASCII)
- Activity reports
- Alert history with email notifications

---

## Screenshots

```
+------------------------------------------------------------------+
| LSYM - Linux System Management Center v3.0                      |
|                                                                  |
|                    MAIN MENU                                    |
|                                                                  |
|   1. System Information                                         |
|   2. Disk Management (diskpart+++)                              |
|   3. Network Management                                         |
|   4. User & Group Management                                    |
|   5. Service & Process Management                               |
|   6. Package Management                                         |
|   7. Security & Firewall                                        |
|   8. Backup & Maintenance                                       |
|   9. System Monitoring & Alerts                                 |
|   0. Exit                                                       |
|                                                                  |
|   [Select]  [Cancel]                                            |
+------------------------------------------------------------------+
```

---

## Installation

### One-Line Installation
```bash
git clone https://github.com/yourusername/lsym.git && cd lsym && chmod +x lsym.sh modules/*.sh && ./lsym.sh
```

### Manual Installation
```bash
# 1. Clone the repository
git clone https://github.com/yourusername/lsym.git
cd lsym

# 2. Make scripts executable
chmod +x lsym.sh modules/*.sh

# 3. Run the application
./lsym.sh
```

### System-wide Installation
```bash
# Install to /usr/local/bin
sudo cp lsym.sh /usr/local/bin/lsym
sudo cp -r modules /usr/local/share/lsym/
sudo cp config.conf /usr/local/share/lsym/

# Create alias
echo 'alias lsym="sudo /usr/local/bin/lsym"' >> ~/.bashrc
source ~/.bashrc
```

---

## Quick Start

```bash
# Run as normal user (sudo will be prompted when needed)
./lsym.sh

# Or run with root privileges
sudo ./lsym.sh

# For first-time use, ensure 'dialog' is installed
# (The script will attempt to install it automatically)
```

---

## Modules

| Module | File | Description |
|--------|------|-------------|
| System Information | `system.sh` | Complete system and hardware information |
| Disk Management | `disk.sh` | Advanced disk and partition management |
| Network Management | `network.sh` | Full network configuration and monitoring |
| User Management | `user.sh` | User and group administration |
| Service Management | `service.sh` | Service and process control |
| Package Management | `package.sh` | Multi-distro package management |
| Security | `security.sh` | Firewall, security, and auditing |
| Backup | `backup.sh` | Backup and system maintenance |
| Monitoring | `monitor.sh` | System monitoring and alerts |

---

## Configuration

### Configuration File (`config.conf`)

LSYM uses a centralized configuration file for all settings:

```bash
# General Settings
APP_NAME="LSYM - Linux System Management Center"
LOG_FILE="/tmp/lsym.log"
BACKUP_PATH="/var/backups/lsym"

# Alert Thresholds
CPU_LOAD_THRESHOLD=5.0
MEMORY_THRESHOLD=90
DISK_THRESHOLD=85

# Backup Settings
BACKUP_COMPRESSION="gzip"
BACKUP_ENCRYPT="no"
BACKUP_RETENTION_DAYS=30

# Security Settings
PASSWORD_MIN_LENGTH=8
ALLOW_SSH_ANY="no"
```

### Environment Variables
```bash
# Override settings at runtime
export BACKUP_PATH="/custom/backup/path"
export CPU_LOAD_THRESHOLD=3.0
./lsym.sh
```

---

## Requirements

### System Requirements
- Linux distribution (Ubuntu, Debian, Fedora, RHEL, Arch, openSUSE, etc.)
- Bash 4.0 or higher
- `dialog` (automatically installed if missing)

### Recommended Packages
```bash
# Debian/Ubuntu
sudo apt install dialog sysstat lm-sensors smartmontools nmap ufw

# Fedora/RHEL
sudo dnf install dialog sysstat lm_sensors smartmontools nmap ufw

# Arch Linux
sudo pacman -S dialog sysstat lm_sensors smartmontools nmap ufw
```

### Optional Packages for Enhanced Features
| Feature | Package |
|---------|---------|
| Temperature monitoring | `lm-sensors` |
| Disk SMART data | `smartmontools` |
| Disk I/O statistics | `sysstat` |
| Network scanning | `nmap` |
| Firewall | `ufw` |
| WiFi management | `network-manager` |
| VPN | `openvpn`, `wireguard` |
| Malware scanning | `clamav` |
| System auditing | `lynis` |
| Speed testing | `speedtest-cli` |

---

## Usage Guide

### Navigation
- **Arrow keys** - Navigate menus
- **Enter** - Select/confirm
- **Tab** - Switch between buttons
- **Space** - Toggle options
- **ESC** - Cancel/go back
- **Ctrl+C** - Exit program

### Module Navigation
```
Main Menu -> Select Module -> Sub-menu -> Select Action -> Confirm -> Results
```

### Common Tasks

#### 1. Check System Health
```
Main Menu -> 1 (System Information) -> 1 (Complete System Overview)
```

#### 2. Manage Disks
```
Main Menu -> 2 (Disk Management) -> 1 (List All Disks)
Main Menu -> 2 (Disk Management) -> 2 (Create Partition)
```

#### 3. Configure Network
```
Main Menu -> 3 (Network Management) -> 4 (Configure Static IP)
Main Menu -> 3 (Network Management) -> 6 (DNS Management)
```

#### 4. Create User
```
Main Menu -> 4 (User Management) -> 3 (Create New User)
```

#### 5. Install Packages
```
Main Menu -> 6 (Package Management) -> 4 (Install Package)
```

#### 6. Backup System
```
Main Menu -> 8 (Backup & Maintenance) -> 1 (Create Backup)
Main Menu -> 8 (Backup & Maintenance) -> 6 (System Backup)
```

#### 7. Monitor Performance
```
Main Menu -> 9 (Monitoring) -> 1 (System Dashboard)
Main Menu -> 9 (Monitoring) -> 8 (Resource Alerts)
```

---

## FAQ

### Q: What is the difference between LSYM and Windows diskpart?
**A:** While diskpart only manages disks and partitions, LSYM provides a complete system management interface including network, users, services, packages, security, backups, and monitoring - all in one unified tool.

### Q: Do I need root privileges?
**A:** Some operations require root access. The script will prompt for sudo when needed. You can run with `sudo ./lsym.sh` for full access.

### Q: Which distributions are supported?
**A:** All major Linux distributions including Ubuntu, Debian, Fedora, RHEL, CentOS, Arch Linux, openSUSE, and more.

### Q: Can I use this on a server?
**A:** Yes! LSYM is perfect for server administration. It's lightweight, doesn't require a GUI, and works over SSH.

### Q: How do I backup my settings?
**A:** The configuration file (`config.conf`) contains all settings. Backup this file along with your regular backups.

### Q: Is it safe to use?
**A:** LSYM includes confirmation prompts before destructive operations. However, always ensure you have backups before making major system changes.

### Q: How do I update LSYM?
**A:** Pull the latest version from git repository and replace the files.

### Q: Can I add custom modules?
**A:** Yes! LSYM is designed to be extensible. Add your custom scripts to the `modules/` directory and update the main menu.

---

## Contributing

Contributions are welcome! Here's how you can help:

1. **Report Bugs**: Open an issue with detailed steps to reproduce
2. **Suggest Features**: Share your ideas for new modules or improvements
3. **Submit Pull Requests**: Fix bugs or add new features
4. **Improve Documentation**: Help make the documentation better

### Development Setup
```bash
git clone https://github.com/yourusername/lsym.git
cd lsym
# Make your changes
./lsym.sh  # Test your changes
```

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## Support

- **Documentation**: [Wiki](https://github.com/yourusername/lsym/wiki)
- **Issues**: [GitHub Issues](https://github.com/yourusername/lsym/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/lsym/discussions)

---

## Acknowledgments

- Inspired by Windows diskpart utility
- Built with Bash and Dialog
- Thanks to all open-source contributors

---

## Star History

If you find this tool useful, please consider giving it a star on GitHub!

---

