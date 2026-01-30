# Shido Mainnet Node

A comprehensive setup script for deploying and synchronizing a Shido blockchain mainnet node on Ubuntu systems.

## Table of Contents

- [Shido Mainnet Node](#shido-mainnet-node)
  - [Table of Contents](#table-of-contents)
  - [Overview](#overview)
  - [Prerequisites](#prerequisites)
    - [System Requirements](#system-requirements)
    - [Dependencies](#dependencies)
  - [Installation](#installation)
  - [Usage](#usage)
    - [Starting the Node](#starting-the-node)
  - [Monitoring](#monitoring)
    - [View Real-time Logs](#view-real-time-logs)
    - [Check Service Status](#check-service-status)
  - [Files](#files)
  - [Contributing](#contributing)
  - [License](#license)

## Overview

This repository provides automated scripts to set up a Shido blockchain node for mainnet synchronization. The setup includes Go installation, node configuration, and service management for continuous operation.

## Prerequisites

### System Requirements

- **Operating System**: Ubuntu (tested and supported)
- **CPU**: 4 or more physical CPU cores
- **Storage**: At least 200GB available disk space
- **Memory**: Minimum 16GB RAM
- **Network**: At least 100 Mbps bandwidth
- **Permissions**: Root or sudo access

### Dependencies

The installation script will automatically handle the following dependencies:
- Go programming language
- Required blockchain binaries
- System service configuration

## Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/ShidoGlobal/mainnetShidoNodeSync.git
   cd mainnetShidoNodeSync
   ```

2. **Make the script executable**
   ```bash
   chmod +x shido_ubuntu_node.sh
   chmod +x install-go.sh
   ```

3. **Run the installation script**
   ```bash
   ./install-go.sh
   ./shido_ubuntu_node.sh
   ```

## Usage

### Starting the Node

The node runs as a systemd service and starts automatically after installation. To manually control the service:

```bash
# Start the service
sudo systemctl start shidochain.service

# Stop the service
sudo systemctl stop shidochain.service

# Restart the service
sudo systemctl restart shidochain.service

# Enable auto-start on boot
sudo systemctl enable shidochain.service
```

## Monitoring

### View Real-time Logs

Monitor the node synchronization progress and status:

```bash
# Follow live logs
journalctl -u shidochain.service -f

# View recent logs
journalctl -u shidochain.service -n 100

# View logs from specific time
journalctl -u shidochain.service --since "1 hour ago"
```

### Check Service Status

```bash
sudo systemctl status shidochain.service
```

## Files

- `shido_ubuntu_node.sh` - Main installation and setup script for Ubuntu
- `install-go.sh` - Go programming language installation script
- `genesis.json` - Genesis block configuration for the Shido mainnet
- `.gitignore` - Git ignore rules for the repository

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**Note**: The blockchain synchronization process runs in the background as a system service. Initial sync may take several hours depending on your network connection and system specifications.


