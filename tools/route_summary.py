"""Summarize live Gallery routes: holds, onset, idle frames and every spike.

Usage: python3 tools/route_summary.py RUN_DIR [RUN_DIR ...] [--json OUT]

Each run directory is a `.runtime/player-runs/<stamp>` produced by
`tools/play.py --scenario gallery_sorcerer --test-script
res://tests/live_spell_checks.gd --live-fireball-ui --profile-pipeline`.
Per run it reuses analyze_live_pipeline.summarize() for actions and adds
frame classes and spike attribution from the recorded frame profile. With
several runs it also prints medians, because single live runs are noisy.
"""
import argparse
import json
from pathlib import Path
from statistics import median
import sys

sys.path.insert(0, str(Path(__file__).parent))
import analyze_live_pipeline as live  # noqa: E402

SPIKE_MS = 1000.0/60.0
# Disjoint Player-script parents in play.gd._process order. Nested phases are
# children of these and are listed separately as detail, never added again.
PARENTS = ["session_timeline", "world_sync", "source_lighting_resolve", "displayed_samples",
    "actor_sync", "actor_sample", "source_lighting", "rotation_publish", "native_2d_lighting",
    "draw_order", "interaction", "optional_preparation", "diagnostics"]
# Children worth naming when a parent dominates a spike.
CHILDREN = {
    "session_timeline": ["preparation_step", "media_publication", "timeline_advance", "timeline_media_ready",
        "timeline_world_ready", "world_prepare_native", "media_plan", "media_plan_demand", "selection_media",
        "action_responses", "session_poll"],
    "native_2d_lighting": ["native_2d_atlas", "modular_shadows", "native_2d_projection"],
    "draw_order": ["draw_sort", "ground_overlay_sync", "ground_overlay_mark_update", "static_order",
        "actor_order", "draw_rank_apply", "native_2d_output", "mask_sync"],
    "actor_sample": ["actor_decorate", "actor_sprite_sample", "component_sample", "native_spell_sample", "blood_sample"],
    "optional_preparation": ["media_optional_maintenance", "media_release_cpu", "view_retirement",
        "component_prepare", "hud_bar_build"],
    "world_sync": ["world_rows", "world_objects", "world_ground", "world_order_publish", "world_atlas_publish",
        "world_membership_publish", "world_scenery_membership", "world_finish_publish"],
}


def frame_class(frame):
    view = frame["view"]
    if view.get("world_waiting"):
        return "held_world"
    if view.get("media_waiting"):
        return "held_media"
    if view.get("active_motion"):
        return "animating"
    if view.get("queued_groups", 1) == 0 and not view.get("world_preparing") and view.get("actors", 0) > 0:
        return "idle"
    return "other"


def pipeline_delta(previous, frame):
    if previous is None:
        return {}
    a = previous.get("pipeline_compilations", {})
    b = frame.get("pipeline_compilations", {})
    return {key: b.get(key, 0)-a.get(key, 0) for key in b if b.get(key, 0)-a.get(key, 0)}


def attribute(frame, previous):
    cpu = frame["cpu_ms"]
    player = cpu.get("player_process", 0.0)
    parents = {name: round(cpu[name], 3) for name in PARENTS if cpu.get(name, 0.0) >= 0.05}
    remainder = player-sum(parents.values())
    dominant = max(parents, key=parents.get) if parents else None
    detail = {}
    for name in sorted(parents, key=parents.get, reverse=True)[:3]:
        for child in CHILDREN.get(name, []):
            if cpu.get(child, 0.0) >= 0.5:
                detail[child] = round(cpu[child], 3)
    view = frame["view"]
    return {
        "frame": frame["frame"], "interval_ms": round(frame["frame_ms"], 3), "player_ms": round(player, 3),
        "outside_player_ms": round(frame["frame_ms"]-player, 3), "hud_ms": round(cpu.get("hud_process", 0.0), 3),
        "render_cpu_ms": round(frame.get("render_cpu_ms", 0.0), 3), "gpu_ms": round(frame.get("gpu_ms", 0.0), 3),
        "pipelines": pipeline_delta(previous, frame), "class": frame_class(frame),
        "stage": view.get("profile_stage"), "world_phase": view.get("world_prepare_phase"),
        "parents": parents, "player_remainder_ms": round(remainder, 3), "dominant": dominant, "children": detail,
    }


def distribution(values):
    return live.distribution(values) or {}


def summarize_run(directory):
    directory = Path(directory)
    # Profiles are ~100 MB; load each once and let it go before the next run.
    frames = live.recorded_frames(directory)
    loader = live.recorded_frames
    live.recorded_frames = lambda _directory: frames
    try:
        summary = live.summarize(directory)
    finally:
        live.recorded_frames = loader
    classes = {}
    for frame in frames:
        classes.setdefault(frame_class(frame), []).append(frame)
    class_rows = {}
    for name, rows in classes.items():
        class_rows[name] = {"count": len(rows),
            "frame_ms": distribution([f["frame_ms"] for f in rows]),
            "player_ms": distribution([f["cpu_ms"].get("player_process", 0) for f in rows])}
    idle_phases = {}
    for frame in classes.get("idle", []):
        for name, value in frame["cpu_ms"].items():
            idle_phases.setdefault(name, []).append(value)
    idle_count = len(classes.get("idle", []))
    idle_phase_medians = {name: round(median(values+[0.0]*(idle_count-len(values))), 3)
        for name, values in idle_phases.items()} if idle_count else {}
    spikes = []
    previous = None
    for frame in frames:
        stage = frame["view"].get("profile_stage") or ""
        # Startup/preload frames are a separate concern from the play route.
        if frame["frame_ms"] > SPIKE_MS and stage not in ("initialization", ""):
            spikes.append(attribute(frame, previous))
        previous = frame
    actions = []
    for command in summary["commands"]:
        waits = command.get("rendering", {}).get("observed_wait_ms", {})
        render = command.get("rendering", {})
        actions.append({
            "number": command["number"], "behavior": command["behavior"].split(".")[-1],
            "packet_to_animation_ms": command.get("client_packet_to_first_animation_ms"),
            "media_hold_ms": waits.get("media_wait"), "world_hold_ms": waits.get("world_wait"),
            "post_onset_max_ms": (render.get("post_onset_frames") or {}).get("frame_ms", {}).get("max"),
            "command_frame_p95_ms": (render.get("all_command_frames") or {}).get("frame_ms", {}).get("p95"),
        })
    return {"run": str(directory), "actions": actions, "idle_same_view": summary["idle_same_view"],
        "classes": class_rows, "idle_phase_medians": idle_phase_medians, "spikes": spikes}


def print_run(result):
    print("\n== %s" % result["run"])
    print("%-4s %-16s %9s %9s %9s %9s %9s" % ("#", "action", "pkt>anim", "media", "world", "postmax", "cmd p95"))
    for a in result["actions"]:
        print("%-4s %-16s %9s %9s %9s %9s %9s" % (a["number"], a["behavior"][:16], *[
            "-" if a[k] is None else "%.1f" % a[k] for k in
            ("packet_to_animation_ms", "media_hold_ms", "world_hold_ms", "post_onset_max_ms", "command_frame_p95_ms")]))
    idle = result["idle_same_view"]
    if idle.get("frame_ms"):
        print("idle same-view: n=%d frame p50 %.2f p95 %.2f | player p50 %.2f" % (
            idle["frame_ms"]["count"], idle["frame_ms"]["p50"], idle["frame_ms"]["p95"], idle["player_cpu_ms"]["p50"]))
    for name, row in sorted(result["classes"].items()):
        if row["frame_ms"]:
            print("class %-11s n=%5d frame p50 %6.2f p95 %6.2f | player p50 %6.2f" % (
                name, row["count"], row["frame_ms"]["p50"], row["frame_ms"]["p95"], row["player_ms"]["p50"]))
    top = sorted(((v, k) for k, v in result["idle_phase_medians"].items() if k in PARENTS or k == "player_process"), reverse=True)
    print("idle parents (median): " + ", ".join("%s %.2f" % (k, v) for v, k in top))
    print("spikes > %.1f ms: %d" % (SPIKE_MS, len(result["spikes"])))
    for s in sorted(result["spikes"], key=lambda s: -s["interval_ms"])[:12]:
        print("  f%-6d %6.1f ms [%s/%s] player %.1f outside %.1f dominant=%s %s %s%s" % (
            s["frame"], s["interval_ms"], s["class"], s["stage"], s["player_ms"], s["outside_player_ms"],
            s["dominant"], json.dumps(s["parents"]), json.dumps(s["children"]),
            (" pipelines=" + json.dumps(s["pipelines"])) if s["pipelines"] else ""))


def print_medians(results):
    print("\n== median of %d runs" % len(results))
    behaviors = [a["behavior"] for a in results[0]["actions"]]
    for index, behavior in enumerate(behaviors):
        def med(key):
            values = [r["actions"][index][key] for r in results if index < len(r["actions"]) and r["actions"][index][key] is not None]
            return "%.1f" % median(values) if values else "-"
        print("%-16s pkt>anim %7s media %7s world %7s postmax %7s" % (
            behavior[:16], med("packet_to_animation_ms"), med("media_hold_ms"), med("world_hold_ms"), med("post_onset_max_ms")))
    idle = [r["idle_same_view"]["frame_ms"]["p50"] for r in results if r["idle_same_view"].get("frame_ms")]
    idle95 = [r["idle_same_view"]["frame_ms"]["p95"] for r in results if r["idle_same_view"].get("frame_ms")]
    player = [r["idle_same_view"]["player_cpu_ms"]["p50"] for r in results if r["idle_same_view"].get("player_cpu_ms")]
    if idle:
        print("idle same-view frame p50 %.2f p95 %.2f player p50 %.2f" % (median(idle), median(idle95), median(player)))
    print("spike counts per run: %s" % [len(r["spikes"]) for r in results])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("runs", nargs="+")
    parser.add_argument("--json")
    args = parser.parse_args()
    results = [summarize_run(run) for run in args.runs]
    for result in results:
        print_run(result)
    if len(results) > 1:
        print_medians(results)
    if args.json:
        Path(args.json).write_text(json.dumps(results, indent=1))


if __name__ == "__main__":
    main()
