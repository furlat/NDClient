"""Register the delivered exact modular source companions; never copy or bake artwork."""
import argparse
import json
from pathlib import Path


def reference_header(path: Path) -> dict:
    # Each reference retains tens of MB of observation evidence. Runtime needs
    # only its leading registration fields, before the top-level metrics body.
    prefix = ""
    with path.open() as source:
        while '\n  "metrics":' not in prefix:
            chunk = source.read(16384)
            if not chunk:
                raise ValueError(f"Missing reference metadata boundary: {path}")
            prefix += chunk
    return json.loads(prefix.split('\n  "metrics":', 1)[0].rstrip().removesuffix(",") + "\n}")


def optical_camera(root: Path) -> dict:
    receipt = "exports/observations/shard-2/configurations/Idle--full-r0-i26/Idle/00/observations.json"
    kernel = json.loads((root / receipt).read_text())["kernel"]
    assert kernel["elevation_degrees"] == 45.0 and kernel["origin_xy"] == [64, 96]
    assert kernel["basis"] == "fixed camera Xright/Yup/Ztoward; each row yaw=row*pi/4"
    return {"elevation_degrees": kernel["elevation_degrees"], "origin": kernel["origin_xy"],
        "physical_camera_calibrated": kernel["physical_camera_calibrated"], "receipt": receipt}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path("/mnt/c/Users/tommaso/Documents/assets/fantasy-unified-catalog/modular-character-geometry-2026-10-11/full-components"))
    parser.add_argument("--output", type=Path, default=Path(__file__).resolve().parents[1] / "generated/character_geometry.json")
    args = parser.parse_args()
    package = args.root / "exports/queue/package"
    catalog = json.loads((package / "catalog.json").read_text())
    assert catalog["queue_finished"] and catalog["planner_all_actions_verified"]
    records = {}
    for row in catalog["records"]:
        record = {key: row[key] for key in ("status", "role", "category", "source_action")}
        if row["status"] in ("validated_partial", "validated_complete"):
            reference = (package / row["output_reference"]).resolve()
            header = reference_header(reference)
            source = header["source"]
            assert source["media"] == row["media"] and source["source_sha256"] == row["source_sha256"]
            assert header["estimated_optical_only"] and not header["physical_depth_sorting_certified"]
            assert header["native_allframe_observations"] and header["source_over_authoritative"]
            assert header["processed_frames"] == list(range(15))
            assert [source["width"], source["height"], source["cell_width"], source["cell_height"]] == [1920, 1024, 128, 128]
            assert header["placement"]["origin_y_from_ground"] == 41
            assert header["placement"]["reconstruction_origin"] == [64, 96]
            files = {key: str((reference.parent / filename).relative_to(args.root)) for key, filename in (
                ("depth", "depth.png"), ("normal", "normals.png"),
                ("support", "raw-support.png"), ("normal_valid", "normal-valid.png"))}
            assert all((args.root / relative).is_file() for relative in files.values())
            record.update(files=files, depth_range=header["depth_range"], slots=source["permitted_slots"],
                reference=str(reference.relative_to(args.root)), source_sha256=source["source_sha256"])
        else:
            assert row["status"] in ("excluded_non_solid", "empty_source_no_surface")
        assert row["media"] not in records
        records[row["media"]] = record
    result = {"qualification": "estimated_visible_surface_optical", "source_catalog": "exports/queue/package/catalog.json",
        "source_count": len(records), "status_counts": catalog["status_counts"],
        "optical_camera": optical_camera(args.root), "normal_basis": catalog["normal_basis"], "facing_baked": catalog["facing_baked"], "records": records}
    args.output.write_text(json.dumps(result, separators=(",", ":")) + "\n")
    print(json.dumps({"output": str(args.output), "sources": len(records), "status_counts": catalog["status_counts"]}))


if __name__ == "__main__":
    main()
