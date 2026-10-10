"""Portable authoring preserves actual effect semantics, without engine or media IO."""
import json
from pathlib import Path
import shutil
import tempfile
import unittest

from tools.build_authoring import read_authoring

ROOT = Path(__file__).resolve().parents[1]


class AuthoringTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.document = read_authoring(ROOT)
        cls.catalog = cls.document['catalog']

    def selection(self, identity):
        return self.catalog['projectile_storage'][identity]['phases']['impact']['paired']

    def test_fireball_keeps_travel_separate_from_new_explosion(self):
        recipe = self.catalog['drafts']['spell.fireball']
        projectile = recipe['projectile']
        selection = self.selection(projectile['impact']['assetId'])
        self.assertEqual(selection['frame_window'], [0, 46])
        self.assertEqual(selection['playback_fps'], 24)
        self.assertEqual(projectile['impact']['composition'], 'paired_depth')
        self.assertIn('release', projectile['sourceSockets'])
        self.assertNotEqual(projectile['travel']['assetId'], projectile['impact']['assetId'])
        travel = self.catalog['projectile_storage'][projectile['travel']['assetId']]
        self.assertTrue(all('paired' not in phase for phase in travel['phases'].values()))

    def test_ice_knife_preserves_coverage_and_additive_flash(self):
        impact = self.catalog['drafts']['spell.ice_knife']['projectile']['impact']
        self.assertTrue(impact['enabled'])
        selection = self.selection(impact['assetId'])
        self.assertEqual(selection['kind'], 'directional_paired_composite')
        self.assertEqual(selection['material_semantics']['flash'], 'additive zero opacity')
        self.assertEqual(selection['material_semantics']['debris'], 'coverage')
        self.assertTrue(all(len(parts) == 2 for parts in selection['parts_by_facing'].values()))

    def test_directions_and_occurrence_coalescing_are_preserved(self):
        beam = self.selection('solar.sunbeam.surface')
        self.assertEqual(beam['banks']['E'], 'sunbeam-dir_7-lifecycle-q0')
        self.assertEqual(beam['banks']['SE'], 'sunbeam-dir_0-lifecycle-q0')
        wall = self.selection('wall.frigid_air_d0.hold.back')
        self.assertEqual(wall['selection_basis'], 'wall_axis')
        self.assertEqual(set(wall['banks']), {'d0', 'd1', 'd2', 'd3'})
        wave = self.selection('area.thunderwave.surface')
        self.assertTrue(wave['replace_historical_halves_with_one_instance'])
        self.assertEqual(wave['coalescing_group'], 'thunderwave')

    def test_every_selected_window_fits_and_no_retired_xyz_is_selected(self):
        for identity, storage in self.catalog['projectile_storage'].items():
            for phase in storage['phases'].values():
                self.assertFalse(phase.get('surfaceFrames'), identity)
                selection = phase.get('paired')
                if not selection:
                    continue
                start, end = selection['frame_window']
                banks = ([selection['bank']] if 'bank' in selection
                         else selection['banks'].values())
                for bank in banks:
                    self.assertLess(start, end, identity)
                    self.assertGreaterEqual(start, 0, identity)
                    self.assertLessEqual(end, self.catalog['paired_banks'][bank]['frame_count'], identity)

    def test_world_edit_is_visible_in_both_existing_export_views(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            authoring = root / 'authoring'
            authoring.mkdir()
            (authoring / 'catalog-index.json').write_text(json.dumps({
                'spatial_media': 'world.json#/spatial_media'}))
            (authoring / 'assets.json').write_text('{}')
            (authoring / 'environment').mkdir()
            (authoring / 'environment/index.json').write_text('{}')
            (authoring / 'items').mkdir()
            (authoring / 'items/index.json').write_text('{}')
            for duration in (10, 25):
                world = {'spatial_media': {'effect': {'holdFrames': duration}}}
                (authoring / 'world.json').write_text(json.dumps(world))
                result = read_authoring(root)
                self.assertEqual(result['world']['spatial_media'], result['catalog']['spatial_media'])
                self.assertEqual(result['catalog']['spatial_media']['effect']['holdFrames'], duration)

    def test_environment_preserves_door_frame_and_leaf_registration(self):
        environment = self.document['environment']
        door = environment['doors']['environment.door.fantasy_c1']
        self.assertEqual(door['pose_offset'], 1)
        self.assertEqual(door['frame_resource_by_pose'],
                         self.document['world']['stone_door_frame'])
        bank = environment['banks'][door['openings']['inward']]
        self.assertEqual((bank['frame_count'], bank['duration_ms']), (12, 750))
        for pose in bank['rows']:
            self.assertEqual(len(bank['frames_by_pose'][pose]), bank['frame_count'])
            self.assertEqual(len(bank['depth_frames_by_pose'][pose]), bank['frame_count'])
            # Depth calibration is not the same point as the artwork's pivot.
            self.assertNotEqual(bank['ground_origins_by_pose'][pose], bank['pivots_by_pose'][pose])
        owners = environment['doors'].keys() | environment['traps'].keys() | environment['props'].keys()
        for identity, wreck in environment['wrecks'].items():
            self.assertIn(wreck['source_item_id'], owners, identity)
        self.assertIn('environment.directional_door.wreck.clear', environment['wrecks'])
        self.assertFalse(any('desert' in name for name in environment['banks']))

    def test_environment_preserves_window_attachment_and_prop_contacts(self):
        environment = self.document['environment']
        wall = environment['props']['environment.window.fantasy_a4.wall']
        insert = environment['props']['environment.window.fantasy_a4.insert']
        self.assertTrue(insert['omit_with_destroyed_parent'])
        self.assertNotEqual(wall['destructions']['default'],
                            wall['destructions_without_attachments']['default'])
        self.assertEqual(wall['passage_point'], [0.4274, 0.004, 0.7202])
        self.assertEqual(set(wall['aperture_masks_by_pose']), {'e', 's', 'w', 'n'})
        for name, pivot in [('prop.content-red-covered-table.intact', [192, 204.5]),
                            ('prop.chest-b1.intact', [192, 271.36])]:
            self.assertEqual(environment['banks'][name]['ground_pivot'], pivot)
        stairs = self.document['world']['terrain_stairs']
        self.assertEqual(stairs['support_offsets'], [[0, 0, 0], [-1, 0, 1], [-2, 0, 2]])

    def test_environment_edits_assemble_without_engine_or_intake(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            authoring = root / 'authoring'
            authoring.mkdir()
            for filename in ('catalog-index.json', 'world.json', 'assets.json'):
                (authoring / filename).write_text('{}')
            (authoring / 'items').mkdir()
            (authoring / 'items/index.json').write_text('{}')
            shutil.copytree(ROOT / 'authoring/environment', authoring / 'environment')
            environment = json.loads(json.dumps(self.document['environment']))
            index = json.loads((authoring / 'environment/index.json').read_text())
            bank_path = authoring / index['banks']['door.fantasy-a1.inward']
            for duration in (750, 900):
                environment['banks']['door.fantasy-a1.inward']['duration_ms'] = duration
                bank_path.write_text(json.dumps(environment['banks']['door.fantasy-a1.inward']))
                self.assertEqual(read_authoring(root)['environment'], environment)

    def test_door_mount_qualification_is_linked_without_changing_placement(self):
        door = self.document['environment']['doors']['environment.door.indoor_door_elegant']
        reference = ROOT / 'authoring' / door['authoring_record']
        record = json.loads(reference.read_text())
        self.assertFalse(record['record']['mounting']['shared_physical_mount_validated'])
        self.assertTrue(record['installed_media'])
        bank = self.document['environment']['banks'][door['openings']['inward']]
        self.assertEqual(bank['pivots_by_pose']['e'], [100, 198])

    def test_wall_and_cliff_corners_keep_distinct_incident_faces(self):
        world = self.document['world']
        self.assertEqual(world['wall_corner_faces'], {
            'e': ['north', 'east'], 's': ['east', 'south'],
            'w': ['south', 'west'], 'n': ['west', 'north']})
        self.assertNotEqual(world['wall_corner_faces'], world['terrain_cliff']['corner_faces'])


if __name__ == '__main__':
    unittest.main()
