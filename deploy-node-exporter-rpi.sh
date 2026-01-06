#!/bin/bash
# Deploy node-exporter to Raspberry Pi
# Run this on the Raspberry Pi (192.168.1.200)

echo "Deploying node-exporter to Raspberry Pi..."

# Pull the image
docker pull prom/node-exporter:latest

# Run the container
docker run -d \
  --name node-exporter \
  --restart unless-stopped \
  --pid host \
  --volume /:/rootfs:ro \
  --volume /sys:/sys:ro \
  --volume /proc:/proc:ro \
  -p 9100:9100 \
  prom/node-exporter:latest \
  --collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/) \
  --collector.filesystem.fs-types-exclude=^(autofs|binfmt_misc|bpf|cgroup2?|configfs|debugfs|devpts|devtmpfs|fusectl|hugetlbfs|iso9660|mqueue|nsfs|overlay|proc|procfs|pstore|rpc_pipefs|securityfs|selinuxfs|squashfs|sysfs|tracefs)$$ \
  --collector.netdev.device-exclude=^(veth.*|br.*|docker.*|virbr.*|lo)$$ \
  --collector.netdev.device-include=^(eth0|eth1|wlan0|wlan1|docker0)$$ \
  --web.telemetry-path=/metrics

echo "✅ node-exporter deployed!"
echo ""
echo "Verify it's running:"
echo "  curl http://192.168.1.200:9100/metrics | head -20"
echo ""
echo "Expected output: HELP and TYPE lines for node-exporter metrics"
