"""Adopt the selected engine EnvironmentDocument once, without copying artwork.

Run with the engine's Python and PYTHONPATH. Intake paths are used only here;
ordinary client assembly reads tracked authoring/environment/index.json independently.
Existing client edits and original engine documents are never overwritten.
"""
import argparse
import json
from pathlib import Path

from game.environment_art import EnvironmentDocument
from build_authoring import check_resources
from environment_layout import write_environment


ROOT = Path(__file__).resolve().parents[1]


def prepare(engine, root, apply=False):
    destination = root / 'authoring/environment/index.json'
    schema_path = root / 'authoring/schemas/environment.schema.json'
    for path in (destination, schema_path, root / 'authoring/environment.json'):
        if path.exists():
            raise ValueError(f'Existing client authoring will not be overwritten: {path}')

    intake = root / '.runtime/environment-assets'
    selection = json.loads((intake / 'authoring-reference/catalog/provenance/production/'
                            'fantasy-selected-media.json').read_text())
    source = json.loads((engine / 'game/data/environment_art.json').read_text())
    document = {'version': source['version']}
    for section in ('banks', 'doors', 'traps', 'props', 'wall_destructions'):
        document[section] = {identity: source[section][identity]
                             for identity in selection[section]}
    # Wrecks refer back to the original item family, not to their own art bank.
    selected_items = document['doors'].keys() | document['traps'].keys() | document['props'].keys()
    document['wrecks'] = {identity: record for identity, record in source['wrecks'].items()
                          if record['source_item_id'] in selected_items}

    paths = {}
    for line in (intake / 'files.jsonl').read_text().splitlines():
        row = json.loads(line)
        if '/game/assets/' in row['source']:
            relative = row['source'].split('/game/assets/', 1)[1]
            paths[relative] = '/media/' + row['payload'].removeprefix('.media/')

    def relocate(value, pointer='environment'):
        if isinstance(value, dict):
            for field, child in value.items():
                location = pointer + '/' + field
                if field in ('path', 'frame_path', 'leaf_path') and child is not None:
                    if child not in paths:
                        raise ValueError(f'{location}: media has no installed location: {child}')
                    value[field] = paths[child]
                else:
                    relocate(child, location)
        elif isinstance(value, list):
            for index, child in enumerate(value):
                relocate(child, pointer + '/' + str(index))

    relocate(document)
    # The existing passive owner checks states, frames, poses and bank references.
    EnvironmentDocument.model_validate(document)
    resources = json.loads((root / 'authoring/assets.json').read_text())['resources']
    for identity, door in document['doors'].items():
        for pose, resource in door['frame_resource_by_pose'].items():
            if resource not in resources:
                raise ValueError(f'environment/doors/{identity}/frame_resource_by_pose/{pose}: '
                                 f'unregistered image resource {resource}')
    media_count = check_resources({'environment': document}, root)
    if apply:
        write_environment(root / 'authoring', document)
        schema = EnvironmentDocument.model_json_schema(mode='serialization')
        schema['$schema'] = 'https://json-schema.org/draft/2020-12/schema'
        schema_path.write_text(json.dumps(schema, indent=2, allow_nan=False) + '\n')
    return {section: len(document[section]) for section in
            ('banks', 'doors', 'traps', 'props', 'wrecks', 'wall_destructions')} | {
                'media_files': media_count, 'written': apply}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', type=Path, required=True)
    parser.add_argument('--root', type=Path, default=ROOT)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    print(json.dumps(prepare(args.engine.resolve(), args.root.resolve(), args.apply), indent=2))
