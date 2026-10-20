# Modular weapon effects — implemented client contract

20 October 2026. Integrated client checkout:
`C:/Users/tommaso/Documents/Dev/NDClientGodot`, sole active/local branch
`codex-authoring-schemabump`. The former implementation worktrees were merged
into this checkout. This is the implemented receiving contract, not a claim that
every enhancement or spell has been migrated or visually approved.

The Factory's newer
[20 October weapon delivery study](/mnt/c/Users/tommaso/Documents/assets/VFXFactory/docs/NDCLIENT_MODULAR_WEAPON_EFFECTS_DELIVERY_HANDOFF_2026-10-20.md)
is work in progress, not an installed sealed successor. Its66 sustain phases
and21 contacts are candidates; source-geometry coverage is currently limited to
specific Scimitar/Melee4 and Greatsword/Melee8 poses. Mace/wood/offhand coverage,
composition and constructor qualification remain separate. Current installed
client package stays `production-bindings-c494177f9ef03e3d`. Do not import loose
Factory files over that package or treat a two-sword demonstration as coverage
of every actual equipped weapon.

## The user's boundary

Every wielded weapon keeps its authored sprite body. Use the modular weapon's
separate weapon/offhand sheet, mask, depth and normals. Do not construct a native
replacement blade/mace. Full authored-character weapons are baked into their body
sprite and their attachment support is deferred. Spiritual Weapon is a separate
summoned actor; it is not an exception for normal held equipment. Spirit Guardians
is a different effect.

Flame Blade now uses the Scimitar sheet family; Devotee's Mace uses the Mace sheet
family. Their old native-body assignments/suppression and creation-ancestry renderer
were removed. Existing Factory native blade/mace sources remain unmodified but are
not selected. Do not relabel those whole-body sources as coatings.

## Authoring homes

| Home | Owns | Existing implementation |
| --- | --- | --- |
| `PresentationGear.effects: Array[PresentationEffectUse]` | Intrinsic sustained item decorations, independent of the sprite body | New compiled `BodySourceIndex.item_effects`; common NativeItems → Timeline → NativeSpellRenderer → Studio path |
| `PresentationGear.impact_effects: Array[PresentationEffectUse]` | Finite hit-contact VFX authored on the weapon | Actual attack occurrence → common finite phase compiler → native renderer/Studio; no persistent item clock |
| Condition Resource effects/lifecycles | Temporary item enchantments and actor-owned buffs | Existing actual condition UUID, application/sustain/removal and exact affected/current item provider |
| Spell/action Resource effects | Finite cast, release, swing/contact, impact, audio | Existing ordered event component/marker clocks; do not put these cues on intrinsic item membership |

An actor-owned buff such as Divine Favor follows that actor's eligible weapon.
An item-owned enhancement follows its exact affected item. The backend owns those
facts. Renderers must not infer a new enchantment, hit, timer, damage or lamp.

## Executable source example

Use `tests/fixtures/wielded_weapon_overlay.tres`. It stages the real delivered
`conditions/continuation/condition_coating_fire_persistent/sustain` twice on the
same real Flame Blade item, proving distinct authored uses, immutable art sharing
and separate native occurrences. This is test-only staging, not production artwork.

The relevant Resource shape is:

```gdscript
# Inside a PresentationGear resource that retains its existing family/slots.
effects: Array[PresentationEffectUse]

# Each sustained intrinsic use:
clip = "<delivered clip_id>"
selection = "<optional delivered selection>"
role = "sustain" # or attached
at = "owner_start"
attachment = "recipient_weapon"
recipient_slots = PackedStringArray("weapon")
follow = true
scale = 1.0
# orientation, rotation_degrees and offset are authored placement values.
# The first intrinsic arm uses source_rate=1; source shape/material stays in Factory.
```

The builder retains the exact `<gear Resource path>::effects/<ordinal>` and
projects typed `recipient_slots` into the existing `entity_geometry` input.
`extra.equipment_slots` can restrict an intrinsic use to actual main/offhand
melee/ranged equipment slots. There is no new runtime JSON catalog or registry.

This first intrinsic arm is deliberately **sustained while the actual item is
shown**: no delayed/finite cast/application/removal staging is accepted there.
The offline builder rejects those unsupported windows, absent optical slots and
sources declaring native `created_item_binding`. Nondefault source rates are also
rejected in this first intrinsic arm. Conditions and event-owned
spell/action cues already provide the separate finite/lifecycle authoring homes.

## Actual runtime operands the Factory may consume

The current prepared measured coating accepts `root_path`, `owner_state`,
`weapon_binding`, `entity_geometry` through its existing public setters.

- `weapon_binding`: actual item_uuid/item_id, actual holder_uuid,
  equipment_slot/render_slot, present/observed/equipped/suppressed and live authored
  hand point. Intrinsic uses have `owner_kind="item"`, `owner_uuid=item_uuid`,
  `binding_origin="intrinsic_authored_item"` and `authored_effect_source` equal to
  the real Resource locator. **No fake condition/effect UUID is sent.** Existing
  temporary condition uses retain their actual effect_uuid. A legacy source that
  insists on unavailable contribution/admission fields remains visibly unsupported.
- `entity_geometry`: only the exact currently displayed modular weapon channel;
  world optical positions/normals/pixels, exact item/equipment slot and geometry
  revision. Existing source sharing/preparation supplies these; do not bake a
  review character, hand position, camera view or weapon mesh into the source.
- `owner_state` for an intrinsic use: sustain with owner/source age since first
  displayed admission. This is an optical clock, **not item creation time or
  gameplay expiry**. It must never start an invented cast, hit or retirement.
- The renderer supplies current root placement and live weapon geometry through
  the same production path used in Studio. Mutable source clocks/instances are
  private to each use; textures, meshes and other immutable sources may share.

On initial attachment an ordinary enchanted item needs no historical creation
spell. Equip/unequip and loss of visual disclosure control visibility; re-equipping
resumes the retained intrinsic clock. Creation/lifetime of Flame Blade remains
actual backend item state. A sensory-only reveal also admits the effect without
waiting for an unrelated actor/HP update.

## Tracks and review

Studio gives each item+authored use its own `Weapon effect` span and `Weapon
surface` child. The row retains clip, Resource source, actual item/holder,
attachment, declared input channels and shared-renderer method. Existing native
light/material channels are inspection children of that same component, not
another scheduler. Seeking/looping reconstructs actual ordered membership.

Do not paint a trail, hit flash, sound or light on the timeline unless its actual
rendered event/resource owns it. Weapon on-hit accents use the finite arm below. Damage-attribution-dependent
riders, hit material choices and audio specializations remain separate; no
additional damage/result is invented from the VFX.

## Weapon impacts — additional user requirement

Weapons may author a finite **on-impact effect** beside their sustained coating.
A flaming/icy weapon can therefore carry both a lasting fire/ice treatment on its
sheet and a separately staged flame/frost contact burst at the recipient.

The typed field is `PresentationGear.impact_effects: Array[PresentationEffectUse]`.
An executable test-only example is `tests/fixtures/wielded_weapon_impact.tres`:

```gdscript
# One use in Gear.impact_effects; the existing weapon sprite remains unchanged.
clip = "spells/fire_bolt/default/impact" # existing test source; Factory may supply a dedicated weapon impact
role = "impact"
at = "body.impact"
attachment = "recipient_body"
follow = false
# Optional delay is relative to the attack impact marker, never its receipt time.
```

This arm is event-owned, distinct from `Gear.effects`:

- Select from the actual AttackFact's **source_item_uuid + source_item_id** and
  actual source/target, not a weapon that happens to be equipped when rendering.
- Emit each authored use once per actual **Hit/Crit attack occurrence**. Misses,
  unresolved/cancelled, unarmed/natural or absent exact item identity emit nothing.
  Opportunity attacks and extra attacks remain separate actual attack occurrences.
- Use the existing attack track's `impact_ms`: melee contact or projectile arrival.
  Each native source plays its own finite authored span. Received packet time and
  persistent coating age are not the impact clock.
- Do not dispatch from every damage packet: physical and elemental packets or
  damage/life descendants must not duplicate the burst. A zero-damage successful
  contact may still display its hit VFX; immunity does not erase the hit. The fire
  artwork does **not** assert that fire damage occurred.
- First placement is a creature's existing authored body contact/anchor with its
  observed position/elevation. The protocol does not claim a physical hit point.
  Object contact and damage-attribution-dependent source constructors remain named
  unsupported inputs, not guessed targets or manufactured damage.

The impact retains a small contact receipt rather than following the recipient's
later body. A killing hit can remove a faction's visual contact before the final
AttackFact arrives. The compiler selects that same attack's latest genuinely
disclosed recipient cut at contact, excluding nested attacks and later-only
disclosures, and samples its actual body track. Source position/elevation also
come from the attack track. An authored delay cannot substitute a later facing
or move the impact; seek/loop reconstruct the same receipt. Missing attack contact
markers remain missing. No other faction's state or surviving fake actor is used.
This first arm requires `follow = false`; sustained recipient treatments belong
to their actual condition, not an impact that follows a later body.

A Factory source may declare public input `weapon_impact`; the common native
setter bridge passes the actual packet:

```gdscript
{
    "operation_sequence": <actual operation sequence>,
    "occurrence": "<actual attack occurrence index>",
    "lineage": "<actual attack lineage index>",
    "source_item_uuid": "<actual item UUID>",
    "source_item_id": "<actual content ID>",
    "weapon_slot": "MELEE_MAIN", # actual slot, not a default
    "source_entity_uuid": "<actual attacker UUID>",
    "target_entity_uuid": "<actual recipient UUID>",
    "attack_outcome": "Hit" # actual Hit or Crit
}
```

There is no fake spell cast, persistent condition owner or fabricated elemental
DamageResult in that packet. Source preparation still runs through the existing
common group/resource path before ordered display. Effect-only programs can use
ordinary root/target inputs and the public packet; this first arm does not project
special result-dependent constructor values. Those must be reported unsupported.

Studio's `Weapon impact` row is nested under the actual attack and retains its
exact `<gear Resource path>::impact_effects/<ordinal>`, source item, event packet,
finite source span and shared renderer diagnostics. It is independent of the
persistent coating row. Use the same native source/channel inspection and replay
seek/loop path rather than a separate weapon timeline.

The Factory delivery should identify **both** sustained and impact clips/Resource
uses for each weapon treatment, their finite spans and declared inputs, keeping
those phases independent. Initial client proof uses an existing fire impact as
test-only staging; it is not approval of a production flame/ice impact's art or
permission to rescale spell explosions into weapon impacts indiscriminately.

## Delivering Factory work

Use the Factory's existing production Resource/selection and complete sealed
package workflow. Do not write client runtime code or copy mutable source fragments
into the installed package. Keep the source a coating/decoration against the
supplied optical surface, preserving base weapon pixels. Start with one modular
main-hand sustained flame treatment; author quality can then be reviewed on that
real path. Return its exact clip/selection/declared inputs and source-clock behavior.

Save the Factory's reply at
`VFXFactory/docs/NDCLIENT_MODULAR_WEAPON_EFFECTS_DELIVERY_HANDOFF_2026-10-20.md`,
with its normal immutable delivery identity, source Resource locations, compatible
input declarations and remaining gaps. Client Gear/Condition/Spell assignments
remain in their existing authoring folders; acceptance of new artwork is separate.

## Explicit gaps, not requests for invented substitutes

- Full-character/baked-in weapon segmentation/registration: deferred by the user.
- Offhand: separate sheet/item identity resolves, but no authored offhand socket
  is qualified yet. Never borrow the main hand's point.
- Dropped/inventory item VFX and complete real transfer qualification: incomplete;
  this first surface contract is the currently held modular weapon.
- Frozen engine Magic Weapon does not publish snapshot_item_effect membership;
  Shillelagh exposes affected_item_uuid on its actor condition. The existing
  PlayerItem.effects contract should be populated where needed, not replaced.
- Contribution winner semantics, some rider/contact attribution and spell-created
  item public lifetime links need separate backend evidence/fixes. Do not add
  fixture UUIDs or assume that source presence supplies those facts.
- Compatibility/conflicting appearance composition, attack trails, attributed rider
  accents and final performance/visual qualification remain separate work. Two concurrent
  coating occurrences prove the framework, not every artistic combination.

## Reproduce the client proof

```sh
bash tools/run_tests.sh --only wielded_weapon_sheet_checks,wielded_weapon_effect_checks,wielded_weapon_effect_render_checks,native_weapon_input_checks --jobs 2
bash tools/run_tests.sh --only wielded_weapon_impact_checks,wielded_weapon_impact_render_checks --jobs 2
```

The GPU proof uses the actual original Amber journal and current Windows
Forward+/Vulkan renderer: 22 checks pass, two private coating occurrences,
225 changed framebuffer pixels while the real Melee4 sprite remains rendered.
First/second construction were 0.739/0.109 ms in that isolated run. This is not
an end-to-end gameplay FPS or no-spike acceptance. The headless two-faction proof
also checks early resource requirements, exact independent tracks, no forged
condition identities, immutable membership cuts and seek/loop restoration.
Captures/report: `.captures/weapon-effects/` and
`.runtime/weapon-effect-render-checks.json`. Original facts are unchanged.


Final bounded evidence: nine affected gates pass (3,386 counted assertions),
`.runtime/tests/20261019T220204Z/`. The subsequent receiver-witness fix passes
24 ownership +22 native assertions with zero script/resource/engine errors,
`.runtime/tests/20261019T220343Z/`. A short plan/antislop/antiOOP review caught
and corrected sensory-only admission, per-use Studio identity, actual draw
witness propagation and the supported source-clock boundary. No owned Godot or
backend process remains open after these finite tests.

### On-impact evidence, 20 October

The original, unchanged Amber and Blue attack/death journals both pass through
the production fold/compiler/Studio path. The new checks verify one impact per
real attack, exact item/recipient/occurrence, actual melee contact, native source
span, correct event parent/Resource, finite seeking/looping and killing-contact
retention. Separate value contracts check misses, cancellation, absent identity,
zero-damage Hit/Crit, newer pre-contact appearance, nested attacks, later-only
disclosure and delayed facing.

The focused seven-gate batch passes **226 assertions**: 49 new impact assertions,
15 native impact assertions and the existing sheet/coating/input/order checks.
There are zero script/resource/engine errors. Report:
`.runtime/tests/20261019T222437Z/`. The native test contributes 111,622 changed
framebuffer pixels while the real Melee2 sword sheet remains rendered, with a
2.944 ms isolated source construction. Its contact is 1,166.67 ms and its finite
tail ends at 1,416.67 ms on the replay clock. This large spell-impact source is
**test-only**, proving dispatch and pixels rather than accepted weapon-burst art,
production scale or gameplay performance.

Captures/report: `.captures/weapon-impact/{impact,plain}.png` and
`.runtime/weapon-impact-render-checks.json`. The authoring, shared runtime path and
Studio track are implemented in the private worktree; no new production coating
or weapon-impact assignment has been installed. The full migration, the separate
actor-copy shader blocker and the explicit gaps above remain open.

Final contact-marker/authoring checks also pass: 189 assertions across
`native_action_cue_checks`, `wielded_weapon_impact_checks` and its native render
check, `.runtime/tests/20261019T222604Z/`. The broader default fast suite is **not
green**: 56 of 113 tests pass and 57 fail, recorded in
`.runtime/tests/20261019T222459Z/summary.json`. Failures include old/missing
recording inputs and stale fake-world/test contracts; this bounded weapon cohort
does not qualify or repair that whole suite. The progress ledger records the
examples; all new weapon checks pass. Test-written tracked reports were restored
and no owned test process remains open.
