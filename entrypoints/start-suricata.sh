#!/bin/bash
set -euo pipefail

# Suricata startup script with error handling and logging
LOG_FILE="${SURICATA_LOG_DIR:-/var/log/suricata}/suricata.startup.log"
SURICATA_INTERFACE="${SURICATA_INTERFACE:-eth0}"
CONFIG_FILE="${CONFIG_FILE:-/etc/suricata/suricata.yaml}"

# Ensure logs directory exists
mkdir -p "${LOG_FILE%/*}"
#####
echo "[$(date +'%Y-%m-%d %H:%M:%S')] Starting Suricata on interface: $SURICATA_INTERFACE" | tee -a "$LOG_FILE"

# Verify interface exists
if ! ip link show "$SURICATA_INTERFACE" &>/dev/null; then
    echo "[ERROR] Interface $SURICATA_INTERFACE not found. Available interfaces:" | tee -a "$LOG_FILE"
    ip link show | grep '^[0-9]' | tee -a "$LOG_FILE"
    exit 1
fi

# Validate config file
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "[ERROR] Config file not found: $CONFIG_FILE" | tee -a "$LOG_FILE"
    exit 1
fi

echo "[$(date +'%Y-%m-%d %H:%M:%S')] Using config: $CONFIG_FILE" | tee -a "$LOG_FILE"
echo "[$(date +'%Y-%m-%d %H:%M:%S')] Running Suricata..." | tee -a "$LOG_FILE"

# Run Suricata in IDS mode (pcap auto for lab environment)
# In production, replace with -i for live interface or AF_PACKET for better performance
suricata -c "$CONFIG_FILE" -i "$SURICATA_INTERFACE" 2>&1 | tee -a "$LOG_FILE" &
SURICATA_PID=$!

echo "[$(date +'%Y-%m-%d %H:%M:%S')] Suricata PID: $SURICATA_PID" | tee -a "$LOG_FILE"

# Trap to handle graceful shutdown
trap "echo '[$(date +'%Y-%m-%d %H:%M:%S')] Shutting down Suricata...' | tee -a \"$LOG_FILE\"; kill $SURICATA_PID 2>/dev/null || true" SIGTERM SIGINT

# Wait for process
wait $SURICATA_PID
