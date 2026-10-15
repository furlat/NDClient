"""Page the selected oversized numeric packets without changing any pixel.

The authored frame rectangles remain the coordinates of the original sheets.
SourceCatalog adapts only their texture path and rectangle using the emitted
layout manifest. The source artwork and authoring documents are never changed.
"""

import json
import os
import re
from pathlib import Path

from PIL import Image


PROJECT = Path(__file__).resolve().parents[1]
BANK = "prop.content-slender-monument.break"
PAGE_COLUMNS = 4
PAGE_ROWS = 2


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


def paginate(source: str, cell: tuple[int, int], output: str) -> dict:
    absolute = (local_path(setting("media_root")) / source.removeprefix("/media/")) if source.startswith("/media/") else local_path(source)
    target = local_path(output)
    with Image.open(absolute) as image:
        image.load()
        width, height = image.size
        if image.mode != "RGBA" or width % cell[0] or height % cell[1]:
            raise ValueError(f"Expected whole RGBA frame cells: {absolute}, {image.mode}, {image.size}")
        source_columns, source_rows = width // cell[0], height // cell[1]
        count = source_columns * source_rows
        cells_per_page = PAGE_COLUMNS * PAGE_ROWS
        if count % cells_per_page:
            raise ValueError("The selected no-padding layout must contain every source cell exactly")
        size = (PAGE_COLUMNS * cell[0], PAGE_ROWS * cell[1])
        target.mkdir(parents=True, exist_ok=True)
        pages = []
        for page in range(count // cells_per_page):
            result = Image.new(image.mode, size)
            for local in range(cells_per_page):
                index = page * cells_per_page + local
                x, y = index % source_columns * cell[0], index // source_columns * cell[1]
                result.paste(image.crop((x, y, x + cell[0], y + cell[1])),
                             (local % PAGE_COLUMNS * cell[0], local // PAGE_COLUMNS * cell[1]))
            name = f"page-{page:03d}.png"
            result.save(target / name, format="PNG")
            # Compare each saved/reloaded cell, including the page boundaries.
            with Image.open(target / name) as saved:
                saved.load()
                if saved.mode != image.mode or saved.size != size:
                    raise ValueError(f"Saved numeric page changed format: {target / name}")
                for local in range(cells_per_page):
                    index = page * cells_per_page + local
                    x, y = index % source_columns * cell[0], index // source_columns * cell[1]
                    dx, dy = local % PAGE_COLUMNS * cell[0], local // PAGE_COLUMNS * cell[1]
                    original = image.crop((x, y, x + cell[0], y + cell[1])).tobytes()
                    actual = saved.crop((dx, dy, dx + cell[0], dy + cell[1])).tobytes()
                    if original != actual:
                        raise ValueError(f"Paging changed source cell {index}: {source}")
            pages.append(output + "/" + name)
        return {"pages": pages, "source_size": [width, height], "size": list(size),
                "cell": list(cell), "source_columns": source_columns, "columns": PAGE_COLUMNS,
                "cells_per_page": cells_per_page, "verified_cells": count,
                "page_rgba_bytes": size[0] * size[1] * 4}


def main() -> None:
    authoring = PROJECT / "authoring"
    index = json.loads((authoring / "environment/index.json").read_text())
    bank = json.loads((authoring / index["banks"][BANK]).read_text())
    original = "/media/environment/props/content-slender-monument/break/geometry/geometry-native.png"
    normals = json.loads((PROJECT / "generated/environment_receiving_normals.json").read_text())
    selected = normals["normals"][original]["path"]
    cell = tuple(bank["cell"])
    for frames in bank["surface_frames_by_pose"].values():
        for frame in frames:
            for region in [frame["geometry_region"], frame["normal"]["region"]]:
                if region["path"] != original:
                    continue
                x, y, w, h = region["rect"]
                if (w, h) != cell or x % w or y % h:
                    raise ValueError("Selected bank has a source rectangle crossing reflow cells")
    layouts = {}
    for source, label in [(original, "original-depth"), (selected, "selected-normal")]:
        output = f"res://.derived/environment-texture-layouts/content-slender-monument-break/{label}/pages"
        layouts[source] = paginate(source, cell, output)
    result = {"version": 2, "operation": "lossless_frame_cell_pages", "layouts": layouts}
    # Publish only after every page/channel has passed the saved-byte comparison.
    manifest = PROJECT / "generated/environment_texture_layouts.json"
    pending = manifest.with_suffix(".json.tmp")
    pending.write_text(json.dumps(result, indent=2) + "\n")
    pending.replace(manifest)
    receipt = {"bank": BANK, "checks": sum(row["verified_cells"] for row in layouts.values()),
               "failures": [], "layouts": layouts, "source_artwork_modified": False}
    (PROJECT / ".runtime").mkdir(exist_ok=True)
    (PROJECT / ".runtime/environment-texture-layout-preparation.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print(json.dumps(receipt, indent=2))


if __name__ == "__main__":
    main()
