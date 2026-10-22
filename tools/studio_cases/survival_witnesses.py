"""Join real survival outcomes for the recorder's two positive lifecycle cases."""
import adapter


def _read(out, perspective, scenario):
    journal = out / perspective / 'journal'
    patient = next(actor for actor in scenario['actors'] if actor['role'] == 'patient')
    name = adapter.actor_name(patient['side'], patient['role'])
    identities = [identity for identity, actor in adapter.initial_actors(journal).items()
                  if actor['name'] == name]
    if len(identities) != 1:
        return None, []
    return identities[0], [row for row in adapter.facts(journal)
                           if row[3].get('phase') == 'completion']


def _location(row):
    return {'sequence': row[0], 'lineage': row[1], 'occurrence': row[3]['occurrence']}


def _stabilization(records, patient):
    own = [row for row in records if row[3]['fact'].get('entity_uuid') == patient]
    dying = [row for row in own if row[3]['fact'].get('kind') == 'life'
             and row[3]['fact'].get('previous_state') == 'alive'
             and row[3]['fact'].get('new_state') == 'dying'
             and row[3]['fact'].get('reason') == 'damage']
    stable = [row for row in own if row[3]['fact'].get('kind') == 'life'
              and row[3]['fact'].get('previous_state') == 'dying'
              and row[3]['fact'].get('new_state') == 'stable'
              and row[3]['fact'].get('reason') == 'stabilization']
    for start in dying:
        for end in stable:
            if end[0] <= start[0]:
                continue
            saves = [row for row in own if start[0] < row[0] <= end[0]
                     and row[3]['fact'].get('kind') == 'death_save']
            successes = [row for row in saves if row[3]['fact'].get('succeeded') is True]
            failures = sum(2 if row[3]['fact']['natural_roll'] == 1 else 1
                           for row in saves if not row[3]['fact']['succeeded'])
            interrupted = any(row[3]['fact'].get('kind') == 'life'
                              and row[3]['fact'].get('new_state') in ('alive', 'dead')
                              and start[0] < row[0] <= end[0] for row in own)
            if (len(successes) != 3 or failures >= 3 or interrupted
                    or any(row[3]['fact']['natural_roll'] == 20 for row in saves)):
                continue
            final = successes[-1]
            if (final[0] != end[0] or final[1] != end[1]
                    or not end[3].get('turn_execution_id')
                    or final[3].get('turn_execution_id') != end[3]['turn_execution_id']
                    or end[3]['occurrence'] not in final[3].get('children_lineages', [])):
                continue
            return {'patient_uuid': patient, 'dying': _location(start),
                    'saves': [_location(row) for row in saves], 'stable': _location(end)}
    return None


def stabilization_evidence(out, perspectives, scenario):
    evidence, missing = [], []
    for perspective in perspectives:
        patient, records = _read(out, perspective, scenario)
        joined = _stabilization(records, patient) if patient else None
        if joined is None:
            missing.append(perspective + ': no third ordinary successful death save joined to this patient stabilization')
        else:
            evidence.append({'perspective': perspective, **joined})
    return evidence, missing


def _shove(records, patient):
    def fact(row):
        return row[3]['fact']

    shoves = [row for row in records if fact(row).get('kind') == 'shove'
              and fact(row).get('target_entity_uuid') == patient
              and fact(row).get('contest_success') is True]
    falls = [row for row in records if fact(row).get('kind') == 'forced_movement'
             and fact(row).get('target_entity_uuid') == patient
             and fact(row).get('landing_kind') == 'fall'
             and fact(row).get('drop_feet') == 10
             and fact(row).get('start_position') == [8, 4]
             and fact(row).get('end_position') == [9, 4]]
    for fall in falls:
        source = fact(fall)['source_entity_uuid']
        blocked = [row for row in shoves if row[0] < fall[0]
                   and fact(row).get('source_entity_uuid') == source
                   and fact(row).get('push_distance') == 0
                   and row[3].get('combat_log', {}).get('data', {}).get('blocked_by')]
        pushing = [row for row in shoves if row[0:2] == fall[0:2]
                   and fact(row).get('source_entity_uuid') == source
                   and fact(row).get('push_distance') == 5
                   and row[3].get('turn_execution_id') == fall[3].get('turn_execution_id')]
        damage = [row for row in records if row[0:2] == fall[0:2]
                  and fact(row).get('kind') == 'damage' and fact(row).get('stage') == 'applied'
                  and fact(row).get('target_entity_uuid') == patient
                  and fact(row).get('damage_type') == 'Bludgeoning'
                  and fact(row).get('applied_damage', 0) > 0
                  and fact(row).get('resulting_normal_hp', 0) > 0]
        if not blocked or not pushing or not damage:
            continue
        memberships = [(row, condition) for row in records
                       for holder, condition in adapter.condition_rows(row[3])
                       if holder == patient]
        applied = [(row, condition) for row, condition in memberships
                   if row[0:2] == fall[0:2]
                   and (condition.get('member') or {}).get('behavior_id') == 'condition.prone']
        for application, condition in applied:
            removed = [row for row, change in memberships if row[0] > application[0]
                       and change['condition_uuid'] == condition['condition_uuid']
                       and change.get('member') is None]
            for removal in removed:
                steps = [row for row in records if row[0] > removal[0]
                         and fact(row).get('kind') == 'step'
                         and fact(row).get('source_entity_uuid') == patient
                         and fact(row).get('committed') is True
                         and fact(row).get('from_position') == [9, 4]
                         and fact(row).get('to_position') == [9, 5]]
                if steps:
                    return {'patient_uuid': patient, 'blocked': _location(blocked[0]),
                            'shove': _location(pushing[0]), 'fall': _location(fall),
                            'damage': _location(damage[0]), 'prone_uuid': condition['condition_uuid'],
                            'application': _location(application), 'removal': _location(removal),
                            'step': _location(steps[0])}
    return None


def shove_lifecycle_evidence(out, perspectives, scenario):
    # The recipient owns its later movement even when the other seat loses sight.
    perspective = next(actor['side'] for actor in scenario['actors'] if actor['role'] == 'patient')
    if perspective not in perspectives:
        return [], ['Shove lifecycle requires the actual patient perspective']
    patient, records = _read(out, perspective, scenario)
    joined = _shove(records, patient) if patient else None
    if joined is None:
        return [], ['No same-patient obstruction, successful fall, positive damage, Prone removal and surviving step chain']
    return [{'perspective': perspective, **joined}], []
