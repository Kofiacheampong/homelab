# Homelab Monitoring Stack

Simple Prometheus + Grafana monitoring for your homelab. Monitor Pi-hole and local machines (RPi, servers).

## What This Does

- **Prometheus**: Collects metrics from your devices
- **Grafana**: Visualizes metrics in dashboards
- **Caddy**: Optional HTTPS reverse proxy
- **Node Exporter**: System metrics (CPU, RAM, disk) for this Docker host

## Security Hardening Defaults

- **Pinned images**: Compose uses explicit image versions (no `latest`) and can be managed via `.env`.
- **Healthchecks**: Core services expose readiness/health probes for faster failure detection.
- **Network segmentation**:
  - `edge`: internet-facing reverse proxy
  - `observability`: Prometheus/Grafana/Loki internal traffic
  - `siem`: reserved lane for Wazuh onboarding (currently connected to log services)

## Wazuh SIEM Overlay

- Wazuh is defined in `docker-compose.wazuh.yml` as an optional overlay (manager, indexer, dashboard).
- It reuses the segmented `siem` network and keeps Wazuh dashboard/indexer bound to localhost by default.
- Agent enrollment ports remain exposed for LAN agents:
  - `1514/udp`
  - `1515/tcp`

Start base stack + Wazuh:
```bash
docker compose -f docker-compose.yml -f docker-compose.wazuh.yml up -d
```

Check service health:
```bash
docker compose -f docker-compose.yml -f docker-compose.wazuh.yml ps
```

Access:
- **Wazuh Dashboard**: http://localhost:5601
- **Wazuh API**: https://localhost:55000

## Quick Start

### 1. Update Pi-hole IP

Edit [prometheus.yml](prometheus.yml:21) and change the Pi-hole IP address:
```yaml
- targets: ['192.168.1.200:9617']  # Change this to your Pi-hole IP
```

### 2. Start the Stack

Create `.env` from template and set a strong Grafana admin password:
```bash
cp .env.example .env
```

Optional: review pinned image versions in `.env` before starting.

```bash
docker-compose up -d
```

### 3. Access Dashboards

- **Grafana**: http://localhost:3000 (login from `.env`)
- **Prometheus**: http://localhost:9090

## Setup Pi-hole Monitoring

On your Pi-hole machine, install the exporter:

```bash
docker run -d \
  --name pihole-exporter \
  -p 9617:9617 \
  -e PIHOLE_HOSTNAME=localhost \
  -e PIHOLE_PASSWORD='your-pihole-password' \
  --restart unless-stopped \
  ekofr/pihole-exporter:latest
```

Verify it's working:
```bash
curl http://your-pihole-ip:9617/metrics
```

## Add More Machines

To monitor additional RPi or servers, install node-exporter on each:

```bash
docker run -d \
  --name node-exporter \
  -p 9100:9100 \
  -v /:/host:ro,rslave \
  --restart unless-stopped \
  prom/node-exporter:latest \
  --path.rootfs=/host
```

Then add them to [prometheus.yml](prometheus.yml:27):
```yaml
- job_name: 'homelab-servers'
  static_configs:
    - targets:
        - '192.168.1.201:9100'  # rpi-1
        - '192.168.1.202:9100'  # rpi-2
```

Reload Prometheus:
```bash
docker-compose restart prometheus
```

## Configure Grafana

1. Go to http://localhost:3000
2. Login with `GRAFANA_ADMIN_USER` and `GRAFANA_ADMIN_PASSWORD` from `.env`
3. Add Prometheus datasource:
   - Configuration → Data Sources → Add data source
   - Choose Prometheus
   - URL: `http://prometheus:9090`
   - Click "Save & Test"

4. Import dashboards:
   - **Pi-hole**: Dashboard ID `10176`
   - **Node Exporter**: Dashboard ID `1860`

## Enable HTTPS

Edit [Caddyfile](Caddyfile:3) and uncomment the HTTPS section:
```
grafana.yourdomain.com {
    reverse_proxy grafana:3000
}
```

Replace `yourdomain.com` with your actual domain. Caddy will automatically get Let's Encrypt certificates.

Restart:
```bash
docker-compose restart caddy
```

## Troubleshooting

**Prometheus can't reach Pi-hole:**
- Check Pi-hole exporter is running: `docker ps` on Pi-hole host
- Verify firewall allows port 9617
- Test: `curl http://pihole-ip:9617/metrics`

**Grafana shows no data:**
- Check Prometheus datasource is configured correctly
- Verify Prometheus is scraping targets: http://localhost:9090/targets
- All targets should show "UP" status

**Can't access Grafana:**
- Check containers are running: `docker-compose ps`
- Check logs: `docker-compose logs grafana`

## File Structure

```
pihole_monitoring/
├── docker-compose.yml    # Service definitions
├── prometheus.yml        # Prometheus scrape config
├── Caddyfile            # Reverse proxy config
├── .env                 # Environment variables (optional)
├── backups/             # Backups stored here
└── scripts/             # Backup scripts
```

## Backups

Run the backup script:
```bash
bash scripts/backup_grafana.sh
```

Restore from backup:
```bash
# Stop Grafana
docker-compose stop grafana

# Extract backup
tar xzf backups/grafana-backup-*.tar.gz -C /tmp/restore

# Restore data
docker run --rm \
  -v /tmp/restore:/restore:ro \
  -v pihole_monitoring_grafana-data:/data \
  alpine:3.18 \
  sh -c 'rm -rf /data/* && cp -r /restore/* /data/ && chown -R 472:472 /data'

# Start Grafana
docker-compose start grafana
```

## What Got Removed

This was over-engineered with 25+ documentation files for:
- InfluxDB/Telegraf stack (replaced with Prometheus)
- Windows monitoring
- SSH tunnels, ngrok tunnels
- Multi-host complex setups
- Dozens of troubleshooting guides

Now it's just the essentials: monitor Pi-hole and local machines. Simple.

---

**Stack**: Prometheus, Grafana, Caddy, Node Exporter
**Purpose**: Monitor Pi-hole + homelab machines
