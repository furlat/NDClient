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
    # Sprites light themselves: each prepared source material is the material
    # its node will display. Record them to prove adoption keeps them.
    for entry in candidate.entries:
        if entry.material is ShaderMaterial and entry.material.shader==world.FIXTURE_FLAME_SHADER:
            seen_fixture_materials[entry.node.get_instance_id()]=entry.material.get_instance_id()
    for actor in candidate.native_actors.values():
        for entry in actor.get("new_entries",actor.entries):
            seen_materials[entry.node.get_instance_id()]=entry.material.get_instance_id()
            actor_check(entry.node.material_override==entry.material,"Future actor layer displays its own lit source material")
        # Retained layers of a reused actor are the displayed ones; only new
        # private layers belong to the unpublished candidate.
        for entry in actor.get("new_entries",[]):
            actor_check(not entry.node.is_visible_in_tree(),"Unpublished future actor layer remains hidden")
            actor_check(entry not in world.entries and entry not in world.actor_entries,"Future layer is absent from both live directories")
            count+=1
    if count>0:seen_candidates[candidate.get_instance_id()]=count
func capture()->Image:
    await process_frame;await RenderingServer.frame_post_draw
    await process_frame;await RenderingServer.frame_post_draw
    return root.get_texture().get_image()
# The original direct constructor, as other ownership suites call it: Play
# refuses unprepared actor structure within a prepared epoch, so the reference
# rebuild runs outside that epoch and restores it.
func direct_rebuild()->void:
    var epoch:int=world.world_prepare_epoch
    world.world_prepare_epoch=-1;world.actor_revision=-1;world._sync_actors();world.world_prepare_epoch=epoch
func resample()->void:
    world._sample_actors();world._sample_fixtures();world._sync_native_lighting();world._sort_draws()
    world.component_renderer.native_spells.sync(world)
func control_uniform(value:Variant)->Variant:
    # Resource identity is diagnostic evidence, not a claim that two textures
    # with different owners necessarily paint different pixels. No readback.
    if value is Resource:
        return {"class":value.get_class(),"path":value.resource_path,"instance":value.get_instance_id()}
    return var_to_str(value)
func control_snapshot()->Dictionary:
    var native=world.component_renderer.native_spells
    var result:Dictionary={"display_ms":world.timeline.display_ms,"quarter":world.quarter,
        "camera":var_to_str(world.camera.global_transform),"camera_size":world.camera.size,
        "components":world.displayed_components.map(func(component):return [component.id,component.kind,component.get("age_ms")]),
        "draw_order":world.draw_order.map(func(entry):return entry.id),"entries":{},"ownership":{},
        "native":{"ready":native.ready,"groups":native.groups.keys(),"handles":{},
            "support_ready":native._support.ready if native._support!=null else null,
            "support_issues":native._support.issues.duplicate() if native._support!=null else []}}
    for entry in world.actor_entries+world.fixture_entries:
        var uniforms:Dictionary={}
        for declared in entry.material.shader.get_shader_uniform_list():
            uniforms[str(declared.name)]=control_uniform(entry.material.get_shader_parameter(declared.name))
        result.entries[str(entry.id)]={"visible":entry.node.visible,"inherited_visible":entry.node.is_visible_in_tree(),
            "transform":var_to_str(entry.node.global_transform),"sort_offset":entry.node.sorting_offset,
            "render_priority":entry.material.render_priority,"role":entry.role,"layer":entry.layer,
            "order_key":entry.get("order_key",[]).duplicate(),"draw_rank":entry.get("draw_rank"),"uniforms":uniforms}
        result.ownership[str(entry.id)]={"node":entry.node.get_instance_id(),"material":entry.material.get_instance_id(),
            "source_version":entry.get("source_version"),"bound_condition_parameters":var_to_str(entry.get("bound_condition_parameters",{}))}
    for id in native.handles:
        var handle:Dictionary=native.handles[id]
        result.native.handles[id]={"clip":handle.clip.get("id"),"requested_time":handle.get("requested_time"),
            "sample_time":handle.get("sample_time"),"drawn_time":handle.get("drawn_time"),"rendered_once":handle.get("rendered_once"),
            "capture_status":native.Inputs.capture_status(handle)}
    return result
func control_difference(before:Dictionary,after:Dictionary)->Dictionary:
    var changes:Dictionary={"world":{},"entries":{}}
    for key in ["display_ms","quarter","camera","camera_size","components","draw_order"]:
        if before[key]!=after[key]:changes.world[key]={"before":before[key],"after":after[key]}
    var identities:Dictionary={}
    for id in before.entries:identities[id]=true
    for id in after.entries:identities[id]=true
    for id in identities:
        if not before.entries.has(id) or not after.entries.has(id):
            changes.entries[id]={"before_present":before.entries.has(id),"after_present":after.entries.has(id)}
            continue
        var prior:Dictionary=before.entries[id];var current:Dictionary=after.entries[id];var changed:Dictionary={}
        for key in prior:
            if key=="uniforms":continue
            if prior[key]!=current.get(key):changed[key]={"before":prior[key],"after":current.get(key)}
        var uniforms:Dictionary={}
        for name in prior.uniforms:uniforms[name]=true
        for name in current.uniforms:uniforms[name]=true
        for name in uniforms:
            if prior.uniforms.get(name)!=current.uniforms.get(name):
                if not changed.has("uniforms"):changed.uniforms={}
                changed.uniforms[name]={"before":prior.uniforms.get(name),"after":current.uniforms.get(name)}
        if not changed.is_empty():changes.entries[id]=changed
    return changes
func shadow_control(label:String)->Dictionary:
    # Inspect the already completed fixed capture. These are the actual
    # retained helper nodes and source operands, with no sample/clock change.
    var owner=world.generated_shadows
    var state:Dictionary=owner.actors.get(caster,{})
    if state.is_empty():return {"present":false}
    var target:SubViewport=state.viewport
    var light:OmniLight3D=state.light
    var view:Camera3D=state.camera
    var result:Dictionary={"present":true,"label":label,"layout":var_to_str(state.layout),
        "geometry":var_to_str(state.geometry),"geometry_basis":var_to_str(state.geometry_basis),
        "footprint":var_to_str(state.footprint),"dominant":state.dominant,"source_id":state.get("source_id"),
        "root_transform":var_to_str(state.root.global_transform),
        "viewport":{"size":var_to_str(target.size),"update_mode":target.render_target_update_mode,
            "clear_mode":target.render_target_clear_mode,"msaa_3d":target.msaa_3d,"use_taa":target.use_taa,
            "shadow_atlas_size":target.positional_shadow_atlas_size,"quadrants":[]},
        "camera":{"transform":var_to_str(view.global_transform),"projection":view.projection,
            "keep_aspect":view.keep_aspect,"size":view.size,"near":view.near,"far":view.far,"cull_mask":view.cull_mask},
        "light":{"transform":var_to_str(light.global_transform),"visible":light.is_visible_in_tree(),
            "color":var_to_str(light.light_color),"energy":light.light_energy,"range":light.omni_range,
            "attenuation":light.omni_attenuation,"shadow_enabled":light.shadow_enabled,
            "shadow_bias":light.shadow_bias,"shadow_normal_bias":light.shadow_normal_bias,
            "shadow_blur":light.shadow_blur,"shadow_mode":light.omni_shadow_mode,"cull_mask":light.light_cull_mask},
        "ground":{"transform":var_to_str(state.ground.global_transform),"mesh_size":var_to_str(state.ground.mesh.size),
            "helper_position":var_to_str(state.ground.material_override.get_shader_parameter("helper_position")),
            "helper_range":state.ground.material_override.get_shader_parameter("helper_range")},
        "casters":{},"snapshots":[],"ownership":{"viewport":target.get_instance_id(),
            "world":target.world_3d.get_instance_id(),"light":light.get_instance_id()},
        "sync":owner.diagnostics(),
        "exact_operands":{"layout":var_to_bytes(state.layout).hex_encode(),"geometry":var_to_bytes(state.geometry).hex_encode(),
            "basis":var_to_bytes(state.geometry_basis).hex_encode(),"root":var_to_bytes(state.root.global_transform).hex_encode(),
            "camera":var_to_bytes([view.global_transform,view.projection,view.keep_aspect,view.size,view.near,view.far]).hex_encode(),
            "light":var_to_bytes([light.global_transform,light.light_color,light.light_energy,light.omni_range,light.omni_attenuation,
                light.shadow_bias,light.shadow_normal_bias,light.shadow_blur]).hex_encode(),
            "ground":var_to_bytes([state.ground.global_transform,state.ground.material_override.get_shader_parameter("helper_position"),
                state.ground.material_override.get_shader_parameter("helper_range")]).hex_encode()}}
    for quadrant in 4:result.viewport.quadrants.append(target.get_positional_shadow_atlas_quadrant_subdiv(quadrant))
    var environment:Environment=view.environment
    if environment!=null:result.camera.environment={"background_mode":environment.background_mode,
        "background_color":var_to_str(environment.background_color),"ambient_light_source":environment.ambient_light_source,
        "ambient_light_energy":environment.ambient_light_energy}
    for id in state.casters:
        var node:MeshInstance3D=state.casters[id]
        var uniforms:Dictionary={};var exact_uniforms:Dictionary={}
        for declared in node.material_override.shader.get_shader_uniform_list():
            var value:Variant=node.material_override.get_shader_parameter(declared.name)
            uniforms[str(declared.name)]=control_uniform(value)
            if not value is Resource:exact_uniforms[str(declared.name)]=var_to_bytes(value).hex_encode()
        var mesh:QuadMesh=node.mesh
        result.casters[str(id)]={"transform":var_to_str(node.global_transform),"visible":node.visible,
            "ownership":{"node":node.get_instance_id(),"material":node.material_override.get_instance_id(),
                "mesh":mesh.get_instance_id(),"render_instance":str(node.get_instance()),"tree_index":node.get_index()},
            "exact_transform":var_to_bytes([node.transform,node.global_transform,node.custom_aabb,node.layers,node.extra_cull_margin]).hex_encode(),
            "mesh_parameters":var_to_bytes([mesh.size,mesh.subdivide_width,mesh.subdivide_depth,mesh.flip_faces]).hex_encode(),
            "exact_uniforms":exact_uniforms,
            "inherited_visible":node.is_visible_in_tree(),"cast_shadow":node.cast_shadow,
            "mesh_bounds":var_to_str(node.mesh.get_aabb()) if node.mesh!=null else "no_mesh",
            "custom_bounds":var_to_str(node.custom_aabb),"uniforms":uniforms}
    for snapshot in state.snapshots:
        var row:Dictionary={}
        for key in ["id","pivot","position","scale_x","basis","model","component_cell_size","ground_pixels","geometry"]:
            if snapshot.has(key):row[key]=var_to_str(snapshot[key])
        for key in owner.CASTER_PARAMETERS:row[key]=control_uniform(snapshot.get(key))
        result.snapshots.append(row)
    var image:Image=target.get_texture().get_image()
    image.save_png("res://.captures/actor-preparation/shadow-"+label+".png")
    result.image={"size":var_to_str(image.get_size()),"format":image.get_format()}
    return result
func changed_condition_control(before:Image)->void:
    var baseline_control:Dictionary=control_snapshot()
    var baseline_shadow:Dictionary=shadow_control("baseline")
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
    var layers:Array=world.Characters.layers(row,rig,world.catalog_cache)
    var clip:String=world.playbacks[id].clip
    # The worker's selected source bindings, as WorldPreparation derives them.
    var source_bindings:Dictionary={}
    for layer in layers:
        if layer.paths.has(clip):source_bindings[layer.slot]=world.ActorConstruction.prepare_binding(rig,layer,layer.paths[clip],world.catalog_cache,
            world.source_depth,world.source_normals,world.character_light_profile,128.0/world.rig_config.TILE_W*row.scale,row.get("scale_x",1.0))
    candidate.result={"worker_ms":0.0,"worker_phases":{},"actors":{id:{"row":row,"rig":rig,
        "layers":layers,"entries":[],"new_entries":[],"playback":null,"reuse_actor":false,"retained_slots":{},
        "source_sample":{"clip":clip,"source_seconds":world.playbacks[id].sample_seconds},"source_bindings":source_bindings,
        "layer_clips":{},"source_ready":{},"source_cursor":0}}}
    # Every displayed actor keeps its published row; only the control actor is new.
    var members:Dictionary={}
    for other in world.visual_actors:members[other]=world.visual_actors[other].row.duplicate(true)
    members[id]=row
    candidate.result.actor_members=members
    candidate.actor_ids=[id]
    var waited:int=0
    while candidate.actor_cursor<candidate.actor_ids.size() and candidate.media_issue.is_empty() and waited<600:
        if not candidate._prepare_actor():await process_frame;waited+=1
    actor_check(candidate.media_issue.is_empty() and candidate.native_actors.get(id,{}).get("complete",false),"Changed-condition control prepares its private actor: "+candidate.media_issue)
    if not candidate.native_actors.get(id,{}).get("complete",false):return
    var prepared:Dictionary=candidate.native_actors[id]
    actor_check(prepared.entries.all(func(entry):return not entry.node.is_visible_in_tree() and entry.material.get_shader_parameter("condition_alpha")==1.0),"New private layers are neutral and hidden before changed-condition admission")
    var nodes:Array=prepared.entries.map(func(entry):return entry.node)
    var neutral_materials:Array=prepared.entries.map(func(entry):return entry.material.get_instance_id())
    world._retire_actor(id);candidate.entries=[];world.prepared_actor_owner=candidate;world.actor_revision=-1
    world._sync_actors();resample()
    actor_check(world.visual_actors[id].entries.map(func(entry):return entry.node)==nodes,"Changed condition keeps exact prepared geometry ownership")
    actor_check(world.visual_actors[id].entries.all(func(entry):return entry.material.get_shader_parameter("condition_alpha")==changed.alpha),"Actual live sampler replaces neutral binding with current condition at admission")
    actor_check(world.visual_actors[id].entries.map(func(entry):return entry.material.get_instance_id())==neutral_materials
        and world.visual_actors[id].entries.all(func(entry):return entry.node.material_override==entry.material),"Changed condition rebinds the prepared lit materials in place")
    var conditioned:Image=await capture()
    var conditioned_control:Dictionary=control_snapshot()
    actor_check(conditioned.get_data()!=before.get_data(),"Changed condition visibly changes the actual recipient framebuffer")
    world._retire_actor(id);direct_rebuild();resample()
    var reference:Image=await capture()
    var reference_control:Dictionary=control_snapshot()
    actor_check(conditioned.get_data()==reference.get_data(),"Changed-at-admission framebuffer equals original direct constructor and current binder exactly")
    world.displayed_components=original_components;resample()
    var restored:Image=await capture()
    actor_check(restored.get_data()==before.get_data(),"Removing the material control restores exact original pixels")
    var restored_control:Dictionary=control_snapshot()
    var restored_shadow:Dictionary=shadow_control("restored")
    restored.save_png("res://.captures/actor-preparation/condition-restored.png")
    before.save_png("res://.captures/actor-preparation/condition-baseline.png")
    var control_report:Dictionary={"scope":"Four existing fixed captures only; exact original assertion/clock/two-frame capture retained. Resource IDs show ownership only, not texture pixel inequality.",
        "restored_byte_exact":restored.get_data()==before.get_data(),"conditioned_byte_exact":conditioned.get_data()==reference.get_data(),
        "restored_difference":control_difference(baseline_control,restored_control),
        "conditioned_difference":control_difference(conditioned_control,reference_control),
        "shadow_helpers":{"baseline":baseline_shadow,"restored":restored_shadow},
        "snapshots":{"baseline":baseline_control,"conditioned_prepared":conditioned_control,"conditioned_direct":reference_control,"restored":restored_control}}
    FileAccess.open("res://.runtime/actor-preparation-material-control.json",FileAccess.WRITE).store_string(JSON.stringify(control_report,"  "))
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
        if seen_materials.get(entry.node.get_instance_id(),-1)==entry.material.get_instance_id() and entry.node.material_override==entry.material:material_adoptions+=1
    actor_check(material_adoptions>0,"Actual live Gallery displays the exact privately prepared actor materials")
    var fixture_material_adoptions:int=0
    for entry in world.fixture_entries:
        var source_id:int=entry.node.get_instance_id()
        if not seen_fixture_materials.has(source_id):continue
        actor_check(entry.material.get_instance_id()==seen_fixture_materials[source_id] and entry.node.material_override==entry.material,
            "Actual Gallery fixture retains its privately constructed lit material")
        fixture_material_adoptions+=1
    actor_check(fixture_material_adoptions>0,"Actual Gallery reveal adopts prepared fixture materials")
    var actual:Image=await capture()
    var created:int=world.entries.size()
    for id in world.visual_actors.keys():world._retire_actor(id)
    direct_rebuild()
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
