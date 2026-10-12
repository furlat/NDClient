"""Summarize native preload/world-preparation runs without hiding loading frames."""
import argparse
import json
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

def distribution(values):
    values = sorted(values)
    if not values:
        return {}
    return {"frames": len(values), "mean_ms": sum(values) / len(values),
            "p95_ms": values[int((len(values) - 1) * .95)], "max_ms": values[-1],
            "over_33_333_ms": sum(value > 33.333 for value in values)}

def summarize(path):
    data = json.loads((ROOT / path).read_text())
    frames = data["frames"]
    traversal = [row for row in frames if row["view"]["profile_stage"].startswith("traversal")
                 or row["view"]["profile_stage"] == "playback"]
    stages = defaultdict(list)
    for row in frames:
        stages[row["view"]["profile_stage"]].append(row["frame_ms"])
    def context(row):
        view = row["view"]
        return {"frame": row["frame"], "frame_ms": row["frame_ms"], "cpu_ms": row["cpu_ms"],
                "sequence": view["displayed_sequence"], "stage": view["profile_stage"],
                "world_preparing": view.get("world_preparing"), "world_waiting": view.get("world_waiting"),
                "retiring_nodes": view.get("retiring_nodes"), "cached_quarters": view.get("cached_quarters")}
    result = {key: data[key] for key in ["gpu", "renderer", "resolution", "vsync_mode",
                                       "sample_count", "recording_total", "recording_evicted"]}
    result.update({"path": path, "stages": {key: distribution(value) for key, value in stages.items()},
                   "traversal_including_loading": distribution([row["frame_ms"] for row in traversal]),
                   "slowest_traversal": [context(row) for row in sorted(traversal, key=lambda row: row["frame_ms"], reverse=True)[:10]],
                   "matched_sequence_maxima": {str(seq): context(max(rows, key=lambda row: row["frame_ms"]))
                      for seq in [40, 77, 98] if (rows := [row for row in traversal if row["view"]["displayed_sequence"] == seq])},
                   "final_media": {key: frames[-1]["view"].get(key) for key in ["encounter_preload", "character_media", "environment_media"]}})
    if any("preload_ready" in row["view"] for row in traversal):
        boot = [row for row in frames if row["view"].get("preload_ready", False)]
        result["startup_preload_complete_ms_from_profile_start"] = boot[0]["time_ms"] if boot else None
        result["traversal_after_startup_preload"] = distribution([row["frame_ms"] for row in traversal if row["view"].get("preload_ready", False)])
        result["world_waiting_intervals_ms"] = sum(row["frame_ms"] for row in traversal if row["view"].get("world_waiting", False))
        result["prepared_worlds"] = frames[-1]["view"].get("world_prepared_count")
    phases = defaultdict(list)
    for row in traversal:
        for name, value in row["cpu_ms"].items():
            if value > 0:
                phases[name].append(value)
    result["nonzero_inclusive_cpu_phases"] = {name: distribution(values) for name, values in phases.items()}
    result["active_retirement_intervals_ms"] = sum(row["frame_ms"] for row in traversal if row["view"].get("retiring_nodes", 0) > 0)
    return result

def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("--crypt", required=True)
    parser.add_argument("--gallery", required=True)
    args = parser.parse_args()
    paths = {"crypt_after": args.crypt, "gallery_after": args.gallery,
             "crypt_before": "generated/profiles/2026-10-12T16-52-23-crypt-order-native.json",
             "gallery_before": "generated/profiles/2026-10-12T16-53-45-gallery-order-native.json"}
    result = {"profiles": {key: summarize(path) for key, path in paths.items()},
              "notes": ["Whole traversal retains loading/preparation frames. Post-startup statistics are separate, not a replacement.",
                        "Same recorded commands and final states; asynchronous idle gaps and sampling trajectories differ. OS caches were not flushed.",
                        "Inclusive CPU phases overlap. View context is sampled at interval end; GPU timing can lag.",
                        "Native Windows RTX5090 Compatibility, 1440x900, VSync off. User-owned lighting demo was not stopped.",
                        "Media byte counts combine decoded CPU bytes and conservative GPU estimates, not measured VRAM residency."]}
    path = ROOT / "generated/async_preparation_profiles.json"
    path.write_text(json.dumps(result, indent=2) + "\n")
    for name, value in result["profiles"].items():
        print(name, json.dumps({key: value[key] for key in ["traversal_including_loading", "traversal_after_startup_preload", "startup_preload_complete_ms_from_profile_start"] if key in value}))
    print(path)

if __name__ == "__main__":
    main()
