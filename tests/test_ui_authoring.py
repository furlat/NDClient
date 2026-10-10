"""Selected artwork remains connected at the portable authoring boundary."""
from pathlib import Path
import unittest

from tools.build_authoring import read_authoring


ROOT = Path(__file__).resolve().parents[1]


class UIAuthoringTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.document = read_authoring(ROOT)

    def test_all_selected_ui_references_resolve_without_legacy_artwork(self):
        resources = self.document['ui_resources']
        for key, row in resources.items():
            with self.subTest(resource=key):
                self.assertTrue(row['path'].startswith('/media/ui/'))
                expected = [48, 48] if key.startswith('icon:') else [192, 256]
                self.assertEqual(row['native_size'], expected)
                self.assertEqual(row['pivot'], [0, 0])
                self.assertIsNone(row.get('rect'))
                self.assertTrue((ROOT / '.media' / row['path'].removeprefix('/media/')).is_file())
        for collection in self.document['ui_presentation'].values():
            for row in collection.values():
                for kind in ('icon', 'portrait'):
                    key = row['presentation'].get(kind + '_key')
                    if key is not None:
                        self.assertIn(kind + ':' + key, resources)
        for row in self.document['ui_choices']:
            self.assertIn('icon:' + row['icon_key'], resources)
        self.assertFalse(self.document['ui_skin'])

    def test_native_spells_conditions_and_creatures_select_the_delivered_art(self):
        resources = self.document['ui_resources']
        self.assertEqual(resources['icon:spell.fireball']['path'],
                         '/media/ui/icons/smooth48/spell.fireball.png')
        slow = resources['icon:condition.dnd-spells-transmutation-slowedeffect']['path']
        frost = resources['icon:condition.dnd-spells-evocation-rayoffrosteffect']['path']
        self.assertNotEqual(slow, frost)
        for creature, filename in [('goblin', 'goblin'), ('dretch', 'dretch'), ('wolf', 'wolf'),
                                   ('skeleton_archer', 'undead--5archer'), ('orc', 'orcs_goblins--orc-01')]:
            self.assertEqual(resources['portrait:creature.' + creature]['path'],
                             '/media/ui/portraits/192x256/creature-portraits-bg1-2026-10-08/' + filename + '.png')
        self.assertNotIn('portrait:creature.skeleton_warrior', resources)

    def test_free_portraits_do_not_create_native_creature_bindings(self):
        resources = self.document['ui_resources']
        choices = self.document['ui_presentation']['portrait_choices']
        for key in choices:
            self.assertFalse(key.startswith('creature.'))
        fighter = resources['portrait:hero.fighter_l5_shield_torch.hero']
        self.assertEqual(fighter, resources['portrait:fighter--human-white--male'])
        self.assertIn('New premade default',
                      choices['hero.fighter_l5_shield_torch.hero']['approximation'])

    def test_configuration_choices_keep_native_values_and_conditional_icons(self):
        choices = self.document['ui_choices']
        curse = next(row for row in choices if row['owner']['content_id'] == 'spell.bestow_curse'
                     and row['field'] == 'curse_option' and row['value'] == 1)
        self.assertIsNone(curse['facet'])
        self.assertIs(type(curse['value']), int)
        strength = next(row for row in choices if row['owner']['content_id'] == 'spell.bestow_curse'
                        and row['field'] == 'cursed_ability' and row['value'] == 'strength')
        self.assertEqual(strength['requirements'], {'curse_option': 1})
        radiant = next(row for row in choices if row['owner']['content_id'] == 'spell.spirit_guardians'
                       and row['value'] == 'radiant')
        self.assertEqual((radiant['facet'], radiant['field'], radiant['field_value']),
                         ('damage_type', 'damage_type', 'Radiant'))
        side = next(row for row in choices if row['owner']['content_id'] == 'spell.wall_of_fire'
                    and row['value'] == 'left')
        self.assertEqual((side['facet'], side['field'], side['requirements']),
                         ('side', 'hot_side', {'form': 'segment'}))


if __name__ == '__main__':
    unittest.main()
