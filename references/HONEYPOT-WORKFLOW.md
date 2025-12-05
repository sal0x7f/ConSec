# ConSEC Honeypot Integration - Workflow & Architecture Analysis

**Date:** November 27, 2025  
**Purpose:** Design honeypot workflow before implementation  
**Status:** PLANNING & ANALYSIS

---

## TABLE OF CONTENTS

1. [Current System Architecture](#current-system-architecture)
2. [Proposed Honeypot Integration](#proposed-honeypot-integration)
3. [Complete Data Flow Workflow](#complete-data-flow-workflow)
4. [Component Interactions](#component-interactions)
5. [Testing Strategy](#testing-strategy)
6. [Implementation Roadmap](#implementation-roadmap)

---

## CURRENT SYSTEM ARCHITECTURE

### Existing Data Flow (Without Honeypot)

```
┌─────────────────────────────────────────────────────────────────┐
│                    ConSEC Current Stack                         │
└─────────────────────────────────────────────────────────────────┘

Network Traffic (eth0)
    │
    ├──────────────────────┬──────────────────────┐
    │                      │                      │
    ▼                      ▼                      ▼
┌─────────────┐      ┌─────────────┐      ┌─────────────┐
│  Suricata   │      │    Zeek     │      │   System    │
│    IDS      │      │  Analysis   │      │  Prometheus │
│             │      │             │      │  Exporter   │
└──────┬──────┘      └──────┬──────┘      └──────┬──────┘
       │                     │                     │
       │ Eve.json            │ conn.log            │ Metrics
       │ Alerts              │ dns.log             │ (CPU, Mem)
       │ fast.log            │ http.log            │
       │                     │ notice.log          │
       └─────────────────────┼─────────────────────┘
                             │
                    ┌────────▼────────┐
                    │  Prometheus     │
                    │  TSDB           │
                    │  (Metrics + Logs)
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │  Grafana        │
                    │  Dashboard      │
                    │  (Visualization)│
                    └─────────────────┘
```

### Current Components

| Component | Function | Input | Output | Port |
|-----------|----------|-------|--------|------|
| Suricata | Network IDS | eth0 traffic | eve.json alerts | N/A |
| Zeek | Network Analysis | eth0 traffic | conn.log, dns.log, http.log | N/A |
| Prometheus | Metrics Collection | System metrics | Time-series DB | 9090 |
| Grafana | Visualization | Prometheus metrics | Dashboards | 3000 |
| System | Metric Export | CPU, Memory, Network | Prometheus format | N/A |

---

## PROPOSED HONEYPOT INTEGRATION

### Honeypot Overview

**Purpose:** Simulate vulnerable services to attract and log attack attempts

**Attack Detection Strategy:**
- Monitor specific ports with fake/decoy services
- Log all connection attempts and payloads
- Trigger Suricata alerts on honeypot interactions
- Export honeypot events as metrics to Prometheus
- Visualize honeypot attacks in Grafana

### Honeypot Service Architecture

```
Honeypot Container
├── Service Port 1: SSH (22) - Fake OpenSSH
├── Service Port 2: Telnet (23) - Fake Telnet
├── Service Port 3: HTTP (8080) - Fake Web Server
├── Service Port 4: MODBUS (502) - Fake MODBUS Controller
├── Service Port 5: DNP3 (20000) - Fake DNP3 Outstation
└── Logging Engine
    ├── Connection Logger
    ├── Payload Logger
    ├── Attack Pattern Detector
    └── Prometheus Exporter
```

### Honeypot Technologies Options

**Option A: Cowrie (SSH/Telnet Honeypot)**
- Simulates SSH and Telnet services
- Logs all commands and interactions
- Can be scripted to respond realistically
- Lightweight and production-ready

**Option B: Dionaea (Multi-protocol)**
- Captures malware
- Logs exploit attempts
- Supports multiple protocols (SMB, HTTP, SIP, etc.)
- More complex but comprehensive

**Option C: Custom Python Honeypot**
- Tailored to OT/ICS protocols (MODBUS, DNP3)
- Full control over logging format
- Can export directly to Prometheus
- Lightweight for VM resources

**Recommendation:** Custom Python honeypot for OT protocol coverage + Cowrie for SSH/Telnet

---

## COMPLETE DATA FLOW WORKFLOW

### Phase 1: Attacker Interaction with Honeypot

```
┌──────────────────────────────────────────────────────────────┐
│ PHASE 1: ATTACKER INITIATES CONNECTION                      │
└──────────────────────────────────────────────────────────────┘

Internet/Network Attacker
    │
    │ (Attempts connection to honeypot ports)
    ▼
┌─────────────────────────────────┐
│  Network Traffic on eth0        │
│  - Source IP: Attacker          │
│  - Destination Port: 22, 502, etc
│  - Payload: Attack data         │
└─────────────────────────────────┘
```

**Flow:**
1. Attacker sends TCP/UDP packets to honeypot ports
2. Packets travel through eth0 network interface
3. Multiple components now receive this traffic

### Phase 2: Parallel Detection & Analysis

```
┌──────────────────────────────────────────────────────────────┐
│ PHASE 2: PARALLEL DETECTION ACROSS STACK                    │
└──────────────────────────────────────────────────────────────┘

Network Traffic (eth0)
    │
    ├─────────────────┬──────────────────┬──────────────────┐
    │                 │                  │                  │
    ▼                 ▼                  ▼                  ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│  Suricata    │ │    Zeek      │ │  Honeypot    │ │  Prometheus  │
│   IDS        │ │  Analysis    │ │  Container   │ │  Exporter    │
└──────┬───────┘ └──────┬───────┘ └──────┬───────┘ └──────┬───────┘
       │                │                │                │
       │ Matches rules: │ Logs:          │ Service       │ Exports:
       │ - Port 22      │ - Connection   │ Responds      │ - Attack
       │   access       │ - Protocol     │ Fake SSH/     │   count
       │ - SSH Brute    │   details      │   Telnet      │ - Source
       │   Force        │ - Payload      │ Records:      │   IPs
       │ - Modbus       │   inspection   │ - Timestamp   │ - Ports
       │   commands     │               │ - Attacker IP │   accessed
       │ - DNP3 ops     │               │ - Commands    │ - Attack
       │                │               │ - Responses   │   types
       └────┬───────────┼───────────────┼───────────────┘
            │           │               │
            │ Alert+    │ Analysis+     │ Events+
            │ Metadata  │ Metadata      │ Metadata
            └───────────┼───────────────┘
                        │
                        ▼
            ┌────────────────────────┐
            │  Data Integration      │
            │  - Correlate alerts    │
            │  - Enrich events       │
            │  - Generate metrics    │
            └────────────┬───────────┘
                         │
                         ▼
            ┌────────────────────────┐
            │  Prometheus            │
            │  Time-Series Database  │
            │  Stores:               │
            │  - suricata_alerts     │
            │  - honeypot_events     │
            │  - zeek_connections    │
            │  - attack_sources      │
            │  - attempt_counts      │
            └────────────┬───────────┘
                         │
                         ▼
            ┌────────────────────────┐
            │  Grafana Dashboard     │
            │  Visualizes:           │
            │  - Attack timeline     │
            │  - Source IP map       │
            │  - Port access rates   │
            │  - Honeypot vs IDS     │
            │  - Real vs Decoy       │
            └────────────────────────┘
```

---

## COMPONENT INTERACTIONS

### Component 1: Suricata IDS Detection

**Input:** Network traffic on eth0

**Honeypot-Specific Rules Triggered:**

| Rule | Condition | Output |
|------|-----------|--------|
| SSH Brute Force | Multiple auth attempts on port 22 | Alert + timestamp |
| MODBUS Write Command | Function 5/6/16 on port 502 | Alert + command type |
| DNP3 Control Operation | Control packet on port 20000 | Alert + operation |
| Suspicious Payload | Malicious binary on honeypot port | Alert + hex dump |
| Protocol Violation | Invalid packet structure | Alert + protocol |

**Output Format:** EVE JSON
```json
{
  "timestamp": "2025-11-27T10:15:23.456Z",
  "event_type": "alert",
  "alert": {
    "action": "alert",
    "gid": 1,
    "signature_id": 1000001,
    "signature": "MODBUS Write Single Coil suspicious",
    "category": "Suspicious Command",
    "severity": 3
  },
  "src_ip": "192.168.1.100",
  "dest_ip": "172.20.0.1",
  "dest_port": 502,
  "proto": "TCP",
  "payload": "<base64_encoded_payload>"
}
```

**Prometheus Metric Export:**
```
suricata_alerts_total{source_ip="192.168.1.100",port="502",signature="MODBUS"} 5
suricata_alerts_total{source_ip="192.168.1.100",port="22",signature="SSH_Brute"} 12
```

---

### Component 2: Honeypot Service Detection

**Input:** Connection attempts to honeypot ports

**Detection Process:**

1. **Connection Logging**
   - Accept connection on honeypot port
   - Log source IP, timestamp, port
   - Record connection duration

2. **Payload Inspection**
   - Read attacker's initial data
   - Parse command/request type
   - Detect attack pattern

3. **Fake Service Response**
   - Respond with synthetic service
   - Trigger honeypot alerts
   - Maintain connection for analysis

4. **Attack Categorization**
   - SSH: Credential attempts, commands
   - MODBUS: Write operations, function codes
   - DNP3: Control operations, sequences
   - Generic: Port scanning, probes

**Output Format:** Structured logs
```
[2025-11-27 10:15:23] HONEYPOT_ALERT
Source: 192.168.1.100:54321
Target: Honeypot SSH (22)
Action: Connection Accept
Payload: SSH protocol banner request
Category: SSH Reconnaissance
Severity: INFO

[2025-11-27 10:15:45] HONEYPOT_ALERT
Source: 192.168.1.100:54322
Target: Honeypot MODBUS (502)
Action: Command Received
Payload: 01 03 00 00 00 0A (Read Coils)
Category: MODBUS Scan
Severity: MEDIUM
```

**Prometheus Metric Export:**
```
honeypot_connections_total{source_ip="192.168.1.100",port="22"} 1
honeypot_connections_total{source_ip="192.168.1.100",port="502"} 3
honeypot_payload_size_bytes{source_ip="192.168.1.100",port="502"} 256
honeypot_session_duration_seconds{source_ip="192.168.1.100",port="22"} 23.45
```

---

### Component 3: Zeek Network Analysis

**Input:** Network traffic on eth0 (including honeypot traffic)

**Detection Focus:**

**Connection Analysis:**
```
conn.log output for honeypot attacks:
- uid: honeypot_session_123
- id.orig_h: 192.168.1.100 (attacker)
- id.orig_p: 54321
- id.resp_h: 172.20.0.1 (honeypot)
- id.resp_p: 22 (SSH honeypot)
- proto: tcp
- service: ssh
- duration: 23.45
- orig_bytes: 456
- resp_bytes: 1024
- state: SF (SYN-FIN)
- missed_bytes: 0
- history: ShADaFf
- orig_pkts: 45
- orig_ip_bytes: 2340
- resp_pkts: 38
- resp_ip_bytes: 3200
- tunnel_parent: (empty)
```

**Notice.log (Alerts):**
```
#timestamp       uid             note                        msg
2025-11-27T10:15:23Z  honeypot_ssh_123  Honeypot::SSH_Scan  SSH scan attempt detected
2025-11-27T10:15:45Z  honeypot_mod_456  ICS::MODBUS_Scan    MODBUS protocol scan
```

**Output:** Zeek DNS, HTTP, SSL logs for honeypot interactions

**Prometheus Metric Export:**
```
zeek_connections_total{dest_port="22",service="ssh"} 1
zeek_connections_total{dest_port="502",service="modbus"} 3
zeek_connection_duration_seconds{dest_port="22"} 23.45
zeek_unique_source_ips{honeypot="true"} 5
```

---

### Component 4: Prometheus Integration

**Metrics Collection Workflow:**

```
┌─────────────────────────────────────────────────────┐
│ PROMETHEUS METRIC COLLECTION FOR HONEYPOT          │
└─────────────────────────────────────────────────────┘

Data Sources
    │
    ├─ Suricata EVE JSON → Parse → Convert to metrics
    ├─ Honeypot Container → Expose /metrics endpoint
    ├─ Zeek Logs → Parse → Convert to metrics
    └─ System Metrics → Prometheus node exporter
         │
         ▼
┌──────────────────────────────┐
│ Prometheus Scrape (15s)      │
│ Targets:                     │
│ - localhost:9090 (self)      │
│ - suricata:9144 (custom)     │
│ - honeypot:9445 (custom)     │
│ - zeek:9889 (custom)         │
└──────────────────────────────┘
         │
         ▼
┌──────────────────────────────┐
│ Time-Series Database (TSDB)  │
│ Stores all metrics with:     │
│ - Timestamp                  │
│ - Labels (source, port, etc) │
│ - Value                      │
│ - 15-day retention           │
└──────────────────────────────┘
```

**Honeypot-Related Metrics:**

```
# Honeypot Connection Metrics
honeypot_connections_total{port="22",source_ip="192.168.1.100"} 5
honeypot_connections_total{port="502",source_ip="192.168.1.100"} 3
honeypot_connections_total{port="23",source_ip="192.168.1.100"} 2

# Attack Pattern Metrics
honeypot_attack_attempts{pattern="ssh_brute_force",source="192.168.1.100"} 12
honeypot_attack_attempts{pattern="modbus_scan",source="192.168.1.100"} 8
honeypot_attack_attempts{pattern="port_scan",source="any"} 45

# Session Metrics
honeypot_session_duration_seconds{port="22"} 25.50
honeypot_payload_bytes_received{port="502"} 1024
honeypot_responses_sent{port="22"} 8

# Correlation Metrics
honeypot_vs_suricata_matches{port="502",rule="MODBUS_Write"} 3
honeypot_vs_zeek_matches{port="22",service="ssh"} 2

# Severity Metrics
honeypot_alerts_high{source="192.168.1.100"} 5
honeypot_alerts_medium{source="192.168.1.100"} 12
honeypot_alerts_low{source="192.168.1.100"} 8
```

---

### Component 5: Grafana Visualization

**Dashboard Panels for Honeypot:**

**Panel 1: Attack Timeline**
```
Metric: honeypot_connections_total
Type: Graph with time series
X-axis: Time
Y-axis: Connection count
Shows: Real-time attack frequency
```

**Panel 2: Attacker Source Map**
```
Metric: honeypot_connections_total group by source_ip
Type: Table/Map
Shows: Top attacking IPs, count, ports targeted
```

**Panel 3: Port Access Heatmap**
```
Metrics: honeypot_connections_total by port
Type: Heatmap
Shows: Which ports are most attacked, when
```

**Panel 4: Honeypot vs Suricata Correlation**
```
Metrics: 
  - honeypot_connections_total
  - suricata_alerts_total
Type: Dual-axis graph
Shows: Both detection systems triggering on same attack
```

**Panel 5: Attack Pattern Distribution**
```
Metric: honeypot_attack_attempts by pattern
Type: Pie chart
Shows: SSH brute force vs MODBUS vs port scans, etc
```

**Panel 6: Payload Analysis**
```
Metrics: honeypot_payload_bytes_received
Type: Table
Shows: Packet sizes, session duration, response times
```

**Panel 7: Severity Distribution**
```
Metrics: honeypot_alerts_high/medium/low
Type: Bar chart
Shows: Alert severity levels over time
```

**Panel 8: Top Attacking Sources**
```
Metric: honeypot_connections_total by source_ip limit 10
Type: Bar chart
Shows: Top 10 attacker IPs and their attempt counts
```

---

## TESTING STRATEGY

### Test Phase 1: Honeypot Service Deployment

**Objective:** Verify honeypot services start correctly

**Tests:**
1. Honeypot container starts successfully
2. Services listening on target ports
3. Logging mechanism working
4. Prometheus exporter responding

**Success Criteria:**
- Container health: Healthy ✅
- Ports: 22, 23, 502, 20000, 8080 listening ✅
- Metrics endpoint: Responding ✅

---

### Test Phase 2: Attack Simulation

**Objective:** Generate honeypot attacks and verify detection

**Attack Scenarios:**

**Scenario A: SSH Brute Force**
```
Command: for i in {1..5}; do
  ssh -o StrictHostKeyChecking=no user@honeypot-ip
  sleep 1
done

Expected Results:
- Honeypot logs 5 connection attempts
- Suricata triggers SSH brute force rule
- Zeek logs 5 SSH connections
- Prometheus records 5 honeypot_connections
- Grafana shows spike in SSH attacks
```

**Scenario B: MODBUS Protocol Scan**
```
Command: python modbus_scanner.py --target honeypot-ip --port 502

Expected Results:
- Honeypot logs MODBUS requests
- Suricata triggers MODBUS write rules
- Zeek logs TCP connections to port 502
- Prometheus records honeypot_attack_attempts{pattern="modbus_scan"}
- Grafana shows MODBUS attempt spike
```

**Scenario C: Port Scanning**
```
Command: nmap -p 22,23,502,20000,8080 honeypot-ip

Expected Results:
- Honeypot logs connection attempts on all ports
- Suricata triggers port scan alert
- Zeek logs 5 TCP connection attempts
- Prometheus records honeypot_connections_total for each port
- Grafana shows multi-port scan pattern
```

---

### Test Phase 3: Data Flow Verification

**Objective:** Verify complete data flow from attack to visualization

**Test Steps:**

1. **Generate Attack**
   - Initiate honeypot attack from test machine
   - Timestamp: T0

2. **Verify Honeypot Detection (T0 + 1 second)**
   - Check honeypot logs
   - Expected: Attack logged with source IP

3. **Verify Suricata Detection (T0 + 2 seconds)**
   - Check Suricata EVE JSON logs
   - Expected: Alert with matching signature

4. **Verify Zeek Detection (T0 + 2 seconds)**
   - Check Zeek conn.log
   - Expected: Connection record with details

5. **Verify Prometheus Collection (T0 + 15 seconds)**
   - Query Prometheus API
   - Expected: Metrics with increment in honeypot counters

6. **Verify Grafana Display (T0 + 16 seconds)**
   - Refresh Grafana dashboard
   - Expected: Graph spikes, new data points visible

**Full Chain Timeline:**
```
T0:     Attack generated
T0+1s:  Honeypot logs attack
T0+2s:  Suricata alerts
T0+2s:  Zeek records connection
T0+15s: Prometheus scrapes metrics
T0+16s: Grafana displays new data
```

---

### Test Phase 4: Correlation Analysis

**Objective:** Verify honeypot, Suricata, and Zeek detect same attacks

**Test:**
1. Generate single attack (e.g., MODBUS write to port 502)
2. Check three detection sources:
   - Honeypot logs: Should show connection + command
   - Suricata alerts: Should show alert with signature match
   - Zeek logs: Should show TCP connection + service details

**Success Criteria:**
- All three detect the attack ✅
- Timestamps correlate (within 2 seconds) ✅
- Source IP matches across all ✅
- Prometheus metrics correlate ✅

---

### Test Phase 5: Dashboard Validation

**Objective:** Verify Grafana visualizations accurately display honeypot data

**Tests:**
1. Attack Timeline Panel
   - Trigger 5 attacks in 10-minute window
   - Expected: Graph shows 5 spikes

2. Source Map Panel
   - Trigger attacks from 3 different IPs
   - Expected: Table shows 3 unique sources with counts

3. Port Access Heatmap
   - Attack ports 22, 502, 23 at different times
   - Expected: Heatmap shows temporal distribution

4. Honeypot vs Suricata Correlation
   - Generate MODBUS attack
   - Expected: Both graphs spike together

5. Attack Pattern Distribution
   - Generate 5 SSH, 3 MODBUS, 2 port scan attacks
   - Expected: Pie chart shows 5:3:2 ratio

---

## IMPLEMENTATION ROADMAP

### Phase 1: Design & Planning ✅ (Current)
- [x] Define workflow architecture
- [x] Design data flow
- [x] Plan component interactions
- [x] Create test strategy

### Phase 2: Honeypot Container Setup (Next)
- [ ] Choose honeypot technology (Cowrie + Custom Python)
- [ ] Create Dockerfile for honeypot
- [ ] Configure services (SSH, Telnet, MODBUS, DNP3)
- [ ] Set up logging system

### Phase 3: Integration with Suricata
- [ ] Add honeypot-specific Suricata rules
- [ ] Configure rule triggering
- [ ] Set up EVE JSON export
- [ ] Test rule matching

### Phase 4: Prometheus Metrics Export
- [ ] Create honeypot metrics exporter
- [ ] Add honeypot scrape target
- [ ] Define metric schema
- [ ] Test metrics collection

### Phase 5: Grafana Dashboard Enhancement
- [ ] Create honeypot dashboard panels
- [ ] Configure data sources
- [ ] Set up visualizations
- [ ] Create alerts

### Phase 6: Testing & Validation
- [ ] Execute Phase 1-5 tests
- [ ] Run attack simulations
- [ ] Verify data flow end-to-end
- [ ] Performance testing

### Phase 7: Documentation & Deployment
- [ ] Document setup procedures
- [ ] Create troubleshooting guide
- [ ] Deploy to production
- [ ] Monitor and optimize

---

## WORKFLOW SUMMARY

### Attack to Dashboard: Complete Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                    COMPLETE ATTACK FLOW                             │
└─────────────────────────────────────────────────────────────────────┘

STEP 1: ATTACK GENERATION
┌──────────────────────────────────────────────────────────┐
│ Attacker sends malicious traffic to honeypot ports       │
│ - SSH attempts on port 22                                │
│ - MODBUS requests on port 502                            │
│ - Port scans on multiple ports                           │
└──────────────────────────────────────────────────────────┘
                          │
                          ▼
STEP 2: PARALLEL DETECTION
┌───────────────┬──────────────┬──────────────┬──────────────┐
│   Suricata    │  Honeypot    │    Zeek      │  Prometheus  │
│   IDS Alert   │  Logs        │  Analysis    │  Exporter    │
└───────────────┴──────────────┴──────────────┴──────────────┘
       │              │              │              │
       │ Signature    │ Raw logs     │ Connection   │ Metrics
       │ match        │              │ metadata     │ export
       └──────────────┼──────────────┼──────────────┘
                      │
                      ▼
STEP 3: DATA AGGREGATION
┌──────────────────────────────────────────────────────────┐
│ All detection data combined with metadata:               │
│ - Source IP, port, timestamp                             │
│ - Attack type, severity, payload                         │
│ - Detection method (honeypot/Suricata/Zeek)              │
└──────────────────────────────────────────────────────────┘
                      │
                      ▼
STEP 4: PROMETHEUS STORAGE
┌──────────────────────────────────────────────────────────┐
│ Time-series metrics stored:                              │
│ - honeypot_connections_total                             │
│ - suricata_alerts_total                                  │
│ - honeypot_vs_suricata_matches                           │
│ - Correlated attack metrics                              │
└──────────────────────────────────────────────────────────┘
                      │
                      ▼
STEP 5: GRAFANA VISUALIZATION
┌──────────────────────────────────────────────────────────┐
│ Real-time dashboard updates showing:                     │
│ - Attack timeline and frequency                          │
│ - Attacker source IPs and locations                      │
│ - Port access patterns                                   │
│ - Honeypot vs IDS correlation                            │
│ - Attack type distribution                               │
│ - Severity levels                                        │
└──────────────────────────────────────────────────────────┘
```

---

## KEY BENEFITS OF THIS WORKFLOW

1. **Multi-Layer Detection**
   - Honeypot catches attacks IDS might miss
   - IDS catches attacks honeypot might not classify
   - Zeek provides network-level confirmation

2. **Correlation & Validation**
   - Multiple sources confirm same attack
   - Reduces false positives
   - Increases detection confidence

3. **Comprehensive Logging**
   - Full attack payload captured (honeypot)
   - Alert signatures matched (Suricata)
   - Network metadata collected (Zeek)
   - All correlated in Prometheus/Grafana

4. **Real-Time Visualization**
   - Live attack timeline
   - Attacker behavior patterns
   - Port/protocol preferences
   - Threat intelligence gathering

5. **Scalability**
   - Easy to add more honeypot services
   - Prometheus handles metrics scaling
   - Grafana dashboards easily extended
   - Multiple honeypots can feed same stack

---

## CONCLUSION

This workflow provides:
- **Transparency**: Clear data flow from attack to dashboard
- **Redundancy**: Multiple detection methods confirm threats
- **Intelligence**: Comprehensive attack data for analysis
- **Automation**: Full integration with existing ConSEC stack
- **Visualization**: Real-time insights into attack patterns

**Ready for Phase 2 Implementation:** Once workflow is approved, we can proceed with honeypot container setup and integration.

