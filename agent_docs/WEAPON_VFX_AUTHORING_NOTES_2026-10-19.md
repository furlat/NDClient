# Weapon appearance and attached VFX — user correction

**Every weapon wielded by a character uses its authored sprite weapon layer or
its authored complete character. Native Godot weapon-body replacements are not
accepted.** Native VFX may decorate the actual weapon; they do not replace it.
Spiritual Weapon is a separately summoned actor, not a hand-held equipment body.
Spirit Guardians is a different effect and is not that exception.

The current implementation focus is **modular characters with separate weapon
sheets**. Full-character sprites have baked-in weapons; their attachment support
is deferred. Do not guess offsets, attach to the whole body or pretend a separate
weapon sheet exists for those characters.

## Correction applied to the two mistaken assignments

- `weapon.flame_blade` uses the existing `weapon.scimitar` Gear family: main
  `Melee4`, offhand `Offhand1`. The frozen engine explicitly describes Flame
  Blade as a temporary real fire scimitar.
- `weapon.devotees_mace` uses the existing `weapon.mace` family: main `Melee9`,
  offhand `Offhand2`. The actual engine builder supplies `visual_item_name="Mace"`
  and `WeaponKind.MACE`.
- Both native_appearance assignments and their unused native-body subresources
  were removed; the obsolete Gear field, compiled native-body index and equipment
  suppression branch are also removed. The delivered Factory sources remain unmodified but unselected.
  They contain blade/mace geometry and must not be relabelled as decorations.
- These Gear resources remain partial: a sheet body does not qualify fire,
  enchantment, contact accents or other attached native VFX. Current old native
  body-owner/pixel checks are superseded, not visual acceptance of this design.

`tests/wielded_weapon_sheet_checks.gd` checks built main/offhand sheet outputs,
absence of a native-body substitution and the exact Flame Blade UUID in both
original faction recordings. A character-domain rebuild is required before its
built-output assertions run. This note makes no new pixel approval claim.

## Existing homes and remaining work

| Owner | Existing authoring and runtime |
| --- | --- |
| Modular weapon body | `PresentationGear.slots`, `hands`, `ground`, family and variants describe the weapon sheets and dropped look. Tint is multiplicative. A Longsword uses `Melee2`; Flaming Scimitar currently uses `Melee4` with orange tint but no intrinsic native fire decoration. |
| Temporary enhancement | `PresentationCondition.effects: Array[EffectUse]` and delivered condition selections own actual application/sustain/removal. `NativeWeaponInputs` matches real affected item UUID, displayed holder, equipment slot and its separate weapon-sheet optical geometry. |
| Cast | Spell Resources own gestures, release, preparation, finite source cues and audio. A cast is not an item's lifetime or a substitute for a disclosed enhancement condition. |

The earlier native-body path required observed creation ancestry and private
admission before it could draw. That is not a requirement for showing an existing
weapon sheet. Actual item existence, equipment and any applied condition lifetime
remain authoritative; they must not be invented by native VFX or a timer.

Concrete gaps:

- Gear now has a typed native-decoration array that preserves its ordinary
  weapon sheets. Runtime membership, exact receiver, rendering and Studio
  qualification remain separate from the source/build contract below.
- Applied enhancement ownership already has an exact-item route, but not every
  needed server item-effect membership is currently published. Keep each actual
  item UUID and effect UUID; do not decorate the caster's first weapon instead.
- Offhand item/slot/surface can resolve, but production attachment explicitly
  rejects the missing authored offhand socket. Factory's independent Special1
  fixture is not production registration. Do not borrow the main hand.
- Item-attached effects on ordinary/dropped/transferred items are incomplete.
  Generic `attachment=item` currently exists only in the deactivated native-body
  path; Continual Flame and real drop/transfer presentation remain named gaps.
- Multiple decorations need separate source clocks and actual item/condition
  owners, with authored composition when they conflict. Hit accents require real
  applied contact/rider facts. An emitter must not invent damage, expiry or light.
- Frozen Magic Weapon/Sacred Weapon membership and legacy Factory admission gaps
  remain as recorded in the provider cohort. Prepared measured consumers do not
  require the legacy contribution/admission fields universally.

## Typed source/build contract now implemented

Keep Gear for **sprite body plus intrinsic native decorations**, Condition for
an applied enhancement and Spell for casting. `Gear.effects: Array[EffectUse]`
reuses the typed source, attachment, timing and sampling fields. EffectUse now
also exposes `recipient_slots: PackedStringArray`, selecting the actual modular
`weapon`/`offhand` optical channel. The characters builder compiles an ordered
`BodySourceIndex.item_effects[item_id]` cue list through the shared EffectUse
conversion, retaining `<gear resource path>::effects/<ordinal>` and source_index.
Typed slots project to the existing exact-item entity_geometry channel.
`slots`/`hands` are unchanged by effects, so the renderer keeps the weapon sheet.
The offline characters build requires explicit nonempty recipient_slots and
rejects a selected clip declaring `created_item_binding`: a native item-body
constructor cannot be relabelled as a decoration. This uses actual source input
metadata, not a spell-name blacklist or runtime validation. An authored offhand
receiver does not fill the still-missing production offhand socket.

`tests/fixtures/wielded_weapon_overlay.tres` is a test-only typed example using
the delivered measured fire-coating sustain source, not a native blade body.
It is not a production assignment or a claim of user art approval. The bounded
headless sheet test additionally checks its compiled cue and preserved Scimitar
body. No new artwork or effect identities are fabricated. Source/build edits
require the normal characters rebuild; runtime and Studio changes are owned by
the parent task and must be qualified together before handoff to the artist.

Uses emit through the existing Timeline/native renderer for real item membership.
Conditions retain their actual UUID and removal semantics; ordinary enchanted
weapons do not require a fictional creation spell. No separate item simulator,
replacement Godot mesh or whole-character weapon tint is needed.

Only the modular separate-weapon optical provider is in the first cohort.
Prepare and track decoration construction, first draw, source clock, actual
contact and removal using the common gameplay/Studio components. Physical light
comes from actual server optical sources; emissive artwork alone adds no lamp.


## Frozen-engine public data confirmed during discussion

The promoted frozen211b71134 already exposes `PlayerItem.effects` with
`ItemEffectPresentationState`: exact effect_uuid, behavior_id, optional
contribution_uuid/damage_type/application cursor and duration. Existing native
ItemEffectsRow/DurationRow reduction and observer projection already carry this;
observers get visible membership with duration withheld. Intrinsic weapon extra
damage publishes `item.property.additional_damage` members, and Continual Flame
implements snapshot_item_effect. Do not design a parallel item-effect schema.

Concrete producer gaps: MagicWeaponEffect currently inherits the default
`BaseCondition.snapshot_item_effect() -> None`; Shillelagh exposes
affected_item_uuid on the actor condition but no snapshot_item_effect override.
FlameBladeItem has its exact lifetime_condition_uuid internally, with a lifetime
marker on its caster; the public item record does not expose that creation
relationship directly. The current client recovers it only from real observed
creation ancestry/holdings. Fresh attach or another faction without that prefix
therefore remains unavailable.

Backend follow-up should first populate the existing item-effect contract for
actual relevant enchantments and created-item lifetime relationships, preserving
real effect UUIDs, ordered membership/removal and audience disclosure. Verify
contribution/winner semantics before adding a field. Keep VFX paths, materials
and artist timing in client/Factory Resources. This is a discussion note, not an
authorized or implemented engine patch; the official checkout remains read-only.


## Implemented first contract — 20 October

The source/build and common renderer/Studio path are now implemented and qualified
for **held modular sustained intrinsic effects**, with two independent test-authored
uses on one real item, preserved sheet body, actual receiving pixels and seek/loop.
This supersedes the earlier runtime/track gaps above for that bounded arm only.
There is no native-body appearance, origin reconstruction or fake condition UUID.
Dropped items, offhand registration, baked-in weapons and full transfer qualification
remain gaps. See the working [Factory contract and executable example](MODULAR_WEAPON_EFFECTS_FACTORY_HANDOFF_2026-10-20.md).
