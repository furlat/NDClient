"""Offline file layout; existing environment IDs and source filenames stay intact."""
import json
from pathlib import Path


def bank_folder(identity):
    kind, _, name = identity.partition('.')
    group = {'door': 'doors', 'prop': 'props', 'trap': 'traps',
             'window': 'windows', 'wall': 'walls'}.get(kind)
    if group:
        family, _, state = name.partition('.')
        return Path(group) / family / (state or 'default')
    return Path('fixtures') / identity


def engine_media_path(relative):
    """Remove import wrappers from installed engine-only images and atlases."""
    if relative.startswith('packed/environment/'):
        bank, rest = relative.removeprefix('packed/environment/').split('/', 1)
        return Path('environment') / bank_folder(bank) / 'atlas' / rest
    for prefix, target in (
        ('environment/architecture/doors/', 'doors'),
        ('environment/props/', 'props'),
        ('environment/windows/', 'windows'),
        ('environment/spell_devices/', 'devices'),
        ('environment/trap-workshop/', 'traps/workshop'),
        ('environment/wall_debris/', 'walls/debris'),
        ('environment/portal/', 'portals'),
        ('water/', 'water'),
        ('torch/', 'lighting/torch'),
    ):
        if relative.startswith(prefix):
            return Path('environment') / target / relative.removeprefix(prefix)
    if relative.startswith('environment/'):
        filename = relative.removeprefix('environment/')
        for prefix, group in (('ground-', 'terrain'), ('wall-', 'walls/static'),
                              ('door-', 'doors/static')):
            if filename.startswith(prefix):
                return Path('environment') / group / filename
    raise ValueError('Unclassified environment media: ' + relative)


def environment_media_path(source):
    # Keep original-library paths recognizable, separated from selected packed
    # runtime banks. The library includes owned artwork not yet used by gameplay.
    for prefix, folder in (
        ('/fantasy-unified-catalog/a-original/vendor/', 'library/fantasy'),
        ('/fantasy-unified-catalog/b-animated-versions/', 'library/animated'),
        ('/fantasy-unified-catalog/c-new-props/', 'library/props'),
        ('/fantasy-unified-catalog/provenance/door-trap-depth/', 'library/depth'),
    ):
        if prefix in source:
            relative = source.split(prefix, 1)[1]
            if relative.startswith('production-media/'):
                return Path('environment/library/registered') / engine_media_path(
                    relative.removeprefix('production-media/')).relative_to('environment')
            return Path('environment') / folder / relative
    if '/game/assets/' in source:
        return engine_media_path(source.split('/game/assets/', 1)[1])
    raise ValueError('Unrecognized environment source: ' + source)


def write_environment(authoring, document):
    """Split one EnvironmentDocument; the index assembles its unchanged shape."""
    index = {}

    def write(relative, value):
        target = authoring / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(json.dumps(value, indent=2, allow_nan=False) + '\n')
        return relative

    index['version'] = write('environment/settings.json', {'version': document['version']}) + '#/version'
    index['banks'] = {
        identity: write('environment/banks/' + str(bank_folder(identity)) + '.json', record)
        for identity, record in document['banks'].items()
    }
    for section in ('doors', 'traps', 'props', 'wrecks'):
        index[section] = {identity: write(f'environment/{section}/{identity}.json', record)
                          for identity, record in document[section].items()}
    index['wall_destructions'] = write('environment/walls/destructions.json', document['wall_destructions'])
    write('environment/index.json', index)
