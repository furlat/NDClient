"""Adopt the existing environment library's effective geometry associations.

This offline adapter reads supplier receipts once. The saved library contains
explicit image/frame samples, not references for a runtime receipt interpreter.
"""
from copy import deepcopy
from pathlib import Path
import struct

import numpy as np


POSES = ('e', 's', 'w', 'n')


def reference(value):
    if isinstance(value, str):
        return value
    return value['path'] + value.get('pointer', '')


def image_region(intake, value, context):
    value = {'path': value} if isinstance(value, str) else value
    source = intake.source(value['path'], context)
    rect = value.get('rect')
    if rect is None:
        with source.open('rb') as stream:
            header = stream.read(24)
        if header[:8] != b'\x89PNG\r\n\x1a\n':
            raise ValueError(f'No source image rectangle: {source}')
        rect = [0, 0, *struct.unpack('>II', header[16:24])]
    url = intake.existing_media(str(source))
    intake.installed[str(source).casefold()] = url
    return {'path': url, 'rect': rect}


def expanded_mapping(intake, row, document, context):
    """A library row can reuse pixels while overriding their physical mount."""
    channels = row.get('channels', {})
    if 'accepted_frame' not in channels:
        return row, document, context
    accepted, source = intake.read_ref(channels['accepted_frame'], context)
    source_document, _ = intake.read_ref(str(source))
    frame = {**accepted, **row}
    for name in ('geometry_region_native', 'native_cell', 'colour_cell'):
        if name in channels:
            frame[name] = channels[name]
    support = channels.get('support')
    if isinstance(support, str) or isinstance(support, dict) and 'path' in support:
        frame['support'] = support
    # Other support entries document reuse or nonzero-depth coverage, not a mask.
    frame['channels'] = {key: value for key, value in channels.items() if key != 'support'}
    calibration = channels.get('calibration')
    if isinstance(calibration, dict) or isinstance(calibration, str) and calibration.split('#', 1)[0].endswith('.json'):
        frame['geometry_calibration'] = reference(calibration)
    # The receipt's override is in library registration, not selected-bank space.
    return frame, source_document, source


def frame_rows(intake, document, context, entry, axes=None):
    """Enumerate declared views, variant slots and frames without name guessing."""
    axes = axes or {}
    if 'views' in document:
        views = document['views']
        names = [axes['source_view']] if axes.get('source_view') in views else list(views)
        for view in names:
            row = views[view]
            yield dict(row, source_view=view), document, context, {**axes, 'source_view': view}
    elif 'source_view' in axes and not any(k in document for k in ('frames', 'variants')):
        yield dict(document, source_view=axes['source_view']), document, context, axes
    for row in document.get('entry_view_geometry', []):
        yield row, document, context, {**axes, 'state': 'entry'}
    for row in document.get('entry_source_sequence', []):
        for view in row.get('pose_aliases', [row.get('pose')]):
            if view is None:
                raise ValueError(f'No declared view/aliases in source sequence {context}')
            yield {**row, 'pose': view, 'source_frame_index': row['source_sequence_index']}, document, context, axes
    for row in document.get('frames', []):
        yield row, document, context, axes
    for index, variant in enumerate(document.get('variants', [])):
        variant_axes = {**axes, 'variant_index': variant.get('variant_index', index),
                        'variant_name': variant['name']}
        if variant.get('original_clock_and_mount'):
            variant_axes['_registration'] = variant['original_clock_and_mount']
        elif variant.get('registration'):
            variant_axes['_registration'] = variant['registration']
        for row in variant.get('geometry_mappings', []):
            yield row, document, context, variant_axes
        if variant.get('geometry_delivery'):
            nested, path = intake.read_ref(reference(variant['geometry_delivery']), context)
            yield from frame_rows(intake, nested, path, entry, variant_axes)
    # Some direct animated families have one reference rather than variants.
    if document.get('geometry_delivery') and not document.get('variants'):
        nested, path = intake.read_ref(reference(document['geometry_delivery']), context)
        yield from frame_rows(intake, nested, path, entry, axes)
    for mapping in document.get('state_frame_correspondence', []):
        selected = mapping['existing_geometry_frame']
        nested, path = intake.read_ref(selected['delivery'], context)
        frames = nested.get('frames', [])
        row = next((f for f in frames if f.get('resource_id') == selected['resource_id']), None)
        if row is None:
            row = next((f for f in frames if f.get('pose') == mapping['pose'] and
                        f.get('frame_index') == mapping['frame_index']), None)
        if row is None:
            raise ValueError(f"No dart frame {selected['resource_id']} in {path}")
        yield {**row, **mapping}, nested, path, axes
    if document.get('role_only') and not document.get('frames'):
        for view, colour in entry['views'].items():
            yield {'source_view': view, 'source_colour': colour}, document, context, axes


def source_colour(row, document, entry, view):
    colour = row.get('source_colour') or row.get('selected_colour') or row.get('colour')
    if colour:
        if isinstance(colour, str):
            return {'path': colour, 'rect': row.get('source_rect')}
        return colour
    original = row.get('original_registration', {})
    if original.get('path'):
        return {'path': original['path'], 'rect': row.get('source_rect')}
    return entry.get('views', {}).get(view) or document.get('source_views', {}).get(view)


def registration(row, document, axes, view):
    own = row.get('registration', {})
    original = row.get('original_registration', {})
    declared = row.get('source_registration') or row.get('native_registration') or document.get('source_registration', {})
    clock = axes.get('_registration', {})
    pivot = (own.get('source_pivot') or row.get('pivot') or
             original.get('source_pivot_px_top_left') or declared.get('source_pivot_px_top_left') or declared.get('pivot') or
             declared.get('anchor') or clock.get('pivot') or
             document.get('pivots_by_pose', {}).get(view))
    if pivot is None and 'pivotPx' in declared:
        pivot = [declared['pivotPx']['x'], declared['pivotPx']['y']]
    scale = row.get('scale', declared.get('scale', clock.get('scale', document.get('scale'))))
    return pivot, scale


def sample(intake, row, document, context, entry, axes):
    row, document, context = expanded_mapping(intake, row, document, context)
    view = str(row.get('source_view', row.get('pose', axes.get('source_view',
                   row.get('calibration_pose', 'single')))))
    colour = source_colour(row, document, entry, view)
    if not colour:
        raise ValueError(f"No explicit library colour: {entry['id']} {view} {context}")
    region = image_region(intake, colour, context)
    pivot, scale = registration(row, document, axes, view)
    geometry = row.get('geometry_calibration') or row.get('geometry')
    if isinstance(geometry, str) and geometry.split('#', 1)[0].endswith('.json'):
        calibration, _ = intake.read_ref(geometry, context)
        pivot = pivot or calibration.get('pivot')
        scale = scale if scale is not None else calibration.get('scale')
    elif isinstance(geometry, dict) and 'kind' in geometry:
        pivot = pivot or geometry.get('pivot')
        scale = scale if scale is not None else geometry.get('scale')
    state = row.get('state_role', row.get('state', axes.get('state', document.get('state', 'static'))))
    index = row.get('source_frame_index', row.get('frame_index', 0))
    # The supplier uses -1 for an independent endpoint/idle image, outside its
    # animated strip. Its own state has one frame; reused geometry has its own index.
    if index == -1:
        index = 0
        frame_name = Path(colour['path']).name
    else:
        frame_name = row.get('original_frame_name')
    out = {'colour': region, 'source_view': view, 'frame_index': index, 'state': state}
    for key in ('variant_index', 'variant_name', 'pitch_degrees', 'camera_quadrant', 'aim_row'):
        value = axes.get(key, row.get(key, document.get(key)))
        if value is not None:
            out[key] = value
    if pivot is not None:
        out['pivot'] = pivot
    if scale is not None:
        out['scale'] = scale
    if 'time_ms' in row:
        out['time_ms'] = row['time_ms']
    if frame_name:
        out['frame_name'] = frame_name
    # Supply the known source cell to the common geometry/mask sampler.
    prepared = {**row, 'source_colour': {**colour, 'rect': region['rect']},
                'source_view': view, 'native_size': region['rect'][2:],
                'selected_colour': {**colour, 'rect': region['rect']}}
    destination = Path(region['path'].removeprefix('/media/')).parent / 'geometry' / entry['id'] / view
    out['surface'] = intake.surface(prepared, document, context, destination)
    return out


def clock_record(document, axes):
    source = axes.get('_registration') or document.get('source_registration') or document
    clock = {key: axes[key] for key in ('variant_index', 'variant_name', 'source_view') if key in axes}
    state = document.get('state', axes.get('state'))
    if state is not None:
        clock['state'] = state
    selectors = len(clock)
    for key in ('fps', 'sample_times_ms', 'duration_ms', 'clear_at_end'):
        if key in source:
            clock[key] = source[key]
    for key in ('animation_frame_count', 'original_frame_count', 'frame_count', 'columns'):
        if key in source:
            clock['frame_count'] = source[key]
            break
    if 'duration_seconds' in source:
        clock['duration_ms'] = source['duration_seconds'] * 1000
    return clock if len(clock) > selectors else None


def adopt_library(intake, records, changes):
    catalog, _ = intake.read_ref(str(intake.catalog / 'catalog.json'))
    entries = {entry['id']: entry for entry in catalog['entries']}
    library = {}
    for record in records:
        if record['list'] != 'families':
            continue
        identity = record['existing_id']
        entry = entries[identity]
        qualification = record.get('qualification')
        if isinstance(qualification, list):
            qualification = '\n'.join(qualification)
        family = {'label': entry['label'], 'role': record['receipt_selection'].get('role', 'environment'),
                  'qualification': qualification, 'samples': [], 'clocks': []}
        seen = set()
        for selected in record['receipt_selection']['effective']:
            document, context = intake.read_ref(selected['reference'])
            axes = {'source_view': selected['source_view']} if 'source_view' in selected else {}
            if 'source_exact' in document:
                family['source_exact'] = document['source_exact']
            for row, owner, path, row_axes in frame_rows(intake, document, context, entry, axes):
                value = sample(intake, row, owner, path, entry, row_axes)
                key = (value['colour']['path'], tuple(value['colour']['rect']), value['source_view'],
                       value['frame_index'], value['state'], value.get('variant_index'),
                       value.get('pitch_degrees'), value.get('camera_quadrant'), value.get('aim_row'))
                if key in seen:
                    continue
                seen.add(key)
                family['samples'].append(value)
                clock = clock_record(owner, row_axes)
                if clock and clock not in family['clocks']:
                    family['clocks'].append(clock)
        if not record['receipt_selection']['effective']:
            for view, colour in entry['views'].items():
                region = image_region(intake, colour, intake.catalog / 'catalog.json')
                family['samples'].append({'colour': region, 'source_view': view, 'frame_index': 0,
                                          'state': 'static', 'surface': {}})
        if not family['samples']:
            raise ValueError(f'No adopted library samples: {identity}')
        library[identity] = family
    adopt_assembly_closures(intake, changes)
    return library


def adopt_assembly_closures(intake, changes):
    summary, context = intake.read_ref('source-recovery/assembly-mount-closure/ASSEMBLY_CLOSURE.json')
    for association in summary['records']:
        identity = association['catalog_id']
        delivery, path = intake.read_ref(association['delivery'], context)
        targets = list((intake.authoring / 'environment/source-records').rglob(identity + '.json'))
        if len(targets) != 1:
            raise ValueError(f'Ambiguous source assembly owner: {identity}: {targets}')
        target = targets[0]
        original, _ = intake.read_ref(str(target))
        updated = deepcopy(changes.get(target, original))
        record = updated['record']
        if 'views' in delivery:
            closure = {key: delivery[key] for key in ('physical_origin', 'adjacent_piece_rebase',
                       'frame_height_interval_relative_to_source_floor_steps')}
            closure['views'] = {}
            for view, supplied in delivery['views'].items():
                calibration, _ = intake.read_ref(supplied['mounted_calibration'], path)
                closure['views'][view] = {key: supplied[key] for key in (
                    'physical_source_floor_contact_px', 'raw_pivot_preserved', 'native_camera_quarter')}
                closure['views'][view]['calibration'] = {key: calibration[key] for key in (
                    'kind', 'basis', 'encoding', 'depthRange', 'pixelToRayOrigin', 'rayDirection',
                    'sourceToLocal', 'pixel_coordinates', 'colour_to_native', 'normalBasis',
                    'normalToLocal', 'host_pose_quarter', 'mounting') if key in calibration}
            mounting = record['mounting']
            record.setdefault('historical_montage_mount', {
                'mounting': deepcopy(mounting),
                'contact_by_pose': deepcopy(record['contact_by_pose']),
                'identity_validation_level': record['identity']['validation_level'],
            })
            record['identity']['validation_level'] = (
                'Measured source floor/contact and image/depth physical mount; '
                'not vendor-exact hidden geometry or collision certification.')
            mounting['registration_space'] = 'Measured source floor/contact and physical mount; see physical_mount.'
            mounting['shared_physical_mount_validated'] = True
            mounting['plane'] = 'Use the measured physical_mount source-to-local calibration and floor contact once.'
            for view, mounted in closure['views'].items():
                contact = record['contact_by_pose'][view]
                floor = mounted['physical_source_floor_contact_px']
                contact['placement_contact_px'] = floor
                contact['placement_contact_kind'] = 'Measured physical source floor contact.'
                contact['selected_marker'] = {'point_px': floor, 'label': 'Physical floor contact',
                                              'physical_anchor_verified': True}
                contact['contacts_scaled_px_relative_to_declared_assembly_origin'] = {
                    name: [(point[axis] - floor[axis]) * mounting['render_scale'] for axis in (0, 1)]
                    for name, point in contact['contacts_source_local_px'].items()}
                contact.pop('door_top_left_minus_header_top_left_scaled_px', None)
        else:
            closure = {key: delivery[key] for key in (
                'basis', 'mount_anchor_source_xyz', 'sourceToMountLocal', 'camera_quarters',
                'contacts_relative_to_lower_floor_XHZ', 'support_sequence', 'lower_landing',
                'upper_landing', 'ascent_lane_width_cells', 'consumer_rule')}
        record['physical_mount'] = closure
        changes[target] = updated


# The bounded, already delivered assembly closure, not a second asset registry.
ASSEMBLY_DOOR_STEMS = ('indoor-door-shabby', 'indoor-door-elegant',
                       'indoor-door-shabby-plain', 'indoor-door-shabby-battens',
                       'indoor-door-shabby-patched', 'indoor-door-elegant-three-panel')
MEMBER_CAMERA_QUARTERS = {'e': 0, 's': 1, 'w': 2, 'n': 3}


def physical_contact(surface, anchor, location):
    """Project a packet-basis source anchor through this capture's actual rays."""
    geometry = surface.get('geometry', {})
    if geometry.get('kind') != 'ray_depth' or geometry.get('basis') != 'object_local':
        raise ValueError(f'{location}: assembly contact requires object-local ray_depth geometry')
    if not surface.get('normal') or not surface.get('geometry_sampling'):
        raise ValueError(f'{location}: assembly contact requires normal and geometry_sampling')
    origin = np.asarray(geometry['pixelToRayOrigin'])
    ray = np.column_stack((origin[:, :2], geometry['rayDirection']))
    uv = np.linalg.solve(ray, np.asarray(anchor) - origin[:, 2])[:2]
    sampling = surface['geometry_sampling']
    return ((uv - sampling.get('offset', [0, 0])) / sampling['scale']).tolist()


def mount_surface(surface, calibration):
    """Replace the effective mount, leaving per-frame rays and all masks intact."""
    surface['geometry']['sourceToLocal'] = deepcopy(calibration['sourceToLocal'])
    surface['normal']['normalToLocal'] = deepcopy(calibration['normalToLocal'])
    qualification = surface.get('qualification', '')
    for obsolete in (
        'Source camera alignment does not resolve the six shared physical frame/leaf mounts: '
        'no pivot/contact/threshold adjustments are authorized by this export.',
        'Six physical shared frame/leaf assembly mounts remain unresolved: packet camera '
        'alignment does not validate physical hinge/threshold or permit renderer offsets.',
    ):
        qualification = qualification.replace(obsolete,
            'The delivered measured source-floor mount is applied; '
            'this does not certify hidden vendor geometry or gameplay collision.')
    if 'qualification' in surface:
        surface['qualification'] = qualification


def retained_contact(projected, supplied, location):
    # Source projections are recorded to 6 decimal places with float camera fits.
    if not np.allclose(projected, supplied, atol=1e-3, rtol=0):
        raise ValueError(f'{location}: supplied physical contact {supplied} disagrees with rays {projected}')
    return deepcopy(supplied)


def door_variants(record):
    rebase = record['physical_mount']['adjacent_piece_rebase']['adjacent_origin_relative_to_door_floor_XHZ']
    variants = {}
    for pairing in record['compatible_pieces']:
        members = []
        for part in record['parts']:
            role = part['role']
            if role == 'generated_frame_and_leaf':
                continue  # Already owned by the selected bank, never draw it twice.
            family = pairing[role] if role in ('opening_header', 'adjacent_partition') else part['asset_family']
            xy = (part['position_offset_cells_by_wall_pose']['e'] if 'position_offset_cells_by_wall_pose' in part
                  else part['position_offset_cells'])
            offset = [xy[0], part['base_height_offset_steps'], xy[1]]
            members.append({'role': role, 'family_id': family,
                            'offset_XHZ': [a + b for a, b in zip(offset, rebase)]})
        variants[pairing['opening_header']] = {'primary': pairing['primary'], 'members': members}
    return variants


def connect_assembly_authoring(environment, door_records, timber_record):
    """Pure bounded amendment of current owners from already tracked measurements."""
    changes = {'banks': {}, 'doors': {}, 'library': {}}
    member_families = set()
    for identity, record in door_records.items():
        door = deepcopy(environment['doors'][identity])
        door['assembly_variants'] = door_variants(record)
        changes['doors'][identity] = door
        for variant in door['assembly_variants'].values():
            member_families.update(member['family_id'] for member in variant['members'])
        mounts = record['physical_mount']['views']
        for bank_id in (*door['openings'].values(), *door['destructions'].values()):
            bank = deepcopy(environment['banks'][bank_id])
            contacts = {}
            for pose in bank['rows']:
                calibration = mounts[pose]['calibration']
                anchor = calibration['mounting']['physical_anchor_source_xyz']
                for index, surface in enumerate(bank['surface_frames_by_pose'][pose]):
                    location = f'{bank_id}/{pose}/{index}'
                    contact = physical_contact(surface, anchor, location)
                    if bank['cell'] == record['contact_by_pose'][pose]['frame_rect'][2:]:
                        contact = retained_contact(contact, mounts[pose]['physical_source_floor_contact_px'], location)
                    if pose in contacts:
                        retained_contact(contact, contacts[pose], location)
                    else:
                        contacts[pose] = contact
                    mount_surface(surface, calibration)
            bank['physical_source_contact_by_pose'] = contacts
            bank['camera_quarter_by_pose'] = {pose: mounts[pose]['native_camera_quarter'] for pose in bank['rows']}
            changes['banks'][bank_id] = bank
        family_id = record['catalog_id']
        family = deepcopy(environment['library'][family_id])
        for index, sample in enumerate(family['samples']):
            pose = sample['source_view']
            calibration = mounts[pose]['calibration']
            location = f'{family_id}/samples/{index}/{pose}'
            contact = physical_contact(sample['surface'], calibration['mounting']['physical_anchor_source_xyz'], location)
            if sample['colour']['rect'][2:] == record['contact_by_pose'][pose]['frame_rect'][2:]:
                contact = retained_contact(contact, mounts[pose]['physical_source_floor_contact_px'], location)
            sample['physical_source_contact_px'] = contact
            sample['camera_quadrant'] = mounts[pose]['native_camera_quarter']
            mount_surface(sample['surface'], calibration)
        changes['library'][family_id] = family

    for family_id in member_families:
        family = deepcopy(environment['library'][family_id])
        for sample in family['samples']:
            sample['camera_quadrant'] = MEMBER_CAMERA_QUARTERS[sample['source_view']]
        changes['library'][family_id] = family

    mount = timber_record['physical_mount']
    matrix = np.asarray(mount['sourceToMountLocal']) @ np.diag([1, -1, 1, 1])
    calibration = {'sourceToLocal': matrix.tolist(),
                   'normalToLocal': np.linalg.inv(matrix[:, :3]).T.tolist()}
    anchor = np.asarray(mount['mount_anchor_source_xyz']) * [1, -1, 1]
    family_id = timber_record['catalog_id']
    family = deepcopy(environment['library'][family_id])
    for index, sample in enumerate(family['samples']):
        pose = sample['source_view']
        location = f'{family_id}/samples/{index}/{pose}'
        contact = physical_contact(sample['surface'], anchor, location)
        sample['physical_source_contact_px'] = retained_contact(
            contact, timber_record['contact_by_pose'][pose]['placement_contact_px'], location)
        sample['camera_quadrant'] = mount['camera_quarters'][pose]
        mount_surface(sample['surface'], calibration)
    # Supplied polygon X/Z already use host axes; subtract the old lower-floor
    # origin. Source centers have the more precise delivered mount-relative values.
    translation = matrix[:, 3]
    family['support_profile'] = {
        'contacts_XHZ': deepcopy(mount['contacts_relative_to_lower_floor_XHZ']),
        'supports': [{
            'center_XHZ': step['support_center_relative_to_lower_floor_XHZ'],
            'polygon_XZ': [[x + translation[0], z + translation[2]]
                           for x, z in step['authored_support']['support_polygon_xy_cells']],
            'contact_px_by_pose': step['authored_support']['contact_px_by_native_pose'],
        } for step in mount['support_sequence']],
        'lane_width_cells': mount['ascent_lane_width_cells'],
        'upper_landing_required': mount['upper_landing']['required'],
    }
    changes['library'][family_id] = family
    return changes
