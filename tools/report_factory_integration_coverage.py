"""Offline report join. It is never imported by the player or Studio."""
import json
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
def read(relative):
    return json.loads((ROOT / relative).read_text())

catalog = read('.runtime/factory-catalog-join-input.json')
factory = read('assets/vfx/index.json')
inventory = read('generated/factory_input_inventory_2026-10-19.json')
ui = read('generated/reports/ui-art-coverage.json')
safety_source = ('.runtime/schema16-recording-safety-post-construction/report.json'
                 if (ROOT / '.runtime/schema16-recording-safety-post-construction/report.json').exists()
                 else '.runtime/schema16-recording-safety-qualified/report.json'
                 if (ROOT / '.runtime/schema16-recording-safety-qualified/report.json').exists()
                 else '.runtime/schema16-recording-safety.json')
safety = read(safety_source)
handover = read('.runtime/condition-handover-inventory.json')
clips = {row['clip_id']: row for row in factory['clips']}
selections = {str(row.get('spell_id', row['key'])): row for row in factory['selections']}
families = defaultdict(list)
for row in factory['selections']:
    for owner in row.get('condition', {}).get('owner_ids', []):
        families[owner].append(row)

# This status means a producer exists, not that every distinct consumer packet
# or visual output has been qualified. State/history/geometry remain separate.
bridge = {
    'root_path': 'existing_occurrence_placement',
    'owner_state': 'ordered_condition_owner_clock',
    'binding_owners': 'legacy_empty_membership_only',
    'entity_geometry': 'actual_authored_actor_exact_slot_surface_partial_unqualified',
    'recipient_geometry': 'actual_authored_actor_exact_slot_surface_partial_unqualified',
    'source_geometry': 'actual_source_exact_slot_surface_partial_unqualified',
    'targets': 'authored_endpoint_arity_roles_sockets_partial_unqualified',
    'live_endpoints': 'authored_endpoint_arity_roles_sockets_partial_unqualified',
    'delivery_timing': 'authored_launch_and_flight_two_argument_adapter_partial_unqualified',
    'actor_layers': 'visible_private_body_material_revision_bridge_partial_unqualified',
    'treatment_state': 'disclosed_condition_state_bridge_partial_unqualified',
    'owner_projection': 'actual_positive_self_heal_or_observed_bounded_condition_only',
    'activation_projection': 'actual_action_and_observed_bounded_condition_only',
    'admitted_cells': 'prepared_world_rectangles_or_native_local_pairs_nullable_contract_partial_unqualified',
    'weapon_binding': 'exact_disclosed_item_holder_slot_and_optical_surface_partial_owner_and_legacy_gaps',
    'appearance_provider': 'prepared_modular_outfit_exact_condition_uuid_sampled_frame_lease_fly_qualified',
}
provider_notes = {
    'appearance_provider': 'Typed appearance definitions prepare actual outfit sheets before admission. Per-condition Factory leases control only opacity; layers follow the body clip/frame/facing. Actual Fly apply/move/view/gear/remove, independent factions, seeking and looping are qualified in agent_docs/APPEARANCE_PROVIDER_COHORT_2026-10-19.md. Unsupported fixed rigs and created-item art remain gaps; there is no new animation controller.',
    'geometry': 'Authored actor/slot lists select actual admitted optical sources. Body, head and weapon slots are not interchangeable. Source pose work is shared independently of translation; receiver-relative geometry keys avoid repeated co-moving uploads. Distinct outputs still need native qualification.',
    'endpoints': 'Authored live_endpoints preserve arity, order, actor roles, sockets and requested surface slots. Extra actors require actual native_actor_uuids. Literal review positions, review trajectories and absent roles remain explicit gaps; no fixture coordinates are copied.',
    'delivery_timing': 'Uses the selected cue launch and contact-minus-launch in the actual two-argument setter. This supplies timing, not evidence that its native visual release/socket is correct.',
    'body_material': 'Current visible body layers and private material revisions are supplied. Focused setter/restoration tests cover private ownership; this does not qualify all treatments, stacking, outfits, animation revisions or final pixels.',
    'admitted_cells': 'The selected approach manifest condition_prepared flag chooses world rectangles/Array-to-bool versus native local pairs/Variant-to-void. Native optional null is skipped, prepared unknown clears then reports unavailable, known empty is distinct, and explicit nonempty false is rejection. Native pairs use the actual first endpoint plane or endpoint-free root inverse; non-unit/non-quarter-turn grid frames remain unavailable. Footprint and frame changes invalidate one cached conversion.',
    'pose_provider': 'A non-capture operation needs no pose packet. Actual requested pose capture, actor history and departure/admission evidence remain unbound; current geometry is not substituted for history.',
    'weapon_binding': 'Exact authored weapon/offhand slots cross-check displayed layer item UUID and canonical visual_loadout. Wrong owner, missing item, ambiguity and actual missing item-owner and legacy admission inputs remain explicit. Active Antimagic suppression is retired in schema16; its absent token is not a provider gap. Magic Weapon/Sacred Weapon item memberships are not published by the frozen producer. See agent_docs/WEAPON_PROVIDER_COHORT_2026-10-19.md; setter-contract checks do not qualify production pixels.',
    'construction': 'Explicit application_result cues join native cast lineage/application UUID, matching saving throw and applied damage before public Source.make. Private phase input data replaces only declared component operands; shared Resources and native facts stay immutable. Static selection cannot construct a successful fixture. Circle has one cast source plus four real recipient instances; this does not close other construction cohorts.',
}
public_gaps = inventory['unavailable_public_selectors']
contracts = {}
def contract(clip_id):
    if clip_id in contracts:
        return clip_id
    row = clips.get(clip_id, {})
    if not row:
        contracts[clip_id] = {'clip': clip_id, 'status': 'exact_clip_missing'}
        return clip_id
    contracts[clip_id] = {'clip': clip_id, 'inputs': row.get('inputs', []),
            'input_setters': row.get('input_setters', {}),
            'approaches': [{'id': a.get('id'), 'kind': a['kind'],
                            'seekable': a.get('seekable'), 'path': a['path']}
                           for a in row.get('approaches', [])],
            'providers': {name: bridge.get(name, 'missing_provider') for name in row.get('inputs', [])},
            'visual_qualification': 'not_inferred_from_binding_or_setter_presence'}
    return clip_id

def resolve(cue, subject):
    clip_id = cue.get('clip', '')
    if clip_id in clips:
        return clip_id
    selected = selections.get(subject.removeprefix('spell.'), {})
    renamed = [c for c in selected.get('clips', []) if c.startswith(clip_id + '/')]
    role = [c['clip'] for c in selected.get('staging', {}).get('cues', [])
            if c.get('role') == cue.get('role') and c.get('clip') in clips]
    return renamed[0] if len(renamed) == 1 else role[0] if len(role) == 1 else clip_id

typed_by_id = defaultdict(list)
selected_clip_ids = set()
for section, rows in catalog['typed'].items():
    for subject, original in rows.items():
        row = dict(original, source_section=section)
        if section != 'conditions':
            cues = []
            for cue in row.get('effects', []):
                i = int(cue['source_index'])
                dispatch = 'event_cue'
                if section == 'spells':
                    if not row['native_staging']:
                        dispatch = 'authored_disabled'
                    elif i in row['excluded_cues']:
                        dispatch = 'excluded_probe'
                    elif i in row['owner_cues'] and (row['owner_kind'] == 'spatial_effect' or any(
                            catalog['typed']['conditions'].get(owner, {}).get('play_package_lifecycle', True)
                            and any(f.get('condition', {}).get('body_channel_included', False) for f in families.get(owner, []))
                            for owner in row['owner_ids'])):
                        dispatch = 'owner_handover'
                    elif row['explicit_event_cues'] and i not in row['event_cues']:
                        dispatch = 'not_selected_for_event'
                if dispatch == 'event_cue' and cue.get('unbound_constructor_inputs'):
                    dispatch = 'unbound_constructor_inputs'
                resolved = resolve(cue, subject)
                cues.append({'constructor_input_gaps': cue.get('unbound_constructor_inputs', []),
                             'source_index': i, 'scope': cue.get('scope', 'default'), 'role': cue.get('role'),
                             'constructor_input': cue.get('constructor_input'),
                             'at': cue.get('at'), 'selection': cue.get('selection', ''),
                             'dispatch': dispatch, 'contract': contract(resolved)})
                if dispatch in ['event_cue', 'owner_handover']:
                    selected_clip_ids.add(resolved)
            row['default_cues'] = cues
            for variant in row.get('variants', []):
                variant['cue_contracts'] = [contract(resolve(cue, variant['id'])) for cue in variant.get('effects', [])]
        if section == 'conditions':
            lifecycle = []
            for selection in families.get(subject, []):
                condition = selection['condition']
                active = row['play_package_lifecycle']
                lifecycle.append({'selection': selection['key'], 'when': condition.get('when', {}),
                                  'dispatch': 'server_owner_candidate_requires_actual_state_selector' if active else 'authored_suppressed',
                                  'registration': condition.get('registration', {}),
                                  'seek': condition.get('seek', {}),
                                  'body_channel_included': condition.get('body_channel_included', False),
                                  'phases': {name: contract(clip) for name, clip in condition.get('phases', {}).items()}})
                if active:
                    selected_clip_ids.update(condition.get('phases', {}).values())
            row['condition_lifecycles'] = lifecycle
        typed_by_id[subject].append(row)

current_families = []
reviewed_families = {row['family']: row for row in inventory['condition_families']}
programs = []
referenced_clips = set(contracts)
for selection in factory['selections']:
    condition = selection.get('condition', {})
    if condition:
        row = dict(reviewed_families.get(selection['key'], {'family': selection['key'], 'group': 'not_reviewed'}))
        inputs = sorted({name for clip in condition.get('phases', {}).values()
                         for name in clips.get(clip, {}).get('inputs', [])})
        row.update(owners=condition.get('owner_ids', []), owner_kind=condition.get('owner_kind'),
                   when=condition.get('when', {}), registration=condition.get('registration', {}),
                   seek=condition.get('seek', {}), phase_clips=condition.get('phases', {}), inputs=inputs)
        row.pop('extra_input_provider_gaps', None)
        row['current_missing_provider_channels'] = [name for name in inputs if name not in bridge]
        row['current_bridge_status'] = {name: bridge.get(name, 'missing_provider') for name in inputs}
        current_families.append(row)
    else:
        programs.append({'key': selection['key'], 'runtime_key': selection.get('runtime_key', ''),
                         'definition_ref': selection.get('definition_ref', {}),
                         'clips': selection.get('clips', []),
                         'has_current_typed_clip_reference': any(clip in referenced_clips for clip in selection.get('clips', [])),
                         'gameplay_requirement': 'not_implied_by_factory_program_presence'})
    for clip in selection.get('clips', []):
        contract(clip)

def check_evidence(relative):
    path = ROOT / relative
    if not path.exists():
        return {'status': 'not_available', 'log': relative, 'qualifies': 'no native pixels'}
    text = path.read_text()
    result = {}
    for line in text.splitlines():
        try:
            candidate = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(candidate, dict) and ('checks' in candidate or 'passed' in candidate):
            result = candidate
    errors = [line for line in text.splitlines() if 'SCRIPT ERROR:' in line or line.startswith('ERROR:')]
    warnings = [line for line in text.splitlines() if line.startswith('WARNING:')]
    failures = result.get('failures', [])
    return {'status': 'passed' if result and not failures and not errors else 'failed',
            'passed': result.get('passed', result.get('checks', 0)) - len(failures),
            'failures': failures, 'engine_errors': errors, 'engine_warnings': warnings,
            'log': relative, 'qualifies': 'no native pixels'}

def native_evidence():
    current = '.runtime/production-bindings-native8'
    post = '.runtime/schema16-studio-replay-post-construction'
    result_path = current + '.json' if (ROOT / (current + '.json')).exists() else post + '.json' if (ROOT / (post + '.json')).exists() else '.runtime/schema16-studio-replay.json'
    log_path = current + '.log' if result_path == current + '.json' else post + '.log' if result_path == post + '.json' else '.runtime/schema16-studio-replay-qualified.log'
    if not (ROOT / result_path).exists() or not (ROOT / log_path).exists():
        return {'status': 'not_available', 'report': result_path, 'log': log_path}
    result = read(result_path)
    lines = (ROOT / log_path).read_text().splitlines()
    errors = [line for line in lines if 'SCRIPT ERROR:' in line or line.startswith('ERROR:')]
    warnings = [line for line in lines if line.startswith('WARNING:')]
    return {'status': 'failed' if result.get('failures') or errors else 'passed_with_warnings' if warnings else 'passed',
            'checks': result.get('checks', 0), 'failures': result.get('failures', []),
            'factory_version': result.get('factory_version', 'conditions-candidate-7fab471588209a41'),
            'case_ids': [row['case'] for row in result.get('evidence', []) if 'case' in row],
            'engine_errors': errors, 'engine_warnings': warnings, 'report': result_path, 'log': log_path,
            'qualifies': 'Actual native Studio replay cohort, not all-spell visual approval or a performance benchmark'}

def live_evidence():
    combined = '.runtime/schema16-native-gui-qualified/report.json'
    relative = combined if (ROOT / combined).exists() else '.runtime/schema16-live-all-spells-final-r3/results.json'
    if not (ROOT / relative).exists():return {'status': 'not_available', 'report': relative}
    result = read(relative)
    rows = []
    for row in result.get('cases', []):
        trace = row.get('render_trace', {})
        components = {component['id']: component for event in trace.get('events', [])
                      for component in event.get('components', [])}
        native = [{key: component[key] for key in ['id', 'kind', 'status', 'reason', 'sample_count',
                   'first_sample_ms', 'last_sample_ms', 'start_ms', 'end_ms', 'source', 'source_id'] if key in component}
                  for component in components.values() if component.get('kind') in ['native_effect', 'native_material']]
        rows.append({'case': row.get('case', row.get('id')), 'command_checks_ok': row.get('ok', False),
                     'checks': row.get('checks', 0), 'failures': row.get('failures', []),
                     'failure': row.get('failure'), 'presentation_errors': row.get('presentation_errors'),
                     'script_resource_errors': row.get('script_resource_errors', row.get('native_errors')),
                     'script_resource_error_scope': 'per_case' if 'script_resource_errors' in row or 'native_errors' in row else 'not_attributed_per_case_in_artifact',
                     'artifact_provenance': {key: row[key] for key in ['artifact_provenance', 'log', 'result', 'log_path', 'result_path'] if key in row},
                     'issue': row.get('issue', {}), 'event_status_counts': trace.get('counts', {}),
                     'component_status_counts': dict(Counter(component.get('status', 'unknown') for component in components.values())),
                     'missing_component_reasons': dict(Counter(component.get('reason', '') for component in components.values() if component.get('status') == 'missing')),
                     'native_components': native,
                     'native_render_scope': 'Production component witnesses only. no_rendered_sample means not observed, not proof of missing artwork; tail completion and nonzero final fragments are not inferred.'})
    complete = result.get('complete', False) and result.get('expected_cases') == len(rows) == result.get('completed_cases')
    log_path = '.runtime/schema16-live-all-spells-final-r3/godot.log' if relative != combined else None
    lines = (ROOT / log_path).read_text().splitlines() if log_path and (ROOT / log_path).exists() else []
    return {'status': 'complete_command_sweep' if complete else 'snapshot_only_completion_not_inferred', 'report': relative,
            'factory_version': 'conditions-candidate-7fab471588209a41',
            'current_package_requalified': factory['version'] == 'conditions-candidate-7fab471588209a41',
            'expected_cases': result.get('expected_cases'), 'completed_cases': result.get('completed_cases'),
            'complete': complete, 'native_exit': result.get('native_exit'), 'log': log_path,
            'artifact_provenance': result.get('artifact_provenance', result.get('sources', [])),
            'log_validation': result.get('log_validation'),
            'global_script_resource_errors': [line for line in lines if 'SCRIPT ERROR:' in line or line.startswith('ERROR:')] if log_path else result.get('native_errors'),
            'global_warnings': [line for line in lines if line.startswith('WARNING:')] if log_path else result.get('warnings'),
            'cases_observed': len(rows), 'passing_cases_observed': sum(row['command_checks_ok'] for row in rows),
            'cases': rows, 'qualifies': 'Observed native issued-command cases only; an active or partial sweep is not all 189 passed'}

reader = {row['id']: row for row in safety.get('spells', [])}
live = live_evidence()
live_cases = {row['case']: row for row in live.get('cases', [])}
entries = []
case_records = {}
for original in catalog['entries']:
    row = dict(original)
    row.pop('requirements', None)
    row.pop('scenarios', None)
    for case in row['cases']:
        case_records[case['id']] = case
    row['case_ids'] = [case['id'] for case in row.pop('cases')]
    row['typed_sources'] = typed_by_id.get(row['id'], [])
    row['ui_art'] = ui.get('icons', {}).get(row['kind'], {}).get(row['id'])
    if row['kind'] == 'creature':
        row['portrait'] = ui.get('portraits', {}).get(row['id'])
    row['recording_safety'] = reader.get(row['id'], {'status': 'not_tested_for_this_capability'})
    row['native_gui_case_ids'] = [case for case in live_cases
                                  if case in row['case_ids'] or case == row['id'] + '/baseline']
    entries.append(row)

source_only = [r for r in entries if r.get('inventory_origin') == 'typed_source']
selected_channels = Counter(name for key in selected_clip_ids for name in clips.get(key, {}).get('inputs', []))
channel_owners = defaultdict(set)
channel_families = defaultdict(set)
for owner, rows in typed_by_id.items():
    for row in rows:
        active_clips = {cue['contract'] for cue in row.get('default_cues', [])
                        if cue['dispatch'] in ['event_cue', 'owner_handover']}
        for lifecycle in row.get('condition_lifecycles', []):
            if lifecycle['dispatch'] == 'authored_suppressed':continue
            active_clips.update(lifecycle['phases'].values())
            for clip_id in lifecycle['phases'].values():
                for name in clips.get(clip_id, {}).get('inputs', []):channel_families[name].add(lifecycle['selection'])
        for clip_id in active_clips:
            for name in clips.get(clip_id, {}).get('inputs', []):channel_owners[name].add(owner)
case_counts = Counter(r['scenario_status'] for r in entries)
report = {
    'schema': 1, 'generated_utc': catalog['generated_utc'],
    'scope': 'Offline complete current server/typed-source catalogue and delivered Factory contracts; not runtime validation or visual approval',
    'engine': catalog['expected_engine'], 'factory_version': factory['version'],
    'counts': {'catalogue': len(entries), 'by_kind': catalog['counts'], 'typed_only': len(source_only),
               'typed_only_by_kind': dict(Counter(r['kind'] for r in source_only)),
               'typed_sources_by_section': {k: len(v) for k, v in catalog['typed'].items()},
               'factory_clips': len(clips), 'factory_selections': len(factory['selections']),
               'condition_families': len(current_families),
               'authored_default_and_condition_candidate_clip_ids': len(selected_clip_ids),
               'possible_default_condition_input_channels': len(selected_channels), 'cases_by_capability_status': dict(case_counts)},
    'qualification': {'source': 'Binding presence only; ready is not visual completion.',
                      'scenario': 'The actual current CaseLibrary records, with original faction journal paths and moments.',
                      'providers': 'Shared bridge presence is partial until its distinct consumer and native output pass. Condition families are possible runtime candidates; actual public state selects them. These counts are not a startup warm set.',
                      'approval': 'User approval stays independent; Aid/Bless/False Life/Sacred Flame remain rejected.',
                      'reader_report_complete': safety.get('complete'), 'reader_report_source': safety_source,
                      'reader_inventory_qualified': safety.get('qualified'),
                      'reader_log_validation': safety.get('log_validation', {'status': 'not_available'}),
                      'reader_does_not_qualify': safety.get('does_not_qualify'),
                      'reader_factory_version': 'conditions-candidate-7fab471588209a41',
                      'safety_history': 'The full safety sweep belongs to the previous package. Current native cohort, targeted live commands and performance evidence are separate; old passing statuses do not requalify this release.',
                      'ui_report_source': 'generated/reports/ui-art-coverage.json'},
    'entries': entries,
    'case_records': case_records,
    'selected_channels': {name: {'selected_clip_count': count, 'provider': bridge.get(name, 'missing_provider'),
                                 'possible_authored_owner_ids': sorted(channel_owners[name]),
                                 'possible_condition_families': sorted(channel_families[name]),
                                 'factory_setters': sorted({clip.get('input_setters', {}).get(name, '') for clip in clips.values() if name in clip.get('inputs', [])}),
                                 'consumer_seams': ['presentation/native_inputs.gd::sync', 'presentation/effect_package.gd::set_input']}
                          for name, count in sorted(selected_channels.items())},
    'condition_families': current_families,
    'clip_contracts': contracts,
    'detailed_factory_input_inventory': 'generated/factory_input_inventory_2026-10-19.json',
    'current_public_construction_contracts': factory.get('runtime', {}).get('production_construction', {}),
    'current_intake': 'agent_docs/FACTORY_PRODUCTION_BINDINGS_INTAKE_2026-10-19.md',
    'construction_readiness': 'generated/reports/factory-construction-readiness.json',
    'factory_noncondition_programs_not_automatic_new_gameplay_requirements': programs,
    'handover': {'source': '.runtime/condition-handover-inventory.json', 'report': 'agent_docs/CONDITION_HANDOVER_MIGRATION_2026-10-19.md', 'errors': handover.get('errors', [])},
    'ui_summary': ui.get('summary', {}), 'ui_errors': ui.get('errors', []),
    'remaining_shared_gaps': {
        'providers': ['weapon_binding_remaining_owner_and_legacy_contracts', 'appearance_provider_other_rigs_and_definitions_unqualified', 'history_state', 'actor_context', 'pose_provider_capture', 'event_state', 'event_binding', 'created_item_identity'],
        'partial_spatial_provider': provider_notes['admitted_cells'] + ' Complete spatial lifecycle/output qualification is pending.',
        'public_selectors': public_gaps,
        'class_gates': ['The delivered Rage/Frenzy source now accepts held owners without removal. The client action projection still requires finite observed removal; that remaining client join blocks held owners.',
                        'Frenzy requires a real child-to-parent condition UUID link, absent from current ConditionState.',
                        'Second Wind factual self-heal projection is implemented but has no real class-action native output recording in this corpus.'],
        'unselected_action_programs': ['reaction.spell.counterspell has success/failure studies: needs the actual native outcome selector.',
                                     'action.fire_breath is not an exact current catalogue/typed action ID; do not alias another breath by name.'],
        'actual_attributions': ['Divine Smite modifies a native occurrence through content_attributions, not a synthetic ActionFact.'],
        'runtime_art': ['Body/head/weapon registrations, body-material stacking and authentic history/appearance/event cohorts need native consumer qualification.',
                        'All Factory alternatives must be inspectable without treating them as automatic gameplay bindings.'],
    },
    'provider_contract_notes': provider_notes,
    'checks': {'action_cues': check_evidence('.runtime/native-action-cues.log'),
               'library': check_evidence('.runtime/schema16-library-browser.log'),
               'native_inputs': check_evidence('.runtime/native-input-cells-contract.log'),
               'native_studio_cohort': native_evidence(),
               'live_all_spell_sweep': live,
               'recording_safety': {'report': safety_source, 'checks': safety.get('checks'),
                                    'passed_spells': len(safety.get('passed', [])),
                                    'inventory': safety.get('inventory'),
                                    'inventory_qualified': safety.get('qualified'),
                                    'unavailable_baseline': safety.get('unavailable_baseline', []),
                                    'tested_failures': safety.get('tested_failures', []),
                                    'log_validation': safety.get('log_validation', {'status': 'not_available'})},
               'ui': {'report': 'generated/reports/ui-art-coverage.json', 'errors': len(ui.get('errors', []))}},
}
target = ROOT / 'generated/reports/factory-integration-coverage.json'
target.parent.mkdir(parents=True, exist_ok=True)
target.write_text(json.dumps(report, indent=2, ensure_ascii=False) + '\n')
print(json.dumps({'report': str(target), 'counts': report['counts'], 'bytes': target.stat().st_size,
                  'reader_report_complete': safety.get('complete')}))
