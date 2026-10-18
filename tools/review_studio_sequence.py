"""Capture real Studio recordings and reuse the Factory's sequence packager.

This does not record server commands, import artwork or alter the user's Studio.
Times supplied on the command line are seconds on the published Studio clock.
"""
from __future__ import annotations

import argparse
import html
import importlib.util
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time
from types import ModuleType

PROJECT = Path(__file__).resolve().parents[1]
OBSERVER = "res://tools/capture_studio_sequence.gd"


def local_path(value: str) -> Path:
    if value.startswith("res://"):
        return (PROJECT / value[6:]).resolve()
    if re.match(r"^[A-Za-z]:[\\/]", value) and os.name != "nt":
        value = subprocess.check_output(["wslpath", "-u", value], text=True).strip()
    return Path(value).expanduser().resolve()


def resource_path(path: Path) -> str:
    return "res://" + path.resolve().relative_to(PROJECT).as_posix()


def native_path(path: Path, windows: bool) -> str:
    if windows and os.name != "nt":
        return subprocess.check_output(["wslpath", "-w", str(path.resolve())], text=True).strip()
    return str(path.resolve())


def seconds(value: str) -> float:
    number = float(value)
    if not math.isfinite(number) or number < 0:
        raise argparse.ArgumentTypeError("Time must be a finite, nonnegative number of seconds")
    return number


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__)
    source = result.add_mutually_exclusive_group(required=True)
    source.add_argument("--recording", help="Existing SDK journal directory, local path or res:// path")
    source.add_argument("--spells", nargs="+", help="Spell IDs from generated/studio_spell_case_inventory.json, or all")
    result.add_argument("--godot", default=os.environ.get("GODOT"), required=not os.environ.get("GODOT"), help="Official Godot executable; alternatively set GODOT")
    result.add_argument("--factory", default=os.environ.get("VFXFACTORY_ROOT", str(PROJECT.parents[1] / "assets/VFXFactory")), help="Factory checkout containing tools/native_authoring/review_sequence.py")
    result.add_argument("--perspective", choices=("amber", "blue"), default="amber")
    result.add_argument("--camera", type=int, choices=range(4), default=0)
    result.add_argument("--review-fps", type=int, choices=range(1, 31), default=12)
    result.add_argument("--start", type=seconds, help="First displayed second; default is the recording start")
    result.add_argument("--end", type=seconds, help="Last displayed second; default is the actual presentation end")
    result.add_argument("--at", type=seconds, help="Capture one settled still; no ffmpeg or Pillow required")
    result.add_argument("--row", help="Exact Studio row ID for observer selection/range following")
    result.add_argument("--follow-actor", help="Recorded actor UUID to follow with the ordinary Studio camera")
    result.add_argument("--view-size", type=seconds, default=12, help="Orthographic Studio camera size (default12)")
    result.add_argument("--output", required=True, help="Fresh local folder inside this client checkout")
    result.add_argument("--retain-frames", action="store_true")
    result.add_argument("--timeout", type=seconds, default=1800, help="Owned Godot capture timeout in wall seconds (default1800)")
    return result


def make_cases(args: argparse.Namespace) -> list[dict]:
    common = {"perspective": args.perspective, "camera": args.camera, "view_size": args.view_size}
    if args.follow_actor:
        common["follow_actor"] = args.follow_actor
    for option in ("start", "end", "at"):
        if getattr(args, option) is not None:
            common[option + "_ms"] = getattr(args, option) * 1000.0
    if args.row:
        common["row_id"] = args.row
    if args.recording:
        journal = local_path(args.recording)
        if not journal.is_dir() or not (journal / "0000000000000000.json").is_file():
            raise ValueError("--recording must name an existing SDK journal directory with initialization packet0000000000000000.json")
        return [{"id": "recording", "recording": resource_path(journal) if journal.is_relative_to(PROJECT) else str(journal), **common}]
    inventory = json.loads((PROJECT / "generated/studio_spell_case_inventory.json").read_text())
    if inventory.get("failures"):
        raise ValueError("The generated spell inventory contains capture failures; inspect it before reviewing")
    # A spell's first case keeps its spell ID; further recordings of the same
    # spell (e.g. native-spell-shield-ranged) are selected by their case suffix.
    by_id = {}
    for case in inventory["cases"]:
        by_id.setdefault(case["spell_id"], case)
        by_id.setdefault(case["id"].removeprefix("native-spell-"), case)
    selected = list(by_id) if args.spells == ["all"] else args.spells
    if "all" in selected or len(set(selected)) != len(selected):
        raise ValueError("Use --spells all alone, or a list of distinct spell IDs")
    cases = []
    for spell in selected:
        if spell not in by_id:
            raise ValueError(f"No recorded migrated spell {spell!r}; available: {', '.join(by_id)}")
        case = by_id[spell]
        if not re.fullmatch(r"[A-Za-z0-9_-]+", spell):
            raise ValueError(f"Unsafe recording case ID: {spell!r}")
        viewpoint = next((view for view in case["perspectives"] if view["id"] == args.perspective), None)
        if viewpoint is None:
            raise ValueError(f"{spell} has no recorded {args.perspective} perspective")
        journal = local_path(viewpoint["journal"])
        if not (journal / "0000000000000000.json").is_file():
            raise ValueError(f"Recording is unavailable: {journal}")
        cases.append({"id": spell, "recording": viewpoint["journal"], "descriptor": case["descriptor"], **common})
    return cases


def factory_packager(factory: Path) -> ModuleType:
    path = factory / "tools/native_authoring/review_sequence.py"
    if not path.is_file():
        raise ValueError(f"Factory packager missing: {path}")
    if shutil.which("ffmpeg") is None:
        raise ValueError("Sequence packaging needs ffmpeg on PATH; --at still capture does not")
    spec = importlib.util.spec_from_file_location("factory_sequence_review", path)
    module = importlib.util.module_from_spec(spec)
    try:
        spec.loader.exec_module(module)
    except ModuleNotFoundError as error:
        raise ValueError(f"Factory packaging dependency unavailable: {error}. Run with the existing Factory export Python environment.") from error
    if not callable(module.package) or not callable(module.contact_moments):
        raise ValueError("Factory packager lacks its documented package/contact_moments API")
    return module


def stop_owned(process: subprocess.Popen, executable: Path, job: str) -> None:
    if process.poll() is not None:
        return
    if executable.suffix.lower() == ".exe" and os.name != "nt":
        # WSL's process is an interop bridge. Match this executable AND this
        # fresh job token; killing the bridge alone can leave Windows Godot open.
        exe = native_path(executable, True).replace("'", "''")
        token = ("--sequence-review=" + job).replace("'", "''")
        script = (
            "$ErrorActionPreference='Stop'; "
            "$owned=@(Get-CimInstance Win32_Process | Where-Object { "
            f"$_.ExecutablePath -eq '{exe}' -and $_.CommandLine -and $_.CommandLine.Contains('{token}') }}); "
            "foreach($entry in $owned){Stop-Process -Id $entry.ProcessId -Force -ErrorAction SilentlyContinue}"
        )
        subprocess.run(["powershell.exe", "-NoProfile", "-NonInteractive", "-Command", script], check=True, timeout=15)
    else:
        process.terminate()
    try:
        process.wait(timeout=10)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait(timeout=10)


def package_case(folder: Path, packager: ModuleType | None, retain: bool) -> dict:
    row = json.loads((folder / "sequence.json").read_text())
    frames = row.get("frames", [])
    if not frames:
        raise ValueError(f"No rendered frames in {folder / 'sequence.json'}")
    for frame in frames:
        path = folder / frame["file"]
        if path.parent != folder or not path.is_file():
            raise ValueError(f"Missing or nonlocal captured frame: {path}")
    # Factory's eight-panel heuristic requires a span. A one-frame request is a
    # still, even when a zero-length sequence range produced it.
    if packager is not None and len(frames) > 1:
        failed = bool(row.get("errors")) or row.get("complete") is False
        packager.package(folder, retain or failed)
        if not retain and not failed:
            for frame in frames:
                if (folder / frame["file"]).exists():
                    continue
                for key in ("world_file", "peer_file"):
                    if frame.get(key):
                        path = folder / frame[key]
                        if path.parent == folder:
                            path.unlink(missing_ok=True)
    return row


def write_index(output: Path, rows: list[dict], failures: list[str]) -> None:
    cards = []
    for row in rows:
        name = html.escape(row["id"], quote=True)
        folder = output / row["id"]
        video = f'<video controls loop src="{name}/sequence.mp4"></video>' if (folder / "sequence.mp4").is_file() else ""
        picture = "contact.jpg" if (folder / "contact.jpg").is_file() else row["frames"][0]["file"]
        image = f'<a href="{name}/{html.escape(picture, quote=True)}"><img src="{name}/{html.escape(picture, quote=True)}"></a>'
        world = row["frames"][0].get("world_file")
        link = f' · <a href="{name}/{html.escape(world, quote=True)}">World still</a>' if world and (folder / world).is_file() else ""
        errors = f'<pre>{html.escape(json.dumps(row["errors"], indent=2))}</pre>' if row.get("errors") else ""
        cards.append(f'<article><h2>{name}</h2>{video}{image}<p><a href="{name}/sequence.json">Timing and recording receipt</a>{link}</p>{errors}</article>')
    (output / "index.html").write_text(
        '<!doctype html><meta charset="utf-8"><title>Studio sequence review</title>'
        '<style>body{background:#10202b;color:#eee;font:16px sans-serif;margin:24px}a{color:#9ddcff}'
        'article{max-width:1280px;margin-bottom:48px}video,img{max-width:100%;height:auto}pre{white-space:pre-wrap}</style>'
        '<h1>Recorded Studio sequences</h1><p>Offline visual samples from recorded display time, not a frame-rate benchmark. Completion is not artistic acceptance.</p>'
        + (f'<pre>{html.escape(chr(10).join(failures))}</pre>' if failures else "") + "".join(cards), encoding="utf-8")


def run(command: list[str], output: Path, cases: list[dict], executable: Path, job_path: str,
        packager: ModuleType | None, retain: bool, timeout: float) -> int:
    started = time.monotonic()
    rows: dict[str, dict] = {}
    attempted: set[str] = set()
    failures: list[str] = []
    source_errors: list[str] = []
    failure_since = None
    process = None

    def completed() -> None:
        for case in cases:
            folder = output / case["id"]
            if case["id"] in attempted or not (folder / "sequence.json").is_file():
                continue
            try:
                rows[case["id"]] = package_case(folder, packager, retain)
                attempted.add(case["id"])
                print(f'Packaged {case["id"]}', flush=True)
            except json.JSONDecodeError as error:
                # The observer writes its receipt after the final frame. If the
                # watcher catches that small write, retry on the next poll.
                if process is not None and process.poll() is None:
                    continue
                attempted.add(case["id"])
                failures.append(f'{case["id"]}: incomplete receipt: {error}')
            except (OSError, ValueError, subprocess.SubprocessError) as error:
                attempted.add(case["id"])
                failures.append(f'{case["id"]}: packaging failed: {error}')

    try:
        with (output / "console.log").open("w") as log:
            process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT)
            while process.poll() is None:
                time.sleep(.5)
                completed()
                contents = (output / "console.log").read_text(errors="replace")
                if "SCRIPT ERROR:" in contents:
                    failure_since = failure_since or time.monotonic()
                if failure_since and time.monotonic() - failure_since >= 3:
                    failures.append("Owned Godot capture stopped after a script error")
                    break
                if time.monotonic() - started > timeout:
                    failures.append(f"Owned Godot capture exceeded {timeout:g} wall seconds")
                    break
    except (OSError, subprocess.SubprocessError, KeyboardInterrupt) as error:
        failures.append(f"Capture interrupted: {type(error).__name__}: {error}")
    finally:
        if process is not None and process.poll() is None:
            try:
                stop_owned(process, executable, job_path)
            except (OSError, subprocess.SubprocessError) as error:
                failures.append(f"Owned-process cleanup failed: {error}")
        completed()
    result = process.returncode if process is not None else None
    capture_file = output / "capture.json"
    try:
        capture = json.loads(capture_file.read_text()) if capture_file.is_file() else {}
    except (OSError, ValueError) as error:
        capture = {}
        failures.append(f"Incomplete capture receipt: {error}")
    if not capture:
        failures.append("Observer did not finish capture.json; partial frames and logs are retained")
    if result != 0:
        failures.append(f"Godot exited with status {result}")
    failures.extend(str(value) for value in capture.get("failures", []))
    for case in cases:
        if case["id"] not in rows:
            failures.append(f'{case["id"]}: no packaged case receipt')
    for row in rows.values():
        failures.extend(f'{row["id"]}: {error}' for error in row.get("errors", []))
        if row.get("complete") is False:
            failures.append(f'{row["id"]}: observer reported an incomplete sequence')
    console = output / "console.log"
    if console.exists():
        source_errors = [line for line in console.read_text(errors="replace").splitlines() if line.lstrip().startswith(("ERROR:", "SCRIPT ERROR:"))]
    failures.extend(source_errors)
    report = {"exit_code": result, "cases": len(rows), "failures": failures,
              "source_errors": source_errors, "elapsed_seconds": time.monotonic() - started,
              "review": str(output / "index.html"), "command": command}
    (output / "runner.json").write_text(json.dumps(report, indent=2) + "\n")
    write_index(output, list(rows.values()), failures)
    print(json.dumps({key: report[key] for key in ("cases", "failures", "review")}))
    return 1 if failures else 0


def main(argv: list[str] | None = None) -> int:
    cli = parser()
    args = cli.parse_args(argv)
    if args.at is not None and (args.start is not None or args.end is not None):
        cli.error("--at is a still capture; do not combine it with --start/--end")
    if args.end is not None and args.end < (args.start or 0):
        cli.error("--end must be at or after --start")
    if args.timeout <= 0:
        cli.error("--timeout must be positive")
    try:
        output = local_path(args.output)
        if not output.is_relative_to(PROJECT):
            raise ValueError("Output must be inside this client checkout so the observer can use res://")
        if output.exists():
            raise ValueError("Output already exists; use a fresh folder to preserve previous evidence")
        executable = local_path(args.godot)
        if not executable.is_file():
            raise ValueError(f"Godot executable does not exist: {executable}")
        cases = make_cases(args)
        packager = None if args.at is not None else factory_packager(local_path(args.factory))
        windows = executable.suffix.lower() == ".exe"
        for case in cases:
            if not case["recording"].startswith("res://"):
                case["recording"] = native_path(Path(case["recording"]), windows)
        output.mkdir(parents=True, exist_ok=False)
        job_file = output / "job.json"
        job_file.write_text(json.dumps({"output": resource_path(output), "review_fps": args.review_fps, "cases": cases}, indent=2) + "\n")
        command = [str(executable), "--path", native_path(PROJECT, windows),
                   "--rendering-method", "forward_plus", "--rendering-driver", "vulkan",
                   "--fixed-fps", "60", "--resolution", "1280x800", "--log-file", native_path(output / "godot.log", windows),
                   "--script", OBSERVER, "--", "--sequence-review=" + resource_path(job_file),
                   "--recording=" + cases[0]["recording"]]
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        cli.error(str(error))
    return run(command, output, cases, executable, resource_path(job_file), packager, args.retain_frames, args.timeout)


if __name__ == "__main__":
    sys.exit(main())
