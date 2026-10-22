"""Run the tests listed in tests/manifest.json and print one table.

Tiers: fast (headless, before every commit), gate (GPU picture/order checks,
before every merge), live (real games through tools/play.py, after every merge).
Only rows with status "ok" gate; --all-status also runs known-red, needs-args and
owned-by-migration rows (reported, never gating). Headless rows run in parallel,
GPU and live rows one at a time. Every Godot run gets the absolute project path,
the manifest timeout, and afterwards its own leftover processes (matched by its
unique engine log path; live runs use the test script) are stopped. Reports go to .runtime/tests/;
tracked generated/ reports stay available for inspection; this runner never
checks out files which a concurrent worker may have changed.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

PROJECT = Path(__file__).resolve().parents[1]
GODOT = PROJECT.parent / "Tools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe"
ENGINE = Path("/home/tommaso/.cache/ndclient/dnd_engine-1f044792b1")
PYTHON = "/home/tommaso/.cache/dnd-engine/venv/bin/python"


def windows_path(path: Path) -> str:
    return subprocess.check_output(["wslpath", "-w", str(path)], text=True).strip()


def godot_processes(marker: str) -> list[dict]:
    """Godot processes whose command line contains marker (this worktree's path)."""
    script = ("Get-CimInstance Win32_Process -Filter \"Name like 'Godot%'\" | Where-Object { $_.CommandLine -and "
        "$_.CommandLine.Contains('" + marker.replace("'", "''") + "') } | ForEach-Object { \"$($_.ProcessId)`t$($_.CommandLine)\" }")
    output = subprocess.run(["powershell.exe", "-NoProfile", "-NonInteractive", "-Command", script],
        capture_output=True, text=True, timeout=60).stdout
    return [{"pid": int(line.split("\t", 1)[0]), "command": line.split("\t", 1)[1]}
        for line in output.splitlines() if "\t" in line and line.split("\t", 1)[0].strip().isdigit()]


def test_processes(rows: list[dict], scripts: set[str]) -> list[dict]:
    # Another preview/reviewer can use this worktree while a headless suite
    # finishes. Only the selected test scripts belong to this invocation.
    return [row for row in rows if any(script in row["command"] for script in scripts)]


def stop_processes(rows: list[dict]) -> None:
    if rows:
        ids = ",".join(str(row["pid"]) for row in rows)
        subprocess.run(["powershell.exe", "-NoProfile", "-NonInteractive", "-Command",
            f"Stop-Process -Id {ids} -Force -ErrorAction SilentlyContinue"], capture_output=True, timeout=60)


def parse_result(text: str) -> tuple:
    """(checks, failures) from the formats the tests print; None when absent."""
    for line in reversed(text.splitlines()):
        start = line.find("{")
        if start < 0 or not any(key in line for key in ('"checks"','"passed"')):
            continue
        try:
            value = json.loads(line[start:])
        except ValueError:
            continue
        failures = value.get("failures", value.get("failed"))
        checks=value.get("checks",value.get("passed"))
        if not isinstance(checks,int):continue
        return checks, len(failures) if isinstance(failures, list) else failures
    for line in reversed(text.splitlines()):
        match=re.search(r"^[A-Z_]+ (\d+) failures=(\[.*\])$",line)
        if match:
            try:failures=json.loads(match[2])
            except ValueError:continue
            return int(match[1]),len(failures)
    for pattern in (r"checks[=: ]+(\d+)\D+?failures[=: ]+(\d+)", r"(\d+) passed=\d+ failed=(\d+)", r"checks[=: ]+(\d+)\D+?failed[=: ]+(\d+)"):
        found = re.findall(pattern, text)
        if found:
            return int(found[-1][0]), int(found[-1][1])
    return None, None


def run_one(row: dict, report: Path, worktree: str, allowed: list[str]) -> dict:
    log = report / (row["name"] + ".log")
    started = time.time()
    if row["mode"] == "live":
        environment = dict(os.environ, PYTHONPATH=f"{ENGINE}:{ENGINE}/sdk/python/src")
        if row.get("runner")=="studio_spell_batch":
            command=[PYTHON,"tools/studio_cases/live.py","--engine",str(ENGINE),"--out",str(report/"live-spells"),*row.get("args",[])]
        elif row.get("runner")=="storage_loot":
            command=[PYTHON,"tools/loot_scenario.py","--engine",str(ENGINE),"--output",str(report/"loot-live"),*row.get("args",[])]
        else:
            command = [PYTHON, "tools/play.py", "--engine", str(ENGINE), "--test-script", row["script"], *row.get("args", [])]
    else:
        command = [str(GODOT), *(["--headless"] if row["mode"] == "headless" else ["--rendering-method", "forward_plus", "--rendering-driver", "vulkan"]),
            "--path", worktree, "--log-file", windows_path(report / (row["name"] + ".engine.log")),
            "--script", row["script"], *(["--", *row["args"]] if row.get("args") else [])]
        environment = None
    timed_out = False
    fatal_log = False
    with log.open("w", encoding="utf-8", errors="replace") as stream:
        process = subprocess.Popen(command, cwd=PROJECT, env=environment, stdout=stream, stderr=subprocess.STDOUT, start_new_session=True)
        deadline = time.monotonic() + row.get("timeout", 300)
        with log.open(encoding="utf-8", errors="replace") as observed:
            tail = ""
            while process.poll() is None:
                tail = (tail[-256:] + observed.read(1024 * 1024))
                fatal_log = any(marker in tail for marker in ("SCRIPT ERROR:", "Parse Error:", "Failed loading resource:", "Can't load script:"))
                timed_out = time.monotonic() >= deadline
                if fatal_log or timed_out:
                    process.kill()
                    break
                time.sleep(.05)
        code = process.wait()
    # The console launcher can leave its windowed child running. Non-live
    # instances carry this invocation's unique engine log path, so another
    # worker running the same script is never mistaken for our child.
    marker = windows_path(report / (row["name"] + ".engine.log")) if row["mode"] != "live" else row["script"]
    leftovers = test_processes(godot_processes(worktree), {marker})
    stop_processes(leftovers)
    text = log.read_text(encoding="utf-8", errors="replace")
    godot_log = text
    if row["mode"] == "live":
        found = re.findall(r"/[^ ]*\.runtime/player-runs/[0-9TZ.]+", text)
        run = report/"loot-live" if row.get("runner")=="storage_loot" else (report/"live-spells" if row.get("runner")=="studio_spell_batch" else (Path(found[0]) if found else None))
        if run is not None and (run / "godot.log").exists():
            godot_log = (run / "godot.log").read_text(encoding="utf-8", errors="replace")
        checks, failures = None, None
        if row.get("runner")=="studio_spell_batch" and run is not None and (run/"results.json").exists():
            value=json.loads((run/"results.json").read_text(encoding="utf-8"))
            checks=sum(case.get("checks",0) for case in value.get("cases",[]))
            failures=sum(not case.get("ok",False) for case in value.get("cases",[]))+len(value.get("native_errors",[]))
            if not value.get("ok",False):failures=max(1,failures)
        elif run is not None and (run / ("loot-checks.json" if row.get("runner")=="storage_loot" else "player-live-checks.json")).exists():
            value = json.loads((run / ("loot-checks.json" if row.get("runner")=="storage_loot" else "player-live-checks.json")).read_text(encoding="utf-8"))
            checks, failures = value.get("checks"), len(value.get("failures", [])) if isinstance(value.get("failures"), list) else value.get("failures")
        if checks is None:
            checks, failures = parse_result(godot_log)
    else:
        checks, failures = parse_result(text)
    errors = [line for line in godot_log.splitlines() if line.startswith("ERROR:")]
    unexpected = [line for line in errors if not any(pattern in line for pattern in allowed)]
    script_errors = sum(1 for line in godot_log.splitlines() if "SCRIPT ERROR" in line)
    failed = bool(code != 0 or timed_out or fatal_log or script_errors or unexpected or leftovers or (failures or 0) > 0)
    return {"name": row["name"], "mode": row["mode"], "status": row["status"], "exit": code, "timed_out": timed_out,
        "checks": checks, "failures": failures, "script_errors": script_errors, "fatal_log": fatal_log, "error_lines": len(errors),
        "unexpected_errors": unexpected[:5], "leftover_processes": len(leftovers), "seconds": round(time.time() - started, 1),
        "failed": failed, "log": str(log)}


def changed_generated() -> set[str]:
    output = subprocess.run(["git", "--no-optional-locks", "status", "--porcelain", "--", "generated"], cwd=PROJECT, capture_output=True, text=True).stdout
    return {line[3:] for line in output.splitlines() if line[:2] in (" M", "M ", "MM")}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--tier", choices=("fast", "gate", "live", "all"), default="fast")
    parser.add_argument("--only", default="", help="comma-separated test names; runs them whatever their tier or status")
    parser.add_argument("--all-status", action="store_true", help="also run known-red, needs-args and owned-by-migration rows")
    parser.add_argument("--jobs", type=int, default=4, help="parallel headless runs")
    args = parser.parse_args()
    manifest = json.loads((PROJECT / "tests/manifest.json").read_text(encoding="utf-8"))
    allowed = [entry["pattern"] for entry in manifest.get("allowed_errors", [])]
    names = {name for name in args.only.split(",") if name}
    rows = [row for row in manifest["tests"] if row["mode"] != "none"]
    if names:
        unknown = names - {row["name"] for row in rows}
        if unknown:
            parser.error("not in tests/manifest.json: " + ", ".join(sorted(unknown)))
        rows = [row for row in rows if row["name"] in names]
    else:
        rows = [row for row in rows if (args.tier == "all" or row["tier"] == args.tier) and (args.all_status or row["status"] == "ok")]
    report = PROJECT / ".runtime/tests" / datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S.%fZ")
    report.mkdir(parents=True, exist_ok=True)
    worktree = windows_path(PROJECT)
    before = changed_generated()
    results = []
    # A source rebuild changes shared on-disk inputs. Finish those checks
    # before independent reader processes start; no locks or sleeps in game.
    for row in rows:
        if row.get("exclusive", False):
            results.append(run_one(row, report, worktree, allowed))
    with ThreadPoolExecutor(max_workers=max(1, args.jobs)) as pool:
        headless = [pool.submit(run_one, row, report, worktree, allowed) for row in rows if row["mode"] == "headless" and not row.get("exclusive", False)]
        for row in rows:
            if row["mode"] != "headless" and not row.get("exclusive", False):
                results.append(run_one(row, report, worktree, allowed))
                print(f"  {row['name']}: {'FAIL' if results[-1]['failed'] else 'ok'}", flush=True)
        results.extend(future.result() for future in headless)
    changed_reports = sorted(changed_generated() - before)
    markers = {windows_path(report / (row["name"] + ".engine.log")) if row["mode"] != "live" else row["script"] for row in rows}
    left = test_processes(godot_processes(worktree), markers)
    stop_processes(left)
    order = {row["name"]: index for index, row in enumerate(rows)}
    results.sort(key=lambda value: order[value["name"]])
    width = max([len(value["name"]) for value in results] + [4])
    lines = [f"{'test':<{width}}  {'mode':<8} {'checks':>7} {'fail':>5} {'script':>6} {'ERROR':>5} {'secs':>7}  result"]
    for value in results:
        verdict = "timeout" if value["timed_out"] else ("FAIL" if value["failed"] else "ok")
        if value["status"] != "ok":
            verdict += f" ({value['status']})"
        lines.append(f"{value['name']:<{width}}  {value['mode']:<8} {str(value['checks']):>7} {str(value['failures']):>5} "
            f"{value['script_errors']:>6} {value['error_lines']:>5} {value['seconds']:>7}  {verdict}")
    gating = [value for value in results if value["status"] == "ok" or names]
    bad = [value for value in gating if value["failed"]]
    lines.append(f"{len(results)} run, {len(bad)} failed; reports in {report}")
    if changed_reports:
        lines.append("tracked reports changed during this run (retained): " + ", ".join(changed_reports))
    if left:
        lines.append(f"stopped {len(left)} Godot process(es) of this worktree still running after the run")
    table = "\n".join(lines)
    print(table)
    (report / "table.txt").write_text(table + "\n", encoding="utf-8")
    (report / "summary.json").write_text(json.dumps({"tier": args.tier, "only": sorted(names), "results": results,
        "changed_generated": changed_reports, "leftover_processes": left}, indent=1), encoding="utf-8")
    return 1 if bad or left else 0


if __name__ == "__main__":
    sys.exit(main())
