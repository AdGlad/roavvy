"""Converts an arbitrary photo into a black-silhouette-on-transparent PNG mask,
matching the convention of every hand/AI-produced mask in assets/png*/ (solid
RGB (0,0,0) in the subject region, alpha carries the shape).

Uses rembg (U2-Net) for subject/background segmentation -- this is a one-time
~176MB model download to ~/.u2net/ on first call. Import is lazy so the review
server can start without rembg installed; ImportError is surfaced as a normal
Python exception for the caller to report.
"""

from __future__ import annotations

import io

import numpy as np
from PIL import Image


def photo_to_silhouette_bytes(photo_bytes: bytes) -> bytes:
    """Returns PNG bytes: a solid black silhouette of the photo's subject on
    a transparent background. Raises on decode/segmentation failure."""
    from rembg import remove  # lazy: heavy (onnxruntime + model) import

    img = Image.open(io.BytesIO(photo_bytes)).convert("RGB")
    cutout = remove(img).convert("RGBA")

    arr = np.array(cutout)
    arr[:, :, 0] = 0
    arr[:, :, 1] = 0
    arr[:, :, 2] = 0
    flattened = Image.fromarray(arr, mode="RGBA")

    out = io.BytesIO()
    flattened.save(out, format="PNG")
    return out.getvalue()
