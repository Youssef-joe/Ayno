import { Socket } from './polyglot';

// Mock WebSocket
const mockWebSocket = {
  on: jest.fn(),
  send: jest.fn(),
  close: jest.fn(),
  readyState: 1
};

jest.mock('ws', () => {
  return jest.fn().mockImplementation(() => mockWebSocket);
});

describe('Socket', () => {
  let socket: Socket;

  beforeEach(() => {
    socket = new Socket('ws://localhost:4000', {
      appId: 'test-app',
      token: 'test-token'
    });
  });

  test('creates socket with options', () => {
    expect(socket).toBeDefined();
  });

  test('creates channel', () => {
    const channel = socket.channel('test:topic');
    expect(channel).toBeDefined();
  });
});
