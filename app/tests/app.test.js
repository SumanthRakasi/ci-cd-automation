const request = require('supertest');
const app = require('../src/app');

describe('GET /', () => {
  it('responds with 200 and a version field', async () => {
    const res = await request(app).get('/');
    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('version');
    expect(res.body).toHaveProperty('message');
  });
});

describe('GET /health', () => {
  it('responds with 200 and status ok', async () => {
    const res = await request(app).get('/health');
    expect(res.statusCode).toBe(200);
    expect(res.body).toEqual({ status: 'ok' });
  });
});

describe('GET /api/info', () => {
  it('responds with version and uptime', async () => {
    const res = await request(app).get('/api/info');
    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('version');
    expect(res.body).toHaveProperty('uptimeSeconds');
  });
});
