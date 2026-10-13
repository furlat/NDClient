"""Install the selected environment receiving-normal lookup; never rewrite artwork.

The delivery's quality.json is the selection authority. The generated lookup
uses existing /media/ identities and direct private Windows packet paths.
"""
import argparse
from collections import Counter
import json
import os
from pathlib import Path
import struct

PROJECT = Path(__file__).resolve().parents[1]
DEFAULT_DELIVERY = PROJECT.parent.parent / 'assets/fantasy-unified-catalog/environment-normal-quality-2026-10-12'
DEFAULT_MEDIA = PROJECT.parent / 'NDClientData/.media'


def local_path(value: str) -> Path:
    value = value.replace('\\', '/')
    if os.name != 'nt' and len(value) > 2 and value[1:3] == ':/':
        return Path('/mnt') / value[0].lower() / value[3:]
    return Path(value)


def require(condition, message):
    if not condition:
        raise ValueError(message)


def png_dimensions(path: Path) -> tuple[int, int]:
    with path.open('rb') as stream:
        header = stream.read(26)
    require(header[:8] == b'\x89PNG\r\n\x1a\n' and header[12:16] == b'IHDR'
            and header[24:26] == bytes([8, 6]), f'Expected numeric RGBA8 PNG: {path}')
    return struct.unpack('>II', header[16:24])


def intake(delivery: Path, media: Path, project: Path = PROJECT) -> dict:
    quality = json.loads((delivery / 'quality.json').read_text())
    validation = json.loads((delivery / quality['validation']).read_text())
    require(quality['version'] == 1 and quality['status'] == 'verified_best_source_selection',
            'Delivery is not a verified selection')
    require(validation['passed'] and validation['complete'] and not validation['failures']
            and not validation['missing_asset_dispositions'], 'Delivery validation is incomplete')
    require(len(quality['assets']) == validation['catalogue_assets'] == validation['explicit_asset_dispositions'],
            'Asset disposition coverage differs from validation')
    require(len(quality['normals']) == validation['packet_counts']['selected_packets'],
            'Packet selection differs from validation')
    media = media.resolve()
    selected, destinations, disk_bytes, rgba_bytes = {}, set(), 0, 0
    for original, record in quality['normals'].items():
        source = local_path(original).resolve()
        identity = '/media/' + source.relative_to(media).as_posix()
        destination = local_path(record['path']).resolve()
        require(destination.is_relative_to(delivery.resolve()), f'Selected packet outside delivery: {destination}')
        require(identity not in selected and destination not in destinations and source != destination,
                f'Duplicate or identity replacement: {identity}')
        dimensions = png_dimensions(source)
        require(png_dimensions(destination) == dimensions, f'Changed packet dimensions: {identity}')
        require(record['qualification'] and record['label'], f'Missing receiving qualification: {identity}')
        selected[identity] = {key: record[key] for key in ['path', 'label', 'quality', 'qualification'] if key in record}
        destinations.add(destination)
        disk_bytes += destination.stat().st_size
        rgba_bytes += dimensions[0] * dimensions[1] * 4
    result = {'version': 1, 'selection': str(delivery / 'quality.json'), 'normals': selected}
    # Large per-frame source proofs stay with the delivery, not the runtime index.
    report = {'selection': str(delivery / 'quality.json'), 'selected_packets': len(selected),
              'asset_dispositions': len(quality['assets']),
              'disposition_counts': dict(sorted(Counter(row['status'] for row in quality['assets'].values()).items())),
              'packet_labels': dict(sorted(Counter(row['label'] for row in selected.values()).items())),
              'selected_disk_bytes': disk_bytes, 'selected_rgba8_bytes': rgba_bytes,
              'footprint_note': 'Whole selected library totals, not active residency. Existing encounter demand loads only requested sources within its cache policy; original depth packets remain required.',
              'source_art_writes': 0, 'art_copies': 0, 'dimensions_preserved': True,
              'pixel_validation': 'Intake checks every selected PNG header and dimensions. Full delivery VALIDATION.json remains source qualification; tests/test_receiving_normals.py independently checks selected packet depth/unsupported bytes.'}
    (project / 'generated/environment_receiving_normals.json').write_text(json.dumps(result, separators=(',', ':')) + '\n')
    (project / 'generated/environment_normal_intake.json').write_text(json.dumps(report, indent=2) + '\n')
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--delivery', type=Path, default=DEFAULT_DELIVERY)
    parser.add_argument('--media', type=Path, default=DEFAULT_MEDIA)
    parser.add_argument('--project', type=Path, default=PROJECT)
    args = parser.parse_args()
    print(json.dumps(intake(args.delivery, args.media, args.project), indent=2))
