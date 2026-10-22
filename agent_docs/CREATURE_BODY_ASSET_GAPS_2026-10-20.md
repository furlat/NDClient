# Creature body deliveries and remaining asset gaps — 22 October 2026

Source: current `authoring/characters/characters/*.tres`, reconciled22October
with the supplied production handoffs. This is a source-resource inventory,
not full native rendering or human artwork acceptance. All artwork/audio are
**UNREVIEWED**.

## Original twelve summon-body rows: eight assigned, dragon delivered for intake, three without an identified own-body delivery

Air/Earth/Fire/Water Elementals and all four equipped Myrmidons now select their
own supplied bodies through existing typed rigs. The Myrmidon batch imports
36banks/4,320poses plus the eight Action bodies/four exact AttackFact recipes;
Earth Burrow keeps actual PortalTransfer/Landing ownership. The combined source build has zero errors/two warnings and its
affected3suite source/dispatch batch passes20,434assertions. Myrmidon native
output, display scale/placement and all artwork remain unqualified/unreviewed.

Selected dragon colour/reconstructed depth/Sprite Fusion Default normals are
delivered but not client-integrated; the current rig remains the explicit T-Rex
substitute. Cambion, Deva and Djinni have no own-body delivery identified in
these handoffs. Thus four original client rows remain incomplete, with only
three unidentified artwork deliveries. Authentic dragon mouth registration
remains separate from its delivered depth/normals. Existing portraits remain.

| Creature | Exact owner | Current source / remaining boundary |
|---|---|---|
| Air Elemental | [`creature.spell.air_elemental`](../authoring/characters/characters/creature.spell.air_elemental.tres) | `summon.elemental.air` — own9clip body/geometry delivered; native movement/intrinsic/hit/death bindings qualified; art/scale review open |
| Air Myrmidon | [`creature.spell.air_myrmidon`](../authoring/characters/characters/creature.spell.air_myrmidon.tres) | `summon.myrmidon.air` — own equipped9clip body plus compatible derived geometry assigned; source publication/dispatch checked separately from native output, display fit and art review. Bare/weapon-only VFX not selected |
| Cambion | [`creature.spell.cambion`](../authoring/characters/characters/creature.spell.cambion.tres) | `smallscale.demonelite01` |
| Deva | [`creature.spell.deva`](../authoring/characters/characters/creature.spell.deva.tres) | `smallscale.characters.4paladin` |
| Djinni | [`creature.spell.djinni`](../authoring/characters/characters/creature.spell.djinni.tres) | `smallscale.characters.6mage` |
| Draconic Spirit | [`creature.spell.draconic_spirit`](../authoring/characters/characters/creature.spell.draconic_spirit.tres) | Selected clean colour/reconstructed depth/Sprite Fusion Default normals delivered; newer shared-material runtime candidate also archived. Client still selects `smallscale.dinosaurs.elite-armored-t-rex`; layout/receiving/caster intake and authentic mouth registration remain |
| Earth Elemental | [`creature.spell.earth_elemental`](../authoring/characters/characters/creature.spell.earth_elemental.tres) | `summon.elemental.earth` — own9clip body/geometry delivered; native movement/intrinsic/hit/death bindings qualified; art/scale review open |
| Earth Myrmidon | [`creature.spell.earth_myrmidon`](../authoring/characters/characters/creature.spell.earth_myrmidon.tres) | `summon.myrmidon.earth` — own equipped9clip body plus compatible derived geometry assigned; source publication/dispatch checked separately from native output, display fit and art review. Bare/weapon-only VFX not selected |
| Fire Elemental | [`creature.spell.fire_elemental`](../authoring/characters/characters/creature.spell.fire_elemental.tres) | `summon.elemental.fire` — own9clip body/geometry delivered; native movement/intrinsic/hit/death bindings qualified; art/scale review open |
| Fire Myrmidon | [`creature.spell.fire_myrmidon`](../authoring/characters/characters/creature.spell.fire_myrmidon.tres) | `summon.myrmidon.fire` — own equipped9clip body plus compatible derived geometry assigned; source publication/dispatch checked separately from native output, display fit and art review. Bare/weapon-only VFX not selected |
| Water Elemental | [`creature.spell.water_elemental`](../authoring/characters/characters/creature.spell.water_elemental.tres) | `summon.elemental.water` — own9clip body/geometry delivered; native movement/intrinsic/hit/death bindings qualified; art/scale review open |
| Water Myrmidon | [`creature.spell.water_myrmidon`](../authoring/characters/characters/creature.spell.water_myrmidon.tres) | `summon.myrmidon.water` — own equipped9clip body plus compatible derived geometry assigned; source publication/dispatch checked separately from native output, display fit and art review. Bare/weapon-only VFX not selected |

The five elemental Dragon summon forms share `creature.spell.draconic_spirit`; their delivered colour variants are one family, not five missing base rigs. Current game geometry still uses an armoured T-Rex. All four equipped Myrmidons now use their own assigned rigs; their bare comparisons, weapon-only receivers and native body output remain separate.

### Newer delivered files versus active authoring and client intake

**Current Myrmidon follow-through:** all four equipped body families are now
assigned. The offline importer preserves36raw colour files and derives108
current-consumer numeric companions with sourcecode validity, original normal
profile and explicit ground0. Common enclosing depth[-49,92] adds at most
0.01835924m depth /0.3764835° normal quantization. Existing nine source clocks,
contact96/138 and all8facing rows remain; no new renderer/shader/lighting path.
[Exact intake/coverage](../.runtime/closing-repairs/myrmidon-body-intake/README.md),
[conversion receipt](../.runtime/closing-repairs/myrmidon-body-intake/conversion-receipt.json).
The delivery descriptions below retain their source status; the expansion's
bare comparisons, new unarmed Water, optional FX and weapon part receivers
remain separate from the selected equipped-body intake.


The earlier [21October handoff](ELEMENTALS_DRAGONS_PRODUCTION_HANDOFF_2026-10-21.md)
is historical where it says dragon geometry is absent. The explicitly supplied
newer handoffs establish three distinct inputs:

| Supplied source | What exists | Current boundary |
| --- | --- | --- |
| [Selected dragon depth/normals handoff](/mnt/c/Users/tommaso/Documents/assets/summon-creature-lab-2026-10-20/production-2026-10-21/dragon-depth-normals/HANDOFF.md), sibling `dragon-depth-normals.zip` | Complete selected clean colour, affine reconstructed depth, Sprite Fusion Default normals, independent normal-admission/depth-support/caster-support masks and optional separate source shadow;1,200appearance banks/20,880appearance poses over120shared action/view banks. Manifest declares `complete selected assets; production adoption separate`. | Preserve each bank's crop/grid/contact/optical origin and measured source-angle adapter. Current rig-wide strip/facing UV assumptions cannot simply receive the new paths. Receiving-normal admission must remain independent of missing depth; caster support remains stricter. The current client normal gate still couples receiving to depth/support (`modular.gdshader`). No import or shader adaptation was performed here. |
| [Shared dragon runtime handoff](/mnt/c/Users/tommaso/Documents/assets/summon-creature-lab-2026-10-20/dragon-runtime-2026-10-22/HANDOFF.md), frozen archive `/mnt/c/Users/tommaso/Documents/assets/summon-creature-lab-2026-10-20/production-2026-10-22/dragon-shared-body-runtime.zip` | Archive exists and contains the handoff plus `data/manifest.json` with `complete=true`,120shared banks/2,088view poses and481PNGs. The shared material stores Light/Dark palette indices in R/G, membrane guidance in B and depth support in A; selected palette alpha supplies body alpha. | The archive's own handoff still calls this an **isolated candidate for visual review** with production/VFXFactory unchanged. A `production-2026-10-22` parent directory does not override that status. The unarchived authoring project/comparison resources may continue changing; use the archived packet for a later selected intake. This is not a client installation or human acceptance. Its existing support-A/palette-alpha/independent-FX-clock contract needs a real production adapter; the prototype explicitly does not demonstrate the production caster adapter. |
| [Elemental expansion handoff](/mnt/c/Users/tommaso/Documents/assets/summon-creature-lab-2026-10-20/elemental-expansion-2026-10-22/HANDOFF.md) and its `manifest.json` | Durable isolated source delivery: four equipped/bare Myrmidon families, a new unarmed flowing Water option and optional Water effects.89banks/10,680registered colour–geometry poses;36weapon banks/4,320weapon poses. Actual native3D surfaces, matching part-ID masks and source motion aliases are supplied. | The handoff states existing released elementals, production and game bindings are unchanged. Current equipped Myrmidon Resources now select the converted own-body rigs. Preserve192px cells,96/138contact,12fps and eight rows. Canonical RG16 ray depth/BA octahedral world normal is **not** the current affine-R/optical-RGB character descriptor; preview depth/normal images must not be relabelled as compatible numeric inputs. Source aliases, body/armour/weapon separation and actual weapon ownership need coherent existing-path intake. This delivery alone does not reverse excluded weapon-body replacement policy or require a new renderer. |

These supplied files remove the corresponding **missing source artwork/geometry**
requests. They do not qualify production Forward+ output, all pose/receiving/
shadow/equipment cases, source timing choices or human review. The isolated
preview's measurements remain its own reported scope, not game performance.
Neither inspected newer dragon handoff supplies an authenticated per-pose mouth
socket/optical region; the selected depth packet explicitly says no mouth
sockets or breath-release times were added. Runtime aura/effect anchors are not
silently relabelled anatomical mouth contacts. Do not request already-delivered
dragon normals or Myrmidon bodies again.

The [elemental/dragon handoff](ELEMENTALS_DRAGONS_PRODUCTION_HANDOFF_2026-10-21.md) identifies the durable packet. Elemental intake copies only144 selected colour/affine-depth/optical-original-normal/support PNGs (44.51MiB), preserving all36banks/4,320poses,192px cells,96/138 fixed contact, eight facing rows and12fps. Canonical RG/BA geometry was not misread as the current affine/RGB format. Exact0 ground registration and original-only normal profiles are explicit schema data; absent alternate profiles retain admission limits. The eight native elemental action bodies are assigned through their existing rig-specific resources without invented hit/release/socket frames. All four unchanged original captures now pass the shared native cohort:28,661 checks, zero failures, native exit0 and no engine errors. Each actual intrinsic Cast/AttackHeavy/Jab/Hook assignment has a separately compiled actor/source track and an acknowledged visible original texture/frame binding. This qualifies those selected recorded paths, not isolated framebuffer parity, lighting acceptance or final scale/placement/artwork review. The initial Earth/Shield one-ULP constructor failure is preserved; the shared endpoint repair has passing current evidence. [Exact four-body cohort](../.runtime/tests/20261021T192153.111850Z-content-closure-affected/summary.json).

## Other substitutions already recorded in the roster

These are existing substitutions to review separately. A `stand_in` label is not by itself a requirement to commission another body.

| Creature | Current substitute body |
|---|---|
| [`creature.bugbear`](../authoring/characters/characters/creature.bugbear.tres) | `smallscale.orc04` |
| [`creature.dire_wolf`](../authoring/characters/characters/creature.dire_wolf.tres) | `smallscale.animals.elite-wolf` |
| [`creature.ghoul`](../authoring/characters/characters/creature.ghoul.tres) | `smallscale.zombies-top-down.zombie-decay-02` |
| [`creature.gnoll`](../authoring/characters/characters/creature.gnoll.tres) | `smallscale.orc10` |
| [`creature.goblin_archer`](../authoring/characters/characters/creature.goblin_archer.tres) | `smallscale.goblin03` |
| [`creature.goblin_caster`](../authoring/characters/characters/creature.goblin_caster.tres) | `smallscale.goblin02` |
| [`creature.hobgoblin`](../authoring/characters/characters/creature.hobgoblin.tres) | `smallscale.orc03` |
| [`creature.kobold`](../authoring/characters/characters/creature.kobold.tres) | `smallscale.goblin01` |
| [`creature.ogre`](../authoring/characters/characters/creature.ogre.tres) | `smallscale.barbarians.1ogre` |
| [`creature.ogre_zombie`](../authoring/characters/characters/creature.ogre_zombie.tres) | `smallscale.zombies-hd.zombiehulk1` |
| [`creature.skeleton`](../authoring/characters/characters/creature.skeleton.tres) | `smallscale.undead.6warrior` |
| [`creature.skeleton_warlock`](../authoring/characters/characters/creature.skeleton_warlock.tres) | `smallscale.undead.8necromancer` |
| [`creature.zombie`](../authoring/characters/characters/creature.zombie.tres) | `smallscale.zombies-hd.zombiemale1` |

The clearest species substitutions are Bugbear, Gnoll and Hobgoblin using Orc bodies; Kobold using a Goblin; and Ghoul using a decayed Zombie. Other rows already use an appropriate pack variant (for example Ogre, Dire Wolf, Skeleton or Zombie) and should not automatically be treated as missing art.

## Why the old report said 63

The original 63-resource snapshot contained **12 summon bodies**, **34 modular-body assignments**, and **17 other substitutions**. Four of those 17 were duplicate `creature.configured_srd.*` entries for Bugbear/Gnoll/Hobgoblin/Kobold. The modular assignments include ordinary human NPC roles and their configured aliases; the shared layered humanoid rig already supplies those bodies. Skeleton Warrior has since moved from that modular group to the installed skeletal melee body below. The old 63 flags are historical receipt counts, not 63 current missing-body commissions.

`creature.spell.flaming_sphere` and `creature.spell.spiritual_weapon` are explicitly VFX-owned internal actors; their absence of a character rig is intentional and does not request creature artwork.

## Original flagged inventory with current source assignments

| Owner | Current rig |
|---|---|
| [`creature.acolyte`](../authoring/characters/characters/creature.acolyte.tres) | `neuroclient.modular` |
| [`creature.bandit`](../authoring/characters/characters/creature.bandit.tres) | `neuroclient.modular` |
| [`creature.bandit_captain`](../authoring/characters/characters/creature.bandit_captain.tres) | `neuroclient.modular` |
| [`creature.berserker`](../authoring/characters/characters/creature.berserker.tres) | `neuroclient.modular` |
| [`creature.bugbear`](../authoring/characters/characters/creature.bugbear.tres) | `smallscale.orc04` |
| [`creature.commoner`](../authoring/characters/characters/creature.commoner.tres) | `neuroclient.modular` |
| [`creature.configured_srd.acolyte`](../authoring/characters/characters/creature.configured_srd.acolyte.tres) | `neuroclient.modular` |
| [`creature.configured_srd.bandit`](../authoring/characters/characters/creature.configured_srd.bandit.tres) | `neuroclient.modular` |
| [`creature.configured_srd.bandit_captain`](../authoring/characters/characters/creature.configured_srd.bandit_captain.tres) | `neuroclient.modular` |
| [`creature.configured_srd.berserker`](../authoring/characters/characters/creature.configured_srd.berserker.tres) | `neuroclient.modular` |
| [`creature.configured_srd.bugbear`](../authoring/characters/characters/creature.configured_srd.bugbear.tres) | `smallscale.orc04` |
| [`creature.configured_srd.commoner`](../authoring/characters/characters/creature.configured_srd.commoner.tres) | `neuroclient.modular` |
| [`creature.configured_srd.cult_fanatic`](../authoring/characters/characters/creature.configured_srd.cult_fanatic.tres) | `neuroclient.modular` |
| [`creature.configured_srd.cultist`](../authoring/characters/characters/creature.configured_srd.cultist.tres) | `neuroclient.modular` |
| [`creature.configured_srd.gnoll`](../authoring/characters/characters/creature.configured_srd.gnoll.tres) | `smallscale.orc10` |
| [`creature.configured_srd.guard`](../authoring/characters/characters/creature.configured_srd.guard.tres) | `neuroclient.modular` |
| [`creature.configured_srd.hobgoblin`](../authoring/characters/characters/creature.configured_srd.hobgoblin.tres) | `smallscale.orc03` |
| [`creature.configured_srd.knight`](../authoring/characters/characters/creature.configured_srd.knight.tres) | `neuroclient.modular` |
| [`creature.configured_srd.kobold`](../authoring/characters/characters/creature.configured_srd.kobold.tres) | `smallscale.goblin01` |
| [`creature.configured_srd.mage`](../authoring/characters/characters/creature.configured_srd.mage.tres) | `neuroclient.modular` |
| [`creature.configured_srd.priest`](../authoring/characters/characters/creature.configured_srd.priest.tres) | `neuroclient.modular` |
| [`creature.configured_srd.scout`](../authoring/characters/characters/creature.configured_srd.scout.tres) | `neuroclient.modular` |
| [`creature.configured_srd.spy`](../authoring/characters/characters/creature.configured_srd.spy.tres) | `neuroclient.modular` |
| [`creature.configured_srd.thug`](../authoring/characters/characters/creature.configured_srd.thug.tres) | `neuroclient.modular` |
| [`creature.configured_srd.tribal_warrior`](../authoring/characters/characters/creature.configured_srd.tribal_warrior.tres) | `neuroclient.modular` |
| [`creature.configured_srd.veteran`](../authoring/characters/characters/creature.configured_srd.veteran.tres) | `neuroclient.modular` |
| [`creature.cult_fanatic`](../authoring/characters/characters/creature.cult_fanatic.tres) | `neuroclient.modular` |
| [`creature.cultist`](../authoring/characters/characters/creature.cultist.tres) | `neuroclient.modular` |
| [`creature.dire_wolf`](../authoring/characters/characters/creature.dire_wolf.tres) | `smallscale.animals.elite-wolf` |
| [`creature.generic_caster`](../authoring/characters/characters/creature.generic_caster.tres) | `neuroclient.modular` |
| [`creature.ghoul`](../authoring/characters/characters/creature.ghoul.tres) | `smallscale.zombies-top-down.zombie-decay-02` |
| [`creature.gnoll`](../authoring/characters/characters/creature.gnoll.tres) | `smallscale.orc10` |
| [`creature.goblin_archer`](../authoring/characters/characters/creature.goblin_archer.tres) | `smallscale.goblin03` |
| [`creature.goblin_caster`](../authoring/characters/characters/creature.goblin_caster.tres) | `smallscale.goblin02` |
| [`creature.guard`](../authoring/characters/characters/creature.guard.tres) | `neuroclient.modular` |
| [`creature.hobgoblin`](../authoring/characters/characters/creature.hobgoblin.tres) | `smallscale.orc03` |
| [`creature.knight`](../authoring/characters/characters/creature.knight.tres) | `neuroclient.modular` |
| [`creature.kobold`](../authoring/characters/characters/creature.kobold.tres) | `smallscale.goblin01` |
| [`creature.mage`](../authoring/characters/characters/creature.mage.tres) | `neuroclient.modular` |
| [`creature.ogre`](../authoring/characters/characters/creature.ogre.tres) | `smallscale.barbarians.1ogre` |
| [`creature.ogre_zombie`](../authoring/characters/characters/creature.ogre_zombie.tres) | `smallscale.zombies-hd.zombiehulk1` |
| [`creature.priest`](../authoring/characters/characters/creature.priest.tres) | `neuroclient.modular` |
| [`creature.scout`](../authoring/characters/characters/creature.scout.tres) | `neuroclient.modular` |
| [`creature.skeleton`](../authoring/characters/characters/creature.skeleton.tres) | `smallscale.undead.6warrior` |
| [`creature.skeleton_warlock`](../authoring/characters/characters/creature.skeleton_warlock.tres) | `smallscale.undead.8necromancer` |
| [`creature.skeleton_warrior`](../authoring/characters/characters/creature.skeleton_warrior.tres) | `smallscale.undead.6warrior` — now partial, not a modular body |
| [`creature.spell.air_elemental`](../authoring/characters/characters/creature.spell.air_elemental.tres) | `summon.elemental.air` — delivered own body, partial qualification |
| [`creature.spell.air_myrmidon`](../authoring/characters/characters/creature.spell.air_myrmidon.tres) | `summon.myrmidon.air` |
| [`creature.spell.cambion`](../authoring/characters/characters/creature.spell.cambion.tres) | `smallscale.demonelite01` |
| [`creature.spell.deva`](../authoring/characters/characters/creature.spell.deva.tres) | `smallscale.characters.4paladin` |
| [`creature.spell.djinni`](../authoring/characters/characters/creature.spell.djinni.tres) | `smallscale.characters.6mage` |
| [`creature.spell.draconic_spirit`](../authoring/characters/characters/creature.spell.draconic_spirit.tres) | `smallscale.dinosaurs.elite-armored-t-rex` |
| [`creature.spell.earth_elemental`](../authoring/characters/characters/creature.spell.earth_elemental.tres) | `summon.elemental.earth` — delivered own body, partial qualification |
| [`creature.spell.earth_myrmidon`](../authoring/characters/characters/creature.spell.earth_myrmidon.tres) | `summon.myrmidon.earth` |
| [`creature.spell.fire_elemental`](../authoring/characters/characters/creature.spell.fire_elemental.tres) | `summon.elemental.fire` — delivered own body, partial qualification |
| [`creature.spell.fire_myrmidon`](../authoring/characters/characters/creature.spell.fire_myrmidon.tres) | `summon.myrmidon.fire` |
| [`creature.spell.water_elemental`](../authoring/characters/characters/creature.spell.water_elemental.tres) | `summon.elemental.water` — delivered own body, partial qualification |
| [`creature.spell.water_myrmidon`](../authoring/characters/characters/creature.spell.water_myrmidon.tres) | `summon.myrmidon.water` |
| [`creature.spy`](../authoring/characters/characters/creature.spy.tres) | `neuroclient.modular` |
| [`creature.thug`](../authoring/characters/characters/creature.thug.tres) | `neuroclient.modular` |
| [`creature.tribal_warrior`](../authoring/characters/characters/creature.tribal_warrior.tres) | `neuroclient.modular` |
| [`creature.veteran`](../authoring/characters/characters/creature.veteran.tres) | `neuroclient.modular` |
| [`creature.zombie`](../authoring/characters/characters/creature.zombie.tres) | `smallscale.zombies-hd.zombiemale1` |


## Skeleton Warrior assignment repaired; kit and optical limits remain

[`creature.skeleton_warrior`](../authoring/characters/characters/creature.skeleton_warrior.tres)
now selects the already-installed
[`smallscale.undead.6warrior`](../authoring/characters/rigs/smallscale.undead.6warrior.tres),
a real skeletal melee/shield body with 29 authored poses. Its existing attack,
cast, movement, hit, Block and Die clips keep their source frames and clocks.
The bow-bodied Skeleton Archer is not substituted. No body artwork was copied,
painted or imported for this repair.

The resource remains `partial`: the baked pixels show a spear and wooden
shield rather than the native Longsword, Wooden Shield and Armor Scraps kit.
They cannot render arbitrary acquired equipment or equipment swaps. The rig's
existing partial optical coverage and named clip fallbacks remain unchanged.
The separate `undead--6warrior` portrait is still explicitly borrowed; no exact
Skeleton Warrior portrait was supplied. This is a source assignment, with no
new runtime, screenshot or human acceptance claim. **All artwork is UNREVIEWED.**

The impossible `Head11` offer was also removed from the modular rig's helmet
choices. The installed delivery contains no `Head11` part, sprites or optical
companions. No current gear/appearance selected it; Leather Hood already uses
its explicit `Head12`/`Head7` variants. This removes unsupported unused metadata
and does not request a fabricated donor part or change a used selection.

## Optical mouth authoring for public Draconic Breath readiness

This is **client body/pose authoring**, separate from delivery of the original
twelve summon-body rows listed above. The current `creature.spell.draconic_spirit` resource uses
`smallscale.dinosaurs.elite-armored-t-rex`. Its real body remains that explicit
substitute until the delivered dragon packet is integrated; no dinosaur
head/face centre is an anatomical mouth measurement. Dragon depth and normals
are now delivered as described above; that fact does not supply a mouth socket.

Factory `runtime-public-admission-20261020-976f8289ebcefa5c` now supplies the
public readiness gate and its paired direct source constructors for the five
playable Fire/Cold/Lightning/Acid/Poison forms. The client binds the actual
condition UUID, current public `ready`/`breath_type`, owner/source actor,
observation revision and ordinary owner/phase clocks. It does not require a
private FreeAction ID, issued flag or granted lineage. The remaining draw input
is an **authentic scoped mouth surface** for this actual body and its displayed
pose/view, currently `authentic_mouth_region_not_authored`.

The concrete requested asset data are:

- For the actual selected dragon body, author a `mouth` socket for each
  supported clip, frame and facing through the existing rig pose-socket data.
  An unsupported frame/view remains absent. The current T-Rex substitute keeps
  its explicit refusal; this does not request a second socket commission for
  a placeholder that the delivered dragon body will replace.
- Author the bounded optical sampling slots/radius around that actual mouth,
  retaining the original colour/depth/support/normal source pixels. The existing
  `PresentationCondition.lifecycle_geometry` can select these real slots with
  `region={id:"mouth",socket:"mouth",radius_cells:<authored finite value>}`.
  Remove its explicit missing status only when that body data exist. No new
  spell-specific consumer is needed: current pose/socket resolution and actual
  EntitySurface sampling already supply those exact points and geometry
  revision to the selected public source.
- Include the same scope for idle, movement, casting/attack, hurt and other
  displayed body clips/views that should support readiness. Missing scope
  stays an explicit empty/missing input; a whole head is never relabelled.

The delivered source witness contains only four inspected lower-forward-face
pixels `(65,48),(66,48),(65,49),(66,49)` on modular
`Head1/Idle.png`, frame1, source UV `(1/15,.625,1/15,.125)`. That is a bounded
Factory source witness, **not** mouth authoring for the actual T-Rex body or a
universal region assignment. No Head1-only demonstration adapter was added.
Actual public `ready=false` still retires the source without mouth geometry;
actual accepted breath firing remains a separate native action. All artwork
remains **unreviewed**, and this new public-source wiring is **unvalidated**.
