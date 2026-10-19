"""Run the real storage UI against the existing five-item authored field cache."""
import argparse
import asyncio
import json
import os
from pathlib import Path
import sys

from dnd.core.content.encounters import EncounterDeploymentSpec, EncounterDeploymentZone, EncounterRecipe
from play import available_port, private_json, stop_godot, stop_host, windows_path
from presentation_scenarios import configuration


def settings_for(output: Path):
    settings, _ = configuration("walk", output, 3)
    original = settings.recipe
    deployment = EncounterDeploymentSpec.create(deployment_id="deployment.storage_ui", title="Storage UI",
        battlefield_id="battlefield.field_cache_bright", zones=(
            EncounterDeploymentZone(zone_id="amber", ordered_slots=((3, 7),)),
            EncounterDeploymentZone(zone_id="blue", ordered_slots=((12, 8),))))
    recipe = EncounterRecipe.create(encounter_id="encounter.storage_ui", title="Storage UI",
        battlefield_id=deployment.battlefield_id, deployment=deployment,
        roster_slots=original.roster_slots, opening_policy=original.opening_policy)
    return settings.model_copy(update={"game_id":"storage_ui", "recipe":recipe})


async def run(args):
    project = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    settings = settings_for(output)
    config = output / "server.json"
    private_json(config, settings.model_dump(mode="json"))
    port = available_port()
    client_config = output / "client.json"
    private_json(client_config, {"url":f"http://127.0.0.1:{port}",
        "token":settings.credentials[0].token, "seat_id":settings.credentials[0].seat_id,
        "journal":windows_path(output / "journal"), "test_result":windows_path(output / "loot-checks.json")})
    if args.prepare_only:
        print(json.dumps({"output":str(output), "server_config":str(config), "client_config":str(client_config)}))
        return
    environment = os.environ.copy()
    environment["PYTHONPATH"] = os.pathsep.join((str(args.engine), str(args.engine / "sdk/python/src")))
    stop = output / "server.stop"
    client = None
    with (output / "server.log").open("wb") as host_log, (output / "godot.log").open("wb") as client_log:
        host = await asyncio.create_subprocess_exec(sys.executable,"-m","devtools.player_server_acceptance.test_host",
            "--config",str(config),"--stop",str(stop),"--result",str(output / "host-result.json"),
            "--host","0.0.0.0","--port",str(port),cwd=args.engine,env=environment,
            start_new_session=True,stdout=host_log,stderr=host_log)
        try:
            async with asyncio.timeout(60):
                while not (output / "host.ready").exists():
                    if host.returncode is not None: raise RuntimeError("Backend startup failed; inspect server.log")
                    await asyncio.sleep(.05)
            command = [str(args.godot),"--path",windows_path(project)]
            if args.headless: command.append("--headless")
            command.extend(["--script","res://tests/loot_live_checks.gd","--","--config",windows_path(client_config)])
            client = await asyncio.create_subprocess_exec(*command,stdout=client_log,stderr=client_log)
            async with asyncio.timeout(200):
                await client.wait()
        finally:
            try:
                if client is not None: await stop_godot(client,client_config)
            finally:
                await stop_host(host,stop)
    log = (output / "godot.log").read_text(errors="replace")
    if client.returncode or any(marker in log for marker in ("SCRIPT ERROR:","ERROR:","PLAYER_CONNECTION_FAILED:")):
        raise RuntimeError("Native storage acceptance failed: " + str(output / "godot.log"))
    report = json.loads((output / "loot-checks.json").read_text())
    if report["failures"]: raise RuntimeError(str(report["failures"]))
    print(json.dumps({"output":str(output),"checks":report["checks"],"render_mode":report["render_mode"]}))


def main():
    project = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output",type=Path,required=True)
    parser.add_argument("--engine",type=Path,default=Path("/home/tommaso/.cache/ndclient/dnd_engine-211b71134"))
    parser.add_argument("--godot",type=Path,default=project.parent / "Tools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe")
    parser.add_argument("--headless",action="store_true")
    parser.add_argument("--prepare-only",action="store_true")
    asyncio.run(run(parser.parse_args()))


if __name__ == "__main__": main()
