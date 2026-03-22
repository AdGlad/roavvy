import * as fs from 'fs';
import * as path from 'path';
import { Resvg } from '@resvg/resvg-js';
import sharp from 'sharp';

/**
 * Input parameters for generateFlagGrid.
 * ADR-065: flag_grid_v1 template — rectangular grid of 4:3 flags, white or
 * transparent background, minimum cell width 100px.
 */
export interface FlagGridInput {
  templateId: 'flag_grid_v1';
  /** ISO 3166-1 alpha-2 country codes (upper or lower case) */
  selectedCountryCodes: string[];
  /** Output canvas width in pixels */
  widthPx: number;
  /** Output canvas height in pixels */
  heightPx: number;
  dpi: number;
  backgroundColor: 'white' | 'transparent';
}

/**
 * Resolves the flag-icons SVG directory at call time (lazy) so the module can
 * be imported in Jest without flag-icons being installed (tests mock fs calls).
 */
function getFlagIconsDir(): string {
  return path.join(
    path.dirname(require.resolve('flag-icons/package.json')),
    'flags',
    '4x3'
  );
}

const MIN_CELL_WIDTH = 100; // px — below this flags become unreadable
const FLAG_ASPECT = 4 / 3; // width / height for 4:3 flags

/**
 * Generates a flag grid PNG buffer from the given country codes.
 *
 * Layout:
 * - Compute column count so that all flags fit at an even size.
 * - Cell height = cell width * (3/4) to preserve 4:3 aspect ratio.
 * - If the minimum cell size cannot fit all flags in the canvas, render as
 *   many as fit and append an overflow text strip listing remaining names.
 * - Unknown or missing flag SVGs are silently skipped.
 *
 * Returns a PNG buffer at exactly widthPx × heightPx.
 */
export async function generateFlagGrid(input: FlagGridInput): Promise<Buffer> {
  const { selectedCountryCodes, widthPx, heightPx, backgroundColor } = input;
  const FLAG_ICONS_DIR = getFlagIconsDir();

  // ── 1. Resolve valid flag codes (filter unknown SVGs) ──────────────────────
  const validCodes: string[] = [];
  for (const code of selectedCountryCodes) {
    const lower = code.toLowerCase();
    if (fs.existsSync(path.join(FLAG_ICONS_DIR, `${lower}.svg`))) {
      validCodes.push(lower);
    }
    // Unknown codes are silently skipped (ADR-065)
  }

  // ── 2. Compute layout ──────────────────────────────────────────────────────
  const n = validCodes.length;

  // Number of columns: choose so cell width is maximised within the canvas.
  // columns = ceil(sqrt(n * (4/3))) biases toward landscape grids.
  let columns = n === 0 ? 1 : Math.max(1, Math.ceil(Math.sqrt(n * FLAG_ASPECT)));
  let cellWidth = Math.floor(widthPx / columns);
  let cellHeight = Math.floor(cellWidth / FLAG_ASPECT);

  // Enforce minimum cell width: reduce flag count if necessary
  let renderCount = n;
  let overflowCodes: string[] = [];

  if (cellWidth < MIN_CELL_WIDTH && n > 0) {
    // How many flags fit at minimum size?
    columns = Math.floor(widthPx / MIN_CELL_WIDTH);
    cellWidth = Math.floor(widthPx / columns);
    cellHeight = Math.floor(cellWidth / FLAG_ASPECT);
    const rows = Math.floor(heightPx / cellHeight);
    const maxFlags = columns * rows;
    renderCount = Math.min(n, maxFlags);
    overflowCodes = validCodes.slice(renderCount);
  }

  const codesToRender = validCodes.slice(0, renderCount);

  // ── 3. Rasterise each flag SVG → PNG buffer ────────────────────────────────
  const flagBuffers: Buffer[] = [];
  for (const code of codesToRender) {
    const svgPath = path.join(FLAG_ICONS_DIR, `${code}.svg`);
    const svg = fs.readFileSync(svgPath, 'utf8');
    const resvg = new Resvg(svg, {
      fitTo: { mode: 'width', value: cellWidth },
    });
    const png = resvg.render().asPng();
    flagBuffers.push(Buffer.from(png));
  }

  // ── 4. Composite all flags onto the canvas ─────────────────────────────────
  const bgColour =
    backgroundColor === 'white'
      ? { r: 255, g: 255, b: 255, alpha: 1 }
      : { r: 0, g: 0, b: 0, alpha: 0 };

  const compositeInputs = flagBuffers.map((buf, i) => {
    const col = i % columns;
    const row = Math.floor(i / columns);
    return {
      input: buf,
      left: col * cellWidth,
      top: row * cellHeight,
    };
  });

  let canvas = sharp({
    create: {
      width: widthPx,
      height: heightPx,
      channels: 4,
      background: bgColour,
    },
  });

  if (compositeInputs.length > 0) {
    canvas = canvas.composite(compositeInputs);
  }

  // ── 5. Append overflow text strip ──────────────────────────────────────────
  if (overflowCodes.length > 0) {
    // Render a simple text strip listing overflow country codes in small text.
    // sharp's text overlay is used via an SVG <text> element.
    const stripHeight = Math.min(48, Math.floor(heightPx * 0.05));
    const overflowText = `+${overflowCodes.length} more: ${overflowCodes
      .map((c) => c.toUpperCase())
      .join(', ')}`;
    const textSvg = `<svg xmlns="http://www.w3.org/2000/svg" width="${widthPx}" height="${stripHeight}">
      <rect width="${widthPx}" height="${stripHeight}" fill="rgba(0,0,0,0.5)"/>
      <text x="8" y="${stripHeight - 10}" font-size="14" fill="white" font-family="sans-serif"
        dominant-baseline="auto">${overflowText}</text>
    </svg>`;

    const stripBuf = Buffer.from(textSvg, 'utf8');
    const gridRows = Math.ceil(renderCount / columns);
    const stripTop = Math.min(gridRows * cellHeight, heightPx - stripHeight);

    canvas = canvas.composite([{ input: stripBuf, left: 0, top: stripTop }]);
  }

  return canvas.toFormat('png').toBuffer();
}
