"""Character authoring reaches real rig sheets without new gameplay assignments."""
import json
from pathlib import Path
import tempfile
from struct import unpack
import unittest

from tools.build_authoring import check_resources, read_catalog


ROOT = Path(__file__).resolve().parents[1]


class CharacterComponentTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.catalog = read_catalog(ROOT / 'authoring')
        cls.components = cls.catalog['sheet_components']
        schema = json.loads((ROOT / 'authoring/schemas/animation.schema.json').read_text())
        cls.excluded_slots = schema['$defs']['BodyRig']['properties']['selection_excluded_slots']['default']

    def test_every_registered_rig_sheet_has_source_component_authoring(self):
        self.assertIn('neuroclient.modular', self.catalog['rigs'])
        self.assertIn('smallscale.goblin08', self.catalog['rigs'])
        self.assertIn('smallscale.bison', self.catalog['rigs'])
        for rig_id, rig in self.catalog['rigs'].items():
            for action, clip in rig['clips'].items():
                for address in clip['sheets'].values():
                    with self.subTest(rig=rig_id, action=action, address=address):
                        url = self.catalog['resources'][address]
                        self.assertIn(url, self.components)

    def test_original_modular_and_fixed_components_keep_their_roles(self):
        for folder, role in [('Shadow', 'shadow'), ('Slash1', 'accent'),
                             ('NakedBody', 'body')]:
            url = f'/media/smallscale/modular/{folder}/Idle.png'
            self.assertEqual(self.components[url]['selection'],
                             {'kind': 'whole', 'role': role})
        demon = self.components[
            '/media/smallscale/authored/demons/Combined/Demon Beast 1/Attack 1.png']
        self.assertEqual(set(demon['source_layers']), {'body', 'shadow', 'accent'})
        self.assertEqual(demon['composition'], {'kind': 'source_interaction', 'has_accent': True})
        for sheet in self.components.values():
            for role, url in sheet.get('source_layers', {}).items():
                with self.subTest(url=url):
                    self.assertEqual(self.components[url]['selection'],
                                     {'kind': 'whole', 'role': role})

    def test_flattening_and_vendor_pose_mismatch_remain_visible_to_consumers(self):
        wizard = self.components[
            '/media/smallscale/authored/characters/With shadow/3Wizard/Run.png']
        self.assertEqual(set(wizard['limitations']),
                         {'visible_partition_only', 'source_body_pose_mismatch'})
        # Wizard's wrong-pose counterpart must not become a body-removal mask.
        self.assertEqual(wizard['selection']['remainder'], 'body')
        self.assertEqual([rule['role'] for rule in wizard['selection']['rules']], ['shadow'])
        for url, sheet in self.components.items():
            if ('/Combined/' in url or '/With shadow/' in url or '/Zombies with shadow/' in url) and 'composition' not in sheet:
                self.assertIn('visible_partition_only', sheet['limitations'], url)
        # Translucent coloured zombie hair must not be declared a weapon swoosh.
        zombie = self.components[
            '/media/smallscale/authored/zombies-hd/With shadow/ZombieFemale5/Idle.png']
        self.assertEqual(zombie['selection']['remainder'], 'body')
        self.assertNotIn('accent', [rule['role'] for rule in zombie['selection']['rules']])

    def test_every_goblin_and_demon_combined_sheet_has_controllable_sources(self):
        selected = {url: row for url, row in self.components.items()
                    if any('/'+pack+'/Combined/' in url
                           for pack in ('demons', 'orcs-and-goblins'))}
        self.assertEqual(len(selected), 1368)
        for url, row in selected.items():
            with self.subTest(url=url):
                self.assertEqual(row['composition']['kind'], 'source_interaction')
                self.assertNotIn('selection', row)
                self.assertNotIn('accent_material_mask', row)
                self.assertTrue({'body', 'shadow'} <= row['source_layers'].keys())
                if row['composition']['has_accent']:
                    self.assertIn('accent', row['source_layers'])
                sizes = set()
                for source in (url, *row['source_layers'].values()):
                    with (ROOT / '.media' / source.removeprefix('/media/')).open('rb') as image:
                        sizes.add(unpack('>II', image.read(24)[16:24]))
                self.assertEqual(len(sizes), 1)

    def test_resource_check_includes_the_classified_source_and_its_mask(self):
        source = '/media/creature/Attack.png'
        mask = '/media/creature/Component masks/Attack.png'
        document = {'sheet_components': {source: {
            'selection': {'kind': 'mask', 'mask': {'path': mask, 'rect': [0, 0, 1, 1]}}}}}
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            mask_file = root / '.media' / mask.removeprefix('/media/')
            mask_file.parent.mkdir(parents=True)
            mask_file.touch()
            with self.assertRaisesRegex(ValueError, 'Missing installed media'):
                check_resources(document, root)
            (root / '.media' / source.removeprefix('/media/')).touch()
            self.assertEqual(check_resources(document, root), 2)

    def test_fixed_rig_companions_have_explicit_source_and_activation_connections(self):
        resources = self.catalog['resources']
        for rig_id, rig in self.catalog['rigs'].items():
            if rig_id == self.catalog['root_rig']:
                continue
            body_category, = rig['slot_categories']['body']
            for action, clip in rig['clips'].items():
                with self.subTest(rig=rig_id, action=action):
                    body_url = resources[clip['sheets'][body_category]]
                    components = self.components[body_url]
                    if 'shadow' in rig['slot_categories']:
                        shadow_category, = rig['slot_categories']['shadow']
                        self.assertEqual(components['source_layers']['shadow'],
                                         resources[clip['sheets'][shadow_category]])
                    if components.get('composition', {}).get('has_accent'):
                        accent = components['source_layers']['accent']
                        owners = [layer for layer in clip.get('layers', [])
                                  if resources[clip['sheets'][layer['category']]] == accent]
                        self.assertEqual(len(owners), 1)
                        self.assertIn(owners[0]['enabled'], (True, False))
                        self.assertIn(owners[0]['slot'], rig.get('selection_excluded_slots', self.excluded_slots))
        # The source inspection's all-on comparison is not the gameplay default.
        for identity, clip, expected in [('smallscale.goblin08', 'Attack5', True),
                                        ('smallscale.goblin03', 'Attack1', False),
                                        ('smallscale.demonbeast01', 'Attack1', False)]:
            self.assertIs(self.catalog['rigs'][identity]['clips'][clip]['layers'][0]['enabled'], expected)

    def test_animal_shadow_connections_preserve_authored_geometry_and_partition(self):
        rig = self.catalog['rigs']['smallscale.bison']
        clip = rig['clips']['Idle']
        url = self.catalog['resources'][clip['sheets']['Bison']]
        row = self.components[url]
        self.assertEqual(row['selection']['kind'], 'source_rgba')
        self.assertIn('visible_partition_only', row['limitations'])
        self.assertNotIn('composition', row)
        self.assertNotIn('body', row['source_layers'])
        self.assertEqual(row['source_layers']['shadow'],
                         self.catalog['resources'][clip['sheets']['BisonShadow']])
        self.assertEqual(rig['lifecycle_scale'], .643)


if __name__ == '__main__':
    unittest.main()
