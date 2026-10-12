"""Slow lane: run actual Godot clients against an owned native encounter host.

Use the engine Python environment and put the engine checkout on PYTHONPATH.
No backend files are modified. Credentials stay in the private run directory.
"""
import argparse
import asyncio
import json
from pathlib import Path
import subprocess
import sys
import time

from devtools.player_server_acceptance.fixtures import combat_configuration


def windows_path(path: Path) -> str:
    return subprocess.check_output(["wslpath", "-w", str(path.resolve())], text=True).strip()


async def run(args):
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    project = Path(__file__).resolve().parents[1]
    settings = combat_configuration(args.case, output)
    config = output / "server.json"
    config.write_text(settings.model_dump_json(indent=2))
    config.chmod(0o600)
    client_config = output / "client.json"
    client_config.write_text(json.dumps({"url": f"http://127.0.0.1:{args.port}",
        "case": args.case, "output": windows_path(output),
        "seats": [{"id": row.seat_id, "token": row.token} for row in settings.credentials]}))
    client_config.chmod(0o600)
    stop = output / "server.stop"
    started = time.monotonic()
    with (output / "server.log").open("wb") as server_log, (output / "godot.log").open("wb") as godot_log:
        host = await asyncio.create_subprocess_exec(sys.executable, "-m", "devtools.player_server_acceptance.test_host",
            "--config", str(config), "--stop", str(stop), "--result", str(output / "host-result.json"),
            "--host", "0.0.0.0", "--port", str(args.port), cwd=args.engine, stdout=server_log, stderr=server_log)
        try:
            async with asyncio.timeout(60):
                while not (output / "host.ready").exists():
                    if host.returncode is not None: raise RuntimeError("Host exited; inspect server.log")
                    await asyncio.sleep(.05)
            client = await asyncio.create_subprocess_exec(str(args.godot), "--headless", "--path", windows_path(project),
                "--script", "res://tests/sdk_live_game.gd", "--", windows_path(client_config), stdout=godot_log, stderr=godot_log)
            try:
                async with asyncio.timeout(270):
                    code = await client.wait()
            except TimeoutError:
                # Tell the real Windows process to exit; killing WSL's bridge
                # alone would leave a native child behind.
                subprocess.run(["powershell.exe", "-NoProfile", "-NonInteractive", "-Command",
                    "Get-CimInstance Win32_Process | Where-Object { $_.Name -like 'Godot*console.exe' -and "
                    "$_.CommandLine -like '*sdk_live_game.gd*' -and $_.CommandLine -like '*" + windows_path(client_config).replace("'", "''") + "*' } | ForEach-Object { Stop-Process -Id $_.ProcessId }"], check=True)
                await client.wait()
                raise
        finally:
            stop.touch()
            await asyncio.wait_for(host.wait(), 25)
    log = (output / "godot.log").read_text()
    if code or "SCRIPT ERROR:" in log or "ERROR:" in log:
        raise RuntimeError(f"Godot integration failed; inspect {output / 'godot.log'}")
    result = json.loads((output / "godot-result.json").read_text())
    if not result["ok"] or not all(seat["terminal"] and seat["replay_matches"] for seat in result["seats"]):
        raise RuntimeError(f"Encounter did not complete with equal replay: {result['failure']}")
    print(json.dumps({"case": args.case, "commands": len(result["commands"]), "seats": result["seats"],
        "reconnects": result["reconnects"], "elapsed_seconds": time.monotonic() - started, "output": str(output)}, indent=2))


def main():
    project = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine", type=Path, default=project.parent / "dnd_engine")
    parser.add_argument("--godot", type=Path, default=project.parent / "Tools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--case", choices=("ranged", "magic_missile"), default="ranged")
    parser.add_argument("--port", type=int, default=8799)
    asyncio.run(run(parser.parse_args()))


if __name__ == "__main__":
    main()
