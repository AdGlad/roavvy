"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.generateFlagGrid = generateFlagGrid;
const fs = __importStar(require("fs"));
const path = __importStar(require("path"));
const resvg_js_1 = require("@resvg/resvg-js");
const sharp_1 = __importDefault(require("sharp"));
/**
 * Resolves the flag-icons SVG directory at call time (lazy) so the module can
 * be imported in Jest without flag-icons being installed (tests mock fs calls).
 */
function getFlagIconsDir() {
    return path.join(path.dirname(require.resolve('flag-icons/package.json')), 'flags', '4x3');
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
async function generateFlagGrid(input) {
    const { selectedCountryCodes, widthPx, heightPx, backgroundColor } = input;
    const FLAG_ICONS_DIR = getFlagIconsDir();
    // ── 1. Resolve valid flag codes (filter unknown SVGs) ──────────────────────
    const validCodes = [];
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
    let overflowCodes = [];
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
    const flagBuffers = [];
    for (const code of codesToRender) {
        const svgPath = path.join(FLAG_ICONS_DIR, `${code}.svg`);
        const svg = fs.readFileSync(svgPath, 'utf8');
        const resvg = new resvg_js_1.Resvg(svg, {
            fitTo: { mode: 'width', value: cellWidth },
        });
        const png = resvg.render().asPng();
        flagBuffers.push(Buffer.from(png));
    }
    // ── 4. Composite all flags onto the canvas ─────────────────────────────────
    const bgColour = backgroundColor === 'white'
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
    let canvas = (0, sharp_1.default)({
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
//# sourceMappingURL=imageGen.js.map