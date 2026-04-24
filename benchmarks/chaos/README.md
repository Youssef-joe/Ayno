# Chaos Engineering Tests for Polyglot Realtime Engine

This directory contains chaos engineering scenarios to test system resilience under failure conditions.

## Prerequisites

- Docker Compose running with Polyglot services
- `chaos-mesh` or `litmuschaos` (optional, for Kubernetes)
- Manual testing capabilities for local development

## Test Scenarios

### 1. Circuit Breaker Validation

**Objective:** Verify circuit breaker opens after repeated failures and recovers automatically.

**Steps:**
```bash
# Stop the Go processor to simulate failure
docker-compose stop processor

# Run load test - should trigger circuit breaker
./benchmarks/run_all_benchmarks.sh k6

# Observe:
# - Circuit breaker should open after 5 consecutive failures
# - System should failover to HTTP fallback
# - After 30s, circuit should half-open and test recovery

# Restart processor
docker-compose start processor

# Verify recovery
curl http://localhost:8080/health
```

**Expected Behavior:**
- Error rate spikes initially
- Automatic failover to backup systems
- Gradual recovery as circuit breaker tests connection
- Full recovery within 60 seconds

---

### 2. Database Failure Simulation

**Objective:** Test system behavior when PostgreSQL becomes unavailable.

**Steps:**
```bash
# Simulate database slowdown
docker-compose exec postgres pg_ctl stop -m fast

# Run benchmarks
./benchmarks/run_all_benchmarks.sh stress

# Check Redis fallback (if configured)
# Verify error messages are appropriate
```

**Expected Behavior:**
- Graceful degradation
- Proper error messages to clients
- No data corruption
- Recovery without manual intervention

---

### 3. Memory Pressure Test

**Objective:** Identify memory leaks under sustained load.

**Steps:**
```bash
# Run soak test for 35 minutes
./benchmarks/run_all_benchmarks.sh soak

# Monitor memory usage
docker stats --no-stream

# Check for increasing memory trend
```

**Metrics to Watch:**
- Elixir gateway memory usage
- Go processor heap size
- Redis memory consumption
- PostgreSQL shared buffers

---

### 4. Network Partition Simulation

**Objective:** Test behavior when services cannot communicate.

**Using Docker network:**
```bash
# Create network partition
docker network disconnect polyglot_default processor

# Run tests
./benchmarks/run_all_benchmarks.sh k6

# Reconnect
docker network connect polyglot_default processor
```

**Expected Behavior:**
- Timeout handling
- Retry logic activation
- Circuit breaker engagement
- Eventual consistency restoration

---

### 5. CPU Throttling Test

**Objective:** Validate performance under resource constraints.

**Using Docker:**
```bash
# Limit CPU for processor service
docker update --cpus="0.5" polyglot-processor-1

# Run stress test
./benchmarks/run_all_benchmarks.sh stress

# Remove limit
docker update --cpus="2.0" polyglot-processor-1
```

**Expected Behavior:**
- Increased latency but no crashes
- Proper queue management
- Backpressure handling

---

### 6. Redis Cluster Failover

**Objective:** Test Redis cluster failover scenarios.

**Steps:**
```bash
# If using Redis cluster, kill one node
docker-compose stop redis-slave-1

# Verify master takes over
# Check replication recovery
```

---

### 7. gRPC Service Degradation

**Objective:** Test fallback from gRPC to HTTP.

**Steps:**
```bash
# Block gRPC port
iptables -A INPUT -p tcp --dport 9090 -j DROP

# Run tests - should use HTTP fallback on port 8080
./benchmarks/run_all_benchmarks.sh k6

# Restore gRPC
iptables -D INPUT -p tcp --dport 9090 -j DROP
```

**Expected Behavior:**
- Automatic protocol switch
- Slight latency increase acceptable
- No request loss

---

## Automation with Chaos Mesh (Kubernetes)

For Kubernetes deployments, use Chaos Mesh:

```yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: PodChaos
metadata:
  name: processor-failure
spec:
  action: pod-failure
  mode: one
  duration: "30s"
  selector:
    pods:
      default: ["polyglot-processor-*"]
```

## Metrics to Monitor

During all chaos tests, monitor:

1. **Error Rates**
   - HTTP 5xx responses
   - WebSocket disconnections
   - gRPC errors

2. **Latency**
   - P50, P95, P99 percentiles
   - Timeout frequency

3. **Recovery Time**
   - Time to detect failure
   - Time to failover
   - Time to full recovery

4. **Data Integrity**
   - Message loss count
   - Duplicate messages
   - Order violations

## Reporting

After each chaos test, document:

- [ ] Failure scenario tested
- [ ] Expected vs actual behavior
- [ ] Recovery time
- [ ] Data loss (if any)
- [ ] Action items for improvement

## Safety Notes

⚠️ **WARNING:** Only run chaos tests in:
- Development environments
- Staging environments with production-like data
- Production with extreme caution and proper safeguards

Always have a rollback plan ready!
