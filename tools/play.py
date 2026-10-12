"""Launch the Lantern Gallery encounter and its native Godot player.

Run in the engine's cached Python environment with engine and sdk/python/src on
PYTHONPATH. All credentials and recordings remain in the private run directory.
Closing this launcher's Godot window stops its owned backend and worker.
"""
import argparse
import asyncio
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import signal
import socket
import subprocess
import sys

from devtools.player_server_acceptance.fixtures import configuration
from delayed_backend import close_delayed_backend, start_delayed_backend


def windows_path(path: Path) -> str:
    return subprocess.check_output(["wslpath", "-w", str(path.resolve())], text=True).strip()


def available_port() -> int:
    with socket.socket() as probe:
        probe.bind(("127.0.0.1", 0))
        return probe.getsockname()[1]


def private_json(path: Path, value: dict) -> None:
    with path.open("x", encoding="utf-8") as stream:
        json.dump(value, stream, indent=2)
    path.chmod(0o600)


async def stop_godot(client: asyncio.subprocess.Process, config_path: Path) -> None:
    if client.returncode is not None:
        return
    # Killing WSL's bridge alone can leave the native Windows child alive. The
    # unique private config path identifies only this launcher's Godot process.
    marker = windows_path(config_path).replace("'", "''")
    script = (
        "$owned = @(Get-CimInstance Win32_Process | Where-Object { "
        "$_.Name -like 'Godot*.exe' -and $_.CommandLine -and "
        f"$_.CommandLine.Contains('{marker}') }}); "
        "foreach ($entry in $owned) { $process = Get-Process -Id $entry.ProcessId -ErrorAction SilentlyContinue; "
        "if ($process) { [void]$process.CloseMainWindow() } }; "
        "Start-Sleep -Milliseconds 1500; "
        "foreach ($entry in $owned) { Stop-Process -Id $entry.ProcessId -Force -ErrorAction SilentlyContinue }"
    )
    cleaner = await asyncio.create_subprocess_exec("powershell.exe", "-NoProfile", "-NonInteractive",
        "-Command", script, stdout=asyncio.subprocess.DEVNULL, stderr=asyncio.subprocess.DEVNULL)
    try:
        await asyncio.wait_for(cleaner.wait(), 12)
    except TimeoutError:
        cleaner.kill()
        await cleaner.wait()
    try:
        await asyncio.wait_for(client.wait(), 8)
    except TimeoutError:
        client.kill()
        await client.wait()


async def stop_host(host: asyncio.subprocess.Process, stop: Path) -> None:
    stop.touch()
    try:
        await asyncio.wait_for(host.wait(), 25)
    except TimeoutError:
        # The host starts in its own process group. Its native worker belongs
        # to that same group; escalation cannot affect another game instance.
        try:
            os.killpg(host.pid, signal.SIGTERM)
        except ProcessLookupError:
            return
        try:
            await asyncio.wait_for(host.wait(), 5)
        except TimeoutError:
            try:
                os.killpg(host.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            await host.wait()


async def run(args: argparse.Namespace) -> Path:
    loop = asyncio.get_running_loop()
    owner = asyncio.current_task()
    for stop_signal in (signal.SIGTERM, signal.SIGHUP):
        loop.add_signal_handler(stop_signal, owner.cancel)
    os.umask(0o077)
    project = Path(__file__).resolve().parents[1]
    if not args.godot.is_file():
        raise RuntimeError("Godot executable was not found: " + str(args.godot))
    output = project / ".runtime/player-runs" / datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S.%fZ")
    output.mkdir(parents=True, mode=0o700)
    settings = configuration(args.scenario, output)
    server_config = output / "server.json"
    private_json(server_config, settings.model_dump(mode="json"))
    port = args.port or available_port()
    proxy = await start_delayed_backend(port,args.test_command_delay_ms) if args.test_command_delay_ms else None
    client_port = proxy["port"] if proxy else port
    client_config = output / "client.json"
    seat = settings.credentials[0]
    private_json(client_config, {"url":f"http://127.0.0.1:{client_port}", "token":seat.token,
        "journal":windows_path(output / "journal"), "seat_id":seat.seat_id,
        "test_command_delay_ms":args.test_command_delay_ms,"test_result":windows_path(output / "player-live-checks.json")})
    environment = os.environ.copy()
    environment["PYTHONPATH"] = os.pathsep.join((str(args.engine.resolve()),
        str(args.engine.resolve() / "sdk/python/src")))
    stop = output / "server.stop"
    client = None
    print(("Lantern Gallery" if args.scenario == "crypt_gallery" else "Lantern Crypt") + " · Expedition", flush=True)
    print("Run files: " + str(output), flush=True)
    with (output / "server.log").open("wb") as server_log, (output / "godot.log").open("wb") as godot_log:
        host = await asyncio.create_subprocess_exec(sys.executable, "-m", "devtools.player_server_acceptance.test_host",
            "--config", str(server_config), "--stop", str(stop), "--result", str(output / "host-result.json"),
            "--host", "0.0.0.0", "--port", str(port), cwd=args.engine, env=environment,
            start_new_session=True, stdout=server_log, stderr=server_log)
        try:
            async with asyncio.timeout(60):
                while not (output / "host.ready").exists():
                    if host.returncode is not None:
                        raise RuntimeError("Backend startup failed; inspect " + str(output / "server.log"))
                    await asyncio.sleep(0.1)
            native_args = [str(args.godot), "--path", windows_path(project)]
            if args.headless:
                native_args.extend(["--headless", "--max-fps", "60"])
            if args.quit_after:
                native_args.extend(["--quit-after", str(args.quit_after)])
            native_args.extend(["--script", args.test_script] if args.test_script else ["res://play.tscn"])
            native_args.extend(["--", "--config", windows_path(client_config)])
            client = await asyncio.create_subprocess_exec(*native_args, stdout=godot_log, stderr=godot_log)
            print("Godot opened; waiting for initialization and current player choices…", flush=True)
            player_ready = False
            with (output / "godot.log").open(encoding="utf-8", errors="replace") as observed:
                while client.returncode is None:
                    if host.returncode is not None:
                        raise RuntimeError("Backend stopped unexpectedly; inspect " + str(output / "server.log"))
                    errors = observed.read()
                    if not player_ready and "PLAYER_READY:" in errors:
                        player_ready = True
                        print("Player connected and ready. Close its window to stop this encounter.", flush=True)
                    if "PLAYER_CONNECTION_FAILED:" in errors:
                        raise RuntimeError("Player connection failed; inspect " + str(output / "godot.log"))
                    if any(marker in errors for marker in ("SCRIPT ERROR:", "Parse Error:", "Failed loading resource")):
                        raise RuntimeError("Godot failed to load or run the player scene; inspect " + str(output / "godot.log"))
                    await asyncio.sleep(0.2)
            if await client.wait() != 0:
                raise RuntimeError("Godot exited with an error; inspect " + str(output / "godot.log"))
            # A parse error can exit Godot with status zero before the polling
            # loop gets its first turn, or be logged during the final frame.
            final_log = (output / "godot.log").read_text(encoding="utf-8", errors="replace")
            if any(marker in final_log for marker in ("SCRIPT ERROR:", "Parse Error:", "Failed loading resource", "PLAYER_CONNECTION_FAILED:")):
                raise RuntimeError("Godot reported a player scene error; inspect " + str(output / "godot.log"))
        finally:
            try:
                if client is not None:
                    await stop_godot(client, client_config)
            finally:
                if proxy:
                    await close_delayed_backend(proxy)
                    private_json(output / "delay-evidence.json",proxy["state"])
                await stop_host(host, stop)
    print("Encounter stopped; recording retained in " + str(output), flush=True)
    return output


def main() -> None:
    project = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine", type=Path, default=project.parent / "dnd_engine")
    parser.add_argument("--godot", type=Path, default=project.parent / "Tools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe")
    parser.add_argument("--port", type=int, default=0, help="Backend port; default selects an available local port")
    parser.add_argument("--scenario", choices=("crypt", "crypt_gallery"), default="crypt_gallery", help="Backend encounter; crypt retains the original small baseline")
    parser.add_argument("--headless", action="store_true", help="Headless Godot for launch validation")
    parser.add_argument("--quit-after", type=int, default=0, metavar="FRAMES", help="Close after a bounded number of Godot frames")
    parser.add_argument("--test-script", choices=("res://tests/prediction_live_checks.gd", "res://tests/player_wait_checks.gd", "res://tests/player_live_checks.gd", "res://tests/player_interaction_checks.gd", "res://tests/lighting_live_checks.gd", "res://tests/chest_live_checks.gd"), help="Run a bounded production-scene acceptance test")
    parser.add_argument("--test-command-delay-ms", type=int, default=0, help="Acceptance only: hold the first real command before forwarding it")
    args = parser.parse_args()
    if args.test_command_delay_ms and (not args.test_script or not 1 <= args.test_command_delay_ms <= 10000):
        parser.error("Command delay is limited to 1–10000 ms and requires a test script")
    if not 0 <= args.port <= 65535 or args.quit_after < 0:
        parser.error("Port must be 0–65535 and frame count must be nonnegative")
    try:
        asyncio.run(run(args))
    except (KeyboardInterrupt, asyncio.CancelledError):
        print("Encounter stopped.", file=sys.stderr)
        sys.exit(130)
    except (RuntimeError, TimeoutError, OSError) as error:
        print("Launch failed: " + str(error), file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
