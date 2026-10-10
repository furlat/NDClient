"""Selected water and door references resolve in the assembled client document.

Input is tracked authoring, observed through the portable assembler. The output
must include an image resource for each selected material channel and door frame;
this does not depend on locally installed artwork or its folder layout.
"""
from pathlib import Path
import unittest

from tools.build_authoring import read_authoring


ROOT = Path(__file__).resolve().parents[1]


class EnvironmentLinkTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.document = read_authoring(ROOT)

    def test_water_material_channels_have_image_resources(self):
        assets = self.document['assets']
        for channel in ('mask', 'normal', 'ripple'):
            identity = assets['water'][channel]
            with self.subTest(channel=channel, resource=identity):
                self.assertTrue(identity in assets['resources'],
                                f'Water {channel} references missing image {identity}')
                resource = assets['resources'][identity]
                self.assertTrue(resource['path'].startswith('/media/'))
                self.assertTrue(all(size > 0 for size in resource['native_size']))

    def test_selected_door_frames_have_image_resources(self):
        resources = self.document['assets']['resources']
        for door, definition in self.document['environment']['doors'].items():
            for pose, identity in definition['frame_resource_by_pose'].items():
                with self.subTest(door=door, pose=pose, resource=identity):
                    self.assertTrue(identity in resources,
                                    f'{door} pose {pose} references missing image {identity}')
                    self.assertTrue(resources[identity]['path'].startswith('/media/'))

    def assert_links_resolve(self, links, owners):
        missing = [(source, target) for source, target in links if target not in owners]
        self.assertEqual(missing, [], 'Selected authoring references absent definitions')

    def test_environment_state_and_aftermath_banks_resolve(self):
        environment = self.document['environment']
        links = []
        for identity, door in environment['doors'].items():
            for field in ('openings', 'destructions'):
                links.extend((f'{identity}/{field}/{state}', bank)
                             for state, bank in door[field].items())
        for identity, prop in environment['props'].items():
            for field in ('intact', 'destructions', 'destructions_without_attachments'):
                links.extend((f'{identity}/{field}/{state}', bank)
                             for state, bank in prop.get(field, {}).items())
        for identity, trap in environment['traps'].items():
            links.append((f'{identity}/intact', trap['intact']))
            links.extend((f'{identity}/destructions/{state}', bank)
                         for state, bank in trap['destructions'].items())
        links.extend((f'wall_destructions/{material}', bank)
                     for material, bank in environment['wall_destructions'].items())
        self.assert_links_resolve(links, environment['banks'])

        owners = environment['doors'] | environment['props'] | environment['traps']
        self.assert_links_resolve(
            [(identity, wreck['source_item_id'])
             for identity, wreck in environment['wrecks'].items()], owners)
        for identity, wreck in environment['wrecks'].items():
            if wreck['source_item_id'] in environment['doors'] and wreck.get('outcome') is not None:
                door = environment['doors'][wreck['source_item_id']]
                for state in ('closed', *(f'open.{swing}' for swing in door['openings'])):
                    key = f'{state}.{wreck["outcome"]}'
                    self.assertTrue(key in door['destructions'],
                                    f'{identity} has no destruction bank for {key}')

    def test_terrain_architecture_and_image_animations_resolve(self):
        world, assets = self.document['world'], self.document['assets']
        links = []
        for material, poses in world['terrain'].items():
            if material == 'water':
                # This is the water material selector, not an image resource ID.
                self.assertEqual(poses, 'water.unity')
                continue
            links.extend((f'terrain/{material}/{pose}', image) for pose, image in poses.items())
        for field in ('stone_wall_straight', 'stone_wall_corner', 'wood_wall_straight',
                      'wood_wall_corner', 'stone_door_frame', 'wood_door_closed', 'wood_door_open'):
            links.extend((f'{field}/{pose}', image) for pose, image in world[field].items())
        for field in ('straight', 'corner'):
            links.extend((f'terrain_cliff/{field}/{pose}', image)
                         for pose, image in world['terrain_cliff'][field].items())
        links.extend((f'terrain_stairs/{pose}', image)
                     for pose, image in world['terrain_stairs']['poses'].items())
        for identity, animation in assets['animations'].items():
            links.extend((f'{identity}/frame/{frame}', image)
                         for frame, image in enumerate(animation['frames']))
        self.assert_links_resolve(links, assets['resources'])

    def test_prop_and_trap_animation_images_resolve(self):
        world, assets = self.document['world'], self.document['assets']
        links, animations = [], dict(world['spatial_effects'])
        lit = []
        for identity, prop in world['props'].items():
            for field in ('body_by_pose', 'active_body_by_pose'):
                links.extend((f'{identity}/{field}/{pose}', image)
                             for pose, image in (prop.get(field) or {}).items())
            if prop.get('lit_animation'):
                lit.append((identity, prop['lit_animation']))
            if prop.get('transition'):
                animations[f'{identity}/transition'] = prop['transition']
        self.assert_links_resolve(lit, assets['animations'])
        for identity, animation in animations.items():
            for pose, frames in animation['frames_by_pose'].items():
                links.extend((f'{identity}/{pose}/frame/{index}', image)
                             for index, image in enumerate(frames))
            if animation.get('actor_depth'):
                links.append((f'{identity}/actor_depth', animation['actor_depth']['asset_id']))
            if animation.get('projectile'):
                for pose, frames in animation['projectile']['frames_by_pose'].items():
                    links.extend((f'{identity}/projectile/{pose}/{index}', image)
                                 for index, image in enumerate(frames))
            if animation.get('tether'):
                for facing, frames in animation['tether']['frames_by_facing'].items():
                    links.extend((f'{identity}/tether/{facing}/{index}', image)
                                 for index, image in enumerate(frames))
            for residue, poses in animation.get('residue_overlays', {}).items():
                for pose, frames in poses.items():
                    links.extend((f'{identity}/{residue}/{pose}/{index}', image)
                                 for index, image in enumerate(frames))
        self.assert_links_resolve(links, assets['resources'])

    def test_residue_receivers_and_surface_images_resolve(self):
        world = self.document['world']
        links = []
        particle_links = list(world['residue_particles'].items())
        for identity, poses in world['residue_ground'].items():
            links.extend((f'{identity}/{pose}', image) for pose, image in poses.items())
        for identity, surface in world['residue_surfaces'].items():
            links.extend((f'{identity}/{field}', surface[field]) for field in ('floor_atlas', 'wall_atlas'))
        particle_links.extend((identity, surface['asset_id'])
                              for identity, surface in world['liquid_surfaces'].items())
        receivers = world['residue_wall_faces']
        links.extend((f'residue receiver/{image}', image) for image in receivers['assets'])
        self.assert_links_resolve(links, self.document['assets']['resources'])
        self.assert_links_resolve(particle_links, self.document['catalog']['action_media_assets'])
        self.assert_links_resolve(list(receivers['assets'].items()), receivers['profiles'])

    def test_devices_preserve_operator_wreck_and_sheet_links(self):
        catalog = self.document['catalog']
        operator_links, wreck_links, media = [], [], []
        for kind in ('devices', 'device_wrecks'):
            for identity, device in catalog[kind].items():
                operator_links.append((identity, device['operator_recipe']))
                for bank in device['banks']:
                    media.extend(bank['sheets'])
                destruction = device.get('destruction')
                if destruction:
                    wreck_links.append((identity, destruction['wreck_item_id']))
                    media.extend(destruction['wreck_sheets'])
                    for sheets in destruction['pitch_banks'].values():
                        media.extend(sheets)
        self.assert_links_resolve(operator_links, catalog['body_action_recipes'])
        self.assert_links_resolve(operator_links, catalog['body_action_bindings'])
        self.assert_links_resolve(wreck_links, catalog['device_wrecks'])
        self.assertEqual([url for url in media if not url.startswith('/media/')], [])

    def test_portal_hatch_keeps_both_components_and_transition_media(self):
        portal = self.document['catalog']['portals']['spatial_effect.environment.portal_hatch']
        hatch = portal['hatch']
        self.assertNotEqual(hatch['sheet'], hatch['front'])
        media = [hatch['sheet'], hatch['front']]
        for side in ('entrance', 'exit'):
            for pages in portal[side]['pages']:
                media.extend(pages)
        self.assertEqual([url for url in media if not url.startswith('/media/')], [])


if __name__ == '__main__':
    unittest.main()
