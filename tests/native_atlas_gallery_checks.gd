extends "res://tools/profile_player_replay.gd"
## Actual Gallery WorldPreparation, native source/sight publication and first
## reveal. Uses the ordinary Play clock; no fixture rows or invented receipt.
var accepted_prefixes:Dictionary={}
var checked_candidates:Dictionary={}
var accepted_generations:Dictionary={}
var accepted_bulk_generations:Dictionary={}
var atlas_failures:Dictionary={}
var atlas_checks:int=0

func follow()->void:
    super.follow()
    var atlas=world.native_light_atlas
    var phase:Dictionary=atlas.last_reconcile_phases
    if phase.get("prepared_prefix_specs",0)>0:
        accepted_prefixes[atlas.revision]=int(phase.prepared_prefix_specs)
        accepted_generations[world.world_generation]=int(phase.prepared_prefix_specs)
        if phase.get("prepared_bulk_registered",0)>0:accepted_bulk_generations[world.world_generation]=int(phase.prepared_bulk_registered)
    var rejected:String=str(phase.get("prepared_prefix_rejected",phase.get("delta_fallback","")))
    if rejected.begins_with("duplicate_") or rejected.begins_with("unreserved_") or rejected=="incomplete_private_prefix":
        atlas_failures[rejected]=true
        if phase.has("delta_rejected_plan"):print("ATLAS_PLAN_FAILURE ",JSON.stringify(phase.delta_rejected_plan))
    if world.pending_world==null:return
    var candidate:Dictionary=world.pending_world.atlas_prefix
    if not candidate.get("complete",false):return
    var key:int=world.pending_world.get_instance_id()
    if checked_candidates.has(key):return
    checked_candidates[key]=true
    var plan:Dictionary=candidate.plan
    for id in plan.specs:
        atlas_checks+=1
        if not plan.positions.has(id):atlas_failures["Unreserved complete candidate: "+id]=true
    for source in candidate.source_patches.values():
        if not source.snapshot.has("batch_rows"):continue
        var sampled:Dictionary=source.snapshot
        for row in sampled.batch_rows:
            var id:String=str(source.entry.node.get_instance_id())+":"+str(row.id)
            atlas_checks+=1
            if not plan.positions.has(id) and not candidate.passive.receiver_index.has(id):
                atlas_failures["Unreserved actual Gallery floor: "+id]=true

func finish(wall_ms:float,display_ms:float)->void:
    if accepted_prefixes.is_empty():failures.append("Real Gallery did not accept any prepared atlas prefix")
    if end_ms>=3000.0:
        for generation in [2,3]:
            if not accepted_generations.has(generation):failures.append("Major Gallery reveal did not admit its prepared prefix: generation "+str(generation))
            if not accepted_bulk_generations.has(generation):failures.append("Major Gallery reveal skipped prepared native bulk registration: generation "+str(generation))
    if checked_candidates.is_empty():failures.append("Real Gallery did not expose a complete prepared candidate")
    for reason in atlas_failures:failures.append(reason)
    var report={"checks":atlas_checks,"failures":failures.duplicate(),"accepted_prefixes":accepted_prefixes,
        "candidate_count":checked_candidates.size(),"accepted_world_generations":accepted_generations,"accepted_bulk_generations":accepted_bulk_generations,"display_ms":world.timeline.display_ms,
        "scope":"Real Gallery initial/reveal WorldPreparation on the ordinary Play clock; every complete planned row owns an address before publication. Correctness run, not a whole-run performance claim."}
    FileAccess.open("res://generated/native_atlas_gallery_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("ATLAS_GALLERY ",JSON.stringify(report))
    await super.finish(wall_ms,display_ms)
