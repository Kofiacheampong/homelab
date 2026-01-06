# Homelab Monitoring Stack

> A simplified, production-ready monitoring solution for homelab infrastructure using Prometheus, Grafana, and Caddy.

## 📋 Table of Contents
- [Overview](#overview)
- [Problem Statement](#problem-statement)
- [Solution Architecture](#solution-architecture)
- [Tech Stack](#tech-stack)
- [Features](#features)
- [Implementation](#implementation)
- [Results](#results)
- [Lessons Learned](#lessons-learned)

---

## 🎯 Overview

A containerized monitoring stack designed to track Pi-hole DNS metrics and system performance across multiple homelab devices. Built with infrastructure-as-code principles using Docker Compose, featuring automatic HTTPS, persistent storage, and automated backups.

**Live Dashboards**: Real-time visualization of DNS queries, ad blocking stats, and system metrics (CPU, memory, disk, network).

---

## 🔍 Problem Statement

**Initial Challenge**: Started with a simple Pi-hole monitoring need but over-engineered the solution with:
- Conflicting monitoring stacks (Prometheus + InfluxDB/Telegraf)
- 25+ documentation files covering every possible scenario
- Complex multi-host architectures not needed for homelab scale
- Windows monitoring, SSH tunnels, ngrok tunnels adding unnecessary complexity

**Goal**: Simplify to a production-ready monitoring solution that:
- Monitors Pi-hole DNS/ad-blocking metrics
- Tracks system resources on homelab machines
- Provides secure HTTPS access with automatic certificate management
- Remains maintainable and scalable

---

## 🏗️ Solution Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Docker Compose Stack                      │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐            │
│  │   Caddy    │  │ Prometheus │  │  Grafana   │            │
│  │ (Reverse   │─▶│  (Metrics  │─▶│(Dashboards)│            │
│  │  Proxy)    │  │ Collection)│  │            │            │
│  │ Port 443   │  │ Port 9090  │  │ Port 3000  │            │
│  └────────────┘  └────────────┘  └────────────┘            │
│         │              │                                      │
│         │              ├──────────────┐                      │
│         │              │              │                      │
│         ▼              ▼              ▼                      │
│  ┌────────────┐  ┌────────────┐  Persistent                │
│  │   HTTPS    │  │Node Exporter│  Volumes                   │
│  │Self-Signed │  │(Host Metrics)│                           │
│  │   Certs    │  │  Port 9100  │                           │
│  └────────────┘  └────────────┘                            │
└─────────────────────────────────────────────────────────────┘
                         │
                         │ Scrapes metrics every 15s
                         │
         ┌───────────────┴───────────────┐
         │                               │
         ▼                               ▼
┌─────────────────┐           ┌─────────────────┐
│   Pi-hole Host  │           │  Other Servers  │
│  (192.168.1.x)  │           │   (Optional)    │
│                 │           │                 │
│  Pi-hole        │           │  node-exporter  │
│  Exporter       │           │  :9100          │
│  :9617          │           │                 │
└─────────────────┘           └─────────────────┘
```

---

## 🛠️ Tech Stack

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **Monitoring** | Prometheus | Time-series metrics database & scraping |
| **Visualization** | Grafana | Dashboard creation and data visualization |
| **Reverse Proxy** | Caddy | Automatic HTTPS with self-signed certificates |
| **System Metrics** | Node Exporter | Linux system metrics collection |
| **Pi-hole Metrics** | ekofr/pihole-exporter | DNS and ad-blocking statistics |
| **Orchestration** | Docker Compose | Container management and networking |
| **Backups** | Bash + systemd timers | Automated daily Grafana backups |

---

## ✨ Features

### Core Monitoring
- ✅ **Real-time Pi-hole Metrics**: DNS queries, blocked ads, query types, top domains
- ✅ **System Performance**: CPU, memory, disk usage, network I/O
- ✅ **Multi-host Support**: Monitor multiple Raspberry Pis and servers
- ✅ **15-second Scrape Interval**: Near real-time metric updates

### Security & Access
- ✅ **Automatic HTTPS**: Caddy generates and manages TLS certificates
- ✅ **Self-signed Certificates**: For local `.homelab.local` domain
- ✅ **Dual Access Methods**: HTTPS via domain or HTTP via localhost

### Reliability & Maintenance
- ✅ **Persistent Storage**: Docker volumes for data retention
- ✅ **Automated Backups**: Daily Grafana backup with 7-day retention
- ✅ **Auto-restart**: All services configured with `restart: unless-stopped`
- ✅ **Minimal Resource Usage**: Runs efficiently on low-power hardware

### Developer Experience
- ✅ **Single Configuration File**: One `docker-compose.yml` for entire stack
- ✅ **Infrastructure as Code**: Version-controlled, reproducible setup
- ✅ **Clear Documentation**: Simplified from 25+ docs to 1 comprehensive README

---

## 💻 Implementation

### Project Structure
```
pihole_monitoring/
├── docker-compose.yml       # Service orchestration
├── prometheus.yml           # Metrics scraping configuration
├── Caddyfile               # HTTPS reverse proxy config
├── .env                    # Secrets (gitignored)
├── scripts/
│   └── backup_grafana.sh   # Backup automation
├── systemd/
│   ├── grafana-backup.service
│   └── grafana-backup.timer
└── backups/                # Backup storage
```

### Key Implementation Details

**1. Prometheus Configuration**
```yaml
scrape_configs:
  - job_name: 'pihole'
    static_configs:
      - targets: ['192.168.1.200:9617']

  - job_name: 'docker-host'
    static_configs:
      - targets: ['node-exporter:9100']
```

**2. Docker Compose Stack**
- Isolated network for service communication
- Named volumes for data persistence
- Explicit restart policies for high availability
- WSL2-compatible volume mounts for node-exporter

**3. Automated Backups**
- Systemd timer triggers daily at 02:00 UTC
- Exports Grafana volume to timestamped tarball
- Retains last 7 backups automatically
- Restoration process documented

---

## 📊 Results

### Simplification Metrics
| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Documentation Files | 25+ | 2 | **92% reduction** |
| Docker Services | 5 (conflicting stacks) | 4 (unified) | Cleaner architecture |
| Config Files | 3 different monitoring systems | 1 Prometheus stack | **Single source of truth** |
| Setup Time | ~2 hours (complex) | ~10 minutes | **92% faster** |

### Monitoring Coverage
- ✅ **Pi-hole**: 100% uptime tracking, DNS query analysis
- ✅ **Docker Host**: Full system metrics (CPU, RAM, disk, network)
- ✅ **Extensible**: Easy to add more hosts by editing one config file

### Performance
- **Resource Usage**: <500MB RAM total for entire stack
- **Data Retention**: 15 days of metrics (configurable)
- **Scrape Interval**: 15 seconds (real-time dashboards)

---

## 🎓 Lessons Learned

### Technical Insights

**1. Simplicity Over Completeness**
- Started with "cover every scenario" approach (InfluxDB + Telegraf + Prometheus)
- Realized homelab doesn't need enterprise-grade complexity
- **Lesson**: Choose one tool that solves the core problem well

**2. Documentation is Technical Debt**
- Created 25+ markdown files documenting every edge case
- Made project harder to understand and maintain
- **Lesson**: One clear README > dozens of scattered docs

**3. Infrastructure as Code Pays Off**
- Docker Compose makes entire stack reproducible
- Can rebuild from scratch in minutes
- **Lesson**: Version-controlled infrastructure enables rapid iteration

**4. Monitoring Stack Trade-offs**
- Prometheus: Better for system/application metrics, simpler setup
- InfluxDB/Telegraf: Better for IoT/custom metrics, steeper learning curve
- **Lesson**: Match technology to use case, not resume-driven development

### Problem-Solving Approach

**Refactoring Strategy**:
1. ✅ Backed up all configs and documentation
2. ✅ Identified core requirements (Pi-hole + system metrics)
3. ✅ Selected single monitoring stack (Prometheus)
4. ✅ Removed unused services (InfluxDB, Telegraf, Windows exporters)
5. ✅ Consolidated documentation into one clear guide
6. ✅ Validated all targets reporting "UP" in Prometheus

**Result**: Transformed over-engineered project into maintainable homelab solution.

---

## 🚀 Quick Start

### Prerequisites
- Docker & Docker Compose
- Pi-hole instance (optional)

### Deployment
```bash
# 1. Clone repository
git clone <repo-url>
cd pihole_monitoring

# 2. Update Pi-hole IP in prometheus.yml
vim prometheus.yml  # Change line 21

# 3. Start stack
docker-compose up -d

# 4. Access Grafana
# HTTP: http://localhost:3000
# HTTPS: https://grafana.homelab.local (requires hosts entry)
# Login: admin/admin
```

### Add Pi-hole Monitoring
On Pi-hole host:
```bash
docker run -d \
  --name pihole-exporter \
  -p 9617:9617 \
  -e PIHOLE_HOSTNAME=localhost \
  -e PIHOLE_PASSWORD='your-password' \
  ekofr/pihole-exporter:latest
```

### Import Dashboards
1. Add Prometheus datasource: `http://prometheus:9090`
2. Import dashboards:
   - Pi-hole: Dashboard ID `10176`
   - Node Exporter: Dashboard ID `1860`

---

## 🔗 Links

- **Repository**: [GitHub Link]
- **Live Demo**: [Screenshots/GIFs]
- **Documentation**: [Full README](README.md)

---

## 📝 License

MIT License - Feel free to use for your own homelab!

---

**Built with ❤️ for homelabs everywhere**