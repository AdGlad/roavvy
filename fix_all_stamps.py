import json, os, struct

META_DIR = "apps/mobile_flutter/assets/mobile_meta"
PNG_DIR = "apps/mobile_flutter/assets/mobile_png"

def read_png_dimensions(path: str):
    with open(path, "rb") as f:
        sig = f.read(8)
        if sig != b"\x89PNG\r\n\x1a\n": return None, None
        f.read(4)
        chunk_type = f.read(4)
        if chunk_type != b"IHDR": return None, None
        return struct.unpack(">I", f.read(4))[0], struct.unpack(">I", f.read(4))[0]

json_files = sorted(f for f in os.listdir(META_DIR) if f.endswith(".json"))
changed = []

for filename in json_files:
    stem = filename[:-5]
    json_path = os.path.join(META_DIR, filename)
    png_path = os.path.join(PNG_DIR, stem + ".png")

    if not os.path.exists(png_path): continue

    actual_w, actual_h = read_png_dimensions(png_path)
    if actual_w is None or actual_h is None: continue

    with open(json_path) as f:
        meta = json.load(f)
    
    meta_w = meta.get("image", {}).get("width")
    meta_h = meta.get("image", {}).get("height")

    if meta_w is None or meta_h is None: continue

    if meta_w != actual_w or meta_h != actual_h:
        scale_x = actual_w / meta_w
        scale_y = actual_h / meta_h

        date = meta.get("date")
        if date:
            if "x" in date: date["x"] = round(date["x"] * scale_x, 1)
            if "y" in date: date["y"] = round(date["y"] * scale_y, 1)
            if "font_size" in date: date["font_size"] = round(date["font_size"] * scale_x, 1)
            if "letter_spacing" in date: date["letter_spacing"] = round(date["letter_spacing"] * scale_x, 1)
        
        meta["image"]["width"] = actual_w
        meta["image"]["height"] = actual_h

        with open(json_path, "w") as f:
            json.dump(meta, f, indent=2)
            f.write("\n")
        
        changed.append((filename, meta_w, meta_h, actual_w, actual_h))

print(f"Summary: Checked {len(json_files)} metadata files.")
print(f"Updated {len(changed)} files.")
for item in changed:
    print(f"- {item[0]}: {item[1]}x{item[2]} -> {item[3]}x{item[4]}")
