# Homelab Improvement Roadmap

> Strategic plan to build a portfolio-worthy homelab with production-grade monitoring, logging, and automation.

**Focus**: Resume-building skills for DevOps/SRE roles
**Timeline**: 3 phases, ~2-4 weeks each
**Current Stack**: ✅ Prometheus, Grafana, Caddy, Node Exporter

---

## 📊 Roadmap Overview

```
Current State              Phase 1                Phase 2                Phase 3
                          (Week 1-2)             (Week 3-4)             (Week 5-8)

┌──────────┐              ┌──────────┐           ┌──────────┐          ┌──────────┐
│Prometheus│              │Prometheus│           │Prometheus│          │ Ansible  │
│ Grafana  │──────────▶   │ Grafana  │──────▶    │ Grafana  │──────▶   │Terraform │
│  Caddy   │   Alerting   │Alertmgr  │  Logging  │   Loki   │  IaC     │  GitOps  │
└──────────┘              │  ntfy    │           │ Promtail │          │          │
                          └──────────┘           └──────────┘          └──────────┘

 Monitoring               + Alerting             + Logging             + Automation

 Resume Value:            Resume Value:          Resume Value:         Resume Value:
 ⭐⭐⭐                    ⭐⭐⭐⭐                ⭐⭐⭐⭐⭐             ⭐⭐⭐⭐⭐
```

---

## 🚀 Phase 1: Alerting & Notifications (2 weeks)

**Goal**: Get notified when things break before you notice manually.

### What You'll Build

```
┌─────────────────────────────────────────────────┐
│           Prometheus Alert Rules                │
│  • Pi-hole Down (no scrape for 2 min)          │
│  • High CPU (>80% for 5 min)                    │
│  • Disk Space Low (<10% free)                   │
│  • Memory Pressure (>90% used)                  │
└─────────────────┬───────────────────────────────┘
                  │ Fires Alert
                  ▼
         ┌────────────────┐
         │  Alertmanager  │
         │  (Routing &    │
         │   Silencing)   │
         └────────┬───────┘
                  │
         ┌────────┴────────┐
         │                 │
         ▼                 ▼
    ┌────────┐      ┌──────────┐
    │  ntfy  │      │  Email   │
    │(Mobile)│      │(Backup)  │
    └────────┘      └──────────┘
```

### Tech Stack
- **Alertmanager**: Alert routing, grouping, silencing
- **ntfy**: Free push notifications (no accounts needed)
- **Prometheus Alert Rules**: Define when to alert

### Implementation

**1. Add Alertmanager to docker-compose.yml**
```yaml
alertmanager:
  image: prom/alertmanager:latest
  container_name: alertmanager
  ports:
    - "9093:9093"
  volumes:
    - ./alertmanager.yml:/etc/alertmanager/alertmanager.yml:ro
    - alertmanager-data:/alertmanager
  networks:
    - monitoring
  restart: unless-stopped
```

**2. Create alert rules (prometheus/alerts.yml)**
```yaml
groups:
  - name: homelab
    interval: 30s
    rules:
      - alert: PiHoleDown
        expr: up{job="pihole"} == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Pi-hole is down"
          description: "Pi-hole has been unreachable for 2 minutes"

      - alert: HighCPU
        expr: 100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage on {{ $labels.instance }}"
          description: "CPU usage is {{ $value }}%"

      - alert: DiskSpaceLow
        expr: (node_filesystem_avail_bytes / node_filesystem_size_bytes) * 100 < 10
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Low disk space on {{ $labels.instance }}"
          description: "Only {{ $value }}% free space remaining"
```

**3. Configure ntfy for mobile notifications**
- No account needed, just pick a unique topic: `ntfy.sh/your-unique-homelab-alerts`
- Install ntfy app on phone, subscribe to your topic
- Get instant push notifications

### Resume Keywords
✅ Prometheus Alertmanager
✅ Alert rule configuration
✅ Incident response automation
✅ SLO/SLA monitoring

### Time Investment: ~4-6 hours

---

## 🔍 Phase 2: Centralized Logging (2 weeks)

**Goal**: Debug issues by searching logs in one place instead of SSH'ing to each server.

### What You'll Build

```
┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│ Docker Host  │   │  Pi-hole     │   │   RPi #2     │
│              │   │              │   │              │
│  Promtail    │   │  Promtail    │   │  Promtail    │
│  (Log Agent) │   │  (Log Agent) │   │  (Log Agent) │
└──────┬───────┘   └──────┬───────┘   └──────┬───────┘
       │                  │                  │
       │ Streams logs     │                  │
       └──────────────────┼──────────────────┘
                          │
                          ▼
                  ┌───────────────┐
                  │     Loki      │
                  │ (Log Storage) │
                  └───────┬───────┘
                          │
                          │ Query logs
                          ▼
                  ┌───────────────┐
                  │    Grafana    │
                  │ (Explore Logs)│
                  └───────────────┘
```

### Tech Stack
- **Loki**: Log aggregation (like Prometheus but for logs)
- **Promtail**: Log shipper (runs on each host)
- **Grafana**: Unified interface for metrics + logs

### What You Get
- Search logs across all servers: `{job="pihole"} |= "error"`
- Correlate logs with metrics (see logs when CPU spikes)
- Tail logs in real-time from Grafana
- Retention policies (keep logs for 30 days)

### Implementation

**1. Add Loki to docker-compose.yml**
```yaml
loki:
  image: grafana/loki:latest
  container_name: loki
  ports:
    - "3100:3100"
  volumes:
    - ./loki-config.yml:/etc/loki/local-config.yaml:ro
    - loki-data:/loki
  networks:
    - monitoring
  restart: unless-stopped

promtail:
  image: grafana/promtail:latest
  container_name: promtail
  volumes:
    - ./promtail-config.yml:/etc/promtail/config.yml:ro
    - /var/log:/var/log:ro
    - /var/lib/docker/containers:/var/lib/docker/containers:ro
  networks:
    - monitoring
  restart: unless-stopped
```

**2. Configure Grafana datasource**
Add Loki as datasource alongside Prometheus

**3. Deploy Promtail to other hosts**
Simple systemd service or Docker container on each Pi/server

### Resume Keywords
✅ Grafana Loki
✅ Log aggregation & analysis
✅ Distributed tracing
✅ Observability stack (Metrics + Logs + Traces)

### Time Investment: ~6-8 hours

---

## 🤖 Phase 3: Infrastructure as Code (3-4 weeks)

**Goal**: Deploy entire homelab with one command. Version control everything.

### What You'll Build

```
┌─────────────────────────────────────────────────┐
│              Git Repository                      │
│  • Ansible playbooks                            │
│  • Docker Compose files                         │
│  • Prometheus/Loki configs                      │
│  • Alert rules                                   │
└─────────────────┬───────────────────────────────┘
                  │
                  │ git push
                  ▼
         ┌─────────────────┐
         │  Control Node   │
         │  (Your Laptop)  │
         │                 │
         │  $ ansible-playbook deploy.yml
         └────────┬────────┘
                  │
      ┌───────────┼───────────┐
      │           │           │
      ▼           ▼           ▼
┌──────────┐ ┌──────────┐ ┌──────────┐
│ Docker   │ │ Pi-hole  │ │  RPi #2  │
│  Host    │ │          │ │          │
│          │ │          │ │          │
│ • Install│ │ • Install│ │ • Install│
│   Docker │ │   node-  │ │   node-  │
│ • Deploy │ │   exporter│ │  exporter│
│   stack  │ │ • Config │ │ • Config │
└──────────┘ └──────────┘ └──────────┘
```

### Tech Stack
- **Ansible**: Configuration management (no agents needed)
- **Git**: Version control for infrastructure
- **Docker Compose**: Application orchestration
- **Make**: Simple CLI interface (`make deploy`)

### What You Get
- One command deploys entire homelab: `ansible-playbook site.yml`
- Idempotent deployments (safe to re-run)
- Disaster recovery (rebuild from scratch in minutes)
- Version-controlled infrastructure changes
- Test changes in dev before production

### Implementation

**1. Ansible Inventory (hosts.yml)**
```yaml
all:
  children:
    monitoring:
      hosts:
        docker-host:
          ansible_host: 172.17.8.182

    pihole:
      hosts:
        pihole-1:
          ansible_host: 192.168.1.200

    nodes:
      hosts:
        rpi-1:
          ansible_host: 192.168.1.201
        rpi-2:
          ansible_host: 192.168.1.202
```

**2. Ansible Playbook (site.yml)**
```yaml
- name: Deploy Monitoring Stack
  hosts: monitoring
  roles:
    - docker
    - prometheus
    - grafana
    - loki

- name: Deploy Node Exporters
  hosts: all
  roles:
    - node-exporter

- name: Deploy Pi-hole Exporter
  hosts: pihole
  roles:
    - pihole-exporter
```

**3. Makefile for easy commands**
```makefile
deploy:
	ansible-playbook -i hosts.yml site.yml

update:
	ansible-playbook -i hosts.yml site.yml --tags update

backup:
	ansible-playbook -i hosts.yml backup.yml
```

### Advanced: GitOps with Flux/ArgoCD (Optional)
- Auto-deploy on git push
- Declarative infrastructure
- Built-in rollback

### Resume Keywords
✅ Ansible automation
✅ Infrastructure as Code (IaC)
✅ Configuration management
✅ GitOps workflows
✅ CI/CD pipelines

### Time Investment: ~12-16 hours

---

## 📈 Resume Impact

### Before
```
Skills:
- Docker
- Basic monitoring
```

### After All 3 Phases
```
Technical Skills:
- Monitoring & Observability: Prometheus, Grafana, Alertmanager, Loki
- Infrastructure as Code: Ansible, Docker Compose
- Incident Response: Alert rule configuration, on-call setup
- Logging & Analysis: Centralized log aggregation, log-based alerting
- Automation: Configuration management, GitOps workflows
- Security: HTTPS/TLS, secret management
- High Availability: Automated backups, disaster recovery procedures

Projects:
Production-Grade Homelab Infrastructure
• Designed and deployed full observability stack (Prometheus, Grafana, Loki)
• Implemented automated alerting with Alertmanager and mobile notifications
• Automated infrastructure deployment using Ansible (IaC)
• Centralized logging across 5+ hosts with Grafana Loki
• Achieved 99.9% uptime through proactive monitoring and alerts
```

---

## 🎯 Quick Wins (Weekend Projects)

Between phases, add these for extra portfolio points:

### 1. Uptime Monitoring (2 hours)
- **Tool**: Uptime Kuma
- **What**: Beautiful status page, ping monitoring
- **Resume**: "Implemented uptime monitoring with public status page"

### 2. Backup Validation (1 hour)
- **Action**: Schedule monthly backup restoration tests
- **Resume**: "Validated disaster recovery procedures with automated testing"

### 3. Documentation as Code (1 hour)
- **Tool**: MkDocs or Docusaurus
- **What**: Turn your docs into a searchable website
- **Resume**: "Created technical documentation site for infrastructure"

### 4. Security Scanning (2 hours)
- **Tool**: Trivy (scan Docker images)
- **What**: Automated vulnerability scanning
- **Resume**: "Implemented security scanning in CI/CD pipeline"

---

## 📚 Learning Resources

### Phase 1 (Alerting)
- Prometheus Alerting Docs: https://prometheus.io/docs/alerting/
- Awesome Prometheus Alerts: https://github.com/samber/awesome-prometheus-alerts
- ntfy.sh Documentation

### Phase 2 (Logging)
- Grafana Loki Tutorial: https://grafana.com/docs/loki/latest/
- LogQL Query Language
- Promtail Configuration

### Phase 3 (Automation)
- Ansible for DevOps (book)
- Jeff Geerling's Ansible YouTube series
- Ansible Galaxy (community roles)

---

## 🎓 Interview Talking Points

**Q: "Tell me about a project where you improved observability"**

**A**: "I built a complete observability stack for my homelab infrastructure. Started with Prometheus for metrics, added Alertmanager for proactive alerting with mobile notifications, then integrated Loki for centralized logging. This gave me full visibility across 5+ hosts. When issues occurred, I could correlate logs and metrics to quickly identify root cause. The alert rules I configured caught problems like disk space running low or services going down before they impacted users. I also automated the entire deployment with Ansible so the infrastructure could be rebuilt from scratch in under 10 minutes."

**Keywords hit**: Observability, Prometheus, Alertmanager, Loki, automation, incident response, root cause analysis

---

## 🚦 Getting Started

### This Week
1. ✅ Review current monitoring setup
2. ⬜ Choose Phase 1 start date
3. ⬜ Set up ntfy.sh mobile app
4. ⬜ Draft first alert rules (Pi-hole down, high CPU)

### This Month
- Complete Phase 1 (Alerting)
- Start Phase 2 (Logging)

### This Quarter
- Complete all 3 phases
- Add 1-2 quick wins
- Update resume/portfolio
- Blog about the journey

---

**Questions? Want help implementing any phase? Just ask!**