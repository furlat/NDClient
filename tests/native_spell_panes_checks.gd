extends SceneTree
## Two real audience journals own independent production native replay worlds,
## even when their disclosed pictures do not require Studio's comparison UI.
const Recording=preload("res://studio/recording.gd")
const Play=preload("res://play.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
const Panes=preload("res://studio/replay_panes.gd")
const REPORT="res://.runtime/native-spell-panes-checks.json"
const CAPTURES="res://.captures/native-spell-panes"
var checks:int=0
var failures:Array=[]
var evidence:Dictionary={}
var finished:bool=false

func _initialize()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000)
    create_timer(240).timeout.connect(func():check(false,"Independent native panes finish within their finite budget");finish())
    run.call_deferred()

func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("NATIVE_PANES_FAIL ",label)

func frame()->void:
    await process_frame
    await RenderingServer.frame_post_draw

func flights(index:Dictionary)->Array:
    return index.rows.filter(func(row):return row.kind=="native_effect" and row.component.get("native_spell",false) and row.component.spell_id=="spell.magic_missile" and row.component.native_cue.role=="flight")

func make_pane(index:Dictionary,row:Dictionary,at:float)->Dictionary:
    var view=Panes.viewport();view.size=Vector2i(800,600);view.audio_listener_enable_3d=false;root.add_child(view)
    var world=Play.new();world.external_playback=true;world.external_clock=true
    world.catalog_cache=Play.Catalog.source_snapshot(index.cache);world.media_warmup.budget_bytes=0
    world.component_renderer.audio.set_enabled(false)
    view.add_child(world);world.install_playback(Recording.restore(index,at))
    var c:Dictionary=row.component
    var a=Vector3(c.from_position[0],float(c.get("from_elevation_feet",0))/5.0*Play.Placement.HEIGHT_UNIT,c.from_position[1])
    var b=Vector3(c.to_position[0],float(c.get("to_elevation_feet",0))/5.0*Play.Placement.HEIGHT_UNIT,c.to_position[1])
    world.camera_focus=(a+b)*.5+Vector3.UP*.5;world.initial_focus=true
    world.camera.size=maxf(6.0,a.distance_to(b)*1.45+2.0);world.position_camera()
    world.wall_mode="hidden";world.update_wall_visibility()
    return {"world":world,"viewport":view,"index":index,"row":row,"at":at,"frozen":[]}

func settle(pane:Dictionary,label:String)->bool:
    var world:Node=pane.world
    var deadline:int=Time.get_ticks_msec()+90000
    while Time.get_ticks_msec()<deadline and world.presentation_errors.is_empty() and world.media_issue.is_empty():
        if world.playback_prepared():
            await frame()
            if world.playback_prepared():return true
        await frame()
    check(false,label+": independent production host prepares")
    print("NATIVE_PANES_PREPARATION ",JSON.stringify({"label":label,"errors":world.presentation_errors,"media":world.media_issue,"native":world.component_renderer.native_spells.diagnostics}))
    return false

func handle(pane:Dictionary)->Dictionary:
    return pane.world.component_renderer.native_spells.handles.get(pane.row.component.id,{})

func layer(pane:Dictionary)->Dictionary:
    return pane.world.component_renderer.native_spells.groups[handle(pane).group_key]

func material_map(source:Dictionary)->Dictionary:
    var result:Dictionary={}
    for piece in source.geometry:
        var node:GeometryInstance3D=piece.node
        if not node is MeshInstance3D or node.mesh==null:continue
        for surface in node.mesh.get_surface_count():
            var material:Material=node.get_active_material(surface)
            if material!=null:result[piece.path+":"+str(surface)]=material
    return result

func assert_occurrence(pane:Dictionary,label:String)->void:
    var source=handle(pane)
    check(not source.is_empty(),label+": real recorded flight has a native instance")
    if source.is_empty():return
    var expected:float=(pane.at-pane.row.start_ms)/1000.0
    check(is_equal_approx(source.sample_time,expected),label+": native instance reaches its exact recorded component age")
    check(is_equal_approx(pane.world.timeline.display_ms,pane.at),label+": independent Timeline retains the shared event phase")
    check(source.rendered_once and source.root.is_visible_in_tree(),label+": native flight submitted a real frame")
    check(pane.world.session==null,label+": offline playback creates no live network session")

func lit_pixels(image:Image)->int:
    var count:int=0
    for y in image.get_height():
        for x in image.get_width():
            var pixel:Color=image.get_pixel(x,y)
            if maxf(pixel.r,maxf(pixel.g,pixel.b))>1.0/255.0:count+=1
    return count

func seek(pane:Dictionary,at:float,label:String)->bool:
    pane.world.set_process(true)
    check(pane.world.try_reset_hidden_playback(Recording.restore(pane.index,at)),label+": production seek accepts an independently restored journal")
    return await settle(pane,label)

func exercise_owner(changed:Dictionary,held:Dictionary,label:String)->void:
    var held_source=handle(held);var changed_source=handle(changed)
    var held_root:Node3D=held_source.root;var old_root:Node3D=changed_source.root
    var position:Vector3=held_root.global_position
    var age:float=held_source.sample_time
    var held_pass=layer(held);var changed_pass=layer(changed)
    var old_ramp:Variant=changed_pass.material.get_shader_parameter("ramp_count")
    var held_ramp:Variant=held_pass.material.get_shader_parameter("ramp_count")
    # An inspector edit is occurrence-local. Hold the sampled clocks while
    # deliberately mutating one real source and finishing material.
    changed.world.set_process(false);held.world.set_process(false)
    changed_pass.material.set_shader_parameter("ramp_count",0 if int(old_ramp)>0 else 1)
    old_root.position+=Vector3(1,0,0)
    check(held_root.global_position==position,label+": editing one native transform leaves the other instance unchanged")
    check(held_pass.material.get_shader_parameter("ramp_count")==held_ramp,label+": editing one finishing material leaves the other profile unchanged")
    changed_pass.material.set_shader_parameter("ramp_count",old_ramp)
    for i in 3:await frame()
    var before:Image=held_pass.viewport.get_texture().get_image()
    if not await seek(changed,0,label+" reverse"):return
    check(not is_instance_valid(old_root),label+": reverse seek retires only its prior native instance")
    check(changed.world.component_renderer.native_spells.groups.is_empty(),label+": pre-spell seek has no retained old native pass")
    check(is_instance_valid(held_root) and handle(held).root==held_root,label+": peer instance survives the other pane's retirement")
    check(held_root.global_position==position and is_equal_approx(handle(held).sample_time,age),label+": peer geometry and source clock stay fixed during retirement")
    var after:Image=held_pass.viewport.get_texture().get_image()
    check(before.get_data()==after.get_data(),label+": retiring the other pane leaves the held native pass pixel-exact")
    if not await seek(changed,changed.at,label+" forward"):return
    assert_occurrence(changed,label+" reseek")
    check(handle(changed).root!=held_root,label+": reseek creates a private occurrence again")
    check(before.get_data()==held_pass.viewport.get_texture().get_image().get_data(),label+": peer native pixels survive the other pane's reconstruction")
    held.world.set_process(true)
    check(await settle(held,label+" peer resume"),label+": held peer remains ready when production sampling resumes")

func run()->void:
    var bundle:Dictionary=Recording.read_case(Fixtures.public_case("magic-missile"))
    check(bundle.ok,"Current exact Magic Missile case admits its independent original seats")
    if not bundle.ok:finish();return
    var amber:Dictionary=bundle.views.amber
    var blue:Dictionary=bundle.views.blue
    check(amber.ok and blue.ok,"Both real faction journals independently reduce and compile")
    if not amber.ok or not blue.ok:finish();return
    check(amber.identity.game_id==blue.identity.game_id and amber.identity.game_epoch==blue.identity.game_epoch,"Both admitted journals describe the same game epoch")
    var amber_flights=flights(amber);var blue_flights=flights(blue)
    check(amber_flights.size()==3 and blue_flights.size()==3,"Both actual faction streams disclose the three real Magic Missile deliveries")
    if amber_flights.is_empty():finish();return
    var row:Dictionary=amber_flights[0]
    var matching=blue_flights.filter(func(other):return other.correspondence_event_key==row.correspondence_event_key)
    check(matching.size()==1,"The other journal has one flight with the same actual shared cause, preserving its local occurrence")
    if matching.size()!=1:finish();return
    var at:float=row.start_ms+(float(row.component.native_cue.launch)+float(row.component.native_cue.contact))*500.0
    var blue_at:float=Recording.switch_time(amber,blue,at,row)
    check(is_equal_approx(at-row.start_ms,blue_at-matching[0].start_ms),"Shared event navigation maps the same recorded flight phase in both views")
    evidence={"amber_occurrence":row.component.source_event_uuid,"blue_occurrence":matching[0].component.source_event_uuid,"shared_event":row.correspondence_event_key,"amber_ms":at,"blue_ms":blue_at,"renderer":RenderingServer.get_current_rendering_method()}
    if DisplayServer.get_name()=="headless":finish();return
    var original_vsync=DisplayServer.window_get_vsync_mode();DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    var a=make_pane(amber,row,at);var b=make_pane(blue,matching[0],blue_at)
    if await settle(a,"Amber") and await settle(b,"Blue"):
        assert_occurrence(a,"Amber");assert_occurrence(b,"Blue")
        check(a.world.get_world_3d()!=b.world.get_world_3d(),"Replay panes have separate World3D resources")
        check(a.world.timeline!=b.world.timeline and a.world.component_renderer!=b.world.component_renderer,"Independent reducers and presenters are not shared")
        var ah=handle(a);var bh=handle(b)
        if not ah.is_empty() and not bh.is_empty():
            check(ah.root!=bh.root,"Matching native occurrences have distinct scene instances")
            check(ah.root.global_position.is_equal_approx(bh.root.global_position),"Matching shared event phase reaches the same recorded world position")
            check(layer(a).material!=layer(b).material,"Matching spell profiles own separate mutable finishing materials")
            var am=material_map(ah);var bm=material_map(bh)
            check(not am.is_empty() and am.keys()==bm.keys(),"Matching native source meshes expose the same real material surfaces")
            for key in am:check(bm.has(key) and am[key]!=bm[key],"Native source material is private: "+key)
            if not am.is_empty() and bm.has(am.keys()[0]):
                var key:String=am.keys()[0]
                var original:int=am[key].render_priority;var peer_priority:int=bm[key].render_priority
                am[key].render_priority=original+1 if original<127 else original-1
                check(bm[key].render_priority==peer_priority,"Editing one actual native material does not alter its peer source")
                am[key].render_priority=original
            for i in mini(ah.emitters.size(),bh.emitters.size()):
                check(ah.emitters[i]!=bh.emitters[i],"Matching particle emitters are private instances")
                check(ah.emitters[i].seed==bh.emitters[i].seed,"The same event has deterministic particle identity without sharing emitters")
            DirAccess.make_dir_recursive_absolute(CAPTURES)
            for pane in [a,b]:
                var name:String="amber" if pane.world==a.world else "blue"
                var source_image:Image=layer(pane).viewport.get_texture().get_image()
                var count=lit_pixels(source_image);evidence[name+"_native_pixels"]=count
                check(count>0,name+": native pass contains actual spell pixels")
                source_image.save_png(CAPTURES+"/"+name+"-source.png")
                pane.viewport.get_texture().get_image().save_png(CAPTURES+"/"+name+"-world.png")
            await exercise_owner(a,b,"Amber");await exercise_owner(b,a,"Blue")
        check(a.world.presentation_errors.is_empty() and b.world.presentation_errors.is_empty(),"Both real replay hosts remain free of presentation errors")
    Panes.discard(a);Panes.discard(b);await frame();await frame()
    DisplayServer.window_set_vsync_mode(original_vsync)
    finish()

func finish()->void:
    if finished:return
    finished=true
    FileAccess.open(REPORT,FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failures.size(),"failures":failures,"evidence":evidence,"scope":"Real Amber and Blue journals independently reduced into two production Play worlds. Native ownership, source materials, exact shared flight phase, mutation isolation and bidirectional seek/retirement. Headless execution only qualifies journal admission and shared event navigation."},"  "))
    print("NATIVE_SPELL_PANES ",JSON.stringify({"checks":checks,"failed":failures.size(),"failures":failures,"report":REPORT}))
    quit(0 if failures.is_empty() else 1)
