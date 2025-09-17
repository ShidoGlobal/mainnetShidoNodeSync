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
    DOWNLOAD_URL="https://github.com/ShidoGlobal/mainnet-enso-upgrade/releases/download/ubuntu${VERSION}/shidod"
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
  
  sed -i 's/enable = false/enable = true/g' "$CONFIG"
	 sed -i 's/rpc_servers \s*=\s* ""/rpc_servers = "https:\/\/rpc.mavnode.io:443,https:\/\/rpc.shidoscan.net:443,https:\/\/tendermint.shidoscan.com:443"/g' "$CONFIG"
   sed -i 's/trust_hash \s*=\s* ""/trust_hash = "5477A86CF04560DFB4A8F163F8A39396307846EC6C6B6BC171C3FEFF8EE620F8"/g' "$CONFIG"
sed -i 's/trust_height = 0/trust_height = 21776000/g' "$CONFIG"
sed -i 's/trust_period = "112h0m0s"/trust_period = "168h0m0s"/g' "$CONFIG"
sed -i 's/flush_throttle_timeout = "100ms"/flush_throttle_timeout = "10ms"/g' "$CONFIG"
sed -i 's/peer_gossip_sleep_duration = "100ms"/peer_gossip_sleep_duration = "10ms"/g' "$CONFIG"

	# these are some of the node ids help to sync the node with p2p connections
	 sed -i 's/persistent_peers \s*=\s* ""/persistent_peers = "f28f693053306fba8bf59c4a54b7bd9f89de7ebb@18.193.227.128:26656,0646ac59a824eeec751e0862e6af72c0f5d6bc55@35.159.179.17:26656,29f9c382e89affd49c4a9bb59cb0ad68347db014@18.159.173.214:26656,b69863dd6da9fa77a285f2d4e40f2cbffed1b54a@45.90.121.111:26656,248bd68031c5f144a976646c160db83dac0b9955@45.90.122.47:26656,e9207104d4cd85a18097fe07eec646a4660f9815@88.99.147.241:26656,42c67bc5d7813fe273d43208400194e7a8bb81a0@85.190.246.81:26656,d457e45a34167e6280204e50eca332e2dae1305f@38.242.226.17:26656,31b1c6b90c936ce43c9453ef9e19d39afc47bacc@65.109.112.34:28656,4d36c3dbf2f9f1ffc66f84133d0143f02dbb42ef@35.183.211.64:26656,89d62bf02b7f3205c90f31b4097b388eeddf7892@15.156.146.164:26656,cb8f8c6f813612a5b9844c0699490a583bc12d84@35.182.147.124:26656,0becc9e6de1c50bce7285a7f40e9b33f776e524f@154.12.228.46:26656,78e1dcc4f884426ea15c6f5367087862c79ad475@195.26.252.72:26656,057365f4c7a4c7fa7ba05423ec5744303a694b65@3.110.11.92:26656,64364788e1d74ff41e075902a780193116d3cf9b@15.156.158.51:26656,355cb9042c2c88f71640da4110a9d65f21084a79@18.184.249.140:26656,2d9782b8636b52a642346aace086c18555d15f0b@3.98.239.17:26656,9b9dee928a174bcd0272be9127f5f455d418d6b2@169.0.36.222:26656,a82689a87eb31c1cd818bd07a11a833ab728b089@162.216.113.26:26656,442a36e50bad68ef9818fe91555f6e3a134f0cef@45.159.221.133:26656,8c3931761e4e213f318b3cfff971a53ddde48029@65.109.156.11:28656,3a49ee1135b4c0cc52a69dc21129583eb9302f9f@167.235.2.101:26656,222b02cae1010ea7cce41a4a5f07bbf611115ff6@13.200.25.27:26656,e53cb10029b52042cd962d6414c60faeb1054b03@51.75.146.180:26656,dbf4d33314f521e2bf153591d0ccbe9f80f7d4dd@84.16.248.143:26656,8bc3477040ab7ef9b0635fc2cb1ea46845cc2f93@65.109.115.195:26656,89b7d60f306e163efcebe3883bd618ba7f886c30@37.187.93.177:26686,ec900135187b3148c177957207e0cdd363f7da71@178.63.12.190:26656,3d70fb431e8c3e44a6257cea73a3c7c2c64825f4@144.91.89.229:26656,cb54b644a17c59a0387297517d6e7e558d6a6924@91.98.115.118:29656,84e5eb203666cb8167953bc61821b9bb633c19b5@178.162.198.204:26656,a78a17dde86e111bb53437528d50a808d9bb6c64@81.17.103.4:26656"/g' "$CONFIG"

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
