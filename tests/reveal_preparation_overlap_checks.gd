extends SceneTree
## Actual graphs, native source layers and environment constructors, with one
## deliberately absent source. Pixel parity remains the native reveal suites.
const Preparation=preload("res://presentation/world_preparation.gd")
const Construction=preload("res://presentation/actor_construction.gd")
const Body=preload("res://presentation/body_sources.gd")
const Renderer=preload("res://presentation/native_spell_renderer.gd")
const Shadows=preload("res://presentation/canvas_shadows.gd")
const A="/fixture/deferred-a.png"
const B="/fixture/ready-b.png"
const ENV="/fixture/ready-env.png"
const LATE_ENV="/fixture/deferred-env.png"
class Host extends "res://presentation/sprite_sources.gd":
    var textures:Dictionary={}
    var resources:Dictionary={}
    var animation_templates:Array=[]
    var external_playback:bool=false
    var character_light_profile:String="original"
    var generated_shadows=Shadows.new()
    var component_renderer={"native_spells":Renderer.new()}
    var scenery_consumers:Dictionary={}
    var floor:Dictionary={}
    func texture(path:String)->Texture2D:return textures.get(path)
    func _scenery_ground_entry(_id:String)->Dictionary:return floor
var checks:int=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("REVEAL_OVERLAP_FAIL ",label)
func actor(id:String,paths:Array,rig:Dictionary,cache:Dictionary)->Dictionary:
    var row={"id":id,"kind":"actor","rig":"fixture","position":[0,0],"base_height_steps":0,"scale":1.0,"facing":"SW"}
    var layers:Array=[];var bindings:Dictionary={}
    for i in paths.size():
        var layer={"slot":"body" if i==0 else "head","paths":{"Idle":paths[i]},"alpha":1.0,"tint":0xffffff}
        layers.append(layer)
        bindings[layer.slot]=Construction.prepare_binding(rig,layer,paths[i],cache,false,false,"original",1.0,1.0)
    return {"row":row,"rig":rig,"layers":layers,"entries":[],"new_entries":[],"playback":null,
        "reuse_actor":false,"retained_slots":{},"source_sample":{"clip":"Idle","source_seconds":0.0},"source_bindings":bindings}
func environment(id:String,path:String)->Dictionary:
    return {"id":id,"kind":"prop","source_sprite":id,"position":[0,0],"base_height_steps":0,"orientation":"east","material":"stone"}
func run()->void:
    var host=Host.new();root.add_child(host)
    host.rig_config={"TILE_W":128.0,"FACING_CYCLE":["SW"]}
    host.source_depth=false;host.source_normals=false
    host.camera=Camera3D.new();host.add_child(host.camera)
    var rig={"cell_width":2,"cell_height":2,"origin_y_from_ground":0,"facing_rows":{"SW":0},"clips":{"Idle":{"frames":1,"fps":1}}}
    host.rigs={"fixture":rig}
    var index=Body.Index.new();var layer=Body.Layer.new()
    for path in [A,B]:index.source_owners[path]=["fixture","Idle"];layer.headers[path]={"width":2,"height":2}
    layer.clips={"Idle":{}}
    host.catalog_cache[Body.KEY]={"index":index,"loaded":{"fixture":layer}}
    host.catalog_cache.unity_sources={}
    host.catalog_cache["res://generated/environment_texture_layouts.json"]={"layouts":{}}
    for pair in [["ready",ENV],["late",LATE_ENV]]:
        var record={"path":pair[1],"native_size":[2,2],"pivot":[1,2],"scale":1.0,"roles":[]}
        host.catalog_cache.unity_sources[pair[0]]={"records":[record,record,record,record]}
    var image=Image.create(2,2,false,Image.FORMAT_RGBA8);image.fill(Color.WHITE)
    var texture=ImageTexture.create_from_image(image)
    for path in [B,ENV]:host.textures[path]=texture;host.source_images[path]=image
    var candidate=Preparation.new();host.add_child(candidate);candidate.host=host;candidate.hide()
    candidate.membership_base={"groups":{},"ground":{}}
    candidate.catalog_cache=host.catalog_cache;candidate.rig_config=host.rig_config;candidate.rigs=host.rigs
    candidate.camera=Camera3D.new();candidate.add_child(candidate.camera)
    var first:Dictionary=actor("first",[A,B],rig,host.catalog_cache)
    var second:Dictionary=actor("second",[B],rig,host.catalog_cache)
    var ready_row:Dictionary=environment("ready",ENV);var missing_row:Dictionary=environment("late",LATE_ENV)
    candidate.result={"actors":{"first":first,"second":second},"wanted":{"late":missing_row,"ready":ready_row},
        "ground":{},"object_sources":{},"ground_sources":{},"visibility":{},"visibility_changes":{}}
    for id in candidate.result.wanted:candidate.result.object_sources[id]=Preparation._row_sources(candidate.result.wanted[id],0,host.catalog_cache)
    candidate.actor_ids=["first","second"];candidate.wanted_ids=["late","ready"]
    for attempt in 20:
        if not candidate._prepare_actor():break
    check(first.entries.size()==2 and first.entries[0].actor_layer.paths.Idle==A and first.entries[1].actor_layer.paths.Idle==B,"Blocked earlier layer preserves canonical entries while later ready layer constructs")
    check(not first.source_ready.has(0) and first.source_ready.has(1),"Missing source stays unfinished while independent same-actor source binds")
    check(second.get("complete",false) and not first.get("complete",false) and candidate.actor_cursor==1,"Ready actor graph/layer/shadow preparation completes while another actor is blocked")
    check(candidate.blocked_actor.get("path")==A,"Deferred actor diagnostic identifies its actual missing source")
    check(candidate._prepare_object(Time.get_ticks_usec()+100000),"Later ready environment row constructs despite earlier absent row and actor")
    check(candidate.native_groups.has("ready") and not candidate.native_groups.has("late"),"Only resident environment operands create private native groups")
    check(host.entries.is_empty() and host.actor_entries.is_empty() and candidate.entries.all(func(entry):return not entry.node.is_visible_in_tree()),"All overlap work remains private and cannot change displayed membership")
    check(not candidate._prepare_actor(Time.get_ticks_usec()-1),"Expired shared allowance defers actor retry without declaring completion")
    var blocked_nodes:Array=first.entries.map(func(entry):return entry.node)
    host.textures[A]=texture;host.source_images[A]=image;host.textures[LATE_ENV]=texture
    for attempt in 20:
        if candidate.actor_cursor==candidate.actor_ids.size():break
        candidate._prepare_actor()
    check(first.get("complete",false) and candidate.actor_cursor==2 and first.entries.map(func(entry):return entry.node)==blocked_nodes,"Arriving exact source finishes retained original layers without recreation")
    check(first.outfit_clip=="Idle" and first.outfit_profile=="original" and first.condition_parameters.is_read_only(),"Complete chosen sources publish actual outfit and shared immutable neutral operands")
    check(candidate._prepare_object(Time.get_ticks_usec()+100000) and candidate.objects_complete.size()==2,"Previously deferred environment source completes its exact original row")
    check(not candidate._prepare_object(Time.get_ticks_usec()+100000) and not candidate._prepare_ground(Time.get_ticks_usec()+100000),"Completed construction lanes return without rescanning unrelated entries")
    # A retained packed row may need a sight change even when a sparse geometry
    # packet touches it; full replacement packets already own exact styles.
    var floor_node=MeshInstance3D.new();floor_node.mesh=QuadMesh.new();host.add_child(floor_node)
    var floor={"node":floor_node,"ground_indices":{"floor":0},"scenery_values":[0.0]}
    host.floor=floor
    candidate.membership={"removed":{},"scenery":{"writes":[]}}
    candidate.scenery_packet_entries={floor_node.get_instance_id():{"sparse":true,"row_changes":{"floor":{}}}}
    candidate._prepare_scenery_write("floor",floor,0,1.0)
    check(candidate.membership.scenery.writes.size()==1 and floor.scenery_values==[0.0],"Sparse geometry preserves live channels so exact retained sight write is prepared without early mutation")
    candidate.membership.scenery.writes=[]
    candidate.scenery_packet_entries[floor_node.get_instance_id()]={"values":[1.0]}
    candidate._prepare_scenery_write("floor",floor,0,1.0)
    check(candidate.membership.scenery.writes.is_empty(),"Full floor style ownership excludes redundant per-row sight writes")
    candidate.membership.scenery.writes=[];candidate.scenery_packet_entries={}
    candidate._prepare_scenery_write("floor",floor,0,0.0)
    check(candidate.membership.scenery.writes.is_empty(),"Unchanged retained style emits no operation")
    host.floor={};host.queue_free();await process_frame;await process_frame
    var report={"checks":checks,"failures":failures,"scope":"Exact native source/graph construction ownership under missing actor/environment inputs, canonical layer order and prepared retained style operands. No live latency/pixel claim."}
    FileAccess.open("res://.runtime/reveal-preparation-overlap-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("REVEAL_PREPARATION_OVERLAP_CHECKS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
