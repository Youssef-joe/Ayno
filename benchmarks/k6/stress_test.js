// Stress Test - Push system to breaking point
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Counter } from 'k6/metrics';

const errorRate = new Rate('errors');
const requestsCompleted = new Counter('requests_completed');

export const options = {
  stages: [
    { duration: '1m', target: 1000 },   // Ramp to 1000 users
    { duration: '2m', target: 1000 },   // Hold peak
    { duration: '1m', target: 2000 },   // Push beyond limits
    { duration: '30s', target: 0 },     // Recovery
  ],
  thresholds: {
    'http_req_failed': ['rate<0.05'],   // Allow 5% errors under stress
    'errors': ['rate<0.1'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:4000';
const API_KEY = __ENV.API_KEY || 'valid_key_demo-app';
const APP_ID = __ENV.APP_ID || 'demo-app';

export default function () {
  const payload = JSON.stringify({
    type: 'stress_test',
    data: { load: Date.now() }
  });

  const res = http.post(
    `${BASE_URL}/apps/${APP_ID}/channels/stress:load/publish`,
    payload,
    { headers: { 'Content-Type': 'application/json', 'X-API-Key': API_KEY } }
  );

  const success = check(res, { 'status is 2xx': (r) => r.status >= 200 && r.status < 300 });
  errorRate.add(!success);
  
  if (success) {
    requestsCompleted.add(1);
  }

  sleep(0.1);
}
