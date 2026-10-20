# Remaining executable gates — 20 October 2026

Read-only inventory at main checkpoint `a76207a6` plus the current working tree.
Sources: `tests/manifest.json`, the actual `.runtime/tests/*/summary.json` receipts,
[excluded-headless review](EXCLUDED_HEADLESS_GATES_2026-10-20.md),
[main recovery ledger](MAIN_CLIENT_SUITE_REPAIR_2026-10-20.md) and
[current checkpoint](REPLAY_PAGING_DEPARTURE_CHECKPOINT_2026-10-20.md).
Only this checklist changed. No gate was run, reclassified, skipped or promoted.
`status=ok` means runner eligibility, not that the latest execution passed.

## Exact inventory

| Current manifest population | Count | Meaning |
|---|---:|---|
| All rows |504|One manifest, including helpers/history.|
| Eligible `ok` executable rows |338|149 headless fast +26 headless gate +152 GPU gate +11 live.|
| Existing excluded executable rows |89|55 `needs-args`,17 `known-red`,17 `owned-by-migration`;27 headless and62 GPU.|
| Retired |52|51 missing historical paths plus the existing explicitly retired workshop; no passes.|
| Helpers |24|Non-executable dependencies/tools; no passes.|
| Other non-executable `ok` |1|`weapon_effect_support`, mode/tier `none`; not a standalone passed gate.|

All currently eligible script paths exist. All literal preloads in the89 existing
excluded scripts also resolve; that does **not** establish API/fixture compatibility.
The old33-excluded-headless and102/99-excluded-total prose is historical: the
current counts are27 and89. No deleted path remains in an executable mode.

- Latest complete fast receipt: `.runtime/tests/20261020T060718.070305Z/`,
  **149/149 clean**. It is not the26 additional headless gates, native or live suite.
- Historical182-row gate sweep `.runtime/tests/20261020T043958.374751Z/`
  had **45 failures**. Forty now have later clean stored results under their
  current declared modes; the five still-red required GPU rows are below.
  This reconciliation is not one coherent new full-native run.
- The snapshot contains no same-mode runner receipt for `lighting_live_checks`,
  `live_gallery_checks` or `player_wait_checks`. Do not turn absence into failure
  or success; those exact live gates remain unqualified by the stored runner ledger.

## Next required red cluster: source clocks and first output

These five are already eligible required gates. All currently take `args=[]`;
no missing fixture argument explains them. Keep their original pixel assertions.

| Gate / latest stored receipt | Actual remaining failure | Bounded next operation |
|---|---|---|
| `effect_package_checks` /061148.551252Z |3 failures in3896 checks: all three Insect Plague recorded approaches have zero coverage at0/25/50/75%.|Retain exact source clock handoff; qualify a repaired sealed delivery, not a new default/experimental sampler.|
| `studio_spell_batch_checks` /061148.551252Z |4 failures in6403 checks, all Sleep/both seats: sibling pending `native_spell_source_colour_not_prepared`, then zero selected-source framebuffer contribution.|Trace actual source-colour/preparation ownership and ordinary process-frame admission; do not equate `status=rendered` with pixels or extend a timeout blindly.|
| `native_actor_context_render_checks` /043958.374751Z |34 assertions but two shader compilation errors. The exit0/assertions alone fail the gate.|Complete sealed successor intake first; then actual first capture, current-view/seek, real Mirror count and Banishment departure output. Static ZIP/API inspection is not native qualification.|
| `native_blood_partition_checks` /043958.374751Z |83 passing assertions plus q3 source coverage0; complement/union equality on an empty image does not close this.|Decompose source sampling/emitter/draw readiness at held age. Keep all four actual views, fixed anchor, one simulation and exact RGBA/union controls.|
| `native_effect_receiving_checks` /050414.504715Z |80 passing assertions plus four failures: A2 q1 coverage0 and missing normal/light response.|Treat alongside partition through their shared `NativeEffectPreview`/sampler path; compare identical reset/draw histories before attributing it to source art.|

The experimental particle-clock A/B was inconclusive and is not a passing
replacement. See [the checkpoint's exact limits](REPLAY_PAGING_DEPARTURE_CHECKPOINT_2026-10-20.md)
and [Factory swarm handoff](FACTORY_SWARM_RECORDING_HANDOFF_2026-10-20.md).
The c494 history-source red remains current until complete e102 replacement and
native receipts; its repaired candidate shaders are not yet installed evidence.

## Actionable input/migration clusters

`J(x,seat)` below is the unchanged original journal
`res://tests/fixtures/schema16/scenarios/<x>/<seat>`; default seat Amber.
Arguments here are **candidate inputs**, not claims that stale tests now pass.
Never export current production output as the missing independent golden.

| Priority / bounded cohort | Actual inputs and required repair |
|---|---|
|1. Current media/ready-order values |`media_latency_checks`: `--state=res://tests/fixtures/schema16/character_sources.json`. `timeline_readiness_checks`: repeated `--recording=J(gallery,amber)` and Blue. `preload_priority_checks`: `--recording=J(gallery)` but its `catalog/rigs.json`/actor-field assumptions need typed-source migration first. Preserve priority, finite queues, no premature publication and canonical immutability.|
|2. Public condition/equipment/Studio controls |Use `J(hide)`, `J(hide-light)`, `J(rage)` for equipment/Frenzy/faction/light UI/restore; both independent seats where compared. `equipment_presentation_checks` and `impact_placement_checks` still read legacy rig JSON; light UI/value tests still contain old visible arrays/level expectations, and faction tests contain retired browser labels. Fix those exact current contracts rather than create fake initial conditions or old UI.|
|3. Actual applications/native event boundaries |`native_application_constructor_checks` has a prior104-check headless receipt011236.703604Z, but its manifest still points into ignored `.runtime/studio-library/...circle_of_death.../20261019T142214.366493Z/amber/journal`. Persist those exact four-recipient/save-branch originals and preserve all104 assertions; Fireball is not a substitute. Existing channel/event/thumbnail tests have already migrated and are now eligible—do not reopen that completed input work as missing.|
|4. World/destruction/blood scenes |`door_state_render_checks`, `world_authority_checks` and `wall_corner_checks` require separated `--recording <path>`; many other tests require `--recording=<path>`. Gallery has four actual destroyed objects, while `world_authority_checks` requires five and old object shape. Its exact old corpus or a lawful equivalent with all five is required. For blood/resumed-movement use actual `J(oa-walk)`/lethal/late-lethal originals only after proving their deposits and resumed target motion satisfy the assertion; a generic attack case is insufficient.|
|5. Independent metadata/material references |`required_actor_optics_checks` and `required_actor_reuse_checks` require `--recording` **and** a genuine immediate `--media-oracle`; both still call retired retained-reducer methods. `presentation_worker_metadata_checks` additionally needs compiler/environment/media oracles; `actor_material_payload_checks` needs conditions+actor oracles and `--native` for pixels. These exact references are not among the durable pinned oracles. Preserve closure/provenance before migration.|
|6. Remaining interaction/live artifacts |`targeting_hover_checks`/`selection_media_checks` need a real targeting `checks.json`; `selection_source_handoff_checks` needs a complete actual player-run directory. Current durable scenario journals are not substitutes for these interaction reports. `trusted_choices_checks` needs an authentic compact HTTP ChoicesResponse envelope; existing Gallery/Vampiric `choices.json` are bare discovery bodies.|
|7. Historical optimization comparisons |`media_recorded_latency_checks` has an existing `media_demand_reference.gd`, but hardcodes command48/56 and inherited retired readers; Gallery cannot establish those cold/warm semantics by number alone. `condition_material_checks --oracle=<directory>` needs independent original Pygame operator output via its existing generator, not a current rendering. Old compiler/thin-index parity needs its actual pre-change source/index; missing originals are explicit blockers, not self-golden permissions.|
|8. Protocol/complete inventory |The27 excluded headless rows are fully listed below; [the older detailed review](EXCLUDED_HEADLESS_GATES_2026-10-20.md) separates obsolete schema6–9 dispatch from still-required semantics. Keep fold/spool/COW/negative/refusal behavior in current owners. `schema16_scenario_recording_checks` still expects recorder-index shape, not the Fixtures catalog. `schema16_recording_safety_checks` remains a complete189 inventory failure until actual missing baseline commands exist.|

Pinned independent oracles currently present are requirements-before-cache,
media-before-source-delta, blood-before-atlas/cache, shadows-before-cache,
original condition-selection values and native-class original sources. Their
[provenance README](../tests/oracles/README.md) defines their permitted adapters;
it does not imply that they implement a different missing immediate oracle.

## Complete outstanding excluded names

These are **all89 existing excluded executable rows**, exactly as currently
classified; this is an inventory, not a retirement or promotion decision.

**headless / needs-args (19)**

`base_audio_checks`, `blood_authority_checks`, `compiler_join_parity_checks`, `compiler_snapshot_checks`, `environment_owner_checks`, `event_trace_isolation_checks`, `frenzy_presentation_checks`, `media_latency_checks`, `native_application_constructor_checks`, `packet_pipeline_equality_checks`, `sdk_cell_checks`, `sdk_optical_sources_checks`, `sdk_points_union_checks`, `sdk_sensory_journal_checks`, `sdk_snapshot_checks`, `sdk_tile_field_checks`, `tile_journal_checks`, `trusted_choices_checks`, `schema16_scenario_recording_checks`.

**headless / known-red (2)**

`event_trace_checks`, `schema16_recording_safety_checks`.

**headless / owned-by-migration (6)**

`character_geometry_checks`, `sdk_reducer_checks`, `sdk_retained_transaction_checks`, `sdk_sensory_context_checks`, `sdk_single_audience_projection_checks`, `thin_body_source_checks`.

**gpu / needs-args (36)**

`actor_material_payload_checks`, `condition_material_checks`, `door_state_render_checks`, `equipment_presentation_checks`, `frenzy_render_checks`, `hud_retention_checks`, `impact_placement_checks`, `light_range_profile_checks`, `media_completion_checks`, `media_handoff_checks`, `media_recorded_latency_checks`, `preload_priority_checks`, `presentation_checks`, `presentation_worker_metadata_checks`, `recorded_lifecycle_checks`, `recorded_media_completion_checks`, `required_actor_optics_checks`, `required_actor_reuse_checks`, `selection_feedback_metadata_checks`, `selection_media_checks`, `selection_source_handoff_checks`, `settings_checks`, `source_requirement_publication_checks`, `studio_blood_partition_checks`, `studio_blood_residue_checks`, `studio_condition_preview_checks`, `studio_effect_version_checks`, `studio_faction_ui_checks`, `studio_light_levels_checks`, `studio_light_ui_checks`, `studio_ui_checks`, `targeting_hover_checks`, `timeline_readiness_checks`, `vfx_effect_hold_checks`, `wall_corner_checks`, `world_authority_checks`.

**gpu / known-red (15)**

`condition_lifecycle_checks`, `legacy_preparation_checks`, `native_atlas_publication_checks`, `native_prefetch_ownership_checks`, `native_preparation_cache_checks`, `native_spell_batch_render_checks`, `native_spell_library_checks`, `native_spell_panes_checks`, `native_spell_playback_checks`, `native_spell_studio_checks`, `receiver_bounds_checks`, `reveal_preparation_overlap_checks`, `studio_checkpoint_native_checks`, `studio_native_preview_resource_checks`, `studio_seek_checks`.

**gpu / owned-by-migration (11)**

`character_geometry_render_checks`, `character_geometry_sampling_checks`, `character_geometry_scene_checks`, `creature_source_checks`, `environment_normal_delivery_checks`, `environment_source_preparation_checks`, `media_demand_precompute_checks`, `native_authoring_checks`, `native_spell_batch_authoring_checks`, `normal_profile_media_checks`, `projectile_sandbox_checks`.

## Plan-adherence / anti-slop boundary review

- Consolidation is real: one main checkout/branch, frozen211 executable input,
  unchanged original subjective streams, explicit source ownership and separate
  required native gates. No reason was found here to reopen canonical schema or
  add runtime validation, a clock hold or a new test/renderer manager.
- The main recovery ledger's465-row/107-fast section and percentages describe
  older checkpoints. Its appended receipts and the manifest supersede those
  numbers; they are not a measurement of accepted spell/condition/class coverage.
  The old remaining-gate prose also overstated excluded counts; this snapshot
  reconciles them without silently deleting obligations.
- Current live inventory artifact still says189 attempted,184 command-success,
 182 runtime-safe; that exact joined result remains red. The new Hellish
  single-target original proves an SDK capture and is in Studio, but is **not**
  yet a new native/live success in that189 result. Its prior area-trigger gap,
  Spare discovery, three smites and unregistered Fixture Test Bless stay explicit.
- Three fresh Gallery runs in `.runtime/tests/20261020T062220.033956Z/` each
  passed313 functional assertions with no owned leftovers. Their actual frame
  p95 values are12.424/12.046/11.896ms, p99=16.180/15.603/15.584ms,
  maxima35.566/36.266/41.900ms. Thus100+FPS/no-spike is **not** complete.
  Analysis: `.runtime/consolidation/paged-gallery-three-analysis.json`.
  Current camera size12 versus previous18 prevents an isolated paging A/B claim;
  separate server dispatch duration must not be subtracted across machine clocks.
- Source delivery, public-provider input, actual scenario, rendered output and
  human approval remain separate. Aid/Bless/False Life/Sacred Flame remain
  unaccepted; package availability/default assignments do not reverse that.
  Actor-history shader fixes/new weapons are a separate complete-package intake,
  not an excuse to swap unselected alternatives or remove the proven same-age
  fallback before actual source hooks are demonstrated.
- Next bounded stop: close the shared source-clock/output red cluster, qualify
  the selected input cohorts with their real evidence, then checkpoint explicit
  code/tests/docs/fixture paths. Do not turn the89-row inventory into an endless
  prerequisite that strands already-authorized shared providers/Studio delivery.
