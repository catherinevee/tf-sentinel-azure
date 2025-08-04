#!/bin/bash

# IoT Edge Runtime Installation Script
# This script installs and configures Azure IoT Edge runtime on Ubuntu

set -e

# Parameters passed from Terraform
IOT_HUB_NAME="${iot_hub_name}"
DPS_NAME="${dps_name}"

# Update system packages
echo "Updating system packages..."
apt-get update
apt-get upgrade -y

# Install required packages
echo "Installing required packages..."
apt-get install -y \
    curl \
    wget \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common

# Install Docker (required for IoT Edge)
echo "Installing Docker..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Configure Docker for IoT Edge
systemctl enable docker
systemctl start docker

# Add azureuser to docker group
usermod -aG docker azureuser

# Install Azure CLI
echo "Installing Azure CLI..."
curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# Add Microsoft package repository
echo "Adding Microsoft package repository..."
wget https://packages.microsoft.com/config/ubuntu/22.04/multiarch/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
dpkg -i packages-microsoft-prod.deb
rm packages-microsoft-prod.deb
apt-get update

# Install IoT Edge runtime
echo "Installing Azure IoT Edge runtime..."
apt-get install -y aziot-edge

# Configure IoT Edge for automatic provisioning via DPS
echo "Configuring IoT Edge..."
cat > /etc/aziot/config.toml << EOF
# Azure IoT Edge Configuration

# Provisioning configuration
[provisioning]
source = "dps"
global_endpoint = "https://global.azure-devices-provisioning.net"
id_scope = "REPLACE_WITH_DPS_ID_SCOPE"

# Authentication using symmetric key (for demo purposes)
# In production, use X.509 certificates or TPM
[provisioning.attestation]
method = "symmetric_key"
registration_id = "edge-device-$(hostname)"
symmetric_key = "REPLACE_WITH_DEVICE_KEY"

# Edge Agent configuration
[agent]
name = "edgeAgent"
type = "docker"

[agent.config]
image = "mcr.microsoft.com/azureiotedge-agent:1.4"

# Edge Hub configuration
[connect]
workload_uri = "unix:///var/run/iotedge/workload.sock"
management_uri = "unix:///var/run/iotedge/mgmt.sock"

# Certificate configuration
[certificates]
device_ca_cert = "/etc/aziot/device-ca-cert.pem"
device_ca_pk = "/etc/aziot/device-ca-key.pem"
trusted_ca_certs = "/etc/aziot/trusted-ca-certs.pem"
auto_generated_ca_lifetime_days = 90

# Hostname configuration
hostname = "$(hostname).local"

# Watchdog configuration
[watchdog]
max_retries = 3
EOF

# Set proper permissions for config file
chmod 600 /etc/aziot/config.toml
chown aziotcs:aziotcs /etc/aziot/config.toml

# Create certificate directories
mkdir -p /etc/aziot/certificates
chown -R aziotcs:aziotcs /etc/aziot/certificates

# Install additional IoT tools
echo "Installing additional IoT development tools..."

# Install Node.js for IoT development
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt-get install -y nodejs

# Install Python and IoT SDK
apt-get install -y python3 python3-pip python3-venv
pip3 install azure-iot-device azure-iot-hub

# Install .NET SDK for custom modules
apt-get install -y dotnet-sdk-8.0

# Install IoT Edge Dev Tool
npm install -g iotedgedev

# Create sample edge module directory
mkdir -p /home/azureuser/edge-modules
chown -R azureuser:azureuser /home/azureuser/edge-modules

# Create a sample temperature sensor module configuration
cat > /home/azureuser/edge-modules/deployment.template.json << 'EOF'
{
  "$schema-version": "0.0.1",
  "modulesContent": {
    "$edgeAgent": {
      "properties.desired": {
        "schemaVersion": "1.1",
        "runtime": {
          "type": "docker",
          "settings": {
            "minDockerVersion": "v1.25",
            "loggingOptions": "",
            "registryCredentials": {}
          }
        },
        "systemModules": {
          "edgeAgent": {
            "type": "docker",
            "settings": {
              "image": "mcr.microsoft.com/azureiotedge-agent:1.4",
              "createOptions": {}
            }
          },
          "edgeHub": {
            "type": "docker",
            "status": "running",
            "restartPolicy": "always",
            "settings": {
              "image": "mcr.microsoft.com/azureiotedge-hub:1.4",
              "createOptions": {
                "HostConfig": {
                  "PortBindings": {
                    "5671/tcp": [{"HostPort": "5671"}],
                    "8883/tcp": [{"HostPort": "8883"}],
                    "443/tcp": [{"HostPort": "443"}]
                  }
                }
              }
            }
          }
        },
        "modules": {
          "SimulatedTemperatureSensor": {
            "version": "1.0",
            "type": "docker",
            "status": "running",
            "restartPolicy": "always",
            "settings": {
              "image": "mcr.microsoft.com/azureiotedge-simulated-temperature-sensor:1.0",
              "createOptions": {}
            }
          }
        }
      }
    },
    "$edgeHub": {
      "properties.desired": {
        "schemaVersion": "1.2",
        "routes": {
          "SimulatedTemperatureSensorToIoTHub": "FROM /messages/modules/SimulatedTemperatureSensor/outputs/temperatureOutput INTO $upstream"
        },
        "storeAndForwardConfiguration": {
          "timeToLiveSecs": 7200
        }
      }
    }
  }
}
EOF

chown -R azureuser:azureuser /home/azureuser/edge-modules

# Create systemd service for monitoring edge health
cat > /etc/systemd/system/iotedge-monitor.service << EOF
[Unit]
Description=IoT Edge Health Monitor
After=network.target aziot-edged.service

[Service]
Type=simple
User=azureuser
ExecStart=/usr/local/bin/iotedge-monitor.sh
Restart=always
RestartSec=60

[Install]
WantedBy=multi-user.target
EOF

# Create the monitoring script
cat > /usr/local/bin/iotedge-monitor.sh << 'EOF'
#!/bin/bash

# IoT Edge Health Monitoring Script
# Monitors edge runtime and sends telemetry

while true; do
    # Check IoT Edge daemon status
    if systemctl is-active --quiet aziot-edged; then
        echo "$(date): IoT Edge daemon is running"
    else
        echo "$(date): WARNING - IoT Edge daemon is not running"
        # Attempt to restart
        systemctl restart aziot-edged
    fi
    
    # Check Docker daemon status
    if systemctl is-active --quiet docker; then
        echo "$(date): Docker daemon is running"
    else
        echo "$(date): WARNING - Docker daemon is not running"
        systemctl restart docker
    fi
    
    # Check disk usage
    DISK_USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    if [ "$DISK_USAGE" -gt 80 ]; then
        echo "$(date): WARNING - Disk usage is at ${DISK_USAGE}%"
        # Clean up old Docker images
        docker image prune -f
    fi
    
    # Check memory usage
    MEMORY_USAGE=$(free | grep Mem | awk '{printf("%.0f", $3/$2 * 100)}')
    if [ "$MEMORY_USAGE" -gt 85 ]; then
        echo "$(date): WARNING - Memory usage is at ${MEMORY_USAGE}%"
    fi
    
    # Sleep for 5 minutes
    sleep 300
done
EOF

chmod +x /usr/local/bin/iotedge-monitor.sh

# Enable and start monitoring service
systemctl daemon-reload
systemctl enable iotedge-monitor
systemctl start iotedge-monitor

# Configure log rotation for IoT Edge logs
echo "Configuring log rotation..."
cat > /etc/logrotate.d/iotedge << EOF
/var/log/aziot/edged/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
}

/var/log/aziot/identityd/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
}
EOF

# Create configuration script for manual setup
cat > /home/azureuser/configure-edge.sh << EOF
#!/bin/bash

# Manual configuration script for IoT Edge
# Run this script to complete the edge device setup

echo "Configuring IoT Edge device..."

# Login using managed identity
az login --identity

# Get IoT Hub information
IOT_HUB_CONNECTION_STRING=\$(az iot hub connection-string show --hub-name "$IOT_HUB_NAME" --query connectionString -o tsv)

# Get DPS information
DPS_ID_SCOPE=\$(az iot dps show --name "$DPS_NAME" --query properties.idScope -o tsv)

echo "IoT Hub: $IOT_HUB_NAME"
echo "DPS ID Scope: \$DPS_ID_SCOPE"

# Note: In production, you would:
# 1. Create a device identity in IoT Hub or register with DPS
# 2. Get the device connection string or provisioning information
# 3. Update the config.toml file with actual values
# 4. Apply the configuration with: sudo iotedge config apply

echo "Manual configuration required:"
echo "1. Create device identity in IoT Hub"
echo "2. Update /etc/aziot/config.toml with device credentials"
echo "3. Run: sudo iotedge config apply"
echo "4. Check status: sudo iotedge system status"
EOF

chmod +x /home/azureuser/configure-edge.sh
chown azureuser:azureuser /home/azureuser/configure-edge.sh

# Configure automatic updates
echo "Configuring automatic security updates..."
apt-get install -y unattended-upgrades
cat > /etc/apt/apt.conf.d/20auto-upgrades << EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF

# Install monitoring and diagnostic tools
echo "Installing monitoring tools..."
apt-get install -y htop iotop nethogs

# Clean up
echo "Cleaning up..."
apt-get autoremove -y
apt-get autoclean
docker system prune -f

# Configure firewall (UFW) for IoT Edge
echo "Configuring firewall..."
ufw --force enable
ufw allow 22/tcp      # SSH
ufw allow 443/tcp     # HTTPS (Edge Hub)
ufw allow 5671/tcp    # AMQP (Edge Hub)
ufw allow 8883/tcp    # MQTT (Edge Hub)

echo "IoT Edge installation completed successfully!"
echo "Next steps:"
echo "1. Configure device identity: /home/azureuser/configure-edge.sh"
echo "2. Check edge status: sudo iotedge system status"
echo "3. View edge logs: sudo iotedge system logs"
echo "4. List edge modules: sudo iotedge list"
