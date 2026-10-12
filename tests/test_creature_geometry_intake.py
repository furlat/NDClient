"""Delivered source identity/partition acceptance, without gameplay or GPU work."""
import json
import math
from pathlib import Path

import numpy as np
import pytest
from PIL import Image

PROJECT = Path(__file__).resolve().parents[1]
FACTORY = Path('/mnt/c/Users/tommaso/Documents/assets/fantasy-unified-catalog/authored-creature-geometry-2026-10-12')
DATA = Path('/mnt/c/Users/tommaso/Documents/Dev/NDClientData')


@pytest.fixture(scope='module')
def index():
    return json.loads((PROJECT / 'generated/creature_geometry.json').read_text())


def test_every_delivered_physical_source_is_retained_without_new_clocks(index):
    expected = set()
    aliases = 0
    for package, layer in (('delivery', 'body'), ('animals/delivery', 'combined')):
        catalog = json.loads((FACTORY / package / 'catalog.json').read_text())
        for row in catalog['actions']:
            path = row['layers'][layer]['media']
            expected.add(path)
            aliases += len(row['aliases'])
            record = index['records'][path]
            assert record['frames'] == row['frames']
            assert len(record['registered_aliases']) == len(row['aliases'])
            assert 'fps' not in record, 'Only existing semantic aliases own playback clocks'
    assert set(index['records']) == expected
    assert index['source_count'] == len(expected) == 1438
    assert aliases == 429
    assert len(index['colour_sources']) == 98


@pytest.mark.parametrize(('family', 'action', 'cell'), [('wolf', 'idle', 64), ('boar', 'idle', 84), ('stag', 'idle', 96), ('elephant', 'idle', 128), ('stag', 'die', 96)])
def test_delivered_animal_colour_is_exact_existing_visible_partition(index, family, action, cell):
    relative = f'animals/delivery/actions/{family}/{action}/colour.png'
    media = index['colour_sources'][relative]
    record = index['records'][media]
    source = np.asarray(Image.open(DATA / '.media' / media.removeprefix('/media/')).convert('RGBA'))
    delivered = np.asarray(Image.open(FACTORY / relative).convert('RGBA'))
    components = json.loads((PROJECT / 'authoring/characters/sheet-components.json').read_text())
    selection = components[media]['selection']
    assert selection['kind'] == 'source_rgba' and selection['remainder'] == 'body'
    expected = source.copy()
    for rule in selection['rules']:
        assert rule['role'] == 'shadow'
        selected = np.all(source >= rule['minimum'], axis=2) & np.all(source <= rule['maximum'], axis=2)
        expected[selected, 3] = 0
    assert np.array_equal(delivered, expected), f'{family}/{action} changes original visible-body bytes'
    assert record['cell_size'] == [cell, cell]
    assert record['optical_camera']['origin'] == [cell / 2, cell * .75]
    assert record['colour_path'] == relative
    assert record['qualification']['visible_body_only']


def test_registered_aliases_keep_native_short_clip_and_authored_pivot(index):
    media = '/media/smallscale/authored/orcs-and-goblins/Bodies/Goblin 01/Block.png'
    record = index['records'][media]
    assert record['frames'] == 6
    assert record['cell_size'] == [128, 128]
    assert record['painted_pivot'] == [64, 87]
    assert record['optical_ground_pixels'] == pytest.approx(9 / math.cos(math.pi / 4))
    assert record['registered_aliases'] == [{'rig': 'smallscale.goblin01', 'clip': 'Block', 'category': 'Goblin01', 'resource': '/rigs/goblin01/body/Block.png', 'source_clip': 'Block', 'frames': 6, 'fps': 12}]
    assert 'colour_path' not in record


def test_stag_repeated_view_qualification_remains_explicit(index):
    media = index['colour_sources']['animals/delivery/actions/stag/die/colour.png']
    record = index['records'][media]
    assert record['status'] == 'validated_partial'
    assert record['source_coverage'] == pytest.approx(0.30754578754578754)
    qualification = record['qualification']['source_camera']
    assert qualification['all_eight_visible_rgba_rows_identical']
    assert not qualification['fixed_rotating_eight_view_assumption_supported']


def test_library_only_families_do_not_acquire_authored_placement(index):
    unknown = [r for r in index['records'].values() if r['painted_pivot'] is None]
    assert unknown
    assert all(not r['registered_aliases'] and r['optical_ground_pixels'] is None for r in unknown)
    report = json.loads((PROJECT / 'generated/creature_geometry_intake.json').read_text())
    missing = report['uncovered_current_body_aliases']
    assert len(missing) == 6
    assert {row['rig'] for row in missing} == {'smallscale.skeletonarcher05'}


def test_packet_affine_and_three_profile_paths_remain_source_local(index):
    for record in index['records'].values():
        assert record['depth_byte_range'] == [32, 224]
        assert record['depth_range'] == [-181.1370849898476, 249.01933598375615]
        assert set(record['normal_profiles']) == {'original', 'gentle', 'reference'}
        assert record['normal_profiles']['original'] == record['files']['normal']
        for path in list(record['files'].values()) + list(record['normal_profiles'].values()):
            assert not Path(path).is_absolute() and '..' not in Path(path).parts
        assert record['slots'] == ['body']
