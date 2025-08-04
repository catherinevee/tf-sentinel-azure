#!/bin/bash

# Azure DevOps Build Agent Installation Script
# This script installs and configures an Azure DevOps build agent on Ubuntu

set -e

# Parameters passed from Terraform
KEY_VAULT_NAME="${key_vault_name}"
AZDO_URL="${azdo_url}"
AGENT_POOL_NAME="${agent_pool_name}"

# Update system packages
echo "Updating system packages..."
apt-get update
apt-get upgrade -y

# Install essential build tools
echo "Installing essential build tools..."
apt-get install -y \
    curl \
    wget \
    git \
    jq \
    unzip \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common

# Install Docker
echo "Installing Docker..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Add azureuser to docker group
usermod -aG docker azureuser

# Install Azure CLI
echo "Installing Azure CLI..."
curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# Install .NET SDK (latest LTS)
echo "Installing .NET SDK..."
wget https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
dpkg -i packages-microsoft-prod.deb
rm packages-microsoft-prod.deb
apt-get update
apt-get install -y dotnet-sdk-8.0

# Install Node.js (LTS)
echo "Installing Node.js..."
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt-get install -y nodejs

# Install Python and pip
echo "Installing Python and development tools..."
apt-get install -y python3 python3-pip python3-venv python3-dev build-essential

# Install PowerShell
echo "Installing PowerShell..."
wget -q "https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb"
dpkg -i packages-microsoft-prod.deb
apt-get update
apt-get install -y powershell

# Install Terraform
echo "Installing Terraform..."
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
apt-get update
apt-get install -y terraform

# Install kubectl
echo "Installing kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

# Install Helm
echo "Installing Helm..."
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash

# Create directory for Azure DevOps agent
echo "Setting up Azure DevOps agent..."
mkdir -p /opt/azdo-agent
cd /opt/azdo-agent

# Download latest Azure DevOps agent
echo "Downloading Azure DevOps agent..."
AGENT_VERSION=$(curl -s https://api.github.com/repos/Microsoft/azure-pipelines-agent/releases/latest | jq -r '.tag_name' | sed 's/v//')
wget "https://vstsagentpackage.azureedge.net/agent/$${AGENT_VERSION}/vsts-agent-linux-x64-$${AGENT_VERSION}.tar.gz"
tar zxvf "vsts-agent-linux-x64-$${AGENT_VERSION}.tar.gz"
rm "vsts-agent-linux-x64-$${AGENT_VERSION}.tar.gz"

# Change ownership to azureuser
chown -R azureuser:azureuser /opt/azdo-agent

# Install dependencies for the agent
echo "Installing agent dependencies..."
./bin/installdependencies.sh

# Create systemd service for the agent
cat > /etc/systemd/system/azdo-agent.service << EOF
[Unit]
Description=Azure DevOps Agent
After=network.target

[Service]
Type=simple
User=azureuser
WorkingDirectory=/opt/azdo-agent
ExecStart=/opt/azdo-agent/runsvc.sh
Restart=always
RestartSec=5
KillMode=process
KillSignal=SIGINT
TimeoutStopSec=5min

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service (agent will be configured via separate script)
systemctl daemon-reload
systemctl enable azdo-agent

# Create agent configuration script
cat > /opt/azdo-agent/configure-agent.sh << 'EOF'
#!/bin/bash

# This script will be run to configure the agent with Azure DevOps
# It requires the PAT token to be retrieved from Key Vault

set -e

# Login using managed identity
az login --identity

# Get the PAT token from Key Vault
PAT_TOKEN=$(az keyvault secret show --name azdo-pat --vault-name "$1" --query value -o tsv)

# Configure the agent
cd /opt/azdo-agent
./config.sh \
  --unattended \
  --url "$2" \
  --auth pat \
  --token "$PAT_TOKEN" \
  --pool "$3" \
  --agent "$(hostname)" \
  --acceptTeeEula \
  --replace

# Start the agent service
sudo systemctl start azdo-agent

echo "Azure DevOps agent configured and started successfully"
EOF

chmod +x /opt/azdo-agent/configure-agent.sh
chown azureuser:azureuser /opt/azdo-agent/configure-agent.sh

# Create a script to run the configuration (will be executed after VM is fully provisioned)
cat > /home/azureuser/setup-agent.sh << EOF
#!/bin/bash
# Run this script to complete agent setup
/opt/azdo-agent/configure-agent.sh "$KEY_VAULT_NAME" "$AZDO_URL" "$AGENT_POOL_NAME"
EOF

chmod +x /home/azureuser/setup-agent.sh
chown azureuser:azureuser /home/azureuser/setup-agent.sh

# Configure automatic updates
echo "Configuring automatic security updates..."
apt-get install -y unattended-upgrades
cat > /etc/apt/apt.conf.d/20auto-upgrades << EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF

# Configure log rotation for build logs
echo "Configuring log rotation..."
cat > /etc/logrotate.d/azdo-agent << EOF
/opt/azdo-agent/_diag/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
}
EOF

# Install additional development tools
echo "Installing additional development tools..."
npm install -g @angular/cli typescript webpack

# Install Python packages commonly used in builds
pip3 install pytest coverage flake8 black bandit safety

# Clean up package caches to reduce disk usage
echo "Cleaning up..."
apt-get autoremove -y
apt-get autoclean
npm cache clean --force
pip3 cache purge

echo "Build agent installation completed successfully!"
echo "To complete setup, run: /home/azureuser/setup-agent.sh"
echo "Agent will be registered with pool: $AGENT_POOL_NAME"
