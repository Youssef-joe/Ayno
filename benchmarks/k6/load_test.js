// k6 Load Test Script for Polyglot Realtime Engine
// Professional-grade load testing with comprehensive metrics

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';
import ws from 'k6/ws';

// Custom Metrics
const errorRate = new Rate('errors');
const latencyP95 = new Trend('latency_p95');
const successfulConnections = new Counter('successful_connections');
const messagesSent = new Counter('messages_sent');
const messagesReceived = new Counter('messages_received');

// Test Configuration
export const options = {
  stages: [
    { duration: '30s', target: 100 },   // Ramp up to 100 users
    { duration: '1m', target: 100 },    // Stay at 100 users
    { duration: '30s', target: 200 },   // Ramp up to 200 users
    { duration: '1m', target: 200 },    // Stay at 200 users
    { duration: '30s', target: 500 },   // Ramp up to 500 users (stress test)
    { duration: '1m', target: 500 },    // Peak load
    { duration: '30s', target: 0 },     // Ramp down
  ],
  thresholds: {
    'http_req_duration': ['p(95)<100'],  // 95% of requests should complete below 100ms
    'http_req_failed': ['rate<0.01'],    // Error rate should be less than 1%
    'ws_session_duration': ['p(95)<200'], // WebSocket connections should be fast
    'errors': ['rate<0.01'],             // Custom error rate threshold
  },
};

// Test Data
const BASE_URL = __ENV.BASE_URL || 'http://localhost:4000';
const WS_URL = __ENV.WS_URL || 'ws://localhost:4000/socket/websocket';
const API_KEY = __ENV.API_KEY || 'valid_key_demo-app';
const APP_ID = __ENV.APP_ID || 'demo-app';

// HTTP API Tests
export function httpPublishTest() {
  const payload = {
    type: 'message',
    data: { text: `Test message at ${Date.now()}` }
  };

  const params = {
    headers: {
      'Content-Type': 'application/json',
      'X-API-Key': API_KEY,
    },
  };

  const res = http.post(
    `${BASE_URL}/apps/${APP_ID}/channels/room:test/publish`,
    JSON.stringify(payload),
    params
  );

  const success = check(res, {
    'status is 200': (r) => r.status === 200,
    'response has success': (r) => JSON.parse(r.body).success === true,
  });

  errorRate.add(!success);
  
  if (success) {
    messagesSent.add(1);
  }

  return res;
}

export function httpHistoryTest() {
  const params = {
    headers: {
      'X-API-Key': API_KEY,
    },
  };

  const res = http.get(
    `${BASE_URL}/apps/${APP_ID}/channels/room:test/history?limit=100`,
    params
  );

  check(res, {
    'history status is 200': (r) => r.status === 200,
    'history returns array': (r) => {
      const body = JSON.parse(r.body);
      return Array.isArray(body.events) || Array.isArray(body.messages);
    },
  });

  return res;
}

export function healthCheckTest() {
  const res = http.get(`${BASE_URL}/health`);
  
  check(res, {
    'health check passes': (r) => r.status === 200,
  });

  return res;
}

// WebSocket Tests
export function websocketTest() {
  const response = ws.connect(WS_URL, {}, function (socket) {
    socket.on('open', () => {
      successfulConnections.add(1);
      console.log('WebSocket connected');
      
      // Join a channel
      socket.send(JSON.stringify({
        event: 'phx_join',
        topic: 'channel:room:test',
        payload: {},
        ref: '1'
      }));
    });

    socket.on('message', (data) => {
      messagesReceived.add(1);
      try {
        const msg = JSON.parse(data);
        check(msg, {
          'message received': (m) => m.event !== undefined,
        });
      } catch (e) {
        errorRate.add(1);
      }
    });

    socket.on('close', () => {
      console.log('WebSocket closed');
    });

    socket.on('error', (err) => {
      console.log('WebSocket error:', err);
      errorRate.add(1);
    });

    // Send periodic messages
    let counter = 0;
    const interval = setInterval(() => {
      if (counter++ < 10) {
        socket.send(JSON.stringify({
          event: 'publish',
          topic: 'channel:room:test',
          payload: {
            type: 'chat_message',
            data: { text: `Message ${counter}`, timestamp: Date.now() }
          },
          ref: counter.toString()
        }));
      } else {
        clearInterval(interval);
        socket.close();
      }
    }, 1000);
  });

  check(response, { 'status is 101': (r) => r.status === 101 });
  latencyP95.add(response.timings ? response.timings.duration : 0);
}

// gRPC Processor Test (HTTP fallback)
export function processorTest() {
  const payload = {
    events: [
      { id: `evt_${Date.now()}`, app_id: APP_ID, channel: 'room:test', type: 'price_update', data: { price: 50000 + Math.random() * 100 } }
    ]
  };

  const res = http.post(
    'http://localhost:8080/process-batch',
    JSON.stringify(payload),
    { headers: { 'Content-Type': 'application/json' } }
  );

  check(res, {
    'processor status is 200': (r) => r.status === 200,
    'processor responds quickly': (r) => r.timings.duration < 50,
  });

  return res;
}

// Main Test Scenarios
export default function () {
  // Scenario 1: Health Check (lightweight)
  healthCheckTest();
  sleep(0.1);

  // Scenario 2: HTTP Publish (core functionality)
  httpPublishTest();
  sleep(0.5);

  // Scenario 3: History Retrieval (read operations)
  httpHistoryTest();
  sleep(0.3);

  // Scenario 4: Processor batch processing
  processorTest();
  sleep(0.2);

  // Scenario 5: WebSocket connection (every 5th iteration)
  if (__VU % 5 === 0) {
    websocketTest();
  }
}

// Handle setup and teardown
export function setup() {
  console.log('Starting Polyglot load test...');
  console.log(`Target: ${BASE_URL}`);
  console.log(`WebSocket: ${WS_URL}`);
  
  // Verify system is ready
  const health = http.get(`${BASE_URL}/health`);
  if (health.status !== 200) {
    throw new Error('System health check failed!');
  }
  
  return { startTime: Date.now() };
}

export function teardown(data) {
  const duration = (Date.now() - data.startTime) / 1000;
  console.log(`\nLoad test completed in ${duration.toFixed(2)} seconds`);
  console.log(`Messages sent: ${messagesSent.values.count}`);
  console.log(`Messages received: ${messagesReceived.values.count}`);
  console.log(`Error rate: ${(errorRate.values.rate * 100).toFixed(2)}%`);
}
