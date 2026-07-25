"""Converts an arbitrary photo into a black-and-transparent PNG mask, matching
the convention of every hand/AI-produced mask in assets/png*/ (solid RGB
(0,0,0) in the subject region, alpha carries the shape).

Uses rembg (U2-Net) for subject/background segmentation -- this is a one-time
~176MB model download to ~/.u2net/ on first call. Import is lazy so the review
server can start without rembg installed; ImportError is surfaced as a normal
Python exception for the caller to report.
"""

from __future__ import annotations

import io

import numpy as np
from PIL import Image


def photo_to_silhouette_bytes(
    photo_bytes: bytes,
    *,
    preserve_detail: bool = False,
    detail_threshold: int = 140,
) -> bytes:
    """Returns PNG bytes: a black-and-transparent mask of the photo's subject.

    By default (`preserve_detail=False`) the entire subject rembg identifies
    is flattened to solid black -- correct for a subject with no internal
    negative space (an animal, a plant).

    `preserve_detail=True` additionally punches transparent holes for
    notably light-toned regions *within* the subject -- e.g. a building's
    windows, or gaps between architectural elements -- instead of flattening
    over them. rembg's own segmentation only separates subject from
    background; it has no notion of holes inside the subject, so without
    this the windows on a tower silhouette get filled in solid. Only useful
    when the subject is drawn/photographed noticeably darker than its own
    internal details (works well for icon-style line art; a real photo with
    a light-coloured subject would need `detail_threshold` raised or this
    left off).
    """
    from rembg import remove  # lazy: heavy (onnxruntime + model) import

    img = Image.open(io.BytesIO(photo_bytes)).convert("RGB")
    cutout = remove(img).convert("RGBA")

    arr = np.array(cutout)
    alpha = arr[:, :, 3]

    if preserve_detail:
        subject = alpha > 127
        luminance = np.array(img.convert("L"))
        light_detail = subject & (luminance > detail_threshold)
        alpha = np.where(light_detail, 0, alpha)

    arr[:, :, 0] = 0
    arr[:, :, 1] = 0
    arr[:, :, 2] = 0
    arr[:, :, 3] = alpha
    flattened = Image.fromarray(arr, mode="RGBA")

    out = io.BytesIO()
    flattened.save(out, format="PNG")
    return out.getvalue()
