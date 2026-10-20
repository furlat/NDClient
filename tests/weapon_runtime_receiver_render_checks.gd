extends SceneTree
## Actual equipped Ember occurrence in ordinary Play. The isolated receiving
## comparison borrows its real displayed mesh/material; it creates no game facts.
const Recording=preload("res://studio/recording.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
const Journal=preload("res://sdk/journal.gd")
const Play=preload("res://play.gd")
const NativeSupport=preload("res://tests/dynamic_weapon_support.gd")
const LightTable=preload("res://presentation/light_table.gd")
const RecordingMedia=preload("res://studio/recording_media.gd")
const BASELINE=preload("res://modular.gdshader")
const OUTPUT="res://.runtime/weapon-runtime-receiver"
var checks:int=0
var failures:Array=[]
var evidence:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("WEAPON_RECEIVER_FAIL ",label)
func frame()->void:await NativeSupport.frame(self)
func settle(world:Node,ids:Array=[])->bool:
    var ok:bool=await NativeSupport.settle(self,world,ids)
    check(ok,"Actual replay/native preparation: "+str(ids if ok else {"errors":world.presentation_errors,"media":world.media_issue,"native":world.component_renderer.native_spells.diagnostics}))
    return ok
func viewport()->SubViewport:
    var view:=SubViewport.new();view.size=Vector2i(800,600);view.own_world_3d=true
    view.transparent_bg=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    root.add_child(view);return view
func cuts(index:Dictionary,owner:Dictionary,seat:String)->Array:
    var actor:String=owner.component.actor_uuid
    var attacks:Array=Fixtures.fact_rows("ember-weapon-runtime","attack",seat).map(func(row):return str(int(row.node.occurrence)))
    var result:Array=[];var idle_candidates:Array=[float(owner.start_ms)+.01]
    for row in index.rows:
        if row.kind!="body" or row.track.actor_uuid!=actor:continue
        var middle:float=lerpf(row.start_ms,row.end_ms,.5)
        if middle>=owner.start_ms and middle<owner.end_ms:
            if row.track.clip.begins_with("Run") and not result.any(func(value):return value.kind=="movement"):
                result.append({"kind":"movement","at_ms":middle,"clip":row.track.clip})
            if str(row.source_event_uuid) in attacks and not result.any(func(value):return value.kind=="attack"):
                result.append({"kind":"attack","at_ms":middle,"clip":row.track.clip})
        idle_candidates.append(float(row.end_ms)+.01)
    idle_candidates.sort()
    for at in idle_candidates:
        if at<owner.start_ms or at>=owner.end_ms:continue
        var timeline:RefCounted=Recording.restore(index,at)
        var actual:Dictionary=timeline.state.actors.get(actor,{})
        if actual.is_empty():continue
        var rig:Dictionary=Recording.Characters.rigs(index.cache)[Recording.Characters.rig_id(actual,index.cache)]
        var rest:Dictionary=Recording.Characters.rest_sample(actual,rig,index.cache)
        if not rest.ok:continue
        var clip:String=timeline.actor_samples().get(actor,{}).get("clip",rest.value.clip)
        if clip.begins_with("Idle"):
            result.append({"kind":"idle","at_ms":at,"clip":clip});break
    result.sort_custom(func(a,b):return a.at_ms<b.at_ms)
    return result
func inspect(world:Node,component:Dictionary,label:String)->Dictionary:
    var native:RefCounted=world.component_renderer.native_spells
    check(native.handles.has(component.id),label+": actual intrinsic occurrence exists")
    if not native.handles.has(component.id):return {}
    var handle:Dictionary=native.handles[component.id]
    check(handle.inner.components.has("equipped_weapon"),label+": occurrence is the delivered equipped component")
    if not handle.inner.components.has("equipped_weapon"):return {}
    var source:Node=handle.inner.components.equipped_weapon
    var binding:Dictionary=source.binding
    check(binding.item_uuid==component.item_owner_uuid and binding.owner_uuid==component.item_owner_uuid \
        and binding.holder_uuid==component.actor_uuid and binding.item_id=="weapon.roster.ember_longsword" \
        and binding.owner_kind=="item" and binding.binding_origin=="intrinsic_authored_item" \
        and binding.equipment_slot=="MELEE_MAIN" and binding.render_slot=="weapon",label+": exact disclosed item/current holder/slot, without a temporary member")
    check(not binding.has("effect_uuid") and not binding.has("contribution_active") and not binding.has("decoration_admitted"),label+": no invented effect UUID or unused legacy admission flags")
    check(not source.bound_materials.is_empty() and source.adapter_error.is_empty() and source.capture_observation().admitted,label+": actual receiver materials are bound, not merely setter-accepted")
    var entries:Array=world.visual_actors[component.actor_uuid].entries.filter(func(entry):return entry.actor_layer.get("item_uuid")==component.item_owner_uuid \
        and entry.actor_layer.category=="Melee2" and entry.actor_layer.slot=="weapon" and entry.node.is_visible_in_tree())
    check(not entries.is_empty(),label+": original modular Melee2 sword remains the actual weapon body")
    check(native.witnesses.any(func(row):return row.id==component.id+":weapon_surface" and row.status=="rendered"),label+": Studio receives the actual surface draw witness")
    check(is_equal_approx(float(source.owner_state.source_age_seconds),float(handle.weapon_source_age)) \
        and source.bound_materials.all(func(material):return is_equal_approx(float(material.get_shader_parameter("weapon_blade_seconds")),float(source.owner_state.source_age_seconds))),label+": actual bound material uses the private source clock, separately from membership age")
    return {"handle":handle,"source":source,"entries":entries}
func seek(world:Node,index:Dictionary,at:float,ids:Array=[])->bool:
    check(world.try_reset_hidden_playback(Recording.restore(index,at)),"Ordinary replay seek to "+str(at))
    return await settle(world,ids)
func advance(world:Node,at:float,ids:Array=[])->bool:
    var plan:Dictionary={};var deadline:int=Time.get_ticks_msec()+45000
    while world.timeline.display_ms<at-.000001 and Time.get_ticks_msec()<deadline:
        await process_frame
        if plan.is_empty():plan=world.timeline.replay_plan(minf(at,world.timeline.display_ms+1000.0/60.0))
        if world.timeline.replay_prepare(plan):
            if world.can_publish_replay_advance(plan):
                check(world.publish_replay_advance(plan),"Original ordered replay boundary publishes")
                plan={}
            else:world.timeline.replay_cancel_preparation();plan={}
        await RenderingServer.frame_post_draw
        if not world.presentation_errors.is_empty() or not world.media_issue.is_empty():break
    check(is_equal_approx(world.timeline.display_ms,at),"Ordinary replay reaches actual cut "+str(at))
    return is_equal_approx(world.timeline.display_ms,at) and await settle(world,ids)
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(800,600)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    DirAccess.make_dir_recursive_absolute(OUTPUT)
    for seat in ["amber","blue"]:
        var index:Dictionary=Fixtures.read("ember-weapon-runtime",seat)
        var journal:RefCounted=Journal.new();var opened:Dictionary=journal.open(Fixtures.journal("ember-weapon-runtime",seat),true)
        check(index.ok and opened.ok,"Independent original "+seat+" journal and production presentation index")
        if not index.ok or not opened.ok:continue
        index.media_preload=RecordingMedia.plan(index)
        var immutable:PackedByteArray=var_to_bytes([index.initialization,index.groups,index.rows])
        var held:Array=index.rows.filter(func(row):return row.kind=="native_effect" and row.get("component",{}).get("intrinsic_item_effect",false))
        check(held.size()==1,"One real Ember owner interval, "+seat)
        if held.size()!=1:continue
        var owner:Dictionary=held[0];var component:Dictionary=owner.component
        var poses:Array=cuts(index,owner,seat)
        check(poses.size()==3 and ["idle","movement","attack"].all(func(kind):return poses.any(func(value):return value.kind==kind)),"Original provides Idle, movement and attack while Ember is equipped: "+str(poses))
        if poses.size()!=3:continue
        for quarter in 4:await original_view(index,owner,poses,seat,quarter,journal.snapshot())
        check(var_to_bytes([index.initialization,index.groups,index.rows])==immutable,"Native playback/seek never mutates original audience facts or source cuts, "+seat)
    var report:Dictionary={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Original both-seat Ember mainhand receiver, actual Idle/Run/attack and equipment retirement/replacement, four views, strict unchanged modular-shader receiving parity under opacity/palette/2D light-table controls, native pixels, seek/loop and teardown. No offhand, other artistic alternatives, invented gameplay or visual approval."}
    FileAccess.open(OUTPUT+"/result.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("WEAPON_RUNTIME_RECEIVER ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
func original_view(index:Dictionary,owner:Dictionary,poses:Array,seat:String,quarter:int,final:Dictionary)->void:
    var view:SubViewport=viewport();var world=Play.new()
    world.external_playback=true;world.external_clock=true;world.quarter=quarter
    world.catalog_cache=Play.Catalog.source_snapshot(index.cache);world.media_warmup.budget_bytes=0
    world.media_warmup.encounter_override=index.media_preload
    world.playback_end_ms=index.presentation_end_ms;world.component_renderer.audio.set_enabled(false)
    view.add_child(world);world.install_playback(Recording.restore(index,poses[0].at_ms))
    var component:Dictionary=owner.component;var label:String=seat+"/q"+str(quarter)
    if not await settle(world,[component.id]):view.queue_free();await frame();return
    world.camera.size=3;world.grid_visible=false;world.wall_mode="hidden";world.update_wall_visibility()
    var epoch:int=world.timeline.initialization_revision
    var original_owner:WeakRef=weakref(world.component_renderer.native_spells.handles[component.id].root)
    for pose in poses:
        if not await advance(world,pose.at_ms,[component.id]):continue
        world.camera_focus=Play.Placement.contact(world.visual_actors[component.actor_uuid].row);world.initial_focus=true;world.position_camera()
        await frame();await frame()
        check(world.playbacks[component.actor_uuid].clip==pose.clip,label+": actual "+pose.kind+" body clip is unchanged")
        check(world.timeline.initialization_revision==epoch and world.component_renderer.native_spells.handles[component.id].root==original_owner.get_ref(),label+": ordinary pose changes retain the same actual private item owner")
        var admitted:Dictionary=inspect(world,component,label+"/"+pose.kind)
        if admitted.is_empty() or admitted.entries.is_empty():continue
        if pose.kind=="idle":await receiver_pixels(world,view,admitted,label,quarter==0)
        var completed:Dictionary=world.profile.frames[(int(world.profile.cursor)-1+world.profile.frames.size())%world.profile.frames.size()].cpu_ms if not world.profile.frames.is_empty() else {}
        evidence.append({"seat":seat,"quarter":quarter,"pose":pose.kind,"clip":pose.clip,"display_ms":world.timeline.display_ms,"item_uuid":component.item_owner_uuid,
            "construction_ms":admitted.handle.construction_phases.duplicate(false),
            "observed_sample_phases_ms":{"native_input_bindings":completed.get("native_input_bindings"),"native_sample_sources":completed.get("native_sample_sources")},
            "source":admitted.source.capture_observation()})
    var native:RefCounted=world.component_renderer.native_spells
    var retired:Array=[]
    if native.handles.has(component.id):retired.append(weakref(native.handles[component.id].root))
    if await advance(world,index.presentation_end_ms):
        check(world.timeline.state==final,label+": final replay equals the independently folded original audience")
        check(world.timeline.component_samples(index.cache).all(func(value):return not value.get("intrinsic_item_effect",false)),label+": removal retires the old Ember owner")
        var entries:Array=world.visual_actors[component.actor_uuid].entries
        check(not entries.any(func(entry):return entry.actor_layer.get("item_uuid")==component.item_owner_uuid and entry.node.is_visible_in_tree()) \
            and entries.any(func(entry):return world.timeline.state.items.get(entry.actor_layer.get("item_uuid",""),{}).get("look",{}).get("item_id")=="weapon.longsword" \
                and entry.actor_layer.category=="Melee2" and entry.node.is_visible_in_tree()),label+": actual plain modular replacement has no Ember body")
    var idle:Dictionary=poses.filter(func(value):return value.kind=="idle")[0]
    if await seek(world,index,idle.at_ms,[component.id]):
        check(retired.all(func(reference):return reference.get_ref()==null),label+": loop releases preceding private native owners")
        inspect(world,component,label+"/loop")
    check(world.presentation_errors.is_empty() and world.media_issue.is_empty() and not world.publication_failed,label+": ordinary renderer leaves no errors")
    native.close(world)
    check(native.handles.is_empty() and native.groups.is_empty() and native.prepared_layers.is_empty(),label+": native owners/material preparations close")
    view.queue_free();await frame();await frame()
func receiver_pixels(world:Node,view:SubViewport,admitted:Dictionary,label:String,oracle:bool)->void:
    world.set_process(false);await frame()
    var source:Node=admitted.source;var binding:Dictionary=source.binding
    var original_state:PackedByteArray=var_to_bytes(world.timeline.state)
    var owner_state:Dictionary=source.owner_state.duplicate(false)
    var age:float=source.owner_state.source_age_seconds;var shown:Image=view.get_texture().get_image()
    var suppressed:Dictionary=binding.duplicate(false);suppressed.suppressed=true
    check(not source.set_weapon_binding(suppressed),label+": explicit optical suppression refuses admission")
    source.sample(age);await frame();await frame()
    var plain:Image=view.get_texture().get_image()
    check(source.bound_materials.is_empty(),label+": suppressed source releases its actual receiver claims")
    check(NativeSupport.changed(shown,plain)>0,label+": admitted Ember source contributes actual framebuffer pixels")
    evidence.append({"cut":label+"/actual-source-pixels","changed_pixels":NativeSupport.changed(shown,plain),"source_age_seconds":age,"owner_age_seconds":source.owner_state.owner_age_seconds})
    shown.save_png(OUTPUT+"/"+label.replace("/","-")+"-active.png")
    plain.save_png(OUTPUT+"/"+label.replace("/","-")+"-suppressed.png")
    if oracle:await receiving_oracle(world,admitted.entries[0],label)
    check(source.set_weapon_binding(binding),label+": exact original binding restores without fake fields")
    source.sample(age);await frame();await frame()
    check(not source.bound_materials.is_empty() and NativeSupport.changed(view.get_texture().get_image(),plain)>0,label+": same owner/source age restores visible native treatment")
    check(source.owner_state==owner_state and var_to_bytes(world.timeline.state)==original_state,label+": optical controls preserve actual source clock and canonical state")
    world.set_process(true)
func alpha_sum(image:Image)->int:
    var data:PackedByteArray=image.get_data();var result:int=0
    for i in range(3,data.size(),4):result+=data[i]
    return result
func receiving_page(world:Node,entry:Dictionary,material:ShaderMaterial)->SubViewport:
    var view:SubViewport=viewport()
    var camera:=Camera3D.new();view.add_child(camera)
    camera.projection=world.camera.projection;camera.keep_aspect=world.camera.keep_aspect;camera.size=world.camera.size
    camera.near=world.camera.near;camera.far=world.camera.far;camera.global_transform=world.camera.global_transform;camera.current=true
    var node:=MeshInstance3D.new();node.mesh=entry.node.mesh;node.material_override=material
    view.add_child(node);node.global_transform=entry.node.global_transform
    node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    return view
func receiving_oracle(world:Node,entry:Dictionary,label:String)->void:
    # Compare the exact real source mesh and uniforms through both programs.
    # Isolated pages avoid modifying the production SourceMaterial/atlas ledger.
    var program:ShaderMaterial=entry.material.duplicate(false)
    var raw:ShaderMaterial=entry.material.duplicate(false)
    check(program.shader.get_meta("factory_actor_material","")=="weapon_layers" \
        and program.get_meta("factory_original_shader")==BASELINE,label+": corrected receiver wraps the actual unchanged modular shader")
    raw.shader=BASELINE
    var actual:SubViewport=receiving_page(world,entry,program)
    var expected:SubViewport=receiving_page(world,entry,raw)
    RenderingServer.global_shader_parameter_set(&"light_ambient",.12)
    RenderingServer.global_shader_parameter_set(&"light_cap",1.0)
    RenderingServer.global_shader_parameter_set(&"light_normals",false)
    var table:=LightTable.new()
    var cookie:Image=Image.create(256,256,false,Image.FORMAT_RGBA8);cookie.fill(Color.WHITE)
    var texture:ImageTexture=ImageTexture.create_from_image(cookie)
    var point:Dictionary={"id":"test-optical-point","enabled":true,"screen_position":Vector2(400,200),"texture":texture,"texture_scale":8.0,"cookie_scale":Vector2.ONE,"offset":Vector2.ZERO,"height":150.0,"color":Color(.35,.65,1.0),"energy":.8}
    var directional:Dictionary={"id":"test-optical-directional","enabled":true,"direction":Vector2(.6,-.8),"height":.8,"color":Color(1.0,.65,.3),"energy":.8}
    var palette_values:=PackedVector3Array([Vector3(.08,.3,.2),Vector3(.9,.35,.7)])
    palette_values.resize(32)
    var samples:Dictionary={}
    for light in ["ambient","directional","point"]:
        table.publish([point] if light=="point" else [],func(_texture):return cookie,[directional] if light=="directional" else [])
        check(table.issues.is_empty(),label+": bounded "+light+" receiving control is prepared")
        for palette in [false,true]:
            for material in [raw,program]:
                material.set_shader_parameter("effect_palette_enabled",palette)
                material.set_shader_parameter("effect_palette_count",2)
                material.set_shader_parameter("effect_palette",palette_values)
            var full:int=0
            for opacity in [1.0,.55,0.0]:
                for material in [raw,program]:material.set_shader_parameter("condition_alpha",opacity)
                await frame();await frame()
                var reference:Image=expected.get_texture().get_image();var received:Image=actual.get_texture().get_image()
                reference.convert(Image.FORMAT_RGBA8);received.convert(Image.FORMAT_RGBA8)
                var key:String="%s/palette=%s/opacity=%s"%[light,palette,opacity]
                check(reference.get_data()==received.get_data(),label+": exact original-shader RGBA, "+key)
                var covered:int=alpha_sum(reference)
                if opacity==1.0:
                    full=covered;check(full>0,label+": actual original sword has visible receiving coverage, "+key)
                    samples[light+str(palette)]=reference.get_data()
                elif opacity==0.0:check(covered==0,label+": opacity zero remains invisible with palette "+str(palette))
                else:check(covered>0 and covered<full,label+": partial opacity remains partial with palette "+str(palette))
                if palette and opacity==.55:
                    reference.save_png(OUTPUT+"/"+label.replace("/","-")+"-"+light+"-baseline.png")
                    received.save_png(OUTPUT+"/"+label.replace("/","-")+"-"+light+"-receiver.png")
    check(samples.get("ambientfalse")!=samples.get("directionalfalse") and samples.get("ambientfalse")!=samples.get("pointfalse"),label+": both directional and point controls change actual native2D receiving")
    check(samples.get("ambientfalse")!=samples.get("ambienttrue"),label+": palette control changes actual original weapon colours")
    expected.queue_free();actual.queue_free();await frame()
    # Restore the real world's owning table before the temporary table retires.
    world.light_table.invalidate();world.receiving_globals=[];world._publish_receiving()
    evidence.append({"cut":label+"/receiver-parity","comparisons":18,"oracle":"unchanged modular.gdshader with actual admitted Melee2 mesh/material/transform/camera","light_controls":"existing native2D receiving table; no Light3D"})
