"""Native initial fixture data followed by ordinary player inputs."""


def hardware_studies(subjects):
    """Five public anchor families; one genuine attack never guarantees destruction."""
    result = []
    for kind, item, content, name in (
        ('spikes', 'spikes', 'spike_trap', 'Spike housing'),
        ('jaw', 'jaw', 'jaw_trap', 'Jaw trap'),
        ('gas_vent', 'gas_vent', 'gas_vent', 'Gas vent'),
        ('pressure_plate', 'pressure_plate', 'pressure_plate', 'Pressure plate'),
        ('tripwire', 'tripwire', 'tripwire', 'Tripwire'),
    ):
        primary = {'id': 'primary', 'kind': kind, 'at': [5, 7],
            'content_id': 'spatial_effect.environment.'+content,
            'item_id': 'environment.trap.'+item, 'hit_points': 1}
        fixtures = [primary]
        approach = [[5, 7]]
        if kind in ('pressure_plate', 'tripwire'):
            fixtures.insert(0, {'id': 'vent', 'kind': 'gas_vent', 'at': [8, 7],
                'content_id': 'spatial_effect.environment.gas_vent',
                'item_id': 'environment.trap.gas_vent', 'gas': {'radius_feet': 0}})
            primary['activates'] = 'vent'
            if kind == 'tripwire':
                primary.update(across=[6, 7], cells=[[5, 7], [6, 7]])
                approach.append([6, 7])
            else:
                approach.append([4, 7])
        elif kind == 'gas_vent':
            primary['gas'] = {'radius_feet': 0}
            fixtures.append({'id': 'plate', 'kind': 'pressure_plate', 'at': [4, 7],
                'content_id': 'spatial_effect.environment.pressure_plate',
                'item_id': 'environment.trap.pressure_plate', 'activates': 'primary'})
            approach = [[4, 7]]
        inventory = subjects(actions=['action.move', 'action.attack'])
        inventory['spatial_effect'] = sorted({row['content_id'] for row in fixtures})
        inventory['environment_object'] = sorted({row['item_id'] for row in fixtures})
        result.append({
            'id': 'environment.'+kind+'/observed_hardware',
            'title': name+': native hardware anchor, legal contact and attack',
            'kind': 'environment', 'seed': 2, 'subjects': inventory,
            'actors': [
                {'role': 'cutter', 'side': 'amber', 'premade': 'fighter', 'at': [5, 6]},
                {'role': 'walker', 'side': 'amber', 'creature': 'creature.knight',
                 'at': [3, 7] if kind == 'gas_vent' else [4, 7]},
                {'role': 'observer', 'side': 'blue', 'creature': 'creature.knight', 'at': [9, 6]}],
            'initial_mechanisms': fixtures,
            'steps': [{'do': 'action.move', 'by': 'walker', 'target': point, 'prefer_safe': False}
                      for point in approach]
                     + [{'do': 'action.attack', 'by': 'cutter', 'target': {'object': name}}],
            'required_behaviors': ['action.move', 'action.attack'],
            'required_facts': ['movement', 'attack', 'spatial_effect_state']
                + ([] if kind == 'spikes' else ['mechanism_activation']),
            'purpose': 'Real native fixtures are installed before audience initialization. Both original '
                'seats must disclose each exact spatial owner to its own actual hardware UUID. Later '
                'movement and one attack use offered SDK choices. The explicitly authored one-HP '
                'hardware permits a real hit to destroy it; a miss is retained and does not qualify '
                'destruction, damage or successful avoidance. No dice or public packets are rewritten.'})
    return result
