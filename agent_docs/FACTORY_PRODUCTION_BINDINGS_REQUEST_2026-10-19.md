# Factory work available now — production bindings and remaining artwork

19 October 2026. This is work the Factory author can start while client integration continues. It covers the complete delivered spell, condition and class library, rather than a special repair for Haste. It does not authorize replacing the client's renderer or changing game rules.

## Where to work and deliver

- Factory source root: `/mnt/c/Users/tommaso/Documents/assets/VFXFactory` (`C:\Users\tommaso\Documents\assets\VFXFactory`). Edit canonical recipes/components/packaging there.
- Client implementation under review: `/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot-authoring-schema`, branch `codex/schema16-unit-a`. The main `NDClientGodot` checkout has **not** received these changes. Read either checkout as needed; do not write into its package, generated build or client code.
- Current installed closed delivery: `conditions-candidate-7fab471588209a41` — 1,149 clips, 497 selections, 155 lifecycle families. Preserve this release unchanged.
- Save the receiving handoff at **`/mnt/c/Users/tommaso/Documents/assets/VFXFactory/docs/NDCLIENT_PRODUCTION_BINDINGS_HANDOFF_2026-10-19.md`**. Record exact selection/clip IDs, public construction/input contracts, corrected source paths, remaining limitations and reproduction commands.
- Deliver a **new complete closed package**, using the existing Factory release process, at **`/mnt/c/Users/tommaso/Documents/assets/VFXFactory/.runtime/condition-deliveries/<new-delivery-id>/vfx-<new-delivery-id>-complete.zip`**. Include the normal index, delivery metadata, dependencies, licences and provenance. All runtime dependencies must resolve within `res://assets/vfx`. Give the exact archive path in the handoff. The client will stage and replace the whole package when its tests are idle; do not overlay the running client.

The authoritative client target is protocol 1 / player schema 16, frozen engine commit `211b71134ed15c89e62232587381f7e15a5961c3`. The production engine checkout has concurrent work and must not be modified or used for Factory test execution. No additional checksum ceremony is requested beyond the existing release checks.

## 1. Make production construction operands explicit

This is the most useful shared work. Several exported phases are review choreographies: their constructors fix example owner/actor/event UUIDs and outcomes. Later setters correctly reject actual gameplay packets because those packets do not match the construction fixture. Relabelling a real surface's actor UUID to `target`, copying review damage/save results, or mutating a live node's private settings is not an integration.

The source APIs already support `make_component(input)` / `create(input)`, public phase `to_clip()` and source construction from component input data. Their art does **not** need rewriting. The client can implement preparation-time operand projection through those APIs. Re-export is not intrinsically necessary for every affected source.

Please publish the smallest explicit supported contract for those existing APIs, and where useful export a production-neutral wrapper/template. For each affected selection, document:

- Which component input members accept actual immutable construction operands; their types and meaning; which public setter owns later changes.
- Actor role versus actor identity: a logical `target` role must bind an actual UUID without falsifying that UUID in geometry/material/history packets.
- Whether a piece runs once per cast, once per **actual application/recipient**, or for an actual condition/item/spatial owner. Export a recipient template separately from an example three-recipient demonstration when these scopes differ.
- Which values are immutable art settings and which are required native identities/outcomes. Missing required native evidence must not activate an embedded successful fixture.

Use the existing package metadata and public entrypoints where possible. This request does not prescribe a new universal DSL, runtime registry, JSON validation pass or replacement effect manager. Keep exported Resources immutable and mutable occurrences/materials private per world and owner.

### First proof: Circle of Death

Canonical source: `factory/components/recipient/circle_receiving_contact.gd`; installed equivalent: `assets/vfx/sources/566cb4376a3c708e14a2/circle_receiving_contact.gd`. Its receiving surface actor must equal `parameters.application.target_actor`.

Concrete delivered clip: `review/circle_of_death/whole/circle_of_death__whole.receive_target`; phase `res://assets/vfx/sources/7bb27289f693c781f1c9/ee957c7866a74c60.tres`; pinned wrapper `res://assets/vfx/clips/414e9976156620ed2a5e2f73/construct.gd`.

The receiving constructor requires actual `application_id`, `target_actor`, `damage_applied`, `save_succeeded` and `damage_type` (`necrotic`). The real client Circle baseline contains **four** application/target UUID pairs, real saves and applied damage **31 / 15 / 31 / 31**. These facts are already available. There is no need to ask the engine for a new damage result.

The package contains three review receiver templates (`caster`, `target`, `target2`); their component input data is equal after removing `application`. Export/document one reusable receiving template. Keep the ground effect once per cast, and construct one receiving instance for each admitted native application. The initial client area binding emitted the three review receivers once. It has now been replaced by one explicit cast-scoped ground cue and one application-scoped receiving template expanded for each real recipient; the initial fixed construction identities are no longer used for this case.

Client evidence: `.runtime/studio-library/cases/spell.circle_of_death__baseline/20261019T142214.366493Z/amber/journal/0000000000000008.json`. The initial safe migration marked the three unusable review receivers as missing. The continuing client work replaces those aliases with one explicit application-scoped template and projects real application/save/damage operands before public source construction. **72 focused checks pass** against that journal, including one ground effect/four receiver occurrences, private constructor data, real warm-plan operands, event-time actor contexts and unchanged canonical final state. Actual-command run `.runtime/schema16-live-constructor-r8/` observes all five effects presented without script/resource errors (ObjectDB exit warning retained). User approval and cold/short-queue first-use timing remain separate gates. The adapter is `presentation/native_constructed_occurrence.gd`; the factual join is `presentation/application_results.gd`. The client owns this work; Factory re-export is not a prerequisite for this case.

### Sweep the same boundary across the library

The client's offline inspection inventory is `.runtime/factory-construction-operands-review.json`: 828 textual phases inspected, 69 binary phases not inspected by that static pass, 72 constructors / 310 unique **candidate** clips with identity/outcome operands. This is not a claim that 310 clips fail. Inspect the actual public initialization/setter contract before classifying a source as blocked. Binary Resources need public `to_clip()` inspection too.

Start with shared constructors, then list affected exact IDs. Cohorts include Charm/Continual Flame/Dancing Lights/Faerie Fire owners; weapon coatings and triggered strikes; Flame Blade/Goodberry/Flaming Sphere created objects; Dragon's Breath/Glyph outcomes; aura/lease recipients; delayed or held projectiles; summons; spatial owners; Counterspell outcomes; Rage/Frenzy; and the divine studies below. The full client [coverage and constructor inventory](FACTORY_INTEGRATION_COVERAGE_2026-10-19.md) identifies concrete fields and sources.

## 2. Fix the Guardian of Faith source error

Canonical source: `factory/components/fields/guardian_blade_arc_trail.gd`, `_refresh_response`, currently line 72. The real native run reports three ScriptErrors reading `history_observation.source_frame`. The override calls its parent, then assumes the observation has `source_frame` and `strike_frame` when its mesh is visible.

Inspect the parent history/response lifecycle and distinguish an initialization/rewind bug from a genuinely absent required provider. Correct the source lifecycle or declare its required input explicitly. Do not delete the assertion, fabricate historical motion or claim an unobserved response happened. Cover initial sampling, non-monotonic seek, held frames and history gaps. Evidence is under client `.runtime/schema16-live-all-spells-final-r4/` with its `godot.log` and Guardian case result.

## 3. Class and divine programs: actual owners, held lifetimes, outcomes

The client has bound eleven existing class actions to fourteen exact Factory cues, using the ordinary action/attack occurrence path. That is not complete class coverage.

**Rage/Frenzy:** their current owner projection requires a finite observed removal while a live owner may still be held. Support an actual active owner with no observed removal yet, then its real suppression/removal. Do not require a fabricated four-second expiry. Frenzy's parent-condition UUID is absent from public ConditionState; keep that named selector gap rather than assuming parent identity.

**Divine studies:** 23 selections / 46 unique clips remain available for proper integration. Twenty-two selections (43 clips) declare lease/event/visibility inputs; Sacred Weapon's three clips use exact weapon binding. Their reusable constructors must receive actual source/recipient/owner/event IDs before admission, instead of comparing production setter packets to review fixture IDs. Keep hold/removal on the already delivered condition lifecycle; do not duplicate it with an action-duration effect.

Exact selection-to-native mappings and all branch details are in the [divine appendix](FACTORY_INTEGRATION_COVERAGE_2026-10-19.md#additional-divine-class-studies--proposed-bindings-not-active-defaults). The work includes:

| Program group | Required distinction |
| --- | --- |
| Turn Undead / Turn Unholy | Cast/radial release versus each actually applied Turned owner. |
| Preserve Life / Lay on Hands / Cleansing Touch | Actual positive healing or accepted removals; lesser/greater/cure are real chosen forms, not amounts guessed from healing. |
| Destroy Undead / Blessed Healer / Divine Strike / Improved Divine Smite | Actual `effective_handler` attribution and emitted damage/heal lineage. These passive features are not invented ActionFacts. |
| Divine Sense / paladin auras / Holy Nimbus | Existing condition-owner lifecycles; exact aura selector where publicly available; Nimbus contact only from real damage. |
| Divine Intervention branches | Actual damaged, living-healed, dead-revived, created-item or created-container results. Dead revival is a committed life change and need not supply a positive HealFact. |
| Devotee's Mace / Sacred Weapon | Actual item UUID, holder, slot, suppression and removal. No first-held-weapon fallback. |

The passive IDs are `class_feature.cleric.destroy_undead`, `class_feature.cleric.blessed_healer`, `class_feature.cleric.divine_strike` and `class_feature.paladin.improved_divine_smite`. The action definitions and effective-handler attributions exist in the frozen engine. The old study matrix's claim that native IDs were unavailable is stale; update that documentation.

Additional public-input gaps remain explicit: paladin `aura_kind`; Frenzy's parent condition link; draconic `breath_type`, `issued`, `free_action_uuid`, `granted_lineage`; replay-safe Lay on Hands form retention. Do not fill them from names, proximity or review choices. The client will handle actual public projection/branch retention on its side.

## 4. Created item appearance: Flame Blade and the mace

Flame Blade's actual created item and lifetime exist. The client gear source `authoring/characters/gear/weapon.flame_blade.tres` explicitly says **“No worn look authored.”** Its inventory icon is not a held weapon visual. The prepared Factory treatment expects the real item/current weapon optical geometry and cannot create that missing publication by coating an unrelated sword.

Please supply the reusable created-weapon visual/appearance or document the supported native item-presentation source and exact optical/material binding. Preserve actual item UUID, caster versus holder, slot/hand, equip/drop/suppression and lifetime. The same missing-worn-look distinction applies to `weapon.devotees_mace`; keep it separately named.

Relevant canonical Flame Blade sources:

- `factory/components/fire_conjurations/flame_blade.gd`
- `factory/components/conditions/fly_flame_solar/flame_blade_source.gd`
- `factory/packaging/fly_flame_solar/condition_flame_blade.gd`
- `factory/packaging/fly_flame_solar/prepare_flame_blade.gd`
- `authoring/bg3-36/flame_blade_native/`

For Flaming Sphere / Spiritual Weapon, distinguish their actual effect-owned entity from an ordinary rigged creature. The client now has explicit effect-owned body authoring; do not provide a humanoid stand-in. Document the effect's actual entity anchor, motion, existence owner and teardown contract. The former Spiritual Weapon preparation stall was fixed by that client body policy and its actual-command run now passes; this is not a request for fabricated Factory state.

## 5. Artwork still awaiting user acceptance

**Aid, Bless, False Life and Sacred Flame are not user accepted.** Package completeness and successful construction do not change this. Preserve that status in the handoff. Timing/release sockets/placement across spells also still need tuning and user review.

Prior feedback: distinguish a finite cast accent from a restrained persistent treatment; use the actual body/material/surface instead of a large cage or dome. Aid/Bless/False Life need further work. Sacred Flame's cantrip scale, dark base and untextured yellow base remain rejected. Cast-hand magic layers are distinct from a full caster aura. Do not blanket-add light, substitute unrelated artwork or mark old screenshots as acceptance. These art iterations can proceed independently after the production-source fixes above.

The approved rendering baseline stays Windows Godot Forward+/Vulkan, a 3D world with native 2D lights/normals, the existing light cap, tint, wall modes and sorting. Decorative VFX emission is not a gameplay light. Strip or explicitly mark donor lamps that are not optical emitters; do not add a replacement lighting system. Finger of Death's zero-emission donor light is already handled on the client and is not a request to retune it.

## Client work that remains on the client

Do not spend Factory time implementing a replacement for these providers:

- Actual entity surfaces, body-layer/material revisions and actor transforms; exact authored hand/head endpoints.
- Item/holder/equipment providers, created-item admission and Bag8 appearance leases.
- Actual rolling colour + RGB24 reversed-Z history, logical pose capture and original admission/departure evidence. Current geometry at seek time is not historic evidence.
- Actual owner/source/stream/occurrence-lineage event projections, monotonic revisions, contact/mouth regions and readiness.
- Scope-aware expansion and construction operands from the canonical reducer's actual applications/results; independent world ownership, ordered publication, Studio tracks and missing-work reporting.

Factory should state the precise public contracts those providers consume and keep examples clearly separate from production inputs. No need to recreate rules or access private engine state. The current client coverage report separates available source, missing provider, missing scenario, native evidence and user visual acceptance.

The [client weapon-provider cohort](WEAPON_PROVIDER_COHORT_2026-10-19.md) now covers exact item/holder/slot/optical binding (44 new + 52 existing focused checks). For the supported schema16 contract, active Antimagic suppression was retired; prepared consumers use suppressed=false unless an explicit observation overrides it. Do not request that retired field as new server data. Legacy contribution/decoration initialization is a separate unresolved adapter, not a universal wire requirement. Frozen Magic Weapon/Sacred Weapon effects do not publish item membership through `snapshot_item_effect`; that is a server producer gap, not missing Factory art. Offhand registration and created-weapon worn looks remain separately named.

## Completion evidence

Batch the normal source/package validation after meaningful changes. For changed construction contracts, test arbitrary actual actor/owner IDs (including two recipients sharing one rig), wrong-owner input and clearing, held owner without a known end, ordered removal/reapplication, missing required input, seeking and cleanup. Confirm one cast-wide piece stays once and recipient pieces match actual applications. Validate native pixels separately from a setter returning successfully; preserve known warnings and untested contracts.

Use serialized GPU runs and the existing Factory test/release tools. Do not modify a package being tested by the client. The final handoff should identify which requested items were completed, which exact IDs changed, how the client invokes them, remaining source/provider/art gaps, and the complete ZIP path. No other-chat messaging is needed; the user will deliver this file and bring the response back.
