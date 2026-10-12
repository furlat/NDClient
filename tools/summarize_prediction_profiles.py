"""Compare the bounded-prediction/media-selection build to its previous Gallery run."""
import argparse
import json
from summarize_preparation_profiles import ROOT, distribution, summarize


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("--gallery", required=True)
    parser.add_argument("--live-result", required=True)
    args = parser.parse_args()
    before = "generated/profiles/2026-10-12T18-03-27-gallery-prepared-final.json"
    current = summarize(args.gallery)
    raw = json.loads((ROOT / args.gallery).read_text())
    prediction = [row["cpu_ms"].get("prediction", 0) for row in raw["frames"]]
    live = json.loads((ROOT / args.live_result).read_text())
    report = {
        "before": summarize(before), "after": current,
        "prediction_idle_cpu_ms": distribution(prediction),
        "live": {"result": args.live_result, "checks": live["checks"], "failures": live["failures"],
                 "evidence": live["evidence"]["prediction"]},
        "media_family_cpu_before": json.loads((ROOT / "generated/media_family_cpu_before.json").read_text()),
        "media_family_cpu_after": json.loads((ROOT / "generated/media_family_cpu_after.json").read_text()),
        "notes": [
            "Same full Gallery recording, source assets, four quarters/two zooms and midroute cache invalidation; canonical completion is separately asserted by scale_profile.gd.",
            "Native Windows RTX5090 Compatibility 1440x900, VSync off, offscreen/unfocusable profile window; other user applications/lighting demo were not stopped and OS caches were not flushed.",
            "Frame intervals include asynchronous preparation and loading. Post-preload results are additional context. Sampling/idle gaps differ between runs.",
            "Replay has no unconfirmed commands: prediction CPU phase here measures its idle path. Real delayed-command movement/jump/rotation evidence is separate.",
            "Family probe is CPU-only source selection over modeled residency, not GPU/frame speedup. Inclusive CPU phases overlap; media estimates are not measured VRAM.",
            "No claim that all frame spikes are fixed or that arbitrary server actions reconcile within 1–2 frames."
        ]
    }
    destination = ROOT / "generated/prediction_profiles.json"
    destination.write_text(json.dumps(report, indent=2) + "\n")
    for name in ["before", "after"]:
        print(name, json.dumps({key: report[name][key] for key in ["traversal_including_loading", "traversal_after_startup_preload", "startup_preload_complete_ms_from_profile_start"]}))
    print("idle_prediction", json.dumps(report["prediction_idle_cpu_ms"]))
    print(destination)


if __name__ == "__main__":
    main()
