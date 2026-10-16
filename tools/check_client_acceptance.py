"""Run the bounded headless preparation/publication baseline, rejecting runtime errors.

Pass an explicit canonical --state and one or more --recording journals to include
the media/UI fixtures. This lane does not qualify native pixels or replay admission.
"""
import argparse
from collections import Counter
import json
from pathlib import Path
import re
import subprocess
import time
from uuid import uuid4


TESTS = (
    "component_trace_checks", "action_completion_checks", "prepared_admission_checks",
    "audio_contact_checks", "audio_presenter_checks", "media_handoff_checks",
    "settings_checks", "studio_recording_media_checks", "media_shared_residency_checks",
)
SCRIPT_ERROR = re.compile(r"^SCRIPT ERROR:", re.MULTILINE)
ENGINE_ERROR = re.compile(r"^ERROR:", re.MULTILINE)
WARNING = re.compile(r"^WARNING:", re.MULTILINE)


def local_path(value, project):
    if value.startswith("res://"):
        return project / value.removeprefix("res://")
    return Path(value).resolve()


def native_path(path):
    return subprocess.check_output(["wslpath", "-w", str(path)], text=True).strip()


def stop_owned(marker):
    # WSL's terminated bridge can leave its native Windows child alive.
    subprocess.run(["powershell.exe", "-NoProfile", "-NonInteractive", "-Command",
        "$owned = Get-CimInstance Win32_Process | Where-Object { "
        "$_.Name -like 'Godot*.exe' -and $_.CommandLine -and "
        f"$_.CommandLine.Contains('{marker}') }}; "
        "$owned | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }"],
        check=True, capture_output=True, timeout=20)


def result_from(output, code):
    summary = None
    for line in output.splitlines():
        start = line.find("{")
        if start < 0:
            continue
        try:
            value = json.loads(line[start:])
        except json.JSONDecodeError:
            continue
        if isinstance(value, dict) and "checks" in value and "failures" in value:
            summary = value
    script_errors = SCRIPT_ERROR.findall(output)
    engine_errors = ENGINE_ERROR.findall(output)
    warnings = WARNING.findall(output)
    if "Parse Error:" in output:
        status = "parse_error"
    elif script_errors:
        status = "runtime_error"
    elif engine_errors:
        status = "engine_error"
    elif summary is not None and summary["failures"]:
        status = "assertion_failure"
    elif code != 0:status = "failed"
    elif summary is None or not summary["checks"]:
        status = "missing_report"
    elif warnings:
        status = "exit_warning"
    else:
        status = "passed"
    return {"status": status, "exit_code": code, "checks": summary["checks"] if summary else None,
        "failures": summary["failures"] if summary else [], "runtime_errors": len(script_errors),
        "engine_errors": len(engine_errors),
        "warnings": len(warnings), "unqualified": summary.get("unqualified", []) if summary else []}


def main():
    project = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, default=project.parent / "Tools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe")
    parser.add_argument("--state", help="Recorded canonical state.json for media handoff and settings")
    parser.add_argument("--recording", action="append", default=[], help="Admitted journal directory for Studio metadata; repeatable")
    parser.add_argument("--test", action="append", choices=TESTS, help="Run only named entries")
    parser.add_argument("--timeout", type=float, default=60, help="Maximum seconds per test")
    parser.add_argument("--output-dir", type=Path, default=project / ".runtime/client-acceptance")
    args = parser.parse_args()
    if args.timeout <= 0:
        parser.error("--timeout must be positive")
    args.output_dir.mkdir(parents=True, exist_ok=True)
    results = []
    for name in args.test or TESTS:
        inputs = []
        missing = []
        requested = []
        if name in ("media_handoff_checks", "settings_checks"):
            requested = [("state", args.state)]
        elif name in ("audio_presenter_checks", "studio_recording_media_checks"):
            recordings = args.recording[:1] if name == "audio_presenter_checks" else args.recording
            requested = [("recording", value) for value in recordings] or [("recording", None)]
        for kind, value in requested:
            if not value:
                missing.append("--" + kind + " is required")
                continue
            path = local_path(value, project)
            exists = path.is_dir() if kind == "recording" else path.is_file()
            if not exists:
                missing.append(str(path))
            else:
                inputs.append("--" + kind + "=" + native_path(path))
        if missing:
            row = {"test": name, "status": "skipped_prerequisite", "missing": missing}
        else:
            started = time.monotonic()
            marker = "client-acceptance-" + uuid4().hex
            command = [str(args.godot), "--headless", "--path", native_path(project),
                "--script", f"res://tests/{name}.gd", "--", *inputs, "--runner-id", marker]
            try:
                process = subprocess.run(command, capture_output=True, text=True, timeout=args.timeout)
                output = process.stdout + process.stderr
                row = {"test": name, **result_from(output, process.returncode)}
            except subprocess.TimeoutExpired as error:
                stop_owned(marker)
                output = "".join(part.decode(errors="replace") if isinstance(part, bytes) else part or ""
                    for part in (error.stdout, error.stderr))
                row = {"test": name, "status": "timeout", "timeout_seconds": args.timeout}
            path = args.output_dir / (name + ".log")
            path.write_text(output)
            row.update(seconds=round(time.monotonic() - started, 3), log=str(path), inputs=inputs)
        results.append(row)
        print(json.dumps(row), flush=True)
    report = {"passed": all(row["status"] == "passed" for row in results),
        "scope": "Selected headless ownership, metadata, audio and Control boundaries; no native pixel, real Studio replay admission or live latency qualification.",
        "counts": dict(Counter(row["status"] for row in results)), "tests": results}
    (args.output_dir / "summary.json").write_text(json.dumps(report, indent=2) + "\n")
    raise SystemExit(0 if report["passed"] else 1)


if __name__ == "__main__":
    main()
