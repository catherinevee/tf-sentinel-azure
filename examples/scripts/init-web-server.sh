#!/bin/bash
# Cost-optimized web server initialization script
# This script sets up a lightweight web server for development/testing

set -e

# Variables
APP_NAME="${app_name}"
LOG_FILE="/var/log/init-web-server.log"

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log "Starting cost-optimized web server initialization for $APP_NAME"

# Update system packages (minimal update for cost efficiency)
log "Updating system packages"
apt-get update -y
apt-get install -y nginx curl htop

# Configure nginx for lightweight operation
log "Configuring nginx for cost optimization"

# Create a simple index page
cat > /var/www/html/index.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>$APP_NAME - Cost Optimized</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .cost-info { background: #e8f5e8; padding: 20px; border-radius: 5px; }
        .spot-indicator { color: #ff6600; font-weight: bold; }
    </style>
</head>
<body>
    <h1>$APP_NAME</h1>
    <div class="cost-info">
        <h2>Cost Optimization Features Active</h2>
        <ul>
            <li><span class="spot-indicator">Spot Instance</span> - Up to 90% cost savings</li>
            <li>Burstable VM (B1s) - Pay for burst performance when needed</li>
            <li>Auto-scaling 1-5 instances based on CPU usage</li>
            <li>Scheduled shutdown during off-hours</li>
            <li>Basic Load Balancer for cost efficiency</li>
        </ul>
    </div>
    <h3>Server Information</h3>
    <p><strong>Hostname:</strong> $(hostname)</p>
    <p><strong>Instance Type:</strong> Standard_B1s (Burstable)</p>
    <p><strong>Pricing Model:</strong> Spot Instance</p>
    <p><strong>Started:</strong> $(date)</p>
</body>
</html>
EOF

# Create health check endpoint
cat > /var/www/html/health << EOF
{
    "status": "healthy",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "instance_type": "spot",
    "cost_optimized": true
}
EOF

# Configure nginx for cost-optimized performance
cat > /etc/nginx/sites-available/default << EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    root /var/www/html;
    index index.html;
    
    server_name _;
    
    # Health check endpoint
    location /health {
        add_header Content-Type application/json;
        return 200 '{"status":"healthy","timestamp":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","cost_optimized":true}';
    }
    
    # Main application
    location / {
        try_files \$uri \$uri/ =404;
    }
    
    # Optimize for cost - disable access logs in development
    access_log off;
    error_log /var/log/nginx/error.log error;
    
    # Basic security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
}
EOF

# Optimize nginx configuration for low resource usage
cat > /etc/nginx/nginx.conf << EOF
user www-data;
worker_processes 1;  # Minimal processes for cost optimization
pid /run/nginx.pid;

events {
    worker_connections 512;  # Lower connections for B1s instance
    use epoll;
    multi_accept on;
}

http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 15;  # Shorter timeout for resource efficiency
    types_hash_max_size 2048;
    
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    # Disable access logs to save disk I/O costs
    access_log off;
    error_log /var/log/nginx/error.log;
    
    # Gzip compression for bandwidth cost savings
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml;
    
    include /etc/nginx/sites-enabled/*;
}
EOF

# Start and enable nginx
log "Starting nginx service"
systemctl start nginx
systemctl enable nginx

# Configure automatic security updates (cost-effective security)
log "Configuring automatic security updates"
apt-get install -y unattended-upgrades
echo 'Unattended-Upgrade::Automatic-Reboot "false";' > /etc/apt/apt.conf.d/50unattended-upgrades-custom

# Set up log rotation to manage disk space costs
cat > /etc/logrotate.d/cost-optimization << EOF
/var/log/nginx/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 644 www-data adm
    postrotate
        systemctl reload nginx
    endscript
}

/var/log/init-web-server.log {
    weekly
    rotate 4
    compress
    missingok
    notifempty
}
EOF

# Create a simple monitoring script for cost awareness
cat > /usr/local/bin/cost-monitor.sh << 'EOF'
#!/bin/bash
# Simple cost monitoring script

INSTANCE_TYPE=$(curl -s -H Metadata:true "http://169.254.169.254/metadata/instance/compute/vmSize?api-version=2021-02-01")
SPOT_STATUS=$(curl -s -H Metadata:true "http://169.254.169.254/metadata/instance/compute/priority?api-version=2021-02-01")

echo "=== Cost Optimization Status ===" > /var/www/html/cost-status.html
echo "<h2>Instance Information</h2>" >> /var/www/html/cost-status.html
echo "<p><strong>Instance Type:</strong> $INSTANCE_TYPE</p>" >> /var/www/html/cost-status.html
echo "<p><strong>Priority:</strong> $SPOT_STATUS</p>" >> /var/www/html/cost-status.html
echo "<p><strong>Cost Model:</strong> Spot Instance (up to 90% savings)</p>" >> /var/www/html/cost-status.html
echo "<p><strong>Last Updated:</strong> $(date)</p>" >> /var/www/html/cost-status.html

# Check disk usage for cost awareness
DISK_USAGE=$(df -h / | awk 'NR==2{print $5}' | sed 's/%//')
if [ $DISK_USAGE -gt 80 ]; then
    echo "<p style='color: red;'><strong>Warning:</strong> Disk usage high ($DISK_USAGE%) - consider cleanup to avoid storage costs</p>" >> /var/www/html/cost-status.html
fi

# Check memory usage
MEMORY_USAGE=$(free | grep Mem | awk '{printf("%.0f", $3/$2 * 100.0)}')
echo "<p><strong>Memory Usage:</strong> $MEMORY_USAGE%</p>" >> /var/www/html/cost-status.html

# Show uptime (relevant for spot instances)
UPTIME=$(uptime -p)
echo "<p><strong>Uptime:</strong> $UPTIME</p>" >> /var/www/html/cost-status.html
EOF

chmod +x /usr/local/bin/cost-monitor.sh

# Set up cron job for cost monitoring
echo "*/5 * * * * root /usr/local/bin/cost-monitor.sh" > /etc/cron.d/cost-monitor

# Create spot instance eviction handler
cat > /usr/local/bin/spot-eviction-handler.sh << 'EOF'
#!/bin/bash
# Handle spot instance eviction gracefully

log_eviction() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> /var/log/spot-eviction.log
}

# Check for eviction notice
EVICTION_NOTICE=$(curl -s -H Metadata:true "http://169.254.169.254/metadata/scheduledevents?api-version=2019-08-01" | grep -i "preempt\|terminate")

if [ ! -z "$EVICTION_NOTICE" ]; then
    log_eviction "Spot instance eviction notice received"
    
    # Graceful shutdown procedures
    log_eviction "Starting graceful shutdown procedures"
    
    # Stop accepting new connections
    nginx -s quit
    
    # Wait for existing connections to close
    sleep 10
    
    log_eviction "Graceful shutdown completed"
fi
EOF

chmod +x /usr/local/bin/spot-eviction-handler.sh

# Set up eviction monitoring (check every 30 seconds)
echo "* * * * * root /usr/local/bin/spot-eviction-handler.sh" > /etc/cron.d/spot-eviction-monitor
echo "* * * * * root sleep 30; /usr/local/bin/spot-eviction-handler.sh" >> /etc/cron.d/spot-eviction-monitor

# Run initial cost monitoring
/usr/local/bin/cost-monitor.sh

# Restart cron to apply new jobs
systemctl restart cron

# Test nginx configuration
log "Testing nginx configuration"
nginx -t

if [ $? -eq 0 ]; then
    log "Nginx configuration test passed"
    systemctl reload nginx
else
    log "Nginx configuration test failed"
    exit 1
fi

# Verify services are running
log "Verifying services"
systemctl is-active --quiet nginx && log "Nginx is running" || log "ERROR: Nginx is not running"

# Final health check
HEALTH_CHECK=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/health)
if [ "$HEALTH_CHECK" = "200" ]; then
    log "Health check passed - web server is ready"
else
    log "ERROR: Health check failed with code $HEALTH_CHECK"
fi

log "Cost-optimized web server initialization completed successfully"
log "Web server features:"
log "  - Lightweight nginx configuration"
log "  - Health check endpoint at /health"
log "  - Cost monitoring at /cost-status.html"
log "  - Spot instance eviction handling"
log "  - Log rotation for cost management"
log "  - Security updates automation"

# Display final status
echo "=== Initialization Complete ==="
echo "Web server is running on port 80"
echo "Health check: http://localhost/health"
echo "Cost status: http://localhost/cost-status.html"
echo "Logs: $LOG_FILE"
echo "============================"
