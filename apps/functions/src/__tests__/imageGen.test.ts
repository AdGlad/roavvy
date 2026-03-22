/**
 * Unit tests for imageGen.generateFlagGrid.
 *
 * @resvg/resvg-js and sharp are mocked via jest moduleNameMapper in package.json
 * because Cloud Run linux/amd64 binaries cannot run on macOS/arm64 dev machines.
 *
 * fs is fully mocked so tests run without flag-icons installed and without
 * hitting the filesystem.
 *
 * flag-icons/package.json is mocked as a virtual module so
 * require.resolve('flag-icons/package.json') succeeds at runtime.
 */

// ── Mocks must be declared before any imports ─────────────────────────────────

// Virtual mock for flag-icons/package.json — satisfies require.resolve()
jest.mock(
  'flag-icons/package.json',
  () => ({ name: 'flag-icons', version: '0.0.0-mock' }),
  { virtual: true }
);

// Full fs mock — non-configurable properties can't be spied on in Node 22
jest.mock('fs');

import * as fs from 'fs';
import { generateFlagGrid } from '../imageGen';

// Minimal valid 4:3 SVG flag (a coloured rectangle)
const MOCK_FLAG_SVG = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 640 480">
  <rect width="640" height="480" fill="#003087"/>
</svg>`;

const KNOWN_CODES = ['gb', 'us', 'fr', 'de', 'jp'];

beforeEach(() => {
  jest.clearAllMocks();
  // existsSync: return true only for known flag codes
  (fs.existsSync as jest.Mock).mockImplementation((filePath: unknown) => {
    const file = String(filePath);
    return KNOWN_CODES.some((c) => file.endsWith(`${c}.svg`));
  });
  // readFileSync: return a minimal SVG for any file read
  (fs.readFileSync as jest.Mock).mockReturnValue(MOCK_FLAG_SVG);
});

const BASE_INPUT = {
  templateId: 'flag_grid_v1' as const,
  widthPx: 800,
  heightPx: 600,
  dpi: 96,
  backgroundColor: 'white' as const,
};

describe('generateFlagGrid', () => {
  it('returns a Buffer for a single known country code', async () => {
    const result = await generateFlagGrid({
      ...BASE_INPUT,
      selectedCountryCodes: ['GB'],
    });
    expect(Buffer.isBuffer(result)).toBe(true);
    expect(result.length).toBeGreaterThan(0);
  });

  it('returns a Buffer for 50 country codes', async () => {
    const codes = Array.from({ length: 50 }, (_, i) =>
      ['GB', 'US', 'FR', 'DE', 'JP'][i % 5]
    );
    const result = await generateFlagGrid({
      ...BASE_INPUT,
      selectedCountryCodes: codes,
    });
    expect(Buffer.isBuffer(result)).toBe(true);
    expect(result.length).toBeGreaterThan(0);
  });

  it('silently skips unknown codes and returns a buffer', async () => {
    // ZZ and XX have no matching SVG (existsSync returns false for them)
    const result = await generateFlagGrid({
      ...BASE_INPUT,
      selectedCountryCodes: ['ZZ', 'XX', 'GB'],
    });
    expect(Buffer.isBuffer(result)).toBe(true);
    // readFileSync called only once — for GB (the only known code)
    expect(fs.readFileSync).toHaveBeenCalledTimes(1);
  });

  it('returns a buffer for an empty array', async () => {
    const result = await generateFlagGrid({
      ...BASE_INPUT,
      selectedCountryCodes: [],
    });
    expect(Buffer.isBuffer(result)).toBe(true);
    expect(fs.readFileSync).not.toHaveBeenCalled();
  });

  it('handles transparent background', async () => {
    const result = await generateFlagGrid({
      ...BASE_INPUT,
      backgroundColor: 'transparent',
      selectedCountryCodes: ['US', 'GB'],
    });
    expect(Buffer.isBuffer(result)).toBe(true);
  });

  it('handles print-resolution dimensions (A3 poster at 300 DPI)', async () => {
    const result = await generateFlagGrid({
      templateId: 'flag_grid_v1',
      selectedCountryCodes: ['GB', 'US', 'FR'],
      widthPx: 3508,
      heightPx: 4961,
      dpi: 300,
      backgroundColor: 'white',
    });
    expect(Buffer.isBuffer(result)).toBe(true);
  });
});
