"""Copy four equipped body sets and derive the existing optical companions.

Offline intake only. Never imports Godot, changes the source laboratory, or
chooses gameplay events. The decode/projection kernels come from the delivered
lab tools/build_elemental_production.py; its source-writing main is not run.
"""

import argparse
import json
import math
import shutil
from pathlib import Path

import numpy as np
from PIL import Image


VARIANTS = ("AirMyrmidon", "EarthMyrmidon", "FireMyrmidon", "WaterMyrmidon")
ACTIONS = ("Idle", "Walk", "Attack", "AttackHeavy", "Jab", "Hook", "Cast", "Hit", "Death")


def decode(g):
    # Literal canonical decoder from the existing elemental production tool.
    code = g[..., 0].astype(np.uint32) * 256 + g[..., 1]
    valid = code > 0
    depth = 9 + (code[valid].astype(float) - 1) * 12 / 65534
    p = g[valid, 2:4].astype(float) / 255 * 2 - 1
    normal = np.column_stack((p, 1 - np.abs(p).sum(axis=1)))
    t = np.maximum(-normal[:, 2], 0)
    normal[:, :2] += np.where(normal[:, :2] >= 0, -t[:, None], t[:, None])
    normal /= np.linalg.norm(normal, axis=1)[:, None]
    return valid, depth, normal


def source_file(root, reference):
    path = (root / reference["path"]).resolve()
    if not path.is_relative_to(root):
        raise ValueError("Source image is outside the declared delivery: " + str(path))
    return path


def image(path):
    with Image.open(path) as opened:
        return np.asarray(opened.convert("RGBA"))


def selected_banks(manifest):
    if manifest["schema"] != "elemental-expansion-2026-10-22-v1":
        raise ValueError("This intake requires the supplied elemental expansion manifest")
    expected = {(variant, action) for variant in VARIANTS for action in ACTIONS}
    found = {}
    for bank in manifest["banks"]:
        if bank["variant"] not in VARIANTS:
            continue
        key = (bank["variant"], bank["action"])
        if key in found or key not in expected:
            raise ValueError("Duplicate or unexpected equipped body bank: " + str(key))
        if bank["frames"] != 15 or bank["directions"] != 8 or bank["fps"] != 12:
            raise ValueError("Unsupported source clock/layout: " + str(key))
        if bool(bank["loop"]) != (bank["action"] in ("Idle", "Walk")):
            raise ValueError("Source loop declaration differs from its supplied action: " + str(key))
        found[key] = bank
    if set(found) != expected:
        raise ValueError("The delivery does not contain the exact four equipped nine-action sets")
    return [found[(variant, action)] for variant in VARIANTS for action in ACTIONS]


def companions(colour, geometry, basis, lo, hi):
    valid, depth, world_normal = decode(geometry)
    if colour.shape != geometry.shape or colour.shape != (1536, 2880, 4):
        raise ValueError("Colour/geometry do not share the supplied 192px,15x8 layout")
    if not np.array_equal(valid, colour[..., 3] > 0):
        raise ValueError("Canonical code>0 coverage does not match actual colour alpha")
    if not np.isfinite(world_normal).all() or not np.isfinite(depth).all():
        raise ValueError("Non-finite canonical surface")
    optical = world_normal @ basis.T
    normal = np.zeros_like(geometry)
    normal[valid, :3] = np.rint((optical * .5 + .5) * 255).clip(0, 255).astype(np.uint8)
    normal[valid, 3] = 255
    optical_depth = 20 * (15 - depth)
    if not ((optical_depth >= lo).all() and (optical_depth <= hi).all()):
        raise ValueError("Selected depth range does not enclose canonical samples")
    # Check the real numeric result before uint8 conversion. Never allow wrap
    # or silently clamp a newly supplied deeper surface to the old range.
    encoded = np.rint(32 + 192 * (optical_depth - lo) / (hi - lo))
    if not np.isfinite(encoded).all() or not ((encoded >= 32).all() and (encoded <= 224).all()):
        raise ValueError("Affine depth would wrap or clip")
    value = encoded.astype(np.uint8)
    affine = np.zeros_like(geometry)
    affine[valid, :3] = value[:, None]
    affine[valid, 3] = 255
    support = np.zeros_like(geometry)
    support[valid] = 255
    reconstructed = lo + (value.astype(float) - 32) * (hi - lo) / 192
    error = np.abs(reconstructed - optical_depth)
    sampled_normal = normal[valid, :3].astype(float) / 255 * 2 - 1
    sampled_normal /= np.linalg.norm(sampled_normal, axis=1)[:, None]
    angular = np.rad2deg(np.arccos(np.clip((sampled_normal * optical).sum(axis=1), -1, 1)))
    return valid, depth, affine, normal, support, error, angular


def pose_coverage(valid, colour, action):
    result = []
    for row in range(8):
        for frame in range(15):
            mask = valid[row * 192:(row + 1) * 192, frame * 192:(frame + 1) * 192]
            count = int(mask.sum())
            if mask[0].any() or mask[-1].any() or mask[:, 0].any() or mask[:, -1].any():
                raise ValueError("Clipped source surface at view/frame " + str((row, frame)))
            if action != "Death" and count == 0:
                raise ValueError("Empty active source pose at view/frame " + str((row, frame)))
            result.append({"row": row, "frame": frame, "covered_pixels": count})
    return result


def idle_anchor(colour):
    # Same generic effect-anchor authoring rule as the previous four-elemental
    # intake. This never changes the supplied sprite/ground registration and
    # is not a hand/head/mouth or temporal contact measurement.
    centres = []
    for row in range(8):
        for frame in range(15):
            mask = colour[row * 192:(row + 1) * 192, frame * 192:(frame + 1) * 192, 3] > 0
            y, x = np.nonzero(mask)
            centres.append([(int(x.min()) + int(x.max()) + 1) / 2,
                            (int(y.min()) + int(y.max()) + 1) / 2])
    return np.median(np.asarray(centres), axis=0).tolist()


def adopt(source, assets, receipt):
    source = source.resolve()
    assets = assets.resolve()
    if assets.is_relative_to(source) or source.is_relative_to(assets):
        raise ValueError("Source laboratory and owned client asset destination must be disjoint")
    manifest_path = source / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    banks = selected_banks(manifest)
    if (manifest["cell"] != [192, 192] or manifest["contact"] != [96, 138]
            or manifest["pixels_per_metre"] != 20 or manifest["frames"] != 15
            or manifest["fps"] != 12
            or manifest["directions"] != ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
            or manifest["geometry"]["depth_range"] != [9, 21]):
        raise ValueError("Source registration/encoding differs from the approved compatible intake")
    camera = manifest["camera"]
    basis = np.array([camera["right"], camera["up"], camera["toward"]])
    if camera["elevation_degrees"] != 30 or not np.allclose(basis @ basis.T, np.eye(3), atol=1e-12):
        raise ValueError("Source camera basis is not the declared orthonormal30degree basis")
    if not np.allclose(camera["position"], 15 * basis[2] + 2.1 * basis[1], atol=1e-12):
        raise ValueError("Source camera/contact does not satisfy the existing optical reconstruction")
    low, high = math.inf, -math.inf
    for bank in banks:
        _, depth, _ = decode(image(source_file(source, bank["files"]["geometry"])))
        if depth.size == 0:
            raise ValueError("Empty canonical bank: " + bank["variant"] + "/" + bank["action"])
        optical = 20 * (15 - depth)
        low = min(low, float(optical.min()))
        high = max(high, float(optical.max()))
    lo, hi = math.floor(low) - 1, math.ceil(high) + 1
    result = {"source": str(source), "manifest": str(manifest_path), "source_schema": manifest["schema"],
              "selection": list(VARIANTS), "bank_count": len(banks), "pose_count": len(banks) * 120,
              "source_registration": {key: manifest[key] for key in
                                      ("cell", "contact", "directions", "frames", "fps", "pixels_per_metre", "camera", "geometry")},
              "source_actions": {key: manifest["sources"][key] for key in VARIANTS},
              "measured_optical_depth_range": [low, high], "depth_range": [lo, hi],
              "normal_profile": "original", "optical_ground_pixels": 0.0,
              "anchors": {}, "banks": [], "copied_pngs": 0, "derived_pngs": 0,
              "qualification": "Offline conversion/coverage only; no native render, gameplay, weapon VFX or art acceptance."}
    for bank in banks:
        variant, action = bank["variant"], bank["action"]
        colour_path = source_file(source, bank["files"]["color"])
        geometry_path = source_file(source, bank["files"]["geometry"])
        colour, geometry = image(colour_path), image(geometry_path)
        valid, depth, affine, normal, support, error, angular = companions(colour, geometry, basis, lo, hi)
        poses = pose_coverage(valid, colour, action)
        yy, xx = np.nonzero(valid)
        x, y = xx % 192, yy % 192
        ray = (np.array(camera["position"]) + (x[:, None] + .5 - 96) * .05 * basis[0]
               + (96 - y[:, None] - .5) * .05 * basis[1] - depth[:, None] * basis[2])
        optical = ((x[:, None] + .5 - 96) * .05 * basis[0]
                   + (138 - y[:, None] - .5) * .05 * basis[1] + (15 - depth[:, None]) * basis[2])
        position_error = float(np.max(np.linalg.norm(ray - optical, axis=1)))
        if position_error >= 1e-10:
            raise ValueError("Canonical/contact optical reconstruction changed")
        relative = Path("art/media/myrmidons") / variant / action
        destination = assets / relative
        destination.mkdir(parents=True, exist_ok=True)
        shutil.copy2(colour_path, destination / "color.png")
        if (destination / "color.png").read_bytes() != colour_path.read_bytes():
            raise ValueError("Raw colour copy differs from its selected source")
        for name, pixels in (("depth-affine", affine), ("normal-optical", normal), ("support", support)):
            Image.fromarray(pixels).save(destination / (name + ".png"), compress_level=6)
        result["copied_pngs"] += 1
        result["derived_pngs"] += 3
        if action == "Idle":
            result["anchors"][variant] = {"anchor": idle_anchor(colour), "poses": 120,
                "basis": "Median centre of actual Idle alpha bounds; generic body-effect anchor only, never sprite registration, a socket or contact."}
        result["banks"].append({"variant": variant, "action": action, "source_bank": bank,
            "source_colour": str(colour_path), "source_geometry": str(geometry_path),
            "output": relative.as_posix(), "colour_copied_verbatim": True, "coverage_exact": True,
            "poses": poses, "canonical_optical_position_max_error_metres": position_error,
            "compat_depth_max_error_source_pixels": float(error.max()),
            "compat_depth_max_error_metres": float(error.max() / 20),
            "compat_normal_max_error_degrees": float(angular.max())})
        print("MYRMIDON_BODY", variant, action, flush=True)
    result["maximum_compat_depth_error_metres"] = max(row["compat_depth_max_error_metres"] for row in result["banks"])
    result["maximum_compat_normal_error_degrees"] = max(row["compat_normal_max_error_degrees"] for row in result["banks"])
    receipt.parent.mkdir(parents=True, exist_ok=True)
    receipt.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print("MYRMIDON_INTAKE_READY", len(banks), result["copied_pngs"] + result["derived_pngs"], lo, hi, flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--assets", type=Path, default=Path(__file__).resolve().parents[1] / "assets")
    parser.add_argument("--receipt", type=Path, required=True)
    arguments = parser.parse_args()
    adopt(arguments.source, arguments.assets, arguments.receipt)
