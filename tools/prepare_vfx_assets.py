"""Copy existing authored VFX, excluding the 23 replacement families and XYZ banks.

Offline intake, not a runtime catalog. Canonical JSON stays unchanged at source.
Artwork is copied under its source names into spell, condition, area and action folders.
"""
import argparse
import ast
from collections import defaultdict
import json
from pathlib import Path
import re

from asset_paths import named_path, write_asset


CORE_REPLACEMENTS = ('fireball', 'fog_cloud', 'darkness', 'cloudkill',
                     'incendiary_cloud', 'stinking_cloud')


def record_installed_replacements(destination):
    """Reconcile copy receipts with the separately installed Factory delivery."""
    receipt = destination / '.runtime/vfx-replacements/summary.json'
    if not receipt.exists():
        return
    replacement = json.loads(receipt.read_text())
    covered = set(replacement['resolved_xyz_references']) | set(replacement['replaced_media_ids'])
    families = {'spell.' + name for name in replacement['spell_families']}
    ordinary = destination / '.runtime/vfx-assets'
    for filename in ('selection.json', 'summary.json'):
        path = ordinary / filename
        report = json.loads(path.read_text())
        report['replacement_delivery'] = replacement['installed_manifest']
        report['excluded_spell_families'] = [name for name in report['excluded_spell_families']
                                             if name not in families]
        if not report['excluded_spell_families']:
            report['deferred_spell_drafts'] = 0
        report['pending_xyz_references'] = {key: value for key, value in
            report['pending_xyz_references'].items() if key not in covered}
        path.write_text(json.dumps(report, indent=2) + '\n')
    for path in (destination / '.runtime/vfx-assets/owners').glob('*/intake-index.json'):
        entries = json.loads(path.read_text())
        for entry in entries.values():
            resolved = covered.intersection(entry['pending_retired_xyz'])
            if resolved:
                entry['replacement_delivery'] = replacement['installed_manifest']
                entry['replacement_asset_ids'] = sorted(resolved)
                entry['pending_retired_xyz'] = sorted(set(entry['pending_retired_xyz']) - covered)
        path.write_text(json.dumps(entries, indent=2) + '\n')


def strings(value):
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for key, item in value.items():
            if key not in ('source', 'provenance', 'preview', 'validation', 'relationships',
                           'definitionRef', 'label', 'description', 'notes'):
                yield from strings(item)
    elif isinstance(value, list):
        for item in value:
            yield from strings(item)


def prepare(engine: Path, destination: Path, replacements: Path, copy: bool):
    documents = {}

    def read(path):
        path = path.resolve()
        if path not in documents:
            documents[path] = json.loads(path.read_text())
        return documents[path]

    replacement_data = read(replacements)
    excluded = {'spell.' + name for name in replacement_data['new_families']}
    excluded.update('spell.' + name for name in CORE_REPLACEMENTS)

    def excluded_owner(identity):
        return next((key for key in sorted(excluded)
                     if identity == key or identity.startswith(key + '.')), None)

    data = engine / 'game/data'
    base = data / 'neuroclient'
    source = base / 'source/src/render/data/animation'
    tree = ast.parse((engine / 'game/animation_data.py').read_text())
    bundles = next(ast.literal_eval(node) for node in ast.walk(tree)
                   if isinstance(node, ast.Tuple) and node.elts
                   and isinstance(node.elts[0], ast.Constant) and node.elts[0].value == 'codexfx')
    # Folder grouping uses native catalog area metadata, not names or sprite shapes.
    catalog_path = engine / 'dnd/spells/catalog_content.py'
    catalog = ast.parse(catalog_path.read_text())
    class_ids = {ast.unparse(node.args[1]): ast.literal_eval(node.args[3])
                 for node in ast.walk(catalog) if isinstance(node, ast.Call)
                 and isinstance(node.func, ast.Name) and node.func.id == 'SpellContentIdentitySpec'}
    area_spells = set()
    for node in ast.walk(catalog):
        if not isinstance(node, ast.Tuple) or len(node.elts) != 2:
            continue
        cls, call = node.elts
        if (isinstance(call, ast.Call) and isinstance(call.func, ast.Name)
                and call.func.id == '_catalog' and any(k.arg == 'area' for k in call.keywords)):
            area_spells.add(class_ids[ast.unparse(cls)])

    assets = {row['assetId']: row for row in read(base / 'source/public/studio/spell-projectile-assets.json')}
    resources = dict(read(base / 'bindings.json')['resources'])
    storage, children, bundle_actions = {}, {}, []
    drafts = {row['definitionRef']['content_id']: row
              for row in read(base / 'spell-studio-drafts.materialized.json')['spells']}
    metadata_paths = set(base.glob('*.json')) | set(source.glob('*.json'))
    metadata_paths.add(base / 'source/public/studio/spell-projectile-assets.json')
    for name in bundles:
        folder = data / name
        binding = read(folder / 'bindings.json')
        resources.update(binding['resources'])
        storage.update(binding.get('projectileStorage', {}))
        assets.update((row['assetId'], row) for row in read(folder / 'projectile-assets.json'))
        metadata_paths.update(folder.glob('*.json'))
        for path in (folder / 'spell-studio-drafts.json', *sorted(folder.glob('*-draft.json'))):
            if path.exists():
                document = read(path)
                drafts.update((row['definitionRef']['content_id'], row) for row in document['spells'])
                children.update(document.get('effectDrafts', {}))
        for name in ('action-recipes.json', 'lifecycle.json', 'weapon-trails.json'):
            if (folder / name).exists():
                bundle_actions.append((folder.name + '/' + name, read(folder / name)))
        if binding.get('actionDeliveries'):
            bundle_actions.append((folder.name + '/deliveries', binding['actionDeliveries']))

    condition_media = read(data / 'condition-media.json')['layers']
    image_resources = read(data / 'assets.json')['resources']
    conditions = {row['definitionRef']['content_id']: row
                  for row in read(source / 'conditionPresentation.json')['recipes']}
    conditions.update((row['definitionRef']['content_id'], row)
                      for row in read(data / 'condition-recipes.json')['recipes'])
    world = read(data / 'world_bindings.json')
    action_assets = {}
    for name in ('body-release-assets.json', 'body-release-particles.json'):
        action_assets.update((row['assetId'], row) for row in read(base / name)['assets'])

    retired = {identity for identity, row in storage.items()
               if any(phase.get('surfaceFrames') for phase in row['phases'].values())}
    replacement_receipt = destination / '.runtime/vfx-replacements/summary.json'
    replacements_installed = (set(json.loads(replacement_receipt.read_text())['replaced_media_ids'])
                              if replacement_receipt.exists() else set())
    groups = defaultdict(lambda: {'assets': set(), 'files': set(), 'pending': set()})
    paths = defaultdict(set)
    missing = set()
    retired_references = defaultdict(set)
    unresolved_sheets = defaultdict(set)
    visited_json_files = set()

    def add_path(relative, group):
        if '{' in relative:
            expanded = sorted(engine.glob(re.sub(r'\{[^}]*\}', '*', relative)))
            if not expanded:
                missing.add(relative)
            for path in expanded:
                add_path(str(path.relative_to(engine)), group)
            return
        if Path(relative).suffix.lower() in ('.zip', '.npz', '.npy'):
            raise ValueError('Unexpected retired/archive payload: ' + relative)
        if group in paths.get(relative, ()):
            return
        path = engine / relative
        if not path.is_file():
            missing.add(relative)
            return
        paths[relative].add(group)
        groups[group]['files'].add(relative)
        # Authored procedural meshes/components may reference companion images.
        if path.suffix == '.json' and (relative, group) not in visited_json_files:
            visited_json_files.add((relative, group))
            visit(read(path), group, set())

    def visit(value, group, visited):
        groups[group]  # Keep procedural-only owners visible too.
        if isinstance(value, dict):
            category = value.get('category')
            if isinstance(category, str) and category.startswith(('Magic', 'Effect')):
                for key, path in resources.items():
                    if key.startswith('/spritesheets/' + category + '/'):
                        add_path(path, 'shared/casting-layers')
        for identity in strings(value):
            if identity in visited:
                continue
            visited.add(identity)
            if identity in retired or identity in replacements_installed:
                retired_references[identity].add(group)
                groups[group]['pending'].add(identity)
            elif identity in assets:
                groups[group]['assets'].add(identity)
                if identity in storage:
                    visit(storage[identity], group, visited)
                else:
                    sheet = assets[identity]['sheet']
                    if sheet in resources:
                        add_path(resources[sheet], group)
                    else:
                        unresolved_sheets[identity].add(group)
            elif identity in condition_media:
                visit(condition_media[identity], 'conditions/layers/' + identity, set(visited))
            elif identity in resources:
                add_path(resources[identity], group)
            elif identity in image_resources:
                add_path('game/assets/' + image_resources[identity]['path'], group)
            elif identity in children:
                visit(children[identity], group, visited)
            elif identity in action_assets:
                row = action_assets[identity]
                if row.get('source'):
                    url = '/spritesheets/' + row['source'] + '.png'
                    if url not in resources:
                        missing.add(url)
                    else:
                        add_path(resources[url], group)
            elif identity.startswith('game/assets/'):
                add_path(identity, group)
            elif identity.startswith('environment/') and Path(identity).suffix in ('.png', '.json'):
                add_path('game/assets/' + identity, group)
        # Category-bearing nested records have their own authored clip/layers.
        if isinstance(value, dict):
            for item in value.values():
                if isinstance(item, (dict, list)):
                    visit(item, group, visited)
        elif isinstance(value, list):
            for item in value:
                if isinstance(item, (dict, list)):
                    visit(item, group, visited)

    for identity, draft in drafts.items():
        if not excluded_owner(identity):
            category = 'areas' if identity in area_spells else 'spells'
            visit(draft, category + '/' + identity.removeprefix('spell.'), set())
    for identity, recipe in conditions.items():
        # Conditions retain their own lifetime even when a source cast is deferred.
        visit(recipe, 'conditions/' + identity.removeprefix('condition.'), set())
    for identity, layer in condition_media.items():
        visit(layer, 'conditions/layers/' + identity, set())
    for section in ('spatial_media', 'concentration_media', 'construction_media', 'spatial_effects'):
        for identity, binding in world[section].items():
            spell = identity.removeprefix('spatial_effect.')
            if section == 'construction_media':
                material = identity.split('.')[1]
                spell = 'spell.wall_of_' + material
            if spell.startswith('spell.') and not excluded_owner(spell):
                visit(binding, 'areas/' + spell.removeprefix('spell.'), set())
    for section in ('deposit_media', 'liquid_surfaces', 'residue_particles'):
        visit(world[section], 'areas/ground-effects', set())
    if 'spatial_effect.material.fire' in world['spatial_media']:
        visit(world['spatial_media']['spatial_effect.material.fire'], 'areas/ground-effects', set())
    for identity, binding in world['spatial_media'].items():
        if identity.startswith('spatial_effect.class_feature.'):
            visit(binding, 'actions/class-areas', set())
    for key in ('actionContextPresentation.json', 'contentActionPresentationRecipes.json',
                'generatedSpellPresentationProfile.json'):
        visit(read(source / key), 'actions/' + Path(key).stem, set())
    for name, document in bundle_actions:
        visit(document, 'actions/' + name.removesuffix('.json'), set())
    for name in ('movement-media.json', 'action-intakes.json', 'action-materials.json',
                 'body-materials.json', 'item-materials.json', 'blood-responses.json',
                 'silhouette-dust.json', 'interruptions.json', 'life-state-poses.json'):
        visit(read(data / name), 'actions/' + Path(name).stem, set())
    for name in ('condition-media.json', 'condition-recipes.json', 'condition-overrides.json',
                 'world_bindings.json', 'assets.json', 'item-attachments.json', 'portals.json'):
        metadata_paths.add(data / name)
    for identity, binding in read(data / 'item-attachments.json').items():
        visit(binding, 'conditions/' + identity.removeprefix('condition.'), set())
    visit(read(data / 'portals.json'), 'spells/portals', set())
    for name in ('body-release-assets.json', 'body-release-particles.json', 'body-release-regions.json',
                 'body-release-bindings.json'):
        visit(read(base / name), 'actions/body-release', set())

    if missing:
        raise ValueError('Missing referenced source files: ' + ', '.join(sorted(missing)))
    report = dict(excluded_spell_families=sorted(excluded),
                  spell_drafts=len(drafts), deferred_spell_drafts=sum(bool(excluded_owner(k)) for k in drafts),
                  condition_recipes=len(conditions), condition_layers=len(condition_media),
                  source_files=len(paths), source_bytes=sum((engine / p).stat().st_size for p in paths),
                  retired_xyz_assets=sorted(retired),
                  pending_xyz_references={k: sorted(v) for k, v in sorted(retired_references.items())},
                  unbound_source_sheets={k: sorted(v) for k, v in sorted(unresolved_sheets.items())},
                  categories={category: sum(k.startswith(category + '/') for k in groups)
                              for category in ('spells', 'conditions', 'areas', 'actions', 'shared')})
    receipt = destination / '.runtime/vfx-assets'
    receipt.mkdir(parents=True, exist_ok=True)
    (receipt / 'selection.json').write_text(json.dumps(report, indent=2) + '\n')
    if not copy:
        record_installed_replacements(destination)
        print((receipt / 'selection.json').read_text())
        return

    views = destination / '.media/vfx'
    # Existing resource URLs identify modular layers, including spell accents.
    # They use the same complete V1.3 library rather than another old image copy.
    modular_sources = {source: identity.removeprefix('/spritesheets/')
                       for identity, source in resources.items()
                       if identity.startswith('/spritesheets/')
                       and (destination / '.media/smallscale/modular' /
                            identity.removeprefix('/spritesheets/')).is_file()}
    records = []
    for relative, owners in sorted(paths.items()):
        row = dict(source=str(engine / relative), source_path=relative, owners=sorted(owners))
        if relative in modular_sources:
            row['modular_member'] = modular_sources[relative]
            target = destination / '.media' / named_path('vfx-assets', row)
            row['bytes'] = target.stat().st_size
        else:
            content = (engine / relative).read_bytes()
            target = destination / '.media' / named_path('vfx-assets', row)
            write_asset(target, content)
            row['bytes'] = len(content)
        row['payload'] = str(target.relative_to(destination))
        records.append(row)
    references = []
    for path in sorted(metadata_paths | set(documents) | {catalog_path, engine / 'game/animation_data.py'}):
        relative = path.relative_to(engine)
        content = path.read_bytes()
        target = receipt / 'authoring-reference' / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(content)
        references.append(dict(source=str(path), snapshot=str(target.relative_to(destination)),
                               bytes=len(content)))
    # The effective authoring import can discover child-outcome dependencies
    # beyond this original intake. Refreshing art must retain their provenance.
    known = {row['source_path'] for row in records}
    previous = receipt / 'files.jsonl'
    if previous.exists():
        for line in previous.read_text().splitlines():
            row = json.loads(line)
            if row['source_path'] not in known and (destination / row['payload']).is_file():
                records.append(row)
                known.add(row['source_path'])
    by_source = {row['source_path']: row for row in records}
    for category in ('spells', 'conditions', 'areas', 'actions', 'shared'):
        folder = receipt / 'owners' / category
        folder.mkdir(parents=True, exist_ok=True)
        rows = {owner.removeprefix(category + '/'): {
            'source_asset_ids': sorted(row['assets']),
            'files': [by_source[p]['payload'] for p in sorted(row['files'])],
            'pending_retired_xyz': sorted(row['pending'])}
            for owner, row in sorted(groups.items()) if owner.startswith(category + '/')}
        (folder / 'intake-index.json').write_text(json.dumps(rows, indent=2) + '\n')
    (views / 'README.md').write_text(
        '# VFX artwork\n\nNamed spells, area effects, conditions, actions and shared resources.\n'
        'Editable authoring is in the tracked authoring/ directory. Intake provenance '
        'is under .runtime/vfx-assets/ and .runtime/vfx-replacements/.\n')
    report.update(copied_bytes=sum(r['bytes'] for r in records),
                  reference_files=len(references), reference_bytes=sum(r['bytes'] for r in references))
    (receipt / 'files.jsonl').write_text(''.join(json.dumps(row) + '\n' for row in records))
    (receipt / 'references.jsonl').write_text(''.join(json.dumps(row) + '\n' for row in references))
    (receipt / 'summary.json').write_text(json.dumps(report, indent=2) + '\n')
    record_installed_replacements(destination)
    print(json.dumps({key: value for key, value in report.items()
                      if key not in ('retired_xyz_assets', 'pending_xyz_references', 'unbound_source_sheets')}, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', type=Path, required=True)
    parser.add_argument('--destination', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--copy', action='store_true')
    args = parser.parse_args()
    prepare(args.engine.resolve(), args.destination.resolve(),
            args.engine.resolve() / '.runtime/spell-asset-review-20261009/replacement-candidates.json', args.copy)
