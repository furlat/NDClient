"""Grease's actual Prone owner, native turn-start retirement and later walking."""

import adapter


def prone_standing_evidence(out, perspectives, scenario):
    actor = next(actor for actor in scenario['actors'] if actor['role'] == 'target')
    name = adapter.actor_name(actor['side'], actor['role'])
    evidence, missing = [], []
    for perspective in perspectives:
        journal = out/perspective/'journal'
        targets = [identity for identity, birth in adapter.initial_actors(journal).items()
                   if birth['name'] == name]
        records = [row for row in adapter.facts(journal) if row[3].get('phase') == 'completion']
        joined = None
        if len(targets) == 1:
            target = targets[0]
            changes = [(row, change) for row in records
                       for holder, change in adapter.condition_rows(row[3]) if holder == target]
            for application, change in changes:
                if (change.get('member') or {}).get('behavior_id') != 'condition.prone':
                    continue
                condition = change['condition_uuid']
                for removal, ended in changes:
                    if (ended['condition_uuid'] != condition or ended.get('member') is not None
                            or removal[3]['occurrence'] <= application[3]['occurrence']):
                        continue
                    turns = [row for row in records if row[0:2] == removal[0:2]
                        and row[3]['fact'].get('kind') == 'turn'
                        and row[3]['fact'].get('entity_uuid') == target
                        and row[3]['fact'].get('event_type') == 'turn_start']
                    steps = [row for row in records if row[3]['occurrence'] > removal[3]['occurrence']
                        and row[3]['fact'].get('kind') == 'step'
                        and row[3]['fact'].get('source_entity_uuid') == target
                        and row[3]['fact'].get('committed') is True
                        and row[3]['fact'].get('movement_mode') == 'walking']
                    if turns and steps:
                        joined = {'perspective': perspective, 'recipient_uuid': target,
                            'condition_uuid': condition, **{name: {'sequence': row[0],
                                'lineage': row[1], 'occurrence': row[3]['occurrence']}
                                for name, row in (('application', application), ('removal', removal),
                                                  ('turn_start', turns[0]), ('post_step', steps[0]))}}
                        break
                if joined:
                    break
        if joined:
            evidence.append(joined)
        else:
            missing.append(perspective+': no same-recipient Prone UUID application/turn-start removal/walking join')
    if len({row['condition_uuid'] for row in evidence}) != 1 or len(evidence) != len(perspectives):
        missing.append('Both perspectives must disclose the same Prone condition lifecycle')
    return evidence, missing
