# wrk HTTP Benchmark Script for Polyglot
# Ultra-fast HTTP load testing with Lua scripting

-- Basic throughput test
wrk.method = "POST"
wrk.body = '{"type":"benchmark","data":{"timestamp":"' .. os.time() .. '"}}'
wrk.headers["Content-Type"] = "application/json"
wrk.headers["X-API-Key"] = "valid_key_demo-app"

local app_id = "demo-app"
local channel = "bench:throughput"

-- Request path generator
local counter = 0
function init(args)
  local base_url = args[1] or "http://localhost:4000"
  wrk.url = base_url .. "/apps/" .. app_id .. "/channels/" .. channel .. "/publish"
  print("Starting wrk benchmark against:", wrk.url)
end

-- Response handler with latency tracking
done = function(summary, latency, requests)
  io.write("------------------------------------------------------------\n")
  io.write("Polyglot Benchmark Results\n")
  io.write("------------------------------------------------------------\n")
  io.write(string.format("  Requests:        %10d total\n", summary.requests))
  io.write(string.format("  Duration:        %10.2f seconds\n", summary.duration / 1000000))
  io.write(string.format("  Throughput:      %10.2f req/sec\n", summary.requests / (summary.duration / 1000000)))
  io.write("\n")
  io.write("Latency Distribution:\n")
  io.write(string.format("  Min:             %10.2f ms\n", latency.min / 1000))
  io.write(string.format("  Max:             %10.2f ms\n", latency.max / 1000))
  io.write(string.format("  Avg:             %10.2f ms\n", latency.mean / 1000))
  io.write(string.format("  Stdev:           %10.2f ms\n", latency.stdev / 1000))
  io.write("\n")
  io.write("Percentiles:\n")
  io.write(string.format("  50th:            %10.2f ms\n", latency:percentile(50) / 1000))
  io.write(string.format("  75th:            %10.2f ms\n", latency:percentile(75) / 1000))
  io.write(string.format("  90th:            %10.2f ms\n", latency:percentile(90) / 1000))
  io.write(string.format("  95th:            %10.2f ms\n", latency:percentile(95) / 1000))
  io.write(string.format("  99th:            %10.2f ms\n", latency:percentile(99) / 1000))
  io.write(string.format("  99.9th:          %10.2f ms\n", latency:percentile(99.9) / 1000))
  io.write("------------------------------------------------------------\n")
  
  -- Check error rate
  if summary.errors > 0 then
    io.write(string.format("\n  ⚠️  ERRORS: %d requests failed!\n", summary.errors))
  else
    io.write("\n  ✅ All requests successful!\n")
  end
end

-- Request interceptor for dynamic data
request = function()
  counter = counter + 1
  wrk.body = '{"type":"benchmark","data":{"counter":' .. counter .. ',"ts":"' .. os.time() .. '"}}'
  return wrk.request()
end
