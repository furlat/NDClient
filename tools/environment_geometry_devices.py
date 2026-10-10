"""Adopt supplied device/hatch companions at their existing selected axes."""
import json
from pathlib import Path


def _staged_document(path, changes):
    if path not in changes:
        changes[path] = json.loads(path.read_text())
    return changes[path]


def _place(frames, key, value, identity):
    if key in frames:
        raise ValueError(f'Duplicate selected device surface {identity}: {key}')
    frames[key] = value


def _device_frames(intake, doc, context, destination, row_count, frame_count, selected_sheets, cell):
    if doc['animation_frame_count'] != frame_count or doc['colour_cell'] != cell:
        raise ValueError('Device companion clock/cell differs from selected colour: ' + str(context))
    samples = {}
    for frame in doc['frames']:
        q, row, index = frame['camera_quadrant'], frame['aim_row'], frame['animation_frame_index']
        if not (0 <= q < 4 and 0 <= row < row_count and 0 <= index < frame_count):
            raise ValueError('Device companion axis outside selected source: ' + str(context))
        colour = frame['selected_colour']
        expected_rect = [index * cell[0], row * cell[1], *cell]
        if colour['rect'] != expected_rect or intake.existing_media(colour['path']) != selected_sheets[q]:
            raise ValueError('Device companion is registered to different colour: ' + str(context))
        _place(samples, (q, row, index), intake.surface(frame, doc, context, destination), doc['bank_id'])
    expected = {(q, row, index) for q in range(4) for row in range(row_count) for index in range(frame_count)}
    if samples.keys() != expected:
        raise ValueError('Incomplete selected device surface coverage: ' + str(context))
    return [[[samples[q, row, index] for index in range(frame_count)]
             for row in range(row_count)] for q in range(4)]


def _adopt_device(intake, entry, devices):
    source, _ = intake.read_ref(entry['owner'].partition('#')[0])
    ids = [identity for identity, device_id in source['bindings'].items() if device_id == entry['existing_id']]
    if not ids or any(identity not in devices for identity in ids):
        raise ValueError('Delivered device has no existing client binding: ' + entry['existing_id'])
    for identity in ids:
        device = devices[identity]
        for selected in entry['receipt_selection']['effective']:
            doc, context = intake.read_ref(selected['reference'])
            state = doc['state']
            if doc['device_id'] != entry['existing_id']:
                raise ValueError('Effective receipt names another device: ' + str(context))
            destination = Path('environment/devices') / entry['existing_id'] / 'geometry' / state
            if state == 'wreck':
                destruction = device['destruction']
                frames = _device_frames(intake, doc, context, destination, len(device['rows']), 1,
                                        destruction['wreck_sheets'], device['cell'])
                destruction['wreck_surfaces_by_camera'] = [[row[0] for row in camera] for camera in frames]
                continue
            owner = device if state == 'firing' else device['destruction'] if state == 'destruction' else None
            if owner is None:
                raise ValueError('Unknown delivered device state: ' + state)
            pitch = doc['pitch_degrees']
            if state == 'firing':
                banks = [bank for bank in owner['banks'] if bank['degrees'] == pitch]
                if len(banks) != 1:
                    raise ValueError('Delivered pitch does not select one authored device bank: ' + str(context))
                sheets = banks[0]['sheets']
            else:
                pitches = [key for key in owner['pitch_banks'] if float(key) == pitch]
                if len(pitches) != 1:
                    raise ValueError('Delivered pitch does not select one authored destruction bank: ' + str(context))
                sheets = owner['pitch_banks'][pitches[0]]
            if doc['fps'] != owner['fps']:
                raise ValueError('Device companion FPS differs from selected source: ' + str(context))
            destination /= 'pitch' + format(pitch, 'g')
            surfaces = _device_frames(intake, doc, context, destination, len(device['rows']), owner['frame_count'],
                                      sheets, device['cell'])
            if state == 'firing':
                banks[0]['surface_frames_by_camera'] = surfaces
            else:
                owner.setdefault('surface_frames_by_pitch', {})[pitches[0]] = surfaces


def _adopt_hatch(intake, entry, portals):
    hatch = portals[entry['existing_id']]['hatch']
    for selected in entry['receipt_selection']['effective']:
        parent, parent_path = intake.read_ref(selected['reference'])
        for component in parent['components']:
            doc, context = intake.read_ref(component['geometry_delivery'], parent_path)
            layer = component['name']
            owner_field = {'overlay': 'surface_frames_by_camera', 'front': 'front_surface_frames_by_camera'}[layer]
            colour_sheet = hatch['sheet' if layer == 'overlay' else 'front']
            samples = {}
            cell = hatch['cell']
            if doc['colour_cell'] != cell or doc['fps'] != hatch['fps']:
                raise ValueError('Hatch companion cell/clock differs from its colour: ' + str(context))
            destination = Path('environment/portals/geometry/hatch') / layer
            for frame in doc['frames']:
                colour, index = frame['selected_colour'], frame['frame_index']
                rect = colour['rect']
                q, remainder = divmod(rect[1], cell[1])
                if (remainder or not 0 <= q < 4 or rect != [index * cell[0], q * cell[1], *cell]
                        or intake.existing_media(colour['path']) != colour_sheet):
                    raise ValueError('Hatch companion is registered to different colour: ' + str(context))
                _place(samples, (q, index), intake.surface(frame, doc, context, destination), layer)
            count = max(index for _, index in samples) + 1
            if samples.keys() != {(q, index) for q in range(4) for index in range(count)}:
                raise ValueError('Incomplete hatch companion coverage: ' + str(context))
            if max(*hatch['opening'], *hatch['closing']) >= count:
                raise ValueError('Hatch companions omit an authored opening/closing frame: ' + str(context))
            hatch[owner_field] = [[samples[q, index] for index in range(count)] for q in range(4)]


def adopt_devices(intake, records, changes):
    """Stage existing client JSON only; the caller owns all eventual writes."""
    devices = _staged_document(intake.authoring / 'catalog/devices.json', changes)
    wrecks = _staged_document(intake.authoring / 'catalog/device_wrecks.json', changes)
    portals = _staged_document(intake.authoring / 'catalog/portals.json', changes)
    for entry in records:
        if entry['list'] != 'devices':
            continue
        if entry['existing_id'] in portals:
            _adopt_hatch(intake, entry, portals)
        else:
            _adopt_device(intake, entry, devices)
    # The existing exported catalog repeats DeviceArt beneath its wreck ID.
    # Keep that owner complete without creating another file or identity system.
    for device in devices.values():
        destruction = device.get('destruction')
        if destruction is None:
            continue
        wreck = wrecks[destruction['wreck_item_id']]
        if wreck['identity'] != device['identity']:
            raise ValueError('Wreck owner does not share its selected device identity')
        for bank in device['banks']:
            matching = [row for row in wreck['banks'] if row['degrees'] == bank['degrees']]
            if len(matching) != 1 or matching[0]['sheets'] != bank['sheets']:
                raise ValueError('Wreck owner differs from its selected device pitch bank')
            matching[0]['surface_frames_by_camera'] = bank['surface_frames_by_camera']
        if wreck['destruction']['wreck_sheets'] != destruction['wreck_sheets']:
            raise ValueError('Wreck owner differs from its selected wreck source')
        for field in ('surface_frames_by_pitch', 'wreck_surfaces_by_camera'):
            wreck['destruction'][field] = destruction[field]
