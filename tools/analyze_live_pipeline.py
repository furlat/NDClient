"""Correlate real client command/frame timestamps with owned backend timings."""
import argparse
import json
from pathlib import Path
from statistics import median


def read_json(path):
    return json.loads(path.read_text())


def duration(row):
    return (row['time_us']-row['started_us'])/1000 if row else None


def summarize(directory):
    commands = read_json(directory/'live-command-trace.json')
    trace = read_json(directory/'client-pipeline-trace.json')
    records = trace['records']
    worker = [json.loads(line) for line in (directory/'worker-dispatch.jsonl').read_text().splitlines()]
    exchanges = [json.loads(line) for line in (directory/'server-exchanges.jsonl').read_text().splitlines()]
    worker_by_command = {row['command_number']:row for row in worker if row['kind']=='command'}
    exchange_by_command = {row['command_number']:row for row in exchanges if row['kind']=='command'}
    ready_by_frame = {row['frame_id']:row for row in records if row['stage']=='sse_record_ready'}
    rows = []
    for command in commands:
        number = command['number']
        sequence = command['receipt']['cursor']['sequence']
        start = command['start_us']
        decode = next((row for row in records if row['stage']=='sse_admission' and row['sequence']==sequence), None)
        packet = ready_by_frame.get(decode['frame_id']) if decode else None
        consumer = next((row for row in records if row['stage']=='canonical_consumer' and row['sequence']==sequence), None)
        prepare = next((row for row in records if row['stage']=='presentation_prepare' and row['sequence']==sequence), None)
        events = [row for row in records if start<=row['time_us']<=command['end_us']]
        command_worker = worker_by_command[number]
        exchange = exchange_by_command[number]
        first = command['first_movement_ms']
        packet_ms = (packet['time_us']-start)/1000 if packet else None
        row = {'number':number, 'behavior':command['behavior'], 'stage':command['stage'],
            'input':command['input'], 'from':command['from'], 'to':command['to'],
            'sequence':sequence, 'ready_ms':command['elapsed_ms'],
            'first_movement_ms':first, 'first_animation_ms':command['first_animation_ms'],
            'complete_sse_frame_ms':packet_ms,
            'operation_bytes':decode['bytes'] if decode else None,
            'server_dispatch_ms':command_worker['dispatch_ms'],
            'server_exchange_ms':exchange['exchange_ms'],
            'server_outer_phases':command_worker['outer_phases'],
            'server_cpu_profiled':command_worker['cpu_profiled'],
            'server_nested_hooks':command_worker.get('action_phase_hooks', True),
            'sse_schema_ms':duration(decode), 'canonical_consumer_ms':duration(consumer),
            'presentation_packet_ms':(prepare['compile_started_us']-prepare['packet_started_us'])/1000 if prepare else None,
            'presentation_compile_ms':(prepare['time_us']-prepare['compile_started_us'])/1000 if prepare else None,
            'client_after_complete_sse_ms':first-packet_ms if first is not None and packet_ms is not None else None,
            'frame_ms':command['frame_ms'], 'client_phase_peaks_ms':command['phase_peaks'],
            'sse_framing_cpu_ms':sum(duration(item) for item in events if item['stage']=='sse_framing')}
        request_stages = []
        for enqueue in (item for item in events if item['stage']=='request_enqueued' and item['operation'] in ['preview','submit_command','choices']):
            reply = next((item for item in records if item['stage']=='response_published' and item['request_id']==enqueue['request_id']),None)
            request_stages.append({'operation':enqueue['operation'], 'request_id':enqueue['request_id'],
                'enqueued_ms':(enqueue['time_us']-start)/1000,
                'worker_reply_ms':(reply['time_us']-start)/1000 if reply else None})
        row['requests']=request_stages
        rows.append(row)
    metrics = ['first_movement_ms','server_dispatch_ms','server_exchange_ms','operation_bytes',
        'sse_schema_ms','canonical_consumer_ms','presentation_compile_ms','client_after_complete_sse_ms']
    sections = {}
    for label, lower, upper in [('before_gallery',0,6),('gallery_entry',7,7),('inside_gallery',8,10)]:
        selected = [row for row in rows if row['behavior']=='action.move' and lower<=row['stage']<=upper and not row['server_cpu_profiled']]
        sections[label] = {'moves':len(selected), 'viewport_clicks':sum(row['input']=='viewport_click' for row in selected)}
        for metric in metrics:
            values = [row[metric] for row in selected if row[metric] is not None]
            if values:sections[label][metric]={'median':median(values),'min':min(values),'max':max(values)}
    return {'run':str(directory.resolve()), 'dropped_client_trace_records':trace['dropped'],
        'sections':sections, 'commands':rows,
        'notes':[
            'Actual production player actions. Input records distinguish native viewport clicks from action handlers.',
            'Client timestamps use one Godot monotonic clock. Complete SSE frame is a client availability observation, not a server send timestamp.',
            'Server exchange includes worker/IPC/record staging; dispatch is inside the actual worker. No subtraction of unsynchronized Windows/WSL clocks.',
            'Client post-packet stages may overlap. Nested engine phases overlap and must not be added together.',
            'CPU-profiled commands are excluded from latency aggregates. Nested phase hooks, when enabled, are diagnostic overhead.',
            'First movement is an observed changed actor position at frame_post_draw. Ready includes intended animation and following choices.',
            'The existing user preview remains open. These are process-attributed measurements, not an isolated GPU benchmark.'
        ]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('run',type=Path)
    parser.add_argument('--output',type=Path,required=True)
    args = parser.parse_args()
    result = summarize(args.run)
    args.output.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result['sections'],indent=2))


if __name__=='__main__':
    main()
