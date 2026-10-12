"""Index the completed normal treatment delivery without copying source images."""
import argparse
import json
import struct
from pathlib import Path


def require(condition, message):
    if not condition:
        raise ValueError(message)


def intake(client, delivery):
    manifest = json.loads((delivery / "analysis/normal-library-manifest.json").read_text())
    validation = json.loads((delivery / "analysis/normal-library-validation.json").read_text())
    geometry = json.loads((client / "generated/character_geometry.json").read_text())
    require(manifest["delivery_complete"] and validation["passed"]
            and validation["complete_library_checked"] and not validation["failures"],
            "Normal delivery is incomplete or has validation failures")
    require(validation["saved_outputs_reloaded_and_exact_recipe_checked"]
            and validation["normal_alpha_preserved"] and validation["all_unadmitted_rgba_bytes_preserved"],
            "Delivery does not preserve the required original byte contract")
    records, excluded, outputs = {}, {}, set()
    saved_bytes = 0
    for row in manifest["records"]:
        identity = row["media"]
        source = geometry["records"].get(identity)
        require(source is not None, f"Missing original geometry index identity: {identity}")
        require(identity not in records and identity not in excluded, f"Duplicate source: {identity}")
        if row["treatment_status"] != "eligible":
            require(not source.get("files") and not row["variants"], f"Excluded source has normal output: {identity}")
            excluded[identity] = row["source_status"]
            continue
        require(source["files"] == row["original_geometry"]
                and source["depth_range"] == row["depth_range"]
                and source["source_sha256"] == row["source_sha256_provenance"],
                f"Delivery disagrees with original registration: {identity}")
        require(row["native_layout"] == {"width": 1920, "height": 1024, "cell_width": 128,
                "cell_height": 128, "columns": 15, "rows": 8}, f"Changed frame registration: {identity}")
        variants = {"original": source["files"]["normal"]}
        for profile in ["gentle", "reference"]:
            relative = row["variants"][profile]
            require(not Path(relative).is_absolute() and ".." not in Path(relative).parts,
                    f"Invalid profile path: {relative}")
            require(relative not in outputs, f"Duplicate profile output: {relative}")
            outputs.add(relative)
            path = delivery / ".derived/normals" / relative
            with path.open("rb") as stream:
                header = stream.read(26)
            require(header[:8] == b"\x89PNG\r\n\x1a\n" and header[12:16] == b"IHDR"
                    and struct.unpack(">II", header[16:24]) == (1920, 1024)
                    and header[24:26] == bytes([8, 6]), f"Unexpected profile PNG encoding: {path}")
            saved_bytes += path.stat().st_size
            variants[profile] = relative
        records[identity] = variants
    require(len(records) == manifest["eligible_sheet_count"] == validation["checked_sheet_count"], "Eligible count mismatch")
    require(len(records) + len(excluded) == geometry["source_count"] == manifest["source_record_count"], "Original source count mismatch")
    index = {"format": "ndclient-normal-profiles-v1", "profiles": ["original", "gentle", "reference"],
             "source": "NDCharacterLight/analysis/normal-library-manifest.json",
             "records": records, "excluded": excluded}
    (client / "generated/normal_profiles.json").write_text(json.dumps(index, separators=(",", ":")) + "\n")
    report = {"eligible_sources": len(records), "excluded_sources": len(excluded), "profile_pngs": len(outputs),
              "profile_disk_bytes": saved_bytes, "registration_matches": True, "header_checks_passed": True,
              "source_art_writes": 0, "profile_art_copies": 0,
              "pixel_validation": "Existing complete-library delivery report; intake checks identities, registration and every saved PNG header, not a second full pixel recomputation."}
    (client / "generated/normal_profiles_intake.json").write_text(json.dumps(report, indent=2) + "\n")
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--delivery", type=Path, required=True)
    parser.add_argument("--client", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    print(json.dumps(intake(args.client, args.delivery)))
