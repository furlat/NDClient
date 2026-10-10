"""Adopted companions preserve source registration, layers and animation axes.

Only tracked client authoring is read. Tests do not require supplier exports,
installed media, the engine, or a running renderer.
"""
from pathlib import Path
import json
import unittest

from tools.build_authoring import read_authoring


ROOT = Path(__file__).resolve().parents[1]
DOORS = {
    'indoor-door-shabby': (37, 1132, [('g10', 'g1')]),
    'indoor-door-elegant': (28, 916, [('d5', 'd8'), ('f5', 'f8')]),
    'indoor-door-shabby-plain': (26, 868, [('g10', 'g1'), ('d5', 'd8'), ('f5', 'f8')]),
    'indoor-door-shabby-battens': (33, 1036, [('g10', 'g1')]),
    'indoor-door-shabby-patched': (30, 964, [('g10', 'g1')]),
    'indoor-door-elegant-three-panel': (24, 820, [('d5', 'd8'), ('f5', 'f8')]),
}


def affine(matrix, point):
    return [sum(a*b for a,b in zip(row[:3],point)) + row[3] for row in matrix]


def rotate(point, quarter):
    x,h,z = point
    return ((x,h,z), (-z,h,x), (-x,h,-z), (z,h,-x))[quarter % 4]


def project(point, quarter):
    x,h,z = rotate(point,quarter)
    return (64*(x-z), 32*(x+z)-64*h)


class EnvironmentGeometryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.document = read_authoring(ROOT)

    def test_bed_native_grid_keeps_existing_colour_size_and_clock(self):
        bank = self.document['environment']['banks']['prop.bed.intact']
        self.assertEqual(bank['cell'], [384, 384])
        for pose in bank['rows']:
            samples = bank['surface_frames_by_pose'][pose]
            self.assertEqual(len(samples), bank['frame_count'])
            for sample in samples:
                self.assertEqual(sample['geometry_region']['rect'][2:], [192, 192])
                self.assertEqual(sample['geometry_sampling']['scale'], [.5, .5])
                self.assertEqual(sample['normal']['region'], sample['geometry_region'])
                self.assertEqual(sample['normal']['encoding'], 'oct8_ba')
        legacy = self.document['environment']['banks']['trap.blade.intact']
        self.assertEqual(legacy['actor_depth'].get('encoding', 'rg16le_contact'), 'rg16le_contact')
        self.assertEqual(legacy['surface_frames_by_pose']['e'][0]['geometry']['encoding'],
                         'rg16be_oct8_rgba8')

    def test_crate_corrected_rest_does_not_replace_destruction_frames(self):
        bank = self.document['environment']['banks']['prop.crate.break']
        self.assertEqual(bank['frame_count'], 26)
        for pose in bank['rows']:
            with self.subTest(pose=pose):
                samples = bank['surface_frames_by_pose'][pose]
                self.assertEqual(len(samples), len(bank['frames_by_pose'][pose]))
                self.assertNotEqual(samples[0]['geometry_region']['path'],
                                    samples[1]['geometry_region']['path'])
                self.assertTrue(all(sample['geometry']['kind'] == 'ray_depth' for sample in samples))
                self.assertTrue(all(sample['normal']['normalToLocal'] for sample in samples))

    def test_d6_keeps_both_sampled_depth_and_aperture_mesh(self):
        resources = self.document['assets']['resources']
        for pose, identity in self.document['world']['stone_door_frame'].items():
            with self.subTest(pose=pose):
                image = resources[identity]
                self.assertEqual(image['geometry']['kind'], 'ray_depth')
                mesh = image['receiving_geometry']
                self.assertEqual(mesh['kind'], 'mesh')
                self.assertEqual(len(mesh['vertices']), len(mesh['uvs']))
                self.assertEqual(len(mesh['triangles']), len(mesh['faceIds']))
                self.assertGreater(len(mesh['triangles']), 1)
                self.assertTrue(image['geometry_region']['path'].startswith('/media/'))

    def test_spike_paint_uses_existing_physical_receiver(self):
        resources = self.document['assets']['resources']
        paint = resources['spikes.blood.e.1']
        self.assertEqual(paint['receiver'], {'kind': 'resource', 'resource_id': 'spikes.e.1'})
        self.assertIn(paint['receiver']['resource_id'], resources)
        self.assertIn('surface_paint', [role['role'] for role in paint['roles']])

    def test_hatch_front_and_moving_overlay_retain_distinct_companions(self):
        hatch = self.document['catalog']['portals']['spatial_effect.environment.portal_hatch']['hatch']
        moving, front = hatch['surface_frames_by_camera'], hatch['front_surface_frames_by_camera']
        self.assertEqual(len(moving), 4)
        self.assertEqual(len(front), 4)
        required = max(*hatch['opening'], *hatch['closing'])
        for camera in range(4):
            self.assertGreater(len(moving[camera]), required)
            self.assertEqual(len(front[camera]), len(moving[camera]))
            for index in range(len(moving[camera])):
                self.assertNotEqual(moving[camera][index]['geometry_region'],
                                    front[camera][index]['geometry_region'])

    def test_devices_keep_pitch_camera_aim_and_frame_axes(self):
        for identity, device in self.document['catalog']['devices'].items():
            with self.subTest(device=identity):
                for bank in device['banks']:
                    self.assert_device_axes(bank['surface_frames_by_camera'], device, device['frame_count'])
                destruction = device['destruction']
                self.assertEqual(set(destruction['surface_frames_by_pitch']), set(destruction['pitch_banks']))
                for cameras in destruction['surface_frames_by_pitch'].values():
                    self.assert_device_axes(cameras, device, destruction['frame_count'])
                self.assertEqual(len(destruction['wreck_surfaces_by_camera']), 4)
                self.assertTrue(all(len(camera) == len(device['rows'])
                                    for camera in destruction['wreck_surfaces_by_camera']))

    def assert_device_axes(self, cameras, device, frame_count):
        self.assertEqual(len(cameras), 4)
        for camera in cameras:
            self.assertEqual(len(camera), len(device['rows']))
            for aim in camera:
                self.assertEqual(len(aim), frame_count)
                self.assertTrue(all(sample['geometry']['kind'] == 'ray_depth' for sample in aim))

    def test_existing_wreck_owners_keep_their_device_companions(self):
        catalog = self.document['catalog']
        for device in catalog['devices'].values():
            wreck = catalog['device_wrecks'][device['destruction']['wreck_item_id']]
            self.assertEqual(wreck['identity'], device['identity'])
            self.assertEqual(wreck['destruction']['wreck_surfaces_by_camera'],
                             device['destruction']['wreck_surfaces_by_camera'])
            self.assertEqual(wreck['destruction']['surface_frames_by_pitch'],
                             device['destruction']['surface_frames_by_pitch'])

    def assert_contact_and_normals(self, surface, contact, source_anchor):
        geometry = surface['geometry']
        mapping = surface['geometry_sampling']
        u,v = [contact[i]*mapping['scale'][i]+mapping.get('offset',[0,0])[i] for i in (0,1)]
        origin = [row[0]*u+row[1]*v+row[2] for row in geometry['pixelToRayOrigin']]
        direction = geometry['rayDirection']
        t = sum((a-o)*d for a,o,d in zip(source_anchor,origin,direction))/sum(d*d for d in direction)
        source = [o+d*t for o,d in zip(origin,direction)]
        for actual,expected in zip(source,source_anchor):
            self.assertAlmostEqual(actual,expected,places=5)
        for value in affine(geometry['sourceToLocal'], source):
            self.assertAlmostEqual(value,0,places=5)
        # Normal transport preserves tangent/normal dot products under the mount.
        linear = geometry['sourceToLocal']
        normal = surface['normal']['normalToLocal']
        for a in range(3):
            for b in range(3):
                self.assertAlmostEqual(sum(linear[i][a]*normal[i][b] for i in range(3)),
                                       float(a==b),places=6)

    def test_all_delivered_door_frames_and_library_samples_have_effective_mounts(self):
        env=self.document['environment']
        frames=0
        for stem,(destruction_frames,library_count,_) in DOORS.items():
            door=env['doors']['environment.door.'+stem.replace('-','_')]
            expected=json.loads((ROOT/'authoring/environment/source-records/doors'/f'generated-{stem}.json').read_text())['record']['physical_mount']['views']
            self.assertEqual(door['pose_offset'],0)
            self.assertEqual(len(door['openings']),2)
            self.assertEqual(len(door['destructions']),3)
            for bank_id in (*door['openings'].values(),*door['destructions'].values()):
                bank=env['banks'][bank_id]
                self.assertEqual(bank['camera_quarter_by_pose'],{'e':0,'s':3,'w':2,'n':1})
                self.assertEqual(bank['frame_count'],destruction_frames if 'destruction' in bank_id else 24)
                for pose,surfaces in bank['surface_frames_by_pose'].items():
                    contact=bank['physical_source_contact_by_pose'][pose]
                    self.assertAlmostEqual(contact[0],bank['cell'][0]/2,places=3)
                    self.assertAlmostEqual(contact[1],bank['cell'][1]/2+80,places=3)
                    for surface in surfaces:
                        self.assertEqual(surface['geometry']['sourceToLocal'],expected[pose]['calibration']['sourceToLocal'])
                        self.assertNotIn('mounts remain unresolved',surface['qualification'])
                        self.assert_contact_and_normals(surface,contact,[0,0,0])
                        frames+=1
            family=env['library']['generated-'+stem]
            self.assertEqual(len(family['samples']),library_count)
            for sample in family['samples']:
                pose=sample['source_view']
                self.assertEqual(sample['camera_quadrant'],expected[pose]['native_camera_quarter'])
                self.assertEqual(sample['surface']['geometry']['sourceToLocal'],expected[pose]['calibration']['sourceToLocal'])
                self.assert_contact_and_normals(sample['surface'],sample['physical_source_contact_px'],[0,0,0])
        self.assertEqual(frames,3288)

    def test_compatible_member_sets_and_capture_views_remain_distinct(self):
        env=self.document['environment']
        for stem,(_,_,pairs) in DOORS.items():
            variants=env['doors']['environment.door.'+stem.replace('-','_')]['assembly_variants']
            self.assertEqual(set(variants),{'fantasy.wall.'+header for header,_ in pairs})
            for i,(header,partition) in enumerate(pairs):
                variant=variants['fantasy.wall.'+header]
                self.assertEqual(variant['primary'],i==0)
                members=variant['members']
                self.assertEqual([m['role'] for m in members],
                                 ['supported_floor','opening_header','adjacent_partition','adjacent_partition'])
                self.assertEqual([m['family_id'] for m in members],
                                 ['fantasy.ground.f1','fantasy.wall.'+header,*['fantasy.wall.'+partition]*2])
                for member,dz in zip(members,[0,0,-1,1]):
                    x,h,z=member['offset_XHZ']
                    self.assertAlmostEqual(x,-.4409448566929133,places=6)
                    self.assertAlmostEqual(h,-.06299272440944884,places=6)
                    self.assertEqual(z,dz)
                    for sample in env['library'][member['family_id']]['samples']:
                        self.assertEqual(sample['camera_quadrant'],{'e':0,'s':1,'w':2,'n':3}[sample['source_view']])

    def test_mount_projection_survives_elevation_and_physical_camera_rotation(self):
        env=self.document['environment']
        # A non-origin source point checks the complete camera/mount projection,
        # beyond the tautology of placing the contact at the floor anchor.
        for family_id,source_point in [('generated-indoor-door-elegant',[.25,.4,1]),
                                      ('generated-timber-stair-flight',[.25,.6,1])]:
            samples={s['camera_quadrant']:s for s in reversed(env['library'][family_id]['samples'])}
            for rotation in range(4):
                for camera in range(4):
                    sample=samples[(rotation+camera)%4]
                    g=sample['surface']['geometry'];d=g['rayDirection'];o=g['pixelToRayOrigin']
                    # Find u,v,t independently by scalar determinants (no import of the adapter).
                    columns=[[o[i][0] for i in range(3)],[o[i][1] for i in range(3)],d]
                    rhs=[source_point[i]-o[i][2] for i in range(3)]
                    def det(a,b,c):
                        return a[0]*(b[1]*c[2]-b[2]*c[1])-b[0]*(a[1]*c[2]-a[2]*c[1])+c[0]*(a[1]*b[2]-a[2]*b[1])
                    a,b,c=columns;divisor=det(a,b,c)
                    uv=[det(rhs,b,c)/divisor,det(a,rhs,c)/divisor]
                    mapping=sample['surface']['geometry_sampling']
                    pixel=[(uv[i]-mapping['offset'][i])/mapping['scale'][i] for i in (0,1)]
                    local=rotate(affine(g['sourceToLocal'],source_point),rotation)
                    for height in (0,2):
                        anchor=[3,height,-2]
                        expected=project([a+b for a,b in zip(anchor,local)],camera)
                        base=project(anchor,camera)
                        sprite=[base[i]+sample['scale']*(sample['pivot'][i]-sample['physical_source_contact_px'][i]) for i in (0,1)]
                        actual=[sprite[i]+sample['scale']*(pixel[i]-sample['pivot'][i]) for i in (0,1)]
                        for got,want in zip(actual,expected):
                            self.assertAlmostEqual(got,want,places=3)

    def test_timber_preserves_continuous_support_and_separate_landing(self):
        env=self.document['environment'];family=env['library']['generated-timber-stair-flight']
        source=json.loads((ROOT/'authoring/environment/source-records/interiors/generated-timber-stair-flight.json').read_text())['record']['physical_mount']
        profile=family['support_profile']
        self.assertEqual(len(family['samples']),124)
        self.assertEqual(len(profile['supports']),12)
        self.assertEqual(profile['contacts_XHZ'],source['contacts_relative_to_lower_floor_XHZ'])
        self.assertTrue(profile['upper_landing_required'])
        self.assertEqual(profile['lane_width_cells'],source['ascent_lane_width_cells'])
        for actual,expected in zip(profile['supports'],source['support_sequence']):
            self.assertEqual(actual['center_XHZ'],expected['support_center_relative_to_lower_floor_XHZ'])
            self.assertEqual(actual['contact_px_by_pose'],expected['authored_support']['contact_px_by_native_pose'])
            for point,original in zip(actual['polygon_XZ'],expected['authored_support']['support_polygon_xy_cells']):
                self.assertEqual(point[0],original[0])
                self.assertAlmostEqual(point[1],original[1]-.5065078681889764,places=12)
        for sample in family['samples']:
            self.assert_contact_and_normals(sample['surface'],sample['physical_source_contact_px'],[0,.995,0])
        self.assertNotIn('generated-timber-stair-flight',env['props'])
        self.assertNotIn('timber',json.dumps(self.document['world']).lower())


if __name__ == '__main__':
    unittest.main()
