"use strict";
/**
 * Jest mock for @resvg/resvg-js.
 *
 * The real package ships linux/amd64 native binaries (enforced by .npmrc).
 * They cannot run on macOS/arm64 dev machines. This mock returns a minimal
 * PNG buffer so unit tests can exercise imageGen.ts logic without the native
 * renderer.
 *
 * The mock PNG is a 1×1 white pixel — valid PNG header + IDAT chunk.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.Resvg = void 0;
// Minimal 1×1 white PNG (67 bytes)
const PNG_1X1 = Buffer.from('89504e470d0a1a0a0000000d49484452000000010000000108020000009001' +
    '2e000000184944415478016360f8cfc000000000200001d702d000000000049454e44ae426082', 'hex');
class Resvg {
    constructor(_svg, _opts) { }
    render() {
        return {
            asPng: () => PNG_1X1,
        };
    }
}
exports.Resvg = Resvg;
//# sourceMappingURL=resvgjs.js.map