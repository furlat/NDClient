# Schema 16, native conditions and the complete Studio

19 October 2026 — revised execution plan. **Canonical base committed; complete Factory integration and shared-provider qualification active.** Requested branch: `codex-authoring-schemabump`; single active implementation branch/worktree: `codex-authoring-schemabump` / `NDClientGodot`, from committed plan `9b73f29a`. [Execution evidence and remaining gates](SCHEMA16_UNIT_A_PROGRESS_2026-10-19.md).

Read the execution checklists first. The single appendix holds the design rationale, contracts and detailed acceptance rules. Phase numbers are unchanged so existing reviews remain traceable.

## Target and authority

- Official schema source: `/mnt/c/Users/tommaso/Documents/Dev/dnd_engine`, branch `event-native-deltas`, inspected commit `211b71134ed15c89e62232587381f7e15a5961c3`.
- Protocol **1**, player schema **16**, digest **`49d14bc20920f5698eb4f09e3aeece442380242cd1453893d45f94ea9fb0c8a5`**.
- Promotion is a real user instruction: “that is offically the schema we are against”. This authorizes reading the promoted source. **All imports, launches, fixtures, recordings and tests use a frozen export; never run from or write into the official checkout.** Preserve concurrent uncommitted engine work. A later promoted commit requires an inspected diff and matching inventory/recordings.
- Sources: [engine handout](/mnt/c/Users/tommaso/Documents/Dev/dnd_engine/agent_docs/GODOT_CLIENT_SCHEMA_16_HANDOUT_2026-10-19.md), [protocol README](/mnt/c/Users/tommaso/Documents/Dev/dnd_engine/sdk/protocol/README.md), reference `dnd/player/{reduction,world_reduction,world_columns}.py`; [schema handoff](SCHEMA16_CLIENT_HANDOFF_2026-10-19.md), [Studio handoff](STUDIO_HANDOFF_2026-10-19.md), [Factory production handoff](/mnt/c/Users/tommaso/Documents/assets/VFXFactory/docs/CONDITIONS_PRODUCTION_HANDOFF_2026-10-19.md), [source design](PRESENTATION_SOURCE_DESIGN_2026-10-18.md), [package contract](VFX_PACKAGE_CONTRACT_2026-10-18.md).
- This plan supersedes old engine pins/digests, schema-9/15 content counts and the requirement to finish all conditions before starting Studio. Current code wins over stale handoff prose. Saved `PlayerSequence` container version **9 carries current schema-16 values**; old wire-schema-9 recordings remain stale.

## Execution units and stop points

**Execution scope clarified by the user, 19 October (during implementation):**
use the complete Factory handoff for **all spells, conditions, class abilities
and actions**, identify every remaining gap, and cover every spell icon and
character portrait. Haste is an example, never a special implementation branch.
The units below remain reviewable checkpoints; **Stop A is no longer the end of
the currently authorized work**. Continue from the canonical playable base into
the closed-package integration and the shared providers that available delivered
effects actually require. Keep unsupported public-input/art gaps explicit; never
claim that package copying, a baseline cast or a placeholder completes a family.
Server recording defects remain named failures while independent client work
continues; they must not strand the Factory migration behind an unrelated gate.

| Unit | Phases | Deliverable / stopping point |
|---|---|---|
| **A — first implementation unit** | 0–2 | **Stop A:** playable schema-16 client, usable Studio cohort and all-spell crash-safety report. Hand over launch commands, evidence and unresolved visual gaps. |
| **B — package integration** | 3 | **Stop B:** closed new package, simple prepared lifecycles/new examples and measured surprise first-use readiness. Hand over again. |
| **C — shared providers and complete coverage** | 4–6 | Shared adaptive inputs, full capability/case coverage and final scale qualification, implemented in bounded cohorts inside the now-authorized full migration. |

The full roadmap stays intact. Implement the canonical base first, then continue
the full delivered-effect migration authorized above. Phase 2a opens a useful
preview before the safety sweep finishes; completion of A still requires Phase
2b. Phase 5 expands scenario/variant depth, not the first all-spell crash check.

### Complete inventory, presentation and UI art coverage

- [ ] Join **every current engine ID** with its typed presentation source,
  Factory selection and declared inputs, supported renderer bindings, recorded
  scenarios, runtime safety result and visual-review status. Include actions,
  reactions, traits and class features; do not restrict the worklist to spells
  or the first cohort. Derive it from the existing catalogs, not a second manual
  registry. Every missing/partial input or source has its exact owner and reason.
- [ ] Resolve every spell's icon and every character/creature's portrait from
  the supplied UI deliveries and typed assignments. Include class/action icon
  requirements in the same audit. Reuse actual existing resources; explicit
  missing artwork and stand-ins remain gaps, not quietly accepted final art.
- [ ] Keep the complete coverage visible in the same Studio browser, with real
  case links and separate source/provider/scenario/approval facts. Qualify each
  shared provider across compatible delivered families rather than adding
  condition-specific code or manufacturing outcomes.

## Rules for every phase

- One canonical schema-16 fold and the production `Play`/compiler/timeline/audio path, shared with Studio. Small existing-module readers; no full legacy projection, synthetic old facts or second reducer.
- Prepare immutable resources early; publish native bodies/items/conditions/disclosure only at their ordered occurrence. Keep immutable transition cuts and private owner clocks/materials/history. **No presentation holds, prediction revival or invented outcomes.**
- Preserve Windows Godot 4.7.2 Forward+/Vulkan, the 3D world, approved native 2D lighting/normals/cap/colours, depth/sorting, shadows, tint, wall modes, body/audio timing and hit-material choice.
- Build/tests validate resources. No runtime schema/hash/freshness passes, deep-copy safety layers, repeated sheet decoding or GPU readbacks. Use existing Resources/Nodes and plain functions/data; no Manager/Registry/Handle framework or 155 condition-specific switches.
- Follow README “How to test” and `tests/manifest.json`. Give affected migration checks real gates/arguments; name unrelated baseline failures. A default subset passing is not the whole repository passing.
- Stage explicit paths; no `git commit -a`, attribution footer, push or merge into `codex/ndclient`. Art/binaries remain ignored. Package changes are separate from code changes.
- Godot runs use an absolute Windows worktree `--path`, a timeout, headless when possible, and path-specific cleanup of only owned processes. Never kill Factory or the user's preview. Serialize GPU tests/profiling.

## Phase 0 — freeze inputs and establish the baseline

**Files:** `tools/setup_worktree.sh`, launch/test engine defaults, `sdk/*identity*`/schema, `tools/snapshot_server_ids.py`, `authoring/server_ids.json`, `presentation/native_presentation_sources.gd`, `build/presentation/`.

- [ ] Arrange the dedicated client worktree safely. Do not invoke `setup_worktree.sh` blindly: it uses `checkout -B` and obsolete `.derived`/mutable-output junctions. Any helper repair is a small separate change, not a prerequisite tool rewrite.
- [ ] Export the verified official commit read-only; use that root consistently for Python SDK, launcher, recorders and tests. No old-pin fallback or implicit inclusion of uncommitted production edits.
- [ ] Copy schema/identity, regenerate IDs, inspect retired Multiattack/hero aliases/item facets, then build the three typed-source domains. Remove the residual unconditional `.derived/native-spells/current` read instead of reviving that path.
- [ ] Record current package, approved fixtures, coverage and relevant manifest failures. Share only immutable source art; each worktree owns its package, build and runtime outputs.

**Gate / output:** one baseline ledger with exact identities, clean-build result, named pre-existing failures and executable launch/test commands. Package integrity is checked at installation; no extra recurring checksum process.

## Phase 1 — SDK, consuming readers and the equip publication race

**Files:** `sdk/{protocol,reducer,transitions,audience,journal,choices,transport,sse}.gd`, `presentation/{session,compiler,components,timeline}.gd`, `play.gd`, existing UI/item/condition readers and launch tools.

- [ ] Implement canonical schema-16 world columns/static stores, sensory membership/memory, bodies/items, HUD/initiative, groups/lineages/cursors and native log in reference order. Preserve cancellations, world-before-fact ordering and seat disclosure.
- [ ] Capture immutable per-row transitions. `ActorChangeFact` rows remain ordered; removal retains its **pre-row condition member**. Remove→reapply must survive within one occurrence; duration-only changes do not replay an application.
- [ ] Replace removed `kind="condition"` dispatch with native-linked presentation cues. Resolve declarations through casts/group resolutions; controlled inventory through `state.items`, actor UI through bodies. Update audio, logs, targeting, inventory/loot and Studio inspection readers together.
- [ ] Update fresh/resumed attachments, ordered backfill/duplicates, free aim with empty target lists, per-member restrictions, multi-position/wall requests, item-use facets and current content bindings. Saved container version 9 is not old-wire compatibility.
- [x] **Fix the equip race now:** prepare the actual actor structure/equipment boundary before its timeline commit. Reuse that admitted candidate at publication; do not hold the clock, delay the authoritative commit or hide the error.

**Gate:** all 32 fold-vector files plus reference error cases; per-record multi-seat spool oracle; reconnect/COW/row-order cases; actual Choices→Preview→Command route; relevant fast/live checks. Run `player_interaction_checks` in **five independent live runs**, recording each result and boundary timings: all green, zero “Actor structure was not prepared before display”, zero presentation holds and correct final equipment. Recheck this gate after later actor/material integration changes. Latest repeat gate: `.runtime/tests/20261020T075025.026968Z/summary.json`, all five fresh runs34/0, zero script/engine errors and no owned leftovers after this shared-provider batch.

## Phase 2 — usable Studio, then early all-spell crash safety

**Files:** `tools/studio_cases/{adapter,record}.py` and scenario data, existing capture tools, `studio/{recording,case_library,studio}.gd`/browser modules, `tests/{studio_library_browser_checks,live_all_spells_checks}.gd`, `tests/manifest.json`.

### 2a. Open the real review surface early

- [ ] Port the useful plain-role adapter idea from `feature/opus-studio-cases` (`303aa50a`); it is only a paused adapter, not a finished runner. Replace old SDK calls and silent nearest-target/failed-step fallbacks.
- [ ] Record original journals for both factions: movement/door/room entry; attack→damage→hurt→death; Fire Bolt/Fireball; real Shield reaction; Haste application/move/end/lethargy; Hide→crouched transparent movement→actual removal/restoration.
- [ ] Start demonstrations in ordinary idle, then execute the real action/application/removal. Use the same production renderer. One authoring-organized browser core replaces overlapping navigation; one rendered faction by default, independently reduced journals and faction selection.
- [ ] Make case selection, meaningful grouped tracks, scrub/seek/loop, camera reuse and follow/autoscroll work. Give the user a substantial preview and actual launch commands now; do not wait for every condition/provider.

### 2b. Mandatory all-spell safety sweep before deep VFX work

- [ ] For **every spell in the frozen engine inventory**, record a legal baseline cast and open/play its real journal through Studio. Include ordinary target/form branches needed to exercise its dispatch. Call Lightning, Chain Lightning and Lightning Bolt are explicit regression cases.
- [ ] Implement and run `live_all_spells_checks` now: actual player spell selection, hover/target, Preview, confirmation and result, including modal/choice ownership. Batch spells per session and report every ID; exercise free aim, item/created payload and multi-position/wall forms where applicable.
- [ ] Separate **safe execution** from visual completeness. Missing authored effect/input remains an explicit coverage gap while the real command/state still proceeds. Do not assert, invent substitute art, skip the spell, swallow an engine error or mark a failed recipe successful.
- [ ] Promote these checks into the real gate now. Retain their baseline cases for later package/provider regressions; Phase 5 adds full outcome/lifecycle/variant coverage rather than postponing safety.

**Stop A gate:** cohort works through seeks/loops/faction changes; schema-16 big map is playable; every inventory spell has Studio and live safety results with zero crashes, script/engine/resource errors. A recorder/setup failure is a failed gate with a reason, not “unsupported”. Source/provider/visual gaps are separately listed. Hand over commands, per-ID results, repeated equip proof and a bounded live door/move/Fireball frame/latency comparison. This does not claim all VFX are implemented or the final performance target met.

## Phase 3 — closed package, simple lifecycles and measured first use

**Files:** `assets/vfx/` metadata/text, `presentation/{effect_package,native_persistent,native_spell_renderer,native_spell_authoring}.gd`, condition/spell typed sources, actual preparation/media modules and timing tests.

- [x] Install the **whole closed package** under `assets/vfx` following the Factory contract. Current installed successor is `runtime-e102c29dec58524b`, published on the sole client branch; c494/candidate7fab/208 are historical. [Installation/publication evidence](FACTORY_RUNTIME_E102_INSTALLATION_2026-10-20.md). Preserve licence/provenance and binary backup; no overlay, client baker, concurrent-write overwrite or binary Git addition. This package gate does not qualify every provider or output.
- [ ] Select declared prepared-condition approaches without changing approved spell approach policy/Studio overrides. Keep separate condition-UUID owner clocks, selectors, suppression and application/hold/removal. Loop length is not expiry.
- [ ] Retain server-ID lifecycle lookup; audit cast→condition handover, `owner_spell`, applied condition/surface refs and `body_channel_included`. No double persistent art and no 155 manually enumerated clip keys.
- [ ] Prove simple lifecycles and first new examples: Chromatic Orb/Acid Arrow, then Hex/Hunter's Mark as actual bindings allow. Weapon/body/appearance examples wait for their shared Phase 4 capability. All missing/partial source entries remain explicit.
- [ ] Implement the measured warm policy below. Preconstruct the two approximately 2 ms acid treatments; reuse shared media/programs and actual actor inputs. Avoid all-155 startup admission.
- [ ] Re-run Phase 2b all-spell safety, the repeated equip gate and relevant package/lifecycle/native output checks after installation.

### Required surprise first-use measurement

- [ ] Use a real server action that first applies a condition **without player preselection**. Test an empty/short presentation queue as well as a backlog around two operations; operations are not a guaranteed time lead.
- [ ] Trace `packet received → preparation queued/start → media/instance ready → visible warm draw/pipeline ready → authored application cue → first visible frame`. Measure available lead, actual worker/main-thread/GPU costs, pipeline compiles and the cue/contact frame. No capture/readback in that measured window.
- [ ] Test cold capability residency separately from warm repeat. A hidden birth sample is not a warm witness; use meaningful actual application/hold geometry. Keep future authoritative state undisplayed during preparation.
- [ ] If readiness misses the cue or compiles in play, change the bounded policy: warm the relevant shared pipeline/known rig inputs earlier or preconstruct the affected occurrence class. Re-measure the same surprise case and startup/memory cost. Do not insert holds, drop/delay the real effect or broaden to an unmeasured preload of everything.

**Stop B gate:** closed-package provenance, correct simple lifecycle handover/removal/output, early new examples, zero safety regressions, and a timing report proving surprise first-use readiness (including the short-queue case) without visible compile/hold spikes. If not achieved, report the decomposed blocker; do not claim the warm policy works from constructor timings alone. Record the checkpoint and continue into the shared providers required by the complete handoff. Missing public inputs remain explicit gaps.

## Phase 4 — shared input cohorts, one at a time

**Files:** existing actor sampling/material/outfit/media modules, `presentation/{surface_sockets,character_geometry,body_sources,spell_placement,native_persistent,native_spell_renderer,effect_package}.gd`, associated source/case/tests.

Implement one shared cohort at a time; wire its actual inputs, apply them to every compatible selected manifest family, add real tracks/cases and qualify it before the next cohort. All required rows are authorized. Do not implement a generic framework first.

| Checklist / shared capability | First proof |
|---|---|
| [ ] Geometry/targets: one current pose packet (positions/normals/pixels/slots/origin/revision), shared source topology + private actor transform/identity; unchanged pose zero rebuild/upload | Film/contour on two actors using one rig, moving/turning/four camera views |
| [ ] Head/weapon/live anchors: actual recipient/head/hand, item UUID/holder/slot/hand; endpoints after root placement without double transform | Head marker, Vampiric Touch hand, Magic Weapon/Divine Favor coating; wrong/unequipped item draws nothing |
| [ ] Body material/logical pose: private layer revisions and per-owner treatment/capture leases, delivered stack composition, rebind and precise restoration | Barkskin/Stoneskin/Petrification/Steel with overlapping owners and ordered removal |
| [ ] Appearance/created item: Fly's Bag8 follows actual body clip/frame/facing; Flame Blade uses its real item/lifetime/holding | Move/view/outfit/remove; equip/drop/lifetime; no substitute body or arbitrary coated weapon |
| [ ] Actor history: real assembled colour + RGB24 reversed-Z depth and private actor context; authentic admission/departure on seek | Blur, Mirror Image actual duplicate count, Banishment current-view capture and original departure |
| [ ] Web spatial owner: actual admitted cells, suppression/disclosure, empty membership draws nothing; body Web separate | Cast/move/partial membership/caster hidden/removal |
| [ ] Event inputs: exact observed condition/source/stream/occurrence-lineage mapping, monotonic revision, mouth/contact/item data | Positive committed Tenacity damage; inactive/stale/wrong-owner cases; readiness only with public evidence |

**Gate per row:** actual application→hold→removal/restoration; concurrent owners/shared-rig actors; view/pose/outfit/equipment/suppression; seek/loop/teardown; native visible output, separate producer/setter/constructor/sample/first-draw cost, bounded cache bytes. Preserve all-spell safety and equip readiness. Missing public data blocks only its named variants. Follow the history/event contract in the appendix. Record each cohort's coverage delta and continue to the next required shared provider.

## Phase 5 — complete library and shared action/class dispatch

**Files:** `tools/studio_cases/`, one generated index/browser, typed-source coverage joins, `studio/README.md`, browser/replay/native/live tests.

- [ ] Extend action/class sources with the existing `PresentationEffectUse` resource list where needed. Build native package cues through one shared path with their actual action kind, actor/target/item ownership and authored action anchors. Never dispatch class actions as pretend spells or retain media-ID matching as the only package binding.
- [ ] Derive the full ID/requirement inventory and link cases from every subject. Keep one entry per capability, organized by authoring; four separate coverage facts (appendix), compact search/filter/counts and explicit unsupported/stale/failure reasons.
- [ ] Expand Phase 2 baseline spell cases to required outcomes/variants/upcasts, hold/removal/restoration and interactions. Cover action/class/item/environment/creature/surface families in the appendix; no generic “base actions” substitute.
- [ ] Finish actual body/material/appearance/history/VFX/audio/item/spatial tracks; group movement/missiles and hide routine exploration detail behind inspection. Complete readable horizontal scale/thumbnails, scrub/loop/follow, compact navigation and input isolation. Preserve single-faction default.
- [ ] Re-record the entire library with one command, at most two backend processes; exact original faction journals, factual moments and no silent skipped/retargeted steps. Retire stale wire-schema-9 cases, superseded browser ownership and dead code.
- [ ] Run browser uniqueness/reachability/status checks, all-spell safety plus expanded live variants, native multi-frame release/impact/removal/restoration captures and 1600×900 UI inspection. Report capture duration and requirement coverage, not only case counts.

**Gate:** every current ID discoverable with truthful source/scenario/presentation/approval status; one-command reproducibility; all required supported cases checked; no crashes/missing-resource errors. Deferred artwork, missing renderer capabilities and absent public inputs remain named incomplete work. Stop with a usable complete review tool, not a claim that all art was accepted.

## Phase 6 — final gameplay qualification

**Files:** existing live route/profiling tools, current relevant manifest gates, one implementation evidence ledger and user launch handoff. Use the existing profiling tools; do not start another profiling framework.

- [ ] Run `gallery_sorcerer` with **actual issued player commands**: startup→move→door→big room→first/later Fireball→reaction/condition→move/view/equip/remove/loot→idle. Add Phase 4 selected capabilities. Compare normal game and Studio without split rendering.
- [ ] Run three serialized comparable cold/warm trials, no competing GPU jobs; oracle dumps/readbacks outside the window. Emit exclusive client/server/transport stages, nested leaves and all long frames as specified below.
- [ ] For any regression, identify its actual component before changing code. Repair that shared owner/path and repeat the same case. Avoid unrelated renderer retuning or an open-ended optimization loop.
- [ ] Run the current build, relevant fast/native/live gates, repeated equip, fold/oracle and all-spell safety; update README/main handoff with exact commands, identities, user acceptance/gaps and measured limits. Clean up only owned test processes.

**Gate:** preserve event ordering/approved pixels, zero new errors, no holds, and the user's **100+ FPS steady game/Studio with no client-caused first-use/impact/reveal freezes**. Report p50/p95/p99/max and each spike's decomposition; averages do not qualify bad frames. If a target remains unmet, hand over the exact blocker and do not declare performance complete or silently expand the selected work.

## Reviews, progress and commits

- During implementation, use **one bounded plan-adherence sub-agent per active execution chunk**, with a concrete deliverable/gate to track, then finish it. No standing polling/review loop or permanent four-agent team.
- At phase boundaries use short read-only **anti-slop** and **correctness/anti-OOP** passes on the changed paths and evidence. Reuse reviewers; condition expertise is part of the relevant correctness pass. Do not re-audit the full repository after each small edit. Same-task agents only, no other-chat reads/messages.
- A phase ledger row records `not started / active / passed / blocked`, commit, commands/report paths, gate results and next stop. The linked execution ledger records the committed canonical base and active B/C integration. Checkpoints are not scope limits; every unsupported provider and unqualified output stays named.
- Original read-only reviews found the ordered pre-row condition capture and authentic admission/departure seek requirements; both remain mandatory below. Short correctness/anti-OOP and anti-slop passes reviewed this revision on 19 October: **ready, no required changes**. These are planning reviews, not implementation/test results or visual approval.
- **This planning change:** commit this file and the main handoff pointer together, with explicit paths. No application/asset changes or Godot runs belong to this revision.

## Appendix — contracts, rationale and evidence

### A. State, ownership and authoring

`native journal → canonical fold + immutable transition cuts → compiler → preparation → ordered timeline publication → Play/world/actors/effects/audio/UI` is the only path. Server owns rules/IDs/targets/outcomes/disclosure/lifetimes; SDK owns fold/journal/cursors; compiler/timeline owns derived native-linked presentation cues; typed sources/build own body/pose/look/audio/staging bindings; Factory owns finished effect programs; Play owns actual optical/material/pose inputs and private instances; Studio observes this same path.

Prepare immutable/static resources from selection or received queued events, but never publish future bodies/items/conditions/visibility. Fold world before facts; preserve group/lineage/occurrence/cancellations. Cue linkage retains actual actor, condition/item UUID and cast. Later rows cannot mutate earlier cuts. A removal's UUID alone is insufficient: transitions preserve its pre-row member, including transient remove→reapply; duration-only updates make no new application/removal. Same journal prefix must yield the same state live, on seek and on loop.

Use the existing Godot-native sources `authoring/{characters,environment,abilities}.tres`, one entry per concept, built by `tools/build_presentation.gd` into `build/presentation/*`. Validation and coverage run there/tests, not per frame. Do not restore deleted JSON presentation importers, `.derived` fallbacks or duplicate authoring. Wire/journal/index/manifest JSON is still appropriate. Reuse physical sheet/pose sources across all knights and concurrent conditions; immutable shader/mesh/texture data shared, mutable owner clock/material/history private. Caches stay bounded in existing preparation/media ownership, not a new registry.

Read-only inventory observed 189 spells, 235 conditions, 119 public actions, 232 creatures, 246 items, 162 environment objects and 67 spatial effects. Refresh against the frozen export; counts are not permanent scope constants. Review consolidated Multiattack/Help/Shield Bash/Protection/new traits/coatings, `encounter_end`, item facets and premade hero aliases. Actual current inventory/code wins over those example names and old schema-15 snapshots.

Fold proof: all world w1–w14, sensory v1–v8, bodies v1–v9 and groups g1 vectors, plus reference error cases. Multi-seat spools use `devtools/performance/gallery_transcript.py` and `seat_oracle.state_data`, comparing **every record**, including memory/member bits/items/static stores/cursors. Test fresh `after=0`, same-attachment resume, duplicates/backfill, multi-actor condition rows/remove→reapply/duration update, free aim, per-member restrictions and ordered wall/multi-position requests. Historical passing numbers do not qualify this schema.

### B. Package, selection and actual providers

Current installed complete successor: **`runtime-e102c29dec58524b`**,1,246clips/504selections/155lifecycle families, committed as `ad26e594`. [Whole-package installation evidence](FACTORY_RUNTIME_E102_INSTALLATION_2026-10-20.md); [current finite provider checklist](SHARED_PROVIDER_COMPLETION_CHECKLIST_2026-10-20.md). It includes the newer weapon delivery and corrected actor-history shader sources;87additional weapon clips remain unassigned and220new approaches do not change selected defaults. All three history modes now have qualified native output; this is separate from final live/gear-transition/visual acceptance. c494,208,the7fab candidate and the earlier inspected weapons5dc archive are historical inputs, superseded by the whole e102installation. Their earlier two shader failures no longer block current native history. Do not reinstall an old package because an earlier checklist or historical receipt names it.

Historical candidate archive: `/mnt/c/Users/tommaso/Documents/assets/VFXFactory/.runtime/condition-deliveries/conditions-candidate-7fab471588209a41/vfx-conditions-candidate-7fab471588209a41-complete.zip`, former implementation commit `f917f382`. This is provenance only, not the current installed namespace or checkout. Current whole-package code/text/metadata is published on the sole client branch, binary resources remain ignored, and all runtime dependencies are project-local; no Factory importer/baker or pinned fixture renderer.

Candidate accounting: 155 lifecycle families (154 condition + one spatial Web), 465 application/hold/removal roles; 147 exact creature/item IDs, one spatial owner, nine canonical-child delegations, 32 internal/client/no-art records. The 46 deferred environment records (39 environment, five spatial leases, two Tile) are not completed body effects. There are 131 directly sampleable families and 24 requiring history/events (three history, 21 events). Factory's 6,258 passing checks/closed dependencies/isolated warm figures are delivery evidence, not production integration, crowded-map performance or user approval.

`effect_package.gd` keeps make/set/sample/warm/clock/place/cleanup; prefer the declared `condition_prepared` / `gpu-prepared-condition` approach only for conditions. Preserve spell policy and Inspect override. `native_persistent.gd` keeps UUID-owned lifecycle clocks, selectors and markers, adds spatial-owner lookup. Audit `native_spell_authoring.gd::owned_cues()`/body-channel handover. The original baseline setter bridge supplied only `owner_state` and `root_path`. Current geometry, item/weapon, optical, material, event and spatial providers are implemented/qualified in bounded cohorts recorded in the linked execution and qualification ledgers; remaining unavailable operands stay explicit. `spell_placement.gd` uses actual head/hand/weapon owners; fixture coordinates, first actor/weapon, independent wing timing and substituted bodies remain invalid shortcuts.

Use current positions/normals/pixels/slots/origin/revisions for body geometry; shared topology keyed by source/pose, actor identity/transforms private. Current materials/layer nodes are actual body treatment inputs; pose/appearance leases release only their owner and rebind on view/outfit/material changes. The delivered stack's limit is tested/reported, not replaced with an invented cap. Missing/ambiguous/suppressed target/item hides that specific adaptive cue and stays a coverage gap; this is not permission to discard an otherwise valid late effect for performance.

Authored variants: Chromatic Orb/Acid Arrow first; Hex/Hunter's Mark, Magic Weapon/Divine Favor, Starry Wisp/Faerie Fire, Flame Blade/Flaming Sphere follow their actual provider availability. Existing build labels were partial. **Aid, Bless, False Life and Sacred Flame remain not visually accepted**, and unresolved timing/placement flags survive installing new art. Shipping/export repacking, engine optimization, new map editor, replacement VFX artwork and deferred environment art are separate scope.

### C. History/event inputs and public-data gaps

Do not unconditionally jump a sustained effect straight to owner age in `native_spell_renderer.gd`. Direct sampling serves stateless approaches; rebuild actual observed prehistory for stateful ones. Blur's rolling window differs from Petrification admission/Banishment departure, which may be minutes earlier: recover the original faction-prefix admission or authentic retained capture checkpoint, not a pose captured at seek time. Already-held recordings lacking that evidence have an explicit unavailable-capture gap. Banishment logical departure revision/origin remain separate from current-view optical capture revision/layers.

Bind event owner condition/source/stream independently. Map actual native occurrence/lineage to package serials explicitly, with monotonic observation revision and real phase/owner time; do not invent UUIDs. Valid inactive packets retire their exact event even when fields clear; wrong-owner/stale packets cannot poison cursors or resurrect accents. Reset stream generation only for a real seek/replay reset. Tenacity needs actual positive committed damage, event identity/lineage and current contact region. Readiness requires factual active observation, item/mouth region and revision, not reconstructed free-action/Multiattack rules.

| Required input/selector | Public/optical source or explicit gap |
|---|---|
| `duplicate_count`, `size_change`, `energy_type`, `affected_item_uuid`, `enhanced_ability` | Public `ConditionState`, actual owner UUID |
| Pose/geometry/head/hand/material/history/item surface | Current observed renderer, public body/item identity |
| Outcome/item/applied damage/type/source condition | Actual disclosed `AttackFact`/`DamageResultFact`; prove exact occurrence/lineage and field mapping per family |
| `aura_kind`, condition-selector `damage_type`, `breath_type`, `prerequisite`, `action_id`, `issued`, `free_action_uuid`, `granted_lineage`, Petrification stage failure count | Absent from current public `ConditionState`; verify whether a real public event supplies each requirement. Otherwise record affected variant/input and precise server/Factory handoff. No private engine reads or inference from names. |

Keep one input→public field/event→optical provider→status mapping beside source/build/tests, derived from package requirements. No second contract database or silent new protocol/disclosure authorization. Missing authority blocks its variants, not unrelated work; all-155 production completion is not claimable until those inputs exist. Native conservative submitted bounds do not prove visible pixels: capture actual changed output/restoration outside measured gameplay windows.

### D. Studio case and track requirements

One library: spells by level/school; conditions/actions by family; interactions; characters/creatures; environment; surfaces; items. Four independent facts per ID: **source/binding**, **scenario/outcome/variant**, **actual presentation/provider/output**, **user visual approval**. State-only/internal, stand-in, offscreen, incomplete and accepted are not interchangeable. Every ID appears once; a multi-subject case is reachable from each subject.

Retain the handoff's version-1 index: engine identity/commit/digest, `engine_ids`, cases with id/kind/subjects/journals/moments/status/reason/seed/scenario/`studio_checked`/errors. `record.py --engine <export> [--only kind|id|case] [--out …]` retains exact original journals for both factions. Scenario data declares legal setup, roles, commands, actual expected outcome and real removal. Use bounded deterministic seeds, no silent nearest-target substitution or omitted decisive step. `engine_unsupported` means truly absent from the frozen engine, not missing art or failed setup.

| Family | Scenario requirements beyond Phase 2 baseline |
|---|---|
| Movement/base/class actions | Modifier before/after speed/budget; doors/corners/stairs/elevation/connectors/windows where supported; jump/land, shove/fall, dash/dodge/disengage/hide, prone/stand/help, extra attacks/action surge |
| Combat/reactions/survival | Hit/miss/critical, damage/hurt/death ordering, resistance/immunity/vulnerability, opportunity interruptions, Shield melee/ranged/Magic Missile, Counterspell/Hellish Rebuke/Protection/Parry/smite; heal/temp HP/death saves/stabilize/revive/shake awake |
| Spells/conditions | Cast/application/hold/move/actual end/restoration; concentration drop/break, suppression/disclosure, repeated and overlapping owners, applicable variants/upcasts; actual hide removal rather than an invented bright-light rule |
| Spatial/construct/item/summon | Cells/sections/boundaries, multi-position walls/Blade Barrier/Forcecage, elevation/traversal/destruction; Flame Blade, Spiritual/Arcane Weapon or Sword, Flaming Sphere, delayed/freezing payloads, summon attacks/despawn and real item/control owners |
| Environment/surfaces/creatures | Doors/chests/loot/torch/levers/traps/equip/coatings; actual oil/fire/water/ice/electric/web/cloud transitions; every creature appears/moves/attacks/takes damage/dies, shared sources and explicit stand-ins |

Library completeness is requirements→cases, not every combinatorial pair or one random replay per ID. Sources without rendering, deferred environment effects and missing connectors remain inspectable named gaps, never invented client outcomes. Both actual faction journals reduce independently; default one preview and faction toggle, no revived split-screen cost or leaked hidden identity.

Timeline: substantial preview; resizable lower pane; meaningful horizontal seconds/clip thumbnails cached on disk/resources; actual recipient/body/material/appearance/history/VFX/audio/contact/item/spatial/important light operations. Group movement samples/multi-projectile deliveries; routine exploration/light behind inspection; no pages of empty bars, undisclosed spam or fake timed missing effects. Correct audio waveform/playback uses the same authored cue/resource/contact markers. Working selection/playhead/seek/loop/bounded lead-tail/follow/autoscroll; camera reuses tracks; divider/modal input cannot zoom or command the map. Ready-case switch remains about one second or better, measured separately from cold startup.

### E. Performance/qualification evidence

Historical quiet 18 October medians: door packet→animation 61 ms (56–63), movement 50 (49–75), Fireball first 49 (48–66), second 51 (33–57); zero door/move holds, idle 7.2/9.9 ms p50/p95. First Fireball still had a 36–43 ms pipeline frame in two runs. These are comparison evidence, not current-schema qualification. Preserve shared media, incremental draw order, worker preparation/main-thread publication, GPU light/receiver work, COW and retirement. Prepacked-sheet benchmark savings were not a completed production migration.

For each live slow action record exclusive `selection/click→Preview→submit→server execution/projection→transport→decode→fold→compile→resource preparation→publication→first visible→contact/removal→choices/UI`. Separate server-reported from queue/network/unattributed time; do not double-count nested/overlapping work. Decompose slow stages into actual leaves: unique source hit/miss/decode, pose producer/setter consumer, constructor/warm/first draw/pipeline, world build/attach, UI and retirement. Report p50/p95/p99/max/all long frames, startup-to-interactable/case-switch, GPU residency/cache/pose-vs-actor counts and teardown residuals. Factory constructor numbers alone prove none of these.

Warm meaningful actual inputs: Web after growth; exact Fly rig/clip media; real actor-history context. Surprise event queue lead must be measured, never assumed; selection/backlog is an opportunity, not a guarantee. No per-frame validation/readback, all-library preload, clock hold or effect dropping to hide a late preparation. Fix costs in their actual shared owner and preserve ordering/pixels.

Run relevant current fast/native/live gates, not only manifest defaults; preserve named unrelated failures instead of claiming universal green. Zero new failures, script/engine/resource errors. Investigate Factory's known combined-fixture 21-instance shutdown warning through production repeat create/remove/seek/loop/teardown: neither assume a client leak nor ignore an actual one. Hand off exact identities/commands/gaps/rejected art/performance; leave no owned test process keeping the PC awake.


## Immediate weapon-authoring cohort — user clarification, 19 October

The user prioritizes the authoring structure, shared renderer and Studio tracks
before requesting corresponding Factory effects. All wielded bodies remain
sprite sheets. Native wielded weapon-body replacements are rejected. Begin with
modular characters' separate weapon layers; full authored-character weapons are
baked into their sprites and their attachment support is deferred. Spiritual
Weapon is a separate summoned actor, not an equipped weapon substitute.

- [x] Preserve each item's existing sprite family/body and add typed `Gear.effects`
  using the common EffectUse resources. Compile to the existing body source index;
  do not introduce another registry or runtime JSON loader.
- [x] Reuse NativeItems/Timeline for independently keyed attached uses, with real
  item UUID plus authored Resource locator; never invent a condition/effect UUID
  or require creation ancestry for an ordinary existing item. Share change-time
  membership work across effects, with live current modular weapon geometry.
- [x] Conditions retain temporary enchantment/buff lifetimes; spells/actions retain
  finite cast/contact cues. Intrinsic effects belong to actual item membership.
  Unequip, replacement, transfer and loss of disclosure cannot coat another item.
- [x] Expose each actual use and its input/source/channel in Studio, preserving
  independent uses on one item, seek/loop, and truthful unsupported inputs. No
  manufactured application event for an item already present at replay start.
- [x] Qualify base sprite preservation, multiple private uses, actual journals,
  seek/loop and native receiving pixels with existing delivered coating sources
  in test-only staging. No new unaccepted production artwork assignment.
- [x] Then write the Factory handoff with the executable Resource example,
  ownership/input contract, output locations and named backend data gaps.

Gate: affected headless/native checks with no script/resource errors; current
ordered publication/approved lighting unchanged. Plan-adherence, antislop and
antiOOP review are short passes at this cohort boundary. Do not expand into a
native mesh/body system or baked-in weapon segmentation.


Cohort receipt: implemented in the private worktree, not published through the
failed actor-context candidate. The bounded held-modular contract and executable
Factory handoff are in `MODULAR_WEAPON_EFFECTS_FACTORY_HANDOFF_2026-10-20.md`.
Nine affected gates passed, then the actual-draw child-witness regression passed
24 ownership/22 native checks. Offhand, baked-character/dropped-item support,
full transfer and final performance remain explicit gaps; the checked cohort
means the structure/render/Studio contract is ready, not that those variants or
all art are complete.


## Weapon on-impact arm — user addition, 20 October

- [x] Add `Gear.impact_effects: Array[EffectUse]` beside sustained `effects`.
  Keep one compiled body index and all existing weapon sheets.
- [x] Emit each authored impact once from the actual Hit/Crit AttackFact with
  exact source_item_uuid/item_id, source/target and attack occurrence/lineage.
  Use the existing track impact marker (melee contact/projectile arrival), not
  every damage packet. Zero-damage contacts remain hits; no damage is invented.
- [x] Reuse native finite phase compilation, component preparation, rendering,
  event hierarchy and Studio rows. No persistent item clock or second scheduler.
  Creature body placement first; missing object/contact/result inputs stay named.
- [x] Verify real two-faction attack recordings, miss/cancel/unknown-item
  boundaries, finite timing, Studio parent/source and native pixels/seek/loop.
- [x] Update the same Factory handoff and executable Resource example with the
  split sustained/impact fields and actual event packet. Keep source admission,
  art approval, backend rules and native lights separate.

A short plan-adherence/antislop/antiOOP review owns this bounded addition. No
engine/Factory writes or new damage logic. Temporary condition/rider attribution
and hit material/audio specializations remain separate, not fabricated inputs.

Cohort evidence: the seven affected gates pass 226 assertions with no
script/resource/engine errors (`.runtime/tests/20261019T222437Z/`). The real Amber
killing hit proves detached contact retention after visual retirement; Blue is
independently reduced. The bounded plan/antislop/antiOOP review found no remaining
material blocker. Test-only fire artwork is not a production assignment or visual
approval. Details and Factory delivery instructions remain in the same modular
weapon handoff.


## Consolidate and restore the complete suite — user priority, 20 October

The user explicitly requires all work in the main client and a passing full
suite regardless of when a failure arose. This supersedes private candidate
publication/selected-only stopping rules above.

- [x] Consolidate committed implementation and check every secondary worktree for
  unique work. Keep one active branch, `codex-authoring-schemabump`, in
  `C:/Users/tommaso/Documents/Dev/NDClientGodot`. Preserve historical evidence;
  never blindly reintroduce obsolete APIs from an older branch.
- [ ] Repair shared suite causes: real schema16 recordings/independent oracles,
  current native Resources and renderer contracts, genuine runtime defects.
  Preserve each observable assertion, event order and approved graphics. No
  skips, status downgrades, invented events or relaxed checks to make green.
- [ ] Run the complete executable test inventory from main: full fast first,
  then native/GPU and live lanes with actual required inputs. Replace retired
  tests only with documented current behavior coverage. Source errors in the
  merged actor-context path are part of this work, not a private exemption.
- [ ] Commit the fixes in main and update the main handoff with exact commands,
  complete pass/failure counts and remaining incomplete capabilities. Leave no
  owned Godot/backend process running.

Delegation: one plan-adherence/antislop/antiOOP reviewer; one worker for authentic
recording-based tests; one worker for stale test/runtime contracts. Root owns
consolidation, common production/Studio blockers and final serialized validation.
Initial evidence is the113-test fast run with57 failures; pre-existing status
is not an exemption. Gate: zero failing executable tests, script/resource/engine
errors, and working normal player/Studio smoke tests on the single main branch.

20 October repair progress: consolidation committed at `7ef2f3f8`; one local
branch and main checkout remain active. Authentic schema16 fixtures and independent
SDK/pre-cache oracles replace retired wire assumptions. Native wall/source and
private callback ownership defects are repaired. Shared passive metadata admission
passes24 concurrent cold tasks and immutable fixed-path reload checks; no pool
child wait, GPU readback or runtime validation is added. The full executable
inventory is not yet qualified; final fast/native/live receipts and the deferred
two-error Factory actor-history gate belong in
[the current repair ledger](MAIN_CLIENT_SUITE_REPAIR_2026-10-20.md).

## Parallel completion lanes — user direction,20 October

After consolidation, keep functional integration moving independently of suite
repair. Root owns shared production providers and integration; one worker owns
compatible typed Factory bindings/per-ID gaps; one worker owns genuine original
server scenarios/capability coverage. A bounded reviewer checks plan adherence,
anti-slop/correctness and ownership at cohort boundaries. All edit disjoint files
in the single main checkout/branch; root commits coherent checkpoints. No external
chat or extra branch is necessary. Native GPU runs remain serialized.

Next shared producer: actual committed-damage outcomes through the existing
`ApplicationResults`→finite constructor/component/Studio path. Preserve actual
source/recipient, positive applied amount/type and native occurrence/lineage;
use declared damage-type filters and actual ancestry. For the finite divine
consumer's opaque `damage_component_uuid`, the disclosed applied-result occurrence
string is its exact identity, just as existing `event_uuid` uses native occurrence
strings. This does not expose a new wire UUID or qualify passive/rider attribution.
Gate: original two-seat damage recordings, canceled/request/zero/foreign-source
controls, unchanged canonical rows, exact constructor operands and native source
consumer when its legal case is available. No new scheduler or runtime validator.
