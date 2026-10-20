extends SceneTree
const Fixtures=preload("res://tests/recording_fixtures.gd")
const World = preload("res://presentation/world.gd")
const Preparation = preload("res://presentation/world_preparation.gd")
const Ground = preload("res://presentation/ground_data.gd")
const Journal = preload("res://sdk/journal.gd")
const BloodRenderer=preload("res://presentation/blood_renderer.gd")
const NativeSources = preload("res://presentation/native_presentation_sources.gd")
var checks = 0
var failures: Array = []
var cache = {"res://build/presentation/environment/world.res":{"terrain":{"stone":{"n":"fixture","e":"fixture","s":"fixture","w":"fixture"}},"props":{},
        "stone_wall_straight":{"n":"fixture","e":"fixture","s":"fixture","w":"fixture"},"wall_corner_faces":{}},
    "res://build/presentation/environment/resources.res":{"resources":{"fixture":{"path":"/fixture/stone.png","native_size":[2,2],"pivot":[1,2],"scale":1.0}}},
    "res://build/presentation/environment/texture_layouts.res":{"layouts":{}},
    "res://build/presentation/environment/index.res":{"doors":{},"props":{},"traps":{}}}
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures.append(label); print("WORLD_PREPARATION_SPARSE_FAIL ",label)
func _initialize() -> void:
    for count in [64,8192]: exercise(count)
    actual_initial_residues()
    print(JSON.stringify({"checks":checks,"failures":failures,"scope":"Actual WorldPreparation worker with an unchanged unrelated floor; sparse routing, no live base mutation, cancelled worker completion and source adoption. No rendered-scene/timing acceptance."}))
    quit(0 if failures.is_empty() else 1)
func exercise(count: int) -> void:
    var state = {"tiles":{},"objects":{},"actors":{},"senses":{"visible":Journal.Reducer.Cells.mask([[0,0]]),"objects":{},"light_sources":{}}}
    for i in count:
        state.tiles[str(i)+",0"] = {"tile_uuid":"tile-"+str(i),"position":[i,0],"elevation_steps":0,"surface":{"base_material":"stone"}}
    state.objects["wall"] = {"placement":{"kind":"boundary","position":[0,1],"base_height_steps":0,"top_height_steps":3,"boundary_direction":"north"},
        "item":{"item_id":"wall","boundary_structure":{"structure":"wall","material":"stone"}}}
    var base = {}
    World.update_rows(state,cache,base,{"full":true})
    var cells = {}; var visibility = World.current_ids(state,base.boundaries,cells)
    var original = var_to_bytes(base)
    var changed: Dictionary = state.objects["wall"].duplicate(true)
    changed.placement.top_height_steps = 4
    state.objects["wall"] = changed
    var input = {"state":state,"changes":{"full":false,"tiles":{},"objects":{"wall":true},"senses":false,"order":[]},
        "actor_state":state,"staged_actors":{},"actor_samples":{},"actor_loadouts":{},"existing_actors":{},
        "cache":cache.duplicate(),"retained":base,"ground":{},"quarter":0,"basis":Basis.IDENTITY,
        "environment_options":{"depth":true,"normals":true},
        "background":true,"global_rows":false,"visibility":visibility,"visible_cells":cells}
    var task = Preparation.new()
    var worker = WorkerThreadPool.add_task(task._derive.bind(input))
    # Cancellation changes only ownership intent; retain the borrowed base until
    # the task completes, then discard its result without touching publication.
    task.stale = true
    WorkerThreadPool.wait_for_task_completion(worker)
    check(var_to_bytes(base)==original,"Cancelled worker leaves all retained rows/cells untouched at size "+str(count))
    var prepared: Dictionary = task.result
    check(prepared.complete and not prepared.full_membership and prepared.wanted.keys()==["wall"],"Only changed static group is routed at size "+str(count))
    check(prepared.ground.is_empty() and prepared.packets.is_empty() and prepared.geometry.is_empty(),"Unchanged floor and wall bucket directory are not rebuilt at size "+str(count))
    check(prepared.row_patch.resolved==1 and prepared.row_patch.writes.object_rows.size()==1,"One dirty object projected at size "+str(count))
    check(is_same(prepared.visibility,visibility) and is_same(prepared.visible_cells,cells) and prepared.visibility_changes.is_empty(),"Unchanged sight borrows immutable owner sets")
    World.apply_changes(base,prepared.row_patch)
    check(base.result==World.rows(state,cache),"Completed projection matches exhaustive independent source rows")
    var binding_input:Dictionary=input.duplicate()
    binding_input.changes={"full":false,"tiles":{},"objects":{},"senses":false,"order":[]}
    binding_input.world_changed=false
    var binding_only=Preparation.new()
    worker=WorkerThreadPool.add_task(binding_only._derive.bind(binding_input));WorkerThreadPool.wait_for_task_completion(worker)
    check(binding_only.result.get("source_only",false),"Source-only unchanged world can publish without light/atlas preparation "+str(count))
    check(binding_only.result.light_resolution.is_empty(),"Source-only cut does not resolve ordinary light/cookie preparation "+str(count))
    binding_input.world_changed=true
    var connector=Preparation.new()
    worker=WorkerThreadPool.add_task(connector._derive.bind(binding_input));WorkerThreadPool.wait_for_task_completion(worker)
    check(not connector.result.get("source_only",true),"Connector-only world revision retains normal ordered world publication "+str(count))
    binding_only.free();connector.free()
    task.free()

func actual_initial_residues()->void:
    var journal=Journal.new()
    var opened:Dictionary=journal.open(Fixtures.journal("gallery"),true,false)
    check(opened.ok,"Actual Gallery recording opens for persistent-residue preparation")
    if not opened.ok:return
    var restored:Dictionary=journal.replay(17)
    check(restored.ok,"Actual Fireball after-state reduces before renderer preparation")
    if not restored.ok:return
    var state:Dictionary=journal.state
    check(state.tiles.values().any(func(tile):return tile.get("residues",[]).any(func(value):return value.residue_id=="residue.blood")),
        "Actual Gallery after-state includes persistent blood without a new presentation component")
    var sources:Dictionary=Preparation.Catalog.source_snapshot({})
    check(Preparation.Catalog.prepared_residue_asset(sources).is_empty(),"Fresh source owner has not admitted the blood asset")
    var input={"state":state,"changes":{"full":true,"tiles":{},"objects":{},"senses":true,"order":[]},
        "actor_state":state,"staged_actors":{},"actor_samples":{},"actor_loadouts":{},"existing_actors":{},
        "cache":sources,"retained":{},"ground":{},"quarter":0,"basis":Basis.IDENTITY,
        "environment_options":{"depth":true,"normals":true},
        "background":true,"global_rows":true,"visibility":{},"visible_cells":{}}
    var task=Preparation.new()
    var worker=WorkerThreadPool.add_task(task._derive.bind(input))
    WorkerThreadPool.wait_for_task_completion(worker)
    check(task.result.get("complete",false),"Actual initial world finishes with its persistent residue source")
    if task.result.get("complete",false):
        var admitted:Dictionary=Preparation.Catalog.prepared_residue_asset(task.result.source_files)
        check(not admitted.is_empty() and is_same(admitted,Preparation.Catalog.prepared_residue_asset(sources)),
            "Existing world projection hands off the exact admitted blood source before any sampling")
        check(not task.result.source_files.has("catalog/action_media_assets.json"),"Initial residue preparation does not parse the full legacy media catalog")
        var actual_count:int=state.tiles.values().filter(func(tile):return not Preparation.Blood.residue(tile).is_empty()).size()
        var renderer=BloodRenderer.new()
        var before_tiles:Dictionary={"previous":{}}
        renderer.tiles=before_tiles
        check(renderer.tiles=={"previous":{}} and task.result.blood_index.full,"Worker prepares full residue classification without changing the displayed index")
        renderer.publish_tile_index(state.tiles,1,task.result.blood_index)
        var expected_index:Dictionary={}
        for key in state.tiles:
            if not Preparation.Blood.residue(state.tiles[key]).is_empty():expected_index[key]=state.tiles[key]
        check(renderer.tiles==expected_index and is_same(renderer.tiles,task.result.blood_index.updates),"Full publication adopts exact canonical residue index reference")
        check(is_same(task.result.blood_index.retired,before_tiles),"Replaced index stays owned by retiring preparation instead of destructing at cue")
        check(task.result.blood_rows.size()==actual_count and actual_count>0,"Initial worker prepares every actual residue including offscreen cells")
        var future_solids:Dictionary={}
        for actor in task.result.actors.values():
            for layer in actor.layers:
                if layer.slot=="shadow" or not layer.get("effect",{}).is_empty():continue
                var binding:Dictionary=actor.source_bindings.get(layer.slot,{})
                if binding.is_empty():continue
                var optical:Dictionary=Preparation.ActorConstruction.CharacterGeometry.BodySources.descriptor(binding.path,layer.slot,task.result.source_files).get("optical_paths",{})
                if not optical.is_empty():future_solids[optical.solid]=true
        var source_record:Dictionary=task.result.required_source_record
        check(source_record.get("roles",{}).size()==future_solids.size() and not future_solids.is_empty(),"Worker declares all and only exact selected ordinary body solid masks together")
        for path in source_record.get("roles",{}):check(future_solids.has(path) and source_record.roles[path][1]==0,"Future mask record is an immutable GPU-only source role")
        for prepared_blood in task.result.blood_rows.values():
            check(is_same(prepared_blood.cache.value,prepared_blood.value) \
                and prepared_blood.kernels==Preparation.Blood.kernels(prepared_blood.value,prepared_blood.tile.position,[],prepared_blood.source,prepared_blood.cache),
                "Persistent field worker owns exact canonical kernels before native construction")
        var source_files:Dictionary=Preparation.Catalog.source_snapshot(task.result.source_files)
        source_files.erase(Preparation.Catalog.ENVIRONMENT+"residues/blood.res")
        var base:Dictionary={};World.update_rows(state,source_files,base,{"full":true})
        var dirty:String=""
        for key in state.tiles:
            if state.tiles[key].get("residues",[]).any(func(value):return value.residue_id=="residue.blood"):dirty=key;break
        var cells:Dictionary={};var visibility:Dictionary=World.current_ids(state,base.boundaries,cells)
        input=input.duplicate();input.cache=source_files;input.retained=base
        input.changes={"full":false,"tiles":{dirty:true},"objects":{},"senses":false,"order":[]}
        input.global_rows=false;input.visibility=visibility;input.visible_cells=cells
        var unchanged=Preparation.new()
        worker=WorkerThreadPool.add_task(unchanged._derive.bind(input));WorkerThreadPool.wait_for_task_completion(worker)
        check(unchanged.result.get("complete",false) and unchanged.result.row_patch.visual_changes.is_empty(),
            "Actual blood tile requires no terrain projection change")
        check(not Preparation.Catalog.prepared_residue_asset(unchanged.result.get("source_files",{})).is_empty(),
            "Dirty authoritative tile admits its residue source even with unchanged terrain geometry and no injury component")
        check(unchanged.result.blood_rows.has(dirty),"Dirty residue without injury component has prepared field operands")
        check(not unchanged.result.blood_index.full and unchanged.result.blood_index.updates.keys()==[dirty],"Sparse worker classifies only the actual dirty canonical tile")
        var displayed_index:Dictionary=renderer.tiles
        renderer.publish_tile_index(state.tiles,2,unchanged.result.blood_index)
        check(is_same(renderer.tiles,displayed_index) and renderer.tiles==expected_index,"Sparse publication preserves index ownership and exact exhaustive classification")
        input.blood_existing={dirty:{"value":Preparation.Blood.residue(state.tiles[dirty]),"source":Preparation.Catalog.prepared_residue_asset(unchanged.result.source_files)}}
        var retained=Preparation.new();worker=WorkerThreadPool.add_task(retained._derive.bind(input));WorkerThreadPool.wait_for_task_completion(worker)
        check(retained.result.blood_rows.is_empty(),"Same canonical residue and source do not rerun worker kernels")
        var removed_input:Dictionary=input.duplicate();removed_input.state=state.duplicate();removed_input.state.tiles=state.tiles.duplicate();removed_input.state.tiles.erase(dirty)
        removed_input.actor_state=removed_input.state;removed_input.changes={"full":true,"tiles":{},"objects":{},"senses":true,"order":[]};removed_input.global_rows=true
        var removed=Preparation.new();worker=WorkerThreadPool.add_task(removed._derive.bind(removed_input));WorkerThreadPool.wait_for_task_completion(worker)
        check(removed.result.blood_rows.get(dirty,{}).get("removed",false),"Full snapshot retires old fields whose tile disappeared")
        renderer.publish_tile_index(removed_input.state.tiles,3,removed.result.blood_index)
        expected_index.erase(dirty)
        check(renderer.tiles==expected_index and not renderer.tiles.has(dirty),"Full authoritative tile removal drops exactly its residue index member")
        var clear_input:Dictionary=input.duplicate();clear_input.state=state.duplicate();clear_input.state.tiles=state.tiles.duplicate()
        clear_input.state.tiles[dirty]=state.tiles[dirty].duplicate();clear_input.state.tiles[dirty].residues=[]
        clear_input.actor_state=clear_input.state
        var cleared=Preparation.new();worker=WorkerThreadPool.add_task(cleared._derive.bind(clear_input));WorkerThreadPool.wait_for_task_completion(worker)
        check(cleared.result.blood_index.removed.has(dirty) and not cleared.result.blood_index.updates.has(dirty),"Sparse authoritative residue removal prepares exact index erasure")
        renderer.publish_tile_index(clear_input.state.tiles,4,cleared.result.blood_index)
        check(renderer.tiles==expected_index and is_same(renderer.tiles_owner,clear_input.state.tiles) and renderer.tiles_revision==4,"Sparse residue removal publishes canonical owner/revision without rescanning terrain")
        renderer.sync_tiles(clear_input.state.tiles,4)
        check(renderer.tiles==expected_index,"Normal first sample retains the already published residue classification")
        cleared.free();retained.free();removed.free()
        unchanged.free()
    task.free()
