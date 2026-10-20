extends SceneTree
## GPU gate: both original seats, actual source socket/contact, pixels and seek.
const Recording=preload("res://studio/recording.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
const Play=preload("res://play.gd")
const Effects=preload("res://presentation/effect_package.gd")
const Playback=preload("res://presentation/native_spell_playback.gd")
const Propagation=preload("res://presentation/propagation_inputs.gd")
var checks:int=0
var failures:Array=[]
var evidence:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("NATIVE_PROPAGATION_FAIL "+label)
func frame()->void:
    await process_frame
    await RenderingServer.frame_post_draw
func settle(world:Node,component_id:String="")->bool:
    var deadline:int=Time.get_ticks_msec()+45000
    while Time.get_ticks_msec()<deadline and not world.publication_failed and world.presentation_errors.is_empty() and world.media_issue.is_empty():
        var bindings:Dictionary=world.component_renderer.native_spells.diagnostics.get(component_id,{}).get("input_bindings",{})
        var inputs_ready:bool=component_id.is_empty() or (not bindings.is_empty() and bindings.unavailable.is_empty())
        if world.playback_prepared() and inputs_ready:
            await frame()
            if world.playback_prepared():return true
        await frame()
    check(false,"Native preparation: "+str({"errors":world.presentation_errors,"media":world.media_issue,"native":world.component_renderer.native_spells.diagnostics}))
    return false
func changed(a:Image,b:Image)->int:
    a=a.duplicate();b=b.duplicate();a.convert(Image.FORMAT_RGBA8);b.convert(Image.FORMAT_RGBA8)
    var left:PackedByteArray=a.get_data();var right:PackedByteArray=b.get_data();var count:int=0
    for pixel in a.get_width()*a.get_height():
        var at:int=pixel*4
        if absi(int(left[at])-int(right[at]))+absi(int(left[at+1])-int(right[at+1]))+absi(int(left[at+2])-int(right[at+2]))>3:count+=1
    return count
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(800,600)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    DirAccess.make_dir_recursive_absolute("res://.runtime/propagation-captures")
    for example in {"chain-lightning":1,"chain-lightning-three":3}:
        for seat in ["amber","blue"]:await read_seat(example,seat,1 if example=="chain-lightning" else 3)
    finish()
func read_seat(example:String,seat:String,expected_links:int)->void:
    var label:String=example+"/"+seat
    var index:Dictionary=Recording.read(Fixtures.journal(example,seat))
    check(index.ok,label+" actual journal compiles")
    if not index.ok:return
    var rows:Array=index.rows.filter(func(row):return row.get("component",{}).has("native_propagation"))
    check(rows.size()==expected_links,label+" every actual native application owns one link")
    if rows.size()!=expected_links:return
    rows.sort_custom(func(a,b):return float(a.start_ms)+float(a.component.native_cue.contact)*1000.0<float(b.start_ms)+float(b.component.native_cue.contact)*1000.0)
    var view:=SubViewport.new();view.size=Vector2i(800,600);view.own_world_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    root.add_child(view)
    var world=Play.new();world.external_playback=true;world.external_clock=true;world.media_warmup.budget_bytes=0
    world.catalog_cache=Play.Catalog.source_snapshot(index.cache);world.playback_end_ms=index.presentation_end_ms
    world.component_renderer.audio.set_enabled(false);view.add_child(world)
    for row in rows:
        var component:Dictionary=row.component
        check(component.status=="available",label+" factual inputs are ready before native admission")
        var source_component:PackedByteArray=var_to_bytes(component.native_cue)
        var contact:float=float(row.start_ms)+float(component.native_cue.contact)*1000.0
        # The exact original stream is sought on either side of contact. This does
        # not insert a pause or manufacture a second server event/clock.
        for offset in [-2.0,10.0]:
            world.install_playback(Recording.restore(index,contact+offset))
            if not await settle(world,component.id):view.queue_free();await frame();return
            var native=world.component_renderer.native_spells
            check(native.handles.has(component.id),label+" actual source prepared near contact "+str(offset))
            if not native.handles.has(component.id):continue
            var handle:Dictionary=native.handles[component.id]
            var networks:Array=handle.occurrence.input_receivers.get("set_link_edges",[])
            check(networks.size()==1,label+" one exact delivered network owns the link")
            if networks.size()!=1:continue
            var network:Node3D=networks[0]
            if network.endpoints.size()!=2:
                check(false,label+" source endpoint packet: "+str(native.diagnostics.get(component.id,{})))
                continue
            check(network.endpoints.size()==2 and network.endpoints[0].actor_uuid==component.native_propagation.source.uuid \
                and network.endpoints[1].actor_uuid==component.native_propagation.target.uuid,label+" source binds the actual original actors")
            var primary:bool=component.actor_uuid==component.native_rule_caster_uuid
            check(network.endpoints[0].point.is_equal_approx(handle.endpoints.hand if primary else handle.endpoints.from),label+" beam originates at its exact measured hand or primary-contact body")
            check(network.settings.get("charge_coil",true)==primary,label+" charge coils occur only on the original caster")
            check(component.native_constructor_evidence.rule_caster_uuid==component.native_rule_caster_uuid,label+" optical source preserves the original gameplay caster in evidence")
            if not primary:
                check(network.endpoints[0].socket=="body_center" and not component.cast_recipe.enabled,label+" primary victim is a body socket, never a new casting actor")
            check(network.endpoints[1].socket=="body_center" and not network.endpoints[1].surface.points.is_empty(),label+" actual recipient pose/normal geometry reaches the source")
            var expected:float=Propagation.optical_contact(component,network.endpoints,handle.root.global_transform)
            check(is_equal_approx(float(handle.cue.source_contact),expected),label+" local cue maps the exact native optical arrival")
            check(is_equal_approx(Playback.source_time(handle.cue,float(handle.cue.contact)),expected),label+" existing source clock maps arrival to compiler contact exactly once")
            check(var_to_bytes(component.native_cue)==source_component,label+" native sampling leaves shared cue/authoring immutable")
            var diagnostic:Dictionary=native.diagnostics.get(component.id,{})
            check(diagnostic.get("input_bindings",{}).get("not_applicable",{})=={"density_field":"selected_factory_density_mask_disabled"},label+" native trace exposes explicit non-supplied density policy")
            check("density_field" not in diagnostic.get("input_bindings",{}).get("supplied",[]),label+" no invented density field is credited")
            world.camera_focus=Vector3(7,0,7.5);world.camera.size=12;world.initial_focus=true;world.position_camera();world.grid_visible=false
            await frame();await frame()
            var capture:String="res://.runtime/propagation-captures/"+example+"-"+seat+"-"+str(component.source_event_uuid)+( "-pre.png" if offset<0 else "-post.png")
            check(view.get_texture().get_image().save_png(capture)==OK,label+" contact capture saved")
            if offset<0:
                check(network.contact_state.is_empty() and network.last_paths.size()==1 and float(network.last_paths[0].reveal)<1.0,label+" native beam has not arrived before the damage contact")
            else:
                check(network.last_paths.size()==1 and is_equal_approx(float(network.last_paths[0].reveal),1.0) \
                    and network.contact_state.any(func(state):return int(state.endpoint)==1),label+" beam and recipient arcs arrive at the scheduled damage boundary")
                check(world.playbacks[component.target_uuid].clip=="TakeDamage",label+" recipient hurt animation is playing at actual link arrival")
                await frame();await frame();world.set_process(false)
                var present:Image=view.get_texture().get_image();Effects.hide(handle);await frame();await frame()
                var pixels:int=changed(present,view.get_texture().get_image())
                check(pixels>0,label+" actual link/contact contributes framebuffer pixels")
                evidence.append({"case":example,"seat":seat,"capture":capture,"application_occurrence":component.source_event_uuid,"contact_ms":contact,"native_source_contact":expected,"source_age":handle.age,
                    "changed_pixels":pixels,"source_uuid":component.actor_uuid,"target_uuid":component.target_uuid})
                handle.root.show();world.set_process(true)
    check(world.presentation_errors.is_empty() and world.media_issue.is_empty(),label+" seeking actual sources introduces no resource/presentation failures")
    world.component_renderer.native_spells.close(world)
    view.queue_free();await frame();await frame()
func finish()->void:
    var report:Dictionary={"checks":checks,"failures":failures,"evidence":evidence,
        "scope":"Original independent two-seat single and three-recipient Chain Lightning, source/recipient sockets, predecessor clocks/contact, victim coil absence, hurt pose, native pixels/captures and seek. Other variants, broad performance and user visual approval remain unqualified."}
    FileAccess.open("res://.runtime/native-propagation-render-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_PROPAGATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
