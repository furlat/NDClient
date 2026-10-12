"""Run the real worker with per-command timing and optional targeted cProfile.

The ordinary native process entry still owns imports, GC policy, rules,
projection, serialization and protocol. cProfile cases are marked explicitly;
their wall latency is diagnostic and not an uninstrumented performance result.
"""
import argparse
import cProfile
import json
from pathlib import Path
import pstats
from time import perf_counter

from dnd.action_timing import reset_action_timing_recorder, set_action_timing_recorder
from server import worker


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--cpu-commands', default='')
    parser.add_argument('--action-phases', action='store_true')
    args = parser.parse_args()
    selected = {int(number) for number in args.cpu_commands.split(',') if number}
    original_dispatch = worker.dispatch
    original_action = worker.execute_player_action
    original_projection = worker.capture_application_operation
    outer = {}

    def measured_action(*arguments, **keywords):
        started = perf_counter()
        try:
            return original_action(*arguments, **keywords)
        finally:
            outer['execute_action_ms'] = (perf_counter()-started)*1000

    def measured_projection(*arguments, **keywords):
        started = perf_counter()
        try:
            return original_projection(*arguments, **keywords)
        finally:
            outer['project_audiences_ms'] = (perf_counter()-started)*1000

    with args.output.open('w') as output:
        def measured_dispatch(runtime, request):
            outer.clear()
            number = request.request.command_number if request.kind == 'command' else None
            phases = {}

            def record(phase, started):
                row = phases.setdefault(phase, {'calls': 0, 'total_ms': 0.0})
                row['calls'] += 1
                row['total_ms'] += (perf_counter()-started)*1000

            profiler = cProfile.Profile() if number in selected else None
            token = set_action_timing_recorder(record if args.action_phases else None)
            started = perf_counter()
            if profiler is not None:
                profiler.enable()
            try:
                result = original_dispatch(runtime, request)
            finally:
                if profiler is not None:
                    profiler.disable()
                elapsed = (perf_counter()-started)*1000
                reset_action_timing_recorder(token)
            row = {'kind': request.kind, 'command_number': number,
                'dispatch_ms': elapsed, 'cpu_profiled': profiler is not None,
                'action_phase_hooks': args.action_phases,
                'outer_phases': dict(outer), 'nested_action_phases': phases,
                'publications': len(result[1])}
            if profiler is not None:
                path = args.output.with_name('command-%d.pstats' % number)
                profiler.dump_stats(str(path))
                functions = [{'file': key[0], 'line': key[1], 'function': key[2],
                    'calls': value[1], 'self_ms': value[2]*1000,
                    'inclusive_ms': value[3]*1000}
                    for key, value in pstats.Stats(profiler).stats.items()]
                row['top_inclusive'] = sorted(functions, key=lambda item:item['inclusive_ms'], reverse=True)[:35]
                row['top_self'] = sorted(functions, key=lambda item:item['self_ms'], reverse=True)[:35]
                row['pstats'] = str(path)
            output.write(json.dumps(row)+'\n')
            output.flush()
            return result

        worker.execute_player_action = measured_action
        worker.capture_application_operation = measured_projection
        worker.dispatch = measured_dispatch
        worker.run_process()


if __name__ == '__main__':
    main()
