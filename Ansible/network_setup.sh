#!/bin/bash

# Capture the current IPv4 address of enp1s0
current_ip=$(ip addr show enp1s0 | grep -oP 'inet \K[\d.]+')

# Check if the current_ip variable is empty
if [ -n "$current_ip" ]; then
    # Replace the placeholder IP address in the YAML configuration
    sed -i "s/^addresses:\n\s*- 255.255.255.255\/24/addresses:\n  - 192.168.3.$current_ip\/24/" /etc/netplan/99_config.yaml
    
    # Apply the updated network configuration
    netplan apply
    echo "setup-server>> Network has been updated with IP 192.168.3.$current_ip."
else
    echo "setup-server>> Failed to obtain the current IP address for enp1s0."
fi
