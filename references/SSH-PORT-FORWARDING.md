# SSH Port Forwarding Guide for ConSEC on VM

## Quick SSH Tunnel Setup

Run this command from your local machine to forward all services:

```bash
# Single command - forward all services
ssh -L 3000:localhost:3000 -L 9090:localhost:9090 -N user@vm-ip

# Or with common name for easier reference:
ssh -L 3000:localhost:3000 -L 9090:localhost:9090 -N user@192.168.x.x
```

Replace:
- `user` = Your SSH username on the VM
- `vm-ip` = IP address of the virtual machine

## Port Mapping Reference

| Service | Local Port | Container Port | Purpose |
|---------|-----------|-----------------|---------|
| Grafana | 3000 | 3000 | Visualization & Dashboards |
| Prometheus | 9090 | 9090 | Metrics Collection |
| Suricata | N/A | Internal | Network IDS |
| Zeek | N/A | Internal | Network Analysis |

## Persistent SSH Tunnel (Background)

```bash
# Create SSH tunnel in background
ssh -L 3000:localhost:3000 -L 9090:localhost:9090 -N user@vm-ip &
SSH_PID=$!

# Kill tunnel when done
kill $SSH_PID
```

## VS Code Remote SSH Setup

Add to `~/.ssh/config`:

```
Host consec-vm
    HostName 192.168.x.x
    User user
    LocalForward 3000 localhost:3000
    LocalForward 9090 localhost:9090
```

Then connect: `ssh consec-vm`

## Troubleshooting

### Port already in use locally
```bash
# Check what's using the port
lsof -i :3000

# Use different local port
ssh -L 4000:localhost:3000 user@vm-ip
# Then access at http://localhost:4000
```

### Connection refused
- Verify Docker containers are running: `docker ps` (on VM)
- Check container logs: `docker logs consec_grafana`
- Ensure firewall allows port access on VM

## Build & Start Containers on VM

```bash
# SSH into VM
ssh user@vm-ip

# Navigate to project
cd ~/Consec_project

# Build custom image (optional)
docker build -t consec-base:latest .

# Start services
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f grafana
```

## One-Time Setup on VM

```bash
# Copy .env.example to .env and customize
cp .env.example .env

# Create data directories with proper permissions
mkdir -p consec_data/{grafana,prometheus,suricata_logs,zeek_logs}
chmod 777 consec_data/*

# Make entrypoint scripts executable
chmod +x entrypoints/*.sh

# Build and start
docker-compose build
docker-compose up -d
```
