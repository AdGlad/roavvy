"""Sanity-checks every traced SVG for the corner-fill inversion bug fixed on
2026-07-23 (see vectorise.py docstring).

Renders each SVG at low resolution and compares alpha at the four corners
(background) against the centre (subject). A correctly-traced silhouette
has transparent corners and >0 opaque coverage; the old bug produced
fully opaque corners with a hollow, near-full-canvas fill.

Requires Inkscape (used elsewhere in this pipeline, see rebuild_pngs.sh).

Usage:
    python tools/silhouette_factory/scripts/verify_polarity.py
"""

from __future__ import annotations

import subprocess
import tempfile
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

from PIL import Image

REPO = Path(__file__).resolve().parents[3]
FACTORY = REPO / "tools" / "silhouette_factory" / "assets"
INKSCAPE = "/Applications/Inkscape.app/Contents/MacOS/inkscape"

SVG_DIRS = ["svg", "svg_landmarks", "svg_plants"]
RENDER_SIZE = 80
CORNER_INSET = 2
WORKERS = 8


def _check_one(svg_path: Path) -> str | None:
    """Returns a problem description, or None if the polarity looks right."""
    with tempfile.NamedTemporaryFile(suffix=".png") as tmp:
        result = subprocess.run(
            [
                INKSCAPE,
                "--export-type=png",
                f"--export-width={RENDER_SIZE}",
                "--export-background-opacity=0",
                "-o",
                tmp.name,
                str(svg_path),
            ],
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            return f"render failed: {result.stderr.strip()[:200]}"

        im = Image.open(tmp.name).convert("RGBA")
        w, h = im.size
        c = CORNER_INSET
        corners = [
            im.getpixel((c, c))[3],
            im.getpixel((w - c - 1, c))[3],
            im.getpixel((c, h - c - 1))[3],
            im.getpixel((w - c - 1, h - c - 1))[3],
        ]
        import numpy as np

        opaque_frac = (np.array(im)[:, :, 3] > 128).mean()

        if all(a > 128 for a in corners):
            return f"all 4 corners opaque, {opaque_frac:.1%} of canvas filled — inverted"
        if opaque_frac == 0:
            return "fully transparent — trace produced nothing"
        return None


def main() -> int:
    targets = []
    for d in SVG_DIRS:
        svg_dir = FACTORY / d
        if svg_dir.exists():
            targets.extend(sorted(svg_dir.glob("*/*.svg")))

    print(f"Verifying {len(targets)} SVGs with {WORKERS} workers...")
    suspects: list[str] = []
    with ThreadPoolExecutor(max_workers=WORKERS) as pool:
        futures = {pool.submit(_check_one, svg): svg for svg in targets}
        for i, fut in enumerate(as_completed(futures), 1):
            svg = futures[fut]
            issue = fut.result()
            if issue:
                suspects.append(f"{svg.relative_to(FACTORY)}: {issue}")
            if i % 100 == 0:
                print(f"  {i}/{len(targets)} checked...")

    print(f"\nDone: {len(targets)} checked, {len(suspects)} suspected problems")
    for s in sorted(suspects):
        print(f"  ✗ {s}")
    return 1 if suspects else 0


if __name__ == "__main__":
    raise SystemExit(main())
