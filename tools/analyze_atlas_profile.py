"""Summarize atlas CPU publication and steady frames from the real Gallery lane.

Run after tools/play.py --profile-pipeline --test-script
res://tests/live_gallery_checks.gd. Raw profiles and encounters remain private.
"""
import argparse
import json
from collections import defaultdict
from pathlib import Path


def distribution(values):
    values = sorted(values)
    if not values:
        return {}
    return {"count": len(values), "mean": sum(values) / len(values),
            "p50": values[int((len(values) - 1) * .5)],
            "p95": values[int((len(values) - 1) * .95)],
            "p99": values[int((len(values) - 1) * .99)], "max": values[-1]}


def summarize(frames):
    result = {"frames": len(frames), "frame_ms": distribution([f["frame_ms"] for f in frames]),
              "frames_over_16_667_ms": sum(f["frame_ms"] > 16.667 for f in frames),
              "frames_over_33_333_ms": sum(f["frame_ms"] > 33.333 for f in frames)}
    for name in ("player_process", "native_2d_atlas", "native_2d_lighting", "modular_shadows", "world_sync", "scenery_sync", "hud_process"):
        result[name] = distribution([f["cpu_ms"].get(name, 0) for f in frames])
    for name in ("native_2d_reconcile_ms", "native_2d_projection_ms", "native_2d_gpu_ms"):
        result[name] = distribution([f["view"].get(name, 0) for f in frames])
    result["main_gpu_ms"] = distribution([f["gpu_ms"] for f in frames])
    phases = sorted({k for f in frames for k in f["view"].get("native_2d_reconcile_phases", {})})
    result["atlas_phases"] = {k: distribution([f["view"]["native_2d_reconcile_phases"][k] for f in frames
                                             if isinstance(f["view"].get("native_2d_reconcile_phases", {}).get(k), (float, int))])
                               for k in phases if k != "layout_mode"}
    return result


def report(run):
    acceptance = json.loads((run / "player-live-checks.json").read_text())
    profile = Path(acceptance["evidence"]["full_profile"].replace("C:/", "/mnt/c/"))
    data = json.loads(profile.read_text())
    commands = json.loads((run / "live-command-trace.json").read_text())
    movement = {f"command_{c['number']}_{c['behavior']}" for c in commands
                if c["stage"] >= 8 and c["behavior"] == "action.move"}
    frames = data["frames"]
    gallery = [f for f in frames if f["view"]["profile_stage"] in movement]
    publication = [f for f in gallery if "native_2d_atlas" in f["cpu_ms"] and "specs_ms" in f["view"]["native_2d_reconcile_phases"]]
    stable = [f for f in gallery if f["view"]["native_2d_reconcile_ms"] < .1]
    active = [f for f in gallery if f["view"].get("active_motion", False) and not f["view"].get("motion_held", False)]
    held = [f for f in gallery if f["view"].get("motion_held", False)]
    by_zoom = {str(zoom): summarize([f for f in active if f["view"]["zoom"] == zoom]) for zoom in sorted({f["view"]["zoom"] for f in active})}
    idle = defaultdict(list)
    for f in frames:
        label = f["view"]["profile_stage"]
        if label.startswith("gallery_idle_"):
            idle[label].append(f)
    return {"run": run.name, "checks": acceptance["checks"], "failures": acceptance["failures"],
            "commands": len(commands), "gallery_viewport_moves": sum(c["stage"] >= 8 and c["behavior"] == "action.move" and c["input"] == "viewport_click" for c in commands),
            "tiles": acceptance["evidence"]["disclosed_tiles"], "objects": acceptance["evidence"]["disclosed_objects"],
            "renderer": data["renderer"], "gpu": data["gpu"], "resolution": data["resolution"],
            "recording_evicted": data["recording_evicted"],
            "gallery_move_commands": summarize(gallery), "gallery_publications": summarize(publication),
            "gallery_reconcile_below_0_1ms": summarize(stable),
            "gallery_active_motion": summarize(active), "active_motion_by_zoom": by_zoom,
            "gallery_presentation_held": summarize(held),
            "presentation_held_total_ms": sum(f["frame_ms"] for f in held),
            "atlas_reference": acceptance["evidence"].get("atlas_reference", ""),
            "movement_markers_present": all("active_motion" in f["view"] for f in gallery),
            "cap_on_frames": sum(f["view"].get("light_cap_enabled", False) for f in gallery),
            "zoom_frames": {str(z): sum(f["view"]["zoom"] == z for f in gallery) for z in sorted({f["view"]["zoom"] for f in gallery})},
            "idle": {k: summarize(v) for k, v in idle.items()},
            "notes": ["Move-command cohorts include server/choices waits as well as animation. Publication subset isolates actual scene-reconcile frames during these commands.",
                      "Active-motion cohort uses displayed motion tracks and excludes held/paused frames; it does not infer movement from command waits. Missing markers yield no active-motion cohort.",
                      "Idle controls have no pending action; 30 settling frames per view/mode are excluded.",
                      "CPU phases are inclusive and must not be added to parents. GPU timings are last available viewport values, not end-to-end frame measurements.",
                      "Both comparison runs must use the same cap and zoom route. Concurrent backend/user activity may change end-to-end timing."]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("run", type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    result = report(args.run)
    args.output.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({k: result[k] for k in ("run", "checks", "failures", "commands", "gallery_viewport_moves")}))


if __name__ == "__main__":
    main()
