#!/usr/bin/env node

/**
 * Polyglot Test Client - CLI
 * Tests WebSocket and HTTP APIs
 * 
 * Usage:
 *   node test-client.js ws-connect
 *   node test-client.js http-publish
 *   node test-client.js stress
 */

const http = require('http');
const https = require('https');
const WebSocket = require('ws');
const url = require('url');

const CONFIG = {
    baseUrl: process.env.POLYGLOT_URL || 'http://localhost:4000',
    wsUrl: process.env.POLYGLOT_WS || 'ws://localhost:4000/socket',
    appId: process.env.APP_ID || 'test-app',
    channel: process.env.CHANNEL || 'room:test',
    apiKey: process.env.API_KEY || 'valid_key_test-app',
    token: process.env.TOKEN || 'valid_token_user123'
};

// Utilities
function log(msg, type = 'info') {
    const timestamp = new Date().toLocaleTimeString();
    const colors = {
        info: '\x1b[36m',
        success: '\x1b[32m',
        error: '\x1b[31m',
        warn: '\x1b[33m',
        reset: '\x1b[0m'
    };
    console.log(`${colors[type]}[${timestamp}] ${msg}${colors.reset}`);
}

function request(method, path, body = null, headers = {}) {
    return new Promise((resolve, reject) => {
        const baseUrl = new url.URL(CONFIG.baseUrl);
        const options = {
            hostname: baseUrl.hostname,
            port: baseUrl.port,
            path,
            method,
            headers: {
                'Content-Type': 'application/json',
                ...headers
            }
        };

        const client = baseUrl.protocol === 'https:' ? https : http;
        const req = client.request(options, (res) => {
            let data = '';
            res.on('data', chunk => data += chunk);
            res.on('end', () => {
                try {
                    resolve({ status: res.statusCode, data: JSON.parse(data) });
                } catch {
                    resolve({ status: res.statusCode, data });
                }
            });
        });

        req.on('error', reject);
        if (body) req.write(JSON.stringify(body));
        req.end();
    });
}

// Commands
async function health() {
    log('Checking /health endpoint...', 'info');
    try {
        const res = await request('GET', '/health');
        log(`Health: ${res.status}`, res.status === 200 ? 'success' : 'error');
        console.log(JSON.stringify(res.data, null, 2));
    } catch (e) {
        log(`Error: ${e.message}`, 'error');
    }
}

async function ready() {
    log('Checking /ready endpoint...', 'info');
    try {
        const res = await request('GET', '/ready');
        log(`Ready: ${res.status}`, res.status === 200 ? 'success' : 'error');
        console.log(JSON.stringify(res.data, null, 2));
    } catch (e) {
        log(`Error: ${e.message}`, 'error');
    }
}

async function publish(message = null) {
    const payload = message || {
        type: 'message',
        data: {
            text: `Test message from CLI at ${new Date().toISOString()}`,
            timestamp: Date.now()
        }
    };

    log(`Publishing to /apps/${CONFIG.appId}/channels/${CONFIG.channel}/publish`, 'info');
    try {
        const res = await request(
            'POST',
            `/apps/${CONFIG.appId}/channels/${CONFIG.channel}/publish`,
            payload,
            { 'X-API-Key': CONFIG.apiKey }
        );
        log(`Published: ${res.status}`, res.status === 200 ? 'success' : 'error');
        console.log(JSON.stringify(res.data, null, 2));
    } catch (e) {
        log(`Error: ${e.message}`, 'error');
    }
}

async function history() {
    log(`Fetching history from /apps/${CONFIG.appId}/channels/${CONFIG.channel}/history`, 'info');
    try {
        const res = await request('GET', `/apps/${CONFIG.appId}/channels/${CONFIG.channel}/history`);
        log(`History: ${res.status}`, res.status === 200 ? 'success' : 'error');
        console.log(JSON.stringify(res.data, null, 2));
    } catch (e) {
        log(`Error: ${e.message}`, 'error');
    }
}

async function wsTest() {
    log(`Connecting to WebSocket: ${CONFIG.wsUrl}`, 'info');
    return new Promise((resolve) => {
        const wsUrl = `${CONFIG.wsUrl}?app_id=${CONFIG.appId}&token=${CONFIG.token}`;
        const ws = new WebSocket(wsUrl);

        ws.on('open', () => {
            log('WebSocket connected!', 'success');
            log('Sending test message...', 'info');
            ws.send(JSON.stringify({
                type: 'message',
                data: { text: 'Hello from WebSocket' }
            }));
        });

        ws.on('message', (data) => {
            log(`Received: ${data}`, 'success');
        });

        ws.on('error', (e) => {
            log(`WebSocket error: ${e.message}`, 'error');
        });

        ws.on('close', () => {
            log('WebSocket closed', 'warn');
            resolve();
        });

        setTimeout(() => {
            ws.close();
        }, 3000);
    });
}

async function stress(requests = 100, concurrent = 10) {
    log(`Stress test: ${requests} requests, ${concurrent} concurrent`, 'info');
    const startTime = Date.now();
    let success = 0;
    let failed = 0;

    const chunks = [];
    for (let i = 0; i < requests; i += concurrent) {
        const batch = Math.min(concurrent, requests - i);
        const promises = [];

        for (let j = 0; j < batch; j++) {
            promises.push(
                publish({
                    type: 'stress-test',
                    data: {
                        id: i + j,
                        timestamp: Date.now()
                    }
                }).then(
                    () => { success++; },
                    () => { failed++; }
                )
            );
        }

        await Promise.all(promises);
        const progress = Math.min(i + concurrent, requests);
        process.stdout.write(`\rProgress: ${progress}/${requests}`);
    }

    const duration = Date.now() - startTime;
    const rps = Math.round((success / duration) * 1000);

    console.log('\n');
    log(`Completed: ${success} success, ${failed} failed`, success === requests ? 'success' : 'warn');
    log(`Duration: ${duration}ms`, 'info');
    log(`Throughput: ${rps} req/s`, 'info');
}

// Main
async function main() {
    const command = process.argv[2] || 'help';

    console.log('\n🎯 Polyglot Test Client\n');
    console.log(`Config:
  Base URL: ${CONFIG.baseUrl}
  WebSocket: ${CONFIG.wsUrl}
  App ID: ${CONFIG.appId}
  Channel: ${CONFIG.channel}\n`);

    try {
        switch (command) {
            case 'health':
                await health();
                break;
            case 'ready':
                await ready();
                break;
            case 'publish':
                await publish();
                break;
            case 'history':
                await history();
                break;
            case 'ws':
                await wsTest();
                break;
            case 'stress':
                const reqs = parseInt(process.argv[3]) || 100;
                const conc = parseInt(process.argv[4]) || 10;
                await stress(reqs, conc);
                break;
            case 'full':
                await health();
                console.log('\n');
                await publish();
                console.log('\n');
                await history();
                break;
            default:
                console.log(`Commands:
  health        - Check /health endpoint
  ready         - Check /ready endpoint  
  publish       - Publish single event
  history       - Get channel history
  ws            - Test WebSocket connection
  stress [n] [c] - Stress test (n requests, c concurrent)
  full          - Run all tests

Environment variables:
  POLYGLOT_URL  - Base URL (default: http://localhost:4000)
  POLYGLOT_WS   - WebSocket URL (default: ws://localhost:4000/socket)
  APP_ID        - App ID (default: test-app)
  CHANNEL       - Channel (default: room:test)
  API_KEY       - API key (default: valid_key_test-app)
  TOKEN         - Token (default: valid_token_user123)
`);
        }
    } catch (e) {
        log(`Fatal error: ${e.message}`, 'error');
        process.exit(1);
    }
}

main();
