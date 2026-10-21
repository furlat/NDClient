"""Native public-API presentation recordings; no backend rules or state edits."""
import argparse
import asyncio
import json
from pathlib import Path
import secrets
import subprocess
import sys

from dnd.content.characters.premades import BARBARIAN_PREMADE_ID, FIGHTER_PREMADE_ID
from dnd.core.content.encounters import (AuthoredCreatureRosterSource, EncounterDeploymentSpec,
    EncounterDeploymentZone, EncounterRecipe, EncounterRosterMember, EncounterRosterRecipe,
    EncounterRosterSlot, FixedRosterOpeningPolicy, PremadeCharacterRosterSource,
    RosterControllerDefaults, RosterControllerKind)
from dnd.core.content.recipes import ContentRecipe
from dnd.monsters.bestiary_content import BESTIARY_CREATURE_RECIPES_BY_ID
from dnd.player.audience import SeatAssignment
from server.config import SeatCredential, ServerConfig

CASES = ("walk", "walk_diagonal", "walk_fast", "jump", "attack", "oa_walk", "oa_jump", "oa_lethal", "oa_jump_lethal", "oa_jump_late_lethal")


def configuration(case: str, output: Path, seed: int):
    slots, zones = [], []
    for side in ("amber", "blue"):
        if "lethal" in case and side == "amber":
            recipe = BESTIARY_CREATURE_RECIPES_BY_ID["generic_caster"]
            source = AuthoredCreatureRosterSource(recipe=ContentRecipe.create(ref=recipe.ref, parameters={"level": 1}))
        else:
            source = PremadeCharacterRosterSource(premade_id=BARBARIAN_PREMADE_ID if (side == "blue" and "lethal" in case) or (side == "amber" and case == "walk_fast") else FIGHTER_PREMADE_ID)
        member = EncounterRosterMember(member_id="actor", display_name=side.title()+" presentation actor",
            deployment_role=side, source=source)
        roster = EncounterRosterRecipe.create(roster_id="roster.presentation_"+side, title=side.title(), members=(member,))
        slots.append(EncounterRosterSlot(roster_slot_id=side, roster=roster, faction_id=side,
            deployment_zone_id=side, controller_defaults=RosterControllerDefaults(controller=RosterControllerKind.HUMAN,participant_name=side)))
        position = (4,6) if side == "amber" else (5,6) if case.startswith("oa_") or case == "attack" else (12,8)
        if case == "oa_jump_late_lethal" and side == "blue": position = (5,7)
        zones.append(EncounterDeploymentZone(zone_id=side,ordered_slots=(position,)))
    battlefield = "battlefield.open_floor_bright"
    deployment = EncounterDeploymentSpec.create(deployment_id="deployment.presentation",title="Presentation records",
        battlefield_id=battlefield,zones=tuple(zones))
    encounter = EncounterRecipe.create(encounter_id="encounter.presentation",title="Presentation records",battlefield_id=battlefield,
        deployment=deployment,roster_slots=tuple(slots),opening_policy=FixedRosterOpeningPolicy(roster_slot_id="amber"))
    settings = ServerConfig(game_id="presentation_"+case,encounter_id=None,recipe=encounter,
        assignments=tuple(SeatAssignment(side,((side,"actor"),)) for side in ("amber","blue")),
        credentials=tuple(SeatCredential(seat_id=side,token=secrets.token_urlsafe(32)) for side in ("amber","blue")),
        spool_directory=output/"spool",test_seed=seed)
    target = (3,6) if case in ("oa_walk","oa_lethal") else (2,6) if case in ("oa_jump","oa_jump_lethal") else (7,6)
    if case == "walk_diagonal": target = (7,9)
    return settings,{"case":case,"behavior":"action.attack" if case == "attack" else "action.jump" if "jump" in case else "action.move","target":target}


def windows_path(path):
    return subprocess.check_output(["wslpath","-w",str(path.resolve())],text=True).strip()


async def run(args):
    if args.seed is None: args.seed = 5 if "lethal" in args.case else 3
    output=args.output.resolve();output.mkdir(parents=True,exist_ok=False)
    project=Path(__file__).resolve().parents[1]
    settings,plan=configuration(args.case,output,args.seed)
    config=output/"server.json";config.write_text(settings.model_dump_json(indent=2));config.chmod(0o600)
    client=output/"client.json"
    client.write_text(json.dumps({**plan,"url":f"http://127.0.0.1:{args.port}","output":windows_path(output),
        "seats":[{"id":row.seat_id,"token":row.token} for row in settings.credentials]}));client.chmod(0o600)
    if args.prepare_only:
        print(json.dumps({"server_config":str(config),"client_config":str(client)}));return
    stop=output/"server.stop"
    with (output/"server.log").open("wb") as server_log,(output/"godot.log").open("wb") as godot_log:
        host=await asyncio.create_subprocess_exec(sys.executable,"-m","devtools.player_server_acceptance.test_host",
            "--config",str(config),"--stop",str(stop),"--result",str(output/"host-result.json"),"--host","0.0.0.0","--port",str(args.port),
            cwd=args.engine,stdout=server_log,stderr=server_log)
        try:
            async with asyncio.timeout(90):
                while not (output/"host.ready").exists():
                    if host.returncode is not None: raise RuntimeError("Host failed; inspect server.log")
                    await asyncio.sleep(.05)
            process=await asyncio.create_subprocess_exec(str(args.godot),"--headless","--path",windows_path(project),
                "--script","res://tests/presentation_capture.gd","--",windows_path(client),stdout=godot_log,stderr=godot_log)
            try:
                async with asyncio.timeout(180): code=await process.wait()
            except TimeoutError:
                subprocess.run(["powershell.exe","-NoProfile","-NonInteractive","-Command",
                    "Get-CimInstance Win32_Process | Where-Object { $_.Name -like 'Godot*console.exe' -and "
                    "$_.CommandLine -like '*presentation_capture.gd*' -and $_.CommandLine -like '*"+windows_path(client).replace("'","''")+"*' } | ForEach-Object { Stop-Process -Id $_.ProcessId }"],check=True)
                await process.wait()
                raise
        finally:
            stop.touch();await asyncio.wait_for(host.wait(),25)
    log=(output/"godot.log").read_text()
    if code or "SCRIPT ERROR:" in log or "ERROR:" in log: raise RuntimeError("Capture failed: "+str(output/"godot.log"))
    result=json.loads((output/"presentation-result.json").read_text())
    if not result["ok"]: raise RuntimeError(result["failure"])
    print(json.dumps({"case":args.case,"seed":args.seed,"output":str(output),"evidence":result["evidence"]}))


def main():
    project=Path(__file__).resolve().parents[1]
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--case",choices=CASES,required=True);parser.add_argument("--seed",type=int)
    parser.add_argument("--output",type=Path,required=True);parser.add_argument("--port",type=int,default=8801)
    parser.add_argument("--engine",type=Path,default=Path("/home/tommaso/.cache/ndclient/dnd_engine-9f81d5267"))
    parser.add_argument("--godot",type=Path,default=project.parent/"Tools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe")
    parser.add_argument("--prepare-only",action="store_true")
    asyncio.run(run(parser.parse_args()))


if __name__ == "__main__": main()
