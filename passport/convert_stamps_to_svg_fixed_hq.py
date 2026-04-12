#!/usr/bin/env python3
"""
Batch convert passport stamp PNG files to SVG templates using a fixed high-quality trace profile.

Expected input filenames:
  xx-arrival.png
  xx-departure.png

Example:
  al-arrival.png
  al-departure.png

Outputs:
  /Users/adglad/git/roavvy/svg/xx-arrival.svg
  /Users/adglad/git/roavvy/svg/xx-departure.svg

Features:
- Transparent SVG background
- Uses ImageMagick + Potrace for consistent high-quality tracing
- Rewrites traced artwork to use currentColor so the stamp colour can be chosen later
- Injects a centered {{DATE}} placeholder for DD-MM-YY values
"""

from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from xml.etree import ElementTree as ET

SVG_NS = "http://www.w3.org/2000/svg"
ET.register_namespace("", SVG_NS)

FILENAME_RE = re.compile(r"^[a-z]{2}-(arrival|departure)\.png$", re.IGNORECASE)


def check_dependencies() -> None:
    missing = []
    for cmd in ("magick", "potrace"):
        if shutil.which(cmd) is None:
            missing.append(cmd)
    if missing:
        joined = ", ".join(missing)
        raise SystemExit(
            f"Missing required command(s): {joined}\n"
            "Install with:\n"
            "  brew install imagemagick potrace"
        )


def run(cmd: list[str]) -> None:
    try:
        subprocess.run(cmd, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    except subprocess.CalledProcessError as e:
        sys.stderr.write(f"\nCommand failed:\n  {' '.join(cmd)}\n")
        if e.stdout:
            sys.stderr.write(f"\nSTDOUT:\n{e.stdout}\n")
        if e.stderr:
            sys.stderr.write(f"\nSTDERR:\n{e.stderr}\n")
        raise


def preprocess_png_to_pbm(input_png: Path, output_pbm: Path) -> None:
    """
    Fixed high-quality preprocessing profile:
    - flatten transparency to white
    - upscale 2x
    - grayscale
    - light blur
    - threshold 58%
    """
    run([
        "magick",
        str(input_png),
        "-background", "white",
        "-alpha", "remove",
        "-alpha", "off",
        "-resize", "200%",
        "-colorspace", "gray",
        "-blur", "0x0.6",
        "-threshold", "58%",
        str(output_pbm),
    ])


def trace_pbm_to_svg(input_pbm: Path, output_svg: Path) -> None:
    run([
        "potrace",
        str(input_pbm),
        "-s",
        "--turdsize", "2",
        "--alphamax", "0.85",
        "--opttolerance", "0.2",
        "-o", str(output_svg),
    ])


def get_viewbox_dimensions(root: ET.Element) -> tuple[float, float]:
    vb = root.get("viewBox")
    if vb:
        parts = vb.replace(",", " ").split()
        if len(parts) == 4:
            return float(parts[2]), float(parts[3])

    width = root.get("width", "1000")
    height = root.get("height", "1000")

    def parse_dim(value: str, default: float) -> float:
        m = re.match(r"^\s*([0-9.]+)", value or "")
        return float(m.group(1)) if m else default

    return parse_dim(width, 1000.0), parse_dim(height, 1000.0)


def restyle_svg_as_template(svg_path: Path, font_family: str = "Arial") -> None:
    tree = ET.parse(svg_path)
    root = tree.getroot()

    width, height = get_viewbox_dimensions(root)

    if root.get("viewBox") is None:
        root.set("viewBox", f"0 0 {width:g} {height:g}")

    # Make sure output remains transparent.
    root.attrib.pop("style", None)

    # Rewrite all traced elements to currentColor.
    for elem in root.iter():
        tag = elem.tag.split("}")[-1]

        if tag in {"path", "rect", "circle", "ellipse", "polygon", "polyline", "line"}:
            fill = elem.get("fill")
            stroke = elem.get("stroke")

            # Potrace SVGs are usually filled black paths.
            if fill not in (None, "none"):
                elem.set("fill", "currentColor")
            elif stroke not in (None, "none"):
                elem.set("stroke", "currentColor")

            if fill is None and stroke is None:
                elem.set("fill", "currentColor")

        elif tag == "g":
            if elem.get("fill") not in (None, "none"):
                elem.set("fill", "currentColor")
            if elem.get("stroke") not in (None, "none"):
                elem.set("stroke", "currentColor")

    # Add centered date placeholder.
    date_text = ET.Element(f"{{{SVG_NS}}}text")
    date_text.set("id", "date-text")
    date_text.set("x", f"{width / 2:.2f}")
    date_text.set("y", f"{height / 2:.2f}")
    date_text.set("text-anchor", "middle")
    date_text.set("dominant-baseline", "middle")
    date_text.set("fill", "currentColor")
    date_text.set("font-family", font_family)
    date_text.set("font-size", f"{max(width, height) * 0.08:.2f}")
    date_text.text = "{{DATE}}"
    root.append(date_text)

    tree.write(svg_path, encoding="utf-8", xml_declaration=True)


def process_file(input_png: Path, output_dir: Path, force: bool = False) -> Path:
    if not FILENAME_RE.match(input_png.name):
        raise ValueError(
            f"Skipping unsupported filename: {input_png.name} "
            "(expected xx-arrival.png or xx-departure.png)"
        )

    output_svg = output_dir / f"{input_png.stem}.svg"
    if output_svg.exists() and not force:
        print(f"Skipping existing file: {output_svg}")
        return output_svg

    with tempfile.TemporaryDirectory(prefix="stamp_trace_") as tmpdir:
        tmp = Path(tmpdir)
        pbm_path = tmp / f"{input_png.stem}.pbm"
        svg_path = tmp / f"{input_png.stem}.svg"

        preprocess_png_to_pbm(input_png, pbm_path)
        trace_pbm_to_svg(pbm_path, svg_path)
        restyle_svg_as_template(svg_path)

        output_dir.mkdir(parents=True, exist_ok=True)
        output_svg.write_text(svg_path.read_text(encoding="utf-8"), encoding="utf-8")

    print(f"Created: {output_svg}")
    return output_svg


def find_pngs(input_dir: Path) -> list[Path]:
    files = sorted(p for p in input_dir.iterdir() if p.is_file() and p.suffix.lower() == ".png")
    return [p for p in files if FILENAME_RE.match(p.name)]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Convert passport stamp PNGs to SVG templates.")
    parser.add_argument(
        "--input",
        required=True,
        type=Path,
        help="Directory containing xx-arrival.png / xx-departure.png files",
    )
    parser.add_argument(
        "--output",
        default=Path("/Users/adglad/git/roavvy/svg"),
        type=Path,
        help="Directory to write SVG files to",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Overwrite existing output files",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    check_dependencies()

    input_dir: Path = args.input
    output_dir: Path = args.output

    if not input_dir.exists() or not input_dir.is_dir():
        raise SystemExit(f"Input directory does not exist or is not a directory: {input_dir}")

    pngs = find_pngs(input_dir)
    if not pngs:
        raise SystemExit(
            f"No matching PNGs found in {input_dir}\n"
            "Expected files like: al-arrival.png, al-departure.png"
        )

    print(f"Found {len(pngs)} matching PNG files")
    print(f"Output directory: {output_dir}")

    failures: list[tuple[Path, str]] = []
    for png in pngs:
        try:
            process_file(png, output_dir, force=args.force)
        except Exception as e:
            failures.append((png, str(e)))
            print(f"Failed: {png.name} -> {e}", file=sys.stderr)

    print()
    print(f"Completed. Success: {len(pngs) - len(failures)} / {len(pngs)}")

    if failures:
        print("\nFailures:")
        for png, err in failures:
            print(f"  - {png.name}: {err}")
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
