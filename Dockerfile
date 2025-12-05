# Dockerfile - consec-base - Multi-stage optimized build
FROM debian:12-slim as builder

ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies (will be pruned in final image)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      build-essential autoconf automake libtool pkg-config \
      ca-certificates curl wget gnupg && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Final runtime stage
FROM debian:12-slim

ENV DEBIAN_FRONTEND=noninteractive \
    CONSEC_HOME=/home/secuser/consec \
    PATH="/home/secuser/.local/bin:$PATH"

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      ca-certificates curl wget gnupg lsb-release \
      python3 python3-venv python3-pip git vim sudo iproute2 iputils-ping \
      make unzip jq net-tools tcpdump tshark \
      procps dnsutils && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && \
    python3 -m venv /opt/venv && \
    /opt/venv/bin/pip install --no-cache-dir PyYAML requests

# Create non-root user with sudo privileges
RUN useradd -m -s /bin/bash -u 1000 secuser && \
    echo "secuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    mkdir -p /home/secuser/consec/{configs,logs,data,entrypoints}

WORKDIR /home/secuser/consec

# Copy entrypoint scripts with correct permissions
COPY --chown=secuser:secuser entrypoints/ /home/secuser/consec/entrypoints/
RUN chmod +x /home/secuser/consec/entrypoints/*.sh

# Copy config files
COPY --chown=secuser:secuser configs/ /home/secuser/consec/configs/

# Set user
USER secuser

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:9090/-/healthy || exit 1

ENTRYPOINT ["/bin/bash"]
CMD ["-c", "echo 'ConSEC container running. Available services: Prometheus, Grafana, Suricata, Zeek'"]