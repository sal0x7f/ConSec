#!/usr/bin/env python3
"""
ConSEC Industrial Honeypot
Simulates vulnerable OT/ICS services and logs attack attempts
Exports metrics to Prometheus
"""

import socket
import threading
import logging
import time
import json
from datetime import datetime
from collections import defaultdict
from prometheus_client import Counter, Gauge, Histogram, start_http_server
import struct

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='[%(asctime)s] %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/honeypot/honeypot.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Prometheus metrics
honeypot_connections = Counter(
    'honeypot_connections_total',
    'Total honeypot connections',
    ['port', 'source_ip', 'service']
)

honeypot_attack_attempts = Counter(
    'honeypot_attack_attempts_total',
    'Total attack attempts by pattern',
    ['pattern', 'source_ip', 'port']
)

honeypot_payload_size = Histogram(
    'honeypot_payload_size_bytes',
    'Payload size in bytes',
    ['service'],
    buckets=[64, 256, 1024, 4096, 16384, 65536]
)

honeypot_session_duration = Histogram(
    'honeypot_session_duration_seconds',
    'Session duration in seconds',
    ['service'],
    buckets=[1, 5, 10, 30, 60, 300]
)

honeypot_alerts = Counter(
    'honeypot_alerts_total',
    'Total honeypot alerts by severity',
    ['severity', 'service', 'source_ip']
)

unique_attackers = Gauge(
    'honeypot_unique_attackers',
    'Number of unique attacker IPs'
)

# Track attackers
attacker_ips = set()


class SSHHoneypot:
    """SSH Honeypot Service"""
    
    def __init__(self, port=2222):
        self.port = port
        self.service_name = 'ssh'
        
    def handle_connection(self, conn, addr):
        """Handle SSH connection"""
        try:
            source_ip = addr[0]
            logger.info(f"SSH connection from {source_ip}:{addr[1]}")
            
            honeypot_connections.labels(
                port=str(self.port),
                source_ip=source_ip,
                service=self.service_name
            ).inc()
            
            # Add to unique attackers
            attacker_ips.add(source_ip)
            unique_attackers.set(len(attacker_ips))
            
            # Send SSH banner
            banner = b"SSH-2.0-OpenSSH_7.4\r\n"
            conn.send(banner)
            start_time = time.time()
            
            # Receive data
            try:
                data = conn.recv(1024)
                if data:
                    payload_size = len(data)
                    honeypot_payload_size.labels(service=self.service_name).observe(payload_size)
                    
                    # Log payload
                    logger.info(f"SSH payload from {source_ip}: {payload_size} bytes")
                    logger.debug(f"Data: {data[:100]}")
                    
                    # Detect brute force
                    if b'SSH' in data or b'root' in data or b'admin' in data:
                        honeypot_attack_attempts.labels(
                            pattern='ssh_brute_force',
                            source_ip=source_ip,
                            port=str(self.port)
                        ).inc()
                        honeypot_alerts.labels(
                            severity='medium',
                            service=self.service_name,
                            source_ip=source_ip
                        ).inc()
                        logger.warning(f"SSH brute force attempt from {source_ip}")
                    
            except socket.timeout:
                pass
            
            duration = time.time() - start_time
            honeypot_session_duration.labels(service=self.service_name).observe(duration)
            
        except Exception as e:
            logger.error(f"SSH handler error: {e}")
        finally:
            conn.close()
    
    def start(self):
        """Start SSH honeypot"""
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        sock.bind(('0.0.0.0', self.port))
        sock.listen(5)
        logger.info(f"SSH Honeypot listening on port {self.port}")
        
        while True:
            try:
                conn, addr = sock.accept()
                conn.settimeout(5)
                thread = threading.Thread(
                    target=self.handle_connection,
                    args=(conn, addr)
                )
                thread.daemon = True
                thread.start()
            except Exception as e:
                logger.error(f"SSH listener error: {e}")


class TelnetHoneypot:
    """Telnet Honeypot Service"""
    
    def __init__(self, port=2323):
        self.port = port
        self.service_name = 'telnet'
        
    def handle_connection(self, conn, addr):
        """Handle Telnet connection"""
        try:
            source_ip = addr[0]
            logger.info(f"Telnet connection from {source_ip}:{addr[1]}")
            
            honeypot_connections.labels(
                port=str(self.port),
                source_ip=source_ip,
                service=self.service_name
            ).inc()
            
            attacker_ips.add(source_ip)
            unique_attackers.set(len(attacker_ips))
            
            # Send telnet banner
            banner = b"\r\nWelcome to Linux Telnet\r\nlogin: "
            conn.send(banner)
            start_time = time.time()
            
            # Receive credential attempts
            try:
                data = conn.recv(1024)
                if data:
                    payload_size = len(data)
                    honeypot_payload_size.labels(service=self.service_name).observe(payload_size)
                    
                    logger.info(f"Telnet payload from {source_ip}: {payload_size} bytes")
                    
                    # Detect credential attempts
                    if b'root' in data or b'admin' in data or b'test' in data:
                        honeypot_attack_attempts.labels(
                            pattern='telnet_brute_force',
                            source_ip=source_ip,
                            port=str(self.port)
                        ).inc()
                        honeypot_alerts.labels(
                            severity='medium',
                            service=self.service_name,
                            source_ip=source_ip
                        ).inc()
                        logger.warning(f"Telnet brute force attempt from {source_ip}")
                        
                    # Send response
                    conn.send(b"Password: ")
                    data2 = conn.recv(1024)
                    if data2:
                        logger.warning(f"Telnet password attempt: {data2[:50]}")
                        
            except socket.timeout:
                pass
            
            duration = time.time() - start_time
            honeypot_session_duration.labels(service=self.service_name).observe(duration)
            
        except Exception as e:
            logger.error(f"Telnet handler error: {e}")
        finally:
            conn.close()
    
    def start(self):
        """Start Telnet honeypot"""
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        sock.bind(('0.0.0.0', self.port))
        sock.listen(5)
        logger.info(f"Telnet Honeypot listening on port {self.port}")
        
        while True:
            try:
                conn, addr = sock.accept()
                conn.settimeout(10)
                thread = threading.Thread(
                    target=self.handle_connection,
                    args=(conn, addr)
                )
                thread.daemon = True
                thread.start()
            except Exception as e:
                logger.error(f"Telnet listener error: {e}")


class ModbusHoneypot:
    """MODBUS Honeypot Service"""
    
    def __init__(self, port=5502):
        self.port = port
        self.service_name = 'modbus'
        
    def handle_connection(self, conn, addr):
        """Handle MODBUS connection"""
        try:
            source_ip = addr[0]
            logger.info(f"MODBUS connection from {source_ip}:{addr[1]}")
            
            honeypot_connections.labels(
                port=str(self.port),
                source_ip=source_ip,
                service=self.service_name
            ).inc()
            
            attacker_ips.add(source_ip)
            unique_attackers.set(len(attacker_ips))
            
            start_time = time.time()
            
            try:
                data = conn.recv(1024)
                if data and len(data) >= 8:
                    payload_size = len(data)
                    honeypot_payload_size.labels(service=self.service_name).observe(payload_size)
                    
                    # Parse MODBUS frame
                    transaction_id = struct.unpack('>H', data[0:2])[0]
                    protocol_id = struct.unpack('>H', data[2:4])[0]
                    length = struct.unpack('>H', data[4:6])[0]
                    unit_id = data[6]
                    function_code = data[7]
                    
                    logger.info(f"MODBUS from {source_ip}: Function={function_code}, Length={length}")
                    
                    # Detect dangerous operations
                    if function_code in [5, 6, 16]:  # Write operations
                        honeypot_attack_attempts.labels(
                            pattern='modbus_write_operation',
                            source_ip=source_ip,
                            port=str(self.port)
                        ).inc()
                        honeypot_alerts.labels(
                            severity='high',
                            service=self.service_name,
                            source_ip=source_ip
                        ).inc()
                        logger.warning(f"MODBUS write operation from {source_ip}: Function {function_code}")
                    
                    # Send response
                    response = bytearray(data[:8])
                    conn.send(bytes(response))
                    
            except Exception as e:
                logger.error(f"MODBUS parsing error: {e}")
            
            duration = time.time() - start_time
            honeypot_session_duration.labels(service=self.service_name).observe(duration)
            
        except Exception as e:
            logger.error(f"MODBUS handler error: {e}")
        finally:
            conn.close()
    
    def start(self):
        """Start MODBUS honeypot"""
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        sock.bind(('0.0.0.0', self.port))
        sock.listen(5)
        logger.info(f"MODBUS Honeypot listening on port {self.port}")
        
        while True:
            try:
                conn, addr = sock.accept()
                conn.settimeout(10)
                thread = threading.Thread(
                    target=self.handle_connection,
                    args=(conn, addr)
                )
                thread.daemon = True
                thread.start()
            except Exception as e:
                logger.error(f"MODBUS listener error: {e}")


class HTTPHoneypot:
    """HTTP Honeypot Service"""
    
    def __init__(self, port=8080):
        self.port = port
        self.service_name = 'http'
        
    def handle_connection(self, conn, addr):
        """Handle HTTP connection"""
        try:
            source_ip = addr[0]
            logger.info(f"HTTP connection from {source_ip}:{addr[1]}")
            
            honeypot_connections.labels(
                port=str(self.port),
                source_ip=source_ip,
                service=self.service_name
            ).inc()
            
            attacker_ips.add(source_ip)
            unique_attackers.set(len(attacker_ips))
            
            start_time = time.time()
            
            try:
                data = conn.recv(4096)
                if data:
                    payload_size = len(data)
                    honeypot_payload_size.labels(service=self.service_name).observe(payload_size)
                    
                    request_str = data.decode('utf-8', errors='ignore')
                    logger.info(f"HTTP request from {source_ip}: {len(request_str)} bytes")
                    
                    # Detect attack patterns
                    if 'union' in request_str.lower() or 'select' in request_str.lower():
                        honeypot_attack_attempts.labels(
                            pattern='sql_injection',
                            source_ip=source_ip,
                            port=str(self.port)
                        ).inc()
                        honeypot_alerts.labels(
                            severity='high',
                            service=self.service_name,
                            source_ip=source_ip
                        ).inc()
                        logger.warning(f"SQL injection attempt from {source_ip}")
                    
                    if '../' in request_str or '..\\' in request_str:
                        honeypot_attack_attempts.labels(
                            pattern='path_traversal',
                            source_ip=source_ip,
                            port=str(self.port)
                        ).inc()
                        honeypot_alerts.labels(
                            severity='high',
                            service=self.service_name,
                            source_ip=source_ip
                        ).inc()
                        logger.warning(f"Path traversal attempt from {source_ip}")
                    
                    # Send fake response
                    response = b"HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: 13\r\n\r\nHello World!\n"
                    conn.send(response)
                    
            except Exception as e:
                logger.error(f"HTTP parsing error: {e}")
            
            duration = time.time() - start_time
            honeypot_session_duration.labels(service=self.service_name).observe(duration)
            
        except Exception as e:
            logger.error(f"HTTP handler error: {e}")
        finally:
            conn.close()
    
    def start(self):
        """Start HTTP honeypot"""
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        sock.bind(('0.0.0.0', self.port))
        sock.listen(5)
        logger.info(f"HTTP Honeypot listening on port {self.port}")
        
        while True:
            try:
                conn, addr = sock.accept()
                conn.settimeout(10)
                thread = threading.Thread(
                    target=self.handle_connection,
                    args=(conn, addr)
                )
                thread.daemon = True
                thread.start()
            except Exception as e:
                logger.error(f"HTTP listener error: {e}")


def main():
    """Main honeypot coordinator"""
    logger.info("Starting ConSEC Industrial Honeypot...")
    
    # Start Prometheus metrics server
    logger.info("Starting Prometheus metrics server on port 9445")
    start_http_server(9445)
    
    # Initialize honeypots
    ssh_hp = SSHHoneypot(port=2222)
    telnet_hp = TelnetHoneypot(port=2323)
    modbus_hp = ModbusHoneypot(port=5502)
    http_hp = HTTPHoneypot(port=8080)
    
    # Start honeypots in threads
    services = [
        ('SSH', ssh_hp.start),
        ('Telnet', telnet_hp.start),
        ('MODBUS', modbus_hp.start),
        ('HTTP', http_hp.start),
    ]
    
    for name, start_func in services:
        thread = threading.Thread(target=start_func)
        thread.daemon = True
        thread.start()
        logger.info(f"{name} honeypot started")
        time.sleep(0.5)
    
    logger.info("All honeypots started successfully")
    logger.info("Honeypot running... Press Ctrl+C to stop")
    
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        logger.info("Honeypot shutting down...")


if __name__ == '__main__':
    main()
