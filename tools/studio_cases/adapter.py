"""Engine adapter for the Studio case recorder: every engine, protocol and SDK call.

Scenario modules (spells.py, conditions.py, ...) name content ids, roles,
positions and steps only. This module turns a scenario into the engine's own
encounter recipe, owns the bounded test host, performs each step as legal SDK
choices/preview/commands and reads the recorded follower packets back. Current schema-16
commands and native occurrence facts are the only supported wire path.

Nothing is injected or rewritten: ordinary setup uses published encounter recipe edits
(roster sources, spell/item/behavior grants, starting damage/conditions,
damage affinities, battlefield and deployment); every later action is an
offered choice. Ordinary recipes retain both original faction journals byte for byte;
existing direct-build skirmishes expose only their real party seat.

Runs under the engine's Python with the engine and its sdk/python/src on
PYTHONPATH; record.py arranges that.
"""
import asyncio
from collections import Counter
import json
import os
from pathlib import Path
import secrets
import signal
import socket
import subprocess
import sys
from uuid import uuid4
from dnd_player.transport import ApiError, headers
from httpx import HTTPStatusError

from dnd.scenarios.encounter_assembler import _SPELL_ROW_BY_REF
from dnd.core.content.encounters import AuthoredCreatureRosterSource, EncounterRosterMember, PremadeCharacterRosterSource, RosterBehaviorGrant, RosterDamageAffinity, RosterItemGrant, RosterItemPlacement, RosterSpellGrant, RosterStartingCondition, RosterStartingDamage, DamageAffinityStatus
from dnd.core.content.recipes import ContentRecipe
from dnd.core.creature_types import DamageType
from dnd.core.equipment_types import BodyPart, WeaponSlot
from dnd.core.content.encounters import EncounterDeploymentSpec, EncounterDeploymentZone, EncounterRecipe, EncounterRosterRecipe, EncounterRosterSlot, FixedRosterOpeningPolicy, RosterControllerDefaults, RosterControllerKind
from dnd.player.audience import SeatAssignment
from server.config import SeatCredential, ServerConfig
from dnd_player import attach, connect
from dnd_player import Follower, acknowledge, action_options, all_actions, binding_position, binding_subject, choices, follow, next_options, preview, preview_positions, receipt, selection_for, status, submit_command, wait_for_cursor
from dnd.player.reduction import reduce_initialization, reduce_operation
from server.protocol import InitializationResponse, PlayerOperation
from dnd.content_system.bootstrap import bootstrap_content_system
from dnd.content.characters.build_types import CharacterBuild
from pydantic import TypeAdapter

PROJECT = Path(__file__).resolve().parents[2]
SIDES = ('amber', 'blue')
PREMADES = {'fighter': 'hero.fighter_l5_shield_torch', 'barbarian': 'hero.barbarian_l5_berserker_torch',
    'paladin': 'hero.paladin_l5_devotion', 'cleric': 'hero.cleric_l5_life', 'wizard': 'hero.wizard_l5_evocation',
    'sorcerer': 'hero.sorcerer_l5_standard_torch', 'spellblade': 'hero.fighter_2_sorcerer_3_spellblade'}
CONCENTRATION = 'condition.concentrating'
# Fact kinds that are presentation moments (others: turn, sensory, spatial, step, ...).
MOMENT_KINDS = {'spell', 'action', 'attack', 'damage', 'heal', 'saving_throw', 'life', 'death_save', 'forced_movement',
    'movement', 'shove', 'temporary_hit_points', 'spatial_effect_state', 'object_destroyed', 'object_damage', 'mechanism_activation',
    'portal_transfer', 'equipment', 'item_charge', 'item_effect', 'faction', 'area_reach'}


# --- engine identity and the ids it can send ---------------------------------

def engine_identity(engine):
    """Commit, protocol and schema of an engine copy (git checkout or exported pinned copy)."""
    engine = Path(engine)
    identity = json.loads((engine/'sdk/protocol/protocol-identity.json').read_text())
    commit = subprocess.run(['git', '--no-optional-locks', '-C', str(engine), 'rev-parse', 'HEAD'], capture_output=True, text=True).stdout.strip()
    provenance = json.loads((engine/'.source.json').read_text()) if (engine/'.source.json').exists() else {}
    commit = commit or provenance.get('commit', '')
    return {'path': str(engine), 'commit': commit, 'protocol_version': identity['protocol_version'],
        'player_schema_version': identity['player_schema_version'], 'schema_digest': identity['schema_digest']}


def list_engine_ids(engine):
    """Every content id this engine can send, in authoring/server_ids.json's shape.

    tools/snapshot_server_ids.py reads the registries through calls the
    frozen current engine has; it runs in a child interpreter so
    its package walk never touches this process. The header commit comes from
    engine_identity (an exported pinned copy has no git metadata)."""
    result = subprocess.run([sys.executable, '-B', str(PROJECT/'tools/snapshot_server_ids.py'), '--extract', '--engine', str(engine)],
        cwd=engine, env=dict(os.environ, PYTHONDONTWRITEBYTECODE='1'), capture_output=True, text=True, timeout=600)
    if result.returncode: raise RuntimeError('Engine id listing failed:\n'+result.stderr[-4000:])
    data = json.loads(result.stdout)
    data['header'].update({key: value for key, value in engine_identity(engine).items() if key != 'path'}, engine=str(engine),
        generator='tools/studio_cases/adapter.py (tools/snapshot_server_ids.py --extract)')
    return data


_DECLARATIONS = None

def declarations():
    """content_id -> registry declaration of the running engine."""
    global _DECLARATIONS
    if _DECLARATIONS is None:
        _DECLARATIONS = {d.ref.content_id: d for d in bootstrap_content_system().registry.declarations.values()}
    return _DECLARATIONS


def ref(content_id):
    declaration = declarations().get(content_id)
    if declaration is None: raise KeyError('The engine has no content '+content_id)
    return declaration.ref


def grantable_spells():
    """Spell ids an encounter spell grant can register (the rest are reactions, item powers or fixtures)."""
    return {key.split(':', 2)[2].rsplit('@', 1)[0] for key, row in _SPELL_ROW_BY_REF.items() if row.spell_type is not None}


# --- scenario -> encounter recipe ----------------------------------------------

def actor_name(side, role):
    return side.title()+' '+role.replace('_', ' ')


def _member(actor, index):
    if 'premade' in actor:
        source = PremadeCharacterRosterSource(premade_id=PREMADES.get(actor['premade'], actor['premade']))
    else:
        parameters = dict(actor.get('parameters', {}))
        if 'level' in actor: parameters['level'] = actor['level']
        source = AuthoredCreatureRosterSource(recipe=ContentRecipe.create(ref=ref(actor['creature']), parameters=parameters))
    effects = []
    if actor.get('spells'):
        effects.append(RosterSpellGrant(spell_refs=tuple(ref(spell) for spell in actor['spells']), caster_level=actor.get('caster_level', actor.get('level', 9))))
    for behavior in actor.get('behaviors', ()):
        effects.append(RosterBehaviorGrant(behavior_ref=ref(behavior)))
    for item in actor.get('items', ()):
        item = {'id': item} if isinstance(item, str) else item
        slot = item.get('slot')
        slot = None if slot is None else (WeaponSlot[slot] if slot in WeaponSlot.__members__ else BodyPart(slot))
        placement = RosterItemPlacement(item.get('placement', 'equipped' if slot is not None else 'inventory'))
        effects.append(RosterItemGrant(item_id=item['id'], count=item.get('count', 1), placement=placement, equipment_slot=slot,
            replace_existing=item.get('replace', slot is not None), on_grant='ignite' if item.get('ignite') else 'none',
            **{key: item[key] for key in ('heal_amount', 'cast_level', 'charges') if key in item}))
    for condition in actor.get('conditions', ()):
        effects.append(RosterStartingCondition(condition_ref=ref(condition)))
    if actor.get('damage'):
        amount, kind = (actor['damage'], 'force') if isinstance(actor['damage'], int) else actor['damage']
        effects.append(RosterStartingDamage(amount=amount, damage_type=DamageType(kind.capitalize() if kind.islower() else kind)))
    for status, kind in actor.get('affinities', ()):
        effects.append(RosterDamageAffinity(status=DamageAffinityStatus(status), damage_type=DamageType(kind.capitalize()), label=status.title()+' to '+kind))
    return EncounterRosterMember(member_id=f'unit_{index}', display_name=actor_name(actor['side'], actor['role']),
        deployment_role=f"{actor['side']}_{index}", source=source, scenario_setup_effects=tuple(effects))


def configuration(scenario, seed, work):
    """Native recipe seats or the existing direct-character party, with exact named roles."""
    if scenario.get('player_builds_source'):
        # Existing native direct-character deployment has one real party seat
        # and native AI opponents. It cannot claim a second faction journal.
        build_path = PROJECT/scenario['player_builds_source']
        builds = TypeAdapter(tuple[CharacterBuild, ...]).validate_json(build_path.read_bytes())
        game = 'studio_'+''.join(c if c.isalnum() else '_' for c in scenario['id'])[:100]
        return ServerConfig(game_id=game, encounter_id=None, player_builds=builds,
            credentials=(SeatCredential(seat_id='party',token=secrets.token_urlsafe(32)),),
            spool_directory=work/'spool',test_seed=seed)
    battlefield = scenario.get('battlefield', 'battlefield.open_floor_bright')
    slots, zones, assignments = [], [], []
    for side in SIDES:
        actors = [actor for actor in scenario['actors'] if actor['side'] == side]
        if not actors: raise ValueError('Every scenario needs an Amber and a Blue actor: '+scenario['id'])
        members = tuple(_member(actor, i) for i, actor in enumerate(actors, 1))
        roster = EncounterRosterRecipe.create(roster_id='roster.studio_'+side, title=side.title(), members=members)
        slots.append(EncounterRosterSlot(roster_slot_id=side, roster=roster, faction_id=side, deployment_zone_id=side,
            controller_defaults=RosterControllerDefaults(controller=RosterControllerKind.HUMAN, participant_name=side)))
        zones.append(EncounterDeploymentZone(zone_id=side, ordered_slots=tuple(tuple(actor['at']) for actor in actors)))
        assignments.append(SeatAssignment(side, tuple((side, member.member_id) for member in members)))
    deployment = EncounterDeploymentSpec.create(deployment_id='deployment.studio_case', title='Studio case', battlefield_id=battlefield, zones=tuple(zones))
    recipe = EncounterRecipe.create(encounter_id='encounter.studio_case', title=scenario.get('title', scenario['id'])[:120], battlefield_id=battlefield,
        deployment=deployment, roster_slots=tuple(slots), opening_policy=FixedRosterOpeningPolicy(roster_slot_id=scenario.get('first', 'amber')))
    game = 'studio_'+''.join(c if c.isalnum() else '_' for c in scenario['id'])[:100]
    return ServerConfig(game_id=game, encounter_id=None, recipe=recipe, assignments=tuple(assignments),
        credentials=tuple(SeatCredential(seat_id=side, token=secrets.token_urlsafe(32)) for side in SIDES),
        spool_directory=work/'spool', test_seed=seed)


# --- bounded owned host ------------------------------------------------------

def _kill_group(process):
    try: os.killpg(process.pid, signal.SIGKILL)
    except (ProcessLookupError, PermissionError): pass


async def hosted(engine, config, work, run, *, timeout=600, port=None):
    """Start the engine's test host for config, await run(url), stop it.

    The host and its worker run in their own process group, so a stuck or
    failed case never leaves an engine process behind."""
    config_path = work/'server.json'; config_path.write_text(config.model_dump_json(indent=2)); config_path.chmod(0o600)
    if port is None:
        with socket.socket() as sock:
            sock.bind(('127.0.0.1', 0)); port = sock.getsockname()[1]
    with (work/'server.log').open('wb') as log:
        host = await asyncio.create_subprocess_exec(sys.executable, '-m', 'devtools.player_server_acceptance.test_host',
            '--config', str(config_path), '--stop', str(work/'server.stop'), '--result', str(work/'host-result.json'), '--port', str(port),
            cwd=engine, stdout=log, stderr=log, start_new_session=True)
        (work/'host.pid').write_text(str(host.pid))
        try:
            async with asyncio.timeout(120):
                while not (work/'host.ready').exists():
                    if host.returncode is not None: raise RuntimeError('Engine host failed to start: '+(work/'server.log').read_text()[-1500:])
                    await asyncio.sleep(.05)
            async with asyncio.timeout(timeout):
                return await run('http://127.0.0.1:'+str(port))
        finally:
            (work/'server.stop').touch()
            try: await asyncio.wait_for(host.wait(), 25)
            except TimeoutError: pass
            _kill_group(host)
            await host.wait()


# --- reading recorded journals -------------------------------------------------

def packets(journal):
    for path in sorted(Path(journal).glob('[0-9]'*16+'.json')):
        yield json.loads(path.read_bytes())


def nodes(journal):
    """Original uncanceled native nodes, including explicit handler observations."""
    for packet in packets(journal):
        for lineage in packet.get('lineages', []):
            for offset, node in enumerate(lineage['events']):
                if not node.get('canceled',False):
                    yield packet['cursor']['sequence'], lineage['lineage'], offset, node


def facts(journal):
    """(sequence, native lineage, offset, node) for every uncanceled fact."""
    for values in nodes(journal):
        if values[3].get('fact') is not None:yield values


def initial_actors(journal):
    packet = json.loads((Path(journal)/('0'*16+'.json')).read_bytes())
    return {row['actor_uuid']: row['birth'] for row in packet['initialization'].get('bodies', []) if row.get('birth') is not None}


def journal_protocol(journal):
    return json.loads((Path(journal)/('0'*16+'.json')).read_bytes())['protocol']


def _uuid_fields(fact):
    return [fact.get(key) for key in ('source_entity_uuid', 'target_entity_uuid', 'entity_uuid')]


def condition_rows(node):
    fact = node['fact']
    if fact['kind'] != 'actor_change': return
    for actor in fact['actors']:
        for row in actor['rows']:
            if row['field'] == 'condition': yield actor['actor_uuid'], row


def moments(journal, names=None):
    """Jump points name actual native occurrences, never fabricated event UUIDs."""
    rows = []
    known_conditions = {}
    for sequence, lineage, offset, node in nodes(journal):
        base = {'sequence':sequence, 'occurrence':node['occurrence'], 'lineage':lineage, 'event_offset':offset}
        for attribution in node.get('content_attributions',[]):
            if attribution.get('role')=='effective_handler' and attribution.get('outcome')!='no_effect':
                rows.append({**base,'kind':'reaction_handler','label':attribution.get('handler_name') or attribution['behavior_id'],
                    'behavior_id':attribution['behavior_id'],'actor_uuid':attribution.get('source_entity_uuid'),
                    'triggering_occurrence':attribution.get('triggering_occurrence'),'triggering_lineage':attribution.get('triggering_lineage')})
        fact=node.get('fact')
        if fact is None:continue
        kind=fact['kind']
        if kind == 'actor_change':
            for actor, row in condition_rows(node):
                member = row.get('member')
                prior = known_conditions.get(row['condition_uuid'], {})
                if member is not None: known_conditions[row['condition_uuid']] = member
                else: known_conditions.pop(row['condition_uuid'], None)
                label = ('condition applied ' if member is not None else 'condition ended ')+str((member or prior).get('behavior_id') or row['condition_uuid'])
                rows.append({**base, 'label':label, 'kind':kind, 'actor_uuid':actor,
                    'condition_uuid':row['condition_uuid'], 'condition_id':(member or prior).get('behavior_id')})
        elif kind in MOMENT_KINDS:
            rows.append({**base, 'kind':kind, 'label':kind+' '+str(fact.get('behavior_id',''))})
    return rows


def journal_summary(journal):
    counted, behaviors, conditions = Counter(), Counter(), set()
    known={};ended=set()
    for _, _, _, node in nodes(journal):
        fact=node.get('fact') or {}
        identities={row['behavior_id'] for row in node.get('content_attributions',[])
            if row.get('role') in ('behavior','effective_handler') and row.get('outcome')!='no_effect' and row.get('behavior_id')}
        if fact.get('behavior_id'):identities.add(fact['behavior_id'])
        behaviors.update(identities)
        if not fact:continue
        counted[fact['kind']] += 1
        for _, row in condition_rows(node):
            member = row.get('member')
            if member and member.get('behavior_id'):
                conditions.add(member['behavior_id']);known[row['condition_uuid']]=member['behavior_id']
            elif member is None:
                previous=known.pop(row['condition_uuid'],None)
                if previous is not None:ended.add(previous)
    return {'facts':dict(counted), 'behaviors':dict(behaviors), 'conditions':sorted(conditions),'ended_conditions':sorted(ended)}


# --- SDK driver -----------------------------------------------------------------

async def open_seat(url, token, *, timeout=90):
    """Connect and attach one seat once its first publication exists; a failed worker raises at once."""
    async with asyncio.timeout(timeout):
        while True:
            connection = await connect(url, token)
            boundary = connection.bootstrap['status']['boundary']
            if boundary['lifecycle'] in ('failed', 'terminal', 'closed', 'closing'):
                await connection.http.aclose()
                raise CaseError('The engine could not start this encounter ('+boundary['lifecycle']+', '+str(boundary.get('reason'))+'); see server.log')
            if connection.bootstrap['status']['published_cursor'] is not None: break
            await connection.http.aclose(); await asyncio.sleep(.05)
    await attach(connection, {'acquisition_id': str(uuid4()), 'expected_attachment_epoch': connection.bootstrap['status']['attachment_epoch']})
    return connection


async def choices(connection, body):
    """Current trusted server query, retaining free-aim rows with empty sets.

    The frozen Python SDK's relation checker predates PositionRegion and rejects
    valid current rows. Keep its connection/auth/session and the actual wire
    request, without mutating that exported SDK or rebuilding targets.
    """
    response=await connection.http.post('/api/v1/games/'+connection.bootstrap['status']['game_id']+'/choices',
        headers=headers(connection),json=body)
    response.raise_for_status()
    result=response.json()
    if result['correlation_id']!=body['correlation_id'] or result['state_revision']!=body['state_revision'] or result['choices']['entity_uuid']!=body['actor_uuid']:
        raise CaseError('Choices correlation mismatch')
    return result


class CaseError(RuntimeError):
    pass


def _distance(a, b):
    return max(abs(a[0]-b[0]), abs(a[1]-b[1]))


async def drive(config, url, out, steps, scenario, *, command_limit=220):
    """Perform scenario steps as legal SDK commands; both seats' follower bytes land in out/<seat>/journal.

    Steps name roles ('caster', 'target', ...), never engine uuids. A step whose
    actor is not the current input actor first ends turns through the real
    initiative order. Returns the command trace, tracked-condition evidence and
    gaps (steps the engine rules made impossible, kept visible)."""
    roles = {actor['role']: actor_name(actor['side'], actor['role']) for actor in scenario['actors']}
    seats, trace, gaps, notes = [], [], [], []
    ctx = {'tracked': None, 'failure': None, 'commands': 0, 'main': None}

    def by_name(name):
        for seat in seats:
            for uuid, actor in seat['state'].actors.items():
                if actor.name == name: return str(uuid), actor
        return None, None

    def actor_of(role):
        return by_name(roles.get(role, role))

    def conditions_of(uuid):
        for seat in seats:
            for key, actor in seat['state'].actors.items():
                if str(key) == uuid: return [(row.behavior_id, str(row.condition_uuid)) for row in actor.conditions]
        return []

    def journal_facts():
        return list(facts(seats[0]['journal']))

    async def settle():
        for seat in seats:
            now = await status(seat['connection'])
            if now['published_cursor'] is not None: await wait_for_cursor(seat['follower'], now['published_cursor'])

    async def active(*, requested_name=None):
        async with asyncio.timeout(60):
            while True:
                outside_encounter = False
                for seat in seats:
                    now = await status(seat['connection'])
                    if now['published_cursor'] is not None: await wait_for_cursor(seat['follower'], now['published_cursor'])
                    if now['boundary']['lifecycle'] in ('terminal', 'failed', 'closed', 'closing'):
                        raise CaseError('Encounter ended ('+now['boundary']['lifecycle']+')')
                    if now['boundary']['lifecycle'] == 'outside_encounter':
                        # The existing SDK permits controlled actors' ordinary
                        # choices outside combat. Keep the exact requested role.
                        if requested_name is not None:
                            for identity in seat['controlled']:
                                if seat['names'].get(identity) == requested_name:return seat, now, identity
                        outside_encounter = True
                        continue
                    actor = now['boundary']['input_actor_uuid']
                    if actor is not None and actor in seat['controlled']: return seat, now, actor
                if outside_encounter:raise CaseError('Encounter ended; no requested controlled actor can take an input turn')
                await asyncio.sleep(.01)

    async def command(seat, now, actor, intent, evidence):
        if ctx['commands'] >= command_limit: raise CaseError('Command limit reached ('+str(command_limit)+')')
        ctx['commands'] += 1
        evidence['command_issued'] = True
        await acknowledge(seat['connection'], seat['follower'].consumed)
        body = {'command_number': now['next_command_number'], 'actor_uuid': actor, 'state_revision': now['boundary']['state_revision'], 'intent': intent}
        evidence.update(command=body, seat=seat['id'], actor=seat['names'].get(actor, actor))
        trace.append(evidence)
        result = await submit_command(seat['connection'], body)
        evidence['receipt'] = result['receipt']
        while result['receipt']['kind'] == 'pending':
            await asyncio.sleep(.01); result = await receipt(seat['connection'], body['command_number'])
            evidence['receipt'] = result['receipt']
        if result['receipt']['kind'] != 'committed': raise CaseError('Command rejected: '+json.dumps(result['receipt'])[:600])
        await wait_for_cursor(seat['follower'], result['receipt']['cursor'])
        await settle()
        return result['receipt']

    async def turn_of(role, *, waits=24):
        """End turns until role's actor has input; None when it never gets one (dead, removed)."""
        name = roles.get(role, role)
        for _ in range(waits):
            seat, now, actor = await active(requested_name=name)
            if seat['names'].get(actor) == name: return seat, now, actor
            await command(seat, now, actor, {'kind': 'end_turn'}, {'request': {'do': 'end_turn', 'waiting_for': role}})
        return None

    def offered_rows(discovered, step, actor):
        behavior = step['do']
        rows = [row for row in all_actions(discovered) if row['behavior_id'] == behavior and row['can_afford']
            and row.get('availability_status') == 'available' and (action_options(discovered, row) or row.get('position_region') is not None)]
        if 'level' in step: rows = [row for row in rows if step['level'] in row.get('cast_levels', [row.get('cast_at_level')])]
        if 'variant' in step:
            rows = [row for row in rows if all(any(f['key'] == key and f['value'] == value for f in row.get('variant_facets', [])) for key, value in step['variant'].items())]
        for key in ('weapon_slot',):
            if key in step: rows = [row for row in rows if row.get(key) == step[key]]
        if 'name' in step: rows = [row for row in rows if step['name'].lower() in row['display_name'].lower()]
        if 'item' in step:
            uuids = {item['item_uuid'] for item in (seats_items(actor)) if item['item_id'] == step['item']}
            rows = [row for row in rows if row.get('source_item_uuid') in uuids or row.get('loot_item_uuid') in uuids]
        return rows

    def seats_items(actor):
        for seat in seats:
            for key, row in seat['state'].actors.items():
                if str(key) == actor and row.controlled_items:
                    return [{'item_uuid':str(uuid), 'item_id':seat['state'].items[uuid].look.item_id} for uuid in row.controlled_items]
        return []

    def subject_matches(domains, binding, wanted, actor, row=None):
        subject = binding_subject(domains, binding) or {}
        if wanted == 'first_legal': return True
        if wanted == 'self': return binding['kind'] == 'self' or subject.get('uuid') == actor
        if isinstance(wanted, dict) and 'object' in wanted:
            if row is not None and row.get('interaction_affordance',{}).get('binding')=='source_item':
                for observed in seats:
                    if actor not in observed['controlled']:continue
                    for identity,value in observed['state'].objects.items():
                        if str(identity)==row.get('source_item_uuid'):
                            return wanted['object'].lower() in value.item.name.lower()
                return False
            return subject.get('kind') == 'object' and wanted['object'].lower() in (subject.get('name') or '').lower()
        if isinstance(wanted, str): return subject.get('name') == roles.get(wanted, wanted)
        return False

    def position_of(role):
        uuid, row = actor_of(role)
        return None if row is None else list(row.last_visual_position)

    def resolve_position(where):
        if isinstance(where, (list, tuple)): return list(where)
        if isinstance(where, str): return position_of(where)
        base = position_of(where['near']) if 'near' in where else list(where['at'])
        if base is None: return None
        dx, dy = where.get('offset', (0, 0))
        return [base[0]+dx, base[1]+dy]

    async def perform(step):
        # A status may be superseded while its follower catches up. Re-discover
        # only an explicitly stale read; submitted commands are never repeated.
        for attempt in range(3):
            evidence = {'request': step, 'previews': 0}
            try:
                return await perform_attempt(step, evidence)
            except (ApiError, HTTPStatusError) as error:
                response = error.value if isinstance(error, ApiError) else error.response.json()
                if response.get('code') != 'stale_state' or evidence.get('command_issued') or attempt == 2:
                    raise
                notes.append({'step':step, 'discovery_retry':attempt+1, 'rejected_response':response,
                    'stage':evidence.get('stage'), 'query_revision':evidence.get('query_revision'),
                    'discovery_generation':evidence.get('discovery_generation'),
                    'reason':'Read-only discovery rejected as stale_state before command submission'})

    async def perform_attempt(step, evidence):
        seat_now = await turn_of(step['by']) if step.get('by') else await active()
        if seat_now is None:
            raise CaseError((step.get('by') or 'actor')+' never had the required turn')
        seat, now, actor = seat_now
        if step['do'] == 'end_turn':
            return await command(seat, now, actor, {'kind': 'end_turn'}, evidence)
        if step['do'] in ('equip', 'unequip'):
            if step['do'] == 'unequip': return await command(seat, now, actor, {'kind': 'unequip', 'item': {'slot': step['slot']}}, evidence)
            items = [item for item in seats_items(actor) if item['item_id'] == step['item']]
            if not items: raise CaseError('No observed item to equip: '+step['item'])
            return await command(seat, now, actor, {'kind': 'equip', 'item': {'item_uuid': items[0]['item_uuid'], 'slot': step['slot']}}, evidence)
        revision = now['boundary']['state_revision']
        evidence.update(stage='choices', query_revision=revision)
        discovered = (await choices(seat['connection'], {'actor_uuid': actor, 'state_revision': revision, 'force_attack': False, 'correlation_id': str(uuid4())}))['choices']
        evidence['discovery_generation'] = discovered['discovery_generation']
        if step['do'] == 'toggle_handler':
            handler = next((row for row in discovered.get('handler_details', []) if row['behavior_id'] == step['handler'] or step['handler'] in row['name'].lower()), None)
            if handler is None: raise CaseError('No toggleable handler '+step['handler'])
            return await command(seat, now, actor, {'kind': 'toggle_handler', 'discovery_generation': discovered['discovery_generation'],
                'handler': {'handler_uuid': handler['uuid'], 'enabled': step.get('enabled', False)}}, evidence)
        if step.get('capture_choices'):
            (out/'choices.json').write_text(json.dumps(discovered,indent=1)+'\n')
        rows = offered_rows(discovered, step, actor)
        if step.get('expect_unavailable'):
            evidence['unavailable'] = not rows; trace.append(evidence)
            if rows: raise CaseError('Expected '+step['do']+' to be unavailable')
            return None
        if not rows:
            known = sorted({row['behavior_id']+':'+row.get('availability_status', '') for row in all_actions(discovered) if row['behavior_id'] == step['do']})
            reason = 'Not offered to '+seat['names'].get(actor, actor)+': '+step['do']+(' ('+', '.join(known)+')' if known else ' (no such action)')
            raise CaseError(reason)
        wanted = step.get('target')
        if wanted is not None and wanted!='first_legal':
            matching=[]
            for candidate in rows:
                if candidate.get('position_region') is not None:
                    matching.append(candidate);continue
                options=action_options(discovered,candidate)
                if isinstance(wanted,(list,dict)) and 'object' not in wanted:
                    spot=resolve_position(wanted)
                    if any(binding_position(discovered,option)==spot for option in options) or (candidate.get('connector_traversal') or {}).get('command',{}).get('destination_position')==spot:matching.append(candidate)
                elif any(subject_matches(discovered,option,wanted,actor,candidate) for option in options):matching.append(candidate)
            if matching:rows=matching
        row = min(rows, key=lambda value: (value.get('cast_at_level') or 0, value['discovery_index']))
        targets = list(action_options(discovered, row))
        if wanted is not None and not (isinstance(wanted, (list, dict)) and 'object' not in wanted):
            targets = [target for target in targets if subject_matches(discovered, target, wanted, actor,row)]
        elif wanted is not None:
            spot = resolve_position(wanted)
            connector = row.get('connector_traversal')
            exact = [target for target in targets if binding_position(discovered, target) == spot
                or (connector is not None and target['kind']=='self' and connector['command']['destination_position']==spot)]
            targets = exact
        if wanted=='first_legal':
            # The baseline explicitly requests the first legal recipient in
            # this authored role order; never invent or expand eligibility.
            order=[roles.get('target'),roles.get('ally'),roles.get('caster')]
            targets.sort(key=lambda option: order.index((binding_subject(discovered,option) or {}).get('name'))
                if (binding_subject(discovered,option) or {}).get('name') in order else len(order))
        free_aim = row.get('position_region') is not None
        if free_aim and wanted is None: raise CaseError('Free aim requires an explicit scenario position')
        if not targets and not free_aim:
            available=[binding_subject(discovered,option) or binding_position(discovered,option) for option in action_options(discovered,row)]
            raise CaseError('The offered '+step['do']+' has no requested target: '+json.dumps(wanted)+'; offered '+json.dumps(available))
        target = targets[0] if targets else None
        if 'affect' in step:
            # Aim an area so its affected cells include each named role (and avoid others when asked).
            goal = [position_of(role) for role in ([step['affect']] if isinstance(step['affect'], str) else step['affect'])]
            avoid = [position_of(role) for role in step.get('avoid', ())]
            candidates = [t for t in targets if binding_position(discovered, t) is not None] or targets
            candidates.sort(key=lambda t: min(_distance(binding_position(discovered, t) or goal[0], spot) for spot in goal if spot))
            target = None
            for candidate in candidates[:step.get('aim_tries', 48)]:
                evidence['stage']='preview_affect'
                aimed = (await preview(seat['connection'], {'actor_uuid': actor, 'state_revision': revision, 'discovery_generation': discovered['discovery_generation'],
                    'correlation_id': str(uuid4()), 'selection': selection_for(row, [candidate], prefer_safe=False)}))['preview']
                evidence['previews'] += 1
                affected = [list(p) for p in preview_positions(aimed, affected=True)]
                if aimed['can_confirm'] or next_options(aimed):
                    if all(spot in affected for spot in goal if spot) and not any(spot in affected for spot in avoid if spot):
                        target = candidate; break
            if target is None: raise CaseError('No offered aim of '+step['do']+' affects '+str(step['affect']))
        selected = selection_for(row, [] if free_aim else [target],
            extra_target_positions=([list(step['aim']) if wanted=='first_legal' else resolve_position(wanted)] if free_aim else [])+step.get('positions', []), prefer_safe=step.get('prefer_safe', False))
        if 'level' in step:selected['cast_at_level']=step['level']
        recipients = [roles.get(role, role) for role in step.get('recipients', [])]
        for _ in range(24):
            evidence['stage']='preview_'+str(evidence['previews']+1)
            result = (await preview(seat['connection'], {'actor_uuid': actor, 'state_revision': revision, 'discovery_generation': discovered['discovery_generation'],
                'correlation_id': str(uuid4()), 'selection': selected}))['preview']
            evidence['previews'] += 1
            if result['can_confirm'] and len(selected['target_indices']) >= max(0 if free_aim else 1, len(recipients)): break
            destinations=list(preview_positions(result))
            if step.get('then') is not None and not selected.get('extra_target_positions'):
                destination=resolve_position(step['then'])
                if destination in destinations:
                    selected['extra_target_positions']=[destination]
                    continue
            options = list(next_options(result))
            if not options:
                raise CaseError('Selection of '+step['do']+' cannot complete: '+str(result.get('reason')))
            offset = len(selected['target_indices'])
            choice = None
            if offset < len(recipients):
                choice = next((o for o in options if (binding_subject(result, o) or {}).get('name') == recipients[offset]), None)
            if choice is None and step.get('then') is not None:
                spot = resolve_position(step['then'])
                choice = next((option for option in options if binding_position(result,option)==spot),None)
            if choice is None and offset < len(recipients): raise CaseError('Requested recipient is not offered by Preview: '+recipients[offset])
            if choice is None and result['can_confirm']: break
            if choice is None: raise CaseError('Scenario must name the next recipient or position for '+step['do'])
            selected['target_indices'].append(choice['index'])
        else: raise CaseError('Selection of '+step['do']+' did not complete in 24 previews')
        evidence['selected_action'] = {key: row.get(key) for key in ('behavior_id', 'display_name', 'cast_at_level', 'variant_facets', 'target_type', 'weapon_slot')}
        evidence['outcome_resolution'] = (row.get('outcome_profile') or {}).get('resolution')
        before = len(journal_facts())
        intent = {'kind': 'execute_selection', 'discovery_generation': discovered['discovery_generation'], 'selection': selected}
        committed = await command(seat, now, actor, intent, evidence)
        if step.get('track'):
            ctx['main'] = {'actor_uuid': actor, 'step': step, 'after': before, 'target_uuid': actor_of(step['target'])[0] if isinstance(step.get('target'), str) and step['target'] != 'self' else actor if step.get('target') == 'self' else None}
            track(step, actor, before)
        return committed

    def track(step, actor, before):
        """The lasting condition the main step applied, preferring its named recipient."""
        rows = journal_facts()[before:]
        wanted = step.get('track_condition')
        target_uuid = ctx['main']['target_uuid']
        affected = [actor_of(role)[0] for role in ([step['affect']] if isinstance(step.get('affect'), str) else step.get('affect', []))]
        best = None
        for sequence, lineage, offset, node in rows:
            fact = node['fact']
            for holder, changed in condition_rows(node):
                member = changed.get('member')
                if member is None: continue
                behavior = member.get('behavior_id')
                if behavior == CONCENTRATION or (wanted and behavior != wanted): continue
                rank = (holder == target_uuid or holder in affected, holder != actor, bool(behavior and behavior.startswith('condition.spell.')))
                if best is None or rank > best[0]:
                    best = (rank, {'condition_id':behavior, 'condition_uuid':member['condition_uuid'], 'holder_uuid':holder,
                        'holder':next((seat['names'].get(holder) for seat in seats if holder in seat['names']),holder),
                        'occurrence':node['occurrence'], 'sequence':sequence})
        if best is not None: ctx['tracked'] = best[1]

    def tracked_on():
        tracked = ctx['tracked']
        return tracked is not None and tracked['condition_uuid'] in [uuid for _, uuid in conditions_of(tracked['holder_uuid'])]

    def holder_role():
        tracked = ctx['tracked']
        if tracked is None: return ctx['main'] and ctx['main']['step'].get('target') if isinstance(ctx['main'] and ctx['main']['step'].get('target'), str) else None
        return next((role for role, name in roles.items() if name == tracked['holder']), tracked['holder'])

    async def walk(role, offset, label):
        if role in (None, 'self'): role = ctx['main']['step']['by'] if ctx['main'] else None
        if role is None: return
        uuid, row = actor_of(role)
        if row is None or row.life_state.value != 'alive':
            gaps.append({'step': label, 'reason': role+' is not alive'}); return
        seat_now = await turn_of(role)
        if seat_now is None: gaps.append({'step': label, 'reason': role+' never had a turn'}); return
        seat, now, actor = seat_now
        discovered = (await choices(seat['connection'], {'actor_uuid': actor, 'state_revision': now['boundary']['state_revision'], 'force_attack': False, 'correlation_id': str(uuid4())}))['choices']
        moves = [r for r in all_actions(discovered) if r['behavior_id'] == 'action.move' and r['can_afford'] and r.get('availability_status') == 'available' and action_options(discovered, r)
            and any(f['value'] == 'walking' for f in r.get('variant_facets', [{'key': 'movement', 'value': 'walking'}]))]
        if not moves:
            gaps.append({'step': label, 'reason': role+' has no movement (condition or rules deny it)', 'remaining_movement': discovered.get('remaining_movement')}); return
        start = list(row.last_visual_position)
        spot = [start[0]+offset[0], start[1]+offset[1]]
        targets = [t for t in action_options(discovered, moves[0]) if binding_position(discovered, t) is not None]
        targets = [target for target in targets if binding_position(discovered, target)==spot]
        if not targets or binding_position(discovered, targets[0]) == start:
            gaps.append({'step': label, 'reason': role+' cannot reach any cell toward '+str(spot)}); return
        selected = selection_for(moves[0], [targets[0]], prefer_safe=True)
        await command(seat, now, actor, {'kind': 'execute_selection', 'discovery_generation': discovered['discovery_generation'], 'selection': selected},
            {'request': {'do': 'action.move', 'by': role, 'phase': label, 'to': binding_position(discovered, targets[0])}})

    async def end_tracked(step):
        tracked = ctx['tracked']
        if tracked is None or not tracked_on(): return
        main = ctx['main']
        caster = main['step']['by']
        caster_uuid = actor_of(caster)[0]
        strategy = step.get('strategy', 'auto')
        concentrating = any(behavior == CONCENTRATION for behavior, _ in conditions_of(caster_uuid))
        if strategy in ('auto', 'concentration') and concentrating and not step.get('prefer_turns'):
            seat_now = await turn_of(caster)
            if seat_now is not None and tracked_on():
                await perform({'do': 'action.drop_concentration', 'by': caster, 'target': 'self', 'optional': False})
            if not tracked_on(): return
        for _ in range(step.get('max_turns', 40)):
            if not tracked_on(): return
            seat, now, actor = await active()
            await command(seat, now, actor, {'kind': 'end_turn'}, {'request': {'do': 'end_turn', 'until_removed': tracked['condition_id']}})
        if tracked_on(): raise CaseError('The tracked condition '+str(tracked['condition_id'])+' did not end within '+str(step.get('max_turns', 40))+' ended turns')

    async def wait_condition(step):
        """Advance ordinary turns until the named observed condition is present.

        This records real delayed rule outcomes such as Flesh to Stone's saves;
        it never creates a condition or replaces a failed outcome with a cast.
        """
        holder, _ = actor_of(step['target'])
        if holder is None: raise CaseError('Condition recipient is not observed: '+step['target'])
        for ended in range(step.get('max_turns', 24)+1):
            if any(behavior == step['condition'] for behavior, _ in conditions_of(holder)):
                notes.append({'step':'wait_condition', 'target':step['target'], 'condition':step['condition'], 'ended_turns':ended})
                return
            if ended == step.get('max_turns', 24): break
            if step.get('while_condition') and not any(behavior == step['while_condition'] for behavior, _ in conditions_of(holder)):
                raise CaseError('The prerequisite '+step['while_condition']+' ended before '+step['condition'])
            seat, now, actor = await active()
            await command(seat, now, actor, {'kind':'end_turn'},
                {'request':{'do':'end_turn', 'until_condition':step['condition'], 'target':step['target']}})
        raise CaseError('No observed '+step['condition']+' after '+str(step.get('max_turns', 24))+' ended turns')

    try:
        for credential in config.credentials:
            connection = await open_seat(url, credential.token)
            journal = out/credential.seat_id/'journal'; journal.mkdir(parents=True, exist_ok=True)
            seat = {'id': credential.seat_id, 'connection': connection, 'journal': journal, 'controlled': set(), 'names': {}, 'state': None}
            async def consume(packet, raw, owner=seat):
                path = owner['journal']/f"{packet['cursor']['sequence']:016}.json"
                if path.exists() and path.read_bytes() != raw: raise RuntimeError('Replay changed original packet bytes')
                path.write_bytes(raw)
                if packet['cursor']['sequence'] == 0:
                    owner['controlled'] = set(packet['initialization']['audience']['controlled'])
                    decoded = InitializationResponse.model_validate_json(raw)
                    owner['state'] = reduce_initialization(decoded.initialization, content_additions=decoded.content_additions)
                else:
                    owner['state'] = reduce_operation(owner['state'], PlayerOperation.model_validate_json(raw))
                for key, row in owner['state'].actors.items(): owner['names'].setdefault(str(key), row.name)
            seat['follower'] = Follower(connection, consume)
            seat['task'] = asyncio.create_task(follow(seat['follower']))
            seats.append(seat)
        await settle()
        for step in steps:
            if step['do'] == 'hold_walk':
                if tracked_on(): await walk(holder_role(), step.get('offset', (0, 3)), 'hold')
                elif ctx['tracked'] is not None: gaps.append({'step': 'hold', 'reason': 'The tracked condition ended before its holder could walk'})
            elif step['do'] == 'end_tracked': await end_tracked(step)
            elif step['do'] == 'wait_condition': await wait_condition(step)
            elif step['do'] == 'tail_walk':
                if ctx['tracked'] is None or not tracked_on(): await walk(step.get('by') or holder_role() or step.get('fallback'), step.get('offset', (3, 0)), 'tail')
            else: await perform(step)
    except Exception as error:
        ctx['failure'] = f'{type(error).__name__}: {error}'
    finally:
        (out/'commands.json').write_text(json.dumps(trace, indent=1, default=str))
        for seat in seats:
            try:
                async with asyncio.timeout(5):
                    current = await status(seat['connection'])
                    if current['published_cursor'] is not None: await wait_for_cursor(seat['follower'], current['published_cursor'])
            except Exception as error:
                ctx['failure'] = ctx['failure'] or f'Final cursor: {error}'
            seat['task'].cancel()
        await asyncio.gather(*(seat['task'] for seat in seats), return_exceptions=True)
        for seat in seats: await seat['connection'].http.aclose()
    (out/'commands.json').write_text(json.dumps(trace, indent=1, default=str))
    return {'ok': ctx['failure'] is None and not gaps, 'failure': ctx['failure'], 'commands': len(trace), 'tracked': ctx['tracked'], 'gaps': gaps, 'notes': notes,
        'names': {uuid: name for seat in seats for uuid, name in seat['names'].items()}, 'roles': roles,
        'sequence': [row['request'].get('do', '')+' · '+row.get('actor', '') for row in trace if 'command' in row]}


async def discover(engine, scenario, work, *, timeout=300):
    """Every action row the engine offers each human-controlled actor at its first turn (no command beyond end_turn)."""
    config = configuration(scenario, 1, work)
    async def run(url):
        rows = {}
        connections = []
        for credential in config.credentials:
            connections.append(await open_seat(url, credential.token))
        seen = set()
        for _ in range(len(scenario['actors'])+2):
            for connection in connections:
                now = await status(connection)
                actor = now['boundary']['input_actor_uuid']
                if actor is None or actor in seen: continue
                await acknowledge(connection, now['published_cursor'])
                discovered = (await choices(connection, {'actor_uuid': actor, 'state_revision': now['boundary']['state_revision'], 'force_attack': False, 'correlation_id': str(uuid4())}))['choices']
                if not discovered: continue
                seen.add(actor)
                name = next((s.get('name') for s in discovered.get('subjects', []) if s['uuid'] == actor), actor)
                out = rows.setdefault(name, [])
                for row in all_actions(discovered):
                    profile = row.get('outcome_profile') or {}
                    out.append({key: row.get(key) for key in ('behavior_id', 'display_name', 'target_type', 'cast_at_level', 'spell_level',
                        'variant_facets', 'availability_status', 'can_afford', 'requires_concentration', 'num_projectiles', 'area_target_filter', 'provided_by_id',
                        'origin_root_id', 'action_category', 'is_item_use', 'fixed_healing', 'cost_type')} | {
                        'resolution': profile.get('resolution'), 'save_ability': profile.get('save_ability'), 'damage': bool(profile.get('damage_rolls')),
                        'targets': len(action_options(discovered, row)), 'self_setup': bool(row.get('self_setup_profile')), 'target_effect': bool(row.get('target_effect_profile'))})
                for row in discovered.get('world_interactions', []):
                    out.append({'behavior_id': row['behavior_id'], 'display_name': row['label'], 'world_interaction': True, 'reason': row.get('reason')})
                for row in discovered.get('handler_details', []):
                    out.append({'behavior_id': row['behavior_id'], 'display_name': row['name'], 'handler': True, 'enabled': row['enabled'], 'trigger_event': row['trigger_event']})
                await acknowledge(connection, now['published_cursor'])
                body = {'command_number': now['next_command_number'], 'actor_uuid': actor, 'state_revision': now['boundary']['state_revision'], 'intent': {'kind': 'end_turn'}}
                result = await submit_command(connection, body)
                while result['receipt']['kind'] == 'pending':
                    await asyncio.sleep(.01); result = await receipt(connection, body['command_number'])
                await asyncio.sleep(.1)
        for connection in connections: await connection.http.aclose()
        return rows
    work.mkdir(parents=True, exist_ok=True)
    return await hosted(engine, config, work, run, timeout=timeout)
