"""Traces an alpha-masked RGBA PNG into a solid-black-on-transparent SVG
silhouette via potrace.

Polarity note (2026-07-23 fix): potrace's SVG backend fills whatever is
BLACK in the bitmap it is given (pixel value 0 in PIL mode "1"); WHITE
(255) stays empty. Every silhouette generated before this fix mapped the
mask backwards -- alpha=255 (the subject) was written as white and
alpha=0 (background) as black, so potrace traced the background and left
the subject as an untraced hole. Confirmed by rendering samples and
comparing corner vs. centre alpha against the source PNG masks in
assets/png*/, which are correctly polarised (see verify_polarity.py).

The fix: `_alpha_to_bitmap` below maps subject -> black (0), background ->
white (255) before ever calling potrace.
"""

from __future__ import annotations

import subprocess
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

POTRACE = "potrace"


def _strip_opaque_letterbox(alpha: Image.Image) -> Image.Image:
    """Zeroes out solid, full-span opaque bars at the image border.

    A handful of source masks were exported with opaque square-padding
    bars (from a resize step) instead of transparent padding. Left alone,
    those bars get traced as part of the subject. Only bands that are
    >=98% opaque across their *entire* span from the edge inward are
    stripped, so a subject that legitimately reaches the canvas edge is
    left untouched.
    """
    arr = np.array(alpha)
    h, w = arr.shape
    row_opaque = (arr > 127).mean(axis=1)
    col_opaque = (arr > 127).mean(axis=0)

    top = 0
    while top < h // 2 and row_opaque[top] > 0.98:
        top += 1
    bottom = h
    while bottom > h // 2 and row_opaque[bottom - 1] > 0.98:
        bottom -= 1
    left = 0
    while left < w // 2 and col_opaque[left] > 0.98:
        left += 1
    right = w
    while right > w // 2 and col_opaque[right - 1] > 0.98:
        right -= 1

    if top == 0 and bottom == h and left == 0 and right == w:
        return alpha

    trimmed = arr.copy()
    trimmed[:top, :] = 0
    trimmed[bottom:, :] = 0
    trimmed[:, :left] = 0
    trimmed[:, right:] = 0
    return Image.fromarray(trimmed, mode="L")


def _alpha_to_bitmap(
    alpha: Image.Image,
    *,
    blur_radius: float,
    preserve_detail: bool,
    alpha_threshold: int,
) -> Image.Image:
    """Converts an alpha channel into a potrace-ready mode "1" bitmap.

    Subject (alpha > threshold) becomes black (0, traced); background
    becomes white (255, left empty).
    """
    alpha = _strip_opaque_letterbox(alpha)
    if blur_radius > 0 and not preserve_detail:
        # Smooths jagged AI-mask edges before thresholding.
        alpha = alpha.filter(ImageFilter.GaussianBlur(blur_radius))
    return alpha.point(lambda a: 0 if a > alpha_threshold else 255).convert("1")


def vectorise_path(
    png_path: Path | str,
    svg_path: Path | str,
    *,
    blur_radius: float = 3.0,
    simplify: float = 0.5,
    preserve_detail: bool = False,
    alpha_threshold: int = 127,
) -> None:
    """Renders the RGBA mask at `png_path` to a silhouette SVG at `svg_path`.

    `simplify` in [0, 1] trades detail for smoother, lower-node-count
    paths (higher = smoother). `preserve_detail` disables both the
    pre-trace blur and most simplification, for hand-cleaned masks that
    are already crisp.
    """
    png_path = Path(png_path)
    svg_path = Path(svg_path)
    svg_path.parent.mkdir(parents=True, exist_ok=True)

    img = Image.open(png_path).convert("RGBA")
    alpha = img.split()[3]
    bitmap = _alpha_to_bitmap(
        alpha,
        blur_radius=blur_radius,
        preserve_detail=preserve_detail,
        alpha_threshold=alpha_threshold,
    )

    alphamax = 0.6 if preserve_detail else 1.0
    opttolerance = 0.05 if preserve_detail else round(0.1 + simplify * 0.3, 3)
    turdsize = 2 if preserve_detail else max(2, round(2 + simplify * 10))

    with tempfile.TemporaryDirectory() as tmp:
        pbm_path = Path(tmp) / "mask.pbm"
        bitmap.save(pbm_path)

        result = subprocess.run(
            [
                POTRACE,
                str(pbm_path),
                "--svg",
                "-o",
                str(svg_path),
                "--alphamax",
                str(alphamax),
                "--opttolerance",
                str(opttolerance),
                "--turdsize",
                str(turdsize),
            ],
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            raise RuntimeError(f"potrace failed for {png_path}: {result.stderr.strip()}")
