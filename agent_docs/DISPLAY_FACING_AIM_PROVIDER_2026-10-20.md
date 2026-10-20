# Display-facing optical aim provider

20 October 2026. Installed Factory `runtime-e102c29dec58524b`; no source/art/default change or gameplay aim rule was introduced.

## Complete compatible selected cohort

The installed selected index has one `live_pose.mode="gaze"` lifecycle:
`condition_eyebite_eye_persistent`, owned by the actual
`condition.spell.eyebite.casting` UUID. Its application, sustain and removal
clips all declare `owner_state`, `root_path`, `live_endpoints`. The frightened
and sickened finite eye clips already carry actual caster/target endpoints;
this change does not replace those with cosmetic facing.

The delivered `conditions/live_pose.gd::update` consumes the second endpoint
only to normalize its direction from the eye's source origin. It does not
read a target UUID, action radius or backend facing field. Its source settings
retain `camera_blend=.32` and offset `[0,1.01823376490863,0]`.

## Existing authoring and provider path

`PresentationCondition.aim_policy="display_facing"` exports
`persistent.nativeAim`; `NativePersistent.lifecycle_samples` forwards it as
`native_cue.aim_policy`. Only the Eyebite Casting condition opts in. Blank or
unknown policies remain unavailable rather than inventing a target.

The existing endpoint provider calls:

```text
SpellPlacement.display_facing_aim(
    actual_published_actor_row, facing_cycle,
    registered_source_point_world, source_live_pose_settings, authored_policy)
→ {rows, reason, direction, source_origin}
```

It requires the actor to be actually displayed through the existing caller's
gate and requires source mode `gaze` plus that explicit policy. The two returned
points carry the same actual actor identity. The second is an **optical unit
direction**, not a new target position or an action range. No canonical actor,
event, source setting or saved target is mutated.

`row.facing` is already the renderer's world-facing value. The inverse of the
existing `Placement.facing` mapping is:

```text
i = (cycle.index(world_facing) − cycle.index("E")) modulo 8
angle = i × π/4 − π/4
direction = (cos(angle), 0, sin(angle))
```

Camera quarter is not applied a second time. For the actual supplied WORLD
source point `P`, the delivered source's equation is `origin=P+offset`, then
`direction=normalize(endpoint[1]−origin)`. Thus the helper returns
`endpoint[1]=P+offset+direction`. The registered point already includes the
actual occurrence/root placement; the source offset is added once in the
space used by the delivered source. Applying the occurrence basis to only
that offset or applying the camera quarter again would tilt/rotate the eye.

## Evidence and limits

`tests/display_facing_aim_checks.gd` passes **1,465 checks, zero failures,
zero script/engine errors and zero owned leftovers**, 1.9 seconds.
Receipt: `.runtime/tests/20261020T073821.159474Z/display_facing_aim_checks.log`.

The headless gate executes the **actual delivered LivePose helper**, using
all eight world facings, four actual Camera3D quarter transforms, unit and
1.7-scale translated/rotated roots, and all three source declarations. It
checks actual node world position/look-at against the retained camera-blend
and source-offset equations, repeated paused values, missing policy/unknown
facing/non-gaze negatives, empty admission and source/actor immutability.

`tests/fixtures/schema16/eyebite-aim` preserves the complete independent
original Amber/Blue journals plus original scenario/commands/report (21 JSON
files) from `spell.eyebite/baseline/20261019T142627.310649Z`. Both preserve actual
casting owner `e94cc307-c32a-436f-8d99-5136e2ff8eaf` on actor
`d1d87568-cff5-48b5-966b-2540ab6d3aac`; each yields exactly one matching native
lifecycle with the policy. No removal or outcome was fabricated.

These are optical math, source-API and original owner/publication-data proofs.
Native framebuffer contribution, actual published gameplay camera rotations,
source readiness under live load and visual acceptance still require the
separate native/shared runtime gate. No such output claim follows from this
headless receipt.


### Native runtime qualification

The separate `native_display_facing_aim_render_checks` gate passes **257 checks,
zero failures, zero script/engine errors and zero owned leftovers**,8.8 seconds:
`.runtime/tests/20261020T075237.070765Z/native_display_facing_aim_render_checks.log`.
It uses both original recorded owners and all four published camera quarters,
checks actual delivered orientation/endpoints and isolated native pixels, then
reverse seek/loop, canonical immutability and teardown. Source readiness under
live load and user art acceptance remain separate; this closes the previously
unqualified native-output gate, not those broader claims.
