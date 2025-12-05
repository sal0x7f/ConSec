# ConSEC Honeypot - Metrics Reference Guide

**Last Updated:** November 27, 2025

---

## METRICS OVERVIEW

The honeypot exports 6 core metrics to Prometheus, all prefixed with `honeypot_`.

| Metric Name | Type | Labels | Purpose |
|------------|------|--------|---------|
| `honeypot_connections_total` | Counter | port, source_ip, service | Total connections tracked per service |
| `honeypot_attack_attempts_total` | Counter | pattern, source_ip, port | Attack patterns detected |
| `honeypot_alerts_total` | Counter | severity, service, source_ip | Severity-categorized alerts |
| `honeypot_payload_size_bytes` | Histogram | service, port | Payload size distribution |
| `honeypot_session_duration_seconds` | Histogram | service, port | Session length tracking |
| `honeypot_unique_attackers` | Gauge | N/A | Count of unique attacker IPs |

---

## DETAILED METRIC DEFINITIONS

### 1. honeypot_connections_total

**Type:** Counter (monotonically increasing)

**Purpose:** Track total number of connections to each honeypot service.

**Labels:**
- `port`: Honeypot port (2222, 2323, 5502, 8080)
- `service`: Service type (ssh, telnet, modbus, http)
- `source_ip`: Client IP address making connection

**PromQL Examples:**
```
# Total connections across all services
sum(honeypot_connections_total)

# Connections per service
sum by (service) (honeypot_connections_total)

# Rate of SSH connections
rate(honeypot_connections_total{service="ssh"}[1m])
```

---

### 2. honeypot_attack_attempts_total

**Type:** Counter

**Purpose:** Track detected attack patterns and categorize them.

**Labels:**
- `pattern`: Attack type (ssh_brute_force, telnet_brute_force, modbus_write, sql_injection, path_traversal)
- `source_ip`: Attacker IP address
- `port`: Honeypot port

**Attack Patterns Detected:**
- `ssh_brute_force`: Multiple SSH connection attempts
- `telnet_brute_force`: Rapid login attempts on Telnet
- `modbus_write`: MODBUS function 5, 6, or 16 (write operations)
- `sql_injection`: SQL keywords in HTTP payload
- `path_traversal`: Path traversal attempts in HTTP payload

**PromQL Examples:**
```
# Total attack attempts
sum(honeypot_attack_attempts_total)

# Attack attempts by pattern
sum by (pattern) (honeypot_attack_attempts_total)

# SQL injection attempts only
honeypot_attack_attempts_total{pattern="sql_injection"}
```

---

### 3. honeypot_alerts_total

**Type:** Counter

**Purpose:** Track security alerts categorized by severity level.

**Labels:**
- `severity`: Alert severity (low, medium, high)
- `service`: Service that generated alert (ssh, telnet, modbus, http)
- `source_ip`: Source of attack

**PromQL Examples:**
```
# Total alerts
sum(honeypot_alerts_total)

# High severity alerts only
honeypot_alerts_total{severity="high"}

# Alerts by severity level
sum by (severity) (honeypot_alerts_total)
```

---

### 4. honeypot_payload_size_bytes

**Type:** Histogram (with buckets)

**Purpose:** Analyze size distribution of attack payloads.

**PromQL Examples:**
```
# Average payload size
sum(rate(honeypot_payload_size_bytes_sum[5m])) / sum(rate(honeypot_payload_size_bytes_count[5m]))

# 95th percentile payload size
histogram_quantile(0.95, rate(honeypot_payload_size_bytes_bucket[5m]))
```

---

### 5. honeypot_session_duration_seconds

**Type:** Histogram

**Purpose:** Track how long attack sessions last.

**PromQL Examples:**
```
# Average session duration
avg(honeypot_session_duration_seconds_sum) / avg(honeypot_session_duration_seconds_count)

# 95th percentile session duration
histogram_quantile(0.95, rate(honeypot_session_duration_seconds_bucket[5m]))
```

---

### 6. honeypot_unique_attackers

**Type:** Gauge (can increase/decrease)

**Purpose:** Track number of unique attacker IP addresses.

**PromQL Examples:**
```
# Raw unique attacker count
honeypot_unique_attackers

# Check if exceeded threshold
honeypot_unique_attackers > 5
```

---

## ALERTING RULES

### Critical Alerts

**Rule 1: High-Severity Attack Spike**
```
rate(honeypot_alerts_total{severity="high"}[5m]) > 2
```

**Rule 2: Rapid SSH Brute Force**
```
rate(honeypot_attack_attempts_total{pattern="ssh_brute_force"}[1m]) > 5
```

**Rule 3: MODBUS Write Attempt**
```
honeypot_attack_attempts_total{pattern="modbus_write"} > 0
```

**Rule 4: Multiple Attacker IPs**
```
honeypot_unique_attackers > 3
```

---

## GRAFANA DASHBOARD QUERIES

### Panel 1: Real-Time Attack Timeline
```
rate(honeypot_connections_total[30s])
```

### Panel 2: Attack Type Distribution
```
sum by (pattern) (honeypot_attack_attempts_total)
```

### Panel 3: Top Attacking IPs
```
topk(10, sum by (source_ip) (honeypot_connections_total))
```

### Panel 4: Service Status
```
sum by (service) (honeypot_connections_total)
```

---

## TROUBLESHOOTING

### Verify metrics are being collected

```bash
# Check if honeypot job is scraping
curl 'http://localhost:9090/api/v1/query?query=up{job="honeypot"}'

# Check all honeypot metrics
curl 'http://localhost:9090/api/v1/query?query=honeypot_connections_total'
```

### Check if honeypot is running

```bash
docker compose ps honeypot

# View honeypot logs
docker compose logs honeypot

# Test connectivity to ports
nc -zv localhost 2222
nc -zv localhost 2323
```

---

**Version:** 1.0  
**Last Updated:** November 27, 2025  
**Status:** Production
