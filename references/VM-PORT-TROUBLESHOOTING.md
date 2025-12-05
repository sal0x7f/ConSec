# Port Connection Troubleshooting - Virtual Machine Issue

**Issue:** Ports refusing connection when accessing from outside the VM  
**Status:** ✅ IDENTIFIED AND SOLUTIONS PROVIDED

---

## THE ISSUE

Your VM is running on **172.17.0.4** but the ports are only binding to the container's internal IP space. When you try to connect from **outside the VM** (from your host machine), the connection fails.

### Current State:
```
✓ Ports ARE listening inside the VM (0.0.0.0:PORT)
✓ Connections work from localhost (172.17.0.4)
✗ Ports DON'T work from outside the VM (your computer)
```

---

## ROOT CAUSE

The honeypot container is binding to `0.0.0.0` on all ports, which means:
- **Inside the VM:** ✅ Works (localhost, 127.0.0.1, 172.17.0.4)
- **Outside the VM:** ✗ Fails (from your host machine)

This is because Docker containers on a bridge network don't expose ports to the outside world unless you're routing traffic correctly.

---

## SOLUTION 1: SSH Tunnel (RECOMMENDED FOR VM)

Use SSH port forwarding to access the honeypot from your host machine:

### From Your Host Computer:

```bash
# Create SSH tunnel to VM
ssh -L 2222:localhost:2222 -L 2323:localhost:2323 -L 5502:localhost:5502 -L 8080:localhost:8080 -L 9445:localhost:9445 user@172.17.0.4

# Keep this terminal open! Then in another terminal:
nc localhost 2222      # Tests SSH honeypot
curl http://localhost:9445/metrics   # Tests metrics endpoint
```

### Permanent SSH Config:

Add to `~/.ssh/config`:
```
Host consec-vm
    HostName 172.17.0.4
    User usersal
    LocalForward 2222 localhost:2222
    LocalForward 2323 localhost:2323
    LocalForward 5502 localhost:5502
    LocalForward 8080 localhost:8080
    LocalForward 9445 localhost:9445
```

Then simply: `ssh consec-vm` and tunnels are automatic.

---

## SOLUTION 2: Connect from Inside the VM

Run all tests directly inside the VM:

```bash
# SSH into VM first
ssh usersal@172.17.0.4

# Then test ports locally (these work!)
nc -zv localhost 2222
curl http://localhost:9445/metrics
docker compose logs honeypot
```

---

## SOLUTION 3: Docker Host Network Mode (ADVANCED)

If you want ports accessible from outside without SSH tunneling, modify `docker-compose.yml`:

```yaml
services:
  honeypot:
    ...
    network_mode: "host"  # ← Add this line
    # Remove "networks:" section
```

Then restart:
```bash
docker compose up -d --build honeypot
```

**Warning:** This exposes the honeypot directly to your VM's network interface.

---

## SOLUTION 4: Port Forwarding at Firewall Level (VM HOST)

If your VM is hosted on another system (VirtualBox, VMware, etc.):

### VirtualBox:
1. VM Settings → Network → Port Forwarding
2. Add entries:
   - Protocol: TCP, Host: 2222, Guest: 2222
   - Protocol: TCP, Host: 2323, Guest: 2323
   - Protocol: TCP, Host: 5502, Guest: 5502
   - Protocol: TCP, Host: 8080, Guest: 8080
   - Protocol: TCP, Host: 9445, Guest: 9445

### VMware:
- Edit VMX file to add port forwarding
- Or use NAT configuration

### Proxmox/KVM:
- Configure bridge or port forwarding at hypervisor level

---

## QUICK TEST COMMANDS

### From Your Host Computer (via SSH tunnel first):

```bash
# Open tunnel
ssh -L 2222:localhost:2222 -L 9445:localhost:9445 usersal@172.17.0.4

# In another terminal, test these:
nc localhost 2222
curl http://localhost:9445/metrics
```

### From Inside the VM:

```bash
ssh usersal@172.17.0.4

# These all work:
nc -zv localhost 2222
nc -zv localhost 2323
nc -zv localhost 5502
curl http://localhost:8080
curl http://localhost:9445/metrics
```

---

## CURRENT VM CONFIGURATION

```
VM Hostname: Project1
VM IP: 172.17.0.4
Project Directory: /home/usersal/Consec_project
Honeypot Container: consec_honeypot
Honeypot Network: consec_project_monitoring_net (bridge)

Port Bindings (0.0.0.0 = accessible from VM):
- 2222/tcp  (SSH)
- 2323/tcp  (Telnet)
- 5502/tcp  (MODBUS)
- 8080/tcp  (HTTP)
- 9445/tcp  (Prometheus)
```

---

## RECOMMENDED WORKFLOW

### For Local Testing (No SSH):
```bash
# 1. SSH into VM
ssh usersal@172.17.0.4

# 2. Run all tests locally
docker compose logs -f honeypot
curl http://localhost:9445/metrics
nc -zv localhost 2222
```

### For Remote Testing (From Your Host):
```bash
# 1. Open SSH tunnel
ssh -L 2222:localhost:2222 -L 9445:localhost:9445 usersal@172.17.0.4

# 2. In another terminal, test:
curl http://localhost:9445/metrics
nc localhost 2222
```

### For Grafana/Prometheus Access:
```bash
# Open tunnel with dashboard ports too
ssh -L 3000:localhost:3000 -L 9090:localhost:9090 usersal@172.17.0.4

# Then visit in browser:
http://localhost:3000   # Grafana
http://localhost:9090   # Prometheus
```

---

## WHY THIS HAPPENS IN VMs

Virtual machines typically use NAT (Network Address Translation) networking:
- VM can access external networks ✓
- External networks can't access VM services ✗ (unless explicitly exposed)
- SSH tunneling bypasses this limitation ✓

Docker adds another layer:
- Docker containers on bridge network are isolated from host network
- Port mappings (0.0.0.0:PORT) work within the VM's network stack
- External access requires SSH tunnel or network re-configuration

---

## VERIFICATION CHECKLIST

- ✓ Ports listen on 0.0.0.0 (verified with netstat)
- ✓ Local connections work (tested)
- ✓ Services are running (honeypot logs confirm)
- ✓ Metrics endpoint responds (9445 works)
- ✓ Firewall is inactive (checked)

**Conclusion:** Everything is working correctly inside the VM. Use SSH tunneling to access from outside.

---

## PERMANENT SOLUTION: Create SSH Tunnel Script

Create `connect_honeypot.sh`:

```bash
#!/bin/bash
echo "Opening tunnel to ConSEC Honeypot..."
echo "Press Ctrl+C to close tunnels"
echo ""
echo "Available endpoints:"
echo "  SSH:      localhost:2222"
echo "  Telnet:   localhost:2323"
echo "  MODBUS:   localhost:5502"
echo "  HTTP:     localhost:8080"
echo "  Metrics:  http://localhost:9445/metrics"
echo "  Prometheus: http://localhost:9090"
echo "  Grafana:    http://localhost:3000"
echo ""

ssh -L 2222:localhost:2222 \
    -L 2323:localhost:2323 \
    -L 5502:localhost:5502 \
    -L 8080:localhost:8080 \
    -L 9445:localhost:9445 \
    -L 9090:localhost:9090 \
    -L 3000:localhost:3000 \
    usersal@172.17.0.4
```

Make executable:
```bash
chmod +x connect_honeypot.sh
./connect_honeypot.sh
```

---

## FINAL ANSWER: Ports ARE Working!

✅ **Inside the VM:** All ports are accessible, services are running
✗ **Outside the VM:** Need SSH tunnel to access

**Start using these commands now:**

```bash
# From your host computer:
ssh -L 9445:localhost:9445 usersal@172.17.0.4

# From another terminal:
curl http://localhost:9445/metrics

# Or just SSH into VM and test locally:
ssh usersal@172.17.0.4
curl http://localhost:9445/metrics
docker compose ps
```

---

**Status:** ✅ Issue Identified - Ports Are Working
**Root Cause:** VM network isolation (normal)
**Solution:** SSH tunneling (recommended)
**Testing:** All ports verified operational
