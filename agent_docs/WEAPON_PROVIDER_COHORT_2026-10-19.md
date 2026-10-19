# Exact weapon input provider — 19 October 2026

This implements the shared weapon-input cohort in the schema/authoring/conditions plan. It does not qualify native pixels or complete the missing item-condition publication.

`presentation/native_weapon_inputs.gd` resolves an authored weapon/offhand optical channel against the actual displayed layer's `item_uuid`, then the canonical actor `visual_loadout` equipment slot. A public `affected_item_uuid` or actual item target remains exact; it cannot be replaced by a caster's first weapon. Actor-owned effects cannot follow another holder. Ambiguous slots, absent item records, stale displayed equipment and missing condition identities remain unavailable.

`native_inputs.gd` supplies one complete weapon packet before its exact-item geometry. Surface packets carry item UUID, holder and equipment slot. The generic input loop does not overwrite the packet with partial factual metadata. Prepared consumers cache their receiver-relative hand and source pose; translation does not repeatedly upload a co-moving item, and a changed source pose refreshes the actual world hand before geometry is rebuilt. Only the relative comparison tolerates float32 cancellation; supplied coordinates are not quantized. Immutable physical sources can share, while item and recipient identity remain private.

`spell_placement.gd` now registers `recipient_weapon` at the actual holder's authored main-hand pose. The current missing offhand socket is explicit. Source/image preparation requests the exact holder and optical slot; it does not warm every weapon. Ordinary `attachment=item` remains the separate unavailable-placement path owned by the parent task.

| Remaining input | Exact limit |
| --- | --- |
| Magic Weapon and Sacred Weapon owner membership | The frozen engine's `MagicWeaponEffect` and `SacredWeaponEffect` do not override `BaseCondition.snapshot_item_effect()`, whose default is `None`. Their item-owned condition/effect UUID and lifetime are therefore absent from `state.items[].effects`. A successful cast is not a persistent membership substitute. |
| Supported schema16 suppression | Active Antimagic suppression is retired, as documented by frozen `dnd/player/compatibility.py:112–136`, which rejects active legacy suppression archives. The provider therefore supplies `suppressed=false` unless actual input explicitly overrides it. No additional server verdict is required for this supported schema. Spatial `SpellSuppression` cells remain a separate contract. |
| Legacy contribution admission | Legacy `Ownership.visible()` additionally consumes `contribution_active` and `decoration_admitted`. These are not universally required new wire fields: contribution belongs to the actual owner's semantics and decoration admission belongs to renderer selection. Their legacy initialization/projection remains explicit and unresolved here; no condition-ID whitelist or universal contribution assumption is added. Missing legacy operands report `weapon_legacy_admission_not_bound`. Prepared Measured does not require or wait for these two fields. |
| Constructor ownership | Legacy source resources retain their configured owner/effect identity. Actual identity correctly fails against fixture identity until the shared constructor adapter supplies real operands. The provider does not rewrite Factory assets. |
| Offhand pose | Exact offhand item/slot/geometry can resolve, but the current client has no authored offhand hand registration. It does not borrow the main hand. |
| Divine Favor hit accent | `hit_input` requires the actual applied rider/contact observation. This cohort does not synthesize hit or damage data. |

Focused headless evidence:

- `tests/native_weapon_input_checks.gd`: **44 checks, zero failures, script/resource errors or warnings** in `.runtime/native-weapon-input-checks.log`. Exercises actual prepared Magic Weapon, Divine Favor, Sacred Weapon and Shillelagh setters without invented suppression/contribution fields, shared-rig actor isolation, exact target/slot, ambiguity, wrong owner, unequip, explicit suppression and unsuppression overrides, restoration, no repeated unchanged/co-moving upload, changed-pose hand refresh, constructor identity rejection and cleanup retaining physical source layers. The supplied optical samples are a named setter-contract fixture, not a capture of production weapon art.
- Existing `tests/native_input_binding_checks.gd`: **52 checks, zero failures, script/resource errors or warnings** in `.runtime/native-weapon-input-regression.log`.

Run either headless with the project's current absolute Windows `--path` and `--script res://tests/<name>.gd`. These are input/consumer ownership checks. Real schema-16 membership, native visible output/restoration, first-use timing and crowded-map cost remain separate gates. No build, GPU run, Factory change or engine change was performed by this cohort.
