# Current schema-16 Fire Bolt journal

Original Amber follower bytes from a legal Studio baseline run on frozen engine
`211b71134ed15c89e62232587381f7e15a5961c3`, protocol 1/schema 16, digest
`49d14bc20920f5698eb4f09e3aeece442380242cd1453893d45f94ea9fb0c8a5`.

Initialization, ordinary end-turn commands, then an actual Fire Bolt cast with
its disclosed damage and actor changes. No credentials or private engine state.
This small committed journal qualifies durable admission/replay; it is not an
artist-approved choreography or the complete Studio library.

Regenerate with `python3 tools/studio_cases/record.py --only spell.fire_bolt`
against the pinned frozen export; retain the original received bytes.
