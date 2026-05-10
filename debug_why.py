import json, os, struct

META_DIR = "apps/mobile_flutter/assets/mobile_meta"
PNG_DIR = "apps/mobile_flutter/assets/mobile_png"

def read_png_dimensions(path: str):
    with open(path, "rb") as f:
        sig = f.read(8)
        if sig != b"\x89PNG\r\n\x1a\n":
            return None, None
        f.read(4)
        chunk_type = f.read(4)
        if chunk_type != b"IHDR":
            return None, None
        width = struct.unpack(">I", f.read(4))[0]
        height = struct.unpack(">I", f.read(4))[0]
    return width, height

filename = "japan-jp-entry.json"
stem = filename[:-5]
json_path = os.path.join(META_DIR, filename)
png_path = os.path.join(PNG_DIR, stem + ".png")

print(f"Checking {filename}")
actual_w, actual_h = read_png_dimensions(png_path)
print(f"actual: {actual_w}, {actual_h}")

with open(json_path) as f:
    meta = json.load(f)

meta_w = meta.get("image", {}).get("width")
meta_h = meta.get("image", {}).get("height")
print(f"meta: {meta_w}, {meta_h}")

if meta_w != actual_w or meta_h != actual_h:
    print("Would update!")
else:
    print("No update needed")

