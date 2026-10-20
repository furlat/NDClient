# Actual Blur history with native spell-hit materials

Frozen engine `211b71134ed15c89e62232587381f7e15a5961c3`, schema 16, ordinary seed 2. Each case preserves both complete original subjective packet streams plus its original scenario, commands and recording result. `native-hit-evidence.json` is derived inspection metadata; the journals are unchanged.

| Case | Genuine observed input | Owner lifetime |
|---|---|---|
| `magic-missile` | One missile applies 4 Force to the Blur caster; the other two target the healthy ally and are actually intercepted by that ally's Shield. The caster then walks from `[4,6]` to `[3,6]`. | First Blur owner remains disclosed at the recording endpoint. No removal is claimed. |
| `fire-bolt` | Actual Fire Bolt **Hit**, 10 applied Fire, then the same actual movement. | A lawful second Blur cast applies a distinct new owner and removes the original owner. Original native row order is preserved. |

The caster's Shield is disabled through the offered, committed `toggle_handler` command before Blur. Dice, damage, concentration outcomes and state are not forced. All other reactions and outcomes remain in the original packets.

The client authoring selects Magic Missile's available hit material at `spells/magic_missile/default/travel`, node `travel/Donor/Box1`, with no explicit hit clock parameter; Fire Bolt selects `spells/fire_bolt/default/travel`, node `travel/Donor/TBHead`, clock parameter `source_clock`. `Components` creates their native-hit treatment only from the actual positive applied DamageResult and its native spell ancestry.

`native_spell_hit_material=true` is an explicit **client rendering control** for the forthcoming native test. It is not a recorded server outcome or an altered journal field. The recording alone does not qualify a private native surface, delayed framebuffer capture, historical source clock or pixels. The intended test observes the real flash and a post-flash cut within Blur's actual 0.24-second history window through ordinary Recording/Timeline sampling.

The separate originals at `.runtime/history-native-hit-20261020/missile` and `missile-replacement` remain failed cleanup attempts. The former could not offer Drop Concentration despite retained disclosed members. The latter completed a second Blur cast but disclosed no removal of the first owner, so its required-end gate failed. Neither has been relabeled as a successful lifecycle or used to invent an end in `magic-missile`. The successful Fire Bolt replacement supplies actual retirement evidence; Missile still requires explicit teardown and retains its authoritative-end gap.

Re-record either preserved scenario with the existing `tools/studio_cases/worker.py`, frozen Python/PYTHONPATH and an **absolute new output directory**. Do not overwrite these originals or read an official mutable engine checkout. The existing Studio recording importer can consume these two preserved case directories; source/provider/graphics approval remains independent from capture safety.
