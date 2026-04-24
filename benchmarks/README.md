# Professional Benchmark Suite for Polyglot Realtime Engine

This directory contains production-grade benchmarking tools for comprehensive performance validation.

## 📋 What's Included

### k6 Load Tests (`k6/`)
- **load_test.js** - Comprehensive load test with staged ramp-up, WebSocket testing, and custom metrics
- **stress_test.js** - Push system to breaking point (1000-2000 concurrent users)
- **soak_test.js** - Long-running stability test (35 minutes) for memory leak detection

### wrk HTTP Benchmarks (`wrk/`)
- **throughput.lua** - Ultra-fast HTTP benchmark with detailed latency distribution

### Chaos Engineering (`chaos/`)
- **README.md** - Complete chaos engineering scenarios including:
  - Circuit breaker validation
  - Database failure simulation
  - Network partition testing
  - CPU throttling tests
  - gRPC failover scenarios

### Profiling Guides (`profiling/`)
- **README.md** - Deep dive profiling instructions for:
  - Go processor (pprof)
  - Elixir gateway (observer, telemetry)
  - PostgreSQL (pg_stat_statements)
  - Redis (slow log, memory analysis)
  - System-wide (perf, eBPF)

## 🚀 Quick Start

### Prerequisites

Install benchmarking tools:

```bash
# k6 (Load testing)
brew install k6
# or
curl https://github.com/grafana/k6/releases/download/v0.47.0/k6-v0.47.0-linux-amd64.tar.gz -L | tar xz
sudo cp k6-v0.47.0-linux-amd64/k6 /usr/local/bin/k6

# wrk (HTTP benchmarking)
brew install wrk
# or
apt-get install wrk

# Docker Compose (for running services)
docker-compose up -d
```

### Run All Benchmarks

```bash
cd benchmarks
./run_all_benchmarks.sh all
```

### Run Specific Tests

```bash
# k6 load test (recommended for CI)
./run_all_benchmarks.sh k6

# Stress test (push to limits)
./run_all_benchmarks.sh stress

# Soak test (35 min stability check)
./run_all_benchmarks.sh soak

# wrk HTTP throughput
./run_all_benchmarks.sh wrk 30s 4 200

# Legacy Go benchmarks
./run_all_benchmarks.sh legacy
```

## 📊 Test Scenarios

### 1. Load Test (k6/load_test.js)

**Duration:** ~5 minutes  
**Peak Load:** 500 concurrent users  

**Features:**
- Staged ramp-up (100 → 200 → 500 users)
- HTTP publish + history retrieval
- WebSocket connections (every 5th user)
- gRPC processor batch testing
- Custom metrics tracking
- Automatic thresholds (P95 < 100ms, error rate < 1%)

**Run:**
```bash
k6 run benchmarks/k6/load_test.js
```

### 2. Stress Test (k6/stress_test.js)

**Duration:** ~4.5 minutes  
**Peak Load:** 2000 concurrent users  

**Purpose:** Find breaking point and validate circuit breakers

**Run:**
```bash
k6 run benchmarks/k6/stress_test.js
```

### 3. Soak Test (k6/soak_test.js)

**Duration:** 35 minutes  
**Load:** 50 concurrent users (sustained)  

**Purpose:** Detect memory leaks and performance degradation

**Run:**
```bash
k6 run benchmarks/k6/soak_test.js
```

### 4. HTTP Throughput (wrk/throughput.lua)

**Duration:** Configurable (default 30s)  
**Connections:** Configurable (default 100)  

**Output:** Detailed latency percentiles (50th, 75th, 90th, 95th, 99th, 99.9th)

**Run:**
```bash
wrk -t4 -c200 -d30s -s benchmarks/wrk/throughput.lua http://localhost:4000
```

## 📈 Metrics Collected

### k6 Metrics
- **http_req_duration**: Request latency (P95, P99)
- **http_req_failed**: Error rate
- **ws_session_duration**: WebSocket connection time
- **Custom metrics:**
  - `errors`: Application-level errors
  - `messages_sent`: Published messages count
  - `messages_received`: Received messages count
  - `successful_connections`: WebSocket connections

### wrk Metrics
- Requests per second
- Latency distribution (min, max, avg, stdev)
- Percentiles (50th → 99.9th)
- Error count

## 🎯 Performance Targets

| Metric | Target | Critical Threshold |
|--------|--------|-------------------|
| P95 Latency | < 100ms | > 200ms |
| P99 Latency | < 200ms | > 500ms |
| Error Rate | < 1% | > 5% |
| Throughput | > 10k req/s | < 5k req/s |
| WebSocket Connect | < 50ms | > 100ms |

## 🔬 Advanced Usage

### Environment Variables

```bash
export BASE_URL=http://localhost:4000
export WS_URL=ws://localhost:4000/socket/websocket
export API_KEY=valid_key_demo-app
export APP_ID=demo-app

k6 run benchmarks/k6/load_test.js
```

### Output to JSON

```bash
k6 run --out json=results/load_test.json benchmarks/k6/load_test.js
```

### Compare Results

```bash
# Baseline
./run_all_benchmarks.sh all > baseline.md

# After optimization
./run_all_benchmarks.sh all > optimized.md

# Compare
diff -u baseline.md optimized.md
```

## 🧪 Chaos Engineering

See [chaos/README.md](chaos/README.md) for detailed scenarios:

1. **Circuit Breaker Test** - Stop processor, verify failover
2. **Database Failure** - Kill PostgreSQL, test graceful degradation
3. **Memory Pressure** - Run soak test, monitor memory trends
4. **Network Partition** - Disconnect services, test recovery
5. **CPU Throttling** - Limit resources, validate backpressure
6. **gRPC Failover** - Block port 9090, verify HTTP fallback

## 📝 Reports

Results are saved to `benchmarks/results/`:
- `k6_*.log` - k6 test logs
- `k6_*.json` - k6 raw metrics
- `wrk_*.txt` - wrk output
- `benchmark_report_*.md` - Auto-generated summary

## 🤖 CI/CD Integration

The benchmark suite is integrated into GitHub Actions (`.github/workflows/ci.yml`):

- Runs on every push to `main`
- Performance regression checks on PRs
- Automatic artifact upload
- Slack notifications on failures

## 🛠 Troubleshooting

### k6 not found
```bash
# Install k6
brew install k6
# Verify
k6 version
```

### Services not responding
```bash
# Check health
curl http://localhost:4000/health
curl http://localhost:8080/health

# Restart if needed
docker-compose restart
```

### WebSocket tests failing
```bash
# Verify WebSocket endpoint
wscat -c ws://localhost:4000/socket/websocket
```

## 📚 Resources

- [k6 Documentation](https://k6.io/docs/)
- [wrk GitHub](https://github.com/wg/wrk)
- [Chaos Engineering Principles](https://principlesofchaos.org/)
- [Go pprof](https://pkg.go.dev/net/http/pprof)
- [Erlang Efficiency Guide](https://www.erlang.org/doc/efficiency_guide.html)

---

*Last updated: 2024*  
*Maintained by: Polyglot Team*
