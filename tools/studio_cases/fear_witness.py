"""Join the real failed fear save, condition owner and same-turn extension."""

import adapter


def fear_extension_evidence(out, perspectives, scenario):
    actor = next(actor for actor in scenario['actors'] if actor['role'] == 'caster')
    name = adapter.actor_name(actor['side'], actor['role'])
    evidence, missing = [], []
    for perspective in perspectives:
        journal = out/perspective/'journal'
        identities = [identity for identity, birth in adapter.initial_actors(journal).items()
                      if birth['name'] == name]
        records = [row for row in adapter.facts(journal) if row[3].get('phase') == 'completion']
        joined = None
        if len(identities) == 1:
            source = identities[0]
            casts = [row for row in records if row[3]['fact'].get('kind') == 'action'
                     and row[3]['fact'].get('source_entity_uuid') == source
                     and row[3]['fact'].get('behavior_id') == 'action.class.barbarian.intimidating_presence']
            for cast in casts:
                target = cast[3]['fact'].get('target_entity_uuid')
                saves = [row for row in records if row[0:2] == cast[0:2]
                    and row[3]['fact'].get('kind') == 'saving_throw'
                    and row[3]['fact'].get('target_entity_uuid') == target
                    and row[3]['fact'].get('ability_name') == 'wisdom'
                    and row[3]['fact'].get('succeeded') is False]
                changes = [(row, change) for row in records
                           for holder, change in adapter.condition_rows(row[3]) if holder == target]
                for application, change in changes:
                    if (application[0:2] != cast[0:2]
                            or (change.get('member') or {}).get('behavior_id') != 'condition.frightened'):
                        continue
                    condition = change['condition_uuid']
                    extensions = [row for row in records if row[3]['fact'].get('kind') == 'action'
                        and row[3]['fact'].get('behavior_id') == 'action.class.barbarian.extend_intimidating_presence'
                        and row[3]['fact'].get('source_entity_uuid') == source
                        and row[3]['fact'].get('target_entity_uuid') == target
                        and cast[3].get('turn_execution_id')
                        and row[3].get('turn_execution_id') == cast[3]['turn_execution_id']
                        and row[3]['occurrence'] > application[3]['occurrence']]
                    for extension in extensions:
                        removed = any(ended['condition_uuid'] == condition and ended.get('member') is None
                            and application[3]['occurrence'] < row[3]['occurrence'] < extension[3]['occurrence']
                            for row, ended in changes)
                        failed = [row for row in saves if row[3]['occurrence']
                                  < application[3]['occurrence'] < cast[3]['occurrence']]
                        if failed and not removed:
                            joined = {'perspective': perspective, 'caster_uuid': source, 'recipient_uuid': target,
                                'condition_uuid': condition, **{name: {'sequence': row[0], 'lineage': row[1],
                                    'occurrence': row[3]['occurrence']} for name, row in
                                    (('cast', cast), ('failed_save', failed[0]), ('application', application),
                                     ('extension', extension))}}
                            break
                    if joined:
                        break
                if joined:
                    break
        if joined:
            evidence.append(joined)
        else:
            missing.append(perspective+': no same-recipient failed save/Frightened UUID/same-turn extension join')
    return evidence, missing
