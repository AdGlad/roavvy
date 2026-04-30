import json, os, struct

def read_png_dimensions(path: str):
    with open(path, "rb") as f:
        sig = f.read(8)
        if sig != b"\x89PNG\r\n\x1a\n": return None, None
        f.read(4)
        chunk_type = f.read(4)
        if chunk_type != b"IHDR": return None, None
        return struct.unpack(">I", f.read(4))[0], struct.unpack(">I", f.read(4))[0]

filename = 'japan-jp-entry.json'
meta_path = f"apps/mobile_flutter/assets/mobile_meta/{filename}"
png_path = f"apps/mobile_flutter/assets/mobile_png/{filename[:-5]}.png"

print(f"PNG exists: {os.path.exists(png_path)}")
actual_w, actual_h = read_png_dimensions(png_path)
print(f"Actual: {actual_w}x{actual_h}")

with open(meta_path) as f:
    meta = json.load(f)
meta_w = meta.get("image", {}).get("width")
meta_h = meta.get("image", {}).get("height")
print(f"Meta: {meta_w}x{meta_h}")
if meta_w != actual_w or meta_h != actual_h:
    print("WILL UPDATE")
else:
    print("NO UPDATE")
