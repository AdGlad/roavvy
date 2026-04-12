#!/usr/bin/env python3
"""
Higher-quality batch PNG -> SVG template converter for passport stamps.

This version is intentionally slower. For each PNG it generates many trace candidates,
rasterises each candidate back to a bitmap, scores it against the source mask, and keeps
the best result.

Key properties:
- preserves fine details better than a single fixed threshold run
- transparent background in output SVG
- traced shapes use currentColor so line/stamp colour is chosen at render time
- injects a centered {{DATE}} placeholder as editable SVG text

Requirements
- Python 3.10+
- ImageMagick v7+ (magick)
- potrace
- pillow

Install:
  brew install imagemagick potrace
  python3 -m pip install pillow

Example:
  python3 convert_stamps_to_svg_search.py \
    --input /Users/adglad/path/to/pngs \
    --output /Users/adglad/git/roavvy/svg \
    --force --verbose
"""
from __future__ import annotations

import argparse
import math
import re
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Sequence
import xml.etree.ElementTree as ET

from PIL import Image, ImageChops, ImageFilter, ImageStat

PNG_PATTERN = re.compile(r"^(?P<code>[a-z]{2})-(?P<kind>arrival|departure)\.png$", re.IGNORECASE)
SVG_NS = "http://www.w3.org/2000/svg"
ET.register_namespace("", SVG_NS)


@dataclass(frozen=True)
class CandidateProfile:
    threshold: int
    blur: float
    despeckle: int
    morphology: int
    sharpen: bool
    scale: int
    turdsize: int
    alphamax: float
    opttolerance: float


@dataclass
class Config:
    input_dir: Path
    output_dir: Path
    force: bool
    verbose: bool
    date_value: str
    font_family: str
    font_weight: str
    font_scale: float
    center_y_ratio: float
    density: int
    max_candidates: int


def check_dependency(name: str) -> None:
    if shutil.which(name) is None:
        raise SystemExit(f"Required dependency '{name}' not found on PATH.")


def run(cmd: Sequence[str], verbose: bool = False) -> None:
    if verbose:
        print("+", " ".join(str(c) for c in cmd))
    subprocess.run(list(cmd), check=True)


def iter_pngs(input_dir: Path) -> Iterable[Path]:
    for p in sorted(input_dir.iterdir()):
        if p.is_file() and PNG_PATTERN.match(p.name):
            yield p


def load_target_mask(png_path: Path) -> Image.Image:
    """Return a high-quality binary mask from the source image.

    Prefer the alpha channel when it clearly carries the stamp shape, otherwise fall back
    to grayscale on white matte.
    """
    with Image.open(png_path) as im:
        im = im.convert("RGBA")
        alpha = im.getchannel("A")
        # If there is meaningful alpha variation, use it. This is usually the best source
        # for transparent-background stamps.
        extrema = alpha.getextrema()
        if extrema and extrema[1] > 0 and extrema[0] < 255:
            mask = alpha.point(lambda p: 255 if p >= 8 else 0, mode="L")
        else:
            flat = Image.new("RGBA", im.size, (255, 255, 255, 255))
            flat.alpha_composite(im)
            gray = flat.convert("L")
            mask = gray.point(lambda p: 255 if p < 245 else 0, mode="L")

    # Clean tiny anti-alias fuzz but preserve detail.
    mask = mask.filter(ImageFilter.MedianFilter(size=3))
    return mask.point(lambda p: 255 if p >= 128 else 0, mode="L")


def build_profiles(limit: int) -> list[CandidateProfile]:
    profiles: list[CandidateProfile] = []
    for scale in (2, 3):
        for threshold in (44, 48, 52, 56, 60, 64):
            for blur in (0.0, 0.4, 0.8):
                for despeckle in (0, 1):
                    for morphology in (0, 1):
                        profiles.append(
                            CandidateProfile(
                                threshold=threshold,
                                blur=blur,
                                despeckle=despeckle,
                                morphology=morphology,
                                sharpen=blur > 0.0,
                                scale=scale,
                                turdsize=1 if scale >= 3 else 2,
                                alphamax=1.0,
                                opttolerance=0.15 if scale >= 3 else 0.2,
                            )
                        )
    # Sort to try more promising candidates first.
    profiles.sort(key=lambda p: (
        -p.scale,
        abs(p.threshold - 54),
        p.blur,
        p.despeckle,
        p.morphology,
    ))
    return profiles[:limit]


def magick_prepare_bitmap(png_path: Path, out_pbm: Path, profile: CandidateProfile, verbose: bool) -> None:
    cmd = [
        "magick",
        str(png_path),
        "-background", "white",
        "-alpha", "remove",
        "-alpha", "off",
        "-resize", f"{profile.scale * 100}%",
        "-colorspace", "gray",
        "-normalize",
    ]
    if profile.blur > 0:
        cmd += ["-blur", f"0x{profile.blur}"]
    if profile.sharpen:
        cmd += ["-unsharp", "0x0.75+0.75+0.008"]
    for _ in range(profile.despeckle):
        cmd += ["-despeckle"]
    if profile.morphology > 0:
        cmd += ["-morphology", "Close", f"Disk:{profile.morphology}"]
    cmd += [
        "-threshold", f"{profile.threshold}%",
        str(out_pbm),
    ]
    run(cmd, verbose=verbose)


def potrace_to_svg(pbm_path: Path, svg_path: Path, profile: CandidateProfile, verbose: bool) -> None:
    cmd = [
        "potrace",
        str(pbm_path),
        "-s",
        "-o", str(svg_path),
        "-t", str(profile.turdsize),
        "-a", str(profile.alphamax),
        "-O", str(profile.opttolerance),
    ]
    run(cmd, verbose=verbose)


def render_svg_to_png(svg_path: Path, out_png: Path, density: int, verbose: bool) -> None:
    cmd = [
        "magick",
        "-background", "white",
        "-density", str(density),
        str(svg_path),
        str(out_png),
    ]
    run(cmd, verbose=verbose)


def raster_mask_from_render(render_png: Path, target_size: tuple[int, int]) -> Image.Image:
    with Image.open(render_png) as im:
        gray = im.convert("L")
        if gray.size != target_size:
            gray = gray.resize(target_size, Image.Resampling.LANCZOS)
        mask = gray.point(lambda p: 255 if p < 245 else 0, mode="L")
    return mask.point(lambda p: 255 if p >= 128 else 0, mode="L")


def f1_score(a: Image.Image, b: Image.Image) -> float:
    ap = a.load()
    bp = b.load()
    w, h = a.size
    tp = fp = fn = 0
    for y in range(h):
        for x in range(w):
            av = 1 if ap[x, y] else 0
            bv = 1 if bp[x, y] else 0
            if av and bv:
                tp += 1
            elif av and not bv:
                fp += 1
            elif not av and bv:
                fn += 1
    if tp == 0:
        return 0.0
    precision = tp / (tp + fp) if tp + fp else 0.0
    recall = tp / (tp + fn) if tp + fn else 0.0
    if precision + recall == 0:
        return 0.0
    return 2 * precision * recall / (precision + recall)


def edge_mask(mask: Image.Image) -> Image.Image:
    # Crisp edge proxy for shape fidelity.
    return mask.filter(ImageFilter.FIND_EDGES).point(lambda p: 255 if p >= 8 else 0, mode="L")


def score_candidate(target_mask: Image.Image, rendered_mask: Image.Image) -> float:
    shape = f1_score(rendered_mask, target_mask)
    edge = f1_score(edge_mask(rendered_mask), edge_mask(target_mask))

    # Light penalty for overfilling/underfilling area.
    area_t = ImageStat.Stat(target_mask).sum[0] / 255.0
    area_r = ImageStat.Stat(rendered_mask).sum[0] / 255.0
    area_ratio = area_r / area_t if area_t else 1.0
    penalty = abs(math.log(area_ratio)) if area_ratio > 0 else 10.0

    return (shape * 0.72) + (edge * 0.28) - (penalty * 0.03)


def _strip_unit(value: str | None, default: float) -> float:
    if not value:
        return default
    match = re.match(r"^\s*([0-9]+(?:\.[0-9]+)?)", value)
    return float(match.group(1)) if match else default


def add_center_date(root: ET.Element, width: float, height: float, cfg: Config) -> None:
    text = ET.SubElement(root, f"{{{SVG_NS}}}text")
    text.set("id", "date-text")
    text.set("x", f"{width / 2:.2f}")
    text.set("y", f"{height * cfg.center_y_ratio:.2f}")
    text.set("text-anchor", "middle")
    text.set("dominant-baseline", "middle")
    text.set("fill", "currentColor")
    text.set("font-family", cfg.font_family)
    text.set("font-weight", cfg.font_weight)
    text.set("font-size", f"{max(12.0, min(width, height) * cfg.font_scale):.2f}")
    text.text = cfg.date_value


def post_process_svg(raw_svg_path: Path, final_svg_path: Path, cfg: Config, add_date: bool = True) -> None:
    tree = ET.parse(raw_svg_path)
    root = tree.getroot()

    width = _strip_unit(root.get("width"), 800.0)
    height = _strip_unit(root.get("height"), 600.0)
    if not root.get("viewBox"):
        root.set("viewBox", f"0 0 {int(round(width))} {int(round(height))}")

    root.set("fill", "currentColor")
    root.set("stroke", "none")

    for elem in root.iter():
        tag = elem.tag.split("}")[-1]
        if tag in {"path", "polygon", "rect", "circle", "ellipse", "line", "polyline", "g"}:
            if elem.get("fill") != "none":
                elem.set("fill", "currentColor")
            if elem.get("stroke") not in {None, "none"}:
                elem.set("stroke", "currentColor")

    if add_date:
        add_center_date(root, width, height, cfg)

    final_svg_path.write_text(ET.tostring(root, encoding="unicode"), encoding="utf-8")


def choose_best_trace(png_path: Path, cfg: Config) -> tuple[Path, CandidateProfile, float]:
    target_mask = load_target_mask(png_path)
    profiles = build_profiles(cfg.max_candidates)

    with tempfile.TemporaryDirectory(prefix="stamptrace_search_") as td:
        tmp = Path(td)
        best_score = -1e9
        best_profile: CandidateProfile | None = None
        best_raw_svg: Path | None = None

        for idx, profile in enumerate(profiles, start=1):
            pbm_path = tmp / f"cand_{idx}.pbm"
            raw_svg = tmp / f"cand_{idx}.svg"
            render_png = tmp / f"cand_{idx}.png"
            score_svg = tmp / f"cand_{idx}_score.svg"

            try:
                magick_prepare_bitmap(png_path, pbm_path, profile, cfg.verbose)
                potrace_to_svg(pbm_path, raw_svg, profile, cfg.verbose)
                # score without the date placeholder so it does not distort matching
                post_process_svg(raw_svg, score_svg, cfg, add_date=False)
                render_svg_to_png(score_svg, render_png, cfg.density, cfg.verbose)
                rendered_mask = raster_mask_from_render(render_png, target_mask.size)
                score = score_candidate(target_mask, rendered_mask)
            except subprocess.CalledProcessError as exc:
                if cfg.verbose:
                    print(f"Candidate failed for {png_path.name}: {profile} -> {exc}")
                continue

            if cfg.verbose:
                print(f"  score={score:.5f} profile={profile}")

            if score > best_score:
                best_score = score
                best_profile = profile
                best_raw_svg = tmp / "best_raw.svg"
                best_raw_svg.write_text(raw_svg.read_text(encoding="utf-8"), encoding="utf-8")

        if best_profile is None or best_raw_svg is None:
            raise RuntimeError(f"No trace candidates succeeded for {png_path.name}")

        kept = tmp / "kept_best.svg"
        kept.write_text(best_raw_svg.read_text(encoding="utf-8"), encoding="utf-8")
        return kept, best_profile, best_score


def parse_args() -> Config:
    parser = argparse.ArgumentParser(description="Search-based high-quality PNG to SVG passport stamp converter")
    parser.add_argument("--input", required=True, help="Directory containing *-arrival.png / *-departure.png files")
    parser.add_argument("--output", required=True, help="Directory to write SVG files into")
    parser.add_argument("--force", action="store_true", help="Overwrite existing output SVG files")
    parser.add_argument("--verbose", action="store_true", help="Print commands and candidate scores")
    parser.add_argument("--date-value", default="{{DATE}}", help="Date text placeholder/value to inject")
    parser.add_argument("--font-family", default="Arial, Helvetica, sans-serif", help="SVG font family for date text")
    parser.add_argument("--font-weight", default="700", help="SVG font weight for date text")
    parser.add_argument("--font-scale", type=float, default=0.11, help="Date font size as fraction of min(width,height)")
    parser.add_argument("--center-y-ratio", type=float, default=0.52, help="Vertical placement for date text")
    parser.add_argument("--density", type=int, default=384, help="Rasterisation density for candidate scoring")
    parser.add_argument("--max-candidates", type=int, default=48, help="How many trace profiles to evaluate per file")
    ns = parser.parse_args()
    return Config(
        input_dir=Path(ns.input).expanduser().resolve(),
        output_dir=Path(ns.output).expanduser().resolve(),
        force=ns.force,
        verbose=ns.verbose,
        date_value=ns.date_value,
        font_family=ns.font_family,
        font_weight=ns.font_weight,
        font_scale=ns.font_scale,
        center_y_ratio=ns.center_y_ratio,
        density=ns.density,
        max_candidates=ns.max_candidates,
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
            f"No matching PNG files found in {cfg.input_dir}. Expected names like al-arrival.png or al-departure.png."
        )

    failures = 0
    for png_path in files:
        out_path = cfg.output_dir / png_path.with_suffix(".svg").name
        if out_path.exists() and not cfg.force:
            print(f"Skipping existing file: {out_path.name}")
            continue

        print(f"Tracing {png_path.name} -> {out_path}")
        try:
            best_raw_svg, best_profile, best_score = choose_best_trace(png_path, cfg)
            post_process_svg(best_raw_svg, out_path, cfg, add_date=True)
            print(f"  kept profile={best_profile} score={best_score:.5f}")
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
