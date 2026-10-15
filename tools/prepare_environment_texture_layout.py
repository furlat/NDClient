"""Page the selected oversized numeric packets without changing any pixel.

The authored frame rectangles remain the coordinates of the original sheets.
SourceCatalog adapts only their texture path and rectangle using the emitted
layout manifest. The source artwork and authoring documents are never changed.
"""

import argparse
import json
import os
import re
import time
from pathlib import Path

from PIL import Image


PROJECT = Path(__file__).resolve().parents[1]
BANK = "prop.content-slender-monument.break"
PAGE_SIZE = (1536, 768)
MIN_SOURCE_BYTES = 16 * 1024 * 1024


def local_path(value: str) -> Path:
    if value.startswith("res://"):
        return PROJECT / value[6:]
    if os.name != "nt" and re.match(r"^[A-Za-z]:/", value):
        return Path("/mnt") / value[0].lower() / value[3:]
    return Path(value)


def setting(name: str) -> str:
    match = re.search(r"^" + re.escape(name) + r'="([^"]+)"$',
                      (PROJECT / "project.godot").read_text(), re.MULTILINE)
    if not match:
        raise ValueError(f"Missing source_data setting: {name}")
    return match.group(1)


def paginate(source: str, cell: tuple[int, int], output: str,
             page_size: tuple[int, int] = PAGE_SIZE) -> dict:
    absolute = (local_path(setting("media_root")) / source.removeprefix("/media/")) if source.startswith("/media/") else local_path(source)
    target = local_path(output)
    with Image.open(absolute) as image:
        image.load()
        width, height = image.size
        if image.mode != "RGBA" or width % cell[0] or height % cell[1]:
            raise ValueError(f"Expected whole RGBA frame cells: {absolute}, {image.mode}, {image.size}")
        source_columns, source_rows = width // cell[0], height // cell[1]
        count = source_columns * source_rows
        columns, rows = page_size[0] // cell[0], page_size[1] // cell[1]
        if columns < 1 or rows < 1:
            raise ValueError("An authored numeric cell exceeds the selected page bounds")
        cells_per_page = columns * rows
        size = (columns * cell[0], rows * cell[1])
        target.mkdir(parents=True, exist_ok=True)
        pages = []
        for page in range((count + cells_per_page - 1) // cells_per_page):
            result = Image.new(image.mode, size)
            used_cells = min(cells_per_page, count - page * cells_per_page)
            for local in range(used_cells):
                index = page * cells_per_page + local
                x, y = index % source_columns * cell[0], index // source_columns * cell[1]
                result.paste(image.crop((x, y, x + cell[0], y + cell[1])),
                             (local % columns * cell[0], local // columns * cell[1]))
            name = f"page-{page:03d}.png"
            result.save(target / name, format="PNG")
            # Compare each saved/reloaded cell, including the page boundaries.
            with Image.open(target / name) as saved:
                saved.load()
                if saved.mode != image.mode or saved.size != size:
                    raise ValueError(f"Saved numeric page changed format: {target / name}")
                for local in range(used_cells):
                    index = page * cells_per_page + local
                    x, y = index % source_columns * cell[0], index // source_columns * cell[1]
                    dx, dy = local % columns * cell[0], local // columns * cell[1]
                    original = image.crop((x, y, x + cell[0], y + cell[1])).tobytes()
                    actual = saved.crop((dx, dy, dx + cell[0], dy + cell[1])).tobytes()
                    if original != actual:
                        raise ValueError(f"Paging changed source cell {index}: {source}")
            pages.append(output + "/" + name)
        return {"pages": pages, "source_size": [width, height], "size": list(size),
                "cell": list(cell), "source_columns": source_columns, "columns": columns,
                "cells_per_page": cells_per_page, "verified_cells": count,
                "page_rgba_bytes": size[0] * size[1] * 4}


def bank_layouts(bank_id: str, index: dict, normals: dict) -> dict:
    bank = json.loads((PROJECT / "authoring" / index["banks"][bank_id]).read_text())
    regions = {}
    for frames in bank["surface_frames_by_pose"].values():
        for frame in frames:
            for region in [frame["geometry_region"], frame["normal"]["region"]]:
                regions.setdefault(region["path"], []).append(region["rect"])
    layouts = {}
    oversized = []
    for original, rectangles in regions.items():
        absolute = local_path(setting("media_root")) / original.removeprefix("/media/") if original.startswith("/media/") else local_path(original)
        with Image.open(absolute) as image:
            if image.width * image.height * 4 <= MIN_SOURCE_BYTES:
                continue
        oversized.append((original, rectangles))
    for source_index, (original, rectangles) in enumerate(oversized):
        sizes = {(int(rect[2]), int(rect[3])) for rect in rectangles}
        if len(sizes) != 1:
            raise ValueError(f"Selected numeric source has inconsistent authored cells: {original}")
        cell = next(iter(sizes))
        for x, y, w, h in rectangles:
            if x % w or y % h:
                raise ValueError(f"Selected bank has a rectangle crossing reflow cells: {bank_id}")
        selected = normals.get(original, {}).get("path", original)
        folder = bank_id.removeprefix("prop.").replace(".", "-")
        if len(oversized) > 1:
            folder += f"/source-{source_index:03d}"
        for source, label in [(original, "original-depth"), (selected, "selected-normal")]:
            if source in layouts:
                continue
            output = f"res://.derived/environment-texture-layouts/{folder}/{label}/pages"
            layouts[source] = paginate(source, cell, output)
    if not layouts:
        raise ValueError(f"Selected bank has no numeric source larger than16MiB: {bank_id}")
    return layouts


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bank", action="append", help="Explicit registered environment bank; repeat for multiple banks")
    args = parser.parse_args()
    banks = args.bank or [BANK]
    began = time.perf_counter()
    authoring = PROJECT / "authoring"
    index = json.loads((authoring / "environment/index.json").read_text())
    normals = json.loads((PROJECT / "generated/environment_receiving_normals.json").read_text())
    layouts = {}
    bank_sources = {}
    for bank_id in banks:
        prepared = bank_layouts(bank_id, index, normals["normals"])
        layouts.update(prepared)
        bank_sources[bank_id] = list(prepared)
    # Publish only after every page/channel has passed the saved-byte comparison.
    manifest = PROJECT / "generated/environment_texture_layouts.json"
    result = json.loads(manifest.read_text()) if manifest.is_file() else {"layouts": {}}
    result.update(version=2, operation="lossless_frame_cell_pages")
    result["layouts"].update(layouts)
    pending = manifest.with_suffix(".json.tmp")
    pending.write_text(json.dumps(result, indent=2) + "\n")
    pending.replace(manifest)
    receipt = {"banks": bank_sources, "checks": sum(row["verified_cells"] for row in layouts.values()),
               "failures": [], "layouts": layouts, "source_artwork_modified": False,
               "elapsed_seconds": time.perf_counter() - began}
    (PROJECT / ".runtime").mkdir(exist_ok=True)
    (PROJECT / ".runtime/environment-texture-layout-preparation.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print(json.dumps(receipt, indent=2))


if __name__ == "__main__":
    main()
