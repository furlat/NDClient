"""Bake exact finite authored optical socket bytes; never alter source artwork.

Run tools/export_surface_socket_inputs.gd headlessly first. Use the engine's
existing Python environment (Pillow), then --gallery or --all. Runtime files live
only under ignored .derived/surface-sockets. Full scope covers registered optical
attachments. Lighting-only creature registrations without an attachment reference
remain explicit runtime fallbacks; no attachment geometry is inferred.
"""
import argparse
import json
import math
from pathlib import Path

from PIL import Image

PROJECT = Path(__file__).resolve().parents[1]


def local_path(path, project=PROJECT):
    if path.startswith("res://"):
        return project / path[6:]
    if path.startswith("C:/"):
        return Path("/mnt/c") / path[3:]
    return Path(path)


def stamp(path):
    value = path.stat()
    return {"mtime": int(value.st_mtime), "size": value.st_size}


def write_json(path, document):
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(document, separators=(",", ":")) + "\n")
    temporary.replace(path)


def valid_inputs(inputs, project=PROJECT):
    return all(local_path(path, project).is_file() and stamp(local_path(path, project)) == value
               for path, value in inputs.items())


def point(value, width, height):
    if not isinstance(value, dict) or not all(k in value for k in ("x", "y")):
        return None
    if not all(isinstance(value[k], (int, float)) and math.isfinite(value[k]) for k in ("x", "y")):
        return None
    x, y = math.floor(value["x"]), math.floor(value["y"])
    return (x, y) if 0 <= x < width and 0 <= y < height else None


def authored_points(data):
    """Rig/clip -> sheet pixels, with effective frame counts and facing rows."""
    result = {}
    for rig_id, rig in data["rigs"].items():
        cell_w, cell_h = int(rig["cell_width"]), int(rig["cell_height"])
        for clip, source in rig["clips"].items():
            pixels = set()
            for facing, row in rig["facing_rows"].items():
                for frame in range(int(source["frames"])):
                    values = [rig.get("body_anchor")]
                    for bank in rig.get("pose_sockets", {}).values():
                        frames = bank.get(clip, {}).get(facing, [])
                        if frames:
                            values.append(frames[min(frame, len(frames) - 1)])
                    for value in values:
                        selected = point(value, cell_w, cell_h)
                        if selected is not None:
                            pixels.add((selected[0] + frame * cell_w, selected[1] + int(row) * cell_h))
            result[rig_id, clip] = pixels
    for spell in data["spells"]:
        cast = spell["cast"]
        clip = cast.get("actionClip")
        for bank in spell["banks"]:
            for rig_id, rig in data["rigs"].items():
                if (bank["rig"] and bank["rig"] != rig_id) or clip not in rig["clips"]:
                    continue
                cell_w, cell_h = int(rig["cell_width"]), int(rig["cell_height"])
                count = int(rig["clips"][clip]["frames"])
                sockets = bank["sockets"]
                for phase in ("preparation", "release"):
                    for facing, values in sockets.get(phase, {}).items():
                        if facing not in rig["facing_rows"]:
                            continue
                        samples = enumerate(values) if isinstance(values, list) else [(int(cast.get("releaseFrame", -1)), values)]
                        for frame, value in samples:
                            selected = point(value, cell_w, cell_h)
                            if selected is not None and 0 <= frame < count:
                                result[rig_id, clip].add((selected[0] + frame * cell_w,
                                                          selected[1] + int(rig["facing_rows"][facing]) * cell_h))
    return result


def source_points(data, points, modular, creatures):
    result = {}
    # Effective clip sheets include selected native .tres source replacements.
    for rig_id, rig in data["rigs"].items():
        for clip, source in rig["clips"].items():
            for resource in source["sheets"].values():
                media = data["resources"].get(resource, resource)
                layer = data["sheet_components"].get(media, {}).get("source_layers", {})
                for path in layer.values() if layer else [media]:
                    result.setdefault(path, set()).update(points[rig_id, clip])
    # Modular delivery explicitly registers its source action, including outfit
    # components not currently worn. The modular rig defines those same cells.
    for path, record in modular["records"].items():
        key = ("neuroclient.modular", record.get("source_action"))
        if key in points:
            result.setdefault(path, set()).update(points[key])
    for path, record in creatures["records"].items():
        for alias in record.get("registered_aliases", []):
            key = (alias["rig"], alias["clip"])
            if key in points:
                result.setdefault(path, set()).update(points[key])
    return result


def sidecar_relative(source):
    if not source.startswith("/media/") or not source.endswith(".png"):
        raise ValueError("Unregistered media identity: " + source)
    relative = Path(source[7:]).with_suffix(".json")
    if ".." in relative.parts:
        raise ValueError("Source outside derived root")
    return relative


def sample_bytes(paths, pixels):
    images = {}
    try:
        for channel, path in paths.items():
            images[channel] = Image.open(path).convert("RGBA")
        size = images["depth"].size
        if any(image.size != size for image in images.values()):
            raise ValueError("Optical source layout mismatch")
        samples = {}
        for x, y in sorted(pixels):
            if not (0 <= x < size[0] and 0 <= y < size[1]):
                raise ValueError(f"Authored sample outside registered optical source: {x},{y} in {size}")
            depth = images["depth"].getpixel((x, y))
            samples[f"{x},{y}"] = [depth[0], depth[3], images["support"].getpixel((x, y))[0], images["solid"].getpixel((x, y))[0]]
        return list(size), samples
    finally:
        for image in images.values():
            image.close()


def bake(data, output, gallery=False, sandbox=False):
    if not valid_inputs(data["authoring_inputs"]):
        raise ValueError("Effective authoring export is stale; rerun the headless export")
    modular = json.loads((PROJECT / "generated/character_geometry.json").read_text())
    creatures = json.loads((PROJECT / "generated/creature_geometry.json").read_text())
    points = authored_points(data)
    requested = source_points(data, points, modular, creatures)
    roots = data["roots"]
    selected = None
    if gallery:
        selected = set(data["gallery_sources"])
        creature_root = roots["creature_geometry_root"] + "/"
        selected = {creatures.get("colour_sources", {}).get(path.removeprefix(creature_root), path)
                    if path.startswith(creature_root) else path for path in selected}
    if sandbox and selected is not None:
        selected.update(f"/media/smallscale/modular/{category}/{clip}.png"
                        for category in ("NakedBody", "Legs2", "Chest14", "Belt2", "Head10")
                        for clip in ("Idle", "Attack5"))
    records = dict(modular["records"])
    records.update(creatures["records"])
    fallbacks = []
    written = reused = total_samples = total_bytes = optical_bytes = 0
    admitted_sidecars = set()
    baked_sources = []
    manifest_path = output / "manifest.json"
    old_manifest = json.loads(manifest_path.read_text()) if manifest_path.is_file() else {}
    for source, record in records.items():
        if selected is not None and source not in selected:
            continue
        if "files" not in record:
            fallbacks.append({"source": source, "reason": record.get("status", "unregistered_geometry")})
            continue
        if "reference" not in record:
            fallbacks.append({"source": source, "reason": "no_registered_attachment_reference"})
            continue
        if source not in modular["records"] and not record.get("registered_aliases"):
            fallbacks.append({"source": source, "reason": "no_registered_authored_pose"})
            continue
        pixels = requested.get(source, set())
        if not pixels:
            fallbacks.append({"source": source, "reason": "no_registered_authored_pose"})
            continue
        root_name = "character_geometry_root" if source in modular["records"] else "creature_geometry_root"
        root = roots[root_name]
        optical_paths = {"depth": root + "/" + record["files"]["depth"],
                         "support": root + "/" + record["files"]["support"],
                         "solid": root + "/" + str(Path(record["reference"]).parent / "solid-valid.png")}
        missing = [path for path in optical_paths.values() if not local_path(path).is_file()]
        if missing:
            fallbacks.append({"source": source, "reason": "missing_registered_companion", "paths": missing})
            continue
        optical = {channel: {"path": path, **stamp(local_path(path))} for channel, path in optical_paths.items()}
        target = output / sidecar_relative(source)
        previous = json.loads(target.read_text()) if target.is_file() else {}
        if (previous.get("schema") == 1 and previous.get("source") == source
                and previous.get("optical") == optical and set(previous.get("samples", {})) == {f"{x},{y}" for x, y in pixels}):
            reused += 1
            count = len(previous["samples"])
            size = previous["size"]
        else:
            size, samples = sample_bytes({k: local_path(v) for k, v in optical_paths.items()}, pixels)
            target.parent.mkdir(parents=True, exist_ok=True)
            write_json(target, {"schema": 1, "source": source, "size": size, "samples": samples,
                                "optical": optical, "sample_count": len(samples)})
            written += 1
            count = len(samples)
        admitted_sidecars.add(target)
        baked_sources.append(source)
        total_samples += count
        total_bytes += target.stat().st_size
        optical_bytes += size[0] * size[1] * 4 * 3
    if selected is not None:
        for source in sorted(selected - records.keys()):
            fallbacks.append({"source": source, "reason": "no_registered_geometry"})
    output.mkdir(parents=True, exist_ok=True)
    if not valid_inputs(data["authoring_inputs"]):
        raise ValueError("Authoring changed during baking; manifest not published")
    # A refreshed global validity stamp must not bless unselected sidecars
    # collected from an older authored point set. Only derived cache files go.
    if old_manifest.get("authoring_inputs") != data["authoring_inputs"]:
        for candidate in output.rglob("*.json"):
            if candidate.name not in ("manifest.json", "bake-report.json") and candidate not in admitted_sidecars:
                candidate.unlink()
    write_json(manifest_path, {"schema": 1, "authoring_inputs": data["authoring_inputs"]})
    report = {"schema": 1, "scope": "gallery+sandbox" if gallery and sandbox else "gallery" if gallery else "registered_optical_attachments", "written": written, "reused": reused,
              "sources": written + reused, "baked_sources": baked_sources, "samples": total_samples, "sidecar_bytes": total_bytes,
              "full_optical_rgba_bytes": optical_bytes, "fallbacks": fallbacks}
    write_json(output / "bake-report.json", report)
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--inputs", type=Path, default=PROJECT / ".derived/surface-socket-inputs.json")
    parser.add_argument("--output", type=Path, default=PROJECT / ".derived/surface-sockets")
    parser.add_argument("--sandbox", action="store_true", help="Include the existing finite five-layer Idle/Attack5 socket fixture")
    scope = parser.add_mutually_exclusive_group(required=True)
    scope.add_argument("--gallery", action="store_true")
    scope.add_argument("--all", action="store_true")
    args = parser.parse_args()
    report = bake(json.loads(args.inputs.read_text()), args.output, args.gallery, args.sandbox)
    print(json.dumps({k: v for k, v in report.items() if k not in ("fallbacks", "baked_sources")} | {"fallback_count": len(report["fallbacks"])}))


if __name__ == "__main__":
    main()
