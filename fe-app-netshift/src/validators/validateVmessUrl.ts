import { ValidationResult } from './types';

export function validateVmessUrl(url: string): ValidationResult {
  if (!url.startsWith('vmess://')) {
    return {
      valid: false,
      message: _('Invalid VMess URL: must start with vmess://'),
    };
  }

  if (/\s/.test(url)) {
    return {
      valid: false,
      message: _('Invalid VMess URL: must not contain spaces'),
    };
  }

  const body = url.slice('vmess://'.length);

  // VMess (V2RayN) is vmess:// + base64(JSON), not a user@host URL.
  // Tolerate unpadded base64 by right-padding to a multiple of 4, matching
  // the backend fix.
  const padded = body + '='.repeat((4 - (body.length % 4)) % 4);

  let decoded: string;
  try {
    decoded = atob(padded);
  } catch (_e) {
    return {
      valid: false,
      message: _('Invalid VMess URL: malformed base64'),
    };
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(decoded);
  } catch (_e) {
    return {
      valid: false,
      message: _('Invalid VMess URL: malformed JSON'),
    };
  }

  if (typeof parsed !== 'object' || parsed === null || Array.isArray(parsed)) {
    return {
      valid: false,
      message: _('Invalid VMess URL: malformed JSON'),
    };
  }

  const config = parsed as Record<string, unknown>;

  if (typeof config.add !== 'string' || config.add.length === 0) {
    return {
      valid: false,
      message: _('Invalid VMess URL: missing address'),
    };
  }

  if (typeof config.id !== 'string' || config.id.length === 0) {
    return {
      valid: false,
      message: _('Invalid VMess URL: missing id'),
    };
  }

  const portNum = Number(config.port);

  if (!Number.isInteger(portNum) || portNum < 1 || portNum > 65535) {
    return {
      valid: false,
      message: _('Invalid VMess URL: invalid port'),
    };
  }

  return { valid: true, message: _('Valid') };
}
