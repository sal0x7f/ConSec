#!/bin/bash

echo "[*] Starting industrial security stack test..."
echo ""

# Test 1: Ping to verify network connectivity
echo "Test 1: Network connectivity check"
ping -c 2 8.8.8.8 2>&1 | tail -2
echo ""

# Test 2: Simulate Modbus traffic (port 502)
echo "Test 2: Testing Modbus-like traffic (port 502)"
(timeout 2 bash -c 'echo -e "GET / HTTP/1.1\r\nHost: localhost\r\n\r\n" > /dev/tcp/127.0.0.1/502' 2>/dev/null) || echo "No service on 502 (expected)"
echo ""

# Test 3: Simulate HTTP requests  
echo "Test 3: Testing HTTP traffic (port 80)"
(timeout 2 bash -c 'echo -e "GET / HTTP/1.1\r\nHost: localhost\r\n\r\n" > /dev/tcp/127.0.0.1/80' 2>/dev/null) || echo "No service on 80 (expected)"
echo ""

# Test 4: Simulate DNS queries
echo "Test 4: DNS queries"
nslookup localhost 127.0.0.1 2>&1 | head -5
echo ""

# Test 5: Multiple connections to trigger detection rules
echo "Test 5: Generating test connection patterns..."
for i in {1..5}; do
  (timeout 1 bash -c "echo test > /dev/tcp/127.0.0.1/22" 2>/dev/null) &
done
wait
echo "Sent 5 test connections"
echo ""

# Test 6: Check Suricata is detecting traffic
echo "Test 6: Checking Suricata logs..."
docker compose exec suricata ls -la /var/log/suricata/ 2>/dev/null || echo "Cannot access Suricata logs"
echo ""

# Test 7: Check Prometheus metrics are being collected
echo "Test 7: Checking Prometheus collection..."
curl -s http://localhost:9090/api/v1/query?query=up | jq '.data.result | length' 2>/dev/null || echo "Cannot query Prometheus"
echo ""

echo "[+] Test complete!"
