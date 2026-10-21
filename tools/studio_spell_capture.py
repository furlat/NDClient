"""Capture the existing thirty-spell Studio batch through real server commands.

Run using the engine's cached uv Python, with engine and sdk/python/src on
PYTHONPATH. Setup uses published encounter recipes; only the SDK's offered
choices/preview/commands perform actions. Original two-audience follower bytes
stay in .runtime. The compact generated inventory contains no credentials.
"""
import argparse
import asyncio
from collections import Counter
import json
from pathlib import Path
import socket
import sys

from dnd.content.characters.premades import FIGHTER_PREMADE_ID
from dnd.core.content.encounters import (EncounterDeploymentSpec, EncounterRecipe,
    EncounterRosterRecipe, PremadeCharacterRosterSource, RosterStartingDamage,
    RosterSpellGrant, RosterItemGrant, RosterItemPlacement)
from dnd.core.creature_types import DamageType
from dnd.core.equipment_types import BodyPart
from dnd.core.content.registration import get_content_declaration
from dnd.spells.catalog_content import SPELL_CONTENT_IDENTITY_BY_NAME
from dnd.player.audience import SeatAssignment
from dnd.spells.infernal import THAUMATURGY_SPELL_DECLARATION
from studio_capture import action, record
from devtools.player_server_acceptance.fixtures import combat_configuration

PROJECT = Path(__file__).resolve().parents[1]
DEFERRED = ('aid', 'bless', 'false_life', 'sacred_flame')
FAMILIES = {
    'acid_splash': 'Area / damage', 'chill_touch': 'Attached / damage',
    'eldritch_blast': 'Projectile / damage', 'fire_bolt': 'Projectile / damage',
    'fireball': 'Area / damage', 'guiding_bolt': 'Projectile / condition',
    'ice_knife': 'Projectile / area', 'magic_missile': 'Repeated delivery',
    'poison_spray': 'Spray / damage', 'produce_flame': 'Projectile / damage',
    'ray_of_frost': 'Projectile / condition', 'scorching_ray': 'Repeated delivery',
    'sleep': 'Area / condition', 'web': 'Area / concentration',
    'bane': 'Condition / concentration', 'command': 'Condition / commanded turn',
    'mage_armor': 'Persistent protection', 'sanctuary': 'Protection / removal',
    'shield': 'Reaction / blocked damage', 'shocking_grasp': 'Touch / damage',
    'burning_hands': 'Cone / damage', 'thunderwave': 'Area / forced movement',
    'cure_wounds': 'Touch / healing', 'healing_word': 'Ranged / healing',
    'guidance': 'Condition / concentration', 'resistance': 'Condition / concentration',
    'light': 'Light / concentration', 'thaumaturgy': 'Self / sign',
    'shield_of_faith': 'Protection / concentration', 'true_strike': 'Weapon / spell attack',
}
# Fixed reviewed outcomes. Earlier resisted/missed attempts remain in .runtime.
CASE_SEEDS = {key: 2 for key in ('acid_splash', 'poison_spray', 'bane', 'command', 'sleep',
    'burning_hands', 'thunderwave', 'guidance', 'light', 'thaumaturgy', 'shield_of_faith', 'web')}
CASE_SEEDS.update(mage_armor=3, true_strike=3)
SELF = {'mage_armor', 'sanctuary', 'cure_wounds', 'healing_word', 'guidance',
        'resistance', 'light', 'thaumaturgy', 'shield_of_faith'}
CONCENTRATION = {'bane', 'web', 'guidance', 'resistance', 'light', 'shield_of_faith'}
AREA = {'fireball', 'sleep', 'web', 'burning_hands', 'thunderwave'}
TOUCH = {'shocking_grasp', 'true_strike'}
NEAR = TOUCH | {'poison_spray', 'burning_hands', 'thunderwave'}


def setup(spell, output, seed):
    # The real Shield case needs its normal automatic reaction owner. Other
    # targets are an authored fighter (no Shield), never an edited HP/AC record.
    config = combat_configuration('magic_missile', output, seed)
    slots = list(config.recipe.roster_slots)
    target_position = (4, 7) if spell in TOUCH else (5, 7) if spell in NEAR else (8, 7)
    names = {key.lower().replace(' ', '_'): key for key in SPELL_CONTENT_IDENTITY_BY_NAME}
    name = names.get(spell, spell.replace('_', ' ').title())
    for i, slot in enumerate(slots):
        member = slot.roster.members[0]
        if i == 1 and spell != 'shield':
            member = member.model_copy(update={'source': PremadeCharacterRosterSource(premade_id=FIGHTER_PREMADE_ID)})
        effects = tuple(effect for effect in member.scenario_setup_effects if effect.kind != 'spell_grant')
        if i == 0 and spell != 'shield':
            ref = THAUMATURGY_SPELL_DECLARATION.ref if spell == 'thaumaturgy' else get_content_declaration(SPELL_CONTENT_IDENTITY_BY_NAME[name].spell_type).ref
            effects += (RosterSpellGrant(spell_refs=(ref,), caster_level=7),)
        if i == 0 and spell == 'mage_armor':
            effects += (RosterItemGrant(item_id='armor.leather', placement=RosterItemPlacement.INVENTORY),)
        if (i == 0 and spell in {'cure_wounds', 'healing_word'}) or (i == 1 and spell == 'sleep'):
            effects += (RosterStartingDamage(amount=15 if i == 0 else 35, damage_type=DamageType.FORCE),)
        member = member.model_copy(update={'scenario_setup_effects': effects,
            'display_name': 'Amber spell caster' if i == 0 else 'Blue spell recipient'})
        members = (member,)
        if i == 0 and spell in {'guidance', 'light'}:
            members += (member.model_copy(update={'member_id': 'unit_2', 'display_name': 'Amber spell recipient', 'deployment_role': 'amber_2',
                'source': PremadeCharacterRosterSource(premade_id=FIGHTER_PREMADE_ID), 'scenario_setup_effects': ()}),)
        roster = EncounterRosterRecipe.create(**{**slot.roster.model_dump(exclude={'recipe_digest', 'members'}), 'members': members})
        slots[i] = slot.model_copy(update={'roster': roster})
    zones = list(config.recipe.deployment.zones)
    zones[0] = zones[0].model_copy(update={'ordered_slots': ((3, 7), (4, 7)) if spell in {'guidance', 'light'} else ((3, 7),)})
    zones[1] = zones[1].model_copy(update={'ordered_slots': (target_position,)})
    deployment = EncounterDeploymentSpec.create(**{**config.recipe.deployment.model_dump(exclude={'content_digest', 'zones'}), 'zones': tuple(zones)})
    recipe = EncounterRecipe.create(**{**config.recipe.model_dump(exclude={'recipe_digest', 'deployment', 'roster_slots', 'opening_policy'}),
        'deployment': deployment, 'roster_slots': tuple(slots), 'opening_policy': config.recipe.opening_policy})
    # Existing assignments contain two blue members in the generic fixture.
    assignments = tuple(SeatAssignment(slot.roster_slot_id, tuple((slot.roster_slot_id, member.member_id) for member in slot.roster.members)) for slot in slots)
    config = config.model_copy(update={'recipe': recipe, 'assignments': assignments})
    cast = action('spell.magic_missile' if spell == 'shield' else 'spell.' + spell,
        actor_name='Amber spell caster')
    if spell in {'guidance', 'light'}:
        cast['subject_name'] = 'Amber spell recipient'
    elif spell in SELF:
        cast['self_target'] = True
    elif spell in {'burning_hands', 'thunderwave'}:
        cast['affected_position'] = list(target_position)
    elif spell in AREA:
        cast['position'] = list(target_position)
    else:
        cast['subject_name'] = 'Blue spell recipient'
    if spell in {'magic_missile', 'shield', 'scorching_ray', 'eldritch_blast'}:
        cast['recipients'] = [0, 0, 0] if spell != 'eldritch_blast' else [0, 0]
    steps = [cast]
    if spell in CONCENTRATION:
        steps.append(action('action.drop_concentration', actor_name='Amber spell caster'))
    elif spell == 'sanctuary':
        steps.append(action('spell.fire_bolt', actor_name='Amber spell caster', subject_name='Blue spell recipient'))
    elif spell == 'mage_armor':
        steps += [action('end_turn'), action('equip', actor_name='Amber spell caster', item_id='armor.leather', slot=BodyPart.BODY.value)]
    elif spell == 'sleep':
        steps += [action('end_turn'), action('spell.fire_bolt', actor_name='Amber spell caster', subject_name='Blue spell recipient')]
    elif spell == 'command':
        steps += [action('end_turn'), action('end_turn')]
    elif spell in {'shield', 'chill_touch', 'ray_of_frost', 'guiding_bolt', 'shocking_grasp'}:
        steps += [action('end_turn'), action('end_turn')]
        if spell == 'guiding_bolt': steps.append(action('end_turn'))
    return config, steps


def resource_path(path):
    return 'res://' + path.resolve().relative_to(PROJECT).as_posix()


def summarize(spell, output, result, seed):
    events, conditions, facts, behaviors = [], [], Counter(), Counter()
    for path in sorted((output/'amber/journal').glob('[0-9]' * 16 + '.json')):
        packet = json.loads(path.read_bytes())
        for lineage in packet.get('lineages', []):
            for event_offset, node in enumerate(lineage['events']):
                fact = node.get('fact')
                if fact is None or node['canceled']:
                    continue
                facts[fact['kind']] += 1
                if fact.get('behavior_id'):
                    behaviors[fact['behavior_id']] += 1
                if fact['kind'] not in {'spell', 'damage', 'heal', 'condition', 'forced_movement', 'life', 'attack', 'saving_throw', 'area_reach', 'spatial_effect_state'}:
                    continue
                identity = {'sequence': packet['cursor']['sequence'], 'lineage_uuid': lineage['lineage_uuid'], 'event_uuid': node['uuid'],
                    'event_offset': event_offset, 'fact': fact}
                events.append(identity)
                if fact['kind'] == 'condition':
                    conditions.append(identity)
    relevant = [row for row in events if row['fact'].get('behavior_id') == 'spell.'+spell]
    # Shield is an automatic reaction with a native reaction identity, not an
    # invented clickable action. Its condition carries its authoritative owner.
    if spell == 'shield':
        relevant = [row for row in conditions if row['fact']['condition'].get('behavior_id') == 'condition.spell.shield']
    failures = [] if result['ok'] else [result['failure']]
    if not relevant:
        failures.append('No uncanceled public spell/reaction evidence for '+spell)
    title = spell.replace('_', ' ').title()
    return {'id': 'native-spell-'+spell, 'spell_id': spell, 'label': title,
        'capability': 'Spell composition', 'interaction': FAMILIES[spell], 'seed': seed,
        'descriptor': resource_path(output/'capture-result.json'),
        'perspectives': [{'id': side, 'label': side.capitalize(), 'journal': resource_path(output/side/'journal')} for side in ('amber', 'blue')],
        'qualification': 'Original server follower packets; legal SDK commands. Fact coverage only, not native rendering or artistic approval.',
        'checks': 2, 'failures': failures, 'facts': dict(facts), 'behaviors': dict(behaviors),
        'sequence': [entry['request']['behavior'].removeprefix('spell.').replace('_', ' ').capitalize()+' · '+entry['seat'].capitalize() for entry in result['commands']],
        'events': events, 'conditions': conditions,
        'condition_lifecycle': dict(Counter(row['fact']['event_type'] for row in conditions)),
        'applied_damage': sum(row['fact'].get('applied_damage', 0) for row in events if row['fact']['kind'] == 'damage' and row['fact'].get('stage') == 'applied')}


async def capture(spell, args):
    seed = args.seed if args.seed is not None else CASE_SEEDS.get(spell, 3)
    suffix = '-lifecycle' if spell in {'mage_armor', 'guiding_bolt', 'shocking_grasp'} else ''
    output = args.output.resolve() / (spell+suffix+'-seed'+str(seed))
    existing = output/'capture-result.json'
    if existing.exists() and args.resume:
        result = json.loads(existing.read_text())
    else:
        output.mkdir(parents=True, exist_ok=False)
        config, steps = setup(spell, output, seed)
        config_path = output/'server.json'; config_path.write_text(config.model_dump_json(indent=2)); config_path.chmod(0o600)
        with socket.socket() as sock:
            sock.bind(('127.0.0.1', 0)); port = sock.getsockname()[1]
        with (output/'server.log').open('wb') as log:
            host = await asyncio.create_subprocess_exec(sys.executable, '-m', 'devtools.player_server_acceptance.test_host',
                '--config', str(config_path), '--stop', str(output/'server.stop'), '--result', str(output/'host-result.json'), '--port', str(port),
                cwd=args.engine, stdout=log, stderr=log)
            try:
                async with asyncio.timeout(90):
                    while not (output/'host.ready').exists():
                        if host.returncode is not None:
                            raise RuntimeError('Owned server failed: '+str(output/'server.log'))
                        await asyncio.sleep(.05)
                async with asyncio.timeout(180):
                    result = await record(config, 'http://127.0.0.1:'+str(port), output, steps)
            finally:
                (output/'server.stop').touch()
                await asyncio.wait_for(host.wait(), 25)
    row = summarize(spell, output, result, seed)
    print(json.dumps({'spell': spell, 'facts': row['facts'], 'failures': row['failures']}), flush=True)
    return row


async def run(args):
    wanted = args.spells.split(',') if args.spells else list(FAMILIES)
    unknown = set(wanted)-FAMILIES.keys()
    if unknown: raise ValueError('Unknown/deferred spells: '+str(sorted(unknown)))
    inventory = {'scope': 'Existing thirty native spell capabilities; real server recordings only.',
        'deferred': list(DEFERRED), 'cases': [], 'failures': []}
    if args.resume and args.inventory.exists():
        inventory = json.loads(args.inventory.read_text())
    rows = {row['spell_id']: row for row in inventory['cases']}
    for spell in wanted:
        rows[spell] = await capture(spell, args)
        inventory['cases'] = [rows[key] for key in FAMILIES if key in rows]
        inventory['failures'] = [{'spell_id': row['spell_id'], 'reason': failure} for row in inventory['cases'] for failure in row['failures']]
        args.inventory.parent.mkdir(parents=True, exist_ok=True)
        args.inventory.write_text(json.dumps(inventory, indent=2)+'\n')
    return 1 if inventory['failures'] else 0


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', type=Path, default=Path("/home/tommaso/.cache/ndclient/dnd_engine-9f81d5267"))
    parser.add_argument('--output', type=Path, default=PROJECT/'.runtime/studio-spells-20261015')
    parser.add_argument('--inventory', type=Path, default=PROJECT/'generated/studio_spell_case_inventory.json')
    parser.add_argument('--seed', type=int, help='Explicit diagnostic seed override; default is the reviewed per-case seed')
    parser.add_argument('--spells', help='Comma-separated finite subset; default all thirty')
    parser.add_argument('--resume', action='store_true')
    sys.exit(asyncio.run(run(parser.parse_args())))
