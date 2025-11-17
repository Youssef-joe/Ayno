# Polyglot Deployment Guide

**Last Updated:** November 17, 2025  
**Status:** Production-Ready (Phase 1 + Phase 2)

---

## Table of Contents
1. [Quick Start](#quick-start)
2. [Local Development](#local-development)
3. [Production Deployment](#production-deployment)
4. [Kubernetes](#kubernetes)
5. [Monitoring](#monitoring)
6. [Troubleshooting](#troubleshooting)

---

## Quick Start

### Easiest: One Command

```bash
./start.sh
```

This:
- Starts Redis (if available)
- Builds and runs Go processor
- Starts Elixir server
- Tests all endpoints

### Manual: 3 Terminals

**Terminal 1: Redis**
```bash
redis-server
```

**Terminal 2: Go Processor**
```bash
cd go_processor
go build -o processor main.go server.go
./processor
```

**Terminal 3: Elixir Gateway**
```bash
mix phx.server
```

### Test

```bash
# Health check
curl http://localhost:4000/health

# Publish event
curl -X POST http://localhost:4000/apps/demo-app/channels/room:test/publish \
  -H "Content-Type: application/json" \
  -H "X-API-Key: valid_key_demo-app" \
  -d '{"type": "message", "data": {"text": "Hello"}}'

# Get history
curl http://localhost:4000/apps/demo-app/channels/room:test/history
```

---

## Local Development

### Setup

```bash
# Clone and prepare
git clone <repo>
cd polyglot
cp .env.example .env

# Dependencies
mix deps.get
cd go_processor && go mod tidy && cd ..

# Build
mix compile
cd go_processor && go build -o processor main.go server.go && cd ..
```

### Running Services

**Start Redis (if using Docker):**
```bash
docker run -d -p 6379:6379 --name polyglot-redis redis:7-alpine
```

**Start all services:**
```bash
./start.sh
```

### Development Workflow

```bash
# Watch for changes
iex -S mix phx.server

# In another terminal, test
curl -X POST http://localhost:4000/apps/test/channels/room:1/publish \
  -H "Content-Type: application/json" \
  -H "X-API-Key: valid_key_test" \
  -d '{"type":"msg","data":{"text":"test"}}'
```

---

## Production Deployment

### Architecture

```
Load Balancer (Nginx/HAProxy)
    ↓
Polyglot (3 instances)  ← Redis Cluster
    ↓
Go Processors (2 instances)
    ↓
C++ Driver (optional)
```

### Step 1: Build Images

```bash
# Build Elixir app
docker build -t polyglot:latest .

# Build Go processor
docker build -t polyglot-processor:latest go_processor/
```

### Step 2: Environment Setup

```bash
# Create .env for production
SECRET_KEY_BASE=$(openssl rand -hex 32)
JWT_SECRET=$(openssl rand -hex 32)

# Save to deployment
cat > .env.prod << EOF
SECRET_KEY_BASE=$SECRET_KEY_BASE
JWT_SECRET=$JWT_SECRET
MIX_ENV=prod
REDIS_HOST=redis-cluster-host
REDIS_PORT=6379
GO_PROCESSOR_URL=http://go-processor:8080
APP_HOST=api.example.com
CORS_ORIGINS=https://example.com
EOF
```

### Step 3: Docker Compose (3 instances)

```bash
# Scale Elixir servers
docker compose up --scale polyglot=3 --scale go-processor=2

# Or with env file
docker compose -f docker-compose.prod.yml up
```

### Step 4: Load Balancer (Nginx)

```nginx
upstream polyglot {
    least_conn;
    server localhost:4000 max_fails=2 fail_timeout=30s;
    server localhost:4001 max_fails=2 fail_timeout=30s;
    server localhost:4002 max_fails=2 fail_timeout=30s;
}

server {
    listen 80;
    server_name api.example.com;
    
    location / {
        proxy_pass http://polyglot;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        
        # Health checks
        proxy_connect_timeout 5s;
        proxy_send_timeout 10s;
        proxy_read_timeout 10s;
    }
    
    location /health {
        access_log off;
        proxy_pass http://polyglot;
    }
}
```

---

## Kubernetes

### Manifest Example

```yaml
---
apiVersion: v1
kind: Namespace
metadata:
  name: polyglot

---
apiVersion: v1
kind: ConfigMap
metadata:
  name: polyglot-config
  namespace: polyglot
data:
  MIX_ENV: "prod"
  LOG_LEVEL: "info"
  GO_PROCESSOR_URL: "http://go-processor:8080"

---
apiVersion: v1
kind: Secret
metadata:
  name: polyglot-secrets
  namespace: polyglot
type: Opaque
stringData:
  SECRET_KEY_BASE: "$(openssl rand -hex 32)"
  JWT_SECRET: "$(openssl rand -hex 32)"

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: polyglot-api
  namespace: polyglot
spec:
  replicas: 3
  selector:
    matchLabels:
      app: polyglot-api
  template:
    metadata:
      labels:
        app: polyglot-api
    spec:
      containers:
      - name: api
        image: polyglot:latest
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 4000
          name: http
        - containerPort: 4369
          name: epmd
        env:
        - name: MIX_ENV
          valueFrom:
            configMapKeyRef:
              name: polyglot-config
              key: MIX_ENV
        - name: SECRET_KEY_BASE
          valueFrom:
            secretKeyRef:
              name: polyglot-secrets
              key: SECRET_KEY_BASE
        - name: JWT_SECRET
          valueFrom:
            secretKeyRef:
              name: polyglot-secrets
              key: JWT_SECRET
        - name: REDIS_HOST
          value: redis-cluster
        - name: GO_PROCESSOR_URL
          value: "http://go-processor:8080"
        
        resources:
          requests:
            cpu: "500m"
            memory: "512Mi"
          limits:
            cpu: "2000m"
            memory: "2Gi"
        
        livenessProbe:
          httpGet:
            path: /alive
            port: 4000
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        
        readinessProbe:
          httpGet:
            path: /ready
            port: 4000
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 2

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: go-processor
  namespace: polyglot
spec:
  replicas: 2
  selector:
    matchLabels:
      app: go-processor
  template:
    metadata:
      labels:
        app: go-processor
    spec:
      containers:
      - name: processor
        image: polyglot-processor:latest
        ports:
        - containerPort: 8080
          name: http
        - containerPort: 9090
          name: grpc
        
        resources:
          requests:
            cpu: "250m"
            memory: "256Mi"
          limits:
            cpu: "1000m"
            memory: "1Gi"
        
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 15
          periodSeconds: 10
        
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5

---
apiVersion: v1
kind: Service
metadata:
  name: polyglot-api
  namespace: polyglot
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 4000
    protocol: TCP
    name: http
  selector:
    app: polyglot-api

---
apiVersion: v1
kind: Service
metadata:
  name: go-processor
  namespace: polyglot
spec:
  type: ClusterIP
  ports:
  - port: 8080
    targetPort: 8080
    protocol: TCP
    name: http
  - port: 9090
    targetPort: 9090
    protocol: TCP
    name: grpc
  selector:
    app: go-processor
```

### Deploy

```bash
# Apply manifest
kubectl apply -f k8s/polyglot.yaml

# Check status
kubectl get pods -n polyglot
kubectl logs -f -n polyglot deployment/polyglot-api

# Port forward (for testing)
kubectl port-forward -n polyglot svc/polyglot-api 8080:80
```

---

## Monitoring

### Health Endpoints

```bash
# Liveness (is the pod alive?)
curl http://localhost:4000/alive
# Returns 200 always

# Readiness (can it handle traffic?)
curl http://localhost:4000/ready
# Returns 200 if healthy, 503 if degraded

# Full status
curl http://localhost:4000/health
```

### Prometheus Metrics

Add to config:

```elixir
config :polyglot, :telemetry,
  enabled: true,
  exporter: :prometheus
```

### Logs

```bash
# Follow Elixir logs
docker logs -f polyglot_1

# Follow Go logs
docker logs -f go-processor_1

# Check circuit breaker status
curl http://localhost:4000/api/debug/circuit-breaker
```

### Alerts

Monitor these metrics:

```
✅ Error rate (< 1%)
✅ Response latency P99 (< 100ms)
✅ Circuit breaker status (should be closed)
✅ /ready endpoint (should be 200)
✅ Go processor availability (should be 100%)
```

---

## Troubleshooting

### Issue: "Connection refused" on Go processor

**Symptom:** Events fail to process

**Fix:**
```bash
# Check if Go is running
curl http://localhost:8080/health

# Restart
pkill processor
cd go_processor && ./processor &
```

### Issue: Redis connection error

**Symptom:** PubSub events not distributed

**Fix:**
```bash
# Check Redis
redis-cli ping

# Check config
echo $REDIS_HOST
echo $REDIS_PORT

# Restart
docker restart polyglot-redis
```

### Issue: Circuit breaker is open

**Symptom:** /ready returns 503, events fail

**Fix:**
```bash
# This is expected - indicates Go processor is down
# Wait 30 seconds for recovery attempt
# Or restart Go processor
cd go_processor && ./processor &

# Check recovery
curl http://localhost:4000/ready
# Should return 200 after recovery
```

### Issue: High latency (> 100ms)

**Symptom:** Slow event processing

**Fix:**
```bash
# Check system resources
top
free -m

# Run benchmark
./benchmark_http.sh

# Scale horizontally
docker compose up --scale polyglot=5

# Enable gRPC (Phase 2)
USE_GRPC=true mix phx.server
```

### Issue: Memory leak

**Symptom:** Memory grows over time

**Fix:**
```bash
# Check ETS table
iex(1)> :ets.info(:event_history)

# Limit history size
# Edit router.ex to cap history at 1000 events

# Use Redis instead
REDIS_HOST=localhost mix phx.server
```

---

## Performance Tuning

### Increase Concurrency

```elixir
# config/prod.exs
config :polyglot, Polyglot.Gateway.Endpoint,
  http: [
    port: 4000,
    transport_options: [
      max_connections: 16_384,
      num_acceptors: 100
    ]
  ]
```

### Enable gRPC (Phase 2)

```bash
USE_GRPC=true GO_PROCESSOR_GRPC_PORT=9090 mix phx.server
```

### Connection Pooling

```elixir
# lib/polyglot/processor_client.ex
@pool_size 20  # Increase from 10
```

### Redis Optimization

```bash
# redis.conf
maxmemory 2gb
maxmemory-policy allkeys-lru
```

---

## Scaling

### Vertical (Single Instance)

- Increase CPU cores
- Increase memory (2-4GB)
- Enable connection pooling
- Use gRPC

### Horizontal (Multiple Instances)

```bash
# Scale to 5 Elixir + 3 Go processors
docker compose up --scale polyglot=5 --scale go-processor=3
```

### Distributed (Kubernetes)

```bash
# Increase replicas
kubectl scale deployment polyglot-api -n polyglot --replicas=10
```

---

## Rollback

If something breaks:

```bash
# Stop new version
docker compose down

# Restart with previous image
docker compose up

# Or with Kubernetes
kubectl rollout undo deployment/polyglot-api -n polyglot
```

---

## Next Steps

1. **Phase 2 Activation** (1-2 weeks)
   - Enable gRPC code generation
   - Benchmark for 5x improvement
   - Deploy to production

2. **Phase 3** (4-8 weeks)
   - Implement C++ native module
   - WebSocket multiplexing
   - Ultra-high frequency support

3. **Enterprise** (Ongoing)
   - Custom authentication
   - Advanced analytics
   - Multi-region replication

---

## Support

- **Docs:** See BENCHMARKS.md, PERFORMANCE_SUMMARY.md
- **Issues:** Check logs with `docker logs`
- **Performance:** Run ./benchmark_http.sh
- **Testing:** Use ./stress_test.sh

---

**Questions?** Check the README or run `mix docs` for API documentation.
