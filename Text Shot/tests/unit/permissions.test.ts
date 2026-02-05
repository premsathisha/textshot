import { describe, expect, it } from 'vitest';
import { shouldThrottle } from '../../src/main/permissions';

describe('shouldThrottle', () => {
  it('returns true when within window', () => {
    const recent = Date.now() - 5_000;
    expect(shouldThrottle(recent, 10_000)).toBe(true);
  });

  it('returns false when window elapsed', () => {
    const old = Date.now() - 20_000;
    expect(shouldThrottle(old, 10_000)).toBe(false);
  });
});
