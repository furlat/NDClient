# Modular weapon effects — implemented client contract

20 October 2026. Client implementation worktree:
`C:/Users/tommaso/Documents/Dev/NDClientGodot-authoring-schema`, branch
`codex/schema16-unit-a`. This is a working first contract for the Factory author,
not a claim that every enhancement or spell has been migrated or visually approved.
The receiving checkout has not yet received this cohort.

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

## Three authoring homes

| Home | Owns | Existing implementation |
| --- | --- | --- |
| `PresentationGear.effects: Array[PresentationEffectUse]` | Intrinsic sustained item decorations, independent of the sprite body | New compiled `BodySourceIndex.item_effects`; common NativeItems → Timeline → NativeSpellRenderer → Studio path |
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
rendered event/resource owns it. Finite attack/contact accents must use actual
server event/result evidence and remain a later event-owned authoring step.

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
- Compatibility/conflicting appearance composition, attack trails/contact accents
  and final performance/visual qualification remain separate work. Two concurrent
  coating occurrences prove the framework, not every artistic combination.

## Reproduce the client proof

```sh
bash tools/run_tests.sh --only wielded_weapon_sheet_checks,wielded_weapon_effect_checks,wielded_weapon_effect_render_checks,native_weapon_input_checks --jobs 2
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
