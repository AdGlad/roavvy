#!/usr/bin/env python3
"""
High-quality batch converter for passport stamp PNG assets to SVG templates.

What it does
- Finds files named like: al-arrival.png, al-departure.png
- Uses ImageMagick + Potrace for high-fidelity bitmap tracing
- Preserves all visible details from the source image (boxes, icons, lines, distressed edges)
- Outputs transparent-background SVG files that use `currentColor`
- Injects a centered `{{DATE}}` text placeholder so callers can substitute DD-MM-YY later

Requirements
- Python 3.10+
- ImageMagick v7+ (`magick` on PATH)
- potrace (`potrace` on PATH)

Optional
- None. This script intentionally does not fall back to lower-quality tracing.

Example
python3 convert_stamps_to_svg_hq.py \
  --input /Users/adglad/path/to/pngs \
  --output /Users/adglad/git/roavvy/svg \
  --threshold 58 \
  --font-family "Arial, Helvetica, sans-serif"
"""
from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Optional
import xml.etree.ElementTree as ET

PNG_PATTERN = re.compile(r"^(?P<code>[a-z]{2})-(?P<kind>arrival|departure)\.png$", re.IGNORECASE)
SVG_NS = "http://www.w3.org/2000/svg"
ET.register_namespace("", SVG_NS)


@dataclass
class Config:
    input_dir: Path
    output_dir: Path
    threshold: int
    despeckle: int
    turdsize: int
    alphamax: float
    opttolerance: float
    center_date: bool
    font_family: str
    font_scale: float
    font_weight: str
    date_value: str
    verbose: bool
    force: bool


def check_dependency(name: str) -> None:
    if shutil.which(name) is None:
        raise SystemExit(
            f"Required dependency '{name}' was not found on PATH. "
            f"Install it first and rerun."
        )


def run(cmd: list[str], verbose: bool = False) -> None:
    if verbose:
        print("+", " ".join(cmd))
    subprocess.run(cmd, check=True)


def iter_pngs(input_dir: Path) -> Iterable[Path]:
    for p in sorted(input_dir.iterdir()):
        if p.is_file() and PNG_PATTERN.match(p.name):
            yield p


def trace_png_to_svg(png_path: Path, svg_path: Path, cfg: Config) -> None:
    with tempfile.TemporaryDirectory(prefix="stamptrace_") as td:
        tmp = Path(td)
        pbm_path = tmp / "trace.pbm"
        raw_svg_path = tmp / "trace.svg"

        # Transparent background -> white matte, stamp detail stays dark.
        # Then threshold to a clean binary image for Potrace.
        # Despeckle is repeated a small configurable number of times.
        magick_cmd = [
            "magick",
            str(png_path),
            "-background", "white",
            "-alpha", "remove",
            "-alpha", "off",
            "-colorspace", "gray",
            "-normalize",
        ]
        for _ in range(max(cfg.despeckle, 0)):
            magick_cmd += ["-despeckle"]
        magick_cmd += [
            "-threshold", f"{cfg.threshold}%",
            str(pbm_path),
        ]
        run(magick_cmd, verbose=cfg.verbose)

        potrace_cmd = [
            "potrace",
            str(pbm_path),
            "-s",                    # SVG output
            "-o", str(raw_svg_path),
            "-t", str(cfg.turdsize), # suppress tiny specks
            "-a", str(cfg.alphamax),
            "-O", str(cfg.opttolerance),
        ]
        run(potrace_cmd, verbose=cfg.verbose)

        final_svg = post_process_svg(raw_svg_path, cfg)
        svg_path.write_text(final_svg, encoding="utf-8")


def _strip_unit(value: Optional[str], default: float) -> float:
    if not value:
        return default
    match = re.match(r"^\s*([0-9]+(?:\.[0-9]+)?)", value)
    return float(match.group(1)) if match else default


def post_process_svg(svg_path: Path, cfg: Config) -> str:
    tree = ET.parse(svg_path)
    root = tree.getroot()

    # Normalise SVG attributes.
    width = _strip_unit(root.get("width"), 800.0)
    height = _strip_unit(root.get("height"), 600.0)

    if not root.get("viewBox"):
        root.set("viewBox", f"0 0 {int(round(width))} {int(round(height))}")

    # Transparent background: do not add any rect.
    # Color control: make traced content use currentColor instead of hardcoded black.
    root.set("fill", "currentColor")
    root.set("stroke", "none")

    # Update existing path fills to currentColor.
    for elem in root.iter():
        tag = elem.tag.split("}")[-1]
        if tag in {"path", "polygon", "rect", "circle", "ellipse", "line", "polyline", "g"}:
            if elem.get("fill") not in {None, "none"}:
                elem.set("fill", "currentColor")
            elif tag in {"path", "polygon", "rect", "circle", "ellipse"}:
                # Potrace paths are normally filled shapes.
                elem.set("fill", "currentColor")
            if elem.get("stroke") not in {None, "none"}:
                elem.set("stroke", "currentColor")

    if cfg.center_date:
        add_center_date(root, width, height, cfg)

    return ET.tostring(root, encoding="unicode")


def add_center_date(root: ET.Element, width: float, height: float, cfg: Config) -> None:
    # Conservative centered placement: visually central, slightly lower than exact midpoint
    # to suit many stamp layouts. Callers can later tweak generated templates if needed.
    text = ET.SubElement(root, f"{{{SVG_NS}}}text")
    text.set("id", "date-text")
    text.set("x", f"{width / 2:.2f}")
    text.set("y", f"{height * 0.52:.2f}")
    text.set("text-anchor", "middle")
    text.set("dominant-baseline", "middle")
    text.set("fill", "currentColor")
    text.set("font-family", cfg.font_family)
    text.set("font-weight", cfg.font_weight)
    text.set("font-size", f"{max(12.0, min(width, height) * cfg.font_scale):.2f}")
    text.text = "{{DATE}}" if cfg.date_value == "{{DATE}}" else cfg.date_value


def parse_args() -> Config:
    parser = argparse.ArgumentParser(description="High-quality PNG to SVG passport stamp converter")
    parser.add_argument("--input", required=True, help="Directory containing *-arrival.png / *-departure.png files")
    parser.add_argument("--output", required=True, help="Directory to write SVG files into")
    parser.add_argument("--threshold", type=int, default=58, help="Binary threshold percentage for trace prep (default: 58)")
    parser.add_argument("--despeckle", type=int, default=1, help="How many ImageMagick despeckle passes to apply (default: 1)")
    parser.add_argument("--turdsize", type=int, default=2, help="Potrace speck suppression size (default: 2)")
    parser.add_argument("--alphamax", type=float, default=1.0, help="Potrace corner threshold (default: 1.0)")
    parser.add_argument("--opttolerance", type=float, default=0.2, help="Potrace curve optimisation tolerance (default: 0.2)")
    parser.add_argument("--no-date", action="store_true", help="Do not inject a centered date text placeholder")
    parser.add_argument("--font-family", default="Arial, Helvetica, sans-serif", help="SVG font family for centered date")
    parser.add_argument("--font-scale", type=float, default=0.11, help="Date font size as fraction of min(width,height) (default: 0.11)")
    parser.add_argument("--font-weight", default="700", help="Date font weight (default: 700)")
    parser.add_argument("--date-value", default="{{DATE}}", help="Default date text to inject (default: {{DATE}})")
    parser.add_argument("--verbose", action="store_true", help="Print executed commands")
    parser.add_argument("--force", action="store_true", help="Overwrite existing output SVG files")

    ns = parser.parse_args()

    return Config(
        input_dir=Path(ns.input).expanduser().resolve(),
        output_dir=Path(ns.output).expanduser().resolve(),
        threshold=ns.threshold,
        despeckle=ns.despeckle,
        turdsize=ns.turdsize,
        alphamax=ns.alphamax,
        opttolerance=ns.opttolerance,
        center_date=not ns.no_date,
        font_family=ns.font_family,
        font_scale=ns.font_scale,
        font_weight=ns.font_weight,
        date_value=ns.date_value,
        verbose=ns.verbose,
        force=ns.force,
    )


def main() -> int:
    cfg = parse_args()

    if not cfg.input_dir.is_dir():
        raise SystemExit(f"Input directory does not exist: {cfg.input_dir}")

    cfg.output_dir.mkdir(parents=True, exist_ok=True)

    check_dependency("magick")
    check_dependency("potrace")

    files = list(iter_pngs(cfg.input_dir))
    if not files:
        raise SystemExit(
            f"No matching PNG files found in {cfg.input_dir}. "
            f"Expected names like al-arrival.png or al-departure.png."
        )

    failures = 0
    for png_path in files:
        out_name = png_path.with_suffix(".svg").name
        svg_path = cfg.output_dir / out_name
        if svg_path.exists() and not cfg.force:
            print(f"Skipping existing file: {svg_path.name}")
            continue

        print(f"Tracing {png_path.name} -> {svg_path}")
        try:
            trace_png_to_svg(png_path, svg_path, cfg)
        except subprocess.CalledProcessError as exc:
            failures += 1
            print(f"FAILED: {png_path.name}: {exc}", file=sys.stderr)
        except Exception as exc:
            failures += 1
            print(f"FAILED: {png_path.name}: {exc}", file=sys.stderr)

    if failures:
        print(f"Completed with {failures} failure(s).", file=sys.stderr)
        return 1

    print(f"Done. Wrote SVG files to: {cfg.output_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
