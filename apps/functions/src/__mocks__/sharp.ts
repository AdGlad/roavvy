/**
 * Jest mock for sharp.
 *
 * The real package ships linux/amd64 native binaries (enforced by .npmrc).
 * This mock chains all sharp operations and returns a minimal PNG buffer
 * from toBuffer(), preserving the chaining API that imageGen.ts uses.
 */

// Minimal 1×1 white PNG (67 bytes)
const PNG_1X1 = Buffer.from(
  '89504e470d0a1a0a0000000d49484452000000010000000108020000009001' +
    '2e000000184944415478016360f8cfc000000000200001d702d000000000049454e44ae426082',
  'hex'
);

type SharpInstance = {
  composite: (_overlays: object[]) => SharpInstance;
  toFormat: (_format: string, _opts?: object) => SharpInstance;
  toBuffer: () => Promise<Buffer>;
  metadata: () => Promise<{ width: number; height: number }>;
};

function createInstance(width = 1, height = 1): SharpInstance {
  const instance: SharpInstance = {
    composite: (_overlays) => instance,
    toFormat: (_format, _opts) => instance,
    toBuffer: async () => PNG_1X1,
    metadata: async () => ({ width, height }),
  };
  return instance;
}

function sharp(
  input?: Buffer | { create: { width: number; height: number; channels: number; background: object } }
): SharpInstance {
  if (input && 'create' in input) {
    return createInstance(input.create.width, input.create.height);
  }
  return createInstance();
}

export default sharp;
