# Atlas publication review — 2026-10-15

Scope: the existing migration plan continuation, preserving source art, exact receiver/address/material semantics, first-frame pixels, event ordering, full fallback and the existing preparation budget. Independent correctness/plan/anti-slop review: motion agent. The ≥10× packet-to-animation target remains unmet; this change addresses a separate measured door publication spike.

## Actual pre-change owner

Run `.runtime/player-runs/20261015T181917.584355Z`, door frame7265:63.190ms frame,62.468ms Player,39.818ms native lighting,35.154ms atlas. Its current-frame atlas phases include addresses9.881ms (output-material adoption7.373ms,address publication1.529ms,normalized growth0.977ms),receivers7.748ms (bindings5.585ms),specs4.334ms,style4.502ms andmaterial synchronization5.490ms. Nested phases are inclusive and must not be summed as independent costs. Actual closure:279 changed sources,1156 specs,1095 prepared receiver bindings,884 preserved floor rows,311 resized output regions. This was genuine disclosure/growth, with no reported proof fallback.

## Retained change

`native_light_delta.gd::prepare_candidate_binding` prepares final crop/normalized region uniforms on each existing private source-patch output, incrementally under the unchanged budget. `reconcile` skips repeated region writes only when the exact candidate was accepted, the source belongs to that candidate and final atlas dimensions match. Stale atlas/source/view/base paths retain ordinary bindings.

Bulk-published receiver identities retain their already-prepared visibility for that same synchronization pass; the temporary identity directory is cleared afterward and at close. Existing receivers and all dynamic sampling keep ordinary style checks. Registered static nonwater material groups/output styles are certified against actual material/version/highlight/visibility before suppressing a redundant copy; changed state follows normal synchronization immediately.

Retained unchanged output materials keep the original normalized growth writes. A proposed private replacement-material path was rejected: the same311-owner/1156-receiver native fixture measured6.932ms for310 swaps versus0.877ms for original normalized-region writes, with both outputs exact. No such replacement cache/queue/proof remains in production. Evidence: `.runtime/atlas-output-swap-rejected.json`.

## Qualification

- Sparse prefix:56 checks, independent frozen full-capture plans/addresses, clean exit.
- Native staged oracle:1617 checks, including all1526 original assertions, stale/base/view/version/visibility/group failures, current hover, changed retained output source, exact first draw, growth, cancellation, floor data and picking-adjacent address contracts. `generated/native_atlas_staged_checks.json`.
- Large native oracle:2676 checks,311 initial static outputs/1156 receivers, real2048→4096 growth,1160 final receivers, zero differing receiver cells and byte-identical first3Dframe versus the complete planner. `generated/native_atlas_large_publication_checks.json`.

One initial implementation bug was caught by the stale-base oracle: equal final height alone did not prove equal reservation positions. Restricting the prepared-region skip to accepted candidate source owners restored the original fallback behavior; the complete oracle was rerun successfully.

## Remaining work and limits

Actual new door/admission latency requires the next matched live route; the numerical fixture is not a gameplay/FPS claim. Receiver/group registry publication, full actual-source proof checks, output-node assignment, floor buffer publication, retained normalized writes, viewport allocation/growth, culling and final wall/output synchronization remain real boundary work. The change does not promise removal of the entire35.154ms atlas owner, does not attribute lagged viewport counters to current frames, and does not relax any readiness gate.

## Live follow-up:184235 and next bounded step

Run `.runtime/player-runs/20261015T184235.919331Z` door frame7614 measured23.370ms atlas versus35.154ms previously. Actual phase costs: specs/proofs4.065ms, receivers8.088ms (bindings6.100ms; bulk4.404ms),output-material adoption5.509ms,address publication0.152ms,retained normalized growth0.252ms,style1.313ms,material synchronization1.085ms.221 source-output regions/material copies and1095 receiver styles used preparation proofs. These nested phase values are not independent totals. Door/world54heldframes314.464ms andmove30heldframes250.739ms remain; bothFireballs had zero later holds. A separate optional metadata dispatch regression is being corrected by its owner, so this run cannot prove the source-planning path complete.

The next scoped step detaches capture-only source fields during the existing incremental binding stage and retains their exact proof/output handles in candidate-owned directories. Publication still validates the same source/view/base fields, but avoids repeated private metadata teardown for hundreds of sources. Native candidate-check and extra-plan subphase timestamps distinguish that work in the next actual live trace. Registry/group registration,node/material assignment,actual source proofs and full fallback remain. No claim of a new live improvement before measurement.

##185727 output attribution and continuous UV proof

Instrumented live door frame6651:25.006ms atlas. Output4.660ms decomposes intoadopt0.774ms,transport/allocation/override2.341ms,actual-copy certification1.318ms andaddress-record assembly0.164ms.47ShaderMaterials were newly created and47dynamic outputs requiredfull copies; material synchronization2.787ms. Move frame6845 had0new outputs and0dynamic outputfull copies,output3.243ms andmaterial synchronization0.394ms. Existing prepared-resource release was0.015/0.009ms andoutside output adoption. Instrumentation wraps each output's four phases, so its own timing overhead is included and no fabricated allocation-only attribution is claimed.

The next bounded change extends the existingActorConstruction `source_frame_change` certificate with `full_version`, carried only through acontinuous chain whose prior certificate matches current base version/material/shader. Any fullmaterial/palette/condition/optical/source change erases it; an untagged version gap starts a new conservative floor. Legacy/manual certificates without this field retain exactadjacency. Atlas material copies andprepared dynamic-material admission can refresh onlyUV across that certified range, while retaining originalquad,condition,geometry,source-key andmaterial/output-owner checks. This isnot permission to skip an arbitrary version gap orafull-change-and-return.

Qualification:531actualproducer/material uniform/ownership checks,1786legacy full/frame-copy checks,623recorded actor-preparation checks,344native lifecycle/frame checks. The new native matrix uses actualActorConstruction in allfour rotations, comparingthe first draw andreceiving pixels with forcedcomplete copies for continuous frames,opacity/palette/optical full-change-and-return,actualquad geometry changes,highlight andprivate outputreplacement. All pass withclean exits. Thenext live route must verify whether the47cold outputs nowreuse their preparedresources; overall25msatlas/publication latency isnot yet resolved.

##190809: range hypothesis not confirmed on the real door

Run190809.274312Z retained47cold dynamic output allocations/full copies and24.715ms dooratlas. NeitherFireball had later holds. The earlier hypothesis that47copies failed onlybecause ofan idle-frame version gap wasnot established: absent candidate copies produce the same old counters. The exactUV-range proof is functionally qualified, but this run showsno corresponding allocation reduction anddoesnot establish its live benefit.

Readiness/acceptance remains unchanged while the next live trace records bounded actualfailure counts/samples: candidateactor preparation's exact missing clip/colour/CPU/companion/atlas status, missing candidate versus actual material/quad/output/transport/group/condition/geometry/frame/source-key/view failure. This identifies the observed path before further changes anddoesnot fabricate a rejection reason from aggregate counters.

##192324 exact diagnosis and correction

The new actual diagnostics reported58dynamic prepared acceptances andno rejection counts, while47output allocations/full copies remained. This disproved an asset/range-rejection explanation for these47outputs. The cause was introduced bythe earlier private-teardown refactor: `source_patches=candidate.source_patches` shares the directory, andpublication adds actual dynamic extras to it. Testing membership in that expanded directory incorrectly chose an absent `candidate.outputs` entry overthe dynamic source's valid `prepared_output`. The same membership test also skipped that extra's private-field cleanup.

Both guards now test actual `candidate.outputs` membership. Captured outputs use their original private owner; actual dynamic extras use the accepted output returned by their ownsource binding and detach their private preparation fields normally. No acceptance proof, clock orreadiness gate changes.

Qualification:56sparse-prefix checks and1708native staged checks, clean exits. The added regression uses actualActorConstruction binding/private materials, thenadds the actor asan actual dynamic extra beside a completed static world prefix. It verifies0newoutput allocations,the exact accepted outputidentity surviving cleanup, no retained privatefuture payload in live source records, andbyte-exact first receiving/final3Dframe against complete planning. Existing1617checks remain included. Prior tests covered preparedactor copies andstaged dynamic extras separately, whichmissed this combined alias-handoff path.

Run192324.856392Z itself stillmeasured25.247ms dooratlas/61.095ms frame,59doorworld-heldframes337.117ms and14moveholds111.237ms; bothFireballs had0laterholds. The next live route mustverify the allocation correction; no new latency result is claimed from this fixture. ContinuousUV-range behavior is separately qualified butwasnot the observed47output cause.

## 194604: allocation correction confirmed; next shortcuts rejected

Run `20261015T194604.370685Z` confirms the correction on the actual door:
frame 7110 reports zero newly created outputs, 279 prepared output materials and
bindings, and 58 accepted dynamic preparations. Atlas CPU remains 24.230 ms.
Receivers take 8.461 ms (bindings 6.342 ms, including bulk registration 4.586 ms);
addresses take 5.559 ms (output materials 5.113 ms); source/specification work
takes 4.670 ms. Output material children are adoption 0.892 ms, transport
2.659 ms, certification 1.348 ms and records 0.159 ms. These are nested values.
Both complete Fireball action ranges have zero media, motion or world holds.
Packet-to-first-animation remains 62.592 / 70.282 ms, above the <30 ms target.

Two further shortcuts were measured and rejected before production edits.
An isolated native Vulkan comparison used 234 exact prepared source/material
groups, with 40 alternating repetitions and 18,720 rank/directory ownership
assertions. Passing precomputed keys instead of ordinary group discovery changed
the median from 0.517 to 0.435 ms. Prebinding 234 output overrides and checking
their identity changed 0.123 to 0.059 ms. Neither result meaningfully addresses
the live publication cost; no new registration or hidden-node binding mechanism
was retained. Evidence is `.runtime/atlas-register-probe-results.json` and its
standalone probe. This comparison has no whole-frame performance claim.

The large first-draw oracle has 311 total outputs and 1,156 initial receivers,
but its append changes only three static source owners. It qualifies growth and
exact pixels, not the CPU cost of the live door's 279 changed sources. A larger
batch implementation would have to preserve interleaved retained binds, group
deletions and exact rank assignment. No such unmeasured redesign was added.
Atlas production remains frozen for the same-code runtime comparison.
