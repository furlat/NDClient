"""Snapshot the real backend definition denominator for offline Studio audits.

Run in the engine environment with its root on PYTHONPATH. This boots only the
content registry: no encounter, player, media import, or fabricated event.
"""
import argparse
import json
from pathlib import Path

from dnd.content_system.bootstrap import bootstrap_content_system
from dnd.content_system.runtime import SERVER_CONTENT_SYSTEM_RUNTIME
from dnd.player.content_composition import ui_content_manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path,
        default=Path(__file__).resolve().parents[1]/'generated/studio_content_catalog.json')
    args = parser.parse_args()
    SERVER_CONTENT_SYSTEM_RUNTIME.install(bootstrap_content_system())
    rows = []
    for ref, descriptor in ui_content_manifest().content:
        if ref.definition_kind not in ('spell', 'action', 'reaction', 'condition'):
            continue
        rows.append({'id': ref.content_id, 'kind': ref.definition_kind,
            'label': descriptor.display_name, 'tags': descriptor.tags,
            'definition_ref': ref.model_dump(mode='json'),
            'presentation': descriptor.presentation.model_dump(mode='json')})
    rows.sort(key=lambda row: (row['kind'], row['id']))
    result = {'scope': 'Current backend spell/action/reaction/condition definitions; existing authored class/trait recipes are audited additionally. Availability is not visual qualification.',
        'source': 'dnd.player.content_composition.ui_content_manifest', 'entries': rows}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps({'entries': len(rows), 'output': str(args.output)}))


if __name__ == '__main__':
    main()
