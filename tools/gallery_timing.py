"""Diagnostic owner for the actual gallery route; native gameplay stays unchanged.

The existing acceptance host launches this worker instead of server.worker.
Existing action timing hooks and call-boundary timers collect inclusive elapsed
wall time. No timing sample is written while a command is being dispatched.
"""
import argparse
import asyncio
from collections import deque
from functools import wraps
import json
from pathlib import Path
import sys
from time import perf_counter
from unittest.mock import patch

from dnd.action_timing import reset_action_timing_recorder, set_action_timing_recorder
from devtools.player_server_acceptance import test_host
from server import connection, worker


def run_worker(output):
    rows = []
    phases = {}
    original_start, original_dispatch = worker.start, worker.dispatch

    def record(phase, started):
        elapsed = (perf_counter() - started) * 1000
        item = phases.setdefault(phase, {'count': 0, 'total_ms': 0.0, 'max_ms': 0.0})
        item['count'] += 1
        item['total_ms'] += elapsed
        item['max_ms'] = max(item['max_ms'], elapsed)

    def measure(request, callback):
        nonlocal phases
        phases = {}
        token = set_action_timing_recorder(record)
        started = perf_counter()
        try:
            return callback()
        finally:
            elapsed = (perf_counter() - started) * 1000
            reset_action_timing_recorder(token)
            rows.append({'kind': request.kind, 'command_number': request.request.command_number
                if request.kind == 'command' else None, 'dispatch_ms': elapsed, 'phases': phases})

    def measured_start(request):
        return measure(request, lambda: original_start(request))

    def measured_dispatch(runtime, request):
        return measure(request, lambda: original_dispatch(runtime, request))

    def timed(function, name):
        @wraps(function)
        def wrapped(*args, **kwargs):
            started = perf_counter()
            try:
                return function(*args, **kwargs)
            finally:
                record(name, started)
        return wrapped

    try:
        with patch.object(worker, 'start', measured_start), \
             patch.object(worker, 'dispatch', measured_dispatch), \
             patch.object(worker, 'execute_player_action', timed(worker.execute_player_action, 'dispatch.execute_player_action_ms')), \
             patch.object(worker, 'capture_application_operation', timed(worker.capture_application_operation, 'dispatch.capture_application_operation_ms')), \
             patch.object(worker, 'advance_controller', timed(worker.advance_controller, 'dispatch.advance_controller_ms')), \
             patch.object(worker, 'discover_player_actions', timed(worker.discover_player_actions, 'dispatch.discover_player_actions_ms')):
            worker.run_process()
    finally:
        output.write_text(json.dumps({'schema_version': 1,
            'scope': 'Real native worker dispatch. Instrumented inclusive wall times; nested phases overlap and must not be added. Excludes HTTP, polling, queue wait, packet write/encode and client rendering. Phase recorder and call wrappers add measurement overhead.',
            'rows': rows}, indent=2))


async def run_host(args):
    async def launch():
        process = await asyncio.create_subprocess_exec(sys.executable, str(Path(__file__).resolve()),
            '--worker', '--output', str(args.result.with_name('action-timings.json')),
            stdin=asyncio.subprocess.PIPE, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE)
        diagnostics = deque(maxlen=64)
        return connection.Connection(process, diagnostics,
            asyncio.create_task(connection._drain(process.stderr, diagnostics)))

    with patch.object(connection, 'launch', launch):
        await test_host.run(args)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--worker', action='store_true')
    parser.add_argument('--output', type=Path)
    parser.add_argument('--config', type=Path)
    parser.add_argument('--stop', type=Path)
    parser.add_argument('--result', type=Path)
    parser.add_argument('--host', default='127.0.0.1')
    parser.add_argument('--port', type=int, default=8795)
    parser.set_defaults(worker_profile=None, profile_census_after=200)
    args = parser.parse_args()
    if args.worker:
        if args.output is None: parser.error('--worker requires --output')
        run_worker(args.output)
    else:
        if args.config is None or args.stop is None or args.result is None:
            parser.error('host requires --config, --stop and --result')
        asyncio.run(run_host(args))


if __name__ == '__main__':
    main()
