# Vampiric Touch: positive healing and ordinary lifecycle

The first bounded recording succeeded, using the frozen schema16 engine
`211b71134ed15c89e62232587381f7e15a5961c3`, seed2. This is source scenario and
original public evidence, **not** qualification of held/repeat/healing VFX.

Durable originals: `tests/fixtures/schema16/vampiric-positive/`.
Both `amber/` and `blue/` retain all22 packets (sequences0–21) byte for byte.
The original `scenario.json`, `commands.json` with receipts, `choices.json`
capturing the offered repeat action, and `recording.json` are also retained.
`provenance.json` indexes the exact original facts. No host config, credentials,
server state, screenshots or generated presentation events were copied.

Original owned run:
`.runtime/scenario-vampiric-positive/20261020T043844.513424Z/`.
It completed13 legal commands with no recorder gaps. Its owned backend process
2734049 was confirmed stopped; no Godot or graphics run was launched.

## Reproducible recipe

`tools/studio_cases/cases.py::vampiric_positive_study()` is included in
`first_cohort()` and can be selected with:

```sh
python3 tools/studio_cases/record.py \
  --only spell.vampiric_touch/positive_healing_lifecycle \
  --out .runtime/vampiric-positive-repeat --timeout 200
```

The ordinary encounter setup applies40 starting Force damage to the level20
generic caster. Independent frozen SDK reduction of each initialization gives
120 normal HP. The initialization's raw BodyRecord still begins at160; its
original initialization rows apply the wounds. Reading only that raw birth
would give the wrong starting state. Starting damage is setup, not an invented
in-record injury event.

The ordered player commands approach, cast level3 at an actual enemy, move
while the owner remains active, end the ordinary turns, choose the offered
`action.spell.vampiric_touch.strike`, drop concentration and walk after removal.
The engine also genuinely emits opportunity attacks and a Shield reaction on
this route. Those original results were preserved rather than suppressed to
make the scenario simpler.

## Actual evidence in each independent seat

Caster: `34430787-4e2a-465b-aa1a-076ea3a07199`.
Recipient: `28afd8d7-0e9a-45e0-ac33-51ebeb02f251`.

| Phase | Sequence | Actual local occurrence | Original public result |
|---|---:|---:|---|
| Approach |8|79|Actual movement to `[3,6]`; caster remains120 HP|
| Owner application |9|90|`condition.spell.vampiric_touch`, UUID `aebf2ad6-b8cc-4717-82ae-d185ed446e45`|
| First applied damage |9|107|10 Necrotic to the actual recipient|
| First self-heal |9|112|`actual_healing=5`, `was_blocked=false`, resulting125 HP|
| First cast completion |9|114|`spell.vampiric_touch`, `attack_outcome=Hit`|
| Held movement |10|129|Actual movement to `[3,7]`, same real owner UUID retained|
| Repeat applied damage |19|190|24 Necrotic to the same actual recipient|
| Repeat self-heal |19|195|`actual_healing=12`, `was_blocked=false`, resulting137 HP|
| Repeat completion |19|196|`action.spell.vampiric_touch.strike`, `attack_outcome=Crit`|
| Owner removal |20|205|The exact Vampiric Touch UUID is removed|
| Concentration removal |20|206|Actual concentrating UUID `10a31335-02e0-47a5-8eff-521fae6e08a2` removed|
| Drop completion |20|208|Actual `action.drop_concentration`|
| Restored movement |21|267|Actual movement to `[2,7]`, both owners absent|

The native source/healing target of both HealFacts is the caster. The first
cast's group is80; its heal has native parent_event91. The repeat group's
native lineage is172; its heal has parent_event174. Full version rows,
resolutions, attributions and ancestry remain in the originals. Equal numeric
IDs in these two views are not a general cross-faction identity guarantee.

Independent frozen SDK folding confirms caster HP120 →125 →137, then137 at
owner removal. Two genuine departure opportunity hits in sequence21 reduce HP
to126. These values come from public facts and reducer state; no client
half-damage calculation was used as evidence.

## Qualification boundary

This closes the missing **positive healing recording** gap and supplies real
first hit, repeat critical hit, persistent owner, movement and owner-end facts.
The recorder's generic `required_facts=['heal',…]` is not by itself a positive
healing gate: the two positive amounts above were inspected in both original
streams, with byte-preserving copy and independent SDK state folding.

No provider, typed spell resource, manifest, runtime renderer or Factory source
was changed here. Existing first-cast native rendering remains distinct from
the still-unqualified held/repeat/healing source contracts and human approval.
