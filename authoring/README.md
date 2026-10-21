# Editable presentation authoring

The production sources are the three typed roots
[abilities.tres](abilities.tres), [characters.tres](characters.tres) and
[environment.tres](environment.tres). Play and Studio consume their ordinary
`build/presentation/` output through the same presentation code. Edit the
resources listed by these roots; an unlisted entry is a build error.

The old `catalog/`, `items/`, `ui/` and media JSON preserve intake and source
measurements. They are not a second runtime catalog. Editing an old exported
spell or item document does not replace its typed source assignment.

## Where to author

| Content | Source owner | Shared consumer |
| --- | --- | --- |
| Spell gestures, native effects, variants, outcome branches, source timing and placement | `abilities/spells/`, `PresentationSpell`, `PresentationEffectUse` | Existing spell/action compiler and native renderer |
| Actions and reactions, including incoming Counterspell preparation | `abilities/actions/`, `PresentationAction`, `PresentationEffectUse.incoming_track` | Existing action compiler and incoming-track projection |
| Committed movement accents | `abilities/contexts/movement.tres`, `PresentationEffectUse.movement` | Existing motion tracks and movement phase compiler |
| Condition application/hold/removal, material/pose changes and finite responses | `abilities/conditions/`, `PresentationCondition`, `PresentationEffectUse.condition_response` | Existing condition owners, material/pose paths and result compiler |
| Weapon trails and actual attributed contact/rider choices | `abilities/attacks/`, spell/action/condition result assignments | Existing attack tracks and exact observed-result joins |
| Intrinsic item decorations and actual item-effect memberships | `characters/gear/`, shared ability item-attachment context | Existing item UUID/effect UUID/holder membership and native item paths |
| Worn equipment and dropped item variants | `characters/gear/`, `PresentationGear.slots`, `.family`, `.ground` | Existing body assembly and environment sprite path |
| Creature bodies, rigs, source geometry, sockets and portraits | `characters/` and its existing measured registrations | Existing character assembly and optical input providers |
| Terrain, objects, doors and structures | `environment/` | Existing world preparation and environment material |
| Retained native spatial fields, mechanism state/activation, portals and residues | `environment/surfaces/`, `PresentationGroundSurface` | Existing native spatial owner or environment program/material path |
| Audio source, event/contact assignment and source-frame crossings | `audio/cues.json`, `bindings.json`, `contacts.json` | Existing selected-audience audio compiler and playback |
| Icons | The owning spell/action/condition/gear `ImageRef` | Generated icon maps shared by HUD and Studio |

The passive resource definitions are in `presentation/source/`. Their exports
are the editable schema; resource IDs and observed engine facts supply identity.
Do not add spell-name branches to the renderer to express another selection,
timing window, offset, orientation, recipient slot or source setter.

## Authoring an effect use

Select an installed package clip and its exact approach, or an explicitly
delivered standalone PhaseResource from the package's public source table.
`role`, `scope`, `at`, `attachment`, `follow`, transforms and source windows own
staging. `source_inputs` and ordered `input_arguments` declare public setters.
`constructor_input` or `observed_result` binds the source's actual occurrence
operands; `when` and ordered resource variants choose among disclosed values.

For Counterspell, edit the actual reaction resource's `incoming_track`; the
spell declaration delegates to that reaction. For movement, edit the shared
movement context. For a finite condition response, edit the condition's response
uses. These tracks retain the existing preparation, publication, lighting and
source clocks. A finite inspection lifetime does not become a retained gameplay
owner's lifetime.

Item sustain follows an actual item/effect membership and current holder;
contacts follow the actual equipped attack/result snapshot. Ground appearances
use their exact authored variant, camera rows, pivot, scale and original optical
companions. Family reuse is explicit data, including its stand-in limitations.

Unsupported operands or source topology remain explicit in the owning resource
and Studio. Do not substitute a fixture UUID, hidden payload, guessed outcome,
another actor's body/socket, synthetic landing, or finite review sequence.
Source assignment and rendering evidence do not establish human art approval.

## Publish a batch

From the Windows Godot console executable, with this checkout's absolute path:

```sh
Godot_v4.7.2-stable_win64_console.exe --headless --path C:/Users/tommaso/Documents/Dev/NDClientGodot --script res://tools/build_presentation.gd
```

The one build publishes characters, environment and abilities and writes
`build/presentation/coverage.json`. Do not run another publication, Studio index
reader or generated-resource consumer concurrently with it. Make broad content
changes first, publish them together, then perform the agreed consolidated
qualification. No per-spell build or test is required for each parameter edit.

The [current remaining-work inventory](../agent_docs/REMAINING_WORK_2026-10-20.md)
and [named content/source boundaries](../agent_docs/AUTHORING_CONTENT_REMAINING_2026-10-20.md)
distinguish implemented source, genuine external requirements, unqualified
runtime behavior and artwork awaiting human review.
