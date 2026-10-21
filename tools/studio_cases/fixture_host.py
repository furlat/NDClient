"""Thin recorder setup around the unchanged native host and worker lifecycle.

Only these authored initial fixtures run between ordinary roster composition
and ordinary audience initialization. All captured packets and later commands
still come from the production worker and legal SDK path.
"""
import argparse
import asyncio
from collections import deque
import json
import os
from pathlib import Path
import sys

from devtools.player_server_acceptance import test_host
from dnd.content.items.ground_hardware_builders import materialize_ground_hardware
from dnd.core.events import EventPhase, EventQueue, MechanismInstallEvent
from dnd.player.session import close_session
from dnd.spatial.environmental_conditions import SpikeTrap
from dnd.spatial.gas_traps import GasCloudSpec, GasVent
from dnd.spatial.jaws import JawTrap
from dnd.spatial.mechanisms import AreaGeometry, FiniteTrap
from dnd.spatial.triggers import PressurePlate, Tripwire
from dnd.types.controls import ActivationLink
from dnd.types.world import CardinalDirection
from server import connection, worker


HARDWARE = {
    'spikes': 'environment.trap.spikes',
    'jaw': 'environment.trap.jaw',
    'gas_vent': 'environment.trap.gas_vent',
    'pressure_plate': 'environment.trap.pressure_plate',
    'tripwire': 'environment.trap.tripwire',
    'dart_emitter': 'environment.trap.dart_emitter',
}


def install_initial_mechanisms(session, rows):
    """Install actual native owners/bodies, resolving only earlier real links."""
    installed = {}
    source = session.player_uuids[0]
    for row in rows:
        name, kind = row['id'], row['kind']
        if not name or name in installed or kind not in HARDWARE:
            raise ValueError('Initial mechanism needs a unique local name and supported native kind')
        position = tuple(row['at'])
        common = {'source_entity_uuid': source, 'position': position,
            'affected_positions': {tuple(cell) for cell in row.get('cells', [row['at']])},
            'condition_stealth_dc': row.get('stealth_dc')}
        if kind == 'spikes':
            mechanism = SpikeTrap(**common)
        elif kind == 'jaw':
            mechanism = JawTrap(**common)
        elif kind == 'gas_vent':
            mechanism = GasVent(**common, gas=GasCloudSpec(**row.get('gas', {})))
        elif kind == 'dart_emitter':
            mechanism = FiniteTrap(**common, geometry=AreaGeometry())
        else:
            target = row['activates']
            if target not in installed:
                raise ValueError('Initial mechanism link must name an earlier actual native fixture: '+target)
            link = ActivationLink(target_condition_uuid=installed[target].uuid)
            if kind == 'pressure_plate':
                mechanism = PressurePlate(**common, link=link)
            else:
                mechanism = Tripwire(**common, across=tuple(row['across']), link=link)
        if mechanism.content_ref.content_id != row['content_id'] or HARDWARE[kind] != row['item_id']:
            raise ValueError('Initial fixture content must match its actual native owner and hardware: '+name)
        cause = EventQueue.publish_declaration(MechanismInstallEvent(
            name='Install '+kind.replace('_', ' '), source_entity_uuid=source, use_register=False))
        for phase in (EventPhase.EXECUTION, EventPhase.EFFECT):
            cause = cause.phase_to(phase)
            if cause.canceled:
                raise RuntimeError('Initial native mechanism installation was canceled: '+name)
        materialize_ground_hardware(mechanism, item_id=HARDWARE[kind],
            hit_points=row.get('hit_points'), orientation=CardinalDirection(row.get('orientation', 'east')),
            parent_event=cause)
        cause.phase_to(EventPhase.COMPLETION)
        installed[name] = mechanism


def native_worker(setup):
    original = worker.create_authored_session

    def configured_session(*args, **kwargs):
        session = original(*args, **kwargs)
        try:
            install_initial_mechanisms(session, setup)
        except BaseException:
            close_session(session)
            raise
        return session

    # start() calls this existing constructor before initialize_audiences.
    # Its request loop, serialization, settlement and cleanup stay unchanged.
    worker.create_authored_session = configured_session
    try:
        worker.main()
    finally:
        worker.create_authored_session = original


async def host(args):
    original = connection.launch

    async def fixture_launch():
        process = await asyncio.create_subprocess_exec(sys.executable, '-B', str(Path(__file__).resolve()),
            '--native-worker', '--initial-mechanisms', str(args.initial_mechanisms),
            cwd=Path(worker.__file__).resolve().parents[1], env=dict(os.environ, PYTHONUNBUFFERED='1'),
            stdin=asyncio.subprocess.PIPE, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE)
        diagnostics = deque(maxlen=64)
        return connection.Connection(process, diagnostics,
            asyncio.create_task(connection._drain(process.stderr, diagnostics)))

    connection.launch = fixture_launch
    try:
        await test_host.run(args)
    finally:
        connection.launch = original


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--native-worker', action='store_true')
    parser.add_argument('--initial-mechanisms', type=Path, required=True)
    parser.add_argument('--config', type=Path)
    parser.add_argument('--stop', type=Path)
    parser.add_argument('--result', type=Path)
    parser.add_argument('--host', default='127.0.0.1')
    parser.add_argument('--port', type=int, default=8795)
    args = parser.parse_args()
    if args.native_worker:
        native_worker(json.loads(args.initial_mechanisms.read_text()))
    else:
        if args.config is None or args.stop is None or args.result is None:
            parser.error('Host mode requires --config, --stop and --result')
        args.worker_profile = None
        args.profile_census_after = 200
        asyncio.run(host(args))


if __name__ == '__main__':
    main()
