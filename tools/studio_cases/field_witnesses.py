"""Public owner joins for the fixed Nimbus and wall continuation captures."""
import json

import adapter
from dnd.player.reduction import node_lineages, parent_lineages


def _read(out, perspective):
    journal = out/perspective/'journal'
    initial = adapter.InitializationResponse.model_validate_json((journal/('0'*16+'.json')).read_bytes())
    state = adapter.reduce_initialization(initial.initialization, content_additions=initial.content_additions)
    records, parents, names, objects = [], {}, {}, {}
    for path in sorted(journal.glob('[0-9]'*16+'.json')):
        if int(path.stem) == 0:
            continue
        raw = path.read_bytes()
        packet = json.loads(raw)
        operation = adapter.PlayerOperation.model_validate_json(raw)
        before = {str(identity): set(effect.positions) for identity, effect in
                  (state.senses.spatial_effects.items() if state.senses is not None else ())}
        first = len(records)
        for group, source in zip(operation.lineages, packet['lineages'], strict=True):
            parents.update(parent_lineages(group.events, group.version_rows))
            for node, lineage in zip(source['events'], node_lineages(group.events, group.version_rows), strict=True):
                if node.get('fact') is not None and node.get('phase') == 'completion' and not node.get('canceled'):
                    records.append({'sequence': int(path.stem), 'occurrence': node['occurrence'],
                                    'lineage': lineage, 'fact': node['fact']})
        state = adapter.reduce_operation(state, operation)
        # These are operation-boundary observations, not inferred hidden coverage
        # or a claim that every intermediate event saw the whole union.
        after = {str(identity): set(effect.positions) for identity, effect in
                 (state.senses.spatial_effects.items() if state.senses is not None else ())}
        for row in records[first:]:
            fact = row['fact']
            owner = fact.get('spatial_effect_uuid') or (fact.get('spatial_source') or {}).get('spatial_effect_uuid')
            if owner is not None:
                row['observed_positions'] = before.get(owner, set()) | after.get(owner, set())
        names.update({str(identity): actor.name for identity, actor in state.actors.items()})
        if state.senses is not None:
            for identity in state.senses.objects:
                if identity in state.objects:
                    objects.setdefault(str(identity), state.objects[identity])
    return records, parents, state, names, objects


def _descends(child, ancestor, parents):
    lineage = child['lineage']
    visited = set()
    while lineage in parents and lineage not in visited:
        visited.add(lineage)
        lineage = parents[lineage]
        if lineage == ancestor['lineage']:
            return True
    return False


def _mark(row):
    return {key: row[key] for key in ('sequence', 'occurrence', 'lineage')}


def nimbus_contact_evidence(out, scenario):
    records, parents, _, names, _ = _read(out, 'party')
    actor_name = adapter.actor_name('party', 'caster')
    casters = [identity for identity, name in names.items() if name == actor_name]
    if len(casters) != 1:
        return [], ['Nimbus requires one observed caster']
    caster = casters[0]
    activations = [row for row in records if row['fact'].get('behavior_id') == 'action.class.paladin.holy_nimbus'
                   and row['fact'].get('source_entity_uuid') == caster]
    turns = [row for row in records if row['fact'].get('kind') == 'turn'
             and row['fact'].get('event_type') == 'turn_start']
    active, evidence = {}, []
    for row in records:
        fact = row['fact']
        if fact['kind'] == 'actor_change':
            for actor in fact['actors']:
                if actor['actor_uuid'] != caster:
                    continue
                for change in actor['rows']:
                    if change['field'] != 'condition':
                        continue
                    identity = change['condition_uuid']
                    member = change.get('member')
                    if member is None:
                        active.pop(identity, None)
                    elif (member.get('behavior_id') == 'condition.class.paladin.holy_nimbus'
                          and any(_descends(row, activation, parents) for activation in activations)):
                        active[identity] = row
        identity = fact.get('source_condition_uuid')
        if (fact['kind'] != 'damage' or fact.get('stage') != 'applied' or fact.get('damage_type') != 'Radiant'
                or fact.get('applied_damage', 0) <= 0 or fact.get('source_entity_uuid') != caster or identity not in active):
            continue
        turn = next((turn for turn in turns if turn['fact'].get('entity_uuid') == fact['target_entity_uuid']
                     and _descends(row, turn, parents)), None)
        if turn is not None:
            evidence.append({'perspective': 'party', 'condition_uuid': identity, 'caster_uuid': caster,
                'target_uuid': fact['target_entity_uuid'], 'application': _mark(active[identity]),
                'turn_start': _mark(turn), 'damage': _mark(row), 'applied_damage': fact['applied_damage']})
    return evidence, [] if evidence else ['No positive Nimbus damage joins its active condition and recipient turn start']


def field_lifecycle_evidence(out, scenario):
    requirement = scenario['required_field_lifecycle']
    perspective = requirement['perspective']
    records, parents, state, names, objects = _read(out, perspective)
    roles = {actor['role']: adapter.actor_name(actor['side'], actor['role']) for actor in scenario['actors']}
    casters = [identity for identity, name in names.items() if name == roles['caster']]
    targets = [identity for identity, name in names.items() if name == roles['target']]
    if len(casters) != 1 or len(targets) != 1:
        return [], ['Field lifecycle requires its observed caster and recipient']
    caster, target = casters[0], targets[0]
    content = {str(identity): value.content_ref.content_id for identity, value in state.spatial_content.items()}
    if not requirement.get('ice_section'):
        caster_side = next(actor['side'] for actor in scenario['actors'] if actor['role'] == 'caster')
        caster_records, caster_parents, caster_state, _, _ = _read(out, caster_side)
        cursors = [json.loads((out/seat/'journal'/('0'*16+'.json')).read_bytes())['cursor']
                   for seat in (perspective, caster_side)]
        if any(cursors[0][key] != cursors[1][key] for key in ('game_id', 'game_epoch')):
            return [], ['Field lifecycle perspectives must belong to the same game and epoch']
        caster_content = {str(identity): value.content_ref.content_id for identity, value in caster_state.spatial_content.items()}
        casts = [row for row in caster_records if row['fact'].get('kind') == 'spell'
                 and row['fact'].get('behavior_id') == requirement['spell']
                 and row['fact'].get('source_entity_uuid') == caster]
    drops = [row for row in records if row['fact'].get('behavior_id') == 'action.drop_concentration'
             and row['fact'].get('source_entity_uuid') == caster]
    created = [row for row in records if row['fact'].get('kind') == 'spatial_effect_state'
               and row['fact'].get('operation') == 'created'
               and content.get(row['fact']['spatial_effect_uuid']) == requirement['content_id']]
    for creation in created:
        owner = creation['fact']['spatial_effect_uuid']
        cells = {tuple(position) for position in creation['fact'].get('positions', [])}
        origin = _ice_origin(creation, records, parents, content, objects, caster) if requirement.get('ice_section') else None
        if not cells or (requirement.get('ice_section') and origin is None):
            continue
        if origin is not None and origin['object_uuid'] in {str(identity) for identity in state.objects}:
            continue
        cast_creation = None
        if not requirement.get('ice_section'):
            cast_creation = next((row for row in caster_records
                if row['fact'].get('kind') == 'spatial_effect_state'
                and row['fact'].get('operation') == 'created' and row['fact'].get('spatial_effect_uuid') == owner
                and caster_content.get(owner) == requirement['content_id']
                and any(_descends(row, cast, caster_parents) for cast in casts)), None)
            if cast_creation is None:
                continue
        contacts = []
        for row in records:
            fact = row['fact']
            source = fact.get('spatial_source') or {}
            if (fact.get('kind') == 'damage' and fact.get('stage') == 'applied' and fact.get('applied_damage', 0) > 0
                    and fact.get('damage_type') == requirement['damage_type'] and fact.get('target_entity_uuid') == target
                    and source.get('spatial_effect_uuid') == owner
                    and tuple(source.get('position', [])) in row['observed_positions']
                    and row['occurrence'] > creation['occurrence']):
                contacts.append(row)
        if not set(requirement['exposures']) <= {row['fact']['spatial_source']['exposure'] for row in contacts}:
            continue
        removal = next((row for row in records if row['fact'].get('kind') == 'spatial_effect_state'
            and row['fact'].get('spatial_effect_uuid') == owner and row['fact'].get('operation') == 'removed'
            and row['occurrence'] > max(contact['occurrence'] for contact in contacts)
            and row['fact'].get('removed_positions')
            and {tuple(position) for position in row['fact']['removed_positions']} <= row['observed_positions']
            and any(_descends(row, drop, parents) for drop in drops)), None)
        if removal is None or state.senses is not None and owner in {str(identity) for identity in state.senses.spatial_effects}:
            continue
        evidence = {'perspective': perspective, 'spatial_effect_uuid': owner, 'content_id': requirement['content_id'],
            'creation': _mark(creation), 'positions': sorted(cells), 'removal': _mark(removal),
            'removed_positions': removal['fact']['removed_positions'],
            'contacts': [{**_mark(row), 'target_uuid': target, 'applied_damage': row['fact']['applied_damage'],
                          'operation_observed_positions': sorted(row['observed_positions']),
                          **row['fact']['spatial_source']} for row in contacts]}
        if cast_creation is not None:
            evidence['caster_creation'] = {'perspective': caster_side, **_mark(cast_creation)}
            evidence['cast'] = {'perspective': caster_side, **_mark(next(cast for cast in casts
                if _descends(cast_creation, cast, caster_parents)))}
        if origin is not None:
            evidence['section_destruction'] = origin
        return [evidence], []
    return [], [requirement['content_id'] + ': no exact creation/contact/concentration-removal owner join']


def _ice_origin(creation, records, parents, content, objects, caster):
    for destruction in records:
        fact = destruction['fact']
        if fact.get('kind') != 'object_destroyed' or fact.get('remains_disposition') != 'disintegrated':
            continue
        identity = fact['object_uuid']
        previous = fact.get('previous_item') or {}
        seen = objects.get(identity)
        if (seen is None or previous.get('item_uuid') != identity or fact.get('item_id') != 'spell_construction.ice.section'
                or content.get(previous.get('construction_owner_uuid')) != 'spatial_effect.spell.wall_of_ice'
                or str(seen.item.item_uuid) != identity or seen.item.item_id != fact['item_id']
                or previous.get('construction_owner_uuid') != str(seen.item.construction_owner_uuid)
                or fact['placement'] != seen.placement.model_dump(mode='json')
                or not _descends(creation, destruction, parents)):
            continue
        cells = {tuple(position) for position in creation['fact'].get('positions', [])}
        if cells != {tuple(support['position']) for support in fact['placement'].get('covered_supports', [])}:
            continue
        cast = next((row for row in records if row['fact'].get('kind') == 'spell'
            and row['fact'].get('behavior_id') == 'spell.disintegrate' and row['fact'].get('target_kind') == 'object'
            and row['fact'].get('source_entity_uuid') == caster and row['fact'].get('target_entity_uuid') == identity
            and row['fact'].get('target_position') == fact['placement']['position']
            and _descends(destruction, row, parents)), None)
        if cast is not None:
            return {'object_uuid': identity, 'wall_owner_uuid': previous['construction_owner_uuid'],
                    'placement': fact['placement'], 'disintegrate': _mark(cast), 'destruction': _mark(destruction)}
    return None
