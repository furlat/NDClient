# Native sandbox placement audit

15 October 2026. Scope: the existing34 capabilities, their selected78 native
phases, original per-spell JSON assignments and the five approved optional cast
poses. This is source-coordinate review, not a new spell batch or artistic scale
approval. No Factory originals or production event semantics were changed.

## Coordinate contract

The actual sequence is:

1. Select the original cast clip, source frame and facing. `sourceSockets` supplies
   a painted hand point; `surface_sockets.gd` resolves its actual painted owner's
   optical depth. Unsupported pixels retain the painted point and report why.
2. Choose a world attachment: current preparation hand, fixed release hand,
   recipient body, actor ground, or the flight curve between those points.
3. Build the aim/world basis, then multiply the cue's `rotation_degrees`. Apply
   `offset` through that basis. **Cue offsets are world units, not source units.**
4. Apply uniform `cue.scale * spell.effect_scale / .18`. Source component scales,
   rotations and local positions remain inside that conversion.
5. Sample native component/animation clocks. A declared carrier cancels source
   internal travel once. A declared `origin_path` then translates the complete
   sampled composition so that exact native node meets the attachment.

For source point`q`, registered source anchor`a`, world attachment`A`, rotation`R`
and uniform scale`s`, the resulting point is `A + R*offset + s*R*(q-a)`.
That subtraction is why a source-local anchor should not be replaced by an
arbitrary world offset. Child particles/lights retain their relative transforms.
Camera rotation changes the authored sprite facing/socket; it does not rotate an
effect independently of its caster-to-target direction.

One horizontal world unit is one five-foot cell. The existing renderer's vertical
five-foot step is `Placement.HEIGHT_UNIT = sqrt(2/3)`; do not assume a source
metre, exported sheet pixel and game elevation step are the same unit.

## Confirmed corrections

All corrections below are saved. The finite native placement suite passes
226/226 checks on Windows Godot4.7.2 Forward+/Vulkan, with no runtime errors.

| Defect | Source evidence | Saved correction |
| --- | --- | --- |
| Magic Missile held, flying and impact cores have different forward displacement | All three Factory phases retain component`input.local_offset=[0,0,-1.2]`. Native Box1 is exactly at z−1.2. With scale.18/.26/.18, those become .216/.312/.216 world-unit offsets from the socket/contact. Curved-flight tangents rotate that error too. | `staging.json` cast and flight`origin_path=travel/Donor/Box1`; impact`origin_path=impact/Donor`. Source-local offsets remain intact and are registered exactly once. |
| Fireball preparation points sideways relative to the launched flame | The formation's own`rotation_degrees=[0,-90,0]` rotates its native trailing mesh onto −X. At source.8, its undeformed x-bounds are −3.113..−.016; the travel mesh trails along +Z. | Cast cue`rotation_degrees=[0,90,0]` cancels the export-facing yaw before ordinary aim rotation. Core origin/scale/source geometry unchanged. |
| Ray of Frost's native head does not meet the hand/contact | Actual`FireTorch_AC` origin is `[0,0,-.6724316]`; undeformed head tip is z−.6571472. Neither main travel nor its Ice companion registered that shared source head. | Both flight cues`origin_path=effect/Donor/FireTorch_AC`. The companion retains that node as a hidden registration anchor; its own ice emitter geometry and scale remain unchanged. |
| Isolated phases disregard Sequence's native core registration | `_sample_isolated_effects` previously applied`origin_path` only inside its attached-role block. Eldritch, Fireball, Ice Knife, Produce Flame and other named flight/cast cores could therefore look detached only when inspected individually. | Apply the selected cue/placement`origin_path` after source sampling for every role. Attached effects use the same operation once. |

Owner files: `authoring/sandbox/staging.json` and only
`sandbox/world.gd::_sample_isolated_effects`. Existing spell animation JSON,
rendering shaders and ordinary room lighting remain unchanged.

## Complete capability inventory

`G`means actor ground;`B`means current body-center socket;`H`means current
preparation hand;`R`means the fixed authored release hand. Numbers are outer
native-unit scales before the editable Size multiplier. Source adapter offsets
listed here are already within that scale; they are not extra suggested offsets.

| Capability | Attachments and source registration | Result / necessary qualification |
| --- | --- | --- |
| Acid Splash | H→R→B .18; native +X projectile becomes aim−Z through cue yaw+90. Impact source rotates−90X internally. | One axis conversion, no duplicated yaw: isolated cue rotation replaces its fallback source yaw. Source head is a stretched mesh around its origin, not a node-centred sphere. No offset change justified. |
| Chill Touch | Strike B,.06; Rx90 converts native descending punch to aimed strike. Contact source1.638889s. | Portal origin sourceY8.19215 becomes.491529 behind the contact along the strike axis. This is part of the native hand/portal composition. Skinned bind-pose bounds cannot determine the animated fingertip; retain recovered animation/contact and prior native hand proof. |
| Eldritch Blast | Cast H/R,.25 at`cast/Donor/Flare`; flight.35 at`travel/Donor/MBall`; impact B,.18. | Source flare z−.219483 and core z−.168584 are registered, not independently nudged. Isolated registration corrected. |
| Fire Bolt | H/R cast.18; flight.18, native`TBHead_inner`at0; impact B,.18. | Torus/core origin0, FireCenter z−.219483 is an intentional internal emitter spread. Do not centre the whole long trail AABB or move every emitter onto the hand. |
| Fireball | Cast H/R,.18; flight.65 at`effect/Donor/FireTorch_AC`; explosion recipientG,2/3. | Charge axis corrected. Flight source core z−.395548 registered once. Explosion has an authored ground origin and radius4cell/source6; it must not attach to body height. |
| Guiding Bolt | H/R cast.18; flight.45 at`travel/Donor/InnerBall`; impact B,.18. | Native donor scale.9, inner ball origin0. No additional offset needed; isolated uses same named core. |
| Ice Knife | H/R flight.16 at`effect/Donor/SmRocksStone4002`; cast.18; delayed explosion G,.25. | Native named stone origin`[0,.0279298,.304365]`registered; source mesh and trails remain relative to it. Its geometric long axis spans ahead/behind the node; do not replace this approved grip/core with AABB centre. |
| Magic Missile | Three H/R→B flights.26, cast/impact.18. | All three phases now use the exact registered source cube/impact origin; corrections above. Repeated/split deliveries retain separate curves and clocks. |
| Poison Spray | Spray R,.3; hand preparation.18. | Native smoke/cone emitters are at0. Spray is an emitter source, not a projectile whose centre should be moved to target. Particle bounds require native simulation; no static AABB correction. |
| Produce Flame | One held/flight source.28 at`effect/Donor/FireTorch_AC8`; impact B,.12. | Source core z−.238099 registered; one source grows then flies. The legacy palm/windup remains isolated-only and has its own source yaw; do not add it back as a second charged flame. |
| Ray of Frost | Two H/R→B flight components.18/.22, shared native head registration; impact B,.18. | Main and Ice companion now subtract the same source head coordinate before their own unit scale. Ice emitter remains behind that head as authored. Four-view held/release/flight captures show the combined effect remains coherent. |
| Scorching Ray | Three H/R→B flights.23; impact B,.3; hand preparation.18. | Selected native FireStrike source core at0; original source-internal translation adapter is not used by the replacement native flight. No second flight offset. |
| Sleep | H/R→B,.55 with yaw+90; area G,1.45. | Declared`carrier_path=Donor/Core`already removes source core x−.302. Actual sampled Core is0; donor then lies x+.302. Do not subtract both carrier and a second guessed head offset. |
| Web | H/R→B,.35; ground area.3302693114. | Projectile emitters at0. Ground mesh native bounds±5.3 inXZ and y0; keep it attached to floor, not body or camera plane. |
| Bane | RecipientG,.5; source donor height1.4, scale.9. | Body envelope centre height.7 after conversion. Application retained; no extra body socket or second source height. |
| Command | RecipientG,.5; ControlGlyph sourceY2.52. | Glyph height1.26; source camera-facing view adapter owns its plane orientation. Body/ground anchor substitution would add another height. |
| Mage Armor | RecipientG,.5; native shield donor height.93/scale.93. | Measured undeformed envelope Y0..1.86→0...93: sole-level base is already correct. |
| Sanctuary | RecipientG,.5; source root0, native scale.24. | Source vertical beam retains native internal height; no extra head/body offset. Sustained opacity/light choices are separate from position. |
| Shield | CasterG,.5; shield donor height1.12/scale1.12. Incoming probe targets caster body; hit_E is separately aimed and ground-registered. | Shield envelope Y0..2.24→0..1.12. Preserve its ground base and the explicitly separate incoming actor/target roles. |
| False Life | Application casterG,.5; source height1.7/scale.78. Sustain is actor-surface projection. | Application offset belongs to source; sustain no longer uses envelope mesh placement. Body projection consumes actual actor position/depth/normal. |
| Sacred Flame | RecipientG,.12; native donor scale`[.28,.45,.28]`. | Native source's anisotropic authored beam scale is retained inside uniform outer conversion. Beam/particle geometry cannot be re-centred from one billboard AABB; ground impact stays at ground. |
| Shocking Grasp | Cast H/R,.18; recipientB,.5. Native root0/scale`[1.3,2.1,1.3]`. | Body attachment follows original `target_body` media; original source has no extra height. Preserve native lightning envelope rather than applying support ground offsets. |
| Burning Hands | Fixed casterR,.5, facing yaw+90;`effect/Donor/fire`registered after source sample. | Source donor offset`[1.102034,1.35,-.053368]`and anisotropic shape scale belong to the approved cone. Named emitter registration removes the position offset once; geometry shape scale remains. |
| Thunderwave | CasterG,.5, facing yaw+90. | Native whole-area source grows along+X; yaw maps it to forward−Z. Source origin0; ground source differs intentionally from hand-cast cone. |
| Aid | RecipientG,.6; donor height.9/scale.72. | Donor envelope base0, top2.448 source→1.4688world. No body offset. Artistic envelope size is not an inferred registration defect. |
| Bless | Application recipientG,.55; source height1.25/scale.9. | Native application base0. Lingering cage is being replaced with shared body-surface treatment per user; position audit does not reintroduce it. |
| Cure Wounds | RecipientB,.3; source scale.8. | Source settings height1.2 is explicitly reset by clip property override`effect/Donor.position:y=0`. Actual sampled source origin0: no double elevation. |
| Healing Word | RecipientB,.35; source scale.85. | Both donor height.35 and verticalflash emitter height are explicitly reset to0 before body attachment. No second height correction. |
| Guidance | RecipientG,.6; donor height1.35/scale.42. | Source envelopeY.72..1.98→.432..1.188world; a body/waist-sized ground-relative envelope, not a floor decal. |
| Resistance | RecipientG,.55; donor height.9/scale.75. | Source envelope intersects floor (Y−.375..2.175); actual source shader coverage can differ from undeformed mesh. Do not raise it by its AABB minimum without source visibility evidence. |
| Light | RecipientG,.6; native orb height2.35/scale.18. | Orb/source light worldY1.41; this is explicitly overhead, not a body-centred effect. Its light follows actual transformed node. |
| Thaumaturgy | CasterG,.55; native height1.6/scale.18. | Small native accent centreY.88; no additional hand/body elevation. |
| Shield of Faith | RecipientG,.5; donor scale.78, source height0. | Source adapter raises shield mesh internally. Actual shield mesh Y.657..1.372→.3285...686; its ground-origin source includes those authored child offsets. |
| True Strike | Current casterH,.3; native source scale1.8, source height0. | Native particles are already offsetY.568...6503 before outer conversion. This is the source weapon aura above its hidden sword, not proof of a hand-pivot error. Original cast remains disabled; local follow-up uses original Attack6. |

## Cast poses and continuity

Authored preserves every original recipe. Optional profiles are only Attack1
(prepare3/release6), Attack4(7/9), Attack5(4/7), Attack6(3/6), and Special1(8/11).
Both cast and projectile sockets change together; each of eight facings satisfies
`preparation[releaseFrame] == release`. Attack6 uses the source corrected Magic2
hand, not the generic socket on the other arm. No Attack2/bow Attack3 adaptation
is in scope. Corrected native five-pose/four-view checks already pass203; source
checks pass2123. Those tests qualify sockets, not every native donor core.

## Evidence and remaining qualification

- `tests/sandbox_position_checks.gd` exercises the real fixture's Sequence and
  isolated paths across four camera views. It checks actual selected native core
  positions at held/release/contact times, plus the native Fireball mesh's trailing
  direction. Headless parse and226 native checks pass. Report:
  `.runtime/sandbox-position-checks.json`; native log:
  `.runtime/sandbox-position-native.log`. The log has only the known source
  VisualShader `graph_offset` deprecation warning.
- `.runtime/sandbox-source-positions.json` records255 sampled native node/mesh
  observations across the selected library. It is read-only diagnostic evidence,
  not a passing test: its headless process wrote all records, then exited5 with no
  source error logged. Mesh bounds exclude GPU particles, skinning and shader
  displacement. They must not be used as a substitute for real visible coverage.
- Saved36 actual native captures under `.captures/positions/`: held, release and
  midflight for Magic Missile, Fireball and Ray of Frost, each from all four views.
  The three contact sheets were inspected: hand-to-flight placement is continuous,
  Fireball's charge and flight axes agree, and Ray's Ice companion stays with its
  main source. Isolated native nodes pass the same registration assertions. This
  is geometric/visible continuity evidence, not final user artistic approval.
- Default source scale, intentional emitter spread and native shader geometry
  are not missing offsets. Only measured anchor/axis errors were changed.

Factory follow-up should name the semantic source anchor and forward axis in the
existing recipe/selection data. It should not require reverse-engineering these
from a screenshot every time a new source is selected.
