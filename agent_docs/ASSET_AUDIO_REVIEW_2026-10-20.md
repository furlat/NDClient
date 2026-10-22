# Asset and audio review: actual omissions, stand-ins and pending review

20 October 2026. Forward this file to art/audio ownership. Client work continues
in parallel. This inventory does not approve artwork or turn every internal
placeholder into a requirement for a new image. No artwork is imported or moved
by creating this document.

## Missing files versus incomplete assignments

The last executed offline image inventory reported **zero missing assigned
image files and zero shipping-map mismatches** for 189 spell icons, 232 creature
portraits and 432 selectable player portraits. Its 103 generic icon placeholders,
53 portrait stand-ins and 63 body stand-ins are historical receipt populations,
not a current new-asset count. The later source assignments below have not
rerun that whole inventory, and source status does not constitute acceptance.

That original inventory was exported with `tools/run_checks.sh tools/ui_art_coverage.gd`.
[Machine-readable exact owners and paths](../generated/reports/ui-art-coverage.json).

## Artwork review is open for the complete inventory

**Human clarification: all artwork and audio remain UNREVIEWED.**
There is no current four-effect rejection list and no implication that the rest
of the artwork has been reviewed or accepted. Earlier named feedback about Aid,
Bless, False Life or Sacred Flame is historical context, not today's acceptance
classification or a fixed rework queue.

The client must make every authored effect and relevant variant inspectable in
Studio, with actual source, placement, cast/release/contact, hold/removal,
intensity and lighting. Runtime integration, installed files, screenshots and
nonzero output are technical evidence; human artistic review remains open for
all of it. Missing creature body artwork is listed separately in
[the exact body-art handoff](CREATURE_BODY_ASSET_GAPS_2026-10-20.md).

### Existing-art assignments added, 21 October

Six gear resources now select supplied artwork: Spellblade Crown uses the
existing Crown family; Ember Quiver/Wayfarer Pack the existing Quiver family;
Warden Pack the Canister family; Pistol explicitly uses the Musket stand-in;
Light Hammer uses its actual existing Melee10 main-hand/Ground sheet, with
the existing Offhand2 approximation still explicit. All387 authored Ground
appearances now have one shared consumer for exact variants, authored pivots,
shadows and original optical companions. These are assignments of existing
files, not six new commissions or an artistic approval.

Ashen floor and original static wood/stone wall motifs now use the supplied
atlases and measured face coordinates. Animated door/destruction banks remain
a source-registration and consumer boundary, detailed below; their colour,
animation and receiving geometry are already supplied. Blood/Dread/Poison
retained pools reuse their existing measured region sources. The six summon spell resources explicitly
reuse the supplied neutral arrival accent for their actual disclosed births;
this does not replace any missing creature body. All of these choices await
human review.

The newer explicitly supplied creature packets now include selected dragon
reconstructed depth/Sprite Fusion Default normals and four actual Myrmidon
body/geometry/weapon-mask families. They are delivered source inputs awaiting
client intake, not requests for those assets again. The separate shared indexed-
material dragon ZIP remains a portable **candidate** by its own archived
handoff, despite its `production-2026-10-22` directory. Current NDClient still
uses the T-Rex and four arcane-elemental substitutes; mouth registration and
layout/receiving/caster adaptation remain separate. See the
[exact delivered-versus-integrated inventory](CREATURE_BODY_ASSET_GAPS_2026-10-20.md#newer-delivered-files-versus-active-authoring-and-client-intake).

### Animated door/destruction residue registration — current source boundary, 22 October

At client `23e14a2e`, Ashen already selects the original wall atlas through
[`residue.ashen.tres`](../authoring/environment/surfaces/residue.ashen.tres).
Its existing `wall_motifs` fields are `art_id`,
`sampling="wall_motifs_80x192"`, measured `opacity` and `faces`. The selected
[`residue_wall_faces.json`](../assets/measured/environment/legacy/residue_wall_faces.json)
contains **24 exact static image IDs**, mapped by `assets` to the three
`profiles` (`wall`, `door_closed`, `door_open`). Each profile's camera pose
contains at most two supplied planes, with `origin`, `across`, `down` and the
optional `reverse` flag. These are registrations of those particular original
wood/stone images; the old static `wood.door.*` entries are not registrations
of the newer animated door banks.

The animated artwork is present. For example, the existing shabby-door outward
bank has **24 frames in each of four views**; its closed/clear destruction bank
has **37 frames in each view**. Their current measured `surface_frames_by_pose`
already contain `geometry`, `geometry_region`, `geometry_sampling` and `normal`.
They retain actual source camera/depth calibration, native source contacts,
leaf/frame partitioning and the existing sampled hinge angles. This is **not**
a missing colour sheet, animation, depth/normal asset or backend residue field.
The source record explicitly distinguishes the fixed frame from the moving
leaf; one full bank must not be drawn again over its separate components.

What is absent is the matching **original-material face registration for each
selected frame/view and, during breakage, each surviving source fragment**.
Ray-depth positions and normals describe current surface geometry; they do not
by themselves identify the original face coordinates to which a mark must stay
attached as the leaf swings or fragments move. Copying a static door plane or
painting the current whole screen quad would slide the motif or apply it to an
unrelated face/frame.

The exact current transport also stops before those banks:

- [`Environment._images`](../tools/presentation_build/environment.gd:190)
  assigns `source_image_id` to registered image records. `_bank` preserves the
  actual frame geometry/clock but has no matching residue-face registration.
- [`_wall_motif_source`](../tools/presentation_build/environment.gd:682)
  resolves the selected `faces.assets` IDs only against those registered image
  resources and validates the supplied planes.
- [`Catalog.wall_residue_record`](../source_catalog.gd:302) requires an exact
  `source_image_id` and a wall row. Animated door rows are `kind="door"` and
  their measured frame surfaces have no such image registration. Destruction
  bank surfaces likewise lack it.
- [`EnvironmentSource.describe`](../presentation/environment_source.gd:33)
  currently applies those motif parameters to body source role1; a door's
  separate fixed frame and depth-partitioned leaf must retain their own source
  ownership. The current sampler admits at most four total motif planes.

The bounded deliverable is therefore an authored bank/frame/view-to-original-
face correspondence, retaining the exact existing bank ID, frame count,
sample times, camera/view mapping, source rect, source component and original
alpha/depth/normals. Where a face is representable by the existing planar
sampler, supply its own measured `origin`/`across`/`down`/optional `reverse` using
the existing `assets`/`profiles` registration schema. Do not put guessed values
into a new parallel format. A destruction frame with independently moving
fragments cannot be claimed supported by one old whole-door plane or by
exceeding the current plane capacity: its original-face correspondence remains
an explicit authoring/consumer design boundary until actually supplied.

After authentic registration exists, the existing builder, Catalog frame
selection and environment material path need one coherent bounded adaptation
to carry it. Actual `ObjectResidueState.condition_uuid`/`residue_id`/`faces`,
current observed-face eligibility, original source clock and leaf/frame split
must remain authoritative. No consumer code or guessed registration was added
in this source review, and no new Factory/backend API is requested.

### Equipped weapon contacts on object targets — authored placement remains open

[`NativeItems.impact_binding`](../presentation/native_items.gd:206) selects an
actual equipped Hit/Crit's intrinsic/coating contact from its source item and
item-effect snapshot. [`Components`](../presentation/components.gd:642) then
uses [`ImpactPlacement.prepare`](../presentation/impact_placement.gd:11), which
currently requires a disclosed **actor** rig/body socket. Non-creature targets
explicitly remain `weapon_impact_object_contact_not_bound`; they do not receive
an actor proxy. The public AttackFact's `target_kind` and `target_position` do
not alone author the object's contact point, height or receiving surface.

For any chosen object-contact assignment, identify its actual supported object
source and intended source-local contact/receiving geometry, then reuse the
existing finite attack/contact clock and exact item/target identity. An object
centre, first nearby wall, fake body UUID or guessed elevation is not that
registration. This is an existing explicit placement boundary, not a request
for new contact artwork, all object/material combinations or a new renderer.

## Audio work to delegate

Current playback already has authored source/contact clocks, selected-faction
hearing and native audio dispatch. It does not constitute complete sound design.
The earlier broad audio audit covered 57 audiences. Its two late-lethal landing
failures were timing/contact-boundary defects with an existing
`audio/jump-landing/jumpland.wav`. The current assignment inventory below
supersedes that inventory scope; it does not supersede native listening review.

Known unfinished sound-design/assignment categories from the current task:

- Damage voices and general spell impact cues.
- General condition application/removal cues.
- Window traversal/contact and additional floor/gear steps.
- Other ability/spell cues and torch extinguishing.
- Actual swing/foot/strike/release offsets and mix/listening review.

Please deliver exact source/owner assignments, licensed credits, source offset
and intended contact timing using existing `authoring/audio` resources. Verify
pause/seek/loop and relevant original cases. Native `play()` dispatch alone does
not prove audible balance or human acceptance. No fabricated sound is requested
for an unavailable gameplay event.

### Current Library assignment audit, 20 October 18:08:59 UTC

The existing `tools/studio_audio_coverage_audit.gd` now joins current integer
sequence/occurrence/phase owners and the production compiler's ordered
`condition_rows` before/after memberships. The headless pass exits **0**, with
zero read/join failures and no owned processes left running.
[Complete owners, case paths, selected assets and timing gaps](../.runtime/studio-audio-coverage-20261020T180859/report.json);
[original stdout](../.runtime/studio-audio-coverage-20261020T180859/stdout.log).
The retained log contains one Unicode replacement warning; it is not described
as a warning-free run.

At this pass the Library contains **331 cases**: 312 ready and 19 original failed
cases. This includes the newly recorded
`spell.flame_blade/equipped_reequip_expire_replace`. All **655 available audience
recordings/prefixes** were read; failed cases remain explicitly unqualified.
`spell.fixture.test_bless/baseline` still has no available recording. Declared
journal paths, original failure reasons and each prefix's scope are retained.

There are **1,491 audio inspection rows**, **zero missing selected files**,
**388 explicit unassigned-cue rows**, **78 timing-defect rows**, and **2,138
disclosed event/condition rows without an authored cue**. These counts include
separate audience views and split condition inspection intervals; they are not
unique sounds, new-asset requirements or an acceptance score. All 24 selected
catalog cues' 32 clip references resolve to 26 existing files.

| Work | Exact current owner/source | Observed rows |
|---|---|---:|
| Deferred condition loop | `authoring/audio/bindings.json:/conditions/condition.concentrating/persistent` | 364 |
| Deferred Magic Missile release | `authoring/audio/bindings.json:/spells/spell.magic_missile` | 20 |
| Unassigned extinguish source | `torch_extinguish`, case `interaction.torch/carried_lifecycle`; no selected suitable licensed source | 4 |
| Missing source contact markers | `authoring/audio/contacts.json:/rigs/smallscale.goblin01/Run/path` | 29 |
| Missing source contact markers | `authoring/audio/contacts.json:/rigs/smallscale.goblin01/Rolling/direct_arc` | 33 |
| Missing source contact markers | `authoring/audio/contacts.json:/rigs/neuroclient.modular/Run/connector_transfer` | 8 |
| Missing source contact markers | `authoring/audio/contacts.json:/rigs/neuroclient.modular/Rolling/connector_transfer` | 6 |
| Invalid clip-end contact boundary | `authoring/audio/contacts.json:/rigs/neuroclient.modular/Rolling/direct_arc/markers/1`, case `reaction.opportunity_attack/airborne_lethal`; occurrences `2:37` and `2:48` | 2 |

The 78 timing rows occur across 12 cases, including 22 rows from available
prefixes of failed scenarios. Their selected footstep/landing files exist.
The full report retains every case, component, clip, assignment pointer and
clock; fix the authored contact or timing selection before considering a new
recording.

### Current motion-contact source assignments, 21 October

The earlier 78-row receipt above is unchanged and has **not** been rerun. Three
of its four missing paths now have explicit source assignments in
[contacts.json](../authoring/audio/contacts.json), using the existing footstep,
takeoff and landing files. These are unvalidated authoring changes; all artwork,
sound, placement and mix remain **UNREVIEWED**.

| Authored path | Exact existing source/clock |
| --- | --- |
| `smallscale.goblin01/Rolling/direct_arc` | The actual `Goblin 01/Roll 1.png` rig context maps a full arc through source frames `0 → 3 → 10 → 14`. Forward frame0 selects takeoff; forward frame14 selects the completed endpoint. Frame14 is not a frame15 clip-end substitute. |
| `neuroclient.modular/Run/connector_transfer` | Reuses the existing modular Run source-frame3/frame10 stride assignments. The current Run connector fallback has zero authored lift and no warped window body keys; it keeps its actual looping source clock. |
| `neuroclient.modular/Rolling/connector_transfer` | The existing window profile maps `0 → 3 → 3 → 2 → 0` across its real arc. Forward frame0 selects takeoff and reverse frame0 selects landing after the return. Interior rolling/recovery poses do not count as floor contact. |

The optional `motion_endpoint: start/end` qualifier is executed by the shared
AudioCues helper against the actual track's motion fractions, disclosed
positions/elevations and existing `Tracks.samples` lift. It refuses looping
endpoints and airborne/incomplete crossings. Source-frame inversion still owns
the time; no additional clock, synthetic step-end contact or changed arc is
introduced. The existing modular direct-arc markers now carry the same qualifier.

**One genuine marker-authoring request remains:**
`authoring/audio/contacts.json:/rigs/smallscale.goblin01/Run/path` has no
authenticated planted-foot frame choices. The installed art is
`assets/art/media/smallscale/authored/orcs-and-goblins/Bodies/Goblin 01/Run.png`
(15 source frames, eight facings, authored at12 fps in
`authoring/characters/rigs/smallscale.goblin01.tres`). Its existing per-frame
optical geometry does not specify temporal foot contacts. Supply exact
zero-based planted-frame boundaries and crossing direction after reviewing the
actual source cycle/facings. No new image or audio file is requested, and no
frame is copied from the modular body.

**22 October source follow-up:** the actual Run and CrouchWalk cycles were
inspected in E, S, SW and N; the labelled source-frame sheets are preserved in
[`goblin-locomotion-contacts/source-inspection`](../.runtime/closing-repairs/goblin-locomotion-contacts/source-inspection).
The visible supporting phase spans several frames, with the opposite foot
obscured differently by the body/weapon across views. A low silhouette or
maximum foot extension does not establish a unique first planted arrival.
No defensible shared arrival boundary was established by that inspection, so
`Run/path` remains unassigned rather than receiving a guessed pair of beats.
The distinct CrouchWalk window source also cannot inherit Run's markers: its
existing connector clock warps/holds source frames `0→3→7→7→11→14`, and a pose
inside the actual arc is not automatically a floor contact. Existing source-
frame and disclosed-endpoint qualifiers already supply the required transport;
the remaining work is the explicit contact/sound authoring decision. No audio
data, source clock, body geometry or human-disabled cue was changed.

**The two terminal Blue-view rows remain an intentional source-admission gap.**
The durable original
`tests/fixtures/schema16/scenarios/oa-jump-late-lethal/blue/0000000000000002.json`
publishes committed Step occurrences37 and48 with ground→air and air→air layers;
its Movement occurrence77 discloses no whole path or terminal ground endpoint.
The independently recorded Amber view supplies its own path; it cannot authorize
Blue's missing arc. `Compiler._schedule` therefore uses the existing
disclosed-edge-only loop, and `AudioCues.contact_marker_error` refuses the
nonlooping frame15 `clip_end` landing. Neither existing `jumpland.wav` nor a
nearby tile proves touchdown. These historical rows must retain their refusal
unless a genuine public terminal motion/contact clock becomes available; no
new asset, arbitrary frame change or observer-state union closes them.

The unassigned event inventory contains 613 spell rows across 184 spell IDs,
1,020 condition transitions across 118 condition keys, 309 nonphysical damage
rows, 136 action/reaction rows across 21 IDs, 52 equipped-attack rows across 13
weapon IDs, and eight object-destruction rows. Exact IDs and original cases are
in `recordings[].unassigned_events`; condition application/removal are separate,
and initial memberships do not invent entry sounds. Review the intended audio
disposition and existing shared cues before authoring sounds for these rows.

This audit does **not** play audio. The saved WASAPI transport receipt remains
historical evidence; none of its recording-path/component-ID pairs joins this
current Library inventory, and current-package matching was not checked. Native
audible output, per-cue timing/mix, pause/seek/loop and human approval remain
separate acceptance work.

### Deterministic physical assignments after that audit

Ten exact equipped-weapon IDs now select the existing physical base swish at
the existing `body.contact` marker. This includes both Ember blades, three
Psychic longsword/scimitar variants, Psychic Greataxe, Arcane Staff, Devotee's
Mace, Flaming Scimitar and Longsword +1. The
[exact variant/base table](../authoring/audio/README.md#physical-weapon-variants-20-october)
and `authoring/audio/bindings.json:/weapons` own these choices. Frozen engine
mechanical definitions establish their bases; no filename or art inference is
used. The pre-change audit contains 40 attack rows for these IDs. No new source,
transient, timing, gain, magical rider or mix approval is introduced. The fresh
headless attribution below qualifies compilation of those assignments; native
playback remains separate. The earlier totals remain historical evidence.

### Post-assignment whole-Library receipt, 20 October 18:28:53 UTC

After the exclusive source rebuild completed, the frozen-resource audit ran
through the existing headless `tools/run_checks.sh`: **exit 0, errors 0**, zero
read/occurrence-join failures and no owned processes left running.
[Current complete inventory](../.runtime/studio-audio-post-assignment-20261020T182853/report.json),
[runner receipt](../.runtime/studio-audio-post-assignment-20261020T182853/receipt.json),
[original stdout](../.runtime/studio-audio-post-assignment-20261020T182853/stdout.log),
[exact before/after attribution](../.runtime/studio-audio-post-assignment-20261020T182853/comparison.json).
The existing Unicode replacement warning remains disclosed in stdout.

All **331 cases / 655 available audience prefixes** remain included: 312 ready,
19 original failed, and the same unavailable `spell.fixture.test_bless/baseline`
recording. There are now **1,531 audio inspection rows**, exactly **40 more**
than the earlier pass. Each of the ten weapon IDs contributes four newly
available rows. Their exact original completed attack occurrences, real item
UUIDs, source/target UUIDs, selected clips and existing `body.contact` selectors
are verified and retained in `comparison.json:new_weapon_rows`.

The corresponding unassigned-event inventory drops by exactly 40, from 2,138
to **2,098** rows. Twelve unassigned equipped-attack rows remain for the three
explicit weapon decisions listed below. These are audience/inspection counts,
not unique sounds or audible voices.

Other distinctions remain unchanged: **zero missing selected files** across 24
catalog cues / 32 clip references / 26 files; **388 explicit unassigned-cue rows**
(364 disabled concentration loops, 20 disabled Magic Missile releases, four
unselected torch-extinguish rows); **78 timing defects** (76 missing contact
marker rows and two invalid landing boundaries); and zero other audio-resolution
gaps. All eight `missing_cues` catalog entries and the selected-cue catalog are
unchanged. The complete current report preserves every exact owner and case.

This is headless component attribution and source/timing availability evidence.
It does not qualify native attachment dispatch, audible output, timing/mix or
human acceptance. The earlier 18:25 attempt remains invalidated by an overlapping
abilities rebuild and is excluded from qualification; its missing generation
resources were an orchestration failure, not a missing audio/Factory asset.

### Exact catalog handoff for remaining audio decisions

These IDs already exist in `authoring/audio/cues.json:/missing_cues`. They group
the remaining authoring work; none is an instruction to add a generic fallback
or manufacture a sound for every inventory row.

| Existing catalog ID | Expected semantics / remaining decision |
|---|---|
| `torch_extinguish` | Physical extinguishing on `action.item.torch.extinguish`, case `interaction.torch/carried_lifecycle` (four rows). Select and license an extinguish-specific source and its transient. The installed/registered torch file is ignition only; reversing ignition or substituting cloth/impact would be a new artistic choice. |
| `damage_reaction_voice` | Select a character/creature-appropriate vocal reaction and permitted recipients. Current `body_fall` and `physical_impact` are nonvocal sources; they do not supply voice coverage. |
| `condition_apply` | Decide which exact observed condition memberships need an application sound; initialization must remain silent. The 118 observed condition keys and original cases are retained in the report. |
| `condition_remove` | Decide which exact observed removals need a one-shot. Do not infer expiry/removal from elapsed display time or suppression. Concentration's `condition_loop` remains explicitly disabled. |
| `spell_impact` | Select explicit spell/contact sources and actual transients against the qualified recipient/outcome clocks; the installed `magic.impact` source is not a universal spell-impact assignment. |
| `other_abilities_and_spells` | Review the report's exact 184 spell IDs and 21 action/reaction IDs. `spell_release`/`spell.magic_missile` and `condition_loop`/`condition.concentrating` remain disabled by the human. Their installed assets do not authorize reenabling them. |
| `window_traversal` | Review actual source contact markers for the window/connector motion already listed above. Existing footstep/landing sources can be used only after their true contact is authored; a dedicated traversal recording is not automatically required. |
| `other_surfaces_and_gear` | Decide explicit surface/gear selections from disclosed data. Existing `footstep`, `footstep_wood` and physical equipment/cloth cues do not establish other materials, armor or gear sound profiles. |

The three equipped-weapon decisions from that audit are now source-authored:
`weapon.circus.soul_draining_morningstar` and `weapon.roster.psychic_trident`
select existing `weapon_swing_heavy`; `weapon.flame_blade` selects the existing
`weapon_swing` physical Scimitar swish. All use the existing `body.contact`
marker. No burning/psychic/necrotic/radiant sound is inferred from the physical
swing or damage type. These later source assignments have not rerun the
whole-Library inventory above: its12 unassigned attack rows and all recorded
counts remain the original receipt. Audible output, timing/mix and human
acceptance remain open. The later motion-contact subsection above supersedes
three marker-path assignments, without rerunning that receipt. One Goblin Run
marker-authoring request, the two undisclosed terminal cases, eight source
categories and disabled Magic Missile/Concentrating choices remain open.

### Source availability reassessment, 21 October

This is a read-only comparison of the supplied source manifest, selected cues
and typed assignments, **not** another playback or whole-Library audit. The
eight `missing_cues` IDs above group different responsibilities; they do not
mean eight missing audio files or eight mandatory new recordings. All sound
selection, transient placement and mix remain **UNREVIEWED**.

The installed [source manifest](../authoring/audio/sources.json) names 28 original
files; 24 existing cues select 26 of them. Two registered originals are unused:
`cloth.movement` (`assets/audio/kenney/rpg/cloth1.ogg`) and `magic.release`
(`assets/audio/magical-release/magical_1.ogg`). One further installed file,
`assets/audio/kenney/impact/impactPlank_medium_000.ogg`, has no source-manifest
or cue entry. These are cloth movement, magical release and a plank impact;
they are not missing voice or torch-extinguishing recordings. Their presence
also does not supply an exact condition/spell assignment or its transient.
No new alias, reversed ignition, blanket magical contact or redundant variation
is selected merely to reduce a missing-category count.

| Existing category | Actual source boundary / delegatable decision |
| --- | --- |
| `torch_extinguish` | **Source selection remains absent.** Supply an extinguish-specific original and credit/license, then select its transient for actual `action.item.torch.extinguish`. The installed `torch.ignition` is explicitly a flare ignition, with no extinguish segment declared. |
| `damage_reaction_voice` | **No vocal original is installed or registered.** Supply intended character/creature voice profiles and their permitted actual recipients. Punch, cloth and body-fall sources remain nonvocal effects. |
| `condition_apply` | **Per-owner sound-design decision.** Existing Prone application already uses `body_fall`; no supplied metadata assigns cloth or magical release to the other exact memberships. Name the desired conditions and one-shot/source/transient for each selected group. Initial membership stays silent. A universal entry sound is not required. |
| `condition_remove` | **Per-owner sound-design decision.** Prone removal already uses `stand_up`. Name actual removal owners that should sound and select their source/transient; do not turn suppression, elapsed display time or every removal into a cue. The disabled concentration loop remains disabled. |
| `spell_impact` | **Assignment/design, not absence of every magical source.** `magic.impact` exists, but its current selected cue is the explicitly disabled Magic Missile release probe. It is not an authored mapping for all spell contacts. Select exact spell/outcome owners and intended transients on their actual contact clocks before reuse or replacement. |
| `other_abilities_and_spells` | **Assignment/design.** Cloth/exertion, bow, handling, potion and ignition cues already exist for named owners. The unused `magic.release` and `cloth.movement` originals have no further exact owner assignment in their supplied metadata. List intended remaining owners rather than commissioning one generic ability sound. Human-disabled Magic Missile and concentration choices are unchanged. |
| `window_traversal` | **Remaining contact authoring/public-motion boundary.** Existing takeoff/landing/step sources support the three newly authored paths above. Goblin Run still needs planted-foot source frames; the two old Blue terminal cuts still lack their own touchdown. Neither is a missing audio file, and a dedicated window sound is optional design. |
| `other_surfaces_and_gear` | **Explicit material/gear design.** Concrete and wood steps plus cloth/belt handling already exist. No distinct water, earth, vegetation, ice, metal-floor or armor-step recording is installed. Choose which disclosed material/gear distinctions are wanted before requesting those specific originals; current hard/wood sources do not establish them. |

For any chosen replacement or new assignment, deliver its exact existing owner
ID, licensed source, source-sync transient and intended semantic contact marker
through the existing `authoring/audio` schema. No new audio tool, renderer or
clock is needed for these decisions. Native listening and human review remain
open for the entire selected inventory. The historical 331-case counts above
are unchanged; this source reassessment does not refresh their evidence.

## Existing asset assignments reconciled 21 October

Eight typed icon owners now use installed artwork rather than their earlier
placeholder or broad parent selection. These are source-data assignments;
ImageRef readiness means the assignment exists, not that the user accepted it.
No icon file was imported or painted.

| Actual owner | Current installed image / explicit reuse |
| --- | --- |
| [`action.draconic_spirit.breath`](../authoring/abilities/actions/action.draconic_spirit.breath.tres) | `action.dragonborn-breath-weapon` shared breath mechanic |
| [`action.environment.storage_chest.loot`](../authoring/abilities/actions/action.environment.storage_chest.loot.tres) | `action.loot-all` shared loot operation |
| [`action.item.field_kit.deploy`](../authoring/abilities/actions/action.item.field_kit.deploy.tres) | `item.field-kit`, the same actual item owner's glyph |
| [`action.item.devotees_mace.healing_incense`](../authoring/abilities/actions/action.item.devotees_mace.healing_incense.tres) | `item.incense` shared incense glyph |
| [`action.spell.arcane_sword.move`](../authoring/abilities/actions/action.spell.arcane_sword.move.tres) | `srd22.spell.arcane_sword`, the same spell owner's glyph |
| [`condition.summon.tenacity`](../authoring/abilities/conditions/condition.summon.tenacity.tres) | Delivered `srd22.creature_action.tenacity` mechanic glyph |
| [`condition.spell.vitriolic_sphere.residue`](../authoring/abilities/conditions/condition.spell.vitriolic_sphere.residue.tres) | Dedicated delivered `srd22.status.vitriolic_residue` glyph |
| [`spell.ice_knife.burst`](../authoring/abilities/spells/spell.ice_knife.burst.tres) | `spell.ice_knife`, the actual parent spell's glyph |

Skeleton Warrior now uses installed skeletal melee/shield art instead of a
living modular humanoid. It remains partial because its baked spear/shield
kit differs from the actual Longsword/Wooden Shield/Armor Scraps, optical
coverage and clip fallbacks remain partial, and acquired equipment is not
redrawn into that baked body. Its portrait remains borrowed. See
[the exact body assignment and limitations](CREATURE_BODY_ASSET_GAPS_2026-10-20.md#skeleton-warrior-assignment-repaired-kit-and-optical-limits-remain).
The absent unused `Head11` helmet offer was removed; no actual gear selection
was deleted and no missing sprites were fabricated. All 19 later-delivery
portraits were already assigned; there is no additional exact portrait to
silently substitute for the remaining borrowed identities. Of the original
twelve summon-body rows, four elemental bodies are assigned, four Myrmidon and
one dragon source families are now delivered but not integrated, and Cambion,
Deva and Djinni have no own-body delivery identified in the inspected handoffs.
The eight incomplete client rows are not eight missing-art requests.
**All artwork and audio remain UNREVIEWED.**

### Furniture Debris is not an observable missing body assignment

Pinned backend `0c2e5a0d7`
[DestructionDebris](/home/tommaso/.cache/ndclient/dnd_engine-0c2e5a0d7/dnd/content/items/world_prop_builders.py:742)
creates an actual `AreaCondition` for difficult terrain after furniture is
destroyed. It does not enable `has_visible_presence`; that field defaults false
in
[SpatialCondition](/home/tommaso/.cache/ndclient/dnd_engine-0c2e5a0d7/dnd/spatial/area_conditions.py:92),
whose observation method refuses the row at line 177. `AreaCondition` retains
that refusal. Thus the existing empty
[`spatial_effect.environment.furniture_debris`](../authoring/environment/surfaces/spatial_effect.environment.furniture_debris.tres)
ledger is not currently a public spatial-owner art requirement. The destroyed
physical furniture and its authored wreck states remain separate presentation.
No invisible region is painted from private mechanics, and no generic debris
asset/program request is added. If that region is later intentionally
published, its artwork decision must follow the actual public owner.

## Exact generic icon assignments

Each row is an existing generic image assignment. Review visible product
capabilities first; internal/developer/state-only owners may retain an explicit
permitted disposition instead of commissioning unnecessary artwork.

| Kind | Owner | Typed source | Current image |
|---|---|---|
| action | `action.class.cleric.divine_intervention.arm_thy_servant` | [action.class.cleric.divine_intervention.arm_thy_servant.tres](../authoring/abilities/actions/action.class.cleric.divine_intervention.arm_thy_servant.tres) | `res://assets/art/media/ui/icons/smooth48/ui.filter-actions.png` |
| action | `action.class.cleric.divine_intervention.golden_generosity` | [action.class.cleric.divine_intervention.golden_generosity.tres](../authoring/abilities/actions/action.class.cleric.divine_intervention.golden_generosity.tres) | `res://assets/art/media/ui/icons/smooth48/ui.filter-actions.png` |
| action | `action.class.cleric.divine_intervention.opulent_revival` | [action.class.cleric.divine_intervention.opulent_revival.tres](../authoring/abilities/actions/action.class.cleric.divine_intervention.opulent_revival.tres) | `res://assets/art/media/ui/icons/smooth48/ui.filter-actions.png` |
| action | `action.class.cleric.divine_intervention.sunder_heretical` | [action.class.cleric.divine_intervention.sunder_heretical.tres](../authoring/abilities/actions/action.class.cleric.divine_intervention.sunder_heretical.tres) | `res://assets/art/media/ui/icons/smooth48/ui.filter-actions.png` |
| action | `action.class.cleric.preserve_life` | [action.class.cleric.preserve_life.tres](../authoring/abilities/actions/action.class.cleric.preserve_life.tres) | `res://assets/art/media/ui/icons/smooth48/ui.filter-actions.png` |
| action | `action.class.cleric.turn_undead` | [action.class.cleric.turn_undead.tres](../authoring/abilities/actions/action.class.cleric.turn_undead.tres) | `res://assets/art/media/ui/icons/smooth48/ui.filter-actions.png` |
| action | `action.class.paladin.cleansing_touch` | [action.class.paladin.cleansing_touch.tres](../authoring/abilities/actions/action.class.paladin.cleansing_touch.tres) | `res://assets/art/media/ui/icons/smooth48/ui.filter-actions.png` |
| action | `action.class.paladin.divine_sense` | [action.class.paladin.divine_sense.tres](../authoring/abilities/actions/action.class.paladin.divine_sense.tres) | `res://assets/art/media/ui/icons/smooth48/ui.filter-actions.png` |
| action | `action.class.paladin.holy_nimbus` | [action.class.paladin.holy_nimbus.tres](../authoring/abilities/actions/action.class.paladin.holy_nimbus.tres) | `res://assets/art/media/ui/icons/smooth48/ui.filter-actions.png` |
| action | `action.class.paladin.lay_on_hands` | [action.class.paladin.lay_on_hands.tres](../authoring/abilities/actions/action.class.paladin.lay_on_hands.tres) | `res://assets/art/media/ui/icons/smooth48/ui.filter-actions.png` |
| action | `action.class.paladin.sacred_weapon` | [action.class.paladin.sacred_weapon.tres](../authoring/abilities/actions/action.class.paladin.sacred_weapon.tres) | `res://assets/art/media/ui/icons/smooth48/ui.filter-actions.png` |
| action | `action.class.paladin.turn_unholy` | [action.class.paladin.turn_unholy.tres](../authoring/abilities/actions/action.class.paladin.turn_unholy.tres) | `res://assets/art/media/ui/icons/smooth48/ui.filter-actions.png` |
| action | `action.class.wizard.arcane_recovery` | [action.class.wizard.arcane_recovery.tres](../authoring/abilities/actions/action.class.wizard.arcane_recovery.tres) | `res://assets/art/media/ui/icons/smooth48/ui.filter-actions.png` |
| action | `action.earth_myrmidon.landing` | [action.earth_myrmidon.landing.tres](../authoring/abilities/actions/action.earth_myrmidon.landing.tres) | `res://assets/art/media/ui/icons/smooth48/ui.filter-actions.png` |
| action | `action.item.potion_true_seeing.drink` | [action.item.potion_true_seeing.drink.tres](../authoring/abilities/actions/action.item.potion_true_seeing.drink.tres) | `res://assets/art/media/ui/icons/smooth48/ui.filter-actions.png` |
| action | `action.monster.natural_attack` | [action.monster.natural_attack.tres](../authoring/abilities/actions/action.monster.natural_attack.tres) | `res://assets/art/media/ui/icons/smooth48/ui.filter-actions.png` |
| action | `action.spell.entangle.escape` | [action.spell.entangle.escape.tres](../authoring/abilities/actions/action.spell.entangle.escape.tres) | `res://assets/art/media/ui/icons/smooth48/ui.filter-actions.png` |
| action | `action.spell.evards_black_tentacles.escape_dexterity` | [action.spell.evards_black_tentacles.escape_dexterity.tres](../authoring/abilities/actions/action.spell.evards_black_tentacles.escape_dexterity.tres) | `res://assets/art/media/ui/icons/smooth48/ui.filter-actions.png` |
| action | `action.spell.evards_black_tentacles.escape_strength` | [action.spell.evards_black_tentacles.escape_strength.tres](../authoring/abilities/actions/action.spell.evards_black_tentacles.escape_strength.tres) | `res://assets/art/media/ui/icons/smooth48/ui.filter-actions.png` |
| action | `action.spell.payload.throw` | [action.spell.payload.throw.tres](../authoring/abilities/actions/action.spell.payload.throw.tres) | `res://assets/art/media/ui/icons/smooth48/ui.filter-actions.png` |
| action | `action.spell.telekinesis.grab` | [action.spell.telekinesis.grab.tres](../authoring/abilities/actions/action.spell.telekinesis.grab.tres) | `res://assets/art/media/ui/icons/smooth48/ui.filter-actions.png` |
| action | `action.wizard.learn_scroll` | [action.wizard.learn_scroll.tres](../authoring/abilities/actions/action.wizard.learn_scroll.tres) | `res://assets/art/media/ui/icons/smooth48/ui.filter-actions.png` |
| class_feature | `class_feature.barbarian.frenzied` | [class_feature.barbarian.frenzied.tres](../authoring/abilities/conditions/class_feature.barbarian.frenzied.tres) | `res://assets/art/media/ui/icons/smooth48/condition.generic.png` |
| class_feature | `class_feature.barbarian.intimidating_presence_immunity` | [class_feature.barbarian.intimidating_presence_immunity.tres](../authoring/abilities/conditions/class_feature.barbarian.intimidating_presence_immunity.tres) | `res://assets/art/media/ui/icons/smooth48/condition.generic.png` |
| class_feature | `class_feature.barbarian.raging` | [class_feature.barbarian.raging.tres](../authoring/abilities/conditions/class_feature.barbarian.raging.tres) | `res://assets/art/media/ui/icons/smooth48/condition.generic.png` |
| class_feature | `class_feature.cleric.blessed_healer` | [class_feature.cleric.blessed_healer.tres](../authoring/abilities/actions/class_feature.cleric.blessed_healer.tres) | `res://assets/art/media/ui/icons/smooth48/ui.filter-actions.png` |
| class_feature | `class_feature.cleric.destroy_undead` | [class_feature.cleric.destroy_undead.tres](../authoring/abilities/actions/class_feature.cleric.destroy_undead.tres) | `res://assets/art/media/ui/icons/smooth48/ui.filter-actions.png` |
| class_feature | `class_feature.cleric.divine_strike` | [class_feature.cleric.divine_strike.tres](../authoring/abilities/actions/class_feature.cleric.divine_strike.tres) | `res://assets/art/media/ui/icons/smooth48/ui.filter-actions.png` |
| class_feature | `class_feature.paladin.improved_divine_smite` | [class_feature.paladin.improved_divine_smite.tres](../authoring/abilities/actions/class_feature.paladin.improved_divine_smite.tres) | `res://assets/art/media/ui/icons/smooth48/ui.filter-actions.png` |
| class_feature | `class_feature.sorcerer.draconic_presence` | [class_feature.sorcerer.draconic_presence.tres](../authoring/abilities/conditions/class_feature.sorcerer.draconic_presence.tres) | `res://assets/art/media/ui/icons/smooth48/condition.generic.png` |
| class_feature | `class_feature.sorcerer.draconic_presence.aura` | [class_feature.sorcerer.draconic_presence.aura.tres](../authoring/abilities/conditions/class_feature.sorcerer.draconic_presence.aura.tres) | `res://assets/art/media/ui/icons/smooth48/condition.generic.png` |
| class_feature | `class_feature.sorcerer.draconic_presence.immunity` | [class_feature.sorcerer.draconic_presence.immunity.tres](../authoring/abilities/conditions/class_feature.sorcerer.draconic_presence.immunity.tres) | `res://assets/art/media/ui/icons/smooth48/condition.generic.png` |
| class_feature | `class_feature.sorcerer.dragon_wings.active` | [class_feature.sorcerer.dragon_wings.active.tres](../authoring/abilities/conditions/class_feature.sorcerer.dragon_wings.active.tres) | `res://assets/art/media/ui/icons/smooth48/condition.generic.png` |
| class_feature | `class_feature.sorcerer.elemental_affinity.resistance` | [class_feature.sorcerer.elemental_affinity.resistance.tres](../authoring/abilities/conditions/class_feature.sorcerer.elemental_affinity.resistance.tres) | `res://assets/art/media/ui/icons/smooth48/condition.generic.png` |
| class_feature | `class_feature.sorcerer.metamagic_active` | [class_feature.sorcerer.metamagic_active.tres](../authoring/abilities/conditions/class_feature.sorcerer.metamagic_active.tres) | `res://assets/art/media/ui/icons/smooth48/condition.generic.png` |
| condition | `condition.attack_assistance` | [condition.attack_assistance.tres](../authoring/abilities/conditions/condition.attack_assistance.tres) | `res://assets/art/media/ui/icons/smooth48/condition.generic.png` |
| condition | `condition.class.cleric.intervention_use` | [condition.class.cleric.intervention_use.tres](../authoring/abilities/conditions/condition.class.cleric.intervention_use.tres) | `res://assets/art/media/ui/icons/smooth48/condition.generic.png` |
| condition | `condition.class.divine.turned` | [condition.class.divine.turned.tres](../authoring/abilities/conditions/condition.class.divine.turned.tres) | `res://assets/art/media/ui/icons/smooth48/condition.generic.png` |
| condition | `condition.class.feature_lifetime` | [condition.class.feature_lifetime.tres](../authoring/abilities/conditions/condition.class.feature_lifetime.tres) | `res://assets/art/media/ui/icons/smooth48/condition.generic.png` |
| condition | `condition.class.paladin.aura_benefit` | [condition.class.paladin.aura_benefit.tres](../authoring/abilities/conditions/condition.class.paladin.aura_benefit.tres) | `res://assets/art/media/ui/icons/smooth48/condition.generic.png` |
| condition | `condition.class.paladin.aura_membership` | [condition.class.paladin.aura_membership.tres](../authoring/abilities/conditions/condition.class.paladin.aura_membership.tres) | `res://assets/art/media/ui/icons/smooth48/condition.generic.png` |
| condition | `condition.class.paladin.aura_owner` | [condition.class.paladin.aura_owner.tres](../authoring/abilities/conditions/condition.class.paladin.aura_owner.tres) | `res://assets/art/media/ui/icons/smooth48/condition.generic.png` |
| condition | `condition.class.paladin.cleansing_capacity` | [condition.class.paladin.cleansing_capacity.tres](../authoring/abilities/conditions/condition.class.paladin.cleansing_capacity.tres) | `res://assets/art/media/ui/icons/smooth48/condition.generic.png` |
| condition | `condition.class.paladin.divine_sense` | [condition.class.paladin.divine_sense.tres](../authoring/abilities/conditions/condition.class.paladin.divine_sense.tres) | `res://assets/art/media/ui/icons/smooth48/condition.generic.png` |
| condition | `condition.class.paladin.holy_nimbus` | [condition.class.paladin.holy_nimbus.tres](../authoring/abilities/conditions/condition.class.paladin.holy_nimbus.tres) | `res://assets/art/media/ui/icons/smooth48/condition.generic.png` |
| condition | `condition.class.paladin.purity_of_spirit` | [condition.class.paladin.purity_of_spirit.tres](../authoring/abilities/conditions/condition.class.paladin.purity_of_spirit.tres) | `res://assets/art/media/ui/icons/smooth48/condition.generic.png` |
| condition | `condition.class.paladin.sacred_weapon` | [condition.class.paladin.sacred_weapon.tres](../authoring/abilities/conditions/condition.class.paladin.sacred_weapon.tres) | `res://assets/art/media/ui/icons/smooth48/condition.generic.png` |
| condition | `condition.class.wizard.recovery_state` | [condition.class.wizard.recovery_state.tres](../authoring/abilities/conditions/condition.class.wizard.recovery_state.tres) | `res://assets/art/media/ui/icons/smooth48/condition.generic.png` |
| condition | `condition.consumable.weapon_coat.concentration_fire` | [condition.consumable.weapon_coat.concentration_fire.tres](../authoring/abilities/conditions/condition.consumable.weapon_coat.concentration_fire.tres) | `res://assets/art/media/ui/icons/smooth48/condition.generic.png` |
| condition | `condition.consumable.weapon_coat.fire` | [condition.consumable.weapon_coat.fire.tres](../authoring/abilities/conditions/condition.consumable.weapon_coat.fire.tres) | `res://assets/art/media/ui/icons/smooth48/condition.generic.png` |
| condition | `condition.consumable.weapon_coat.lightning` | [condition.consumable.weapon_coat.lightning.tres](../authoring/abilities/conditions/condition.consumable.weapon_coat.lightning.tres) | `res://assets/art/media/ui/icons/smooth48/condition.generic.png` |
| condition | `condition.consumable.weapon_coat.timed_fire` | [condition.consumable.weapon_coat.timed_fire.tres](../authoring/abilities/conditions/condition.consumable.weapon_coat.timed_fire.tres) | `res://assets/art/media/ui/icons/smooth48/condition.generic.png` |
| condition | `condition.environment.wet` | [condition.environment.wet.tres](../authoring/abilities/conditions/condition.environment.wet.tres) | `res://assets/art/media/ui/icons/smooth48/condition.generic.png` |
| condition | `condition.revealed` | [condition.revealed.tres](../authoring/abilities/conditions/condition.revealed.tres) | `res://assets/art/media/ui/icons/smooth48/condition.generic.png` |
| condition | `condition.spell.acid_surface.membership` | [condition.spell.acid_surface.membership.tres](../authoring/abilities/conditions/condition.spell.acid_surface.membership.tres) | `res://assets/art/media/ui/icons/smooth48/condition.generic.png` |
| condition | `condition.spell.independent_summon_owner` | [condition.spell.independent_summon_owner.tres](../authoring/abilities/conditions/condition.spell.independent_summon_owner.tres) | `res://assets/art/media/ui/icons/smooth48/condition.generic.png` |
| condition | `condition.spell.payload_lifetime` | [condition.spell.payload_lifetime.tres](../authoring/abilities/conditions/condition.spell.payload_lifetime.tres) | `res://assets/art/media/ui/icons/smooth48/condition.generic.png` |
| condition | `condition.summon.draconic_breath_cadence` | [condition.summon.draconic_breath_cadence.tres](../authoring/abilities/conditions/condition.summon.draconic_breath_cadence.tres) | `res://assets/art/media/ui/icons/smooth48/condition.generic.png` |
| condition | `condition.summon.elemental_multiattack_bonus` | [condition.summon.elemental_multiattack_bonus.tres](../authoring/abilities/conditions/condition.summon.elemental_multiattack_bonus.tres) | `res://assets/art/media/ui/icons/smooth48/condition.generic.png` |
| condition | `condition.summon.myrmidon_strike_dice` | [condition.summon.myrmidon_strike_dice.tres](../authoring/abilities/conditions/condition.summon.myrmidon_strike_dice.tres) | `res://assets/art/media/ui/icons/smooth48/condition.generic.png` |
| condition | `condition.summon.raging_vortex_owner` | [condition.summon.raging_vortex_owner.tres](../authoring/abilities/conditions/condition.summon.raging_vortex_owner.tres) | `res://assets/art/media/ui/icons/smooth48/condition.generic.png` |
| condition | `condition.summon.sweetplum_field_owner` | [condition.summon.sweetplum_field_owner.tres](../authoring/abilities/conditions/condition.summon.sweetplum_field_owner.tres) | `res://assets/art/media/ui/icons/smooth48/condition.generic.png` |
| condition | `condition.summon.sweetplum_membership` | [condition.summon.sweetplum_membership.tres](../authoring/abilities/conditions/condition.summon.sweetplum_membership.tres) | `res://assets/art/media/ui/icons/smooth48/condition.generic.png` |
| condition | `condition.summon.sweetplum_restrained` | [condition.summon.sweetplum_restrained.tres](../authoring/abilities/conditions/condition.summon.sweetplum_restrained.tres) | `res://assets/art/media/ui/icons/smooth48/condition.generic.png` |
| condition | `condition.tile.spike_trap` | [condition.tile.spike_trap.tres](../authoring/abilities/conditions/condition.tile.spike_trap.tres) | `res://assets/art/media/ui/icons/smooth48/condition.generic.png` |
| condition | `condition.tile.zone_marker` | [condition.tile.zone_marker.tres](../authoring/abilities/conditions/condition.tile.zone_marker.tres) | `res://assets/art/media/ui/icons/smooth48/condition.generic.png` |
| condition | `spatial_effect.class.paladin.aura` | [spatial_effect.class.paladin.aura.tres](../authoring/abilities/conditions/spatial_effect.class.paladin.aura.tres) | `res://assets/art/media/ui/icons/smooth48/condition.generic.png` |
| condition | `spatial_effect.item.devotees_mace.healing_incense` | [spatial_effect.item.devotees_mace.healing_incense.tres](../authoring/abilities/conditions/spatial_effect.item.devotees_mace.healing_incense.tres) | `res://assets/art/media/ui/icons/smooth48/condition.generic.png` |
| condition | `spatial_effect.spell.acid_surface` | [spatial_effect.spell.acid_surface.tres](../authoring/abilities/conditions/spatial_effect.spell.acid_surface.tres) | `res://assets/art/media/ui/icons/smooth48/condition.generic.png` |
| condition | `spatial_effect.spell.antilife_shell` | [spatial_effect.spell.antilife_shell.tres](../authoring/abilities/conditions/spatial_effect.spell.antilife_shell.tres) | `res://assets/art/media/ui/icons/smooth48/condition.generic.png` |
| condition | `spatial_effect.spell.aura_of_life` | [spatial_effect.spell.aura_of_life.tres](../authoring/abilities/conditions/spatial_effect.spell.aura_of_life.tres) | `res://assets/art/media/ui/icons/smooth48/condition.generic.png` |
| condition | `spatial_effect.spell.blade_barrier` | [spatial_effect.spell.blade_barrier.tres](../authoring/abilities/conditions/spatial_effect.spell.blade_barrier.tres) | `res://assets/art/media/ui/icons/smooth48/condition.generic.png` |
| condition | `spatial_effect.spell.flaming_sphere.aura` | [spatial_effect.spell.flaming_sphere.aura.tres](../authoring/abilities/conditions/spatial_effect.spell.flaming_sphere.aura.tres) | `res://assets/art/media/ui/icons/smooth48/condition.generic.png` |
| condition | `spatial_effect.spell.forcecage` | [spatial_effect.spell.forcecage.tres](../authoring/abilities/conditions/spatial_effect.spell.forcecage.tres) | `res://assets/art/media/ui/icons/smooth48/condition.generic.png` |
| condition | `spatial_effect.spell.glyph_of_warding` | [spatial_effect.spell.glyph_of_warding.tres](../authoring/abilities/conditions/spatial_effect.spell.glyph_of_warding.tres) | `res://assets/art/media/ui/icons/smooth48/condition.generic.png` |
| condition | `spatial_effect.spell.moonbeam` | [spatial_effect.spell.moonbeam.tres](../authoring/abilities/conditions/spatial_effect.spell.moonbeam.tres) | `res://assets/art/media/ui/icons/smooth48/condition.generic.png` |
| condition | `spatial_effect.spell.pass_without_trace` | [spatial_effect.spell.pass_without_trace.tres](../authoring/abilities/conditions/spatial_effect.spell.pass_without_trace.tres) | `res://assets/art/media/ui/icons/smooth48/condition.generic.png` |
| condition | `spatial_effect.spell.plant_growth` | [spatial_effect.spell.plant_growth.tres](../authoring/abilities/conditions/spatial_effect.spell.plant_growth.tres) | `res://assets/art/media/ui/icons/smooth48/condition.generic.png` |
| condition | `spatial_effect.spell.simple_toxin` | [spatial_effect.spell.simple_toxin.tres](../authoring/abilities/conditions/spatial_effect.spell.simple_toxin.tres) | `res://assets/art/media/ui/icons/smooth48/condition.generic.png` |
| condition | `spatial_effect.summon.fire` | [spatial_effect.summon.fire.tres](../authoring/abilities/conditions/spatial_effect.summon.fire.tres) | `res://assets/art/media/ui/icons/smooth48/condition.generic.png` |
| condition | `spatial_effect.summon.raging_vortex` | [spatial_effect.summon.raging_vortex.tres](../authoring/abilities/conditions/spatial_effect.summon.raging_vortex.tres) | `res://assets/art/media/ui/icons/smooth48/condition.generic.png` |
| condition | `spatial_effect.summon.sweetplum_gales` | [spatial_effect.summon.sweetplum_gales.tres](../authoring/abilities/conditions/spatial_effect.summon.sweetplum_gales.tres) | `res://assets/art/media/ui/icons/smooth48/condition.generic.png` |
| condition | `unbound:dnd.spatial.environmental_conditions.Wet` | [semantic.wet.tres](../authoring/abilities/conditions/semantic.wet.tres) | `res://assets/art/media/ui/icons/smooth48/condition.generic.png` |
| feat | `feat.lucky` | [feat.lucky.tres](../authoring/abilities/actions/feat.lucky.tres) | `res://assets/art/media/ui/icons/smooth48/ui.filter-all.png` |
| spell | `spell.fixture.test_bless` | [spell.fixture.test_bless.tres](../authoring/abilities/spells/spell.fixture.test_bless.tres) | `res://assets/art/media/ui/icons/smooth48/ui.filter-spells.png` |
| trait | `trait.body_response` | [trait.body_response.tres](../authoring/abilities/actions/trait.body_response.tres) | `res://assets/art/media/ui/icons/smooth48/ui.filter-all.png` |
| trait | `trait.brave` | [trait.brave.tres](../authoring/abilities/actions/trait.brave.tres) | `res://assets/art/media/ui/icons/smooth48/ui.filter-all.png` |
| trait | `trait.brute` | [trait.brute.tres](../authoring/abilities/actions/trait.brute.tres) | `res://assets/art/media/ui/icons/smooth48/ui.filter-all.png` |
| trait | `trait.dark_devotion` | [trait.dark_devotion.tres](../authoring/abilities/actions/trait.dark_devotion.tres) | `res://assets/art/media/ui/icons/smooth48/ui.filter-all.png` |
| trait | `trait.dire_wolf_bite_prone` | [trait.dire_wolf_bite_prone.tres](../authoring/abilities/actions/trait.dire_wolf_bite_prone.tres) | `res://assets/art/media/ui/icons/smooth48/ui.filter-all.png` |
| trait | `trait.keen_hearing_and_sight` | [trait.keen_hearing_and_sight.tres](../authoring/abilities/actions/trait.keen_hearing_and_sight.tres) | `res://assets/art/media/ui/icons/smooth48/ui.filter-all.png` |
| trait | `trait.keen_hearing_and_smell` | [trait.keen_hearing_and_smell.tres](../authoring/abilities/actions/trait.keen_hearing_and_smell.tres) | `res://assets/art/media/ui/icons/smooth48/ui.filter-all.png` |
| trait | `trait.martial_advantage` | [trait.martial_advantage.tres](../authoring/abilities/actions/trait.martial_advantage.tres) | `res://assets/art/media/ui/icons/smooth48/ui.filter-all.png` |
| trait | `trait.sneak_attack` | [trait.sneak_attack.tres](../authoring/abilities/actions/trait.sneak_attack.tres) | `res://assets/art/media/ui/icons/smooth48/ui.filter-all.png` |
| trait | `trait.surprise_attack` | [trait.surprise_attack.tres](../authoring/abilities/actions/trait.surprise_attack.tres) | `res://assets/art/media/ui/icons/smooth48/ui.filter-all.png` |
| trait | `trait.wolf_bite_prone` | [trait.wolf_bite_prone.tres](../authoring/abilities/actions/trait.wolf_bite_prone.tres) | `res://assets/art/media/ui/icons/smooth48/ui.filter-all.png` |

## Exact creature portrait stand-ins

| Creature | Current portrait | Typed source |
|---|---|---|
| `creature.acolyte` | `cleric--human-white--male` | [creature.acolyte.tres](../authoring/characters/characters/creature.acolyte.tres) |
| `creature.bandit` | `rogue--human-white--male` | [creature.bandit.tres](../authoring/characters/characters/creature.bandit.tres) |
| `creature.bandit_captain` | `rogue--human-white--male` | [creature.bandit_captain.tres](../authoring/characters/characters/creature.bandit_captain.tres) |
| `creature.berserker` | `barbarian--human-white--male` | [creature.berserker.tres](../authoring/characters/characters/creature.berserker.tres) |
| `creature.bugbear` | `orcs_goblins--orc-04` | [creature.bugbear.tres](../authoring/characters/characters/creature.bugbear.tres) |
| `creature.commoner` | `monk--human-white--male` | [creature.commoner.tres](../authoring/characters/characters/creature.commoner.tres) |
| `creature.configured_srd.acolyte` | `cleric--human-white--male` | [creature.configured_srd.acolyte.tres](../authoring/characters/characters/creature.configured_srd.acolyte.tres) |
| `creature.configured_srd.bandit` | `rogue--human-white--male` | [creature.configured_srd.bandit.tres](../authoring/characters/characters/creature.configured_srd.bandit.tres) |
| `creature.configured_srd.bandit_captain` | `rogue--human-white--male` | [creature.configured_srd.bandit_captain.tres](../authoring/characters/characters/creature.configured_srd.bandit_captain.tres) |
| `creature.configured_srd.berserker` | `barbarian--human-white--male` | [creature.configured_srd.berserker.tres](../authoring/characters/characters/creature.configured_srd.berserker.tres) |
| `creature.configured_srd.bugbear` | `orcs_goblins--orc-04` | [creature.configured_srd.bugbear.tres](../authoring/characters/characters/creature.configured_srd.bugbear.tres) |
| `creature.configured_srd.commoner` | `monk--human-white--male` | [creature.configured_srd.commoner.tres](../authoring/characters/characters/creature.configured_srd.commoner.tres) |
| `creature.configured_srd.cult_fanatic` | `warlock--human-white--male` | [creature.configured_srd.cult_fanatic.tres](../authoring/characters/characters/creature.configured_srd.cult_fanatic.tres) |
| `creature.configured_srd.cultist` | `warlock--human-white--male` | [creature.configured_srd.cultist.tres](../authoring/characters/characters/creature.configured_srd.cultist.tres) |
| `creature.configured_srd.gnoll` | `orcs_goblins--orc-10` | [creature.configured_srd.gnoll.tres](../authoring/characters/characters/creature.configured_srd.gnoll.tres) |
| `creature.configured_srd.guard` | `fighter--human-white--male` | [creature.configured_srd.guard.tres](../authoring/characters/characters/creature.configured_srd.guard.tres) |
| `creature.configured_srd.hobgoblin` | `orcs_goblins--orc-03` | [creature.configured_srd.hobgoblin.tres](../authoring/characters/characters/creature.configured_srd.hobgoblin.tres) |
| `creature.configured_srd.knight` | `paladin--human-white--male` | [creature.configured_srd.knight.tres](../authoring/characters/characters/creature.configured_srd.knight.tres) |
| `creature.configured_srd.kobold` | `creature.goblin` | [creature.configured_srd.kobold.tres](../authoring/characters/characters/creature.configured_srd.kobold.tres) |
| `creature.configured_srd.mage` | `wizard--human-white--male` | [creature.configured_srd.mage.tres](../authoring/characters/characters/creature.configured_srd.mage.tres) |
| `creature.configured_srd.priest` | `cleric--human-white--male` | [creature.configured_srd.priest.tres](../authoring/characters/characters/creature.configured_srd.priest.tres) |
| `creature.configured_srd.scout` | `ranger--human-white--male` | [creature.configured_srd.scout.tres](../authoring/characters/characters/creature.configured_srd.scout.tres) |
| `creature.configured_srd.spy` | `rogue--human-white--male` | [creature.configured_srd.spy.tres](../authoring/characters/characters/creature.configured_srd.spy.tres) |
| `creature.configured_srd.thug` | `rogue--human-white--male` | [creature.configured_srd.thug.tres](../authoring/characters/characters/creature.configured_srd.thug.tres) |
| `creature.configured_srd.tribal_warrior` | `barbarian--human-white--male` | [creature.configured_srd.tribal_warrior.tres](../authoring/characters/characters/creature.configured_srd.tribal_warrior.tres) |
| `creature.configured_srd.veteran` | `fighter--human-white--male` | [creature.configured_srd.veteran.tres](../authoring/characters/characters/creature.configured_srd.veteran.tres) |
| `creature.cult_fanatic` | `warlock--human-white--male` | [creature.cult_fanatic.tres](../authoring/characters/characters/creature.cult_fanatic.tres) |
| `creature.cultist` | `warlock--human-white--male` | [creature.cultist.tres](../authoring/characters/characters/creature.cultist.tres) |
| `creature.dire_wolf` | `animals--elite-wolf` | [creature.dire_wolf.tres](../authoring/characters/characters/creature.dire_wolf.tres) |
| `creature.generic_caster` | `sorcerer--human-white--male` | [creature.generic_caster.tres](../authoring/characters/characters/creature.generic_caster.tres) |
| `creature.ghoul` | `top--zombie-decay-02` | [creature.ghoul.tres](../authoring/characters/characters/creature.ghoul.tres) |
| `creature.gnoll` | `orcs_goblins--orc-10` | [creature.gnoll.tres](../authoring/characters/characters/creature.gnoll.tres) |
| `creature.goblin_archer` | `creature.goblin_reedshot` | [creature.goblin_archer.tres](../authoring/characters/characters/creature.goblin_archer.tres) |
| `creature.goblin_caster` | `creature.goblin_wispbinder` | [creature.goblin_caster.tres](../authoring/characters/characters/creature.goblin_caster.tres) |
| `creature.guard` | `fighter--human-white--male` | [creature.guard.tres](../authoring/characters/characters/creature.guard.tres) |
| `creature.hobgoblin` | `orcs_goblins--orc-03` | [creature.hobgoblin.tres](../authoring/characters/characters/creature.hobgoblin.tres) |
| `creature.knight` | `paladin--human-white--male` | [creature.knight.tres](../authoring/characters/characters/creature.knight.tres) |
| `creature.kobold` | `creature.goblin` | [creature.kobold.tres](../authoring/characters/characters/creature.kobold.tres) |
| `creature.mage` | `wizard--human-white--male` | [creature.mage.tres](../authoring/characters/characters/creature.mage.tres) |
| `creature.ogre` | `barbarian--1ogre` | [creature.ogre.tres](../authoring/characters/characters/creature.ogre.tres) |
| `creature.ogre_zombie` | `hdz--zombiehulk1` | [creature.ogre_zombie.tres](../authoring/characters/characters/creature.ogre_zombie.tres) |
| `creature.priest` | `cleric--human-white--male` | [creature.priest.tres](../authoring/characters/characters/creature.priest.tres) |
| `creature.scout` | `ranger--human-white--male` | [creature.scout.tres](../authoring/characters/characters/creature.scout.tres) |
| `creature.skeleton` | `undead--6warrior` | [creature.skeleton.tres](../authoring/characters/characters/creature.skeleton.tres) |
| `creature.skeleton_warlock` | `undead--8necromancer` | [creature.skeleton_warlock.tres](../authoring/characters/characters/creature.skeleton_warlock.tres) |
| `creature.skeleton_warrior` | `undead--6warrior` | [creature.skeleton_warrior.tres](../authoring/characters/characters/creature.skeleton_warrior.tres) |
| `creature.spell.flaming_sphere` | `srd22.portrait.fire_elemental` | [creature.spell.flaming_sphere.tres](../authoring/characters/characters/creature.spell.flaming_sphere.tres) |
| `creature.spell.spiritual_weapon` | `cleric--human-white--male` | [creature.spell.spiritual_weapon.tres](../authoring/characters/characters/creature.spell.spiritual_weapon.tres) |
| `creature.spy` | `rogue--human-white--male` | [creature.spy.tres](../authoring/characters/characters/creature.spy.tres) |
| `creature.thug` | `rogue--human-white--male` | [creature.thug.tres](../authoring/characters/characters/creature.thug.tres) |
| `creature.tribal_warrior` | `barbarian--human-white--male` | [creature.tribal_warrior.tres](../authoring/characters/characters/creature.tribal_warrior.tres) |
| `creature.veteran` | `fighter--human-white--male` | [creature.veteran.tres](../authoring/characters/characters/creature.veteran.tres) |
| `creature.zombie` | `hdz--zombiemale1` | [creature.zombie.tres](../authoring/characters/characters/creature.zombie.tres) |

## Exact creature body stand-ins

| Creature | Typed source |
|---|---|
| `creature.acolyte` | [creature.acolyte.tres](../authoring/characters/characters/creature.acolyte.tres) |
| `creature.bandit` | [creature.bandit.tres](../authoring/characters/characters/creature.bandit.tres) |
| `creature.bandit_captain` | [creature.bandit_captain.tres](../authoring/characters/characters/creature.bandit_captain.tres) |
| `creature.berserker` | [creature.berserker.tres](../authoring/characters/characters/creature.berserker.tres) |
| `creature.bugbear` | [creature.bugbear.tres](../authoring/characters/characters/creature.bugbear.tres) |
| `creature.commoner` | [creature.commoner.tres](../authoring/characters/characters/creature.commoner.tres) |
| `creature.configured_srd.acolyte` | [creature.configured_srd.acolyte.tres](../authoring/characters/characters/creature.configured_srd.acolyte.tres) |
| `creature.configured_srd.bandit` | [creature.configured_srd.bandit.tres](../authoring/characters/characters/creature.configured_srd.bandit.tres) |
| `creature.configured_srd.bandit_captain` | [creature.configured_srd.bandit_captain.tres](../authoring/characters/characters/creature.configured_srd.bandit_captain.tres) |
| `creature.configured_srd.berserker` | [creature.configured_srd.berserker.tres](../authoring/characters/characters/creature.configured_srd.berserker.tres) |
| `creature.configured_srd.bugbear` | [creature.configured_srd.bugbear.tres](../authoring/characters/characters/creature.configured_srd.bugbear.tres) |
| `creature.configured_srd.commoner` | [creature.configured_srd.commoner.tres](../authoring/characters/characters/creature.configured_srd.commoner.tres) |
| `creature.configured_srd.cult_fanatic` | [creature.configured_srd.cult_fanatic.tres](../authoring/characters/characters/creature.configured_srd.cult_fanatic.tres) |
| `creature.configured_srd.cultist` | [creature.configured_srd.cultist.tres](../authoring/characters/characters/creature.configured_srd.cultist.tres) |
| `creature.configured_srd.gnoll` | [creature.configured_srd.gnoll.tres](../authoring/characters/characters/creature.configured_srd.gnoll.tres) |
| `creature.configured_srd.guard` | [creature.configured_srd.guard.tres](../authoring/characters/characters/creature.configured_srd.guard.tres) |
| `creature.configured_srd.hobgoblin` | [creature.configured_srd.hobgoblin.tres](../authoring/characters/characters/creature.configured_srd.hobgoblin.tres) |
| `creature.configured_srd.knight` | [creature.configured_srd.knight.tres](../authoring/characters/characters/creature.configured_srd.knight.tres) |
| `creature.configured_srd.kobold` | [creature.configured_srd.kobold.tres](../authoring/characters/characters/creature.configured_srd.kobold.tres) |
| `creature.configured_srd.mage` | [creature.configured_srd.mage.tres](../authoring/characters/characters/creature.configured_srd.mage.tres) |
| `creature.configured_srd.priest` | [creature.configured_srd.priest.tres](../authoring/characters/characters/creature.configured_srd.priest.tres) |
| `creature.configured_srd.scout` | [creature.configured_srd.scout.tres](../authoring/characters/characters/creature.configured_srd.scout.tres) |
| `creature.configured_srd.spy` | [creature.configured_srd.spy.tres](../authoring/characters/characters/creature.configured_srd.spy.tres) |
| `creature.configured_srd.thug` | [creature.configured_srd.thug.tres](../authoring/characters/characters/creature.configured_srd.thug.tres) |
| `creature.configured_srd.tribal_warrior` | [creature.configured_srd.tribal_warrior.tres](../authoring/characters/characters/creature.configured_srd.tribal_warrior.tres) |
| `creature.configured_srd.veteran` | [creature.configured_srd.veteran.tres](../authoring/characters/characters/creature.configured_srd.veteran.tres) |
| `creature.cult_fanatic` | [creature.cult_fanatic.tres](../authoring/characters/characters/creature.cult_fanatic.tres) |
| `creature.cultist` | [creature.cultist.tres](../authoring/characters/characters/creature.cultist.tres) |
| `creature.dire_wolf` | [creature.dire_wolf.tres](../authoring/characters/characters/creature.dire_wolf.tres) |
| `creature.generic_caster` | [creature.generic_caster.tres](../authoring/characters/characters/creature.generic_caster.tres) |
| `creature.ghoul` | [creature.ghoul.tres](../authoring/characters/characters/creature.ghoul.tres) |
| `creature.gnoll` | [creature.gnoll.tres](../authoring/characters/characters/creature.gnoll.tres) |
| `creature.goblin_archer` | [creature.goblin_archer.tres](../authoring/characters/characters/creature.goblin_archer.tres) |
| `creature.goblin_caster` | [creature.goblin_caster.tres](../authoring/characters/characters/creature.goblin_caster.tres) |
| `creature.guard` | [creature.guard.tres](../authoring/characters/characters/creature.guard.tres) |
| `creature.hobgoblin` | [creature.hobgoblin.tres](../authoring/characters/characters/creature.hobgoblin.tres) |
| `creature.knight` | [creature.knight.tres](../authoring/characters/characters/creature.knight.tres) |
| `creature.kobold` | [creature.kobold.tres](../authoring/characters/characters/creature.kobold.tres) |
| `creature.mage` | [creature.mage.tres](../authoring/characters/characters/creature.mage.tres) |
| `creature.ogre` | [creature.ogre.tres](../authoring/characters/characters/creature.ogre.tres) |
| `creature.ogre_zombie` | [creature.ogre_zombie.tres](../authoring/characters/characters/creature.ogre_zombie.tres) |
| `creature.priest` | [creature.priest.tres](../authoring/characters/characters/creature.priest.tres) |
| `creature.scout` | [creature.scout.tres](../authoring/characters/characters/creature.scout.tres) |
| `creature.skeleton` | [creature.skeleton.tres](../authoring/characters/characters/creature.skeleton.tres) |
| `creature.skeleton_warlock` | [creature.skeleton_warlock.tres](../authoring/characters/characters/creature.skeleton_warlock.tres) |
| `creature.spell.air_elemental` | [creature.spell.air_elemental.tres](../authoring/characters/characters/creature.spell.air_elemental.tres) |
| `creature.spell.air_myrmidon` | [creature.spell.air_myrmidon.tres](../authoring/characters/characters/creature.spell.air_myrmidon.tres) |
| `creature.spell.cambion` | [creature.spell.cambion.tres](../authoring/characters/characters/creature.spell.cambion.tres) |
| `creature.spell.deva` | [creature.spell.deva.tres](../authoring/characters/characters/creature.spell.deva.tres) |
| `creature.spell.djinni` | [creature.spell.djinni.tres](../authoring/characters/characters/creature.spell.djinni.tres) |
| `creature.spell.draconic_spirit` | [creature.spell.draconic_spirit.tres](../authoring/characters/characters/creature.spell.draconic_spirit.tres) |
| `creature.spell.earth_elemental` | [creature.spell.earth_elemental.tres](../authoring/characters/characters/creature.spell.earth_elemental.tres) |
| `creature.spell.earth_myrmidon` | [creature.spell.earth_myrmidon.tres](../authoring/characters/characters/creature.spell.earth_myrmidon.tres) |
| `creature.spell.fire_elemental` | [creature.spell.fire_elemental.tres](../authoring/characters/characters/creature.spell.fire_elemental.tres) |
| `creature.spell.fire_myrmidon` | [creature.spell.fire_myrmidon.tres](../authoring/characters/characters/creature.spell.fire_myrmidon.tres) |
| `creature.spell.water_elemental` | [creature.spell.water_elemental.tres](../authoring/characters/characters/creature.spell.water_elemental.tres) |
| `creature.spell.water_myrmidon` | [creature.spell.water_myrmidon.tres](../authoring/characters/characters/creature.spell.water_myrmidon.tres) |
| `creature.spy` | [creature.spy.tres](../authoring/characters/characters/creature.spy.tres) |
| `creature.thug` | [creature.thug.tres](../authoring/characters/characters/creature.thug.tres) |
| `creature.tribal_warrior` | [creature.tribal_warrior.tres](../authoring/characters/characters/creature.tribal_warrior.tres) |
| `creature.veteran` | [creature.veteran.tres](../authoring/characters/characters/creature.veteran.tres) |
| `creature.zombie` | [creature.zombie.tres](../authoring/characters/characters/creature.zombie.tres) |

## Aura of Life main field is assigned; runtime and human review remain open

The earlier missing-main-owner diagnosis is superseded by the delivered mapped
PhaseResource and the explicit
[`condition.spell.aura_of_life.owner` assignment](../authoring/abilities/conditions/condition.spell.aura_of_life.owner.tres).
It selects `production-review/aura-of-life/main_owner` through the shared
standalone source path on the actual owner UUID/lifetime. Benefit memberships
retain their separate recipient lifecycle, and the spatial ledger delegates
rather than drawing a duplicate owner field. This is source integration;
original-case rendering, placement/timing, audio and human acceptance are not
qualified by this document reconciliation. All artwork and audio are UNREVIEWED.

A source file existing is not evidence that its body, portrait, icon or audio
has been accepted. This file will gain actual newly discovered missing-file
paths as they occur; it does not label source-contract/backend gaps as asset
absence. [Authoritative work status](REMAINING_WORK_2026-10-20.md).
