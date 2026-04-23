#!/usr/bin/env python3
"""
Fix stamp metadata JSON files after PNGs were cropped.

The PNG files were trimmed to remove whitespace, but the image.width/height
in the JSON files were not updated. This causes date text to be rendered at
the wrong position in the Flutter app.

Fix: for each JSON, read actual PNG dimensions, scale all coordinates
proportionally, and update image dimensions.
"""

import json
import os
import struct
import sys

META_DIR = "apps/mobile_flutter/assets/mobile_meta"
PNG_DIR = "apps/mobile_flutter/assets/mobile_png"


def read_png_dimensions(path: str) -> tuple[int, int]:
    """Read width and height from PNG IHDR chunk (bytes 16–23)."""
    with open(path, "rb") as f:
        sig = f.read(8)
        if sig != b"\x89PNG\r\n\x1a\n":
            raise ValueError(f"Not a PNG file: {path}")
        f.read(4)  # chunk length
        chunk_type = f.read(4)
        if chunk_type != b"IHDR":
            raise ValueError(f"Expected IHDR, got {chunk_type}: {path}")
        width = struct.unpack(">I", f.read(4))[0]
        height = struct.unpack(">I", f.read(4))[0]
    return width, height


def fix_meta_file(json_path: str, png_path: str, dry_run: bool = False) -> str:
    """
    Update a single JSON meta file to match actual PNG dimensions.
    Returns a status string.
    """
    with open(json_path) as f:
        meta = json.load(f)

    meta_w = meta["image"]["width"]
    meta_h = meta["image"]["height"]
    actual_w, actual_h = read_png_dimensions(png_path)

    if meta_w == actual_w and meta_h == actual_h:
        return "ok"

    scale_x = actual_w / meta_w
    scale_y = actual_h / meta_h

    date = meta["date"]
    date["x"] = round(date["x"] * scale_x, 4)
    date["y"] = round(date["y"] * scale_y, 4)
    date["font_size"] = round(date["font_size"] * scale_y, 4)
    if "letter_spacing" in date:
        date["letter_spacing"] = round(date["letter_spacing"] * scale_x, 4)

    meta["image"]["width"] = actual_w
    meta["image"]["height"] = actual_h

    if not dry_run:
        with open(json_path, "w") as f:
            json.dump(meta, f, indent=2)
            f.write("\n")

    return f"fixed ({meta_w}x{meta_h} → {actual_w}x{actual_h}, scale {scale_x:.3f}x{scale_y:.3f})"


def main():
    dry_run = "--dry-run" in sys.argv

    if dry_run:
        print("DRY RUN — no files will be written\n")

    repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    meta_dir = os.path.join(repo_root, META_DIR)
    png_dir = os.path.join(repo_root, PNG_DIR)

    json_files = sorted(
        f for f in os.listdir(meta_dir) if f.endswith(".json")
    )

    ok = fixed = skipped = 0
    for filename in json_files:
        stem = filename[:-5]  # strip .json
        json_path = os.path.join(meta_dir, filename)
        png_path = os.path.join(png_dir, stem + ".png")

        if not os.path.exists(png_path):
            print(f"  SKIP  {filename} — PNG not found at {png_path}")
            skipped += 1
            continue

        try:
            status = fix_meta_file(json_path, png_path, dry_run=dry_run)
        except Exception as e:
            print(f"  ERROR {filename} — {e}")
            skipped += 1
            continue

        if status == "ok":
            ok += 1
        else:
            print(f"  FIXED {filename} — {status}")
            fixed += 1

    print(f"\nDone: {fixed} fixed, {ok} already correct, {skipped} skipped")


if __name__ == "__main__":
    main()
