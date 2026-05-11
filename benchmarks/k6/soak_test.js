// Soak Test - Long-running stability test
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

const errorRate = new Rate('errors');
const memoryLeakIndicator = new Trend('memory_leak_indicator');

export const options = {
  stages: [
    { duration: '5m', target: 50 },    // Moderate load
    { duration: '25m', target: 50 },   // Sustain for 25 minutes
    { duration: '5m', target: 0 },     // Cool down
  ],
  thresholds: {
    'http_req_duration': ['p(95)<150'],
    'http_req_failed': ['rate<0.01'],
    'errors': ['rate<0.02'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:4000';
const API_KEY = __ENV.API_KEY || 'valid_key_demo-app';
const APP_ID = __ENV.APP_ID || 'demo-app';

let iterationCount = 0;

export default function () {
  iterationCount++;
  
  // Publish message
  const publishRes = http.post(
    `${BASE_URL}/apps/${APP_ID}/channels/soak:test/publish`,
    JSON.stringify({ type: 'soak_test', data: { iteration: iterationCount } }),
    { headers: { 'Content-Type': 'application/json', 'X-API-Key': API_KEY } }
  );
  
  check(publishRes, { 'publish ok': (r) => r.status === 200 });
  errorRate.add(publishRes.status !== 200);
  
  sleep(0.5);
  
  // Retrieve history
  const historyRes = http.get(
    `${BASE_URL}/apps/${APP_ID}/channels/soak:test/history?limit=10`,
    { headers: { 'X-API-Key': API_KEY } }
  );
  
  check(historyRes, { 'history ok': (r) => r.status === 200 });
  errorRate.add(historyRes.status !== 200);
  
  // Track response time trends (memory leak detection)
  memoryLeakIndicator.add(publishRes.timings.duration);
  
  sleep(1);
}

export function teardown() {
  console.log(`Soak test completed: ${iterationCount} iterations`);
}
