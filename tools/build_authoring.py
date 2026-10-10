"""Read the editable catalog sections; optionally assemble a portable JSON artifact.

No engine imports, asset intake, hashing or renderer initialization at build time.
The source shape is the existing AnimationData catalog and world/image documents.
"""
import argparse
import json
from pathlib import Path
import re


def read_section(authoring, location):
    filename, _, pointer = location.partition('#')
    value = json.loads((authoring / filename).read_text())
    if pointer:
        for key in pointer.removeprefix('/').split('/'):
            value = value[key.replace('~1', '/').replace('~0', '~')]
    return value


def read_index(authoring, filename):
    index = json.loads((authoring / filename).read_text())
    catalog = {}
    for field, location in index.items():
        if isinstance(location, dict):
            catalog[field] = {identity: read_section(authoring, path)
                              for identity, path in location.items()}
        else:
            catalog[field] = read_section(authoring, location)
    return catalog


def read_catalog(authoring):
    return read_index(authoring, 'catalog-index.json')


def media_urls(value):
    if isinstance(value, str):
        if value.startswith('/media/'):
            yield value
    elif isinstance(value, dict):
        for key, child in value.items():
            if key.startswith('/media/'):
                yield key
            yield from media_urls(child)
    elif isinstance(value, list):
        for child in value:
            yield from media_urls(child)


def check_resources(document, root):
    urls = set(media_urls(document))
    missing = []
    for url in sorted(urls):
        relative = url.removeprefix('/media/')
        if '..' in Path(relative).parts:
            raise ValueError('Media URL leaves its root: ' + url)
        path = root / '.media' / relative
        if '{' in relative:
            pattern = re.sub(r'\{[^}]+\}', '*', relative)
            exists = any((root / '.media').glob(pattern))
        else:
            exists = path.is_file()
        if not exists:
            missing.append(url)
    if missing:
        raise ValueError('Missing installed media:\n' + '\n'.join(missing))
    return len(urls)


def read_authoring(root):
    authoring = root / 'authoring'
    document = {'catalog': read_catalog(authoring),
            'world': json.loads((authoring / 'world.json').read_text()),
            'assets': json.loads((authoring / 'assets.json').read_text()),
            'environment': read_index(authoring, 'environment/index.json'),
            **read_index(authoring, 'items/index.json'),
            **read_index(authoring, 'ui/index.json')}
    return document


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    document = read_authoring(args.root)
    count = check_resources(document, args.root)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(document, separators=(',', ':'), allow_nan=False) + '\n')
    print(f'Authoring assembled; {count} distinct media references resolve.')
