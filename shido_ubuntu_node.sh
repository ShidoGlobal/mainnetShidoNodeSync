#!/bin/bash

# Check if the script is run as root
#if [ "$(id -u)" != "0" ]; then
#  echo "This script must be run as root or with sudo." 1>&2
#  exit 1
#fi
current_path=$(pwd)
bash  $current_path/install-go.sh 

source $HOME/.bashrc
ulimit -n 16384

go install cosmossdk.io/tools/cosmovisor/cmd/cosmovisor@v1.5.0

# Get OS and version
OS=$(awk -F '=' '/^NAME/{print $2}' /etc/os-release | awk '{print $1}' | tr -d '"')
VERSION=$(awk -F '=' '/^VERSION_ID/{print $2}' /etc/os-release | awk '{print $1}' | tr -d '"')

# Define the binary and installation paths
BINARY="shidod"
INSTALL_PATH="/usr/local/bin/"

# Check if the OS is Ubuntu and the version is either 20.04 or 22.04
if [ "$OS" == "Ubuntu" ] && [ "$VERSION" == "20.04" -o "$VERSION" == "22.04" ]; then
  # Copy and set executable permissions
  current_path=$(pwd)
  
  # Update package lists and install necessary packages
  sudo  apt-get update
  sudo apt-get install -y build-essential jq wget unzip
  
  # Check if the installation path exists
  if [ -d "$INSTALL_PATH" ]; then
  sudo  cp "$current_path/ubuntu${VERSION}build/$BINARY" "$INSTALL_PATH" && sudo chmod +x "${INSTALL_PATH}${BINARY}"
    echo "$BINARY installed or updated successfully!"
  else
    echo "Installation path $INSTALL_PATH does not exist. Please create it."
    exit 1
  fi
else
  echo "Please check the OS version support; at this time, only Ubuntu 20.04 and 22.04 are supported."
  exit 1
fi

sudo cp $current_path/libwasmvm.x86_64.so /usr/lib
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
	shidod config keyring-backend $KEYRING --home "$HOMEDIR"
	shidod config chain-id $CHAINID --home "$HOMEDIR"
    echo "===========================Copy these keys with mnemonics and save it in safe place ==================================="
	shidod keys add $KEYS --keyring-backend $KEYRING --algo $KEYALGO --home "$HOMEDIR"
	echo "========================================================================================================================"
	echo "========================================================================================================================"
	shidod init $MONIKER -o --chain-id $CHAINID --home "$HOMEDIR"

		# Change parameter token denominations to shido
	jq '.app_state["staking"]["params"]["bond_denom"]="shido"' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"
	jq '.app_state["crisis"]["constant_fee"]["denom"]="shido"' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"
	jq '.app_state["gov"]["deposit_params"]["min_deposit"][0]["denom"]="shido"' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"
	jq '.app_state["gov"]["params"]["min_deposit"][0]["denom"]="shido"' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"
	jq '.app_state["evm"]["params"]["evm_denom"]="shido"' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"
    jq '.app_state["mint"]["params"]["mint_denom"]="shido"' >"$TMP_GENESIS" "$GENESIS" && mv "$TMP_GENESIS" "$GENESIS"

	jq '.consensus_params["block"]["max_bytes"]="8388608"' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"
    jq '.app_state["mint"]["params"]["blocks_per_year"]="31536000"' >"$TMP_GENESIS" "$GENESIS" && mv "$TMP_GENESIS" "$GENESIS"
    jq '.app_state["mint"]["minter"]["inflation"]="0.080000000000000000"' >"$TMP_GENESIS" "$GENESIS" && mv "$TMP_GENESIS" "$GENESIS"
    jq '.app_state["mint"]["params"]["inflation_rate_change"]="0.080000000000000000"' >"$TMP_GENESIS" "$GENESIS" && mv "$TMP_GENESIS" "$GENESIS"
    jq '.app_state["mint"]["params"]["inflation_max"]="0.080000000000000000"' >"$TMP_GENESIS" "$GENESIS" && mv "$TMP_GENESIS" "$GENESIS"
    jq '.app_state["mint"]["params"]["inflation_min"]="0.080000000000000000"' >"$TMP_GENESIS" "$GENESIS" && mv "$TMP_GENESIS" "$GENESIS"
    jq '.app_state["feemarket"]["params"]["base_fee"]="182855642857142"' >"$TMP_GENESIS" "$GENESIS" && mv "$TMP_GENESIS" "$GENESIS"
	# Set gas limit in genesis
	jq '.consensus_params["block"]["max_gas"]="10000000"' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"
	

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
	 sed -i 's/rpc_servers \s*=\s* ""/rpc_servers = "https:\/\/shidochain_mainnet_rpc.chain.whenmoonwhenlambo.money:443,https:\/\/rpc-maverick.mavnode.io:443,https:\/\/rpc.kenseishido.com:443,https:\/\/tendermint.shidoscan.com:443"/g' "$CONFIG"
   sed -i 's/trust_hash \s*=\s* ""/trust_hash = "08E89881362E15E3AC9F332DE23E0A54087FF2A8C67CBD50238F98EFC066E640"/g' "$CONFIG"
sed -i 's/trust_height = 0/trust_height = 11035000/g' "$CONFIG"
sed -i 's/trust_period = "112h0m0s"/trust_period = "168h0m0s"/g' "$CONFIG"
sed -i 's/flush_throttle_timeout = "100ms"/flush_throttle_timeout = "10ms"/g' "$CONFIG"
sed -i 's/peer_gossip_sleep_duration = "100ms"/peer_gossip_sleep_duration = "10ms"/g' "$CONFIG"

	# these are some of the node ids help to sync the node with p2p connections
	 sed -i 's/persistent_peers \s*=\s* ""/persistent_peers = "c43c82096f3ea0e8cc128fa6dadb71b3ba2178d8@63.176.19.128:26656,355cb9042c2c88f71640da4110a9d65f21084a79@3.98.239.17:26656,cb8f8c6f813612a5b9844c0699490a583bc12d84@35.182.147.124:26656,64364788e1d74ff41e075902a780193116d3cf9b@15.156.158.51:26656"/g' "$CONFIG"

	# remove the genesis file from binary
	 rm -rf $HOMEDIR/config/genesis.json

	# paste the genesis file
	 cp $current_path/genesis.json $HOMEDIR/config

	# Run this to ensure everything worked and that the genesis file is setup correctly
	shidod validate-genesis --home "$HOMEDIR"

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
ExecStart=/home/$(whoami)/go/bin/cosmovisor run start --home $DAEMON_HOME
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
shidod tendermint unsafe-reset-all --home $HOMEDIR
sudo systemctl start shidochain.service
