"""Named VFX destinations used by both intake and the one-time reorganization."""
from pathlib import Path
import re

# Native area ownership, including directional and secondary area deliveries.
AREAS = {
    'fireball', 'fog_cloud', 'darkness', 'cloudkill', 'incendiary_cloud',
    'stinking_cloud', 'insect_plague', 'ice_storm', 'sleet_storm', 'flame_strike',
    'sunburst', 'shatter', 'cone_of_cold', 'gust_of_wind', 'wind_wall',
    'wall_of_fire', 'wall_of_ice', 'wall_of_stone', 'wall_of_thorns', 'sunbeam',
    'lightning_bolt', 'sleep', 'burning_hands', 'thunderwave', 'color_spray',
    'ice_knife', 'web', 'grease', 'spike_growth', 'fear', 'hypnotic_pattern',
    'silence', 'circle_of_death', 'spirit_guardians', 'globe_of_invulnerability',
    'antimagic_field', 'wall_of_force', 'call_lightning', 'daylight',
    'guardian_of_faith', 'mass_cure_wounds', 'heroes_feast', 'slow', 'frigid_air',
}


def slug(name):
    return re.sub(r'[-_.: ]+', '-', name).strip('-')


def spell_folder(name):
    if name == 'ground-effects':
        return Path('vfx/areas/ground-effects')
    return Path('vfx') / ('areas' if name in AREAS else 'spells') / slug(name)


def bank_folder(spell, bank):
    if bank.startswith('core:'):
        return spell_folder(spell) / ('explosion' if spell == 'fireball' else 'lifecycle')
    name = bank.removeprefix(spell + '-')
    if bank.startswith('frigid_air-'):
        return spell_folder('frigid_air') / slug(bank.removeprefix('frigid_air-'))
    return spell_folder(spell) / slug(name)


def ordinary_path(row):
    if 'modular_member' in row:
        return Path('smallscale/modular') / row['modular_member']
    original = Path(row['source_path'].removeprefix('game/assets/'))
    parts = list(original.parts)
    bundle = parts.pop(0)
    if bundle == 'fps32':
        parts.pop(0)  # Import bundle; the next segment is the named asset bank.
    parts = [p for p in parts if p not in ('media', 'assets', 'production-gaps')]
    if bundle == 'construction_operators':
        return Path('vfx/shared/construction') / Path(*parts)
    if bundle in ('wind_flow', 'thorns_flow'):
        return spell_folder('wind_wall' if bundle == 'wind_flow' else 'wall_of_thorns') / 'operator' / Path(*parts)
    if bundle == 'debuff-markers-20261005':
        return Path('vfx/conditions') / slug(original.stem) / original.name
    if bundle == 'liquid_media':
        return Path('vfx/areas/ground-effects') / Path(*parts)
    if bundle == 'surface_ignition_media':
        return Path('vfx/areas/ground-effects/ignition') / Path(*parts)
    if bundle == 'class_media':
        if len(parts) == 1:
            return Path('vfx/shared/class-materials') / parts[0]
        feature = parts.pop(0)
        category = 'actions' if any(o.startswith('actions/') for o in row['owners']) else 'conditions'
        return Path('vfx') / category / slug(feature) / Path(*parts)
    if bundle == 'summoning_media' and parts[0].startswith('cast-'):
        return Path('vfx/shared/summoning') / Path(*parts)
    if bundle == 'utility_media' and parts[0].startswith('hand-'):
        return Path('vfx/shared/telekinesis') / Path(*parts)
    if bundle == 'weather_solar_media' and original.name == 'hand-glow.png':
        return Path('vfx/conditions/sunbeam') / original.name
    if bundle == 'summoning_media' and parts[0].startswith(('arrival-', 'departure-', 'dismiss-')):
        return Path('vfx/actions/summoning') / Path(*parts)
    if bundle == 'environment':
        if parts[0] == 'portal':
            return Path('vfx/spells/portals') / Path(*parts[1:])
        return Path('vfx/actions') / Path(*parts)
    if bundle == 'spell_recovery' and parts[0] == 'palettes':
        return Path('vfx/shared/palettes') / Path(*parts[1:])
    if len(parts) > 1 and parts[0] == 'conditions':
        return Path('vfx/conditions') / Path(*parts[1:])
    owners = row['owners']
    categories = {o.split('/')[0] for o in owners}
    spells = {o.split('/', 1)[1] for o in owners if o.startswith(('spells/', 'areas/'))}
    if len(categories) == 1 and categories <= {'spells', 'areas'} and len(spells) == 1:
        owner = next(iter(spells))
        root = spell_folder(owner)
    elif categories == {'conditions'}:
        names = [o.split('/', 1)[1].removeprefix('spell.').removeprefix('condition.')
                 for o in owners if not o.startswith('conditions/layers/')]
        names = sorted(set(names))
        if names and all(n in ('sleep', 'eyebite.asleep') for n in names):
            name = 'asleep'
        elif len(names) == 1:
            name = names[0]
        else:
            name = parts[0] if len(parts) > 1 else original.stem
            name = re.sub(r'^(persistent|pending|support|control|divine|nature|class|sensory)[._-]', '', name)
            name = re.sub(r'[._-](front|back)([._-]\d+)?$', '', name)
        name = slug(name).removeprefix('condition-')
        name = re.sub(r'-source-v\d+$', '', name)
        if name.startswith('energy-'):
            root = Path('vfx/conditions/protection-from-energy') / name.removeprefix('energy-').split('-')[0]
        elif name.startswith('enhance-'):
            root = Path('vfx/conditions/enhance-ability') / name.split('-')[1]
        elif name.startswith('curse-'):
            root = Path('vfx/conditions/bestow-curse')
        else:
            root = Path('vfx/conditions') / re.sub(r'-(application|sustain|removal|execute)$', '', name)
    elif categories == {'actions'}:
        names = [o.split('/', 1)[1] for o in owners]
        name = {'counterspell_media': 'interruptions', 'summoning_media': 'summoning'}.get(bundle)
        name = name or (names[0] if len(set(names)) == 1 else bundle)
        name = name.removesuffix('-media').removesuffix('/action-recipes').replace('_media/', '/')
        root = Path('vfx/actions') / name
    else:
        # Shared ownership is explicit in receipts; no byte-content deduplication.
        name = parts[0] if len(parts) > 1 else original.stem
        root = Path('vfx/shared') / slug(name)
    if len(parts) > 1 and slug(parts[0]) == root.name:
        parts.pop(0)
    # Keep named bank distinctions but remove historical wrapper words.
    parts[:-1] = [re.sub(r'_source_v\d+$', '', p) for p in parts[:-1]]
    return root / Path(*parts)
