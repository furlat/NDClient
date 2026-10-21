extends "res://tests/native_vampiric_touch_render_checks.gd"
## One actual-production cohort. Every family requires genuine independent
## originals; absent head/held-item evidence is a failed prerequisite.
const SourceFacts=preload("res://tests/source_phase_owner_inputs_checks.gd")
var directories:Dictionary={"aura":"res://tests/fixtures/schema16/scenarios/aura-of-life","deafness":"","item":""}
func seat_path(directory:String,seat:String)->String:
    var path:String=directory.path_join(seat)
    return path.path_join("journal") if DirAccess.dir_exists_absolute(path.path_join("journal")) else path
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(800,600)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    check(DisplayServer.get_name()!="headless","Owner/head/item qualification requires the real native renderer")
    if DisplayServer.get_name()=="headless":finish();return
    for argument in OS.get_cmdline_user_args():
        for name in directories:
            if argument.begins_with("--"+name+"-recording="):directories[name]=argument.trim_prefix("--"+name+"-recording=")
    DirAccess.make_dir_recursive_absolute("res://.runtime/owner-head-item-captures")
    for name in directories:
        check(not directories[name].is_empty(),name+" genuine original recording supplied")
        if directories[name].is_empty():continue
        for seat in ["amber","blue"]:await family(name,seat,seat_path(directories[name],seat))
    finish()
func source_program(handle:Dictionary,name:String)->Node:
    for node in handle.root.find_children("*","Node",true,false):
        if node.get_script()==null:continue
        var file:String=node.get_script().resource_path.get_file()
        if name=="aura" and file=="field.gd" and node.has_method("capture_observation") and node.capture_observation().has("aura_owner"):return node
        if name=="deafness" and file=="deafened_application.gd":return node
        if name=="item" and file=="current_item_flame_hold.gd":return node
    return null
## Exact signed source-over contribution; the independent scene can differ
## without changing this selected bounded source. Whole-scene drift stays in
## the saved evidence and original present/hidden images.
func contribution_difference(a:Image,hidden_a:Image,b:Image,hidden_b:Image)->int:
    var bytes:Array=[]
    for image in [a,hidden_a,b,hidden_b]:
        var copy:Image=image.duplicate();copy.convert(Image.FORMAT_RGBA8);bytes.append(copy.get_data())
    if bytes.any(func(value):return value.size()!=bytes[0].size()):return -1
    var count:int=0
    for at in bytes[0].size():
        if int(bytes[0][at])-int(bytes[1][at])!=int(bytes[2][at])-int(bytes[3][at]):count+=1
    return count

func raster_difference(a:Image,b:Image)->Dictionary:
    var left:Image=a.duplicate();var right:Image=b.duplicate()
    left.convert(Image.FORMAT_RGBA8);right.convert(Image.FORMAT_RGBA8)
    var x:PackedByteArray=left.get_data();var y:PackedByteArray=right.get_data()
    var count:int=0;var maximum:int=0;var low:=Vector2i(a.get_width(),a.get_height());var high:=Vector2i(-1,-1)
    for pixel in a.get_width()*a.get_height():
        var different:bool=false
        for channel in 4:
            var amount:int=absi(int(x[pixel*4+channel])-int(y[pixel*4+channel]))
            maximum=maxi(maximum,amount);different=different or amount>0
        if different:
            count+=1;var point:=Vector2i(pixel%a.get_width(),pixel/a.get_width())
            low=low.min(point);high=high.max(point)
    return {"pixels":count,"bounds_inclusive":[low.x,low.y,high.x,high.y] if count>0 else [],"maximum_byte_difference":maximum}

func actor_pose_snapshot(world:Node)->Dictionary:
    var result:Dictionary={}
    for id in world.visual_actors:
        var row:Dictionary=world.visual_actors[id].row;var playback:Node=world.playbacks.get(id)
        if playback==null:continue
        result[id]={"rig":row.rig,"facing":row.facing,"clip":playback.clip,"source_seconds":playback.sample_seconds}
    return result

func family(name:String,seat:String,directory:String)->void:
    var label:String=name+"/"+seat
    var index:Dictionary=Recording.read(directory)
    check(index.ok,label+" independent original compiles through production")
    if not index.ok:return
    var rows:Array=index.rows.filter(func(row):return row.get("component",{}).get("native_clip",{}).get("id")==SourceFacts.SOURCES[name])
    check(not rows.is_empty(),label+" actual source owner/selected Deafness/held-item membership creates a production component")
    if rows.is_empty():return
    var row:Dictionary=rows[0];var component:Dictionary=row.component
    check(component.native_clip.get("source_kind")=="standalone_phase",label+" actual mapped standalone source selected without an invented index clip")
    if name=="deafness":check(component.get("native_variant",{}).get("id")=="control.deafened",label+" exact original disclosed Deafness facet selects its finite source")
    if name=="item":check(component.get("dynamic_item_effect",false) and component.item_effect_member.behavior_id=="condition.spell.continual_flame",label+" exact actual item/effect membership owns the held decoration")
    var original:PackedByteArray=var_to_bytes(component)
    var phase:Resource=load(component.native_clip.source_phase);var immutable:PackedByteArray=var_to_bytes(phase.to_clip())
    var view:=SubViewport.new();view.size=Vector2i(800,600);view.own_world_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    var world=Play.new();world.external_playback=true;world.external_clock=true;world.media_warmup.budget_bytes=0
    world.catalog_cache=Play.Catalog.source_snapshot(index.cache);world.playback_end_ms=index.presentation_end_ms
    world.component_renderer.audio.set_enabled(false);view.add_child(world)
    var age:float={"aura":.65,"deafness":.5,"item":1.75}[name]
    var at:float=float(row.start_ms)+age*1000.0
    check(at<=index.presentation_end_ms,label+" original preserves a complete source witness window")
    if at>index.presentation_end_ms:await close_world(world,view,label);return
    var canonical:PackedByteArray=PackedByteArray();var first:Image;var first_hidden:Image;var first_poses:Dictionary={};var previous:WeakRef
    for pass_index in 2:
        world.install_playback(Recording.restore(index,maxf(0.0,float(row.start_ms)-1.0)))
        if not await settle(world):await close_world(world,view,label);return
        if previous!=null:check(previous.get_ref()==null,label+" reverse seek retires prior private source")
        world.install_playback(Recording.restore(index,at))
        if not await settle(world,component.id):await close_world(world,view,label);return
        if pass_index==0:canonical=var_to_bytes(world.timeline.state)
        else:check(var_to_bytes(world.timeline.state)==canonical,label+" loop restores the exact independent canonical prefix")
        for quarter in ([0,1,2,3] if pass_index==0 else [0]):
            world.request_view(quarter)
            var deadline:int=Time.get_ticks_msec()+45000
            while world.rotation_pending() and Time.get_ticks_msec()<deadline:await frame()
            check(world.quarter==quarter and world.world_quarter==quarter and not world.rotation_pending(),label+" real view publication reaches quarter "+str(quarter))
            if not await settle(world,component.id):await close_world(world,view,label);return
            var native=world.component_renderer.native_spells
            check(native.handles.has(component.id),label+" ordinary preparation owns the actual native source")
            if not native.handles.has(component.id):continue
            var handle:Dictionary=native.handles[component.id];var program:Node=source_program(handle,name)
            check(program!=null,label+" actual delivered component program receives production inputs")
            if program==null:continue
            var bound:Dictionary=native.diagnostics.get(component.id,{}).get("input_bindings",{})
            check(bound.get("unavailable",{}).is_empty() and component.native_clip.inputs.all(func(channel):return channel in bound.get("supplied",[])),label+" every exact declared channel supplied after the native fence")
            check(is_equal_approx(handle.age,age),label+" source samples the unchanged owner/application age")
            var observation:Dictionary=program.capture_observation();var focus:Vector3
            if name=="aura":
                var facts:Dictionary=observation.aura_owner
                check(facts.owner_uuid==component.condition_uuid and facts.owner_admitted and facts.visible_pieces==6 and facts.radius_cells==6,label+" real self-owner drives original six-petal6cell field")
                focus=facts.actual_anchor;world.camera.size=18
            elif name=="deafness":
                check(program.head_endpoints.size()==1,label+" complete single actual target-head endpoint")
                if program.head_endpoints.size()!=1:continue
                var endpoint:Dictionary=program.head_endpoints[0]
                check(endpoint.actor_uuid==component.target_uuid and endpoint.socket=="head" and endpoint.surface.points.size()>0 and endpoint.view_basis.is_equal_approx(world.camera.global_basis),label+" actual measured head/support/current published basis are supplied")
                check(observation.phase=="finite_application" and not observation.persistent_marker_owned and observation.overhead_anchor.measured_head_points>0,label+" finite donor application remains separate from the persistent Deafened marker")
                focus=endpoint.point;world.camera.size=3
            else:
                check(program.item_identity.item_uuid==component.item_owner_uuid and program.item_identity.effect_uuid==component.item_effect_uuid and program.current_holder_uuid==component.actor_uuid,label+" exact item/effect identities and actual current holder reach bounded source")
                check(program.packet.normal_support_points>0 and program.packet.actual_item_optical_depth and program.packet.facts.condition_present and program.packet.actor_id==handle.endpoints.holder_uuid,label+" current exact item support and public membership admit output")
                check(observation.seekable and observation.clock_mode=="bounded_source_hold_and_unwrapped_absolute_material_phase" and program.source.absolute_source_tick==roundi(age*144.0),label+" proven bounded hold preserves unwrapped owner/material age")
                focus=program.packet.point;world.camera.size=3
            world.camera_focus=focus;world.initial_focus=true;world.position_camera();world.grid_visible=false
            if not await settle(world,component.id):await close_world(world,view,label);return
            native=world.component_renderer.native_spells
            check(native.handles.has(component.id),label+" final camera publication retains the current source")
            if not native.handles.has(component.id):continue
            handle=native.handles[component.id];program=source_program(handle,name)
            check(program!=null,label+" final camera has the actual current source program")
            if program==null:continue
            bound=native.diagnostics.get(component.id,{}).get("input_bindings",{})
            check(bound.get("unavailable",{}).is_empty() and component.native_clip.inputs.all(func(channel):return channel in bound.get("supplied",[])),label+" final camera optical inputs are fully published")
            observation=program.capture_observation()
            world.set_process(false)
            var present:Image=view.get_texture().get_image();Effects.hide(handle);await frame();await frame()
            var absent:Image=view.get_texture().get_image();var pixels:int=changed(present,absent)
            check(pixels>0,label+" actual source contributes native framebuffer pixels in quarter "+str(quarter))
            var stem:String="res://.runtime/owner-head-item-captures/"+name+"-"+seat+"-"+str(pass_index)+"-q"+str(quarter)
            check(present.save_png(stem+"-present.png")==OK and absent.save_png(stem+"-absent.png")==OK,label+" exact positive/hidden frame pair saves")
            var restoration:Dictionary={}
            if pass_index==0 and quarter==0:
                first=present;first_hidden=absent;first_poses=actor_pose_snapshot(world)
            if pass_index==1 and quarter==0 and name in ["aura","item"]:
                var source_difference:int=contribution_difference(first,first_hidden,present,absent)
                var background:Dictionary=raster_difference(first_hidden,absent)
                restoration={"source_differing_channel_bytes":source_difference,"full_frame":raster_difference(first,present),
                    "background":background,"world_drift_status":"open_background_raster_drift" if background.pixels>0 else "no_background_drift_observed",
                    "first_actor_poses":first_poses,"restored_actor_poses":actor_pose_snapshot(world),
                    "scope":"Exact isolated selected-source contribution; original whole-scene drift remains explicit and is not art approval."}
                check(source_difference==0,label+" direct backward loop restores the identical signed bounded-source raster contribution")
            check(var_to_bytes(component)==original and var_to_bytes(phase.to_clip())==immutable and var_to_bytes(world.timeline.state)==canonical,label+" source/view/seek sampling leaves original facts and immutable art untouched")
            evidence.append({"family":name,"seat":seat,"pass":pass_index,"quarter":quarter,"at_ms":at,"source_age":handle.age,"source_phase":phase.resource_path,"source_kind":"standalone_phase","changed_pixels":pixels,"observation":observation,"capture":stem+"-present.png","restoration":restoration})
            previous=weakref(handle.root);handle.root.show();world.set_process(true)
    if name=="deafness":
        world.install_playback(Recording.restore(index,minf(index.presentation_end_ms,float(row.end_ms)+1.0)))
        if await settle(world):check(world.component_renderer.native_spells.witnesses.all(func(witness):return witness.id!=component.id),label+" finite application retires after full1.2s source while owner marker remains independently selected")
    await close_world(world,view,label)
    check(previous==null or previous.get_ref()==null,label+" teardown releases private occurrence")
func close_world(world:Node,view:SubViewport,label:String)->void:
    var native=world.component_renderer.native_spells;native.close(world)
    check(native.handles.is_empty() and native.groups.is_empty() and native.prepared_layers.is_empty(),label+" actual native source/layer teardown completes")
    check(world.presentation_errors.is_empty() and world.media_issue.is_empty(),label+" no presentation or resource errors")
    view.queue_free();await frame();await frame()
func finish()->void:
    var report:Dictionary={"checks":checks,"failures":failures,"evidence":evidence,"factory_version":JSON.parse_string(FileAccess.get_file_as_string(Effects.INDEX)).version,
        "scope":"Actual independent original main-owner, disclosed Deafness and genuinely held item membership through ordinary Play. Exact public/source identities, source readiness, measured head/item registration, source ages, positive pixels in four published views, reverse seek/loop and teardown. Missing original prerequisites fail. Logical synthetic transfer/removal, inventory equipment transfer, performance and human art approval are not inferred."}
    FileAccess.open("res://.runtime/native-owner-head-item-render-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_OWNER_HEAD_ITEM ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
