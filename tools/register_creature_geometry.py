"""Index delivered creature companions against existing authored body sources.

This importer reads metadata and PNG headers. It never copies/reconstructs art,
changes authoring, creates gameplay clips, or imports the demo's inspection FPS.
"""
import argparse
import json
import math
import struct
from collections import Counter
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[1]
FACTORY = Path('/mnt/c/Users/tommaso/Documents/assets/fantasy-unified-catalog/authored-creature-geometry-2026-10-12')
AUTHORING = PROJECT / 'authoring'
MEDIA = PROJECT.parent / 'NDClientData/.media'
PACKAGES = ('delivery', 'animals/delivery')
COMPANIONS = {'depth': 'depth.png', 'normal': 'normals.png', 'support': 'raw-support.png', 'normal_valid': 'normal-valid.png'}
FACING_ROWS = {'E': 0, 'SE': 1, 'S': 2, 'SW': 3, 'W': 4, 'NW': 5, 'N': 6, 'NE': 7}


def read_json(path):
    return json.loads(path.read_text())


def require(condition, message):
    if not condition:
        raise ValueError(message)


def png_size(path):
    with path.open('rb') as source:
        header = source.read(33)
    require(len(header) == 33 and header[:8] == b'\x89PNG\r\n\x1a\n' and header[12:16] == b'IHDR', f'Not a PNG: {path}')
    width, height, bits, colour, compression, filtering, interlace = struct.unpack('>IIBBBBB', header[16:29])
    require(bits == 8 and colour in (0, 2, 4, 6) and compression == filtering == 0 and interlace in (0, 1), f'Unsupported native PNG header: {path}')
    return [width, height]


def body_path(resource, resources, components):
    media = resources[resource]
    return components.get(media, {}).get('source_layers', {}).get('body', media)


def rooted_file(root, package, relative):
    path = Path(relative)
    require(not path.is_absolute() and '..' not in path.parts, f'Companion outside factory: {relative}')
    # The subsequent PNG-header/JSON read proves existence. Avoid resolving
    # every ancestor or issuing duplicate stat calls for these trusted manifests.
    return (Path(package) / path).as_posix()


def authoring_inputs(root):
    index = read_json(root / 'catalog-index.json')
    return (read_json(root / index['rigs']), read_json(root / index['resources']), read_json(root / index['sheet_components']))


def validate_alias(alias, row, family, rig, resources, components, expected_media, cell, layout):
    label = alias['rig'] + '/' + alias['clip']
    require(alias['category'] in rig['slot_categories'].get('body', []), f'Alias is not an authored body category: {label}')
    clip = rig['clips'][alias['clip']]
    require(clip['sheets'][alias['category']] == alias['resource'], f'Body resource changed: {label}')
    require(body_path(alias['resource'], resources, components) == expected_media, f'Actual selected body path differs: {label}')
    for field in ('frames', 'fps', 'source_clip'):
        require(clip[field] == alias[field], f'Authored {field} mismatch: {label}')
    require(alias['frames'] == row['frames'], f'Native frame count differs: {label}')
    require([rig['cell_width'], rig['cell_height']] == cell, f'Authored cell dimensions differ: {label}')
    require(rig['facing_rows'] == layout['facing_rows'], f'Authored facing rows differ: {label}')
    require(rig['origin_y_from_ground'] == family['placement']['origin_y_from_ground'], f'Authored painted ground pivot differs: {label}')
    require(rig.get('body_anchor') == family['placement']['body_anchor'], f'Authored body anchor differs: {label}')
    require(clip.get('layers', []) == alias.get('layers', []), f'Authored effect-layer enablement differs: {label}')
    return {key: alias[key] for key in ('rig', 'clip', 'category', 'resource', 'source_clip', 'frames', 'fps')}


def build(root=FACTORY, authoring=AUTHORING, media_root=MEDIA):
    rigs, resources, components = authoring_inputs(authoring)
    records = {}
    colour_sources = {}
    admitted_aliases = set()
    package_counts = {}
    png_headers = 0
    registered_rigs = set()
    for package in PACKAGES:
        catalog = read_json(root / package / 'catalog.json')
        recipe = catalog['recipe']
        require(recipe['depth_byte_range'] == [32, 224], f'Unexpected creature depth affine: {package}')
        require(catalog['normal_basis'] == 'fixed_camera_Xright_Yup_Ztoward', f'Unsupported normal basis: {package}')
        require(recipe['elevation_degrees'] == 45 and not recipe['physical_camera_calibrated'], f'Unexpected camera qualification: {package}')
        families = {family['family']: family for family in catalog['families']}
        package_counts[package] = len(catalog['actions'])
        for row in catalog['actions']:
            label = package + '/' + row['id']
            family = families[row['family']]
            animal = package == 'animals/delivery'
            selected = row['layers']['combined']['media'] if animal else row['layers']['body']['media']
            require(selected and selected.startswith('/media/'), f'No original media identity: {label}')
            require(selected not in records, f'Duplicate physical source identity: {selected}')
            layout_relative = rooted_file(root, package, row['files']['layout.json']['path'])
            layout = read_json(root / layout_relative)
            cell = layout['cell_size']
            size = [cell[0] * row['frames'], cell[1] * 8]
            require(size == row['size'] == layout['size'], f'Native sheet size mismatch: {label}')
            require(layout['frames'] == row['frames'] and layout['facing_rows'] == FACING_ROWS, f'Native frame/facing mismatch: {label}')
            require(layout['registered_aliases'] == row['aliases'] and not layout['geometry_pivot_override'], f'Layout alias/pivot mismatch: {label}')
            expected_cells = [{'frame': frame, 'row': facing, 'rect': [frame * cell[0], facing * cell[1], *cell]} for facing in range(8) for frame in range(row['frames'])]
            require(layout['cells'] == expected_cells, f'Frame-local companion layout mismatch: {label}')
            require(png_size(media_root / selected.removeprefix('/media/')) == size, f'Installed original dimensions differ: {label}')
            png_headers += 1
            files = {key: rooted_file(root, package, row['files'][filename]['path']) for key, filename in COMPANIONS.items()}
            profiles = {'original': files['normal'], **{name: rooted_file(root, package, row['files']['normals-' + name + '.png']['path']) for name in ('gentle', 'reference')}}
            colour_path = rooted_file(root, package, row['files']['colour.png']['path'])
            for relative in set(files.values()) | set(profiles.values()) | {colour_path}:
                require(png_size(root / relative) == size, f'Companion dimensions differ: {relative}')
                png_headers += 1
            profile = row['normal_profiles']
            require(profile['validated'] and profile['status'] == 'validated' and profile['time_step'] == 0.2, f'Normal profiles not validated: {label}')
            require(profile['cell_size'] == cell and profile['frames'] == row['frames'] and profile['size'] == size and profile['facing_rows'] == 8, f'Normal profile cells differ: {label}')
            for name, passes in (('gentle', 1), ('reference', 2)):
                p = profile['profiles'][name]
                require(p['validated'] and p['passes'] == passes and p['alpha_unchanged'] and p['unadmitted_rgba_unchanged'], f'Normal profile qualification differs: {label}/{name}')
            aliases = []
            for alias in row['aliases']:
                require(alias['rig'] in rigs, f'Delivery alias absent from current authoring: {label}/{alias["rig"]}')
                aliases.append(validate_alias(alias, row, family, rigs[alias['rig']], resources, components, selected, cell, layout))
                identity = (alias['rig'], alias['clip'], alias['category'])
                require(identity not in admitted_aliases, f'Duplicate registered alias: {identity}')
                admitted_aliases.add(identity)
                registered_rigs.add(alias['rig'])
            rig = rigs.get(family['rig'])
            pivot = [cell[0] / 2, cell[1] - rig['origin_y_from_ground']] if rig else None
            origin = recipe['origin_xy']
            if animal:
                mapping = row['canonical_mapping']
                require(layout['canonical_mapping'] == mapping and not mapping['resampling'] and not mapping['authored_pivots_changed'], f'Native crop/pivot changed: {label}')
                origin = mapping['native_inferred_camera_origin']
                require(origin == [cell[0] / 2, cell[1] * .75], f'Unknown native camera assumption: {label}')
                require([origin[i] + mapping['integer_padding_offset'][i] for i in range(2)] == recipe['origin_xy'], f'Native/canonical camera translation differs: {label}')
                original = row['layers']['combined']['media']
                require(components[original] == row['component_definition'], f'Visible animal partition differs from current authoring: {label}')
                require(row['visible_body_only'] and not row['hidden_body_recovered'], f'Unexpected recovered animal body: {label}')
                colour_sources[colour_path] = selected
            counts = row['coverage']['counts']
            flags = sorted({flag for item in row['coverage']['flagged_frames'] for flag in item['flags']})
            qualification = {'kind': 'estimated_visible_surface_optical', 'physical_geometry_certified': False, 'temporal_consistency_certified': False, 'visible_body_only': animal, 'flags': flags}
            if row.get('source_camera_qualification'):
                qualification['source_camera'] = row['source_camera_qualification']
            record = {
                'media': selected, 'status': 'validated_partial' if counts['missing'] or counts['valid_pixels'] < counts['raw_pixels'] else 'validated_complete',
                'role': 'body', 'slots': ['body'], 'family': row['family'], 'source_action': row['source_action'],
                'files': files, 'normal_profiles': profiles, 'depth_range': recipe['common_depth_world_range'], 'depth_byte_range': recipe['depth_byte_range'],
                'optical_camera': {'origin': origin, 'elevation_degrees': recipe['elevation_degrees'], 'physical_camera_calibrated': False},
                'cell_size': cell, 'frames': row['frames'], 'facing_rows': layout['facing_rows'],
                'painted_pivot': pivot, 'optical_ground_pixels': (origin[1] - pivot[1]) / math.cos(math.radians(recipe['elevation_degrees'])) if pivot else None,
                'source_coverage': row['coverage']['source_coverage'], 'coverage_counts': counts, 'qualification': qualification,
                'registered_aliases': aliases,
            }
            if animal:
                record['colour_path'] = colour_path
                record['source_partition'] = row['component_definition']['selection']
            records[selected] = record
    require(len(records) == 1438, f'Expected complete delivered source count1438, found {len(records)}')
    uncovered = []
    for rig_id, rig in rigs.items():
        if rig_id == 'neuroclient.modular':
            continue
        for clip_name, clip in rig['clips'].items():
            for category in rig['slot_categories'].get('body', []):
                if category not in clip['sheets']:
                    continue
                path = body_path(clip['sheets'][category], resources, components)
                identity = (rig_id, clip_name, category)
                if path not in records or identity not in admitted_aliases:
                    uncovered.append({'rig': rig_id, 'clip': clip_name, 'category': category, 'media': path})
    result = {'schema': 'ndclient-creature-geometry/1', 'qualification': 'estimated_visible_surface_optical',
              'source_catalogs': [p + '/catalog.json' for p in PACKAGES], 'source_count': len(records),
              'normal_basis': 'fixed_camera_Xright_Yup_Ztoward', 'facing_baked': True,
              'records': records, 'colour_sources': colour_sources}
    report = {'sources': len(records), 'packages': package_counts, 'registered_rigs': len(registered_rigs),
              'registered_aliases': len(admitted_aliases), 'registered_sources': sum(bool(r['registered_aliases']) for r in records.values()),
              'library_only_sources': sum(not r['registered_aliases'] for r in records.values()),
              'unknown_authored_placement_sources': sum(r['painted_pivot'] is None for r in records.values()),
              'animal_colour_partitions': len(colour_sources), 'png_headers_checked': png_headers,
              'cell_sizes': sorted({tuple(r['cell_size']) for r in records.values()}),
              'frame_counts': dict(sorted(Counter(r['frames'] for r in records.values()).items())),
              'status_counts': dict(Counter(r['status'] for r in records.values())), 'uncovered_current_body_aliases': uncovered}
    return result, report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=FACTORY)
    parser.add_argument('--authoring', type=Path, default=AUTHORING)
    parser.add_argument('--media', type=Path, default=MEDIA)
    parser.add_argument('--output', type=Path, default=PROJECT / 'generated/creature_geometry.json')
    parser.add_argument('--report', type=Path, default=PROJECT / 'generated/creature_geometry_intake.json')
    args = parser.parse_args()
    data, report = build(args.root, args.authoring, args.media)
    args.output.write_text(json.dumps(data, separators=(',', ':')) + '\n')
    args.report.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report))


if __name__ == '__main__':
    main()
