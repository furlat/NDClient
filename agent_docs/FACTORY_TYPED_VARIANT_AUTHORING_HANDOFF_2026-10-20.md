# Factory follow-up: explicit spell alternative predicates and source binding

20 October 2026. The client now supports shared typed per-application variant dispatch. This handoff asks for authoring/source data, not a new renderer or a vendor edit in the client checkout.

**Client production update:** Ray of Sickness hit/saved, Dissonant Whispers
saved and Vicious Mockery saved now have exact client-authored predicates.
Those assignments did not require new Factory artwork or permission. Their
sources already supported actual endpoints and save feedback. Replacement cue
lists can explicitly set `override_owner_cues = true` and `owner_cues` (including
an empty list) to retain finite feedback without inheriting another cue list's
condition indices. [Current qualification and remaining gaps](PRODUCTION_INTEGRATION_CLOSURE_2026-10-20.md).

For an alternative intended to replace the spell's finite event cues, provide an explicit typed predicate using actual current public facts, for example:

```gdscript
when = {"attack_outcome": ["Miss", "Crit Miss"], "target_kind": ["creature"]}
```

Fields combine with AND and values in each array with OR. Current accepted public enums are `attack_outcome = Hit | Miss | Crit | Crit Miss` and `target_kind = creature | object`. Missing/null facts retain the baseline. Empty `when` deliberately stays unsupported; neither `kind`, `value`, ID nor an art title dispatches it. Element, passive rider or area branches still need their actual public fact/provider contract; titles are insufficient.

Exact disclosed option identity is also supported:

```gdscript
when = {"effect_id": ["support.enhance_ability.strength"]}
```

This is literal `SpellFact.effect_id`, separate from a saving throw's effect ID.
The client now assigns the existing17 public forms across Bestow Curse,
Blindness/Deafness, Enhance Ability and Protection from Energy, borrowing one
current immutable caster/recipe and their existing condition owners. No new
spell-specific decoder or copied TypeScript recipe is required. Missing, null
and unknown values retain the baseline. Chromatic Orb, Acid Arrow and Sorcerous
Burst originals still carry null option IDs; do not invent elemental selectors.
[Exact forms, original journals and remaining gaps](PRODUCTION_OPTION_IDENTITIES_2026-10-20.md).

The one newly confirmed source request is Deafness's finite application: the
shared `review/blindness_deafness/back/lifecycle` is hardcoded Blinded. Its
Deafened option remains explicitly missing instead of playing that art. The
separate actual Deafened condition marker already works and must not be replaced
or counted as the missing finite source.

Saving-throw alternatives now have a shared application-result provider:

```gdscript
when = {"save_succeeded": [false]}
save_effect_id = "spell.circle_of_death.saving_throw"
```

The qualifier is mandatory and matches the exact disclosed `SavingThrowFact.effect_id`
inside the same native cast/application/recipient. Do not construct it from a
spell name: Ice Knife actually publishes `spell.ice_knife.burst`. The
[observed save IDs](FACTORY_OBSERVED_SAVE_EFFECT_IDS_2026-10-20.md) give current
original evidence for 31 capabilities. No damage is required to select a save.
Null, missing or duplicate results remain baseline with a named gap; declarations
have no recipient-save requirement. Different save effects are independent, so
opposite booleans on different effect IDs are not mutually exclusive predicates.
Rendering and Studio borrow the same cached application choice and evidence.

The Resource retains all130 imported alternatives/240cues across43 current
native owners, their metadata and gaps. Three explicitly authored saved-outcome
predicates and seventeen literal public option predicates are active. The remaining alternative count is not a count of missing
gameplay branches: condition/spatial/item ownership, review-only choices and
rejected artwork have separate meanings. Source presence, input provider,
recorded scenario, native output and user approval remain separate facts.

For each proposed predicate:

1. Identify the original public application fields that prove it, including mixed outcomes within one cast. Preserve actual caster identity; recipients' impact/delivery may differ while one caster animation/cast owner remains shared.
2. Supply source-compatible endpoints/constructor inputs and the intended exact native clips. Replacing cue lists cannot inherit numeric base owner/event/exclusion indices that refer to another list. An outcome alternative cannot replace the common caster-body recipe.
3. A Miss impact is allowed only when the explicit predicate names that actual Miss/Crit Miss and a replacement effect list intentionally authors its partial contact. Target-kind-only variants or empty inherited effect lists retain ordinary Miss suppression.
4. Keep a concrete `dispatch_gap` for known unresolved source binding. Do not silently convert review-stage coordinates to gameplay facts.

Concrete first source gap: `spell.ray_of_sickness` / `ray_of_sickness_miss_native` imports `bg3-36/ray-of-sickness/miss` with fixed live endpoint `[2, 0.8, 0.65]`. It remains **`review_endpoint_position_not_bound`**; the client did not invent an optical miss offset or substitute another spell's art. Please provide its actual supported presentation endpoint contract before enabling it.

Actual original Miss evidence is ready at `tests/fixtures/schema16/typed-variants-miss/{amber,blue}/journal`: sequence 7 occurrence 45 (Amber) / 53 (Blue), one legal Ray cast after actual Dodge, fixed seed 2. Whole independent streams are unchanged. The native dispatcher test may use an explicitly test-only predicate on the existing source-compatible Ray delivery; that proves dispatch/render ownership and does **not** accept this missing Miss-art binding.

Preparation already has the required ownership: eligible alternatives warm only when that capability is actively selected, as optional bounded source work; the exact selected application becomes required after disclosure. Do not request whole-library/all-variant startup warming. Existing default art, body animation, event order, clocks and materials remain unchanged when no predicate matches.
