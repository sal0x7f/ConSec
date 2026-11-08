FROM python:3.11-slim

WORKDIR /app

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Install Python packages
RUN pip install --no-cache-dir prometheus-client

# Create log directory
RUN mkdir -p /var/log/honeypot && \
    chmod 777 /var/log/honeypot

# Copy honeypot script
COPY honeypot.py /app/honeypot.py

# Run as non-root
RUN useradd -m -u 1000 honeypot && \
    chown -R honeypot:honeypot /app /var/log/honeypot

USER honeypot

# Expose honeypot ports for attract intruder
EXPOSE 2222 2323 5502 8080 9445

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import socket; socket.create_connection(('localhost', 2222), timeout=2)" || exit 1

CMD ["python", "-u", "honeypot.py"]
