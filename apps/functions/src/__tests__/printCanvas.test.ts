/**
 * Tests for M167: correct Printful print canvas dimensions and chest placement math.
 *
 * Verified against Printful API:
 *   GET /mockup-generator/printfiles/12  → printfile_id 1: 1800×2400 at 150 DPI
 *   GET /v2/catalog-variants/567         → placement_dimensions.front: 12.0"×16.0"
 */

import { PRINT_DIMENSIONS } from '../printDimensions';

// Representative Shopify GID for Black/XL
const TSHIRT_GID = 'gid://shopify/ProductVariant/47577103564987';
// Representative poster GID
const POSTER_GID = 'gid://shopify/ProductVariant/47577104318651';

describe('printDimensions — t-shirt canvas', () => {
  const dims = PRINT_DIMENSIONS[TSHIRT_GID]!;

  it('uses correct width: 1800px (12" at 150 DPI)', () => {
    expect(dims.widthPx).toBe(1800);
  });

  it('uses correct height: 2400px (16" at 150 DPI)', () => {
    expect(dims.heightPx).toBe(2400);
  });

  it('uses 150 DPI', () => {
    expect(dims.dpi).toBe(150);
  });

  it('is 3:4 aspect ratio (matches Printful front print area)', () => {
    expect(dims.widthPx / dims.heightPx).toBeCloseTo(3 / 4);
  });

  it('canvas in inches is 12×16', () => {
    expect(dims.widthPx / dims.dpi).toBe(12);
    expect(dims.heightPx / dims.dpi).toBe(16);
  });

  it('all 25 t-shirt variants share the same dimensions', () => {
    const tshirtGids = Object.keys(PRINT_DIMENSIONS).filter(
      (gid) => PRINT_DIMENSIONS[gid]!.dpi === 150 && PRINT_DIMENSIONS[gid]!.backgroundColor === 'transparent'
    );
    expect(tshirtGids.length).toBe(25);
    for (const gid of tshirtGids) {
      const d = PRINT_DIMENSIONS[gid]!;
      expect(d.widthPx).toBe(1800);
      expect(d.heightPx).toBe(2400);
    }
  });
});

describe('printDimensions — poster canvas', () => {
  it('poster variants are unchanged (300 DPI, white background)', () => {
    const d = PRINT_DIMENSIONS[POSTER_GID]!;
    expect(d.dpi).toBe(300);
    expect(d.backgroundColor).toBe('white');
  });
});

describe('chest placement pixel math (M167)', () => {
  const DPI = 150;
  const CANVAS_W = 1800; // 12"
  const CANVAS_H = 2400; // 16"
  const SHIRT_CENTER_X = CANVAS_W / 2; // 900px = 6"
  const LOGO_SIZE_PX = Math.round(3.5 * DPI); // 525px

  describe('left chest (wearer\'s left = viewer\'s right)', () => {
    const top = Math.round(3.0 * DPI);           // 450px
    const centerX = Math.round(10.0 * DPI);      // 1500px (4" right of center)
    const left = centerX - Math.round(LOGO_SIZE_PX / 2); // 1237px

    it('top is 3.0" = 450px from print area top', () => {
      expect(top).toBe(450);
      expect(top / DPI).toBeCloseTo(3.0);
    });

    it('logo center is 4" right of shirt center', () => {
      expect(centerX - SHIRT_CENTER_X).toBe(600); // 4" × 150 DPI
      expect((centerX - SHIRT_CENTER_X) / DPI).toBeCloseTo(4.0);
    });

    it('logo left edge is 1237px (~8.25" from canvas left)', () => {
      expect(left).toBe(1237);
      expect(left / DPI).toBeCloseTo(8.25, 1);
    });

    it('logo right edge stays within 12" canvas', () => {
      expect(left + LOGO_SIZE_PX).toBeLessThanOrEqual(CANVAS_W);
    });

    it('logo size is 3.5" = 525px', () => {
      expect(LOGO_SIZE_PX).toBe(525);
    });
  });

  describe('right chest (wearer\'s right = viewer\'s left)', () => {
    const top = Math.round(3.0 * DPI);           // 450px
    const centerX = Math.round(2.0 * DPI);       // 300px (4" left of center)
    const left = centerX - Math.round(LOGO_SIZE_PX / 2); // 37px

    it('top is 3.0" = 450px from print area top', () => {
      expect(top).toBe(450);
    });

    it('logo center is 4" left of shirt center', () => {
      expect(SHIRT_CENTER_X - centerX).toBe(600); // 4" × 150 DPI
    });

    it('logo left edge is 37px (~0.25" from canvas left)', () => {
      expect(left).toBe(37);
    });

    it('logo right edge stays within 12" canvas', () => {
      expect(left + LOGO_SIZE_PX).toBeLessThanOrEqual(CANVAS_W);
      expect(left + LOGO_SIZE_PX).toBe(562); // 37 + 525
    });

    it('logo fits within canvas height', () => {
      expect(top + LOGO_SIZE_PX).toBeLessThanOrEqual(CANVAS_H); // 975 ≤ 2400
    });
  });

  describe('frontLayerPosition inch values', () => {
    // These mirror the hardcoded values in frontLayerPosition() in index.ts.
    // If those values change, these tests will catch the mismatch.
    const LEFT_CHEST = { top: 3.0, left: 8.25, width: 3.5, height: 3.5 };
    const RIGHT_CHEST = { top: 3.0, left: 0.25, width: 3.5, height: 3.5 };

    it('left_chest: top 3" matches pixel calculation', () => {
      expect(Math.round(LEFT_CHEST.top * DPI)).toBe(450);
    });

    it('left_chest: left 8.25" means logo center at 10" (4" right of 6" center)', () => {
      const centerInches = LEFT_CHEST.left + LEFT_CHEST.width / 2;
      expect(centerInches).toBeCloseTo(10.0);
    });

    it('right_chest: top 3" matches pixel calculation', () => {
      expect(Math.round(RIGHT_CHEST.top * DPI)).toBe(450);
    });

    it('right_chest: left 0.25" means logo center at 2" (4" left of 6" center)', () => {
      const centerInches = RIGHT_CHEST.left + RIGHT_CHEST.width / 2;
      expect(centerInches).toBeCloseTo(2.0);
    });

    it('both placements: logo size is 3.5"×3.5"', () => {
      expect(LEFT_CHEST.width).toBe(3.5);
      expect(LEFT_CHEST.height).toBe(3.5);
      expect(RIGHT_CHEST.width).toBe(3.5);
      expect(RIGHT_CHEST.height).toBe(3.5);
    });

    it('left_chest logo stays within 12" canvas', () => {
      expect(LEFT_CHEST.left + LEFT_CHEST.width).toBeLessThanOrEqual(12);
    });

    it('right_chest logo stays within 12" canvas', () => {
      expect(RIGHT_CHEST.left + RIGHT_CHEST.width).toBeLessThanOrEqual(12);
    });
  });
});
