# Factory follow-up: explicit spell alternative predicates and source binding

20 October 2026. The client now supports shared typed per-application variant dispatch. This handoff asks for authoring/source data, not a new renderer or a vendor edit in the client checkout.

For an alternative intended to replace the spell's finite event cues, provide an explicit typed predicate using actual current public facts, for example:

```gdscript
when = {"attack_outcome": ["Miss", "Crit Miss"], "target_kind": ["creature"]}
```

Fields combine with AND and values in each array with OR. Current accepted public enums are `attack_outcome = Hit | Miss | Crit | Crit Miss` and `target_kind = creature | object`. Missing/null facts retain the baseline. Empty `when` deliberately stays unsupported; neither `kind`, `value`, ID nor an art title dispatches it. Element, passive rider or area branches still need their actual public fact/provider contract; titles are insufficient.

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

The Resource retains all 130 imported alternatives/240 cues across 43 current native owners, their metadata and gaps. No production alternative was automatically enabled. Source presence, input provider, recorded scenario, native output and user approval remain separate facts.

For each proposed predicate:

1. Identify the original public application fields that prove it, including mixed outcomes within one cast. Preserve actual caster identity; recipients' impact/delivery may differ while one caster animation/cast owner remains shared.
2. Supply source-compatible endpoints/constructor inputs and the intended exact native clips. Replacing cue lists cannot inherit numeric base owner/event/exclusion indices that refer to another list. An outcome alternative cannot replace the common caster-body recipe.
3. A Miss impact is allowed only when the explicit predicate names that actual Miss/Crit Miss and a replacement effect list intentionally authors its partial contact. Target-kind-only variants or empty inherited effect lists retain ordinary Miss suppression.
4. Keep a concrete `dispatch_gap` for known unresolved source binding. Do not silently convert review-stage coordinates to gameplay facts.

Concrete first source gap: `spell.ray_of_sickness` / `ray_of_sickness_miss_native` imports `bg3-36/ray-of-sickness/miss` with fixed live endpoint `[2, 0.8, 0.65]`. It remains **`review_endpoint_position_not_bound`**; the client did not invent an optical miss offset or substitute another spell's art. Please provide its actual supported presentation endpoint contract before enabling it.

Actual original Miss evidence is ready at `tests/fixtures/schema16/typed-variants-miss/{amber,blue}/journal`: sequence 7 occurrence 45 (Amber) / 53 (Blue), one legal Ray cast after actual Dodge, fixed seed 2. Whole independent streams are unchanged. The native dispatcher test may use an explicitly test-only predicate on the existing source-compatible Ray delivery; that proves dispatch/render ownership and does **not** accept this missing Miss-art binding.

Preparation already has the required ownership: eligible alternatives warm only when that capability is actively selected, as optional bounded source work; the exact selected application becomes required after disclosure. Do not request whole-library/all-variant startup warming. Existing default art, body animation, event order, clocks and materials remain unchanged when no predicate matches.
