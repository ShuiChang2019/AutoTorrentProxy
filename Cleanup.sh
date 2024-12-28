#!/bin/bash

echo "Cleaning up the services created"

SERVICES=("gost4torrent.service" "frp4torrent.service")

for SERVICE in "${SERVICES[@]}"; do
    echo "Stopping the $SERVICE service..."
    echo "executing systemctl stop $SERVICE"
    sudo systemctl stop "$SERVICE"

    echo "Removing the $SERVICE service file..."
    echo "executing rm -f /etc/systemd/system/$SERVICE"
    sudo rm -f "/etc/systemd/system/$SERVICE"
done

for SERVICE in "${SERVICES[@]}"; do
    echo "Reloading systemd daemon..."
    sudo systemctl daemon-reload
    sudo systemctl reset-failed

    echo "Validating whether cleanup is complete for $SERVICE..."

    if systemctl list-units --type=service | grep -q "$SERVICE"; then
        echo "Error: $SERVICE service still exists."
        exit 1
    else
        echo "$SERVICE service has been removed successfully."
    fi
done

echo "Cleaning up complete!"
