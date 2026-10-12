"""Original Cycles receiving normals: bytes/registration, not inferred geometry."""
import json
from pathlib import Path
import unittest
import zlib
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT.parent / 'NDClientData/.media'

class ReceivingNormals(unittest.TestCase):
    def test_original_pixel_samples_and_unchanged_depth(self):
        manifest = json.loads((ROOT / 'generated/environment_receiving_normals.json').read_text())
        self.assertEqual(len(manifest['provenance']), 28)
        for frame in manifest['provenance']:
            with self.subTest(bank=frame['bank'], pose=frame['pose']):
                record = manifest['normals'][frame['original_normal_path']]
                original = np.asarray(Image.open(DATA / frame['original_normal_path'].removeprefix('/media/')).convert('RGBA'))
                selected = np.asarray(Image.open(ROOT / record['path'].removeprefix('res://')).convert('RGBA'))
                np.testing.assert_array_equal(selected[..., :2], original[..., :2])
                x,y,w,h = frame['region']
                selected = selected[y:y+h,x:x+w]
                raw = np.frombuffer(zlib.decompress(Path(frame['original_cycles_normal']).read_bytes()), dtype='<f4').reshape(h,w,3).astype(float)
                raw[...,1] *= -1
                mask = ((selected[...,0] != 0) | (selected[...,1] != 0)) & (np.linalg.norm(raw,axis=-1)>1e-8)
                expected = raw[mask] / np.linalg.norm(raw[mask],axis=-1)[:,None]
                encoded = selected[mask,2:].astype(float)/127.5-1
                actual = np.column_stack((encoded,1-np.abs(encoded).sum(axis=-1)))
                fold = np.maximum(-actual[:,2],0)
                actual[:,:2] -= np.sign(actual[:,:2])*fold[:,None]
                actual /= np.linalg.norm(actual,axis=-1)[:,None]
                self.assertLess(float(np.max(np.linalg.norm(actual-expected,axis=-1))), .017)
                self.assertEqual(frame['retained_center_ray_pixels'],0)
                self.assertEqual(int(mask.sum()),frame['replaced_pixels'])
        # The known desk center-ray side hit must now use the original integrated
        # source normal, not a made-up flat top, smoothing kernel or copied neighbor.
        path=manifest['normals']['/media/environment/props/interior-writing-desk/intact/geometry/geometry-native.png']['path']
        value=np.asarray(Image.open(ROOT/path.removeprefix('res://')))[114,95,2:]
        self.assertNotEqual(tuple(value),(255,128))
        self.assertNotEqual(tuple(value),(128,128))

if __name__ == '__main__': unittest.main()
