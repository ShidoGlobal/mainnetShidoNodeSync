# Sync Mainnet shido node

This repository contains a script for setting up a node on shido blockchain. 

## Installation

Prerequisites:

System Requirements:
    4 or more physical CPU cores.
    At least 200GB disk storage.
    At least 16GB of memory (RAM)
    At least 100mbps network bandwidth.


#### Clone this repo using:
```bash
git clone 'repourl'

```
## Setup a node first:

open a terminal window and run the following command
[Verify permission of that file]
```bash
./shido_ubuntu_node.sh (it's for ubuntu os)
```

**NOTE:** The blockchain syncing is running in a background as a service you can print the logs and check the logs of the node with the following command.
```bash
journalctl -u shido -f (it's for ubuntu)
```


