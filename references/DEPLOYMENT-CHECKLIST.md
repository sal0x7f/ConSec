# ConSEC Project - Deployment Checklist

## ✅ Pre-Deployment Verification

### System Requirements
- [ ] VM/Host has Docker installed
- [ ] Docker Compose installed (v1.29+)
- [ ] Minimum 4GB RAM available
- [ ] Minimum 20GB disk space
- [ ] SSH access configured (for remote VM)
- [ ] Firewall allows port access (3000, 9090)

### Repository Setup
- [ ] Project files copied to VM (if using remote)
- [ ] All files are executable: `chmod +x deploy.sh entrypoints/*.sh`
- [ ] `.env.example` exists and is readable
- [ ] `docker-compose.yml` exists and is valid
- [ ] `Dockerfile` exists and is readable
- [ ] All configuration files in `configs/` are readable

---

## 🚀 Deployment Steps

### Step 1: Initial Setup
```bash
cd ~/Consec_project

# Create .env file
cp .env.example .env

# Review configuration
cat .env  # Make changes if needed
```
- [ ] .env created
- [ ] Configuration reviewed and customized
- [ ] Passwords changed from defaults

### Step 2: Choose Deployment Method

#### Option A: Makefile (Recommended)
```bash
make deploy
```
- [ ] Makefile is executable
- [ ] `make deploy` runs successfully
- [ ] All containers start without errors

#### Option B: Deployment Script
```bash
./deploy.sh 1
```
- [ ] deploy.sh is executable
- [ ] Script runs to completion
- [ ] All containers started

#### Option C: Manual
```bash
docker-compose build
docker-compose up -d
```
- [ ] Build completes without errors
- [ ] Containers start and remain running

### Step 3: Verify Deployment
```bash
# Check container status
docker-compose ps

# Expected output: All containers should show "Up" status
# • consec_grafana     - Up
# • consec_prometheus  - Up
# • consec_suricata    - Up
# • consec_zeek        - Up
```
- [ ] All containers show "Up" status
- [ ] No containers in "Exited" state
- [ ] Health checks passing (after 30 seconds)

### Step 4: Test Services

#### Grafana
```bash
curl http://localhost:3000/api/health
# Expected: {"database":"ok"}
```
- [ ] Grafana accessible
- [ ] Health check passes
- [ ] Can access http://localhost:3000

#### Prometheus
```bash
curl http://localhost:9090/-/healthy
# Expected: HTTP 200
```
- [ ] Prometheus accessible
- [ ] Health check passes
- [ ] Can access http://localhost:9090

#### Suricata & Zeek
```bash
docker-compose logs suricata | tail -20
docker-compose logs zeek | tail -20

# Should show process running, not errors
```
- [ ] Suricata logs show "running" status
- [ ] Zeek logs show "running" status
- [ ] No error messages in logs

### Step 5: Verify Data Collection
```bash
# Check if logs are being generated
ls -la consec_data/suricata_logs/
ls -la consec_data/zeek_logs/

# Should have recent files with data
```
- [ ] Suricata logs exist and have data
- [ ] Zeek logs exist and have data
- [ ] Timestamps show recent updates

---

## 🔌 Remote VM Setup (SSH Access)

### On Local Machine

#### Test SSH Connection
```bash
ssh user@vm-ip "docker ps"
# Should list running containers
```
- [ ] SSH connection works
- [ ] Docker accessible via SSH
- [ ] `docker ps` shows running containers

#### Create SSH Port Forwarding Tunnel
```bash
# Single command
ssh -L 3000:localhost:3000 -L 9090:localhost:9090 -N user@vm-ip

# Or in background
ssh -L 3000:localhost:3000 -L 9090:localhost:9090 -N user@vm-ip &
```
- [ ] SSH tunnel created successfully
- [ ] No "Permission denied" errors
- [ ] Tunnel remains active

#### Test Local Access Through Tunnel
```bash
curl http://localhost:3000/api/health
curl http://localhost:9090/-/healthy
```
- [ ] Can access Grafana through tunnel
- [ ] Can access Prometheus through tunnel
- [ ] HTTP responses are successful (200/OK)

---

## 📊 Service Verification

### Grafana Verification
- [ ] Accessible at http://localhost:3000
- [ ] Login page visible
- [ ] Default credentials work (admin/admin)
- [ ] Dashboard page loads
- [ ] Prometheus datasource exists
- [ ] Can view metrics

### Prometheus Verification
- [ ] Accessible at http://localhost:9090
- [ ] Expression browser loads
- [ ] Targets page shows all targets
- [ ] At least one target is "UP"
- [ ] Graph section allows metric queries
- [ ] Can query `up` metric

### Suricata Verification
- [ ] Container is running: `docker-compose ps suricata`
- [ ] Process active: `docker-compose exec suricata pgrep suricata`
- [ ] Log file exists: `ls consec_data/suricata_logs/eve.json`
- [ ] Log has recent data: `tail -1 consec_data/suricata_logs/eve.json`

### Zeek Verification
- [ ] Container is running: `docker-compose ps zeek`
- [ ] Process active: `docker-compose exec zeek pgrep zeek`
- [ ] Log directory exists: `ls consec_data/zeek_logs/`
- [ ] Logs have recent data: `ls -lt consec_data/zeek_logs/ | head -5`

---

## 🔧 Troubleshooting Checklist

### If Containers Won't Start
- [ ] Check logs: `docker-compose logs <service>`
- [ ] Verify images pulled: `docker images | grep -E 'grafana|prometheus|suricata|zeek'`
- [ ] Ensure ports not in use: `lsof -i :3000` and `lsof -i :9090`
- [ ] Check disk space: `df -h`
- [ ] Check memory: `free -h`
- [ ] Rebuild containers: `docker-compose build --no-cache`

### If SSH Tunnel Fails
- [ ] Verify SSH works: `ssh user@vm-ip "echo OK"`
- [ ] Check VM firewall: Can ports 3000/9090 be reached?
- [ ] Verify containers running on VM: `ssh user@vm-ip "docker-compose ps"`
- [ ] Check local ports: `lsof -i :3000` (may need different local port)
- [ ] Restart tunnel if stalled

### If Services Unreachable
- [ ] Verify tunnel is active: `ps aux | grep ssh`
- [ ] Test direct connection: `curl http://localhost:3000`
- [ ] Check container status: `docker-compose ps`
- [ ] Review container logs: `docker-compose logs -f`
- [ ] Test from inside container: `docker-compose exec grafana curl http://localhost:3000`

### If Data Not Appearing
- [ ] Check Prometheus targets: http://localhost:9090/targets
- [ ] Verify scrape interval: `curl http://localhost:9090/api/v1/query?query=up`
- [ ] Check Suricata running: `docker-compose exec suricata pgrep suricata`
- [ ] Check Zeek running: `docker-compose exec zeek pgrep zeek`
- [ ] Review interface configuration: `grep INTERFACE .env`

---

## 📋 Post-Deployment Configuration

### Grafana Setup
- [ ] Change admin password from "admin" to something secure
- [ ] Configure Prometheus datasource if not auto-discovered
- [ ] Import dashboards from community repository
- [ ] Set up alerts (optional)
- [ ] Configure email notifications (optional)

### Prometheus Configuration
- [ ] Verify scrape targets are working
- [ ] Configure retention policy in `.env` if needed
- [ ] Set up alerting rules (optional)
- [ ] Configure alertmanager (optional)

### Network Interface Configuration
- [ ] Verify Suricata is monitoring correct interface
- [ ] Verify Zeek is monitoring correct interface
- [ ] Check interface name: `ip link show`
- [ ] Update `.env` if interface name is different
- [ ] Restart services if interface changed: `docker-compose restart`

---

## 🔐 Security Checklist

### Passwords & Credentials
- [ ] Changed Grafana default password (admin/admin)
- [ ] Set `GRAFANA_PASSWORD` in `.env` before deployment
- [ ] No hardcoded credentials in git
- [ ] `.env` file is in `.gitignore` (if using git)

### Access Control
- [ ] SSH key-based auth configured (not password-based)
- [ ] SSH tunnel used for remote access (not exposed ports)
- [ ] Firewall rules restrict unnecessary access
- [ ] Default ports changed if necessary

### Data Protection
- [ ] Regular backups of `consec_data/` scheduled
- [ ] Logs rotated to prevent disk fill
- [ ] Sensitive logs not exposed publicly

---

## 📈 Performance Verification

### Resource Usage
```bash
docker stats --no-stream
# Note typical memory/CPU usage
```
- [ ] Grafana: < 500MB RAM
- [ ] Prometheus: < 1GB RAM
- [ ] Suricata: < 1GB RAM
- [ ] Zeek: < 500MB RAM
- [ ] Total: < 4GB RAM (adjust if you have more)

### Disk Usage
```bash
du -sh consec_data/*
```
- [ ] Suricata logs not exceeding disk space
- [ ] Prometheus TSDB reasonable size
- [ ] Sufficient free disk space remaining

### Network Performance
```bash
# Monitor traffic
docker stats --no-stream
```
- [ ] No excessive network I/O
- [ ] Services responding promptly
- [ ] No connection timeouts

---

## ✅ Final Verification

Run this final verification command:

```bash
# Create SSH tunnel (if remote)
ssh -L 3000:localhost:3000 -L 9090:localhost:9090 -N user@vm-ip &

# Run verification
docker-compose ps && \
curl -s http://localhost:3000/api/health && \
curl -s http://localhost:9090/-/healthy && \
echo "✓ All checks passed!"
```

Successful output should show:
- [ ] All containers with "Up" status
- [ ] Grafana health check: `{"database":"ok"}`
- [ ] Prometheus health check: HTTP 200
- [ ] "✓ All checks passed!" message

---

## 📞 Support Resources

- **Documentation**: See README.md
- **SSH Tunneling**: See SSH-PORT-FORWARDING.md
- **Commands**: See QUICK-REFERENCE.md or `make help`
- **Optimization Details**: See OPTIMIZATION-SUMMARY.md
- **Docker Logs**: `docker-compose logs -f`
- **Container Shells**: `docker-compose exec <service> /bin/bash`

---

## 🎉 Deployment Complete!

Once all checkboxes are marked, your ConSEC stack is:
- ✅ Deployed
- ✅ Verified
- ✅ Operational
- ✅ Secure
- ✅ Monitored

### Next Steps:
1. Configure Grafana dashboards
2. Set up custom Suricata rules
3. Create Zeek monitoring scripts
4. Configure alerts
5. Schedule data backups

**Status**: Ready for Production Monitoring
