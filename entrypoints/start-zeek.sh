#!/bin/bash
set -euo pipefail

# Zeek startup script with error handling and logging
LOG_FILE="${ZEEK_LOG_DIR:-/opt/zeek/logs}/zeek.startup.log"
ZEEK_INTERFACE="${ZEEK_INTERFACE:-eth0}"

# Ensure logs directory exists
mkdir -p "${LOG_FILE%/*}"

echo "[$(date +'%Y-%m-%d %H:%M:%S')] Starting Zeek on interface: $ZEEK_INTERFACE" | tee -a "$LOG_FILE"

# Verify interface exists
if ! ip link show "$ZEEK_INTERFACE" &>/dev/null; then
    echo "[ERROR] Interface $ZEEK_INTERFACE not found. Available interfaces:" | tee -a "$LOG_FILE"
    ip link show | grep '^[0-9]' | tee -a "$LOG_FILE"
    exit 1
fi

# Initialize zeekctl
echo "[$(date +'%Y-%m-%d %H:%M:%S')] Deploying Zeek control..." | tee -a "$LOG_FILE"
zeekctl deploy 2>&1 | tee -a "$LOG_FILE" || echo "[WARNING] zeekctl deploy had issues, continuing..." | tee -a "$LOG_FILE"

# Start Zeek in passive mode
echo "[$(date +'%Y-%m-%d %H:%M:%S')] Running Zeek in passive mode on $ZEEK_INTERFACE..." | tee -a "$LOG_FILE"
zeek -i "$ZEEK_INTERFACE" local 2>&1 | tee -a "$LOG_FILE" &
ZEEK_PID=$!

echo "[$(date +'%Y-%m-%d %H:%M:%S')] Zeek PID: $ZEEK_PID" | tee -a "$LOG_FILE"

# Trap to handle graceful shutdown
trap "echo '[$(date +'%Y-%m-%d %H:%M:%S')] Shutting down Zeek...' | tee -a \"$LOG_FILE\"; kill $ZEEK_PID 2>/dev/null || true" SIGTERM SIGINT

# Wait for process
wait $ZEEK_PID