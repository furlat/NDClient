# Production spell → existing condition handovers

20 October 2026. Phase 3–4 production ownership cleanup against installed
`runtime-e102c29dec58524b`. This changes typed spell ownership only; no source
art, shaders, registration, native inputs, body animation, or predicate changes.

Each row adds `owner_kind = "condition"`, the exact `owner_ids` below, and
the listed `owner_cues`. Existing `NativeSpells.owned_cues` removes those bounded
cast copies because the selected condition already supplies its complete body
lifecycle. `NativePersistent` supplies application/hold/removal from that actual
condition UUID. The separate finite accents remain event cues.

| Spell Resource (`authoring/abilities/spells/spell.<id>.tres`) | Exact condition owner | Owner cue indices | Event cues retained | Installed condition selection |
|---|---|---|---|---|
| `acid_arrow` | `condition.spell.acid_arrow` | 2 residue | 0 delivery, 1 impact, 3 tick, 4 spatial patch | `condition_acid_arrow_persistent` |
| `branding_smite` | `condition.spell.branding_smite` | 1 condition, 2 retire | 0 impact | `condition_branding_smite_persistent` |
| `divine_favor` | `condition.spell.divine_favor` | 2 sustain, 3 retire | 0 windup, 1 application, 4 hit | `condition_divine_favor_persistent` |
| `ensnaring_strike` | `condition.spell.ensnaring_strike` | 1 condition, 3 retire | 0 application, 2 tick | `condition_ensnaring_vines_persistent` |
| `hex` | `condition.spell.hex.quarry` | 2 condition, 4 retire | 0 windup, 1 application, 3 hit | `condition_hex_persistent` |
| `hunters_mark` | `condition.spell.hunters_mark.quarry` | 2 condition, 4 retire | 0 windup, 1 application, 3 hit | `condition_hunters_mark_persistent` |
| `magic_weapon` | `condition.spell.magic_weapon` | 2 sustain, 3 retire | 0 windup, 1 application | `condition_magic_weapon_persistent` |
| `searing_smite` | `condition.spell.searing_smite` | 1 condition, 2 retire | 0 impact, 3 tick | `condition_burning_persistent` |
| `shillelagh` | `condition.spell.shillelagh` | 0 equipped-item interval | none (body/hand casting stays authored) | `condition_shillelagh_persistent` |
| `starry_wisp` | `condition.spell.starry_wisp` | 2 hold, 3 remove | 0 delivery, 1 reveal | `condition_starry_wisp_persistent` |

## Source proof and boundaries

These are exact provenance matches, not inferred from labels. In
`assets/vfx/index.json`, each selection above declares the exact owner ID,
`body_channel_included = true`, `complete_visual_channels = true`, and an empty
`when`. Its `condition.source.phase` is the same original phase identified by
the held clip's `provenance.composition_source`:

| Owner selection | Original held phase under `authoring/` |
|---|---|
| acid arrow | `gpu-cached-v382/phases/f89300769a4d1221.tres` |
| branding smite | `gpu-cached-v382/phases/f4e38d027b07db1c.tres` |
| divine favor | `gpu-cached-v382/phases/9bf84028824a8089.tres` |
| ensnaring vines | `gpu-cached-v382/phases/1e19fc48d6f43a63.tres` |
| hex | `gpu-cached-v382/phases/73eeccb3e54f61f5.tres` |
| hunter's mark | `gpu-cached-v382/phases/fe2be1aa023d626a.tres` |
| magic weapon | `gpu-cached-v382/phases/ad825e90b0cd3733.tres` |
| burning/searing smite | `gpu-cached-v382/phases/785d9aba871b1a02.tres` |
| shillelagh | `gpu-cached-v382/phases/4b01bea1b3ffc00e.tres` |
| starry wisp | `gpu-minor-v395/phases/399e4f9c413d79ee.tres` |

Prepared `assets/vfx/conditions/<selection>/application.gd` constructors retain
those same actual body/item treatments, then supply native application and
removal envelopes on one owner's age. Shillelagh, Magic Weapon and Divine Favor
explicitly request `weapon_binding`; this does not replace wielded sprite sheets.
Hex/Hunter's Mark hand over only their quarry condition, never the distinct
caster sustain condition. All ten typed conditions already allow package
lifecycles; no suppression override or new alias is added.

Application, impact, tick, hit and reveal accents are preserved even when their
existing producer inputs remain unavailable. In particular this does not pretend
to implement their observed damage, quarry contribution, or tick semantics.
No new production variant predicates are enabled; existing unselected drafts
remain unchanged. Aid, Bless, False Life and Sacred Flame are untouched.

No other current missing handover was proven by this audit: Flame Blade's hand
preparation, Sunbeam's beam/contact, Sleep's area/projectile, Glyph of Warding's
armed object, and summon birth cues have different actual phase/owner semantics.
Their `applies_conditions` lists are not grounds for dropping them.

## Actual original recording evidence

Original frozen211 baseline directories copied byte-for-byte from
`.runtime/studio-library/cases/spell.<id>__baseline/` into the durable
`tests/fixtures/schema16/production-condition-handover/spell.<id>__baseline/`:

| ID | Original directory | Actual condition UUID (each audience inspected independently) |
|---|---|---|
| acid_arrow | `20261019T141826.056415Z` | `7f972fc8-77ea-44d0-aade-974a16ad225e` |
| divine_favor | `20261019T142511.372333Z` | `cf8a3cef-4e00-4c5d-b654-6a817ede9f2a` |
| hex | `20261019T143104.526336Z` | `e89b064c-3682-4e71-a760-dc9c72bf6582` |
| hunters_mark | `20261019T144540.033289Z` | `40b6ea31-86b8-4c7e-8ba8-0806343960c9` |
| magic_weapon | `20261019T144735.744552Z` | **No Magic Weapon condition was emitted.** This is a genuine completed cast with Concentrating only, not a lifetime proof. |
| shillelagh | `20261019T144916.773864Z` | `cdd5a0b6-1ff1-4036-8a24-5b46f752a2db` |
| starry_wisp | `20261019T143631.559288Z` | `fb0b0d94-3e2c-479e-8eb5-5e73313c2512` |

All six positive memberships occur in packet8. Starry Wisp's actual application
occurrence is Amber65/Blue69; matching raw audience-local occurrence IDs is
never assumed. The Magic Weapon baseline targets an actor without an affected
weapon and therefore supplies no same-family owner. A legal equipped-target
Magic Weapon lifecycle remains a scenario gap.

Branding Smite, Searing Smite and Ensnaring Strike have actual frozen producer
`game_failed`/indeterminate command failures in the existing baseline corpus.
Their metadata is source-proven; no successful cast, application/removal, or
native draw is claimed for them.

## Focused qualification

`tests/production_condition_handover_checks.gd` checks all ten typed ownership
records and the existing native phase filter, preserves every listed event cue,
then uses the seven existing original two-seat baselines through SDK fold,
ordinary compiler and Timeline. It requires six actual UUID-owned admissions,
the real no-owner Magic Weapon negative, no bounded duplicate held copies,
immutable packet facts and exact canonical drain. It accepts
`--recordings-root=<original cases root>`; default is the durable fixture above.
All 147 original JSON files (three scenario/recording/command records and nine
packets per independent audience for each of seven cases) are preserved. No
configurations, authentication, logs, artwork, or captures are copied. No
originals are edited or generated by this test.

The headless gate passes649 assertions with zero failures, script/engine errors
or owned leftovers (`.runtime/tests/20261020T103720.479266Z/summary.json`).
Original baselines do not include all removals,
equipped-item changes or full interactions. These checks do not qualify pixels,
first-use latency, final visual acceptance, or the previously missing finite
event-input providers.
