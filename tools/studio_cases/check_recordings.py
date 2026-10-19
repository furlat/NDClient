"""Run the existing headless recording sweep and qualify its complete Godot log.

Assertion results alone cannot detect a GDScript function that aborted while
its caller continued. The existing per-journal markers locate those failures;
warnings remain explicit evidence, never a claim of native visual readiness.
"""
import argparse
import json
from pathlib import Path
import re
import subprocess
import sys

PROJECT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(PROJECT / 'tools'))
from run_tests import GODOT, godot_processes, stop_processes, windows_path

SCRIPT = 'res://tests/schema16_recording_safety_checks.gd'
REPORT = PROJECT / '.runtime/schema16-recording-safety.json'
START = re.compile(r'^SCHEMA16_RECORDING_START (\S+) / (\S+) ')


def qualify(report, log, native_exit):
    current = None
    errors = []
    warnings = []
    for number, line in enumerate(log.splitlines(), 1):
        match = START.match(line)
        if match:
            current = match.groups()
        elif line.startswith('SCHEMA16_RECORDING_SAFETY '):
            current = None
        if any(token in line for token in ('SCRIPT ERROR:', 'ERROR:', 'Parse Error:', 'Failed loading resource')):
            errors.append({'line': number, 'message': line,
                'spell': current[0] if current else None, 'faction': current[1] if current else None})
        elif 'WARNING:' in line:
            warnings.append({'line': number, 'message': line})
    for spell in report.get('spells', []):
        own = [error for error in errors if error['spell'] == spell['id']]
        spell['native_errors'] = own
        for faction in spell.get('factions', []):
            local = [error for error in own if error['faction'] == faction['faction']]
            faction['native_errors'] = local
            if local:
                faction['assertion_status'] = faction['status']
                faction['status'] = 'failed'
                faction['failures'].append(f'Godot emitted {len(local)} script/resource error lines')
        if own:
            spell['assertion_status'] = spell['status']
            spell['status'] = 'failed'
            spell['failures'].append(f'Godot emitted {len(own)} script/resource error lines')
    report['assertion_failures'] = report.get('failures', []).copy()
    report['passed'] = [row['id'] for row in report.get('spells', []) if row['status'] == 'passed']
    report['tested_failures'] = [row['id'] for row in report.get('spells', []) if row['status'] == 'failed']
    report['log_validation'] = {'native_exit': native_exit, 'error_lines': len(errors),
        'script_errors': sum('SCRIPT ERROR:' in error['message'] for error in errors),
        'warnings': warnings, 'errors': errors}
    report['qualified'] = bool(report.get('complete') and not report.get('failures') and not errors and native_exit == 0)
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--godot', type=Path, default=GODOT)
    parser.add_argument('--timeout', type=int, default=300)
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    log_path = args.out / 'godot.log'
    REPORT.unlink(missing_ok=True)
    with log_path.open('w') as log:
        process = subprocess.Popen([str(args.godot), '--headless', '--path', windows_path(PROJECT),
            '--script', SCRIPT], cwd=PROJECT, stdout=log, stderr=subprocess.STDOUT)
        try:
            native_exit = process.wait(timeout=args.timeout)
        except subprocess.TimeoutExpired:
            owned = [row for row in godot_processes(windows_path(PROJECT)) if SCRIPT in row['command']]
            stop_processes(owned)
            process.kill()
            process.wait()
            native_exit = 124
    report = json.loads(REPORT.read_text()) if REPORT.exists() else {'complete': False, 'failures': ['Recording sweep produced no report'], 'spells': []}
    report = qualify(report, log_path.read_text(errors='replace'), native_exit)
    report['log_validation']['log'] = str(log_path.resolve())
    output = json.dumps(report, indent=1) + '\n'
    REPORT.write_text(output)
    (args.out / 'report.json').write_text(output)
    print(json.dumps({'inventory': report.get('inventory'), 'passed': len(report['passed']),
        'baseline_unavailable': len(report.get('unavailable_baseline', [])), 'tested_failures': len(report['tested_failures']),
        'script_errors': report['log_validation']['script_errors'], 'error_lines': report['log_validation']['error_lines'],
        'warning_lines': len(report['log_validation']['warnings']), 'qualified': report['qualified'], 'report': str(args.out / 'report.json')}))
    return 0 if report['qualified'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
