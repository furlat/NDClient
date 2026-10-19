# Real Flesh to Stone and restoration recording

Both faction folders contain the original server follower packets, unchanged.
They were recorded with schema 16 from frozen engine `211b71134ed15c89e62232587381f7e15a5961c3` using seed 2.

The ordinary target is a Goblin. It moves, stops, receives Flesh to Stone,
fails all four actual Constitution saves, becomes petrified, receives Greater
Restoration from its ally, and can move again. No trap, interrupted reaction,
starting petrification, injected save result or client-created condition is used.

| Amber sequence | Actual outcome |
| --- | --- |
| 4 | Target moves from `[4,7]` to `[4,6]` |
| 9 | Flesh to Stone; initial failed Constitution save and stages applied |
| 12, 18, 24 | Three failed progress saves |
| 24 | Completed `condition.spell.flesh_to_stone.petrified`; stages and concentration removed |
| 26 | Greater Restoration removes the exact petrified condition UUID |
| 31 | Target moves back to `[4,7]` |

There are 32 original packets per faction, four saving-throw facts, two
movement facts and 17 submitted commands. `evidence.json` lists exact actor and
condition identities, packet sequences and original engine identity. The Blue
stream independently observes the same lifecycle. `commands.json` preserves
the actual selected actions, previews and server receipts; `scenario.json`
preserves the recipe and choreography.

Reproduce from the client checkout:

```sh
python3 tools/studio_cases/record.py \
  --only spell.flesh_to_stone/petrification_restoration \
  --out .runtime/petrification-provider-cohort --timeout 210
```

The recorder advances ordinary turns while waiting for the named condition.
It fails if stages end before petrification, the target is not observed, or
the bounded turn limit is exhausted. It does not recast or select another target.

This fixture qualifies authoritative lifecycle inputs. It does not itself
qualify the client's pose capture, source rendering, seeking or visual approval.
The owned recording host exited with worker return code 0; no Godot was started.
