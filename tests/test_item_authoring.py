"""Equipment dependencies and authored appearance survive client assembly."""
from pathlib import Path
import unittest

from tools.build_authoring import read_authoring


ROOT = Path(__file__).resolve().parents[1]


class ItemAuthoringTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.document = read_authoring(ROOT)

    def test_equipment_layers_resolve_through_every_authored_body_action(self):
        document = self.document
        appearances = document['item_appearances']
        layers = [layer for row in appearances['hands'] for layer in row['layers']]
        sprites = set()
        for row in appearances['ground']:
            sprites.add(row['sprite_key'])
            layers.extend(row.get('layers', []))
            if row.get('shadow_sprite_key'):
                sprites.add(row['shadow_sprite_key'])
        for category in document['item_visuals']['categories']:
            for row in (category['base_presentation'], *category['variants']):
                layers.extend(row['equipment_layers'])
        sprites.update(layer['sprite_key'] for layer in layers)
        catalog = document['catalog']
        rig = catalog['rigs'][catalog['root_rig']]
        palettes = {row['category'] for row in document['source_palettes']['entries']}
        self.assertFalse(sprites - {'Shadow'} - palettes)
        for action, clip in rig['clips'].items():
            for sprite in sprites:
                with self.subTest(action=action, sprite=sprite):
                    self.assertIn(sprite, clip['sheets'])
                    self.assertIn(clip['sheets'][sprite], catalog['resources'])
        # Regression: this layer previously had no Run sheet registration.
        self.assertEqual(catalog['resources'][rig['clips']['Run']['sheets']['Chest1']],
                         '/media/smallscale/modular/Chest1/Run.png')

    def test_held_dropped_and_coated_items_keep_distinct_authored_data(self):
        appearances = self.document['item_appearances']
        dagger = next(row for row in appearances['hands']
                      if row['category'] == 'Dagger' and row['variant'] is None)
        self.assertEqual(dagger['slot'], 'weapon_melee_off')
        self.assertEqual(dagger['layers'], [
            {'render_layer': 'offhand', 'sprite_key': 'Offhand2', 'tint_rgb': 8952234}])
        club = next(row for row in appearances['ground']
                    if row['category'] == 'Club' and row['variant'] is None)
        self.assertEqual(club['rows_by_camera'], [2, 4, 6, 0])
        self.assertEqual(club['pivots_by_camera'],
                         [[55, 65.5], [66.5, 57.5], [75, 65], [64, 73]])
        self.assertEqual((club['scale'], club['reference_tile_width']), (0.75, 64))
        armor = next(row for row in appearances['ground']
                     if row['category'] == 'Padded Armor' and row['variant'] is None)
        self.assertEqual([layer['sprite_key'] for layer in armor['layers']],
                         ['Legs1', 'Chest4', 'Belt1'])
        category = next(row for row in self.document['item_visuals']['categories']
                        if row['base_category'] == 'Club')
        variant = next(row for row in category['variants']
                       if row['display_name'] == 'Ironbound Club')
        self.assertEqual(variant['visual_variant_id'], '10000001')
        self.assertEqual(variant['mechanical_factory_identity'],
                         'content.srd_5_1_cc:item:weapon.club@1')
        materials = {row['behavior_id']: row for row in self.document['item_materials']['recipes']
                     if row['damage_type'] == 'Fire'}
        self.assertEqual(materials['item.property.additional_damage']['tint_rgb'], 16739125)
        self.assertGreater(materials['condition.consumable.weapon_coat.fire']['priority'],
                           materials['item.property.additional_damage']['priority'])


if __name__ == '__main__':
    unittest.main()
