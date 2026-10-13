"""Run the native Godot SDK contract lane; fail on runtime errors as well as exit codes."""
import argparse
import json
from pathlib import Path
import re
import subprocess
import time
from uuid import uuid4


def main():
    project = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, default=project.parent / "Tools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe")
    parser.add_argument("--trusted-operations-recording", help="Explicit current-server journal for the optional exact operation/loopback trust checks")
    args = parser.parse_args()
    native_project = subprocess.check_output(["wslpath", "-w", str(project)], text=True).strip()
    logs = project / ".runtime/sdk-checks"
    logs.mkdir(parents=True, exist_ok=True)
    results = []
    names = ["sdk_protocol_checks", "sdk_protocol_parity", "sdk_choices_checks", "sdk_reducer_checks", "sdk_retained_transaction_checks", "sdk_journal_checks", "sdk_transport_checks"]
    if (project / "tests/sdk_decimal_checks.gd").exists(): names.insert(0, "sdk_decimal_checks")
    if args.trusted_operations_recording: names.append("trusted_operations_checks")
    for name in names:
        started = time.monotonic()
        marker = "sdk-check-" + uuid4().hex
        inputs = ["res://generated/sdk_protocol_parity.jsonl"] if name == "sdk_protocol_parity" else []
        if name == "trusted_operations_checks":
            recording = args.trusted_operations_recording
            if not recording.startswith(("res://", "user://")):
                recording = subprocess.check_output(["wslpath", "-w", str(Path(recording).resolve())], text=True).strip()
            inputs = ["--recording=" + recording]
        try:
            process = subprocess.run([str(args.godot), "--headless", "--path", native_project,
                "--script", f"res://tests/{name}.gd", "--", *inputs, "--runner-id", marker],
                capture_output=True, text=True, timeout=120)
        except subprocess.TimeoutExpired as error:
            # subprocess kills WSL's bridge on timeout; its native Windows
            # child needs explicit cleanup, scoped to this exact invocation.
            subprocess.run(["powershell.exe", "-NoProfile", "-NonInteractive", "-Command",
                "$owned = Get-CimInstance Win32_Process | Where-Object { "
                "$_.Name -like 'Godot*.exe' -and $_.CommandLine -and "
                f"$_.CommandLine.Contains('{marker}') }}; "
                "$owned | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }"],
                check=True, capture_output=True, timeout=20)
            output = (error.stdout or b"") + (error.stderr or b"")
            (logs / (name + ".log")).write_bytes(output)
            results.append({"test":name,"checks":None,"passed":False,"timeout":True,
                "seconds":round(time.monotonic()-started,3),"log":str(logs / (name + ".log"))})
            print(json.dumps(results[-1]),flush=True)
            break
        output = process.stdout + process.stderr
        (logs / (name + ".log")).write_text(output)
        count = None
        passed = False
        for line in output.splitlines():
            line = line.removeprefix("SDK_RETAINED_TRANSACTION_CHECKS ")
            line = line.removeprefix("TRUSTED_OPERATIONS_CHECKS ")
            if line.startswith("{"):
                value = json.loads(line)
                if "checks" in value and "failures" in value:
                    count, passed = value["checks"], not value["failures"]
            match = re.fullmatch(r"SDK_REDUCER_CHECKS cases=(\d+) failures=(\d+)", line)
            if match:
                count, passed = int(match[1]), int(match[2]) == 0
        passed = passed and process.returncode == 0 and "SCRIPT ERROR:" not in output and "ERROR:" not in output
        row = {"test": name, "checks": count, "passed": passed,
            "seconds": round(time.monotonic() - started, 3), "log": str(logs / (name + ".log"))}
        results.append(row)
        print(json.dumps(row), flush=True)
    report = {"passed": all(row["passed"] for row in results), "runtime": "Native Windows Godot 4.7.2 headless", "tests": results}
    destination = project / "generated/sdk_checks.json"
    destination.write_text(json.dumps(report, indent=2))
    raise SystemExit(0 if report["passed"] else 1)


if __name__ == "__main__":
    main()
