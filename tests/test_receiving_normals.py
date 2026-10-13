"""Selected delivery bytes, independent of the production receiving lookup."""
from collections import Counter
import json
from pathlib import Path
import unittest
import numpy as np
from PIL import Image
from tools.prepare_receiving_normals import DEFAULT_DELIVERY, DEFAULT_MEDIA, local_path

ROOT = Path(__file__).resolve().parents[1]


class ReceivingNormals(unittest.TestCase):
    def test_selected_packets_preserve_depth_and_unsupported_pixels(self):
        quality = json.loads((DEFAULT_DELIVERY / 'quality.json').read_text())
        validation = json.loads((DEFAULT_DELIVERY / 'VALIDATION.json').read_text())
        installed = json.loads((ROOT / 'generated/environment_receiving_normals.json').read_text())['normals']
        self.assertEqual(len(installed), 1142)
        expected = {'/media/' + local_path(path).relative_to(DEFAULT_MEDIA).as_posix(): row
                    for path, row in quality['normals'].items()}
        self.assertEqual(set(installed), set(expected))
        changed_pixels = 0
        labels = Counter()
        for index, (identity, source) in enumerate(expected.items()):
            with self.subTest(packet=identity):
                chosen = installed[identity]
                for field in ['path', 'label', 'qualification']:
                    self.assertEqual(chosen[field], source[field])
                with Image.open(DEFAULT_MEDIA / identity.removeprefix('/media/')) as image:
                    self.assertEqual(image.mode, 'RGBA')
                    original = np.asarray(image).copy()
                with Image.open(local_path(chosen['path'])) as image:
                    self.assertEqual(image.mode, 'RGBA')
                    selected = np.asarray(image).copy()
                self.assertEqual(selected.shape, original.shape)
                np.testing.assert_array_equal(selected[..., :2], original[..., :2])
                unsupported = (original[..., 0] == 0) & (original[..., 1] == 0)
                np.testing.assert_array_equal(selected[unsupported], original[unsupported])
                changed = np.any(selected[..., 2:] != original[..., 2:], axis=-1)
                count = int(np.count_nonzero(changed))
                self.assertGreater(count, 0, 'Identity copies must not masquerade as selected improvements')
                changed_pixels += count
                labels[chosen['label']] += 1
            if (index + 1) % 200 == 0:
                print(f'Validated {index + 1}/{len(expected)} selected packets', flush=True)
        self.assertEqual(changed_pixels, validation['packet_counts']['changed_normal_pixels'])
        # Explicitly retained registrations must not acquire a replacement from
        # a similar bank, another frame, or a rejected inferred candidate.
        retained_frames = 0
        for frame in validation['frame_resolutions']:
            if not frame['status'].startswith('retained_original'):
                continue
            identity = '/media/' + local_path(frame['original']).relative_to(DEFAULT_MEDIA).as_posix()
            self.assertNotIn(identity, installed)
            self.assertEqual(frame['selected'], frame['original'])
            retained_frames += 1
        report = {'selected_packets': len(expected), 'changed_normal_pixels': changed_pixels,
                  'retained_frame_records': retained_frames, 'packet_labels': dict(labels),
                  'failures': [], 'depth_bytes_preserved': True, 'unsupported_rgba_preserved': True,
                  'scope': 'All selected original/replacement PNG bytes and exact manifest selection. Delivery validation owns source-pass/inference qualification and unadmitted interior/skirts proofs; native tests separately check registration and rendered response.'}
        (ROOT / 'generated/environment_normal_pixel_checks.json').write_text(json.dumps(report, indent=2) + '\n')


if __name__ == '__main__':
    unittest.main()
