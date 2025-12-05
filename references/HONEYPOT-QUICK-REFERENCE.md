# ConSEC Honeypot - Quick Command Reference

**Updated:** November 27, 2025

---

## SERVICE MANAGEMENT

### Check Status
```bash
# All services
docker compose ps

# Just honeypot
docker compose ps honeypot

# Detailed health
docker compose ps --format "table {{.Service}}\t{{.Status}}"
```

### Start/Stop Services
```bash
# Start all services
docker compose up -d

# Start honeypot only
docker compose up -d honeypot

# Stop honeypot
docker compose stop honeypot

# Restart honeypot
docker compose restart honeypot

# Rebuild honeypot image
docker compose build honeypot

# Rebuild and restart
docker compose up -d --build honeypot
```

### View Logs
```bash
# Real-time honeypot logs
docker compose logs -f honeypot

# Last 50 lines
docker compose logs --tail=50 honeypot

# Search logs for patterns
docker compose logs honeypot | grep -i "attack\|brute\|injection"

# View raw log file
tail -f /home/usersal/Consec_project/consec_data/honeypot_logs/honeypot.log
```

---

## METRICS & MONITORING

### Check Honeypot Metrics
```bash
# All honeypot metrics
curl http://localhost:9445/metrics | grep "honeypot_"

# Connection metrics
curl -s http://localhost:9445/metrics | grep "honeypot_connections_total"

# Attack patterns
curl -s http://localhost:9445/metrics | grep "honeypot_attack_attempts"

# Alerts
curl -s http://localhost:9445/metrics | grep "honeypot_alerts_total"
```

### Query Prometheus
```bash
# Query Prometheus API
curl 'http://localhost:9090/api/v1/query?query=honeypot_connections_total'

# Pretty print results
curl -s 'http://localhost:9090/api/v1/query?query=honeypot_connections_total' | jq '.'

# Specific metric by service
curl -s 'http://localhost:9090/api/v1/query?query=honeypot_connections_total{service="ssh"}'

# Get alert status
curl -s 'http://localhost:9090/api/v1/rules' | grep honeypot
```

---

## PORT VERIFICATION

### Check Honeypot Ports
```bash
# All honeypot ports
for port in 2222 2323 5502 8080 9445; do
  nc -zv localhost $port && echo "✓ Port $port open"
done

# Individual ports
nc -zv localhost 2222    # SSH
nc -zv localhost 2323    # Telnet
nc -zv localhost 5502    # MODBUS
nc -zv localhost 8080    # HTTP
nc -zv localhost 9445    # Metrics

# Using netstat
netstat -tulnp | grep -E "2222|2323|5502|8080|9445"

# Using ss
ss -tulnp | grep -E "2222|2323|5502|8080|9445"
```

---

## ATTACK SIMULATION

### SSH Test
```bash
# Connect to SSH honeypot
ssh -o ConnectTimeout=2 localhost -p 2222

# Or via telnet
(echo "test"; sleep 1) | telnet localhost 2222

# Via netcat
echo "" | nc localhost 2222
```

### Telnet Test
```bash
# Connect to Telnet honeypot
telnet localhost 2323

# Via netcat
(echo "root"; echo "password"; sleep 1) | nc localhost 2323
```

### MODBUS Test
```bash
# Send MODBUS frame
echo -ne "\x01\x03\x00\x00\x00\x0A" | nc localhost 5502
```

### HTTP Test
```bash
# Simple HTTP request
curl http://localhost:8080/

# SQL injection attempt
curl "http://localhost:8080/?id=1' UNION SELECT * FROM users--"

# Path traversal attempt
curl "http://localhost:8080/../../../etc/passwd"
```

---

## ANALYSIS & TROUBLESHOOTING

### Check Container Resources
```bash
# Memory and CPU usage
docker stats honeypot

# Detailed container info
docker inspect honeypot | grep -A 20 "HostConfig"

# Disk usage
du -sh /home/usersal/Consec_project/consec_data/honeypot_logs/
```

### Verify Prometheus Integration
```bash
# Check honeypot job status
curl -s 'http://localhost:9090/api/v1/targets' | jq '.data.activeTargets[] | select(.labels.job=="honeypot")'

# Check scrape duration
curl -s 'http://localhost:9090/api/v1/query?query=scrape_duration_seconds{job="honeypot"}' | jq '.data.result'

# Check last scrape
curl -s 'http://localhost:9090/api/v1/query?query=scrape_samples_scraped{job="honeypot"}' | jq '.data.result'
```

### Check Network Connectivity
```bash
# From host to honeypot container
ping -c 3 172.20.0.2  # Honeypot container IP

# From host to other containers
ping -c 3 172.20.0.3  # Prometheus
ping -c 3 172.20.0.4  # Grafana

# List all container IPs
docker network inspect monitoring_net | grep -A 10 "Containers"
```

### Verify Prometheus Config
```bash
# Check config was loaded
curl -s http://localhost:9090/api/v1/metadata | grep honeypot

# View raw prometheus config
docker exec consec_prometheus cat /etc/prometheus/prometheus.yml | grep -A 5 honeypot

# Reload config (if edited)
docker compose exec prometheus kill -HUP 1
```

---

## LOGGING & LOG ANALYSIS

### View Honeypot Log Statistics
```bash
# Connection count by service
grep "connection" /consec_data/honeypot_logs/honeypot.log | awk '{print $NF}' | sort | uniq -c

# Attack pattern count
grep "WARNING" /consec_data/honeypot_logs/honeypot.log | wc -l

# Unique source IPs
grep "from" /consec_data/honeypot_logs/honeypot.log | grep -oE "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | sort | uniq

# Top attacked port
grep "port" /consec_data/honeypot_logs/honeypot.log | awk '{print $(NF-1)}' | sort | uniq -c | sort -rn
```

### Export Logs
```bash
# Copy logs to file
cp /consec_data/honeypot_logs/honeypot.log ~/honeypot_backup_$(date +%Y%m%d).log

# Compress logs
tar -czf honeypot_logs_$(date +%Y%m%d_%H%M%S).tar.gz /consec_data/honeypot_logs/

# Search across log history
find /consec_data/honeypot_logs/ -name "*.log" -exec grep "pattern" {} \;
```

---

## MAINTENANCE

### Backup Configuration
```bash
# Backup honeypot.py
cp honeypot/honeypot.py honeypot/honeypot.py.backup.$(date +%s)

# Backup docker-compose
cp docker-compose.yml docker-compose.yml.backup.$(date +%s)

# Backup prometheus config
cp configs/prometheus.yml configs/prometheus.yml.backup.$(date +%s)
```

### Clean Logs
```bash
# Clear current logs
echo "" > /consec_data/honeypot_logs/honeypot.log

# Archive and clear (keep last 7 days)
find /consec_data/honeypot_logs/ -name "*.log" -mtime +7 -delete

# Compress old logs
for f in /consec_data/honeypot_logs/*.log.old; do
  gzip "$f"
done
```

### Database Cleanup (Prometheus)
```bash
# View TSDB size
du -sh /home/usersal/Consec_project/consec_data/prometheus/

# Cleanup old data (keep 30 days)
docker compose exec prometheus \
  find /prometheus -type f -name "*.db" -mtime +30 -delete

# Force Prometheus compaction
docker compose exec prometheus \
  kill -USR2 1
```

---

## GRAFANA INTEGRATION

### Access Grafana
```bash
# Open in browser
http://localhost:3000

# Default credentials
username: admin
password: admin (change on first login)
```

### Add Honeypot Queries
```
# SSH Connections Over Time
rate(honeypot_connections_total{service="ssh"}[1m])

# Attack Distribution
sum by (pattern) (honeypot_attack_attempts_total)

# Alert Severity
sum by (severity) (honeypot_alerts_total)

# Top Attackers
topk(10, sum by (source_ip) (honeypot_connections_total))
```

### Create Dashboard Panels

**Panel 1: Real-Time Attacks**
- Query: `rate(honeypot_connections_total[30s])`
- Type: Graph
- Legend: `{{ service }}`

**Panel 2: Attack Types**
- Query: `sum by (pattern) (honeypot_attack_attempts_total)`
- Type: Pie Chart

**Panel 3: Alert Status**
- Query: `honeypot_alerts_total`
- Type: Gauge
- Threshold: 0, 5, 10

---

## PERFORMANCE TESTING

### Load Test
```bash
# Simulate 100 connections in 10 seconds
for i in {1..100}; do
  (timeout 1 nc localhost 2222 &) 
  sleep 0.1
done

# Monitor resource usage
watch -n 1 'docker stats honeypot --no-stream'
```

### Metrics Throughput
```bash
# Measure metrics endpoint response time
time curl http://localhost:9445/metrics > /dev/null

# Measure Prometheus query time
time curl 'http://localhost:9090/api/v1/query?query=honeypot_connections_total'

# Measure scrape frequency
curl -s 'http://localhost:9090/api/v1/query_range?query=up{job="honeypot"}&start=1&end=2&step=1'
```

---

## COMMON ISSUES & FIXES

### Issue: "Connection refused" on port 2222

**Solution:**
```bash
# Check if honeypot is running
docker compose ps honeypot

# Restart honeypot
docker compose restart honeypot

# Check logs
docker compose logs honeypot | tail -20
```

### Issue: Prometheus not scraping metrics

**Solution:**
```bash
# Verify honeypot job config
docker exec consec_prometheus cat /etc/prometheus/prometheus.yml | grep -A 5 honeypot

# Restart Prometheus
docker compose restart prometheus

# Check targets
curl -s http://localhost:9090/api/v1/targets | jq '.'
```

### Issue: No metrics appearing in Grafana

**Solution:**
```bash
# Check Prometheus datasource
curl http://localhost:9090/-/healthy

# Test PromQL query
curl 'http://localhost:9090/api/v1/query?query=honeypot_connections_total'

# Refresh Grafana data source
# In Grafana UI: Configuration → Data Sources → Prometheus → Test
```

### Issue: High CPU usage

**Solution:**
```bash
# Check container stats
docker stats honeypot

# Reduce log verbosity
# In honeypot/honeypot.py: Change LOG_LEVEL to "WARNING"

# Reduce Prometheus scrape interval
# In prometheus.yml: Increase scrape_interval to 30s
```

---

## USEFUL ALIASES

Add to `~/.bashrc`:

```bash
alias consec-ps='docker compose ps'
alias consec-logs='docker compose logs -f honeypot'
alias consec-restart='docker compose restart honeypot'
alias consec-metrics='curl -s http://localhost:9445/metrics | grep honeypot_'
alias consec-test-ssh='timeout 2 nc localhost 2222'
alias consec-test-telnet='timeout 2 nc localhost 2323'
alias consec-status='docker compose ps; echo "---"; curl -s http://localhost:9445/metrics | wc -l'
```

---

## ENVIRONMENT VARIABLES

```bash
# Project root
export CONSEC_ROOT="/home/usersal/Consec_project"

# Key paths
export HONEYPOT_LOGS="$CONSEC_ROOT/consec_data/honeypot_logs"
export HONEYPOT_CODE="$CONSEC_ROOT/honeypot"

# Service endpoints
export HONEYPOT_METRICS="http://localhost:9445/metrics"
export PROMETHEUS_API="http://localhost:9090/api/v1"
export GRAFANA_URL="http://localhost:3000"

# Container names
export HONEYPOT_CONTAINER="consec_honeypot"
export PROMETHEUS_CONTAINER="consec_prometheus"
```

---

**Quick Reference Version:** 1.0
**Last Updated:** November 27, 2025
