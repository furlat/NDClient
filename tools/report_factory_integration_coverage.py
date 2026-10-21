"""Offline report join and compact receipt projection for the existing Studio library."""
import argparse
import json
import math
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--safety-report', help='Exact recording-reader receipt to retain, including its package/completeness.')
parser.add_argument('--native-report', action='append', default=[], help='Additional exact Studio native receipt; repeat for independent cohorts.')
parser.add_argument('--live-report', help='Exact issued-command receipt; partial runs remain partial.')
parser.add_argument('--audio-report', action='append', default=[], help='Additional exact authored audio receipt; repeat for independent cohorts.')
parser.add_argument('--ui-report', default='generated/reports/ui-art-coverage.json')
args = parser.parse_args()
def read(relative):
    return json.loads((ROOT / relative).read_text())

def json_values(value):
    # Godot JSON rejects Python's nonstandard Infinity/NaN literals. Retain
    # those diagnostic operands as strings in this offline receipt projection.
    if isinstance(value, float) and not math.isfinite(value):return str(value)
    if isinstance(value, dict):return {key: json_values(item) for key, item in value.items()}
    if isinstance(value, list):return [json_values(item) for item in value]
    return value

catalog = read('.runtime/factory-catalog-join-input.json')
factory = read('assets/vfx/index.json')
inventory = read('generated/factory_input_inventory_2026-10-19.json')
ui = read(args.ui_report) if (ROOT / args.ui_report).exists() else {'status': 'not_available', 'errors': ['UI receipt unavailable: ' + args.ui_report]}
safety_source = args.safety_report or ('.runtime/shared-provider-recording-safety-final/report.json'
                 if (ROOT / '.runtime/shared-provider-recording-safety-final/report.json').exists()
                 else '.runtime/shared-provider-recording-safety-second-checkpoint/report.json'
                 if (ROOT / '.runtime/shared-provider-recording-safety-second-checkpoint/report.json').exists()
                 else '.runtime/shared-provider-recording-safety/report.json'
                 if (ROOT / '.runtime/shared-provider-recording-safety/report.json').exists()
                 else '.runtime/schema16-recording-safety-post-construction/report.json'
                 if (ROOT / '.runtime/schema16-recording-safety-post-construction/report.json').exists()
                 else '.runtime/schema16-recording-safety-qualified/report.json'
                 if (ROOT / '.runtime/schema16-recording-safety-qualified/report.json').exists()
                 else '.runtime/schema16-recording-safety.json')
safety = read(safety_source) if (ROOT / safety_source).exists() else {"status": "not_available", "log_validation": {"status": "not_available"}}
handover_path = '.runtime/condition-handover-inventory.json'
handover = read(handover_path) if (ROOT / handover_path).exists() else {'status': 'not_available'}
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
    'owner_state': 'ordered_condition_item_owner_clock_or_exact_factual_actor_birth_visibility',
    'binding_owners': 'legacy_empty_membership_only',
    'entity_geometry': 'actual_authored_actor_exact_slot_surface_partial_unqualified',
    'recipient_geometry': 'actual_authored_actor_exact_slot_surface_partial_unqualified',
    'source_geometry': 'actual_source_exact_slot_surface_partial_unqualified',
    'targets': 'authored_endpoint_arity_roles_sockets_partial_unqualified',
    'live_endpoints': 'authored_endpoint_arity_roles_sockets_partial_unqualified',
    'delivery_timing': 'authored_launch_and_flight_two_argument_adapter_partial_unqualified',
    'actor_layers': 'visible_private_body_material_revision_bridge_partial_unqualified',
    'treatment_state': 'disclosed_condition_state_bridge_partial_unqualified',
    'owner_projection': 'actual_positive_self_heal_or_observed_condition_uuid_clock_unknown_end_allowed',
    'activation_projection': 'authored_actual_action_and_exact_public_parent_child_membership_partial_unqualified',
    'event_input': 'authored_observed_cast_positive_damage_heal_removal_revival_and_ordinary_creation_partial_consumer_qualification',
    'lease_input': 'finite_observed_event_empty_lease_only_persistent_source_provenance_still_required',
    'owner_visibility': 'actual_displayed_actor_and_authored_owner_alpha_partial_unqualified',
    'admitted_cells': 'prepared_world_rectangles_or_native_local_pairs_nullable_contract_partial_unqualified',
    'weapon_binding': 'exact_disclosed_item_holder_slot_optical_surface_and_selected_source_admission_limits',
    'appearance_provider': 'prepared_modular_outfit_exact_condition_uuid_sampled_frame_lease_fly_qualified',
    'actor_context': 'actual_current_copy_original_departure_or_bounded_disclosed_history_three_mode_native_gate_only',
    'history_state': 'actual_disclosed_mirror_duplicate_count_non_mirror_scoped_inapplicability',
    'pose_provider': 'original_immutable_condition_admission_and_shared_current_view_pose_provider',
    'created_item_identity': 'same_source_condition_inventory_join_and_current_exact_item_partial_subjective_ancestry',
    'surface_presence': 'actual_current_disclosed_spatial_owner_membership_not_synthetic_creation_or_burn',
    'surface_state': 'exact_current_ice_spatial_uuid_unsuppressed_cells_and_optical_membership_only',
    'removed_cells': 'actual_observed_spatial_owner_retirement_not_subjective_visibility_loss',
    'strike_input': 'exact_initial_or_accepted_repeat_vampiric_positive_strike_scope_only',
    'owner_input': 'exact_pre_row_vampiric_grant_condition_for_completed_repeat_only_not_idle_readiness',
    'healing_input': 'exact_positive_vampiric_healing_return_scope_only',
    'native_state': 'actual_applied_contacts_or_explicitly_attributed_vitriolic_recipient_end_only',
    'observation': 'actual_cast_completion_or_divine_word_child_membership_death_outcomes_only',
    'accepted_release': 'actual_completed_direct_payload_cast_and_disclosed_aim_or_exact_created_placement_only',
    'blast_event': 'actual_freezing_direct_explosion_or_exact_delayed_item_lifetime_retirement_footprint_only',
    'damage_event': 'exact_native_payload_or_accepted_exhale_result_save_recipient_only_not_retained_grant_state',
    'contact_event': 'actual_flaming_sphere_ram_owner_save_positive_result_only',
    'operation_state': 'actual_accepted_action_completion_and_disclosed_operation_sheet_witness_only',
    'link_edges': 'actual_disclosed_application_propagation_links_not_all_particle_or_density_sources',
    'weapon_impact': 'exact_observed_equipped_item_attributed_damage_contact_scope_only',
    'reaction_observation': 'resource_authored_actual_accepted_reaction_with_interrupted_public_presentation_partial_unqualified',
}
provider_notes = {
    'appearance_provider': 'Typed appearance definitions prepare actual outfit sheets before admission. Per-condition Factory leases control only opacity; layers follow the body clip/frame/facing. Actual Fly apply/move/view/gear/remove, independent factions, seeking and looping are qualified in agent_docs/APPEARANCE_PROVIDER_COHORT_2026-10-19.md. Unsupported fixed rigs and created-item art remain gaps; there is no new animation controller.',
    'geometry': 'Authored actor/slot lists select actual admitted optical sources. Body, head and weapon slots are not interchangeable. Source pose work is shared independently of translation; receiver-relative geometry keys avoid repeated co-moving uploads. Distinct outputs still need native qualification.',
    'endpoints': 'Authored live_endpoints preserve arity, order, actor roles, sockets and requested surface slots. Extra actors require actual native_actor_uuids. Literal review positions, review trajectories and absent roles remain explicit gaps; no fixture coordinates are copied.',
    'delivery_timing': 'Uses the selected cue launch and contact-minus-launch in the actual two-argument setter. Attached sources with explicit source_launch_local/source_contact_local retain that authored source clock. This supplies timing, not evidence that its native visual release/socket is correct.',
    'event_spheres': 'Finite payload/exhale contacts consume their own applied-result/save/recipient and preserve original caster separately from accepted acting recipient. Direct release uses the actual completed caster and disclosed ground aim or exact created bead placement before flight timing. Freezing immediate blast proves direct declaration ancestry; delayed blast proves actual item/lifetime retirement. Neither uses an occurrence key as a retained payload/grant UUID. Divine Word uses actual child memberships/death. Vitriolic END requires its exact before-member source_condition_uuid and actual recipient END ancestry. Current attributed packets can bind; historical packets without that attribution remain unavailable and are never filled from a newer producer. Exact channels are conditional providers, not proof of actual operands or pixels for every source.',
    'surface_state': 'Only the selected observed-ice source consumes this shape. Actual current spatial UUID/content and unsuppressed disclosed cells provide its optical occupancy gate, with original factual topology retained only to clear absent/suppressed visibility. The delivered128-cell source replaces the old32-cell capacity gap for real49-cell ice owners. Review state/2.6-second retirement are cleared; current spatial ownership handles disclosure loss and seek. No damage, slip, gameplay activity, retained power or inferred rounds are supplied.',
    'body_material': 'Current visible body layers and private material revisions are supplied. Focused setter/restoration tests cover private ownership; this does not qualify all treatments, stacking, outfits, animation revisions or final pixels.',
    'admitted_cells': 'The selected approach manifest condition_prepared flag chooses world rectangles/Array-to-bool versus native local pairs/Variant-to-void. Native optional null is skipped, prepared unknown clears then reports unavailable, known empty is distinct, and explicit nonempty false is rejection. Native pairs use the actual first endpoint plane or endpoint-free root inverse; non-unit/non-quarter-turn grid frames remain unavailable. Footprint and frame changes invalidate one cached conversion.',
    'pose_provider': 'A non-capture operation needs no pose packet. Actual original condition admission is retained through ordered immutable cuts; Flesh to Stone native captured-pose/restoration and the separate logical capture gates qualify their scope. Current geometry is never substituted for history.',
    'actor_context': 'The three delivered actor-history modes consume genuine immutable original draw operands: actual current Mirror copies with disclosed count; bounded real Blur predecessors; Banishment original pre-cut departure even when the actor is canonically absent. Shared native gate294, logical history350 and departure436 are green on independent originals/all quarters/seek/teardown. Actual gear-transition/live surprise cost and whole-package visual approval are not inferred.',
    'created_item_identity': 'The typed creationIdentity descriptor joins an actual lifetime admission and unique descendant inventory admission under its completed original cast. Metadata publishes on the later actual commit. Actual current item/holder/lifetime gates native identity/weapon delivery; absent subjective ancestry stays unavailable. Actual authored created-weapon bodies use their exact admitted item/lifetime/holding and selected body source; unobserved subjective ancestry or unsupported holders still refuse. Historical producer155 evidence and current native output qualification remain separate.',
    'weapon_binding': 'Exact authored weapon/offhand slots cross-check displayed layer item UUID and canonical visual_loadout. Wrong owner, absent current item, ambiguous holder and any additional admission fields actually consumed by the selected source remain explicit per-occurrence refusals; they are not a universal missing item-owner claim. Active Antimagic suppression is retired in schema16; its absent token is not a provider gap. Magic Weapon/Sacred Weapon use their actual public item-effect memberships; actor ledgers do not duplicate those owners. See agent_docs/WEAPON_PROVIDER_COHORT_2026-10-19.md; setter-contract checks do not qualify production pixels.',
    'construction': 'Explicit application_result cues join native cast lineage/application UUID, matching saving throw and applied damage before public Source.make. observed_event cues join their source declaration to real positive heals, recipient-local removals and dead-to-alive changes. Application facts cannot repeat the source invocation. Private phase input data replaces only declared component operands; shared Resources and native facts stay immutable. Static selection cannot construct a successful fixture. Circle has one cast source plus four real recipients, and Preserve Life has one source plus two real receiving draws. Distinct consumers still need native qualification.',
}
# The old input inventory is historical. Current selector limitations below
# come from actual typed variant predicates/dispatch gaps, not its old producer.
public_gaps = [{'owner': owner, 'variant': variant['id'], 'source': row['source'],
                'when': variant.get('when', {}), 'dispatch_gap': variant.get('dispatch_gap', '')}
               for owner, row in catalog['typed'].get('spells', {}).items()
               for variant in row.get('variants', []) if variant.get('dispatch_gap')]
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
            'providers': {name: bridge.get(name, 'provider_not_catalogued') for name in row.get('inputs', [])},
            'visual_qualification': 'not_inferred_from_binding_or_setter_presence'}
    return clip_id

def resolve(cue, subject):
    resolved = cue.get('resolved_source', {})
    if resolved and resolved.get('source_kind') != 'standalone_phase':
        return resolved['id']
    clip_id = cue.get('clip', '')
    if clip_id in clips:
        return clip_id
    selected = selections.get(subject.removeprefix('spell.'), {})
    renamed = [c for c in selected.get('clips', []) if c.startswith(clip_id + '/')]
    role = [c['clip'] for c in selected.get('staging', {}).get('cues', [])
            if c.get('role') == cue.get('role') and c.get('clip') in clips]
    return renamed[0] if len(renamed) == 1 else role[0] if len(role) == 1 else clip_id

def cue_contract(cue, subject):
    source = cue.get('resolved_source', {})
    if source.get('source_kind') != 'standalone_phase':
        return contract(resolve(cue, subject))
    # Keep the real phase path/API separate; do not manufacture an indexed clip.
    key = 'standalone_phase:' + source['source_phase']
    contracts[key] = {
        'clip': source['id'], 'source_kind': 'standalone_phase',
        'source_phase': source['source_phase'], 'inputs': source.get('inputs', []),
        'input_setters': source.get('input_setters', {}),
        'approaches': [{name: approach[name] for name in
                       ['id', 'kind', 'path', 'source_phase', 'seekable', 'construction_input_contract']
                       if name in approach} for approach in source.get('approaches', [])],
        'providers': {name: bridge.get(name, 'provider_not_catalogued') for name in source.get('inputs', [])},
        'visual_qualification': 'not_inferred_from_binding_or_setter_presence',
    }
    return key

typed_by_id = defaultdict(list)
selected_clip_ids = set()
for section, rows in catalog['typed'].items():
    for subject, original in rows.items():
        row = dict(original, source_section=section)
        if section in ['spells', 'actions', 'conditions']:
            cues = []
            for cue in row.get('effects', []):
                i = int(cue['source_index'])
                dispatch = 'condition_owner' if section == 'conditions' else 'event_cue'
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
                if dispatch in ['event_cue', 'condition_owner'] and cue.get('unbound_constructor_inputs'):
                    dispatch = 'unbound_constructor_inputs'
                resolved = cue_contract(cue, subject)
                cues.append({'constructor_input_gaps': cue.get('unbound_constructor_inputs', []),
                             'source_index': i, 'scope': cue.get('scope', 'default'), 'role': cue.get('role'),
                             'constructor_input': cue.get('constructor_input'),
                             'at': cue.get('at'), 'selection': cue.get('selection', ''),
                             'dispatch': dispatch, 'contract': resolved})
                if dispatch in ['event_cue', 'condition_owner', 'owner_handover']:
                    selected_clip_ids.add(resolved)
            row['default_cues'] = cues
            for variant in row.get('variants', []):
                variant['cue_contracts'] = [cue_contract(cue, subject) for cue in variant.get('effects', [])]
                variant['dispatch'] = ('authored_dispatch_limit' if variant.get('dispatch_gap') else
                                       'candidate_requires_actual_public_predicate' if variant.get('when') else 'inventory_only')
                if variant['dispatch'] == 'candidate_requires_actual_public_predicate':
                    selected_clip_ids.update(variant['cue_contracts'])
        if section == 'conditions':
            row['response_cues'] = []
            for cue in row.get('responses', []):
                resolved = cue_contract(cue, subject)
                dispatch = 'unbound_constructor_inputs' if cue.get('unbound_constructor_inputs') else 'candidate_requires_actual_attributed_response'
                row['response_cues'].append({'contract': resolved, 'dispatch': dispatch,
                                             'response': cue.get('condition_response', {}),
                                             'constructor_input_gaps': cue.get('unbound_constructor_inputs', [])})
                if dispatch != 'unbound_constructor_inputs':selected_clip_ids.add(resolved)
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
        row['provider_catalogue_unlisted_channels'] = [name for name in inputs if name not in bridge]
        row['provider_catalogue_scope'] = 'Static method notes only. Missing notes do not prove a runtime provider is absent; actual occurrence diagnostics own binding availability.'
        row['current_bridge_status'] = {name: bridge.get(name, 'provider_not_catalogued') for name in inputs}
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
            'factory_version': result.get('factory_version'),
            'engine': result.get('engine'), 'expected_engine': result.get('expected_engine'),
            'case_ids': [row['case'] for row in result.get('evidence', []) if 'case' in row],
            'engine_errors': errors, 'engine_warnings': warnings, 'report': result_path, 'log': log_path,
            'qualifies': 'Actual native Studio replay cohort, not all-spell visual approval or a performance benchmark'}

def live_evidence():
    combined = '.runtime/schema16-native-gui-qualified/report.json'
    current = '.runtime/shared-providers-live-spells/results.json'
    relative = args.live_report or (current if (ROOT / current).exists() else combined if (ROOT / combined).exists() else '.runtime/schema16-live-all-spells-final-r3/results.json')
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
                     'artifact_provenance': {key: row[key] for key in ['artifact_provenance', 'evidence', 'log', 'result', 'log_path', 'result_path'] if key in row},
                     'issue': row.get('issue', {}), 'event_status_counts': trace.get('counts', {}),
                     'component_status_counts': dict(Counter(component.get('status', 'unknown') for component in components.values())),
                     'missing_component_reasons': dict(Counter(component.get('reason', '') for component in components.values() if component.get('status') == 'missing')),
                     'native_components': native,
                     'native_render_scope': 'Production component witnesses only. no_rendered_sample means not observed, not proof of missing artwork; tail completion and nonzero final fragments are not inferred.'})
    complete = result.get('complete', False) and result.get('expected_cases') == len(rows) == result.get('completed_cases')
    log_path = str(Path(relative).parent / 'godot.log') if args.live_report else '.runtime/shared-providers-live-spells/godot.log' if relative == current else '.runtime/schema16-live-all-spells-final-r3/godot.log' if relative != combined else None
    lines = (ROOT / log_path).read_text().splitlines() if log_path and (ROOT / log_path).exists() else []
    package_input = str(Path(relative).parent / 'package-input.json')
    version = result.get('factory_version') or (read(package_input).get('factory_version') if (ROOT / package_input).exists() else None)
    return {'status': 'complete_command_sweep' if complete else 'snapshot_only_completion_not_inferred', 'report': relative,
            'factory_version': version,
            'engine': result.get('engine'), 'expected_engine': result.get('expected_engine'),
            'current_package_requalified': factory['version'] == version and complete and result.get('ok', False),
            'expected_cases': result.get('expected_cases'), 'completed_cases': result.get('completed_cases'),
            'complete': complete, 'native_exit': result.get('native_exit'), 'log': log_path,
            'artifact_provenance': result.get('artifact_provenance', result.get('sources', [])),
            'prior_sweep_history': '.runtime/schema16-native-gui-qualified/report.json' if relative == current else None,
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
selected_channels = Counter(name for key in selected_clip_ids for name in contracts.get(key, clips.get(key, {})).get('inputs', []))
channel_owners = defaultdict(set)
channel_families = defaultdict(set)
for owner, rows in typed_by_id.items():
    for row in rows:
        active_clips = {cue['contract'] for cue in row.get('default_cues', [])
                        if cue['dispatch'] in ['event_cue', 'condition_owner', 'owner_handover']}
        active_clips.update(cue['contract'] for cue in row.get('response_cues', [])
                            if cue['dispatch'] == 'candidate_requires_actual_attributed_response')
        for variant in row.get('variants', []):
            if variant.get('dispatch') == 'candidate_requires_actual_public_predicate':active_clips.update(variant['cue_contracts'])
        for lifecycle in row.get('condition_lifecycles', []):
            if lifecycle['dispatch'] == 'authored_suppressed':continue
            active_clips.update(lifecycle['phases'].values())
            for clip_id in lifecycle['phases'].values():
                for name in clips.get(clip_id, {}).get('inputs', []):channel_families[name].add(lifecycle['selection'])
        for clip_id in active_clips:
            for name in contracts.get(clip_id, clips.get(clip_id, {})).get('inputs', []):channel_owners[name].add(owner)
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
                      'approval': 'All current artwork and audio remain unreviewed. Source assignments, historical receipts and preview thumbnails do not approve or reject the current artwork.',
                      'reader_report_complete': safety.get('complete'), 'reader_report_source': safety_source,
                      'reader_inventory_qualified': safety.get('qualified'),
                      'reader_log_validation': safety.get('log_validation', {'status': 'not_available'}),
                      'reader_does_not_qualify': safety.get('does_not_qualify'),
                      'reader_factory_version': safety.get('factory_version'),
                      'safety_history': 'Recording safety, native issued-command witnesses and visual approval are distinct. Each report retains its package identity and completeness; an older passing report does not requalify a successor.',
                      'ui_report_source': args.ui_report},
    'entries': entries,
    'case_records': case_records,
    'selected_channels': {name: {'selected_clip_count': count, 'provider': bridge.get(name, 'provider_not_catalogued'),
                                 'possible_authored_owner_ids': sorted(channel_owners[name]),
                                 'possible_condition_families': sorted(channel_families[name]),
                                 'factory_setters': sorted({clip.get('input_setters', {}).get(name, '') for clip in clips.values() if name in clip.get('inputs', [])}),
                                 'consumer_seams': ['presentation/native_inputs.gd::sync', 'presentation/effect_package.gd::set_input']}
                          for name, count in sorted(selected_channels.items())},
    'condition_families': current_families,
    'clip_contracts': contracts,
    'detailed_factory_input_inventory': 'generated/factory_input_inventory_2026-10-19.json',
    'detailed_factory_input_inventory_scope': 'Historical static join against conditions-candidate-7fab471588209a41. Current typed selections, installed clip contracts, providers and gaps are the fields of this report, not the historical producer-absence flags.',
    'current_public_construction_contracts': factory.get('runtime', {}).get('production_construction', {}),
    'current_intake': 'agent_docs/FACTORY_PRODUCTION_BINDINGS_INTAKE_2026-10-19.md',
    'construction_readiness': 'generated/reports/factory-construction-readiness.json',
    'factory_noncondition_programs_not_automatic_new_gameplay_requirements': programs,
    'handover': {'status': handover.get('status', 'reported'), 'source': handover_path, 'report': 'agent_docs/CONDITION_HANDOVER_MIGRATION_2026-10-19.md', 'errors': handover.get('errors', [])},
    'ui_summary': ui.get('summary', {}), 'ui_errors': ui.get('errors', []),
    'remaining_shared_gaps': {
        'providers': ['weapon_binding_selected_source_admission_and_actual_offhand_weapon_qualification', 'appearance_provider_other_rigs_and_definitions_unqualified', 'actor_history_actual_gear_transition_and_live_readiness_qualification', 'event_state_exact_factual_attribution_and_receiving_regions', 'event_binding_exact_current_owner_readiness', 'created_item_identity_subjective_creation_ancestry_gaps'],
        'partial_spatial_provider': provider_notes['admitted_cells'] + ' Actual disclosed membership/suppression and source-owned partition topology have shared consumers. Selected finite contacts require their exact native result/owner operands; richer fixed burn/armed/payload studies remain optional unselected alternatives. Source presence does not qualify output.',
        'authored_variant_dispatch_limits': public_gaps,
        'historical_public_selector_inventory': inventory.get('unavailable_public_selectors', []),
        'historical_public_selector_scope': 'Original inventory receipt only; no current producer-absence claim is inferred.',
        'class_gates': ['Rage/Frenzy holds now use actual condition UUID ownership and unknown-removal clocks. Initial unobserved application, ordinary Rage native output and the separate body-film API remain unqualified.',
                        'Frenzy uses the actual public child-to-parent membership relationship and authored activation projection. An old capture lacking that field cannot qualify its current successor.',
                        'Second Wind has an original two-faction wounded-fighter/self-heal recording, actual projection checks and a submitted native self-heal draw through seeking/factions/looping. This qualifies that scenario, not all class-native consumers.',
                        'Preserve Life has actual declaration/recipient/native-output qualification; Cleansing Touch, Opulent Revival, Turn Undead and Turn Unholy bindings need their own legal scenario/output qualification.'],
        'unselected_action_programs': ['reaction.spell.counterspell uses actual reaction outcome and resource-authored incoming presentation; source assignment is separate from replay/output qualification.',
                                     'action.fire_breath is not an exact current catalogue/typed action ID; do not alias another breath by name.'],
        'actual_attributions': ['Divine Smite modifies a native occurrence through content_attributions, not a synthetic ActionFact.'],
        'runtime_art': ['Body/head/weapon registrations, body-material stacking and authentic history/appearance/event cohorts need native consumer qualification.',
                        'All Factory alternatives must be inspectable without treating them as automatic gameplay bindings.'],
    },
    'provider_contract_notes': provider_notes,
    'checks': {'action_cues': check_evidence('.runtime/shared-providers-headless/native_action_cue_checks.log' if (ROOT / '.runtime/shared-providers-headless/native_action_cue_checks.log').exists() else '.runtime/native-action-cues.log'),
               'library': check_evidence('.runtime/schema16-library-browser.log'),
               'native_inputs': check_evidence('.runtime/shared-providers-headless/native_input_binding_checks.log' if (ROOT / '.runtime/shared-providers-headless/native_input_binding_checks.log').exists() else '.runtime/native-input-cells-contract.log'),
               'native_class_projection': check_evidence('.runtime/shared-providers-headless/native_class_projection_checks.log'),
               'native_studio_cohort': native_evidence(),
               'live_all_spell_sweep': live,
               'recording_safety': {'status': safety.get('status', 'reported'), 'report': safety_source, 'checks': safety.get('checks'),
                                    'passed_spells': len(safety.get('passed', [])),
                                    'inventory': safety.get('inventory'),
                                    'inventory_qualified': safety.get('qualified'),
                                    'unavailable_baseline': safety.get('unavailable_baseline', []),
                                    'tested_failures': safety.get('tested_failures', []),
                                    'log_validation': safety.get('log_validation', {'status': 'not_available'}),
                                    'factory_version': safety.get('factory_version'),
                                    'engine': safety.get('engine'), 'expected_engine': safety.get('expected_engine'),
                                    'complete': safety.get('complete')},
               'ui': {'report': args.ui_report, 'errors': len(ui.get('errors', []))}},
}

# These receipts augment the one existing case index. They never mark its
# studio_checked flag, invent a scenario, or turn an old package run into a
# qualification of the installed successor. Keep evidence kinds independent.
case_evidence = defaultdict(list)
unmatched_evidence = []

def journal_key(value):
    if not isinstance(value, str) or not value:return None
    value = value.replace('\\', '/')
    if value.startswith('res://'):value = str(ROOT / value.removeprefix('res://'))
    if len(value) > 2 and value[1:3] == ':/':value = '/mnt/' + value[0].lower() + value[2:]
    return str(Path(value).resolve())

journal_cases = defaultdict(set)
for case_id, case in case_records.items():
    for directory in case.get('journals', {}).values():
        journal_cases[journal_key(directory)].add(case_id)

def exact_case(row):
    identity = row.get('case', row.get('case_id'))
    if identity in case_records:return identity
    candidates = set()
    for field in ['directory', 'journal', 'recording']:
        candidates.update(journal_cases.get(journal_key(row.get(field)), ()))
    return next(iter(candidates)) if len(candidates) == 1 else None

def witness(case_id, kind, source, receipt, status, **detail):
    if case_id not in case_records:
        unmatched_evidence.append({'kind': kind, 'report': source, 'case': case_id,
                                   'reason': 'No exact case id or unique original journal path is published; no family-name inference.'})
        return
    version = receipt.get('factory_version')
    case_evidence[case_id].append({
        'kind': kind, 'report': source, 'status': status,
        'factory_version': version,
        'package_scope': 'reported_package_matches_installed_at_join' if version == factory['version'] else 'historical_package' if version else 'package_identity_not_recorded',
        'engine': receipt.get('engine'), 'expected_engine': receipt.get('expected_engine'),
        **detail,
    })

for row in safety.get('spells', []):
    witness(exact_case(row), 'recording_reader', safety_source, safety, row.get('status', 'reported'),
            qualifies='Recorded journal reduction/error safety only; no native pixels, live gestures or audio acceptance.',
            failures=row.get('failures', []), complete_inventory=safety.get('complete'), inventory_qualified=safety.get('qualified'))
for row in live.get('cases', []):
    witness(row['case'], 'issued_command', live['report'], live, 'command_checks_passed' if row['command_checks_ok'] else 'command_checks_failed',
            qualifies=row['native_render_scope'], native_components=row['native_components'],
            failures=row['failures'], complete_inventory=live.get('complete'))

native_reports = list(dict.fromkeys([native_evidence().get('report'),
    '.runtime/shared-providers-second-wind-native.json', '.runtime/native-heavy-effects-render.json', *args.native_report, *args.audio_report]))
for source in native_reports:
    if not source:continue
    if not (ROOT / source).exists():
        unmatched_evidence.append({'report': source, 'reason': 'Requested receipt is unavailable.'})
        continue
    receipt = read(source)
    scope = receipt.get('scope', 'Actual Studio native replay and canonical seeking/looping for this recorded cohort; no all-family or human approval claim.')
    log_path = Path(receipt.get('log') or Path(source).with_suffix('.log'))
    if str(log_path).startswith('res://'):log_path = ROOT / str(log_path).removeprefix('res://')
    log_lines = (ROOT / log_path).read_text(errors='replace').splitlines() if (ROOT / log_path).exists() else []
    native_errors = [line for line in log_lines if 'SCRIPT ERROR:' in line or line.startswith('ERROR:')]
    log_validation = 'failed' if native_errors else 'passed' if log_lines else 'not_available'
    passed = receipt.get('checks', 0) > 0 and not receipt.get('failures') and not native_errors
    rows = receipt.get('cases', []) + receipt.get('evidence', [])
    if source in args.audio_report and not rows and receipt.get('recording'):
        rows = [{'recording': receipt['recording'], 'audio_transport_only': True}]
    for row in rows:
        if not isinstance(row, dict):continue
        case_id = exact_case(row)
        # Preparation-only diagnostics are not pixel or playback witnesses.
        if row.get('kind') in ['native_preparation_profile', 'native_settle_pending', 'native_settle_failed']:continue
        if source not in args.audio_report:
            witness(case_id, 'native_replay', source, receipt,
                    row.get('presentation_status', 'replay_checks_passed') if passed else 'replay_checks_failed',
                    qualifies=scope, perspective=row.get('perspective'), failures=receipt.get('failures', []),
                    native_sources=row.get('native_sources', []), observed_native=row.get('observed_native', {}),
                    log=str(log_path), log_validation=log_validation, native_errors=native_errors,
                    clip_id=row.get('clip'), seat=row.get('seat'), quarter=row.get('quarter', row.get('published_quarter')),
                    source_event_uuid=row.get('source_event_uuid', row.get('occurrence')),
                    changed_pixels=row.get('changed_pixels', row.get('pixels')),
                    source_age=row.get('source_age'))
        audio = row.get('audio_primary', {}) or (row.get('diagnostics', {}) if source in args.audio_report else {})
        if audio:
            observed = audio.get('counters', {}).get('started', 0) > 0 or (row.get('pcm_frames', 0) > 0 and row.get('peak', 0) > 0)
            witness(case_id, 'audio_playback' if observed else 'audio_transport', source, receipt,
                    'playback_errors' if audio.get('errors') or native_errors else 'playback_observed' if observed else 'no_playback_observed',
                    qualifies=scope if source in args.audio_report else 'Actual authored audio transport starts for these exact rows; sound completeness, mix, timing and artistic acceptance are separate.',
                    counters=audio.get('counters', {}), errors=audio.get('errors', []), rows=audio.get('rows', {}),
                    receipt_failures=receipt.get('failures', []),
                    pcm_frames=row.get('pcm_frames'), pcm_peak=row.get('peak'), pcm_capture=row.get('pcm_capture'),
                    log=str(log_path), log_validation=log_validation)
        elif row.get('audio_transport_only'):
            witness(case_id, 'audio_transport', source, receipt, 'transport_checks_passed' if passed else 'transport_checks_failed',
                    qualifies=scope, failures=receipt.get('failures', []), log=str(log_path), log_validation=log_validation)

report['case_evidence'] = dict(case_evidence)
report['unmatched_evidence'] = unmatched_evidence
for entry in entries:
    entry['witnesses'] = [value for case_id in entry['case_ids'] for value in case_evidence.get(case_id, [])]
    entry['output_witnesses'] = [value for value in entry['witnesses'] if value['kind'] in ['native_replay', 'audio_playback']]
    if entry['presentation_status'] in ['not_assessed', 'evidence_available']:
        entry['presentation_status'] = 'evidence_available' if entry['output_witnesses'] else 'not_assessed'
evidence_path = ROOT / 'generated/reports/studio-case-evidence.json'
evidence_path.parent.mkdir(parents=True, exist_ok=True)
evidence_path.write_text(json.dumps(json_values({
    'schema': 1, 'generated_utc': catalog['generated_utc'], 'factory_version': factory['version'],
    'engine': catalog['expected_engine'],
    'scope': 'Exact saved case receipts, joined offline. Reader safety, issued commands, native replay/pixels and audio playback retain separate scopes and original package identities. Evidence availability is not complete capability coverage or visual approval.',
    'cases': dict(case_evidence), 'unmatched_evidence': unmatched_evidence,
}), indent=2, ensure_ascii=False, allow_nan=False) + '\n')
target = ROOT / 'generated/reports/factory-integration-coverage.json'
target.parent.mkdir(parents=True, exist_ok=True)
target.write_text(json.dumps(json_values(report), indent=2, ensure_ascii=False, allow_nan=False) + '\n')
print(json.dumps({'report': str(target), 'counts': report['counts'], 'bytes': target.stat().st_size,
                  'reader_report_complete': safety.get('complete')}))
