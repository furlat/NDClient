extends "res://tools/profile_player_replay.gd"
## Actual Gallery on the ordinary player clock, then an exhaustive displayed
## actor rebuild at the same published time. No altered event/animation clocks.
var actor_checks:int=0
var actor_failures:Array=[]
var seen_candidates:Dictionary={}
var seen_materials:Dictionary={}
var seen_fixture_materials:Dictionary={}
func actor_check(value:bool,message:String)->void:
    actor_checks+=1
    if not value:actor_failures.append(message);printerr("ACTOR_NATIVE_FAIL ",message)
func follow()->void:
    super.follow()
    if world.pending_world==null:return
    var candidate=world.pending_world
    var count:int=0
    for fixture in candidate.atlas_fixture_shells.values():
        var material:Dictionary=fixture.get("materials",{})
        if not material.is_empty():
            seen_fixture_materials[fixture.entry.node.get_instance_id()]={"output":material.output.received_material.get_instance_id(),
                "groups":material.groups.values().map(func(group):return group.material.get_instance_id())}
    for actor in candidate.native_actors.values():
        for materials in actor.get("materials",{}).values():
            seen_materials[materials.entry.node.get_instance_id()]=materials.output.received_material.get_instance_id()
            actor_check(materials.specs.is_empty() and materials.receivers.is_empty(),"Future actor material copies have no receiver geometry or address")
        for entry in actor.entries:
            actor_check(not entry.node.is_visible_in_tree(),"Unpublished future actor layer remains hidden")
            actor_check(entry not in world.entries and entry not in world.actor_entries,"Future layer is absent from both live directories")
            count+=1
    if count>0:seen_candidates[candidate.get_instance_id()]=count
func capture()->Image:
    await process_frame;await RenderingServer.frame_post_draw
    await process_frame;await RenderingServer.frame_post_draw
    return root.get_texture().get_image()
func resample()->void:
    world._sample_actors();world._sample_fixtures();world._sync_native_lighting();world._sort_draws()
    world.native_light_atlas.sync_output(world,[world.world_generation,world.quarter,world.scenery_revision,world.wall_mode,world.native_light_atlas.revision],true)
    world.component_renderer.native_spells.sync(world)
func changed_condition_control(before:Image)->void:
    # Renderer-input control using the actual authored Hidden material. It never
    # enters Timeline, creates an SDK event or changes canonical condition state.
    var id:String=caster
    actor_check(world.visual_actors.has(id),"Recorded caster exists for changed-at-admission material control")
    if not world.visual_actors.has(id):return
    var original_components:Array=world.displayed_components
    var recipe:Dictionary=world.Conditions.recipe({"behavior_id":"condition.hidden"},world.catalog_cache)
    var sample:Dictionary={"kind":"condition","actor_uuid":id,"condition_uuid":"actor-preparation-control", "id":"actor-preparation-control",
        "recipe":recipe,"alpha":1.0,"age_ms":200.0,"initial":false,"source":"authored Hidden material admission control"}
    world.displayed_components=original_components.duplicate();world.displayed_components.append(sample)
    var changed:Dictionary=world.Conditions.material(id,world.displayed_components)
    actor_check(changed.alpha<1.0,"Delivered Hidden authoring supplies a nonneutral material for the control")
    var candidate=world.WorldPreparation.new();world.add_child(candidate);candidate.host=world;candidate.hide()
    candidate.epoch=world.timeline.initialization_revision;candidate.quarter=world.quarter
    candidate.catalog_cache=world.catalog_cache;candidate.actor_catalog_owner=world.catalog_cache
    candidate.rigs=world.rigs;candidate.rig_config=world.rig_config;candidate.profile=world.profile
    candidate.camera=Camera3D.new();candidate.add_child(candidate.camera)
    var row:Dictionary=world.visual_actors[id].row.duplicate(true);var rig:Dictionary=world.rigs[row.rig]
    candidate.result={"worker_ms":0.0,"actors":{id:{"row":row,"rig":rig,
        "layers":world.Characters.layers(row,rig,world.catalog_cache),"entries":[],"playback":null,
        "source_sample":{"clip":world.playbacks[id].clip,"source_seconds":world.playbacks[id].sample_seconds}}}}
    candidate.actor_ids=[id]
    while candidate.actor_cursor<candidate.actor_ids.size():candidate._prepare_actor()
    var prepared:Dictionary=candidate.native_actors[id]
    actor_check(prepared.entries.all(func(entry):return not entry.node.is_visible_in_tree() and entry.material.get_shader_parameter("condition_alpha")==1.0),"New private layers are neutral and hidden before changed-condition admission")
    var nodes:Array=prepared.entries.map(func(entry):return entry.node)
    actor_check(not prepared.get("materials",{}).is_empty(),"Changed-condition control prepares real neutral source/receiving copies before admission")
    var old_outputs:Array=prepared.materials.values().map(func(materials):return materials.output.received_material.get_instance_id())
    world._retire_actor(id);candidate.entries=[];world.prepared_actor_owner=candidate;world.actor_revision=-1
    world._sync_actors();resample()
    actor_check(world.visual_actors[id].entries.map(func(entry):return entry.node)==nodes,"Changed condition keeps exact prepared geometry ownership")
    actor_check(world.visual_actors[id].entries.all(func(entry):return entry.material.get_shader_parameter("condition_alpha")==changed.alpha),"Actual live sampler replaces neutral binding with current condition at admission")
    actor_check(world.visual_actors[id].entries.all(func(entry):return not entry.has("received_material") or entry.received_material.get_instance_id() not in old_outputs),"Changed condition rejects the old neutral receiving destinations")
    var conditioned:Image=await capture()
    actor_check(conditioned.get_data()!=before.get_data(),"Changed condition visibly changes the actual recipient framebuffer")
    world._retire_actor(id);world.actor_revision=-1;world._sync_actors();resample()
    var reference:Image=await capture()
    actor_check(conditioned.get_data()==reference.get_data(),"Changed-at-admission framebuffer equals original direct constructor and current binder exactly")
    world.displayed_components=original_components;resample()
    var restored:Image=await capture()
    actor_check(restored.get_data()==before.get_data(),"Removing the material control restores exact original pixels")
    conditioned.save_png("res://.captures/actor-preparation/conditioned-staged.png")
    reference.save_png("res://.captures/actor-preparation/conditioned-original.png")
func finish(wall_ms:float,display_ms:float)->void:
    if not healthy() or frames.is_empty():
        printerr("ACTOR_INITIAL_FAILURE ",world.media_issue," ",world.presentation_errors)
        await super.finish(wall_ms,display_ms);return
    world.timeline.paused=true;world.set_process(false)
    if world.hud!=null:world.hud.hide()
    # Follow updates the camera after ordinary Play sampling. Settle the same
    # published state/view before either frozen-constructor comparison.
    resample()
    var canonical:PackedByteArray=var_to_bytes(world.timeline.state)
    var clock:float=world.timeline.display_ms
    var original_rows:Dictionary={}
    var original_graphs:Dictionary={}
    for id in world.visual_actors:
        original_rows[id]=world.visual_actors[id].row.duplicate(true)
        original_graphs[id]=[world.playbacks[id].clip,world.playbacks[id].sample_seconds]
    var adopted:int=world.actor_prepared_layers
    actor_check(adopted>0,"Actual initial/reveal synchronization adopts prepared native layers")
    actor_check(not seen_candidates.is_empty(),"Actual running world exposes hidden constructed future layers before publication")
    var material_adoptions:int=0
    for entry in world.actor_entries:
        if entry.has("received_material") and seen_materials.get(entry.node.get_instance_id(),-1)==entry.received_material.get_instance_id():material_adoptions+=1
    actor_check(material_adoptions>0,"Actual live Gallery uses the exact privately prepared actor output materials")
    var fixture_material_adoptions:int=0
    for entry in world.fixture_entries:
        var source_id:int=entry.node.get_instance_id()
        if not seen_fixture_materials.has(source_id):continue
        var prepared:Dictionary=seen_fixture_materials[source_id]
        var groups:Dictionary=world.native_light_atlas.source_groups.get(source_id,{})
        actor_check(entry.received_material.get_instance_id()==prepared.output and groups.values().all(func(group):return group.material.get_instance_id() in prepared.groups),
            "Actual Gallery fixture retains its privately constructed output and receiver material owners")
        fixture_material_adoptions+=1
    actor_check(fixture_material_adoptions>0,"Actual Gallery reveal adopts prepared fixture material owners")
    var actual:Image=await capture()
    var created:int=world.entries.size()
    for id in world.visual_actors.keys():world._retire_actor(id)
    world.actor_revision=-1;world._sync_actors()
    resample()
    var rebuilt:Image=await capture()
    actor_check(world.entries.size()==created,"Original constructor recreates the exact live actor membership")
    actor_check(world.actor_prepared_layers==adopted,"Reference rebuild uses original direct constructor, not staged owners")
    for id in original_rows:
        actor_check(world.visual_actors[id].row==original_rows[id],"Exact live row survives ordinary rebuild: "+id)
        actor_check([world.playbacks[id].clip,world.playbacks[id].sample_seconds]==original_graphs[id],"Current pose/clock remains exact after rebuild: "+id)
    actor_check(var_to_bytes(world.timeline.state)==canonical and world.timeline.display_ms==clock,"Native construction and comparison never change reducer state or published clock")
    var exact:bool=actual.get_data()==rebuilt.get_data()
    actor_check(exact,"Actual prepared reveal framebuffer equals original direct construction byte-for-byte")
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.captures/actor-preparation"))
    actual.save_png("res://.captures/actor-preparation/staged.png")
    rebuilt.save_png("res://.captures/actor-preparation/original.png")
    await changed_condition_control(rebuilt)
    actor_check(var_to_bytes(world.timeline.state)==canonical and world.timeline.display_ms==clock,"Changed-material control never changes canonical state or published clock")
    var report={"checks":actor_checks,"failures":actor_failures,"adopted_layers":adopted,"candidate_layers":seen_candidates.values(),
        "prepared_materials_seen":seen_materials.size(),"prepared_materials_adopted":material_adoptions,
        "fixture_materials_seen":seen_fixture_materials.size(),"fixture_materials_adopted":fixture_material_adoptions,
        "actors":original_rows.size(),"display_ms":clock,"byte_exact":exact,
        "scope":"Actual server Gallery normal-clock candidate/adoption, followed by original direct actor reconstruction at identical published state/time."}
    FileAccess.open("res://.runtime/actor-preparation-native-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("ACTOR_NATIVE ",JSON.stringify(report));failures.append_array(actor_failures)
    await super.finish(wall_ms,display_ms)
