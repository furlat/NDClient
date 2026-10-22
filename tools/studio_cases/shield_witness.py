"""Exact ranged Shield lifecycle joins over unchanged public originals."""

import adapter


def shield_lifecycle_evidence(out, perspectives, scenario):
    requirement = scenario['require_shield_lifecycle']
    names = {actor['role']: adapter.actor_name(actor['side'], actor['role'])
             for actor in scenario['actors']}
    evidence, missing = [], []
    for perspective in perspectives:
        journal = out/perspective/'journal'
        actors = adapter.initial_actors(journal)
        identities = {role: [identity for identity, actor in actors.items()
                            if actor['name'] == names[requirement[role]]]
                      for role in ('recipient', 'attacker')}
        matches = []
        result = {'perspective': perspective, 'matches': matches}
        evidence.append(result)
        if any(len(values) != 1 for values in identities.values()):
            missing.append(perspective+': Shield recipient/attacker identity is not unique')
            continue
        recipient, attacker = identities['recipient'][0], identities['attacker'][0]
        applications, removals, attacks, steps = {}, {}, [], []
        for sequence, lineage, offset, node in adapter.nodes(journal):
            if node.get('phase') != 'completion':
                continue
            fact = node.get('fact') or {}
            location = {'sequence': sequence, 'lineage': lineage,
                        'occurrence': node['occurrence'], 'event_offset': offset}
            if fact.get('kind') == 'actor_change':
                for holder, row in adapter.condition_rows(node):
                    if holder != recipient:
                        continue
                    condition = row['condition_uuid']
                    member = row.get('member')
                    if member and member.get('behavior_id') == 'condition.spell.shield':
                        applications.setdefault(condition, location)
                    elif member is None:
                        removals[condition] = location
            elif (fact.get('kind') == 'attack'
                  and fact.get('source_entity_uuid') == attacker
                  and fact.get('target_entity_uuid') == recipient
                  and fact.get('weapon_slot') == 'RANGED_MAIN'
                  and fact.get('source_item_id') == 'weapon.longbow'
                  and fact.get('attack_source_kind') == 'equipped'
                  and fact.get('attack_outcome') == 'Miss'
                  and fact.get('intercepted_by_condition_uuid')):
                handlers = [row for row in node.get('content_attributions', ())
                    if row.get('role') == 'effective_handler'
                    and row.get('behavior_id') == 'reaction.spell.shield'
                    and row.get('source_entity_uuid') == recipient
                    and row.get('outcome') == 'modified_event']
                if handlers:
                    attacks.append((fact['intercepted_by_condition_uuid'], location, handlers))
            elif (fact.get('kind') == 'step' and fact.get('source_entity_uuid') == recipient
                  and fact.get('committed') is True and fact.get('movement_mode') == 'walking'):
                steps.append(location)
        for condition, attack, handlers in attacks:
            application, removal = applications.get(condition), removals.get(condition)
            if not application or not removal:
                continue
            if not application['occurrence'] < attack['occurrence'] < removal['occurrence']:
                continue
            post_steps = [step for step in steps if step['occurrence'] > removal['occurrence']
                and not any(applied['occurrence'] < step['occurrence']
                    and (identity not in removals or removals[identity]['occurrence'] > step['occurrence'])
                    for identity, applied in applications.items())]
            if post_steps:
                matches.append({'recipient_uuid': recipient, 'attacker_uuid': attacker,
                    'condition_uuid': condition, 'application': application, 'attack': attack,
                    'effective_handlers': handlers, 'removal': removal, 'post_step': post_steps[0]})
        if not matches:
            missing.append(perspective+': no exact ranged Shield interception/application/removal/post-Step join')
    common = None
    for row in evidence:
        identities = {match['condition_uuid'] for match in row['matches']}
        common = identities if common is None else common & identities
    if not common:
        missing.append('No same Shield condition UUID has the complete lifecycle in every perspective')
    return evidence, missing
