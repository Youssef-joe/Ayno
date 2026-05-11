# Profiling Guide for Polyglot Realtime Engine

This directory contains profiling configurations and scripts for deep performance analysis.

## Tools Overview

### 1. Go Processor Profiling

#### CPU Profiling
```bash
# Enable pprof endpoint (already configured in processor)
# Access at: http://localhost:8080/debug/pprof/

# Collect CPU profile (30 seconds)
go tool pprof -http=:8081 http://localhost:8080/debug/pprof/profile?seconds=30

# Or save to file
curl -o cpu.prof http://localhost:8080/debug/pprof/profile?seconds=30
go tool pprof -http=:8081 cpu.prof
```

#### Memory Profiling
```bash
# Get heap profile
curl -o mem.prof http://localhost:8080/debug/pprof/heap

# Analyze
go tool pprof -http=:8081 mem.prof

# Force GC before profiling
curl http://localhost:8080/debug/pprof/heap?gc=1
```

#### Block Profiling
```bash
# Enable block profiling (add to main.go if not present)
// import _ "net/http/pprof"
// runtime.SetBlockProfileRate(1)

curl -o block.prof http://localhost:8080/debug/pprof/block
go tool pprof -http=:8081 block.prof
```

#### Mutex Profiling
```bash
# Enable mutex profiling
// runtime.SetMutexProfileFraction(1)

curl -o mutex.prof http://localhost:8080/debug/pprof/mutex
go tool pprof -http=:8081 mutex.prof
```

---

### 2. Elixir Gateway Profiling

#### Using Observer
```bash
# Start observer (requires Erlang GUI)
cd apps/gateway
iex -S mix

# In IEx:
:observer.start()
```

#### ETelemetry
```elixir
# Add to mix.exs
{:telemetry_poller, "~> 1.0"},
{:telemetry_metrics, "~> 0.6"}

# Configure in application.ex
```

#### Flame Graphs
```bash
# Install fprof
mix deps.get

# Profile specific function
:fprof.trace({:start, [:procs]})
# ... run load ...
:fprof.trace({:stop, []})
:fprof.analyze()
```

#### Memory Analysis
```bash
# Check memory usage
docker stats polyglot-gateway-1

# In IEx:
:erlang.memory()
:observer.start(:load)
```

---

### 3. PostgreSQL Profiling

#### Enable pg_stat_statements
```sql
-- Add to postgresql.conf
shared_preload_libraries = 'pg_stat_statements'
pg_stat_statements.track = all

-- Query slow queries
SELECT query, calls, total_time, mean_time
FROM pg_stat_statements
ORDER BY mean_time DESC
LIMIT 10;
```

#### EXPLAIN ANALYZE
```sql
EXPLAIN (ANALYZE, BUFFERS) 
SELECT * FROM events 
WHERE channel = 'room:test' 
ORDER BY created_at DESC 
LIMIT 100;
```

---

### 4. Redis Profiling

#### Slow Log
```bash
# Configure slow log threshold (microseconds)
redis-cli CONFIG SET slowlog-log-slower-than 10000

# View slow commands
redis-cli SLOWLOG GET 10

# Clear slow log
redis-cli SLOWLOG RESET
```

#### Memory Usage
```bash
# Check memory info
redis-cli INFO memory

# Analyze memory by key pattern
redis-cli --bigkeys

# Memory doctor
redis-cli MEMORY DOCTOR
```

---

### 5. System-Wide Profiling

#### perf (Linux)
```bash
# Record CPU cycles
sudo perf record -F 99 -p $(pgrep beam.smp) -g -- sleep 30

# Generate flame graph
sudo perf script | stackcollapse-perf.pl | flamegraph.pl > gateway-flame.svg

# For Go process
sudo perf record -F 99 -p $(pgrep processor) -g -- sleep 30
```

#### eBPF/bpftrace
```bash
# Install bpftrace
sudo apt-get install bpftrace

# Trace syscall latency
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_* /pid == $target/ { @start[tid] = nsecs; } tracepoint:syscalls:sys_exit_* /pid == $target/ { @latency = hist(nsecs - @start[tid]); }' -p $(pgrep processor)
```

#### htop/atop
```bash
# Real-time monitoring
htop

# Historical data
atop 5  # 5-second intervals
```

---

## Automated Profiling Script

```bash
#!/bin/bash
# profile_system.sh

PROFILE_DIR="./benchmarks/profiling/results_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$PROFILE_DIR"

echo "Starting profiling session..."

# Profile Go processor
echo "Profiling Go processor CPU..."
curl -o "$PROFILE_DIR/cpu.prof" "http://localhost:8080/debug/pprof/profile?seconds=30"

echo "Profiling Go processor memory..."
curl -o "$PROFILE_DIR/mem.prof" "http://localhost:8080/debug/pprof/heap"

# Profile PostgreSQL
echo "Capturing PostgreSQL slow queries..."
docker-compose exec postgres psql -U postgres -c \
  "SELECT query, calls, mean_time FROM pg_stat_statements ORDER BY mean_time DESC LIMIT 20;" \
  > "$PROFILE_DIR/pg_slow_queries.txt"

# Profile Redis
echo "Capturing Redis slow log..."
docker-compose exec redis redis-cli SLOWLOG GET 20 > "$PROFILE_DIR/redis_slow.log"

# System metrics
echo "Capturing system metrics..."
docker stats --no-stream > "$PROFILE_DIR/docker_stats.txt"

echo "Profiling complete! Results in: $PROFILE_DIR"
```

---

## Performance Optimization Checklist

### Go Processor
- [ ] Reduce allocations in hot paths
- [ ] Use sync.Pool for frequently allocated objects
- [ ] Optimize map access patterns
- [ ] Review goroutine leaks
- [ ] Tune GC parameters (GOGC)

### Elixir Gateway
- [ ] Optimize message passing
- [ ] Review GenServer state size
- [ ] Tune BEAM VM flags (+sbwt, +sdio)
- [ ] Check for binary memory leaks
- [ ] Optimize database queries

### Database
- [ ] Add missing indexes
- [ ] Optimize query plans
- [ ] Tune connection pool size
- [ ] Review vacuum settings
- [ ] Partition large tables

### Redis
- [ ] Use appropriate data structures
- [ ] Set TTL on ephemeral keys
- [ ] Optimize key naming (hash tags for cluster)
- [ ] Review maxmemory policy

---

## Benchmark Comparison

Run before and after optimizations:

```bash
# Baseline
./benchmarks/run_all_benchmarks.sh all > baseline_results.md

# After optimization
./benchmarks/run_all_benchmarks.sh all > optimized_results.md

# Compare
diff -u baseline_results.md optimized_results.md
```

---

## Resources

- [Go pprof documentation](https://pkg.go.dev/net/http/pprof)
- [Erlang Efficiency Guide](https://www.erlang.org/doc/efficiency_guide.html)
- [PostgreSQL Performance Tips](https://wiki.postgresql.org/wiki/Performance_Optimization)
- [Redis Performance Best Practices](https://redis.io/topics/performance)
