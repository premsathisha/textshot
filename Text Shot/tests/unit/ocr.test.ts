import { describe, expect, it } from 'vitest';
import { cleanupOcrText } from '../../src/main/ocr';

describe('cleanupOcrText', () => {
  it('trims trailing whitespace and excessive newlines', () => {
    const raw = 'Hello   \n\n\nWorld   \n';
    expect(cleanupOcrText(raw)).toBe('Hello\n\nWorld');
  });

  it('drops obvious punctuation-only artifact lines', () => {
    const raw = 'Actual Text\n....\n|\nNext';
    expect(cleanupOcrText(raw)).toBe('Actual Text\nNext');
  });
});
