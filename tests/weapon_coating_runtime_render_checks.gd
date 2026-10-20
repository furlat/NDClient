extends "res://tests/weapon_runtime_receiver_render_checks.gd"
## Production Basic Poison on unchanged independent journals. The actual
## membership owns the clock; source suppression is only a pixel control.
const COATING_OUTPUT="res://.runtime/weapon-coating-runtime"
const SOURCE_REFUSALS=["material_only_source_has_no_qualified_finish","current_source_pose_has_no_authored_axis","concurrent_direct_material_requires_authored_composition"]
func settle(world:Node,ids:Array=[])->bool:
    var ready:bool=await NativeSupport.settle(self,world,ids,SOURCE_REFUSALS)
    check(ready,"Exact coating output or explicit unsupported-pose disposition: "+str(ids if ready else world.component_renderer.native_spells.diagnostics))
    return ready

func inspect(world:Node,component:Dictionary,label:String)->Dictionary:
    var native:RefCounted=world.component_renderer.native_spells
    check(native.handles.has(component.id),label+": actual item-effect occurrence exists")
    if not native.handles.has(component.id):return {}
    var handle:Dictionary=native.handles[component.id]
    check(handle.inner.components.has("equipped_weapon"),label+": delivered equipped source is used")
    if not handle.inner.components.has("equipped_weapon"):return {}
    var source:Node=handle.inner.components.equipped_weapon
    var binding:Dictionary=source.binding
    check(binding.item_uuid==component.item_owner_uuid and binding.owner_uuid==component.item_owner_uuid \
        and binding.holder_uuid==component.actor_uuid and binding.item_id=="weapon.longsword" \
        and binding.owner_kind=="item" and binding.binding_origin=="observed_item_effect" \
        and binding.effect_uuid==component.item_effect_uuid \
        and binding.contribution_uuid==component.item_effect_member.contribution_uuid \
        and binding.behavior_id==component.item_effect_member.behavior_id \
        and binding.damage_type==component.item_effect_member.damage_type and binding.equipment_slot=="MELEE_MAIN" \
        and binding.render_slot=="weapon",label+": actual item/effect/member/current holder is preserved")
    check(not binding.has("contribution_active") and not binding.has("decoration_admitted") \
        and not component.has("condition_uuid"),label+": no legacy flags or fabricated actor condition")
    var observation:Dictionary=source.capture_observation()
    evidence.append({"cut":label+"/admission","source":observation,"source_binding_valid":source._binding_valid(),
        "surface_actor":source.surface.get("actor"),"surface_item":source.surface.get("item_uuid"),
        "raw_actor":source.raw_layers.get("actor_uuid"),"binding_holder":binding.get("holder_uuid"),"retired":source.retired})
    if observation.rejection in SOURCE_REFUSALS:
        check(source.bound_materials.is_empty() and not observation.admitted,label+": unaudited axis stays source-refused without guessed geometry")
        check(native.diagnostics[component.id].status=="partial" and native.diagnostics[component.id].reason==observation.rejection,label+": Studio reports the real source refusal rather than an earlier green draw")
        if observation.rejection=="concurrent_direct_material_requires_authored_composition":
            var peers:Array=native.handles.values().filter(func(other):return other!=handle and other.component.get("item_owner_uuid")==component.item_owner_uuid \
                and other.inner.get("components",{}).has("equipped_weapon") and not other.inner.components.equipped_weapon.bound_materials.is_empty())
            check(peers.size()==1,label+": actual separate member owns the material; a second direct treatment never silently overwrites it")
        return {}
    check(not source.bound_materials.is_empty() and observation.admitted,label+": actual audited weapon receiver is admitted")
    var entries:Array=world.visual_actors[component.actor_uuid].entries.filter(func(entry):return \
        entry.actor_layer.get("item_uuid")==component.item_owner_uuid and entry.actor_layer.category=="Melee2" \
        and entry.actor_layer.slot=="weapon" and entry.node.is_visible_in_tree())
    check(not entries.is_empty(),label+": original Longsword Melee2 sheet remains the receiver")
    check(native.witnesses.any(func(row):return row.id==component.id+":weapon_surface" \
        and row.status=="rendered"),label+": actual bound weapon draw is witnessed")
    check(is_equal_approx(float(source.owner_state.owner_age_seconds),(world.timeline.display_ms-component.start_ms)/1000.0),label+": membership clock retains its real original age")
    return {"handle":handle,"source":source,"entries":entries}
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(800,600)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    DirAccess.make_dir_recursive_absolute(COATING_OUTPUT)
    case_id="poison-weapon-contact"
    var cases:Array=[]
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--case="):case_id=argument.trim_prefix("--case=")
        if argument.begins_with("--cases="):cases=Array(argument.trim_prefix("--cases=").split(","))
    if cases.is_empty():cases=[case_id]
    for selected in cases:
        case_id=selected
        for seat in ["amber","blue"]:
            var index:Dictionary=Fixtures.read(case_id,seat)
            check(index.ok,seat+": original compiles through production assignments")
            if not index.ok:continue
            index.media_preload=RecordingMedia.plan(index)
            var immutable:PackedByteArray=var_to_bytes([index.initialization,index.groups,index.rows])
            var held:Array=index.rows.filter(func(row):return row.kind=="native_effect" and row.get("component",{}).get("dynamic_item_effect",false))
            check(not held.is_empty(),seat+": genuine original has an equipped coating interval")
            if held.is_empty():continue
            for quarter in 4:await coating_view(index,held,seat,quarter)
            check(var_to_bytes([index.initialization,index.groups,index.rows])==immutable,seat+": rendering never mutates original identities, state or timing")
    var report:Dictionary={"checks":checks,"failures":failures,"evidence":evidence,"case":case_id,
        "scope":"Selected actual production coating appearances, both original factions/four views, real membership and retirement, actual weapon poses/contact, suppression pixels, exact unchanged opacity/palette/native 2D lighting oracle, seeking/loop/cleanup. Source pose/composition refusals remain explicit. No invented elemental damage/Poisoned, guessed axis or artistic acceptance."}
    FileAccess.open(COATING_OUTPUT+"/result.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("WEAPON_COATING_RUNTIME ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
func coating_view(index:Dictionary,held:Array,seat:String,quarter:int)->void:
    var first:Dictionary=held[0];var component:Dictionary=first.component
    var poses:Array=cuts(index,first,seat)
    check(poses.any(func(value):return value.kind=="idle") and poses.any(func(value):return value.kind=="attack"),seat+": actual original supplies held Idle and attack")
    if poses.is_empty():return
    var view:SubViewport=viewport();var world=Play.new()
    world.external_playback=true;world.external_clock=true;world.quarter=quarter
    world.catalog_cache=Play.Catalog.source_snapshot(index.cache);world.media_warmup.budget_bytes=0
    world.media_warmup.encounter_override=index.media_preload
    world.playback_end_ms=index.presentation_end_ms;world.component_renderer.audio.set_enabled(false)
    view.add_child(world);world.install_playback(Recording.restore(index,maxf(0.0,first.start_ms-.01)))
    if not await settle(world):view.queue_free();await frame();return
    check(world.timeline.component_samples(index.cache).all(func(value):return not value.get("dynamic_item_effect",false)),seat+": no coating is published before actual membership")
    world.camera.size=3;world.grid_visible=false;world.wall_mode="hidden";world.update_wall_visibility()
    var label:String=case_id+"/"+seat+"/q"+str(quarter)
    var owner:WeakRef
    for pose in poses:
        if not await advance(world,pose.at_ms,[component.id]):continue
        world.camera_focus=Play.Placement.contact(world.visual_actors[component.actor_uuid].row);world.initial_focus=true;world.position_camera()
        await frame();await frame()
        var admitted:Dictionary=inspect(world,component,label+"/"+pose.kind)
        if admitted.is_empty():continue
        if owner==null:owner=weakref(admitted.handle.root)
        check(admitted.handle.component.start_ms==component.start_ms,label+": pose support never restarts the actual membership clock")
        if pose.kind=="idle":await receiver_pixels(world,view,admitted,label,quarter==0)
        evidence.append({"seat":seat,"quarter":quarter,"pose":pose.kind,"display_ms":world.timeline.display_ms,
            "binding":admitted.source.binding,"construction_ms":admitted.handle.construction_phases,
            "source":admitted.source.capture_observation()})
        for peer in world.timeline.component_samples(index.cache).filter(func(value):return value.get("dynamic_item_effect",false) \
                and value.item_owner_uuid==component.item_owner_uuid and value.id!=component.id):
            inspect(world,peer,label+"/coexisting-member")
    if await advance(world,index.presentation_end_ms):
        check(world.timeline.component_samples(index.cache).all(func(value):return not value.get("dynamic_item_effect",false)),label+": actual expiry removes the optical coating")
        if case_id=="poison-weapon-contact":check(world.timeline.state.items[component.item_owner_uuid].effects.is_empty(),label+": same item has the genuine empty membership after expiry")
        var entries:Array=world.visual_actors[component.actor_uuid].entries.filter(func(entry):return entry.actor_layer.get("item_uuid")==component.item_owner_uuid \
            and entry.actor_layer.slot=="weapon" and entry.node.is_visible_in_tree())
        if case_id=="poison-weapon-contact":check(not entries.is_empty(),label+": exact same sword remains visibly equipped after natural expiry")
        check(entries.all(func(entry):return entry.material.shader==BASELINE or ["weapon_blade_enabled","weapon_element_enabled","weapon_auxiliary_enabled","weapon_pure_enabled","weapon_receiver_draw_enabled"].all(func(uniform):return entry.material.get_shader_parameter(uniform)==false)),label+": actual remaining receiver has no enabled coating after real retirement")
    if await seek(world,index,poses[0].at_ms,[component.id]):
        check(owner==null or owner.get_ref()==null,label+": reverse loop releases previous private source")
        inspect(world,component,label+"/loop")
    check(world.presentation_errors.is_empty() and world.media_issue.is_empty() and not world.publication_failed,label+": ordinary replay remains healthy")
    world.component_renderer.native_spells.close(world)
    check(world.component_renderer.native_spells.handles.is_empty(),label+": private owner cleanup is complete")
    view.queue_free();await frame();await frame()
