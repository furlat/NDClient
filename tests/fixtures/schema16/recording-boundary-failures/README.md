# Failed recording boundary originals (2026-10-20)

Fresh unchanged legal scenarios, recorded with frozen engine
`211b71134ed15c89e62232587381f7e15a5961c3`, protocol1/schema16. Each directory
preserves scenario, actual commands, last actual choices, failure and original
journal packets. Only `capture_choices` was added to the failing scenario step
for diagnostics. Host credentials/configuration and duplicated spool are omitted.
These are failed originals, not successful rendering or gameplay receipts;
the Studio Library/index is unchanged. See
[producer analysis](../../../../agent_docs/BACKEND_REVIEW_2026-10-20.md).

The separately named `incense_inventory` control stops before same-item re-equip
and retains the same failed Incense expectation; its actual Choices response
contains `requirements_unmet`, whereas the equipped original has no such row.
It demonstrates the location/discovery contradiction without executing a
fabricated item action or replacing the original failure.

`help_envelope` is a further unchanged Help failure capturing the actual full
HTTP ChoicesResponse returned by the native server (`choices-response.json`).
It provides the transport decoder's real scoped envelope; no metadata wrapper
or defaults were added around the bare choices. It remains a failed Help case.
