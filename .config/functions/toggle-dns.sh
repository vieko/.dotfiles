#!/bin/bash

# Path to resolved.conf
RESOLVED_CONF="/etc/systemd/resolved.conf"

# Path to the secrets file
SECRETS_FILE="/home/vieko/secrets/nextdns.conf"

# Public WiFi Configuration (Empty DNS settings)
WIFI_CONFIG="[Resolve]"

# Check if NextDNS is currently configured by looking for '.dns.nextdns.io'
if grep -q ".dns.nextdns.io" "$RESOLVED_CONF"; then
    # Switch to default DNS settings for public WiFi
    echo -e "$WIFI_CONFIG" | sudo tee "$RESOLVED_CONF" > /dev/null
    echo "Switched to public Wi-Fi DNS settings."
else
    # Switch to NextDNS settings from secrets file
    sudo cp "$SECRETS_FILE" "$RESOLVED_CONF"
    echo "Switched to NextDNS settings."
fi

# Restart systemd-resolved
sudo systemctl restart systemd-resolved.service
echo "DNS service restarted."
