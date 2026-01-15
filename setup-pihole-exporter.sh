#!/bin/bash
# Pi-hole Exporter Setup Script
# Run this on your Pi-hole host (192.168.1.200)

set -e

echo "================================="
echo "Pi-hole Exporter Setup"
echo "================================="
echo ""

# Check if Docker is available
if command -v docker &> /dev/null; then
    echo "✓ Docker found! Will use Docker deployment."
    INSTALL_METHOD="docker"
else
    echo "✗ Docker not found. Will use binary installation."
    INSTALL_METHOD="binary"
fi

echo ""
echo "Getting Pi-hole password..."
echo "You'll need your Pi-hole web interface password (or API token)."
echo ""
read -sp "Enter Pi-hole password: " PIHOLE_PASSWORD
echo ""

if [ "$INSTALL_METHOD" = "docker" ]; then
    echo ""
    echo "Installing Pi-hole exporter via Docker..."

    # Stop existing container if running
    docker stop pihole-exporter 2>/dev/null || true
    docker rm pihole-exporter 2>/dev/null || true

    # Run Pi-hole exporter
    docker run -d \
      --name pihole-exporter \
      --restart unless-stopped \
      -p 9617:9617 \
      -e PIHOLE_HOSTNAME=localhost \
      -e PIHOLE_PASSWORD="${PIHOLE_PASSWORD}" \
      ekofr/pihole-exporter:latest

    echo ""
    echo "✓ Pi-hole exporter installed successfully!"
    echo ""
    echo "Testing metrics endpoint..."
    sleep 3
    curl -s http://localhost:9617/metrics | grep pihole | head -5

else
    echo ""
    echo "Installing Pi-hole exporter binary..."

    # Download latest release
    LATEST_VERSION=$(curl -s https://api.github.com/repos/eko/pihole-exporter/releases/latest | grep tag_name | cut -d '"' -f 4)
    ARCH=$(uname -m)

    if [ "$ARCH" = "x86_64" ]; then
        BINARY="pihole_exporter-linux-amd64"
    elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
        BINARY="pihole_exporter-linux-arm64"
    elif [[ "$ARCH" == arm* ]]; then
        BINARY="pihole_exporter-linux-armv7"
    else
        echo "Unsupported architecture: $ARCH"
        exit 1
    fi

    echo "Downloading $BINARY version $LATEST_VERSION..."
    wget -O /tmp/pihole_exporter "https://github.com/eko/pihole-exporter/releases/download/${LATEST_VERSION}/${BINARY}"
    chmod +x /tmp/pihole_exporter
    sudo mv /tmp/pihole_exporter /usr/local/bin/pihole_exporter

    # Create systemd service
    echo "Creating systemd service..."
    sudo tee /etc/systemd/system/pihole-exporter.service > /dev/null <<EOF
[Unit]
Description=Pi-hole Exporter
After=network.target

[Service]
Type=simple
User=nobody
Environment="PIHOLE_HOSTNAME=127.0.0.1"
Environment="PIHOLE_PASSWORD=${PIHOLE_PASSWORD}"
ExecStart=/usr/local/bin/pihole_exporter
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    # Start service
    sudo systemctl daemon-reload
    sudo systemctl enable pihole-exporter
    sudo systemctl start pihole-exporter

    echo ""
    echo "✓ Pi-hole exporter installed successfully!"
    echo ""
    echo "Checking service status..."
    sudo systemctl status pihole-exporter --no-pager

    echo ""
    echo "Testing metrics endpoint..."
    sleep 2
    curl -s http://localhost:9617/metrics | grep pihole | head -5
fi

echo ""
echo "================================="
echo "Setup Complete!"
echo "================================="
echo ""
echo "Pi-hole exporter is now running on port 9617"
echo "Prometheus will start scraping metrics within 15 seconds."
echo ""
echo "To verify it's working from your monitoring host:"
echo "  curl http://192.168.1.200:9617/metrics | head -20"
echo ""
echo "Check Prometheus targets: http://localhost:9090/targets"
echo ""