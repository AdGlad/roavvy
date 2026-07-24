"""Batch re-traces every source PNG mask under assets/png*/ into assets/svg*/,
replacing the polarity-inverted output of the pre-2026-07-23 pipeline (see
vectorise.py docstring). Safe to re-run: each SVG is fully regenerated from
its PNG source, never patched in place.

Usage:
    python tools/silhouette_factory/scripts/retrace_all.py
"""

from __future__ import annotations

from pathlib import Path

from vectorise import vectorise_path

REPO = Path(__file__).resolve().parents[3]
FACTORY = REPO / "tools" / "silhouette_factory" / "assets"

# (png source dir, svg output dir)
SOURCES = [
    (FACTORY / "png", FACTORY / "svg"),
    (FACTORY / "png_landmarks", FACTORY / "svg_landmarks"),
    (FACTORY / "png_plants", FACTORY / "svg_plants"),
]


def main() -> int:
    total = 0
    failed: list[str] = []

    for png_dir, svg_dir in SOURCES:
        if not png_dir.exists():
            continue
        pngs = sorted(png_dir.glob("*/*.png"))
        print(f"\n── {png_dir.name} ({len(pngs)} PNGs → {svg_dir.name})")
        for png in pngs:
            cc = png.parent.name
            svg = svg_dir / cc / f"{png.stem}.svg"
            total += 1
            try:
                vectorise_path(png, svg)
            except Exception as exc:  # noqa: BLE001
                failed.append(f"{png.relative_to(FACTORY)}: {exc}")
                print(f"  ✗ {png.stem} ({exc})")

    print(f"\nDone: {total - len(failed)}/{total} traced, {len(failed)} failed")
    if failed:
        print("\nFailures:")
        for f in failed:
            print(f"  {f}")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
