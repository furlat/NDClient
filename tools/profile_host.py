"""Optional measurement wrapper for the unchanged production acceptance host.

Only durations and request identity numbers are recorded. No credentials, HTTP
bodies or gameplay payloads are written to these timing files.
"""
import argparse
import asyncio
from collections import deque
import json
from pathlib import Path
import sys
from time import perf_counter_ns
from unittest.mock import patch

from devtools.player_server_acceptance import test_host
from server import connection


async def run(args):
    directory = args.result.parent
    original_exchange = connection.exchange
    with (directory / 'server-exchanges.jsonl').open('w') as output:
        async def measured_launch():
            process = await asyncio.create_subprocess_exec(sys.executable,
                str(Path(__file__).with_name('profile_worker.py')),
                '--output', str(directory / 'worker-dispatch.jsonl'),
                '--cpu-commands', args.cpu_commands,
                *(['--action-phases'] if args.action_phases else []),
                stdin=asyncio.subprocess.PIPE, stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE)
            diagnostics = deque(maxlen=64)
            return connection.Connection(process, diagnostics,
                asyncio.create_task(connection._drain(process.stderr, diagnostics)))

        async def measured_exchange(process, request, recording):
            started = perf_counter_ns()
            result = await original_exchange(process, request, recording)
            row = {'kind': request.kind,
                'exchange_ms': (perf_counter_ns()-started)/1e6,
                'worker_reported_ms': result[0].elapsed_ms}
            if request.kind == 'command':
                row['command_number'] = request.request.command_number
            output.write(json.dumps(row)+'\n')
            output.flush()
            return result

        with patch.object(connection, 'launch', measured_launch), \
                patch.object(connection, 'exchange', measured_exchange):
            await test_host.run(args)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', type=Path, required=True)
    parser.add_argument('--stop', type=Path, required=True)
    parser.add_argument('--result', type=Path, required=True)
    parser.add_argument('--host', default='0.0.0.0')
    parser.add_argument('--port', type=int, required=True)
    parser.add_argument('--cpu-commands', default='')
    parser.add_argument('--action-phases', action='store_true')
    args = parser.parse_args()
    # Existing optional GC census lane is deliberately not enabled here.
    args.worker_profile = None
    args.profile_census_after = 0
    asyncio.run(run(args))


if __name__ == '__main__':
    main()
