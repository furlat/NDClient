# Actual free-aim Choices refusal

This is failed public-query evidence, not a successful Studio scenario. The
unchanged targeting gate completed **zero checks**: HTTP Choices returned 200,
then the frozen Python SDK rejected it before any Preview request or gameplay
command. `checks.json` is the original failure report.

`0001-choices-{request,response}.json` are the exact original request/body.
`amber/journal/` retains original public packets 0 and 1. `host-result.json`
contains the original pre-start source provenance; `source-provenance.json`
explains the selection. No credential-bearing server configuration or spool is
included.

Only discovery rows 15 and 16 trigger the SDK's unconditional
`available != bool(targets)` relation. They are the actual Drop actions for
Potion of Greater Invisibility and Potion of Haste. Both explicitly publish a
nonnull `position_region` and the shared empty `target_set=0`. The frozen
producer contract expressly permits discovery to omit enumerated cells for a
free-aim region; the Python SDK relation omitted that case.

`sdk-refusal-review.json` records an offline replay through the unmodified
frozen SDK `transport.validate("ChoicesResponse", response)`. That replay
reproduces the refusal; it does not bypass admission or qualify the unavailable
Fireball/Magic Missile targeting witnesses.

See [the exact source boundary and requested correction](../../../../../agent_docs/BACKEND_REVIEW_2026-10-20.md#python-sdk-choices-refuses-valid-lazy-position-regions).
