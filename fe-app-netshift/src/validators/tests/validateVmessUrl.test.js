import { describe, it, expect } from 'vitest';
import { validateVmessUrl } from '../validateVmessUrl';

// Node global (vitest runs in the node environment); aliased so ESLint's
// no-undef does not flag the bare `Buffer` identifier.
const NodeBuffer = globalThis.Buffer;

// Build a vmess:// link from a config object the V2RayN way:
// vmess:// + base64(JSON).
const b64 = (obj) => NodeBuffer.from(JSON.stringify(obj)).toString('base64');
const vmess = (obj) => `vmess://${b64(obj)}`;

const baseConfig = {
  v: '2',
  ps: 'node',
  add: '1.2.3.4',
  port: 443,
  id: 'b831381d-6324-4d53-ad4f-8cda48b30811',
  net: 'ws',
  type: 'none',
  host: '',
  path: '/',
  tls: 'tls',
  aid: 0,
};

// A config whose JSON base64 contains a '+' char (ps:'>>>' forces it).
// Regression parity with the backend S1 fix.
const plusB64 = b64({ ...baseConfig, ps: '>>>' });

// An unpadded base64 variant of a valid config (strip trailing '=' padding).
const unpaddedBody = b64(baseConfig).replace(/=+$/, '');

const validUrls = [
  ['basic add/port/id', vmess({ add: '1.2.3.4', port: 443, id: 'uuid-1' })],
  ['full config with net:ws tls:tls', vmess(baseConfig)],
  ['port as numeric string', vmess({ ...baseConfig, port: '8443' })],
  ['base64 body containing "+"', `vmess://${plusB64}`],
  ['unpadded base64 body', `vmess://${unpaddedBody}`],
];

const invalidUrls = [
  ['wrong prefix', `vless://${b64(baseConfig)}`],
  ['contains space', `vmess://${b64(baseConfig)} `],
  ['non-base64 body', 'vmess://!!!not base64!!!'],
  [
    'base64 of non-JSON',
    `vmess://${NodeBuffer.from('not json at all').toString('base64')}`,
  ],
  [
    'base64 of JSON array',
    `vmess://${NodeBuffer.from('[1,2,3]').toString('base64')}`,
  ],
  ['missing add', vmess({ port: 443, id: 'uuid-1' })],
  ['empty add', vmess({ add: '', port: 443, id: 'uuid-1' })],
  ['missing id', vmess({ add: '1.2.3.4', port: 443 })],
  ['empty id', vmess({ add: '1.2.3.4', port: 443, id: '' })],
  ['port 0', vmess({ add: '1.2.3.4', port: 0, id: 'uuid-1' })],
  ['port 99999', vmess({ add: '1.2.3.4', port: 99999, id: 'uuid-1' })],
  ['non-numeric port', vmess({ add: '1.2.3.4', port: 'abc', id: 'uuid-1' })],
];

describe('validateVmessUrl', () => {
  describe.each(validUrls)('Valid URL: %s', (_desc, url) => {
    it(`returns valid=true for "${url}"`, () => {
      const res = validateVmessUrl(url);
      expect(res.valid).toBe(true);
      expect(res.message).toBe('Valid');
    });
  });

  describe.each(invalidUrls)('Invalid URL: %s', (_desc, url) => {
    it(`returns valid=false for "${url}"`, () => {
      const res = validateVmessUrl(url);
      expect(res.valid).toBe(false);
    });
  });

  it('reports the wrong-prefix message', () => {
    const res = validateVmessUrl('http://example.com');
    expect(res.valid).toBe(false);
    expect(res.message).toBe('Invalid VMess URL: must start with vmess://');
  });

  it('reports malformed base64', () => {
    const res = validateVmessUrl('vmess://@@@@');
    expect(res.valid).toBe(false);
    expect(res.message).toBe('Invalid VMess URL: malformed base64');
  });

  it('reports malformed JSON', () => {
    const res = validateVmessUrl(
      `vmess://${NodeBuffer.from('definitely not json').toString('base64')}`,
    );
    expect(res.valid).toBe(false);
    expect(res.message).toBe('Invalid VMess URL: malformed JSON');
  });

  it('reports missing address', () => {
    const res = validateVmessUrl(vmess({ port: 443, id: 'uuid-1' }));
    expect(res.valid).toBe(false);
    expect(res.message).toBe('Invalid VMess URL: missing address');
  });

  it('reports missing id', () => {
    const res = validateVmessUrl(vmess({ add: '1.2.3.4', port: 443 }));
    expect(res.valid).toBe(false);
    expect(res.message).toBe('Invalid VMess URL: missing id');
  });

  it('reports invalid port', () => {
    const res = validateVmessUrl(
      vmess({ add: '1.2.3.4', port: 99999, id: 'uuid-1' }),
    );
    expect(res.valid).toBe(false);
    expect(res.message).toBe('Invalid VMess URL: invalid port');
  });

  it('confirms the "+"-containing base64 fixture really contains "+"', () => {
    expect(plusB64).toContain('+');
  });
});
