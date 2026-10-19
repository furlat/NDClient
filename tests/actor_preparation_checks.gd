extends SceneTree
## Exact recorded candidate loadouts and real native actor construction ownership.
## Headless geometry/material checks are separate from framebuffer qualification.
const Recording=preload("res://studio/recording.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
const Construction=preload("res://presentation/actor_construction.gd")
const Preparation=preload("res://presentation/world_preparation.gd")
const Characters=preload("res://presentation/characters.gd")
const Catalog=preload("res://source_catalog.gd")
const Graphs=preload("res://animation/graphs.gd")
var checks:int=0
var failures:Array=[]
class Probe extends "res://play.gd":
    func _ready()->void:
        set_process(false);set_process_unhandled_input(false)
        camera=Camera3D.new();add_child(camera);add_child(context_menu)
        generated_shadows.attach(self)
    func _process(_delta:float)->void:pass
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr("ACTOR_PREP_FAIL ",label)
func _initialize()->void:run.call_deferred()
func recorded_loadouts(index:Dictionary)->void:
    var timeline=Recording.restore(index,0.0)
    var endpoints:Dictionary={}
    for record in index.groups:
        var group:Dictionary=record.group
        endpoints[record.start_ms+group.duration_ms]=true
        for track in group.actor_tracks:
            endpoints[record.start_ms+track.start_ms]=true
            endpoints[record.start_ms+track.start_ms+track.duration_ms*.5]=true
        for component in group.get("components",[]):
            if component.kind=="sprite_layer":
                endpoints[record.start_ms+component.start_ms]=true
                endpoints[record.start_ms+component.start_ms+component.duration_ms*.5]=true
    var ordered:Array=endpoints.keys();ordered.sort()
    var layer_boundaries:int=0
    for at in ordered:
        if at<timeline.display_ms:continue
        var plan:Dictionary=timeline.replay_plan(at)
        if plan.segments.is_empty():continue
        var original:PackedByteArray=var_to_bytes([timeline.state,timeline.retained_components,timeline.crossed_audio,timeline.display_ms])
        var candidate:Dictionary=timeline._world_candidate(plan)
        check(var_to_bytes([timeline.state,timeline.retained_components,timeline.crossed_audio,timeline.display_ms])==original,"Preparing actual boundary does not consume state/audio/retention at "+str(at))
        var predicted:Dictionary=Construction.loadouts(candidate.actor_samples,candidate.actor_layers)
        timeline._apply_world_plan(plan)
        var actual:Dictionary=Construction.loadouts(timeline.actor_samples(),timeline.component_samples(index.cache))
        check(predicted==actual,"Prospective outfit/hand layers equal actual published samples at "+str(at))
        check(candidate.state==timeline.state and candidate.staged_actors==timeline.staged_actors(),"Prospective actor disclosure equals actual committed state at "+str(at))
        if not candidate.actor_layers.is_empty():layer_boundaries+=1
    check(layer_boundaries>0,"Real spells exercise temporary authored hand layers")
func host_for(index:Dictionary)->Probe:
    var host=Probe.new();host.catalog_cache=Catalog.source_snapshot(index.cache)
    var catalog:Dictionary=Catalog.read_file("catalog-index.json",host.catalog_cache)
    host.rigs=Catalog.read_file(catalog.rigs,host.catalog_cache)
    host.rig_config=Catalog.read_file(catalog.rig,host.catalog_cache)
    host.timeline=Recording.restore(index,0.0);host.media_metadata_ready=true
    root.add_child(host)
    return host
func selected(host:Probe)->Dictionary:
    for actor in host.timeline.state.actors.values():
        if not host.WorldRows.visible_actor(actor,host.timeline.state,false):continue
        var resolved:Dictionary=Characters.resolve(actor,host.timeline.state,host.catalog_cache)
        if resolved.ok and resolved.value!=null:return {"actor":actor,"row":resolved.value,"rig":host.rigs[resolved.value.rig]}
    return {}
func candidate_for(host:Probe,selected:Dictionary)->Node:
    var candidate=Preparation.new();host.add_child(candidate);candidate.host=host;candidate.hide()
    candidate.epoch=host.timeline.initialization_revision;candidate.quarter=host.quarter
    candidate.catalog_cache=host.catalog_cache;candidate.actor_catalog_owner=host.catalog_cache
    candidate.rigs=host.rigs;candidate.rig_config=host.rig_config;candidate.profile=host.profile
    candidate.camera=Camera3D.new();candidate.add_child(candidate.camera)
    var row:Dictionary=selected.row.duplicate(true)
    var id:String=row.id
    var layers:Array=Characters.layers(row,selected.rig,host.catalog_cache)
    var resting:Dictionary=Characters.rest_sample(selected.actor,selected.rig,host.catalog_cache)
    var bindings:Dictionary={}
    for layer in layers:
        var path:String=layer.paths[resting.value.clip]
        var binding:Dictionary=Construction.prepare_binding(selected.rig,layer,path,host.catalog_cache,
            host.source_depth,host.source_normals,host.character_light_profile,128.0/host.rig_config.TILE_W*row.scale,row.get("scale_x",1.0))
        bindings[layer.slot]=binding
        for texture_path in [binding.path]+binding.geometry.textures.values():
            if not host.textures.has(texture_path):
                var image:Image=Image.load_from_file(texture_path)
                check(image!=null and not image.is_empty(),"Actual raw source loads for prepared actor: "+texture_path)
                if image==null or image.is_empty():candidate.queue_free();return null
                host.textures[texture_path]=ImageTexture.create_from_image(image)
        host.source_images[binding.path]=host.textures[binding.path].get_image()
    candidate.result={"worker_ms":0.0,"worker_phases":{},"actor_members":{id:row},"actors":{id:{"row":row,"rig":selected.rig,
        "layers":layers,"entries":[],"new_entries":[],"playback":null,"reuse_actor":false,"retained_slots":{},
        "source_sample":resting.value,"source_bindings":bindings,"layer_clips":{},"source_ready":{},"source_cursor":0}}}
    candidate.actor_ids=[id]
    return candidate
func drain(host:Probe)->void:
    for frame in 60:
        host._dispose_views();await process_frame
        if host.retiring_node_count==0:break
    check(host.retiring_node_count==0,"Bounded retirement finishes all candidate-owned nodes")
func worker_isolation(index:Dictionary)->void:
    var host=host_for(index)
    host.catalog_cache.__creature_shadow_rigs={"prior-immutable-result":true}
    var plan:Dictionary=host.timeline.replay_plan(750.0)
    var boundary:Dictionary=host.timeline._world_candidate(plan)
    var candidate=Preparation.new();host.add_child(candidate);candidate.configure(host,boundary)
    candidate.join()
    check(candidate.result.get("complete",false),"Actual reveal passive world worker completes actor selection")
    check(host.catalog_cache.__creature_shadow_rigs=={"prior-immutable-result":true},"Worker creature-shadow memo never mutates the live owner's directory")
    var catalog:Dictionary=Catalog.read_file("catalog-index.json",host.catalog_cache)
    var creatures:Dictionary={"content.neurodragon:creature:creature.goblin@1":"smallscale.goblin01"}
    var creature:String="content.neurodragon:creature:creature.goblin@1"
    var worker_cache:Dictionary=Construction.source_cache(host.catalog_cache)
    Characters._generated_creature_shadow({"creature_content_ref":creature},host.rigs[creatures[creature]],worker_cache)
    check(worker_cache.__creature_shadow_rigs=={"prior-immutable-result":true} and not is_same(worker_cache.__creature_shadow_rigs,host.catalog_cache.__creature_shadow_rigs),"Read-only built creature-shadow selection leaves the live owner unchanged and its worker shell private")
    check(is_same(worker_cache[catalog.rigs],host.catalog_cache[catalog.rigs]),"Worker still shares immutable rig/source data")
    check(host.entries.is_empty() and host.visual_actors.is_empty(),"Passive worker creates no native actors or live membership")
    host.pending_world=candidate;host._discard_world_preparation();await drain(host)
    host.queue_free();await process_frame;await process_frame
func construction_ownership(index:Dictionary)->void:
    var host=host_for(index);var selection:Dictionary=selected(host)
    check(not selection.is_empty(),"Actual recorded actor resolves original modular source")
    if selection.is_empty():host.queue_free();return
    var id:String=selection.row.id
    var candidate=candidate_for(host,selection)
    if candidate==null:host.queue_free();return
    candidate._prepare_actor()
    var graph_ref=weakref(candidate.native_actors[id].playback)
    check(host.entries.is_empty() and host.visual_actors.is_empty(),"Hidden graph construction cannot publish actor membership")
    check(candidate.take_actor(id,selection.row,selection.rig).is_empty(),"Partial graph without its authored layers cannot be adopted")
    while candidate.actor_cursor<candidate.actor_ids.size() and candidate.media_issue.is_empty():
        if not candidate._prepare_actor():await process_frame
    var prepared:Dictionary=candidate.native_actors[id]
    check(prepared.entries.all(func(entry):return not entry.node.is_visible_in_tree()),"Every staged real sprite layer is hidden before admission")
    check(host.entries.is_empty() and host.playbacks.is_empty(),"Complete hidden construction does not alter live graph/layer directories")
    var mismatched:Dictionary=selection.row.duplicate(true);mismatched.appearance.skin_tint=0x010203
    check(candidate.take_actor(id,mismatched,selection.rig).is_empty(),"Changed appearance rejects the prepared source")
    mismatched=selection.row.duplicate(true);mismatched.equipment_layers=mismatched.equipment_layers.duplicate(true)
    mismatched.equipment_layers.append({"category":"different"})
    check(candidate.take_actor(id,mismatched,selection.rig).is_empty(),"Changed loadout rejects the prepared source")
    check(candidate.take_actor(id,selection.row,selection.rig.duplicate(true)).is_empty(),"Equal-value replacement rig still rejects old authoring ownership")
    host.quarter+=1;check(candidate.take_actor(id,selection.row,selection.rig).is_empty(),"Camera quarter invalidates staged construction");host.quarter-=1
    host.timeline.initialization_revision+=1;check(candidate.take_actor(id,selection.row,selection.rig).is_empty(),"New Timeline epoch invalidates candidate ownership");host.timeline.initialization_revision-=1
    var original_cache:Dictionary=host.catalog_cache;host.catalog_cache=original_cache.duplicate()
    check(candidate.take_actor(id,selection.row,selection.rig).is_empty(),"Authoring reload invalidates source ownership");host.catalog_cache=original_cache
    var neutral:Dictionary=Construction.Conditions.material(id,[])
    var neutral_parameters:Dictionary=Construction.Conditions.parameters(neutral,host.textures,host.resources)
    check(prepared.entries.all(func(entry):return neutral_parameters.keys().all(func(name):return entry.source_parameters[name]==neutral_parameters[name])),"Hidden new layers carry the exact current neutral condition key")
    for entry in prepared.entries:
        var expected=ShaderMaterial.new();expected.shader=entry.material.shader
        Construction.Conditions.bind(expected,neutral,host.textures,host.resources)
        for uniform in expected.shader.get_shader_uniform_list():
            var name:String=uniform.name
            var value:Variant=expected.get_shader_parameter(name)
            if value!=null:check(entry.material.get_shader_parameter(name)==value,"Hidden neutral initialization equals original binder: "+name)
    # The key owns a passive value snapshot, not a mutable frame sample.
    neutral.alpha=.25
    check(prepared.entries.all(func(entry):return entry.source_parameters.condition_alpha==1.0),"A later sampled material value cannot mutate prepared condition keys")
    var original_entries:Array=prepared.entries.duplicate()
    # Compare with the exact shared original constructor, under an independent owner.
    var reference=host_for(index)
    for i in prepared.layers.size():
        var old:Dictionary=Construction.layer(reference,selection.row,selection.rig,prepared.layers[i],i)
        var now:Dictionary=prepared.entries[i]
        check(old.actor_layer==now.actor_layer and old.cell==now.cell and old.pivot==now.pivot and old.scale==now.scale and old.node.mesh.size==now.node.mesh.size and old.node.mesh.center_offset==now.node.mesh.center_offset,"Original layer geometry/role/order is unchanged: "+str(i))
        for name in ["layer_alpha","shadow","tint","normal_smoothness"]:
            check(old.material.get_shader_parameter(name)==now.material.get_shader_parameter(name),"Original constructor shader parameter "+name+" layer "+str(i))
    reference.queue_free();await process_frame
    host.timeline.state=host.timeline.state.duplicate();host.timeline.state.actors={id:selection.actor}
    host.displayed_samples=host.timeline.actor_samples();host.displayed_components=[]
    candidate.entries=[];host.prepared_actor_owner=candidate
    host._sync_actors()
    check(host.prepared_actor_owner==null and host.visual_actors.has(id),"Ordinary actor synchronization consumes and retires the staged owner")
    check(host.playbacks[id]==graph_ref.get_ref() and host.visual_actors[id].entries==original_entries,"Adoption reuses the exact staged graph/layer nodes")
    check(original_entries.all(func(entry):return entry.node.get_parent()==host and is_same(entry.placement,host.visual_actors[id].row)),"Every adopted layer shares the current row and stable live parent")
    Graphs.sample(host.playbacks[id],"Idle",.2,"actual-current")
    check(is_equal_approx(host.playbacks[id].sample_seconds,.2),"Current graph sampler still owns animation time after adoption")
    await drain(host)
    check(is_instance_valid(graph_ref.get_ref()) and original_entries.all(func(entry):return is_instance_valid(entry.node)),"Retiring the candidate cannot free adopted live nodes")
    for partial in [true,false]:
        var rejected=candidate_for(host,selection)
        rejected._prepare_actor()
        if not partial:
            while rejected.actor_cursor<rejected.actor_ids.size() and rejected.media_issue.is_empty():
                if not rejected._prepare_actor():await process_frame
        var private_graph=weakref(rejected.native_actors[id].playback)
        host.pending_world=rejected;host._discard_world_preparation();await drain(host)
        check(private_graph.get_ref()==null,"Cancelled "+("partial" if partial else "complete")+" candidate releases only its private graph")
        check(is_instance_valid(graph_ref.get_ref()),"Cancelling another candidate preserves the displayed actor")
    host.queue_free();await process_frame;await process_frame
func run()->void:
    var descriptor:Dictionary=Fixtures.case_record("gallery")
    var bundle:Dictionary=Recording.read_case(descriptor)
    check(bundle.get("ok",false),"Actual Gallery recording admits: "+str(bundle.get("error","")))
    if not bundle.get("ok",false):quit(1);return
    var index:Dictionary=Recording.view_index(bundle,"amber")
    var original:PackedByteArray=var_to_bytes([index.initialization,index.groups])
    recorded_loadouts(index)
    await worker_isolation(index)
    await construction_ownership(index)
    check(var_to_bytes([index.initialization,index.groups])==original,"Source recording and compiled groups remain immutable")
    var report={"checks":checks,"failures":failures,"scope":"Real-recording candidate/live outfit parity and actual native actor graph/layer ownership. No framebuffer or performance claim."}
    FileAccess.open("res://.runtime/actor-preparation-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("ACTOR_PREPARATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
