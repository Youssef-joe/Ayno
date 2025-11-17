#!/bin/bash

# Stress Test for Polyglot
# Tests system under increasing load

echo "🔥 Polyglot Stress Test"
echo "=================================="
echo ""

API_KEY="valid_key_stress-test"
APP_ID="stress-test"
CHANNEL="room:1"
BASE_URL="http://localhost:4000"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

run_stress_test() {
    local concurrent_requests=$1
    local duration=$2
    
    echo -e "${YELLOW}Test: $concurrent_requests concurrent requests for ${duration}s${NC}"
    
    success=0
    failed=0
    total=0
    start=$(date +%s%N)
    end_time=$(($(date +%s) + duration))
    
    while [ $(date +%s) -lt $end_time ]; do
        for i in $(seq 1 $concurrent_requests); do
            (
                response=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/apps/$APP_ID/channels/$CHANNEL/publish" \
                  -H "Content-Type: application/json" \
                  -H "X-API-Key: $API_KEY" \
                  -d "{\"type\": \"stress\", \"data\": {\"id\": $((RANDOM)), \"msg\": \"load test\"}}")
                
                http_code=$(echo "$response" | tail -n1)
                if [ "$http_code" = "200" ]; then
                    ((success++))
                else
                    ((failed++))
                fi
                ((total++))
            ) &
        done
        wait
    done
    
    elapsed=$(($(date +%s%N) - start))
    elapsed_sec=$((elapsed / 1000000000))
    throughput=$((total / elapsed_sec))
    
    echo -e "${GREEN}✓ Completed: $total requests${NC}"
    echo "  Success: $success | Failed: $failed"
    echo "  Throughput: ~$throughput req/s"
    echo ""
}

# Check server health
echo "Checking server health..."
if ! curl -s http://localhost:4000/health > /dev/null; then
    echo -e "${RED}❌ Server not responding on http://localhost:4000${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Server is healthy${NC}"
echo ""

# Progressive load testing
echo "Starting progressive load test..."
echo "=================================="
echo ""

# Light load
run_stress_test 5 3

# Medium load
run_stress_test 25 3

# Heavy load
run_stress_test 50 3

# Very heavy load
run_stress_test 100 3

echo -e "${GREEN}✅ Stress test complete!${NC}"
echo ""
echo "Summary:"
echo "--------"
echo "• Light load (5 concurrent): Expected 100+ req/s"
echo "• Medium load (25 concurrent): Expected 500+ req/s"
echo "• Heavy load (50 concurrent): Expected 1000+ req/s"
echo "• Very heavy load (100 concurrent): Expected 2000+ req/s"
echo ""
echo "If throughput drops significantly at higher loads,"
echo "consider scaling with docker-compose or adding Redis."
