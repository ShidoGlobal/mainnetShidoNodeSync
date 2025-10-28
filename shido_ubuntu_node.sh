#!/bin/bash

# Exit on error
set -e

# Function to print error messages
print_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

# Function to print status messages
print_status() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Function to print warning messages
print_warning() {
    echo "[WARNING] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

current_path="$(pwd)"

# Install Go dependencies
bash "$current_path/install-go.sh" || print_error "Failed to install Go dependencies"

# Source bashrc and set ulimit
source "$HOME/.bashrc" || print_error "Failed to source bashrc"
ulimit -n 16384 || print_error "Failed to set ulimit"

print_status "Installing cosmovisor..."
go install cosmossdk.io/tools/cosmovisor/cmd/cosmovisor@v1.5.0 || print_error "Failed to install cosmovisor"

# Get OS and version
OS=$(awk -F '=' '/^NAME/{print $2}' /etc/os-release | awk '{print $1}' | tr -d '"')
VERSION=$(awk -F '=' '/^VERSION_ID/{print $2}' /etc/os-release | awk '{print $1}' | tr -d '"')

# Define the binary and installation paths
BINARY="shidod"
INSTALL_PATH="/usr/local/bin/"

# Check if the OS is Ubuntu and the version is either 20.04 or 22.04
# Check if the OS is Ubuntu and the version is either 20.04 or 22.04
if [ "$OS" = "Ubuntu" ] && { [ "$VERSION" = "20.04" ] || [ "$VERSION" = "22.04" ]; }; then
    print_status "Starting installation for Ubuntu $VERSION..."
    print_status "Binary: $BINARY"
    print_status "Install path: $INSTALL_PATH"
    print_status "Downloading shidod binary for Ubuntu $VERSION..."
    
    # Download the binary
    DOWNLOAD_URL="https://github.com/ShidoGlobal/shido-upgrade-v3.2.0/releases/download/ubuntu${VERSION}/shidod"
    print_status "Download URL: $DOWNLOAD_URL"
    
    # Remove existing binary if present
    if [ -f "$BINARY" ]; then
        rm -f "$BINARY"
    fi
    
    # Download with error checking
    if command -v wget >/dev/null 2>&1; then
        wget "$DOWNLOAD_URL" -O "$BINARY"
    elif command -v curl >/dev/null 2>&1; then
        curl -L "$DOWNLOAD_URL" -o "$BINARY"
    else
        print_error "Neither wget nor curl is installed. Please install one of them."
        exit 1
    fi
    
    # Verify download
    if [ ! -f "$BINARY" ]; then
        print_error "Failed to download binary"
        exit 1
    fi
    
    # Make the binary executable
    chmod +x "$BINARY"
    
    # Verify binary works
    if ./"$BINARY" version >/dev/null 2>&1; then
        print_status "Binary downloaded and verified successfully"
    else
        print_warning "Binary downloaded but version check failed"
    fi
  
  current_path=$(pwd)
  
  # Update package lists and install necessary packages
  print_status "Installing system dependencies..."
  sudo apt-get update -y || print_error "Failed to update package lists"
  sudo apt-get install -y build-essential jq wget unzip || print_error "Failed to install dependencies"
  
  # Check if the installation path exists
  if [ -d "$INSTALL_PATH" ]; then
    sudo  cp "$current_path/$BINARY" "$INSTALL_PATH" && sudo chmod +x "${INSTALL_PATH}${BINARY}"
    echo "$BINARY installed or updated successfully!"
  else
    echo "Installation path $INSTALL_PATH does not exist. Please create it."
    exit 1
  fi
else
  echo "Please check the OS version support; at this time, only Ubuntu 20.04 and 22.04 are supported."
  exit 1
fi

print_status "Installing WASMVM library..."

# Remove existing WASMVM library
if [ -f "/usr/lib/libwasmvm.x86_64.so" ]; then
    print_status "Removing existing WASMVM library..."
    sudo rm /usr/lib/libwasmvm.x86_64.so || print_error "Failed to remove existing WASMVM library"
fi

# Download WASMVM library
print_status "Downloading WASMVM library v2.1.4..."
sudo wget -O /usr/lib/libwasmvm.x86_64.so https://github.com/CosmWasm/wasmvm/releases/download/v2.1.4/libwasmvm.x86_64.so \
    || print_error "Failed to download WASMVM library"

# Update library cache
print_status "Updating library cache..."
sudo ldconfig || print_error "Failed to update library cache"

# Verify installation
if [ -f "/usr/lib/libwasmvm.x86_64.so" ]; then
    print_status "WASMVM library installed successfully"
else
    print_error "WASMVM library installation failed"
fi
#==========================================================================================================================================
KEYS="glen"
CHAINID="shido_9008-1"
KEYRING="os"
MONIKER="AlphaValidator"
KEYALGO="eth_secp256k1"
LOGLEVEL="info"

# Set dedicated home directory for the shidod instance
 HOMEDIR="/data/.tmp-shidod"

# Path variables
CONFIG=$HOMEDIR/config/config.toml
APP_TOML=$HOMEDIR/config/app.toml
CLIENT=$HOMEDIR/config/client.toml
GENESIS=$HOMEDIR/config/genesis.json
TMP_GENESIS=$HOMEDIR/config/tmp_genesis.json

# validate dependencies are installed
command -v jq >/dev/null 2>&1 || {
	echo >&2 "jq not installed. More info: https://stedolan.github.io/jq/download/"
	exit 1
}

# used to exit on first error
set -e

# User prompt if an existing local node configuration is found.
if [ -d "$HOMEDIR" ]; then
	printf "\nAn existing folder at '%s' was found. You can choose to delete this folder and start a new local node with new keys from genesis. When declined, the existing local node is started. \n" "$HOMEDIR"
	echo "Overwrite the existing configuration and start a new local node? [y/n]"
	read -r overwrite
else
	overwrite="Y"
fi

# Setup local node if overwrite is set to Yes, otherwise skip setup
if [[ $overwrite == "y" || $overwrite == "Y" ]]; then
	# Remove the previous folder
	file_path="/etc/systemd/system/shidochain.service"

# Check if the file exists
if [ -e "$file_path" ]; then
sudo systemctl stop shidochain.service
    echo "The file $file_path exists."
fi
	sudo rm -rf "$HOMEDIR"

	# Set client config
	shidod config set client chain-id "$CHAINID" --home "$HOMEDIR"
	shidod config set client keyring-backend "$KEYRING" --home "$HOMEDIR"
    echo "===========================Copy these keys with mnemonics and save it in safe place ==================================="
	shidod keys add $KEYS --keyring-backend $KEYRING --algo $KEYALGO --home "$HOMEDIR"
	echo "========================================================================================================================"
	echo "========================================================================================================================"
	shidod init $MONIKER -o --chain-id $CHAINID --home "$HOMEDIR"


	#changes status in app,config files
    sed -i 's/timeout_commit = "3s"/timeout_commit = "1s"/g' "$CONFIG"
    sed -i 's/pruning = "default"/pruning = "custom"/g' "$APP_TOML"
    sed -i 's/pruning-keep-recent = "0"/pruning-keep-recent = "100000"/g' "$APP_TOML"
    sed -i 's/pruning-interval = "0"/pruning-interval = "100"/g' "$APP_TOML"
    sed -i 's/seeds = ""/seeds = ""/g' "$CONFIG"
    sed -i 's/prometheus = false/prometheus = true/' "$CONFIG"
    sed -i 's/experimental_websocket_write_buffer_size = 200/experimental_websocket_write_buffer_size = 600/' "$CONFIG"
    sed -i 's/prometheus-retention-time  = "0"/prometheus-retention-time  = "1000000000000"/g' "$APP_TOML"
    sed -i 's/enabled = false/enabled = true/g' "$APP_TOML"
    sed -i 's/minimum-gas-prices = "0shido"/minimum-gas-prices = "0.25shido"/g' "$APP_TOML"
    sed -i 's/enable = false/enable = true/g' "$APP_TOML"
    sed -i 's/swagger = false/swagger = true/g' "$APP_TOML"
    sed -i 's/enabled-unsafe-cors = false/enabled-unsafe-cors = true/g' "$APP_TOML"
    sed -i 's/enable-unsafe-cors = false/enable-unsafe-cors = true/g' "$APP_TOML"
        sed -i '/\[rosetta\]/,/^\[.*\]/ s/enable = true/enable = false/' "$APP_TOML"
	sed -i 's/localhost/0.0.0.0/g' "$APP_TOML"
    sed -i 's/localhost/0.0.0.0/g' "$CONFIG"
    sed -i 's/:26660/0.0.0.0:26660/g' "$CONFIG"
    sed -i 's/localhost/0.0.0.0/g' "$CLIENT"
    sed -i 's/127.0.0.1/0.0.0.0/g' "$APP_TOML"
    sed -i 's/127.0.0.1/0.0.0.0/g' "$CONFIG"
    sed -i 's/127.0.0.1/0.0.0.0/g' "$CLIENT"
    sed -i 's/\[\]/["*"]/g' "$CONFIG"
	sed -i 's/\["\*",\]/["*"]/g' "$CONFIG"
  
#   sed -i 's/enable = false/enable = true/g' "$CONFIG"
# 	 sed -i 's/rpc_servers \s*=\s* ""/rpc_servers = "https:\/\/rpc.mavnode.io:443,https:\/\/rpc.shidoscan.net:443,https:\/\/tendermint.shidoscan.com:443"/g' "$CONFIG"
#    sed -i 's/trust_hash \s*=\s* ""/trust_hash = "5477A86CF04560DFB4A8F163F8A39396307846EC6C6B6BC171C3FEFF8EE620F8"/g' "$CONFIG"
sed -i 's/trust_height = 0/trust_height = 21776000/g' "$CONFIG"
sed -i 's/trust_period = "112h0m0s"/trust_period = "168h0m0s"/g' "$CONFIG"
sed -i 's/flush_throttle_timeout = "100ms"/flush_throttle_timeout = "10ms"/g' "$CONFIG"
sed -i 's/peer_gossip_sleep_duration = "100ms"/peer_gossip_sleep_duration = "10ms"/g' "$CONFIG"

	# these are some of the node ids help to sync the node with p2p connections
	 sed -i 's/persistent_peers \s*=\s* ""/persistent_peers = "bc09b4d678127976fa5c110bbb56858b1a347e08@65.21.141.41:26656,59a7eef026f75180765bac5a90293a0686e14f4e@65.108.232.180:28656,8bc3477040ab7ef9b0635fc2cb1ea46845cc2f93@65.109.115.195:26656,9b9dee928a174bcd0272be9127f5f455d418d6b2@169.0.36.222:26656,e9207104d4cd85a18097fe07eec646a4660f9815@88.99.147.241:26656,0bfc540907ef1ea08a70dacd12e8f12d887137d5@45.149.204.240:26656,523b25de11811eb9fa244102c98e1cebb433d93d@45.90.122.47:26656,9175d479359850dbfc692a01ddf3b6d9b85e66e0@45.159.221.133:26656,93d223146fed882e85c3768ea44845932df483ad@45.90.121.111:26656,42c67bc5d7813fe273d43208400194e7a8bb81a0@85.190.246.81:26656,84e5eb203666cb8167953bc61821b9bb633c19b5@178.162.198.204:26656,ab897953413fd07d3c75f854d3d326e1495b0386@167.86.124.38:26656,f91156c7370f50f1535ad05c691a325683778f8e@194.163.157.130:26656,b9c6d2efe500520be2f2580f71c4e219ab1de318@144.91.89.229:26656,cf7e57f6714275d7d28ba1bc81be2c47dfa23a41@173.212.196.235:26656,cc3625aaeb99ffcc4209cf68d4a5821eb3787ebe@49.0.207.158:26656,a82689a87eb31c1cd818bd07a11a833ab728b089@162.216.113.26:26656,0becc9e6de1c50bce7285a7f40e9b33f776e524f@154.12.228.46:26656,da0f97e10794e3154577c449f51448391ca6f5c2@119.8.162.212:26656,b89314600b61d9e933b7e7a3fbacf36cba079842@166.108.233.54:26656,1aa98da1d98341682ac0b3be83397862a6a9b63e@111.119.195.49:26656,cf6fa73d0de03edf1fee9ea37dd701138831746c@124.243.138.199:26656,60231be20d2b7db49262f41806bccdfae4743a5c@65.109.57.221:28656,e54176379eaec1ff90d57ee739daf95a7baa85c0@45.10.163.234:26656,d457e45a34167e6280204e50eca332e2dae1305f@38.242.226.17:26656,c0ec2b52346085e60ee73f3ae82ede3f8fb61c61@52.193.158.166:26656,0ba0f738aa691a9fc0f629f46828d067dd712f49@166.108.226.54:26656,952519d26301b2b6ec00bdcef83c34f845efba1f@190.92.216.122:26656,b20be5ff9a0575a1a267d6b61370316eb7bbdb3a@89.117.57.35:26656,084df0241f9553c37480ccc36466ceaf568530f6@97.91.90.171:26656,bf58ad2521e9f2a00b8b954a872d6b58805d57c2@178.18.249.66:26656,89b7d60f306e163efcebe3883bd618ba7f886c30@37.187.93.177:26686,3a49ee1135b4c0cc52a69dc21129583eb9302f9f@167.235.2.101:26656,dbf4d33314f521e2bf153591d0ccbe9f80f7d4dd@84.16.248.143:26656,0a5ea964ab71f2651687eebd55cdc122f3b3e4a3@18.178.17.86:26656,e53cb10029b52042cd962d6414c60faeb1054b03@51.75.146.180:26656,78e1dcc4f884426ea15c6f5367087862c79ad475@195.26.252.72:26656,ec900135187b3148c177957207e0cdd363f7da71@178.63.12.190:26656,8195144d794325ebd3adcfc50ee951e37ab3cc1d@110.238.109.15:26656,06a108e96c8b1018ecf62a5b669661da1cbfa496@188.239.47.206:26656,03559e74aa9bed98789563518c787a71e837ca03@65.108.228.209:28656,3bed49649bbd852c49cf697c82f7f47ae1943fe2@111.119.249.233:26656,95d38cedefe4068c900dd9711b54a821e80101eb@13.114.137.89:26656,00dc45f439d9e42853c69f7cf6265ad45741f5e8@91.98.115.118:32656"/g' "$CONFIG"

	# remove the genesis file from binary
	 rm -rf $HOMEDIR/config/genesis.json

	# paste the genesis file
	 cp $current_path/genesis.json $HOMEDIR/config

	# Run this to ensure everything worked and that the genesis file is setup correctly
	# shidod validate-genesis --home "$HOMEDIR"

	echo "export DAEMON_NAME=shidod" >> ~/.profile
    echo "export DAEMON_HOME="$HOMEDIR"" >> ~/.profile
    source ~/.profile
    echo $DAEMON_HOME
    echo $DAEMON_NAME

	cosmovisor init "${INSTALL_PATH}${BINARY}"

	
	TENDERMINTPUBKEY=$(shidod tendermint show-validator --home $HOMEDIR | grep "key" | cut -c12-)
	NodeId=$(shidod tendermint show-node-id --home $HOMEDIR --keyring-backend $KEYRING)
	BECH32ADDRESS=$(shidod keys show ${KEYS} --home $HOMEDIR --keyring-backend $KEYRING| grep "address" | cut -c12-)

	echo "========================================================================================================================"
	echo "tendermint Key==== "$TENDERMINTPUBKEY
	echo "BECH32Address==== "$BECH32ADDRESS
	echo "NodeId ===" $NodeId
	echo "========================================================================================================================"

fi

#========================================================================================================================================================
sudo su -c  "echo '[Unit]
Description=Shido Node
Wants=network-online.target
After=network-online.target
[Service]
User=$(whoami)
Group=$(whoami)
Type=simple
ExecStart=$(which cosmovisor) run start --home $DAEMON_HOME
Restart=always
RestartSec=3
LimitNOFILE=4096
Environment="DAEMON_NAME=shidod"
Environment="DAEMON_HOME="$HOMEDIR""
Environment="DAEMON_ALLOW_DOWNLOAD_BINARIES=false"
Environment="DAEMON_RESTART_AFTER_UPGRADE=true"
Environment="DAEMON_LOG_BUFFER_SIZE=512"
Environment="UNSAFE_SKIP_BACKUP=false"
[Install]
WantedBy=multi-user.target'> /etc/systemd/system/shidochain.service"

sudo systemctl daemon-reload
sudo systemctl enable shidochain.service
sudo systemctl start shidochain.service
