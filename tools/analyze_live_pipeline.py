"""Correlate real client command/frame timestamps with owned backend timings."""
import argparse
from collections import Counter
import json
from pathlib import Path, PureWindowsPath
from statistics import median


def read_json(path):
    return json.loads(path.read_text())


def duration(row):
    return (row['time_us']-row['started_us'])/1000 if row else None


def packet_shape(directory, sequence):
    packet = read_json(directory/'journal'/('%016d.json' % sequence))
    lineages = packet['lineages']
    events = [event for lineage in lineages for event in lineage.get('events',[])]
    updates = [update for lineage in lineages for update in lineage.get('world_updates',[])]
    return {'lineages': len(lineages), 'events': len(events),
        'facts': dict(sorted(Counter(event['fact']['kind'] for event in events if event.get('fact') is not None).items())),
        'versions': sum(len(lineage.get('version_rows',[])) for lineage in lineages),
        'bodies': sum(len(lineage.get('bodies',[])) for lineage in lineages),
        'sensory_rows': sum(len(lineage.get('sensory_rows',[])) for lineage in lineages),
        'world_tile_statics': sum(len(update.get('tile_statics',[])) for update in updates),
        'world_tile_columns': sum(len(update.get('tile_columns',[])) for update in updates),
        'world_objects': sum(len(update.get('objects',[])) for update in updates),
        'world_boundary_structures': sum(len(update.get('boundary_structures',[])) for update in updates)}


def opening_frames(frames, prepared_us, visible_us):
    """Disjoint wall-clock intervals with inclusive CPU/context samples attached."""
    result = []
    cursor = prepared_us
    for frame in frames:
        if frame['interval_end_us'] > visible_us:
            break
        end = frame['interval_end_us']
        begin = max(cursor, frame['interval_start_us'])
        if end <= begin:
            continue
        if begin > cursor:
            result.append({'kind':'outside_recorded_interval', 'elapsed_ms':(begin-cursor)/1000})
        view = frame['view']
        result.append({'kind':'process_interval', 'frame':frame['frame'],
            'elapsed_ms':(end-begin)/1000,
            'interval_frame_ms':frame['frame_ms'],
            'world_phase_at_sample':view.get('world_prepare_phase'),
            'waiting_for_world_at_sample':view.get('world_waiting'),
            'preparation_at_sample':view.get('preparation_admission',{}),
            'inclusive_cpu_ms_at_sample':frame['cpu_ms']})
        cursor = end
        if cursor >= visible_us:
            break
    if cursor < visible_us:
        result.append({'kind':'after_last_process_sample', 'elapsed_ms':(visible_us-cursor)/1000})
    return result


def recorded_frames(directory):
    checks = directory/'player-live-checks.json'
    if not checks.exists():
        return []
    name = read_json(checks).get('evidence',{}).get('full_profile')
    if not name:
        return []
    profile = Path(name)
    if not profile.exists() and PureWindowsPath(name).drive and Path('/mnt').is_dir():
        path = PureWindowsPath(name)
        profile = Path('/mnt',path.drive[0].lower(),*path.parts[1:])
    return read_json(profile)['frames'] if profile.exists() else []


def distribution(values):
    values = sorted(values)
    if not values:
        return None
    return {'count':len(values), 'mean':sum(values)/len(values),
        **{name:values[int((len(values)-1)*quantile)]
           for name,quantile in [('p50',.5),('p95',.95),('p99',.99)]}, 'max':values[-1]}


def rendering_summary(samples):
    return {'frame_ms':distribution([frame['frame_ms'] for frame in samples]),
        'player_cpu_ms':distribution([frame['cpu_ms'].get('player_process',0) for frame in samples]),
        'intervals_above_10ms':sum(frame['frame_ms']>10 for frame in samples),
        'intervals_above_16_67ms':sum(frame['frame_ms']>1000/60 for frame in samples),
        'intervals_above_33_33ms':sum(frame['frame_ms']>1000/30 for frame in samples)}


def reveal_summary(command, frames):
    selected = [frame for frame in frames
        if command['start_us']<=frame['interval_end_us']<=command['end_us']]
    waits = {'media_wait':[], 'world_wait':[]}
    phases = command['phases']
    for index,phase in enumerate(phases):
        end = phases[index+1]['ms'] if index+1<len(phases) else command['elapsed_ms']
        for kind in waits:
            if phase['state'][kind]:
                waits[kind].append({'start_ms':phase['ms'], 'end_ms':end,
                    'elapsed_ms':end-phase['ms']})
    publication = max((frame for frame in selected if frame['cpu_ms'].get('world_sync',0)>0),
        key=lambda frame:frame['cpu_ms']['world_sync'], default=None)
    onset = command.get('first_animation_ms')
    result = {'observed_wait_intervals':waits,
        'observed_wait_ms':{kind:sum(item['elapsed_ms'] for item in intervals)
            for kind,intervals in waits.items()},
        'all_command_frames':rendering_summary(selected),
        'post_onset_frames':rendering_summary([frame for frame in selected
            if onset is not None and frame['interval_end_us']>=command['start_us']+onset*1000])}
    markers = command.get('submit_markers',[])
    submitted_us = markers[0]['time_us'] if markers else command['start_us']
    pre_submit = [frame for frame in selected if frame['interval_end_us']<submitted_us]
    result['pre_submit_targeting_frames']=rendering_summary(pre_submit)
    result['slow_pre_submit_frames']=[{'frame':frame['frame'], 'frame_ms':frame['frame_ms'],
        'before_submit_ms':(submitted_us-frame['interval_end_us'])/1000, 'cpu_ms':frame['cpu_ms']}
        for frame in pre_submit if frame['frame_ms']>1000/60]
    if publication:
        result['largest_world_publication']={'frame':publication['frame'],
            'after_click_ms':(publication['interval_end_us']-command['start_us'])/1000,
            'frame_ms':publication['frame_ms'], 'cpu_ms':publication['cpu_ms'],
            'preparation':publication['view'].get('preparation_admission',{}),
            'atlas':publication['view'].get('native_2d_reconcile_phases',{}),
            'worker_ms':publication['view'].get('world_prepare_worker_ms')}
    result['slow_frames']=[{'frame':frame['frame'], 'frame_ms':frame['frame_ms'],
        'after_click_ms':(frame['interval_end_us']-command['start_us'])/1000,
        'phase':frame['view'].get('world_prepare_phase'), 'cpu_ms':frame['cpu_ms']}
        for frame in selected if frame['frame_ms']>1000/60]
    return result


def summarize(directory):
    commands = read_json(directory/'live-command-trace.json')
    trace = read_json(directory/'client-pipeline-trace.json')
    records = trace['records']
    frames = recorded_frames(directory)
    worker = [json.loads(line) for line in (directory/'worker-dispatch.jsonl').read_text().splitlines()]
    exchanges = [json.loads(line) for line in (directory/'server-exchanges.jsonl').read_text().splitlines()]
    worker_by_command = {(row.get('actor_uuid'),row['command_number']):row for row in worker if row['kind']=='command'}
    exchange_by_command = {(row.get('actor_uuid'),row['command_number']):row for row in exchanges if row['kind']=='command'}
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
        opening = next((row for row in records if row['stage']=='presentation_opening' and row['sequence']==sequence), prepare)
        framing = max((row for row in records if packet and row['stage']=='sse_framing'
            and row.get('http_id')==packet.get('http_id') and row.get('records',0)>0
            and row['time_us']<=packet['time_us']),key=lambda row:row['time_us'],default=None)
        events = [row for row in records if start<=row['time_us']<=command['end_us']]
        command_worker = worker_by_command.get((command['actor'],number),worker_by_command.get((None,number)))
        exchange = exchange_by_command.get((command['actor'],number),exchange_by_command.get((None,number)))
        if command_worker is None or exchange is None:
            raise ValueError('No exact actor/command timing for '+str((command['actor'],number)))
        first = command['first_movement_ms']
        packet_ms = (packet['time_us']-start)/1000 if packet else None
        framing_start = packet.get('framing_started_us',framing['started_us'] if framing else packet['time_us']) if packet else None
        framing_ms = (framing_start-start)/1000 if framing_start is not None else None
        first_group = next((phase['ms'] for phase in command['phases'] if phase['state']['group']), None)
        row = {'number':number, 'actor':command['actor'], 'behavior':command['behavior'], 'stage':command['stage'],
            'input':command['input'], 'from':command['from'], 'to':command['to'],
            'sequence':sequence, 'ready_ms':command['elapsed_ms'],
            'playback_complete_ms':command.get('playback_complete_ms'),
            'end_to_ready_ms':command.get('end_to_ready_ms'),
            'post_ready_frame_peak_ms':max((frame['frame_ms'] for frame in command.get('post_ready_frames',[])), default=None),
            'post_ready_hud_peak_ms':max((frame['cpu_ms'].get('hud_process',0) for frame in command.get('post_ready_frames',[])), default=None),
            'input_ready_after_samples':command.get('input_ready_after_samples'),
            'bar_settled_ms':command.get('bar_settled_ms'),
            'post_ready_bar_build_peak_ms':max((frame['cpu_ms'].get('hud_bar_build',0) for frame in command.get('post_ready_frames',[])), default=None),
            'first_movement_ms':first, 'first_animation_ms':command['first_animation_ms'],
            'first_group_ms':first_group,
            'complete_sse_frame_ms':packet_ms,
            'final_sse_framing_start_ms':framing_ms,
            'final_sse_framing_cpu_ms':duration(framing),
            'operation_bytes':decode['bytes'] if decode else None,
            'packet_shape':packet_shape(directory, sequence),
            'server_dispatch_ms':command_worker['dispatch_ms'],
            'server_exchange_ms':exchange['exchange_ms'],
            'server_outer_phases':command_worker['outer_phases'],
            'server_cpu_profiled':command_worker['cpu_profiled'],
            'server_nested_hooks':command_worker.get('action_phase_hooks', True),
            'sse_schema_ms':duration(decode), 'canonical_consumer_ms':duration(consumer),
            'sse_admission_phases_ms':decode.get('phases_ms',{}) if decode else {},
            'canonical_phases':consumer.get('phases',{}) if consumer else {},
            'presentation_packet_ms':(prepare['compile_started_us']-prepare['packet_started_us'])/1000 if prepare else None,
            'presentation_compile_ms':(prepare.get('compile_ended_us',prepare['time_us'])-prepare['compile_started_us'])/1000 if prepare else None,
            'presentation_required_media_ms':prepare.get('required_media_ms',0) if prepare else None,
            'presentation_opening_media_ms':opening.get('required_media_ms',0) if opening else None,
            'presentation_opening_phases_ms':opening.get('phases',{}) if opening else {},
            'opening_preparation_stage':opening['stage'] if opening else None,
            'client_to_prepared_ms':(prepare['time_us']-packet['time_us'])/1000 if prepare and packet else None,
            'client_to_opening_prepared_ms':(opening['time_us']-framing_start)/1000 if opening and framing_start is not None else None,
            'prepared_to_first_movement_ms':first-(prepare['time_us']-start)/1000 if first is not None and prepare else None,
            'client_after_complete_sse_ms':first-packet_ms if first is not None and packet_ms is not None else None,
            'prepared_to_first_animation_ms':command['first_animation_ms']-(opening['time_us']-start)/1000 if command['first_animation_ms'] is not None and opening else None,
            'client_after_record_ready_to_first_animation_ms':command['first_animation_ms']-packet_ms if command['first_animation_ms'] is not None and packet_ms is not None else None,
            'client_packet_to_first_animation_ms':command['first_animation_ms']-framing_ms if command['first_animation_ms'] is not None and framing_ms is not None else None,
            'frame_ms':command['frame_ms'], 'client_phase_peaks_ms':command['phase_peaks'],
            'sse_framing_cpu_ms':sum(duration(item) for item in events if item['stage']=='sse_framing')}
        request_stages = []
        for enqueue in (item for item in events if item['stage']=='request_enqueued' and item['operation'] in ['preview','submit_command','choices']):
            reply = next((item for item in records if item['stage']=='response_published' and item['request_id']==enqueue['request_id']),None)
            request_stages.append({'operation':enqueue['operation'], 'request_id':enqueue['request_id'],
                'enqueued_ms':(enqueue['time_us']-start)/1000,
                'worker_reply_ms':(reply['time_us']-start)/1000 if reply else None})
        row['requests']=request_stages
        if frames:
            row['rendering']=reveal_summary(command,frames)
        if opening and command['first_animation_ms'] is not None and frames:
            row['opening_to_visible_intervals']=opening_frames(
                frames,opening['time_us'],start+command['first_animation_ms']*1000)
        rows.append(row)
    metrics = ['first_movement_ms','server_dispatch_ms','server_exchange_ms','operation_bytes',
        'sse_schema_ms','canonical_consumer_ms','presentation_compile_ms','presentation_required_media_ms','client_to_prepared_ms','client_after_complete_sse_ms','prepared_to_first_animation_ms','client_packet_to_first_animation_ms',
        'end_to_ready_ms','post_ready_frame_peak_ms','post_ready_hud_peak_ms','post_ready_bar_build_peak_ms']
    sections = {}
    for label, lower, upper in [('before_gallery',0,6),('gallery_entry',7,7),('inside_gallery',8,10)]:
        selected = [row for row in rows if row['behavior']=='action.move' and lower<=row['stage']<=upper and not row['server_cpu_profiled']]
        sections[label] = {'moves':len(selected), 'viewport_clicks':sum(row['input']=='viewport_click' for row in selected)}
        for metric in metrics:
            values = [row[metric] for row in selected if row[metric] is not None]
            if values:sections[label][metric]={'median':median(values),'min':min(values),'max':max(values)}
    context = directory/'source-context.json'
    idle = [frame for frame in frames if frame['view'].get('profile_stage')=='spell_profile_idle_same_view']
    return {'run':str(directory.resolve()), 'source_context':read_json(context) if context.exists() else None,
        'dropped_client_trace_records':trace['dropped'],
        'sections':sections, 'commands':rows, 'idle_same_view':rendering_summary(idle),
        'notes':[
            'Actual production player actions. Input records distinguish native viewport clicks from action handlers.',
            'Client timestamps use one Godot monotonic clock. Complete SSE frame is a client availability observation, not a server send timestamp.',
            'Packet-to-first-animation begins before final SSE feed/framing, including its UTF-8 validation. Older traces infer that start from the matching framing record; no server time is inferred from it.',
            'presentation_opening is the first partial source cut; presentation_prepare completes later requirements. Prepared-to-first-animation uses the opening when present. Full continuation may finish after the animation begins.',
            'Server exchange includes worker/IPC/record staging; dispatch is inside the actual worker. No subtraction of unsynchronized Windows/WSL clocks.',
            'Client post-packet stages may overlap. Nested engine phases overlap and must not be added together.',
            'opening_to_visible_intervals partitions elapsed wall time. CPU/context values are inclusive samples at each process interval end, not exclusive causes of its clipped duration. Time after the last process sample is kept separate from later samples.',
            'CPU-profiled commands are excluded from latency aggregates. Nested phase hooks, when enabled, are diagnostic overhead.',
            'First movement is an observed changed actor position at frame_post_draw. Ready includes intended animation and following choices.',
            'Post-ready samples precede canonical-state test comparisons. input_ready_after_samples distinguishes first readiness from sustained input readiness; older runs lack this field.',
            'Post-packet first-movement time may include required reactions before entry. Client-to-prepared covers admission, reduction, compilation and required media metadata, before timeline playback.',
            'These are process-attributed measurements. The trace alone does not establish GPU isolation; record whether other previews or native tests were running.',
            'Observed wait intervals are sampled phase transitions; they describe wall-clock holds, not CPU durations. The largest_world_publication is selected by world_sync CPU within each command, not by maximum whole-frame interval. Slow-frame lists retain every command interval above 60-Hz budget; receipt-validation and boot frames are outside command cohorts. Pre-submit targeting is reported separately from the first native submit marker; the command timer starts before selection/hover/Confirm input.'
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
