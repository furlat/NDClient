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
from live_spell_profile import drive_blue
from studio_gallery_spell_capture import setup as gallery_sorcerer_setup
from dnd.ai.policies.basic import BASIC_POLICY_ID
from dnd.core.content.encounters import EncounterRecipe, RosterControllerDefaults, RosterControllerKind


def interactive_sorcerer(settings):
    """Use the existing Gallery roster with ordinary backend AI opponents."""
    slots = tuple(slot.model_copy(update={"controller_defaults": RosterControllerDefaults(
        controller=RosterControllerKind.AI, participant_name=slot.roster_slot_id,
        policy_id=BASIC_POLICY_ID)}) if slot.roster_slot_id == "blue" else slot
        for slot in settings.recipe.roster_slots)
    recipe = EncounterRecipe.create(**{
        **settings.recipe.model_dump(exclude={"recipe_digest", "roster_slots", "deployment", "opening_policy"}),
        "roster_slots": slots, "deployment": settings.recipe.deployment,
        "opening_policy": settings.recipe.opening_policy})
    return settings.model_copy(update={"game_id": "gallery_sorcerer", "recipe": recipe,
        "assignments": tuple(seat for seat in settings.assignments if seat.seat_id == "amber"),
        "credentials": tuple(seat for seat in settings.credentials if seat.seat_id == "amber")})


def windows_path(path: Path) -> str:
    return subprocess.check_output(["wslpath", "-w", str(path.resolve())], text=True).strip()


def available_port(excluded: tuple[int, ...] = ()) -> int:
    # Godot runs on Windows while its backend runs in WSL. A WSL-only port0
    # allocation can land in Windows' excluded TCP ranges, preventing localhost
    # forwarding. Let the actual Windows socket stack choose first; no exclusion
    # table or machine-specific port range is duplicated here.
    script = (
        "$ErrorActionPreference = 'Stop'; "
        "$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0); "
        "$listener.ExclusiveAddressUse = $true; "
        "try { $listener.Start(1); $listener.LocalEndpoint.Port } "
        "finally { $listener.Stop() }"
    )
    for _ in range(10):
        try:
            output = subprocess.check_output(
                ["powershell.exe", "-NoProfile", "-NonInteractive", "-Command", script],
                text=True, stderr=subprocess.PIPE, timeout=10)
            port = int(output.strip())
        except (subprocess.SubprocessError, ValueError) as error:
            raise RuntimeError("Native Windows loopback port allocation failed") from error
        if not 1 <= port <= 65535:
            raise RuntimeError("Native Windows loopback allocation returned an invalid port")
        if port in excluded:
            continue
        try:
            with socket.socket() as probe:
                # Match the backend/proxy's real bind address, including conflicts
                # from other WSL interfaces, then release before its normal start.
                probe.bind(("0.0.0.0", port))
            return port
        except OSError:
            continue
    raise RuntimeError("No port was available to both native Windows and WSL after 10 attempts")


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
    sorcerer = args.scenario == "gallery_sorcerer"
    spell_profile = sorcerer and args.test_script == "res://tests/live_spell_checks.gd" and not args.live_fireball_ui
    settings, profile_steps = gallery_sorcerer_setup(output, 3) if sorcerer else (configuration(args.scenario, output), [])
    if sorcerer and not spell_profile:
        settings = interactive_sorcerer(settings)
    server_config = output / "server.json"
    private_json(server_config, settings.model_dump(mode="json"))
    port = args.port or available_port()
    proxy = await start_delayed_backend(port,args.test_command_delay_ms,available_port((port,))) if args.test_command_delay_ms else None
    client_port = proxy["port"] if proxy else port
    client_config = output / "client.json"
    seat = settings.credentials[0]
    client_values = {"url":f"http://127.0.0.1:{client_port}", "token":seat.token,
        "trusted_operations":True,
        "journal":windows_path(output / "journal"), "seat_id":seat.seat_id,
        "test_command_delay_ms":args.test_command_delay_ms,"test_result":windows_path(output / "player-live-checks.json")}
    if spell_profile:
        client_values["profile_steps"] = profile_steps + [
            {"behavior":"spell.fire_bolt", "actor_name":"Expedition sorcerer", "offered_opponent":True},
            {"behavior":"end_turn", "actor_name":"Expedition sorcerer"},
            {"behavior":"spell.fire_bolt", "actor_name":"Expedition sorcerer", "offered_opponent":True}]
        client_values["blue_request"] = windows_path(output / "blue-request.json")
        client_values["blue_result"] = windows_path(output / "blue-result.json")
    if args.live_fireball_ui:
        client_values["live_fireball_ui"] = True
        client_values["profile_steps"] = [
            {"behavior":"action.environment.directional_door.open", "actor_name":"Expedition sorcerer", "display_name":"Open Door (Lantern gallery door)"},
            {"behavior":"action.move", "actor_name":"Expedition sorcerer", "position":[26,6]},
            {"behavior":"action.item.potion_haste.drink", "actor_name":"Expedition sorcerer"},
            {"behavior":"spell.fireball", "actor_name":"Expedition sorcerer", "position":[32,8]},
            {"behavior":"spell.fireball", "actor_name":"Expedition sorcerer", "position":[33,7]}]
    private_json(client_config, client_values)
    environment = os.environ.copy()
    environment["PYTHONPATH"] = os.pathsep.join((str(args.engine.resolve()),
        str(args.engine.resolve() / "sdk/python/src")))
    stop = output / "server.stop"
    client = None
    blue_driver = None
    print(("Lantern Gallery" if args.scenario in ("crypt_gallery", "gallery_sorcerer") else "Lantern Crypt") + " · Expedition", flush=True)
    print("Run files: " + str(output), flush=True)
    with (output / "server.log").open("wb") as server_log, (output / "godot.log").open("wb") as godot_log:
        host_entry = [str(project / "tools/profile_host.py"), "--cpu-commands", args.profile_cpu_commands] if args.profile_pipeline else ["-m", "devtools.player_server_acceptance.test_host"]
        if args.profile_pipeline and args.profile_action_phases:
            host_entry.append("--action-phases")
        host = await asyncio.create_subprocess_exec(sys.executable, *host_entry,
            "--config", str(server_config), "--stop", str(stop), "--result", str(output / "host-result.json"),
            "--host", "0.0.0.0", "--port", str(port), cwd=args.engine, env=environment,
            start_new_session=True, stdout=server_log, stderr=server_log)
        try:
            async with asyncio.timeout(60):
                while not (output / "host.ready").exists():
                    if host.returncode is not None:
                        raise RuntimeError("Backend startup failed; inspect " + str(output / "server.log"))
                    await asyncio.sleep(0.1)
            if spell_profile:
                blue_driver = asyncio.create_task(drive_blue(f"http://127.0.0.1:{port}", settings.credentials[1].token, output))
            native_args = [str(args.godot), "--path", windows_path(project)]
            if sorcerer or args.profile_view_size is not None or args.profile_stop_stage is not None:
                native_args.extend(["--rendering-method", "forward_plus", "--rendering-driver", "vulkan"])
            if args.headless:
                native_args.extend(["--headless", "--max-fps", "60"])
            if args.quit_after:
                native_args.extend(["--quit-after", str(args.quit_after)])
            native_args.extend(["--script", args.test_script] if args.test_script else ["res://loading.tscn"])
            native_args.extend(["--", "--config", windows_path(client_config)])
            if args.live_fireball_ui:
                native_args.append("--live-fireball-ui")
            if args.profile_root_player:
                native_args.append("--profile-root-player")
            if args.test_atlas_reference:
                native_args.append("--reference-atlas=" + args.test_atlas_reference)
            if args.test_light_cap is not None:
                native_args.append("--profile-light-cap=" + args.test_light_cap)
            if args.profile_view_size is not None:
                native_args.append("--profile-view-size=" + str(args.profile_view_size))
            if args.profile_stop_stage is not None:
                native_args.append("--profile-stop-stage=" + str(args.profile_stop_stage))
            native_args.extend(args.client_arg)
            client = await asyncio.create_subprocess_exec(*native_args, stdout=godot_log, stderr=godot_log)
            print("Godot opened; waiting for initialization and current player choices…", flush=True)
            player_ready = False
            with (output / "godot.log").open(encoding="utf-8", errors="replace") as observed:
                while client.returncode is None:
                    if blue_driver is not None and blue_driver.done():
                        await blue_driver
                        raise RuntimeError("Blue SDK driver stopped unexpectedly")
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
            if blue_driver is not None and blue_driver.done():
                await blue_driver
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
                if blue_driver is not None:
                    blue_driver.cancel()
                    await asyncio.gather(blue_driver, return_exceptions=True)
                if proxy:
                    await close_delayed_backend(proxy)
                    private_json(output / "delay-evidence.json",proxy["state"])
                await stop_host(host, stop)
    print("Encounter stopped; recording retained in " + str(output), flush=True)
    return output


def main() -> None:
    project = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine", type=Path, default=Path("/home/tommaso/.cache/ndclient/dnd_engine-9f81d5267"))
    parser.add_argument("--godot", type=Path, default=project.parent / "Tools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe")
    parser.add_argument("--port", type=int, default=0, help="Backend port; default checks native Windows and WSL availability")
    parser.add_argument("--scenario", choices=("crypt", "crypt_gallery", "gallery_sorcerer"), default="crypt_gallery", help="Backend encounter; crypt retains the original small baseline")
    parser.add_argument("--headless", action="store_true", help="Headless Godot for launch validation")
    parser.add_argument("--quit-after", type=int, default=0, metavar="FRAMES", help="Close after a bounded number of Godot frames")
    parser.add_argument("--test-script", choices=("res://tests/player_startup_checks.gd", "res://tests/live_idle_ui_checks.gd", "res://tests/live_gallery_checks.gd", "res://tests/live_spell_checks.gd", "res://tests/player_wait_checks.gd", "res://tests/player_live_checks.gd", "res://tests/player_interaction_checks.gd", "res://tests/lighting_live_checks.gd", "res://tests/chest_live_checks.gd"), help="Run a bounded production-scene acceptance test")
    parser.add_argument("--live-fireball-ui", action="store_true", help="Live spell profile: ordinary Gallery AI setup and native Fireball selection/hover/Confirm input")
    parser.add_argument("--profile-root-player", action="store_true", help="Live spell control: ordinary root viewport and production admitted action handlers, without GUI gesture preparation")
    parser.add_argument("--test-command-delay-ms", type=int, default=0, help="Acceptance only: hold the first real command before forwarding it")
    parser.add_argument("--test-atlas-reference", default="", help="Gallery profiling only: load a frozen reference atlas script instead of the current atlas")
    parser.add_argument("--test-light-cap", choices=("on", "off"), help="Gallery profiling only: compare live movement with or without the light cap")
    parser.add_argument("--profile-pipeline", action="store_true", help="Record worker execution and host exchange timings during real live commands")
    parser.add_argument("--profile-cpu-commands", default="", help="Optional comma-separated command numbers for cProfile; adds overhead to those commands")
    parser.add_argument("--profile-action-phases", action="store_true", help="Optional nested engine phase hooks; adds diagnostic overhead")
    parser.add_argument("--profile-view-size", type=float, help="Live Gallery profiling: fixed orthographic camera size, with a 1600×960 native window")
    parser.add_argument("--client-arg", action="append", default=[], help="Extra user argument passed to the Godot client (repeatable)")
    parser.add_argument("--profile-stop-stage", type=int, help="Live Gallery profiling: stop after 9–11 route stages and retain a three-second idle control instead of the full zoom/cap matrix")
    args = parser.parse_args()
    if args.live_fireball_ui and (args.scenario != "gallery_sorcerer" or args.test_script != "res://tests/live_spell_checks.gd"):
        parser.error("Live Fireball UI requires Gallery sorcerer and live_spell_checks.gd")
    if args.test_atlas_reference and args.test_script != "res://tests/live_gallery_checks.gd":
        parser.error("Reference atlas requires the live Gallery acceptance script")
    if args.test_light_cap is not None and args.test_script != "res://tests/live_gallery_checks.gd":
        parser.error("Light-cap profiling requires the live Gallery acceptance script")
    if args.scenario == "gallery_sorcerer" and args.test_script not in (None, "res://tests/live_spell_checks.gd", "res://tests/live_idle_ui_checks.gd"):
        parser.error("Gallery sorcerer supports normal play or the live spell profiling script")
    if args.test_script == "res://tests/live_spell_checks.gd" and args.scenario != "gallery_sorcerer":
        parser.error("Live spell profiling requires the Gallery sorcerer setup")
    if args.profile_view_size is not None:
        if (args.test_script, args.scenario) not in (("res://tests/live_gallery_checks.gd", "crypt_gallery"), ("res://tests/live_spell_checks.gd", "gallery_sorcerer")):
            parser.error("Fixed-view profiling requires a live Gallery movement or spell fixture")
    if args.profile_stop_stage is not None and (args.test_script != "res://tests/live_gallery_checks.gd" or args.scenario != "crypt_gallery"):
        parser.error("Bounded route stages require the live Gallery movement fixture")
    if args.profile_view_size is not None and not 4 <= args.profile_view_size <= 80:
        parser.error("Profile view size must be between 4 and 80")
    if args.profile_stop_stage is not None and not 9 <= args.profile_stop_stage <= 11:
        parser.error("Profile stop stage must be 9–11, including Gallery entry and an interior move")
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
