#! /bin/bash

DEP_DIR=$(pwd)/AutoTorrentProxy
CONFIG_DIR="$(pwd)/AutoTorrentProxy/config"
FRP_REPO="https://github.com/fatedier/frp/releases/download/v0.61.1/frp_0.61.1_linux_amd64.tar.gz"
GOST_REPO="https://github.com/ginuerzh/gost/releases/download/v2.12.0/gost_2.12.0_linux_amd64.tar.gz"

# parse cmd 
while getopts "f:g:p:" opt; do
  case $opt in
    f)
      FRP_INI_FILE=$OPTARG
      ;;
    g)
      GOST_INI_FILE=$OPTARG
      ;;
    p)
      PROXY=$OPTARG
      ;;
    *)
      echo "Usage: $0 -f <frp config path> -g <gost config string> -p <proxy>"
      exit 1
      ;;
  esac
done

if [ -z "$FILE_PATH" ]; then
  echo "Waring: -f (frp config file path) not specified. Using $CONFIG_DIR/frps.toml"
  FRP_INI_FILE=$CONFIG_DIR/frps.toml
fi

if [ -z "$GOST_INI_FILE" ]; then
  echo "Waring: -g (gost config file path) not specified. Using $CONFIG_DIR/gost.ini"
  GOST_INI_FILE=$CONFIG_DIR/gost.ini
fi

if [ -n "$PROXY" ]; then
  export http_proxy="$PROXY"
  export https_proxy="$PROXY"
  echo "Set proxy to: $PROXY"
fi

# working directory
mkdir -p "$DEP_DIR"
mkdir -p "$DEP_DIR/frp"
mkdir -p "$DEP_DIR/gost"
mkdir -p "$CONFIG_DIR"

# download 
if [ ! -f "$DEP_DIR/frp/frp.tar.gz" ]; then
  echo "$DEP_DIR/frp/frp.tar.gz not found, downloading..."
  echo "Running: wget -O $DEP_DIR/frp/frp.tar.gz $FRP_REPO"
  wget -O $DEP_DIR/frp/frp.tar.gz $FRP_REPO
else
  echo "$DEP_DIR/frp/frp.tar.gz already exists, skipping download."
fi


if [ ! -f "$DEP_DIR/gost/gost.tar.gz" ]; then
  echo "$DEP_DIR/gost/gost.tar.gz not found, downloading..."
  echo "Running: wget -O $DEP_DIR/gost/gost.tar.gz $GOST_REPO"
  wget -O $DEP_DIR/gost/gost.tar.gz $GOST_REPO
else
  echo "$DEP_DIR/gost/gost.tar.gz already exists, skipping download."
fi

echo "Download complete. Decompressing..."
tar -xzf $DEP_DIR/gost/gost.tar.gz -C "$DEP_DIR/gost"
tar -xzf $DEP_DIR/frp/frp.tar.gz -C "$DEP_DIR/frp"


# echo "Decompressed complete... Removing tar cache..."
# rm "$DEP_DIR/frp/frp.tar.gz" && rm "$DEP_DIR/gost/gost.tar.gz"


if [ -n $(env | grep http_proxy) ]; then
  unset http_proxy
  unset https_proxy
  echo "Unsetting proxy..."
fi

echo "Reading gost configuration..."
GOST_USERNAME=$(grep -E '^username=' "$GOST_INI_FILE" | cut -d'=' -f2)
GOST_PASSWORD=$(grep -E '^password=' "$GOST_INI_FILE" | cut -d'=' -f2)
GOST_IP_ADDR=$(grep -E '^ip_addr=' "$GOST_INI_FILE" | cut -d'=' -f2)
GOST_PORT=$(grep -E '^port=' "$GOST_INI_FILE" | cut -d'=' -f2)
if [ -z "$GOST_USERNAME" ] || [ -z "$GOST_PASSWORD" ] || [ -z "$GOST_IP_ADDR" ] || [ -z "$GOST_PORT" ]; then
  echo "Error: Failed to extract parameters from $GOST_INI_FILE"
  exit 1
fi
GOST_CONF="${GOST_USERNAME}:${GOST_PASSWORD}@${GOST_IP_ADDR}:${GOST_PORT}"
echo "Setting GOST_CONF: $GOST_CONF"

GOST_SERVICE_FILE="/etc/systemd/system/gost4torrent.service"
GOST_ROOT="$DEP_DIR/gost"
if [ -f "$GOST_SERVICE_FILE" ]; then
  echo "Error: $GOST_SERVICE_FILE already exists. Exiting script."
  exit 1
fi

echo "Creating systemd service unit file at $GOST_SERVICE_FILE..."
cat > "$GOST_SERVICE_FILE" <<EOL
[Unit]
Description=GOST for Torrent
After=network.target  

[Service]
ExecStart=$GOST_ROOT/gost -L=$GOST_CONF
WorkingDirectory=$(dirname "$GOST_ROOT")  
Restart=always  
User=$USER 
Group=$GROUP 

[Install]
WantedBy=multi-user.target  
EOL

if [ ! -f "$GOST_SERVICE_FILE" ]; then
  echo "Error: Failed to create systemd service file: $GOST_SERVICE_FILE."
  exit 1
fi

echo "Configurating frp service..."
FRP_SERVICE_FILE="/etc/systemd/system/frp4torrent.service"
FRP_ROOT="$DEP_DIR/frp/frp_0.61.1_linux_amd64"
if [ -f "$FRP_SERVICE_FILE" ]; then
  echo "Error: $FRP_SERVICE_FILE already exists. Exiting script."
  exit 1
fi

echo "Creating systemd service unit file at $FRP_SERVICE_FILE..."
cat > "$FRP_SERVICE_FILE" <<EOL
[Unit]
Description=FRP for Torrent
After=network.target  

[Service]
ExecStart=$FRP_ROOT/frps -c=$FRP_INI_FILE
WorkingDirectory=$(dirname "$FRP_ROOT")  
Restart=always  
User=$USER 
Group=$GROUP 

[Install]
WantedBy=multi-user.target  
EOL

if [ ! -f "$FRP_SERVICE_FILE" ]; then
  echo "Error: Failed to create systemd service file: $FRP_SERVICE_FILE."
  exit 1
fi


echo "Reloading systemd daemon..."
sudo systemctl daemon-reload

echo "Enabling and starting the service..."
sudo systemctl enable gost4torrent.service
sudo systemctl start gost4torrent.service
sudo systemctl enable frp4torrent.service
sudo systemctl start frp4torrent.service

echo "Systemd service setup complete!"
echo "Finish!"
