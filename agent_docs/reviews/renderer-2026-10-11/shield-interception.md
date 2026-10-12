# Shield interception — native condition response

The recorded Magic Missile cast admits three blocks owned by the same native
Shield condition. The client now presents the original defensive cast on first
application and the original directional impact pair at each blocked contact.
It does not change the server's damage, condition or reaction decision.

## Source and implementation

- Original behavior: `game_obsolete/condition_reaction.py`, the condition branch
  of `game_obsolete/body_action.py`, and the installed condition/draft recipes.
- Shared consumer: `src/presentation/condition-interception.ts`, called from
  the existing occurrence compiler before canonical event commits are rebuilt.
- The reaction faces the incoming actor. Its release and authored contact delay
  align with the first interception. An otherwise negative reaction start shifts
  the incoming occurrence without changing either authored playback rate. This
  delay branch is source-reviewed, not independently exercised by this recording.
- Each block chooses its incoming world-direction bank. The bank's source basis
  remains E and rotates with the camera; those are distinct directions.
- Later contacts reuse the maintained condition. The finite back/front media
  use ordinary Pixi Sprites, the existing resource owner and scene ordering.

## Actual recording and checks

`.runtime/recordings/shield-interception/case.json` contains three exact SDK
packets, each compared byte-for-byte with the retained server spool. Supported
ServerConfig setup grants the actual Shield reaction to the defender; native
commands produce the outcome. No packets, dice or hit points were fabricated.

The native regression passes: one defensive cast, three blocked contacts, six
authored component tracks, no premature Shield reveal, HP unchanged at 40,
canonical final state unchanged, every event committed once, and rewind stable.
The existing Counterspell regressions also pass after the compiler integration.

Twelve production-renderer samples cover four camera quarters at defensive cast,
interception and aftermath. They have no presentation/browser errors; visible
impacts contribute pixels, repeated draws and hide/restore are exact, and all
scene views/leases return to zero. An explicit world-direction light is supplied
for this rendering check; backend perception categories are not lighting RGB.
The sampled source can legitimately have an empty back or front band early in
its animation. Original frame windows remain unchanged.

Evidence: `.runtime/reviews/shield-interception/` and the focused
`tests/condition-interception.test.ts` / `.browser.mjs` tests. This is software
WebGL correctness evidence, not hardware performance acceptance. Independent
source/ECS review passed. Spatial projectile deflection is separate work.
