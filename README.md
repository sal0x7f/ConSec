# ConSEC - Container Security Monitoring Stack

A comprehensive Docker-based security monitoring stack combining **Prometheus**, **Grafana**, **Suricata** (Network IDS), and **Zeek** (Network Analysis) for network security monitoring and visualization.

## 📋 Overview

- **Grafana**: Interactive dashboards for security metrics visualization
- **Prometheus**: Time-series metrics collection and alerting
- **Suricata**: High-performance Network Intrusion Detection System (NIDS)
- **Zeek**: Network traffic analysis and forensics
- **Docker Compose**: Orchestrated multi-container deployment
- **SSH Port Forwarding**: Secure remote access via SSH tunnels

## 🚀 Quick Start

### Prerequisites
- Docker (v20.10+)
- Docker Compose (v1.29+)
- SSH access to VM (if deploying remotely)
- Minimum 4GB RAM, 20GB disk space

### Local/VM Installation

#### Option 1: Automated Deployment Script (Recommended)

```bash
# Clone/navigate to project directory
cd ~/Consec_project

# Run deployment script with full setup
./deploy.sh 1

# Or run interactively
./deploy.sh
```

#### Option 2: Manual Setup

```bash
# Setup environment
cp .env.example .env
mkdir -p consec_data/{grafana,prometheus,suricata_logs,zeek_logs}

# Build and start
docker-compose build
docker-compose up -d

# Verify
docker-compose ps
```

## 🌐 Access Services

### From Local Machine

**Using SSH Port Forwarding** (Recommended for remote VMs):

```bash
# Forward all services to localhost
ssh -L 3000:localhost:3000 -L 9090:localhost:9090 -N user@vm-ip

# In another terminal, access:
# Grafana: http://localhost:3000 (admin/admin)
# Prometheus: http://localhost:9090
```

### Direct Access (Local or Same Network)

- **Grafana**: http://localhost:3000 (Default: admin/admin)
- **Prometheus**: http://localhost:9090

## 🔧 Configuration

### Environment Variables

Copy `.env.example` to `.env`:

```bash
cp .env.example .env
```

Customize as needed:
```env
GRAFANA_PASSWORD=your_secure_password
SURICATA_INTERFACE=eth0
ZEEK_INTERFACE=eth0
PROMETHEUS_RETENTION=30d
```

### Network Interfaces

Update interface names in `.env` if your system uses different interface names:
- `eth0` (default)
- `ens0` (common on VMs)
- `wlan0` (wireless)

To find your interface:
```bash
ip link show
```

### Suricata Configuration

Edit `configs/suricata/suricata.yaml`:
- Set appropriate logging level
- Configure rule files in `configs/suricata/rules/`
- Add custom rules in `configs/suricata/rules/custom.rules`

### Zeek Configuration

Add custom scripts to `configs/zeek/scripts/local/`

## 📊 Monitoring

### View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f grafana
docker-compose logs -f prometheus
docker-compose logs -f suricata
docker-compose logs -f zeek

# Application logs
tail -f consec_data/suricata_logs/eve.json
tail -f consec_data/zeek_logs/*.log
```

### Check Container Status

```bash
docker-compose ps
docker stats
```

## 🔌 SSH Port Forwarding (VM/Remote Access)

See [SSH-PORT-FORWARDING.md](SSH-PORT-FORWARDING.md) for detailed instructions on:
- SSH tunnel setup
- Port mapping reference
- Persistent tunnel creation
- Troubleshooting

### Quick Command

```bash
# From local machine - creates SSH tunnel
ssh -L 3000:localhost:3000 -L 9090:localhost:9090 -N user@192.168.x.x

# Now access locally
# Grafana: http://localhost:3000
# Prometheus: http://localhost:9090
```

## 📦 Docker Build Optimization

The Dockerfile uses multi-stage builds for efficiency:
- **Stage 1**: Builder with build tools
- **Stage 2**: Runtime with only runtime dependencies
- Result: ~30% smaller image size
- Health checks included for all services

### Manual Build

```bash
docker build -t consec-base:latest .
docker-compose build
```

## 🛠️ Useful Commands

```bash
# Start services
docker-compose up -d

# Stop services
docker-compose down

# Rebuild after config changes
docker-compose up -d --force-recreate

# Execute command in container
docker-compose exec suricata suricata-update -r

# Remove everything including volumes
docker-compose down -v

# View network
docker network inspect consec_project_monitoring_net

# Show stats
docker stats --no-stream
```

## 📁 Directory Structure

```
consec_project/
├── Dockerfile              # Multi-stage build definition
├── docker-compose.yml      # Service orchestration
├── deploy.sh              # Deployment automation script
├── .env.example           # Configuration template
├── SSH-PORT-FORWARDING.md # SSH tunnel guide
├── configs/
│   ├── prometheus.yml     # Prometheus config
│   ├── suricata/
│   │   ├── suricata.yaml  # Suricata config
│   │   └── rules/
│   │       └── custom.rules
│   └── zeek/
│       └── scripts/
│           └── local/     # Custom Zeek scripts
├── entrypoints/
│   ├── start-suricata.sh  # Suricata startup
│   └── start-zeek.sh      # Zeek startup
└── consec_data/
    ├── grafana/           # Grafana data
    ├── prometheus/        # Prometheus TSDB
    ├── suricata_logs/     # Suricata logs
    └── zeek_logs/         # Zeek logs
```

## 🔒 Security Considerations

### Production Deployment
1. Change default Grafana password (`.env`)
2. Use HTTPS/TLS for external access
3. Configure Prometheus authentication
4. Implement firewall rules
5. Use SSH key-based authentication
6. Run with non-root user (already configured)

### Network Isolation
- Services use internal `monitoring_net` bridge network
- Only Prometheus (9090) and Grafana (3000) exposed
- Suricata/Zeek run in isolated network namespace

## 🐛 Troubleshooting

### Port Already in Use
```bash
# Check what's using a port
lsof -i :3000

# Use different local port in SSH tunnel
ssh -L 4000:localhost:3000 user@vm-ip
```

### Docker Compose Issues
```bash
# Rebuild from scratch
docker-compose down -v
docker-compose build --no-cache
docker-compose up -d
```

### Network Interface Not Found
```bash
# List available interfaces
ip link show

# Update .env and docker-compose.yml with correct interface
sed -i 's/eth0/ens0/g' .env
```

### Container Fails to Start
```bash
# Check logs
docker-compose logs -f <service-name>

# Inspect container
docker inspect consec_<service>
```

## 📚 Additional Resources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Suricata Documentation](https://docs.suricata.io/)
- [Zeek Documentation](https://docs.zeek.org/)
- [Docker Documentation](https://docs.docker.com/)

## 📝 License

This project combines open-source monitoring and security tools. See individual component licenses.

## ✅ Verification Checklist

After deployment, verify:
- [ ] All containers are running: `docker-compose ps`
- [ ] Grafana is accessible at http://localhost:3000
- [ ] Prometheus is accessible at http://localhost:9090
- [ ] Suricata logs exist: `ls consec_data/suricata_logs/`
- [ ] Zeek logs exist: `ls consec_data/zeek_logs/`
- [ ] SSH port forwarding works (if on VM)
- [ ] Health checks pass: `docker-compose ps` (status UP)

---

**Version**: 1.0  
**Last Updated**: 2026-11-8  
**Maintainer**: ConSEC Team
