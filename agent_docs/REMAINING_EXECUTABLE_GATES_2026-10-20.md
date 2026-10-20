# Remaining executable gates

20 October 2026. Read-only manifest/source inventory; no Godot, backend, build or
test was launched for this report. No manifest status was changed. Deleted or
excluded rows are **not passes**.

`tests/manifest.json` currently has 496 rows. All `status=ok` paths exist. There
are 51 missing script paths: three already use `mode=none/status=retired`, while
48 still use an executable mode with `owned-by-migration`. Those 48 make an
`--all-status` run attempt files that no longer exist. Separately, **102 existing
executable scripts** remain excluded: 64 `needs-args`, 20 `known-red`, and 18
`owned-by-migration`. Their existence and unresolved contracts must stay distinct
from deleted historical rows.

## Deleted paths only

Every old name below is an absent `tests/<name>.gd` file, verified against the
current directory. Current owners name executable contract checks, not a claim
that an old unknown assertion was reproduced or that the current check passed
in this inventory. Root owns any manifest retirement decision.

| Deleted historical rows | Current executable contract owners |
|---|---|
| `catalog_checks`, `source_catalog_static_owner_checks` | `source_index_owner_checks`, `presentation_resource_revision_checks`, `body_source_reload_checks`: typed source admission, sharing, revision replacement and retained immutable owners. |
| `body_source_parity_checks`, `character_companion_cache_checks`, `modular_tint_checks` | `characters_source_checks`, `schema16_character_sources_checks`, `native_demo_parity_checks`, `native_assembled_demo_checks`, `native_colour_transfer_checks`: actual outfit sources, companions, assembled colour and selected native reference pixels. |
| `creature_geometry_checks`, `normal_profile_checks` | `creature_scene_checks`, `creature_shadow_checks`, `native_optical_media_checks`, `native_surface_receiving_checks`: current registered creature geometry/normals and native receiving. |
| `environment_input_state_checks` | `environment_streaming_checks`, `environment_media_delta_checks`, `world_preparation_receiver_ownership_checks`, `architectural_lighting_checks`: current environment sources, canonical after-values and prepared owner retirement/receiving. |
| `grid_alpha_checks`, `grid_render_checks` | `ground_visibility_checks`, `native_floor_batch_checks`, `native_floor_lighting_checks`, `player_view_checks`: actual current floor overlay/alpha/painter output. `grid_render_checks` is already retired. |
| `exploration_checks` | Already retired. `player_view_checks`, `player_interaction_checks`, `chest_live_checks`, `architectural_lighting_checks`, `frame_profile_checks` retain canonical-player, object/light and rolling-profile contracts; the local gameplay simulator is not restored. |
| `lighting_render_checks` | Already retired. `native_2d_source_checks`, `architectural_lighting_checks`, `lighting_2d_checks`, `light_table_checks`, `door_overlap_checks` own the current approved 2D-light path; the removed demo's 3D-light renderer is not restored. |
| `input_walking_checks`, `walking_checks`, `unity_walk_checks`, `live_chain_separation_checks` | `sdk_transport_checks`, `studio_replay_prefix_checks`, `studio_replay_native_checks`, `movement_reference_speed_checks`, `player_interaction_checks`, `live_spell_checks`: actual delivery, independent ordered replay, movement clocks and issued player actions. No Unity-tour simulator is a current gameplay requirement. |
| `native_area_mask_checks` | `native_area_mask_ownership_checks`, `native_spatial_owner_checks`, `studio_spatial_owner_checks`: actual footprint ownership/receiving and recorded Studio lifetimes. |
| `native_constant_resource_checks`, `native_shared_mesh_checks`, `native_source_resources_checks`, `native_source_admission_checks`, `native_source_startup_checks`, `native_source_reload_checks` | `native_asset_admission_checks`, `native_immutable_preparation_checks`, `native_effect_source_checks`, `native_recorded_preparation_checks`, `native_startup_lifecycle_failure_checks`, `body_source_reload_checks`: immutable preparation, private occurrences/clocks, admission and retirement. |
| `native_source_noise_checks`, `native_source_variant_checks`, `native_source_variant_render_checks` | Current selected-source ownership is checked by `native_effect_source_checks` and `native_immutable_preparation_checks`; source output by `native_effect_render_checks`/`native_spell_witness_checks`. The deleted scripts' complete noise/variant oracle is unavailable here: do not claim all variant output equivalence from these replacements. |
| `native_spell_feedback_checks`, `sandbox_feedback_checks`, `sandbox_flash_playback_checks`, `sandbox_support_feedback_checks`, `sandbox_utility_feedback_checks`, `sandbox_body_surface_checks` | `native_spell_hits_checks`, `native_spell_retained_tail_checks`, `native_support_spell_event_checks`, `native_positive_healing_render_checks`, `wielded_weapon_impact_render_checks`, `native_surface_receiving_checks`: factual contacts/results, body/material receiving and retained tails. Unassigned/user-rejected artwork remains unaccepted. |
| `sandbox_casting_checks`, `sandbox_casting_native_checks`, `sandbox_position_checks`, `sandbox_surface_socket_checks`, `surface_socket_bake_checks` | `native_cast_socket_checks`, `pose_socket_binding_checks`, `native_weapon_input_checks`, `native_spell_admission_checks`, `native_spell_witness_checks`: actual pose registration, source model, endpoints and draw witnesses. |
| `sandbox_particle_clock_checks`, `sandbox_particle_scale_checks`, `sandbox_light_units_checks`, `sandbox_source_light_checks` | `native_effect_particle_checks`, `native_particle_units_checks`, `native_effect_receiving_checks`, `native_light_output_checks`: current absolute clocks, spatial units and native receiving; no old sandbox fixture light is introduced. |
| `sandbox_chill_source_checks`, `sandbox_colour_checks`, `sandbox_ice_web_checks`, `sandbox_support_authoring_checks` | `native_colour_transfer_checks`, `native_requirement_templates_checks`, `native_spell_admission_checks`, `support_spell_event_checks`, `native_support_spell_event_checks`: selected typed bindings and actual inputs. These do not grant visual acceptance of every spell or revive old spell-specific sandbox adjustments. |
| `sandbox_batch_checks`, `sandbox_choreography_checks`, `sandbox_regression_checks`, `sandbox_scene_integration_checks`, `spell_sandbox_checks` | `studio_gallery_spell_checks`, `studio_replay_native_checks`, `live_all_spells_checks`, `live_spell_checks`: original recorded chronology, actual Studio and real player-issued spell paths. Their finite output and timing evidence must remain per case. |
| `sheet_prepack_checks` | `schema16_character_sources_checks`, `media_texture_native_checks`, `source_cut_reuse_checks`: exact current sheets/companions, actual decode/upload roles and source-cut reuse. No retired prepack format is recreated. |

This table covers all 51 absent rows. In particular it does **not** retire the
still-existing geometry/environment tests, old SDK schema tests,
`media_demand_precompute_checks`, `projectile_sandbox_checks`, or any known-red
native/Studio script merely because migration is difficult. `workshop_checks`
also still exists; its already-explicit retirement describes the removed
`main.tscn` product path, not a missing script.

## Three useful existing excluded gates

These are immediate argument-selection candidates, **not qualified results**.
All consume the unchanged committed schema16 Gallery journal; no new engine
recording, compatibility adapter, production accessor or invented state is
needed. Keep their existing assertions and record actual failures if they occur.

| Priority / current manifest row | Exact proposed arguments | Why run it next |
|---|---|---|
| 1. `session_execution_checks` — headless / fast / `needs-args` | `["--recording=res://tests/fixtures/schema16/scenarios/gallery/amber"]` | Durable transport/ACKs continue while display preparation is bounded; actual Gallery reaches independent canonical final state; retirement/cancellation joins without draining unseen history. Its current loopback peer already emits schema16. |
| 2. `studio_recording_media_checks` — GPU / gate / `needs-args` | `["--recording=res://tests/fixtures/schema16/scenarios/gallery/amber", "--recording=res://tests/fixtures/schema16/scenarios/gallery/blue"]` | Exact per-prefix source closures, immutable recording ownership, CPU/GPU roles, byte estimates and optional budgets. It exercises the current `RecordingMedia.plan` that native cohort tests now require. Retain its present manifest mode until root qualifies/classifies it. |
| 3. `trusted_operations_checks` — headless / fast / `needs-args` | `["--recording=res://tests/fixtures/schema16/scenarios/gallery/amber"]` | Exact strict-versus-current-producer decode values, actual SSE/consumer/ACK behavior and named negative envelope controls. Its explicitly archived decoder fixtures also still exist; no old wire path is introduced into production. |

After root supplies those manifest arguments, the existing runner can select the
three rows by name. No `--all-status` sweep should be described as executable
coverage while its 48 deleted paths still have runnable modes.

### Written test-only corrections; qualification pending

- `session_execution_checks` checks its explicit current original before opening
  the loopback worker and independently replays that same journal for canonical
  equality. Initialization failures now report/close the actual owner rather than
  continuing into a half-ready timeline. Bounded preparation, durable ACKs,
  cancellation, private malformed-journal controls and retirement assertions
  remain intact.
- `trusted_operations_checks` removes the retired operation-level `audience`
  assumption. Named malformed-body and numeric controls use the actual optional
  HUD field. Strict/public arbitrary-input negatives remain strict; current
  producer identity/positive sequence, real transport scope/order/ID/consumer/ACK
  negatives remain enforced at their actual owner. The trusted current producer
  deliberately owns nested body schema and UTF-8 validity: this test does not
  reinstall retired recursive validation or a duplicate UTF-8 pass. Actual raw
  Gallery packets must retain exact values/types and sparse field presence;
  diagnostic offline normalization cannot mutate them. The archive check now
  rejects current wire under an old identity rather than fabricating an old
  positive operation by replacing just its identity.
- `studio_recording_media_checks` pins actual typed body/native index admissions
  before its worker borrows them, then checks the same immutable Resource owners
  and retained physical metadata. The retired `catalog/rigs.json` cache-key
  expectation becomes actual typed-index provenance; mutable derived planner
  caches are still excluded. Existing independent exhaustive source/role/byte,
  per-prefix, priority, budget and no-texture/no-readiness controls remain. The
  full-groups environment pass is retained as an independent exhaustive oracle;
  its first-group `required` semantics are still current.

Initial edits were released without a test/build launch. Qualification then
exposed two exact boundaries; no assertions were marked green from source
inspection alone:

- Root's native `studio_recording_media_checks` receipt
  `.runtime/tests/20261020T042634.875211Z` passed **2,606 checks, zero failures** in
  35.6 seconds against both durable Gallery originals.
- The same run's `trusted_operations_checks` found one test-only mismatch:
  `JSON.stringify` sorts object keys, while a pre-serialization dictionary has
  a different insertion order. The control now compares strict and trusted
  parses of the **same serialized bytes**, retaining exact value/type parity.
  Focused headless `.runtime/tests/20261020T042824.965373Z` then passed **472
  checks, zero failures/script errors/engine errors**, exit0 in2.3 seconds.
- `session_execution_checks` exposed a genuine current runtime assumption at
  `Timeline.accept`: the actual schema16 empty loopback initialization reduces
  to `state.senses=null`, but initial spatial observation dereferences it as a
  dictionary. The test retains that legal no-disclosure case; no fake sensory
  state or test-side normalization replaces it. Root corrected initial and
  later resource-owner observation to use empty spatial membership when the
  canonical value is null. Focused headless
  `.runtime/tests/20261020T042954.764626Z` then passed **40 checks, zero
  failures/script errors/engine errors or warnings**, exit0 in5.3 seconds.
  Besides the actual loopback initialization, a labelled compiler-output cut
  checks null→null membership without modifying canonical state, inventing an
  owner or bumping its resource revision. The unchanged Gallery finishes at
  sequence104/118 groups, matches independent replay, and drains all118 groups;
  active cancellation takes34ms and paused replay cancellation0ms in this run.

Manifest argument/status promotion remains root-owned. These receipts qualify
only their stated contracts, not the remaining excluded inventory.

## What remains separate

The current UI/media repair quartet is written and released, with native
qualification still parent-owned; see `CLIENT_SUITE_REMAINDER_2026-10-20.md`.
Factory actor-history shader failures are a real current-source blocker, not a
reason to retire that executable test. The remaining 99 existing excluded rows
need bounded argument/source/assertion review in their actual contract cohorts;
this inventory neither marks them green nor converts them into deletions.
