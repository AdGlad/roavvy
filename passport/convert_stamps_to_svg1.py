#!/usr/bin/env python3
"""
Batch-convert passport stamp PNGs like `al-arrival.png` / `al-departure.png`
into SVG templates.

Features
- Reads transparent PNGs from an input directory
- Traces them to SVG
- Writes all SVGs to a single output directory
- Makes artwork colorable via `currentColor`
- Adds a centered date placeholder: {{DATE}}
- Keeps background transparent

Preferred tracing backend:
- potrace (best quality) if installed
Fallback backend:
- OpenCV contour tracing (works without potrace, but is rougher)

Usage:
  python3 convert_stamps_to_svg.py \
      --input /path/to/pngs \
      --output /Users/adglad/git/roavvy/svg

Optional:
  --date-font-size 42
  --date-y-ratio 0.52
  --date-placeholder "{{DATE}}"
  --force-opencv

Dependencies:
  pip install pillow opencv-python
Optional recommended dependency:
  brew install potrace
"""

from __future__ import annotations

import argparse
import math
import os
import re
import shutil
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, List, Sequence

import cv2
import numpy as np
from PIL import Image

SVG_NS = "http://www.w3.org/2000/svg"
ET.register_namespace("", SVG_NS)


@dataclass
class Config:
    input_dir: Path
    output_dir: Path
    date_placeholder: str
    date_font_size: int
    date_y_ratio: float
    alpha_threshold: int
    luminance_threshold: int
    simplify_epsilon_ratio: float
    min_area_ratio: float
    force_opencv: bool


def parse_args() -> Config:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, help="Directory containing *-arrival.png / *-departure.png")
    parser.add_argument("--output", required=True, help="Directory to write SVG templates")
    parser.add_argument("--date-placeholder", default="{{DATE}}", help="Placeholder text inserted at center")
    parser.add_argument("--date-font-size", type=int, default=42)
    parser.add_argument("--date-y-ratio", type=float, default=0.52, help="Vertical position as fraction of image height")
    parser.add_argument("--alpha-threshold", type=int, default=8, help="Pixels with alpha <= this are treated as transparent")
    parser.add_argument("--luminance-threshold", type=int, default=245, help="Darker than this is treated as ink")
    parser.add_argument("--simplify-epsilon-ratio", type=float, default=0.0018, help="Contour simplification factor")
    parser.add_argument("--min-area-ratio", type=float, default=0.000015, help="Ignore blobs smaller than this fraction of image area")
    parser.add_argument("--force-opencv", action="store_true", help="Do not use potrace even if available")
    ns = parser.parse_args()
    return Config(
        input_dir=Path(ns.input).expanduser().resolve(),
        output_dir=Path(ns.output).expanduser().resolve(),
        date_placeholder=ns.date_placeholder,
        date_font_size=ns.date_font_size,
        date_y_ratio=ns.date_y_ratio,
        alpha_threshold=ns.alpha_threshold,
        luminance_threshold=ns.luminance_threshold,
        simplify_epsilon_ratio=ns.simplify_epsilon_ratio,
        min_area_ratio=ns.min_area_ratio,
        force_opencv=ns.force_opencv,
    )


def discover_pngs(input_dir: Path) -> List[Path]:
    files = []
    pattern = re.compile(r"^[a-z]{2}-(arrival|departure)\.png$", re.IGNORECASE)
    for p in sorted(input_dir.iterdir()):
        if p.is_file() and pattern.match(p.name):
            files.append(p)
    return files


def build_binary_mask(png_path: Path, cfg: Config) -> tuple[np.ndarray, int, int]:
    """Return binary mask with stamp ink as 255, background as 0."""
    img = Image.open(png_path).convert("RGBA")
    arr = np.array(img)
    rgb = arr[:, :, :3].astype(np.float32)
    alpha = arr[:, :, 3]

    # Perceptual luminance.
    lum = 0.2126 * rgb[:, :, 0] + 0.7152 * rgb[:, :, 1] + 0.0722 * rgb[:, :, 2]

    ink = (alpha > cfg.alpha_threshold) & (lum < cfg.luminance_threshold)
    mask = np.where(ink, 255, 0).astype(np.uint8)

    # Mild cleanup to reduce pepper noise without destroying distressed edges.
    k = np.ones((2, 2), np.uint8)
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, k, iterations=1)
    mask = cv2.medianBlur(mask, 3)

    h, w = mask.shape
    return mask, w, h


def save_pbm(mask: np.ndarray, pbm_path: Path) -> None:
    Image.fromarray(mask).convert("1").save(pbm_path)


def run_potrace(mask: np.ndarray, width: int, height: int, out_svg: Path) -> bool:
    potrace_path = shutil.which("potrace")
    if not potrace_path:
        return False

    with tempfile.TemporaryDirectory() as td:
        td_path = Path(td)
        pbm_path = td_path / "trace.pbm"
        save_pbm(mask, pbm_path)
        cmd = [potrace_path, str(pbm_path), "-s", "-o", str(out_svg)]
        subprocess.run(cmd, check=True)
    return True


def contour_to_svg_path(contour: np.ndarray) -> str:
    pts = contour.reshape(-1, 2)
    if len(pts) == 0:
        return ""
    parts = [f"M {pts[0][0]} {pts[0][1]}"]
    for x, y in pts[1:]:
        parts.append(f"L {x} {y}")
    parts.append("Z")
    return " ".join(parts)


def run_opencv_trace(mask: np.ndarray, width: int, height: int, out_svg: Path, cfg: Config) -> None:
    contours, hierarchy = cv2.findContours(mask, cv2.RETR_CCOMP, cv2.CHAIN_APPROX_SIMPLE)
    if hierarchy is None:
        raise RuntimeError("No contours found")

    hierarchy = hierarchy[0]
    min_area = width * height * cfg.min_area_ratio

    svg = ET.Element(f"{{{SVG_NS}}}svg", {
        "xmlns": SVG_NS,
        "viewBox": f"0 0 {width} {height}",
        "width": str(width),
        "height": str(height),
    })
    ET.SubElement(svg, f"{{{SVG_NS}}}title").text = out_svg.stem
    group = ET.SubElement(svg, f"{{{SVG_NS}}}g", {
        "id": "stamp-art",
        "fill": "currentColor",
        "stroke": "none",
        "fill-rule": "evenodd",
    })

    for idx, contour in enumerate(contours):
        area = abs(cv2.contourArea(contour))
        if area < min_area:
            continue
        epsilon = cfg.simplify_epsilon_ratio * cv2.arcLength(contour, True)
        approx = cv2.approxPolyDP(contour, epsilon, True)
        path_d = contour_to_svg_path(approx)
        if not path_d:
            continue
        ET.SubElement(group, f"{{{SVG_NS}}}path", {"d": path_d})

    indent_xml(svg)
    ET.ElementTree(svg).write(out_svg, encoding="utf-8", xml_declaration=True)


def indent_xml(elem: ET.Element, level: int = 0) -> None:
    i = "\n" + level * "  "
    if len(elem):
        if not elem.text or not elem.text.strip():
            elem.text = i + "  "
        for child in elem:
            indent_xml(child, level + 1)
        if not child.tail or not child.tail.strip():
            child.tail = i
    if level and (not elem.tail or not elem.tail.strip()):
        elem.tail = i


def normalize_svg(svg_path: Path, width: int, height: int, cfg: Config) -> None:
    tree = ET.parse(svg_path)
    root = tree.getroot()
    root.tag = f"{{{SVG_NS}}}svg"
    root.set("viewBox", f"0 0 {width} {height}")
    root.set("width", str(width))
    root.set("height", str(height))
    root.set("fill", "none")

    # Remove any white background rectangles generated by tracing tools.
    for parent in root.iter():
        for child in list(parent):
            tag = child.tag.split("}")[-1]
            if tag == "rect" and child.get("fill", "").lower() in {"white", "#fff", "#ffffff"}:
                parent.remove(child)

    # Make all artwork colorable.
    for elem in root.iter():
        tag = elem.tag.split("}")[-1]
        if tag in {"path", "rect", "circle", "ellipse", "polygon", "polyline", "line"}:
            if elem.get("fill") not in {None, "none"}:
                elem.set("fill", "currentColor")
            if elem.get("stroke") not in {None, "none"}:
                elem.set("stroke", "currentColor")
        if tag == "g":
            if elem.get("fill") not in {None, "none"}:
                elem.set("fill", "currentColor")
            if elem.get("stroke") not in {None, "none"}:
                elem.set("stroke", "currentColor")

    # Ensure there is a main group and add template text.
    main_group = None
    for child in list(root):
        if child.tag.split("}")[-1] == "g":
            main_group = child
            break
    if main_group is None:
        main_group = ET.SubElement(root, f"{{{SVG_NS}}}g", {"id": "stamp-art", "fill": "currentColor"})

    # Remove any earlier generated date-text to make script idempotent.
    for parent in root.iter():
        for child in list(parent):
            if child.tag.split("}")[-1] == "text" and child.get("id") == "date-text":
                parent.remove(child)

    text = ET.SubElement(root, f"{{{SVG_NS}}}text", {
        "id": "date-text",
        "x": str(width / 2),
        "y": str(height * cfg.date_y_ratio),
        "text-anchor": "middle",
        "dominant-baseline": "middle",
        "fill": "currentColor",
        "font-family": "Arial, Helvetica, sans-serif",
        "font-size": str(cfg.date_font_size),
        "font-weight": "700",
        "letter-spacing": "1",
    })
    text.text = cfg.date_placeholder

    indent_xml(root)
    tree.write(svg_path, encoding="utf-8", xml_declaration=True)


def process_file(png_path: Path, cfg: Config) -> Path:
    mask, width, height = build_binary_mask(png_path, cfg)
    out_svg = cfg.output_dir / (png_path.stem + ".svg")

    traced_with_potrace = False
    if not cfg.force_opencv:
        try:
            traced_with_potrace = run_potrace(mask, width, height, out_svg)
        except Exception as exc:
            print(f"[warn] potrace failed for {png_path.name}: {exc}. Falling back to OpenCV.")
            traced_with_potrace = False

    if not traced_with_potrace:
        run_opencv_trace(mask, width, height, out_svg, cfg)

    normalize_svg(out_svg, width, height, cfg)
    return out_svg


def main() -> int:
    cfg = parse_args()

    if not cfg.input_dir.exists() or not cfg.input_dir.is_dir():
        print(f"Input directory does not exist: {cfg.input_dir}", file=sys.stderr)
        return 2

    cfg.output_dir.mkdir(parents=True, exist_ok=True)
    pngs = discover_pngs(cfg.input_dir)
    if not pngs:
        print("No matching PNG files found. Expected names like al-arrival.png", file=sys.stderr)
        return 3

    print(f"Found {len(pngs)} PNG files")
    print(f"Output directory: {cfg.output_dir}")
    print(f"Tracing backend: {'OpenCV only' if cfg.force_opencv else 'potrace if available, otherwise OpenCV'}")

    failures = []
    for png in pngs:
        try:
            out_svg = process_file(png, cfg)
            print(f"[ok] {png.name} -> {out_svg.name}")
        except Exception as exc:
            failures.append((png.name, str(exc)))
            print(f"[fail] {png.name}: {exc}", file=sys.stderr)

    if failures:
        print("\nSome files failed:", file=sys.stderr)
        for name, err in failures:
            print(f"  - {name}: {err}", file=sys.stderr)
        return 1

    print("\nDone.")
    print("Each SVG uses currentColor and includes a centered {{DATE}} placeholder.")
    print("Example render usage in HTML/CSS: set `color: #b22222;` on the <svg> or container.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
