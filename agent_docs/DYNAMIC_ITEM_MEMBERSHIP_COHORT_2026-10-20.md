# Dynamic item-effect membership — 20 October 2026

This bounded Phase 4 cohort extends the existing item decoration path. It does
not assign production artwork, replace modular weapon sheets, infer elemental
damage, or introduce another reducer, scheduler or source registry.

## Actual public evidence

The original single-seat `divine-arm` party journal contains the Devotee Mace
`4df65b6b-e8c4-42e6-928d-26e74b579ea1`. Packet 8 discloses its permanent effect
`f13a6583-c3c4-42d8-9fb9-eeff69686626`, behavior
`item.property.additional_damage`, damage type `Radiant`. Its actual
`contribution_uuid` equals that effect UUID; `applied_source_event_cursor` is
null. Membership does not identify a past enchantment cast or a later damage
packet. The recorder's later missing Healing Incense choice remains a failed
scenario step; it is not excused by this provider.

The public schema already provides whole `ItemRecord.effects`, ordered
`item_effects`, and `item_effect_duration` updates. Missing membership in the old
Magic Weapon/Sacred Weapon recordings remains a producer/scenario gap in those
specific originals. This real Devotee membership is separate evidence.

## Existing authoring and ownership

Two optional typed fields on `PresentationEffectUse` select public membership
inside the existing `Gear.effects` array:

```gdscript
item_effect_behavior_id = "item.property.additional_damage"
item_effect_damage_type = "Radiant"
```

An empty behavior retains intrinsic item semantics. A nonempty behavior matches
that exact public member, optionally restricted by its actual damage type. The
character builder emits these into its existing `BodyIndex.item_effects` cue
index. Selector admission runs offline. A damage-only selector and dynamic
selectors on `Gear.impact_effects` are rejected: membership alone cannot prove
elemental impact attribution.

`NativeItems` retains its one passive Timeline owner table. A dynamic identity is
the real item UUID, existing authored-use locator, and real effect UUID. Members
are admitted through actual ordered membership rows or disclosed holdings. An
explicit membership row with no currently disclosed holder starts a hidden
owner and preserves its clock for later disclosure. Bare cached item metadata
alone cannot admit an owner. Inventory membership may start an owner before it
is wielded. Unequip or loss of disclosure hides its appearance
without restarting the membership clock. Explicit removal ends that exact
membership; reapplication starts a new clock. Duration-only metadata updates
preserve the clock. Different effects and intrinsic decorations remain separate.
Ended dynamic owners retire in the existing sampler strictly after their end
time. Exact same-clock transient inspection remains available, while active
undisclosed membership and intrinsic clocks survive; Timeline uses its existing
resource revision when this retirement changes the owner set.

The SDK captures item before/after arrays once at its existing canonical writes,
in native row order, and forwards those captures through existing compiler
commits, Timeline publication and Recording history. This retains same-event
remove/reapply without another fold. A final-absent apply/remove can expose a
zero-duration membership inspection record; it cannot supply a native draw.

Common `native_item` paths supply placement, owner clock, optical geometry and
weapon-surface witnesses. Dynamic `weapon_binding` uses
`binding_origin = "observed_item_effect"`, the actual item/effect/contribution,
and its currently disclosed holder/slot. Intrinsic art still has no fake
`effect_uuid`. Null applied-source provenance is retained as unknown. Actor
conditions keep their independent ownership and finite attacks keep their
existing contact semantics.

The delivered prepared Measured weapon sources require exact item/holder,
observed equipped eligibility, actual hand/weapon geometry and suppression.
Their receiving admission does not require a Sacred Weapon gameplay identity or
legacy `contribution_active` / `decoration_admitted` fields. Schema16 has retired
the old Antimagic mechanism; no new public suppression field is invented.

## Qualification and acceptance boundary

- Test-only `tests/fixtures/dynamic_weapon_overlay.tres` selects an existing
  prepared coating for two dynamic uses plus an independent intrinsic control.
  This is provider staging, not accepted Radiant artwork, a Sacred Weapon
  condition, or Fire damage on the mace. No production Gear resource changes.
- `tests/dynamic_item_effect_checks.gd` uses the unchanged original journal and
  independent Journal replay for canonical/Studio/seek proof. Its explicit
  extra-member, duration, removal/reapply and disclosure after-values are client
  contract controls, not new recorded server events.
- `tests/dynamic_item_effect_render_checks.gd` uses that same typed staging via
  `tests/dynamic_weapon_support.gd`. It checks both independent native uses,
  actual Mace-only optical geometry, source binding/contribution and pixels at
  the original equipment boundaries 237/239/240. Membership clocks must survive
  unequip/re-equip; seek/loop must replace private instances without changing
  authored source resources or original recorded groups. The native gate is
  prepared for the root's serialized GPU lane; it was not run by this worker.
- Root owns the SDK row gate, coordinated source build, focused headless run and
  native framebuffer qualification. Results belong in the root's current
  receipts; this document does not infer a pass from source implementation or
  setter acceptance.

```sh
python3 -B tools/run_tests.py --only dynamic_item_effect_checks
python3 -B tools/run_tests.py --only dynamic_item_effect_render_checks
```

Production visual assignment, offhand pose sockets, baked-character weapons,
dropped-item effects and elemental damage-result attribution remain separate
work. Existing wielded bodies remain the actual modular sprite layers.

## Bounded review checklist

- [x] Existing typed source/index and passive owner path; no second registry.
- [x] Exact public item/effect identities, no invented enchantment or outcome.
- [x] Ordered capture transport reviewed by the plan-adherence agent.
- [x] Dynamic headless gate:75 checks, zero failures/errors, including ordered
  unknown-holder admission, exact Studio links/transients,32 unique short-lived
  memberships and bounded retirement. Receipt
  `.runtime/tests/20261020T015415.644918Z/`. SDK row gate66, ActorRow817 and
  support356 also pass in the root's receipts.
- [x] Exact Studio link/transient headless checks.
- [x] New native framebuffer gate:82/82; actual Taunt registration gap retained.
- [x] Bounded plan-adherence/correctness and anti-slop/anti-OOP provider review.
  The unknown-holder and retirement findings above were repaired in the same
  existing owner path. Root owns final full-suite and native/publication gates.

## Authored grip and replay source ownership

The original occurrence237 equip samples the real `Taunt` body pose. That pose
has `clasped_hands` registration but no weapon `hand` registration. The receiver
does not borrow clasped hands: the exact missing grip remains unavailable and
hidden, while genuinely unprepared optical source bytes remain pending. This
does not complete Taunt weapon registration or change the separate invocation's
authored clasped-hands attachment.

The native harness requires that gap without a fatal publication error, then
uses original track boundaries and ordinary resting arbitration to locate a
later registered Idle inside the actual held interval. It must recover through
normal replay advancement in the same epoch and retain positive pixel, clock,
seek/loop and cleanup assertions. It never substitutes a body pose. If the
original interval has no registered Idle, the gate reports that missing input.

The first such advance exposed a replay ownership defect. Live publication
calls `world_published` for a prepared source-only cut, but replay publication
omitted that transfer; its next scene update treated the source-only candidate,
which deliberately has no full lighting/scenery packet, as a world replacement.
`Timeline.replay_publish` now invokes the same callback once after successful
atomic apply/cancel, retaining the actual prepared candidate. A full-world
callback returning false keeps normal scene publication. No-boundary and
rejected or consumed plans make no callback. No Lighting/Play empty-data guards
were added.

The75-check headless receipt also covers exact missing-versus-pending socket
policy and original source-only/full-world replay callback identity, readiness,
ordering and once-only ownership. Final native output remains pending the
root's coordinated source build and serialized qualification. Earlier native
failures remain in their original receipts.


## Native qualification

Root's serialized Forward+/Vulkan run now passes **82/82 checks**, zero
script/engine errors and clean owned teardown:
`.runtime/tests/20261020T015752.094638Z/`. Actual prepared coating output adds157
pixels in the first registered held cut and124pixels after re-equipping and
looping, with two distinct occurrences and the original membership clock.
The original Taunt interval remains an explicit missing-grip/hidden-output
case; a later registered Idle cut recovers normally in the same replay epoch.
No clasped-hands substitution, body-pose change or accepted artwork assignment
is made. The regression also exposed/fixed the shared replay source-only
publication callback, using the same exact prepared owner transfer as live.

Final headless ownership/callback gate is75/75 at
`.runtime/tests/20261020T015415.644918Z/`; native output is independent evidence,
not inferred from that headless result. Full source build/fast suite and live
publication/performance qualification remain root's later checkpoint gates.
