extends "res://tests/native_vampiric_touch_render_checks.gd"
## Actual original Mace/shield pixels, with explicit client-only decoration.
const Data=preload("res://tests/weapon_surface_anchor_checks.gd")
const Support=preload("res://tests/dynamic_weapon_support.gd")
const Items=preload("res://presentation/native_items.gd")
const Sockets=preload("res://presentation/spell_placement.gd")

func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(800,600)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    DirAccess.make_dir_recursive_absolute("res://.runtime/weapon-surface-captures")
    var index:Dictionary=Recording.read(Fixtures.journal("divine-arm","party"),{},{},Data.source_cache())
    check(index.ok,"Original party recording compiles with test-only intrinsic source staging")
    if not index.ok:finish();return
    var original:PackedByteArray=var_to_bytes([index.initialization,index.groups])
    var at:float=-1.0;var idle:float=-1.0
    # Inspect only actual recorded cuts and their real track boundaries.
    # No pose, equipment, source frame or canonical state is replaced.
    var candidates:Array=[]
    for entry in index.groups:
        for commit in entry.group.commits:candidates.append(float(entry.start_ms)+float(commit.at_ms)+.01)
        for track in entry.group.actor_tracks:candidates.append(float(entry.start_ms)+float(track.start_ms)+float(track.duration_ms)+.01)
    candidates.sort()
    var identities:Dictionary={}
    for candidate in candidates:
        var timeline:RefCounted=Recording.restore(index,candidate)
        var ids:Dictionary=Data.identities(timeline.state)
        if ids.is_empty():continue
        var actor:Dictionary=timeline.state.actors[ids.actor]
        var rig:Dictionary=Recording.Characters.rigs(index.cache)[Recording.Characters.rig_id(actor,index.cache)]
        var resting:Dictionary=Recording.Characters.rest_sample(actor,rig,index.cache)
        if not resting.ok:continue
        var clip:String=timeline.actor_samples().get(ids.actor,{}).get("clip",resting.value.clip)
        if at<0 and clip=="Taunt":at=candidate;identities=ids
        elif at>=0 and candidate>at and clip.begins_with("Idle"):
            idle=candidate;break
    check(at>=0 and idle>at,"Original actual main/offhand holdings expose missing-grip Taunt then registered Idle")
    if at<0 or idle<=at:finish();return
    var view:=SubViewport.new();view.size=Vector2i(800,600);view.own_world_3d=true
    view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    var world=Play.new();world.external_playback=true;world.external_clock=true;world.media_warmup.budget_bytes=0
    world.catalog_cache=Play.Catalog.source_snapshot(index.cache);world.playback_end_ms=index.presentation_end_ms
    world.component_renderer.audio.set_enabled(false);view.add_child(world)
    world.install_playback(Recording.restore(index,at))
    var expected:PackedByteArray=var_to_bytes(world.timeline.state)
    if not await settle_items(world,identities):await close_world(world,view);finish();return
    check(world.playbacks[identities.actor].clip=="Taunt", "Ordinary replay retains the actual unregistered-grip pose")
    var native=world.component_renderer.native_spells
    var owned:Array=selected(world,identities)
    check(owned.size()==2,"Both exact original item channels own independent test decorations")
    var owners:Array=[]
    for component in owned:
        var handle:Dictionary=native.handles[component.id]
        owners.append({"id":component.id,"owner":handle.occurrence})
        var points:Dictionary=handle.endpoints
        var registration:Dictionary=points.weapon_registration
        var binding:Dictionary=handle.occurrence.receiving.weapon_binding
        check(registration.ready and registration.measured and not registration.hand.ready and points.has("optical_anchor") and not points.has("hand"),"Missing grip uses only the named measured support anchor")
        check(not binding.has("hand") and binding.item_uuid==component.item_owner_uuid and binding.holder_uuid==identities.actor,"No offhand/main-hand grip or fabricated item identity is supplied")
        check(not binding.has("contribution_active") and not binding.has("decoration_admitted"),"Prepared exact receiving does not forge legacy gameplay contribution flags")
        check(handle.occurrence.receiving.admitted_geometry and handle.occurrence.receiving.current_surface.points.all(func(point):return point.slot==registration.weapon.render_slot),"Only the actual selected item source pixels are admitted")
        check(not bool(handle.occurrence.receiving.entries[0].material.get_shader_parameter("vfx_measured_reverse")),"Missing-grip branch retains the source's explicit optional orientation default")
        var surface:Dictionary=registration.surface
        var centroid:=Vector3.ZERO
        for point in surface.points:centroid+=point.position
        centroid/=float(surface.points.size())
        check(points.optical_anchor.is_equal_approx(centroid),"Cached optical anchor equals independently summed actual world support points")
        check(handle.root.global_position.is_equal_approx(centroid),"Native receiving frame is rooted at its own real optical centroid")
        check(native.diagnostics[component.id].input_bindings.unavailable.is_empty(),"All actual source inputs resolve without a grip placeholder")
    world.camera_focus=Play.Placement.contact(world.visual_actors[identities.actor].row);world.camera.size=3.5
    world.initial_focus=true;world.position_camera();world.grid_visible=false;world.wall_mode="hidden";world.update_wall_visibility()
    for quarter in 4:
        world.request_view(quarter)
        var deadline:int=Time.get_ticks_msec()+45000
        while world.rotation_pending() and Time.get_ticks_msec()<deadline:await frame()
        check(not world.rotation_pending() and world.quarter==quarter,"Actual view publishes q"+str(quarter))
        if not await settle_items(world,identities):break
        for owner in owners:check(native.handles.has(owner.id) and native.handles[owner.id].occurrence==owner.owner,"View change preserves exact native item occurrence")
        await pixels(world,view,selected(world,identities),"taunt-q"+str(quarter))
        check(var_to_bytes(world.timeline.state)==expected,"Optical registration and view changes preserve every canonical public fact")
    # Restore the actual later Idle cut: existing registered hand math and its
    # source's hilt/tip orientation must remain completely intact.
    world.install_playback(Recording.restore(index,idle))
    if await settle_items(world,identities):
        var main:Array=selected(world,identities).filter(func(component):return component.item_owner_uuid==identities.main)
        check(main.size()==1,"Later registered pose still has the exact Mace source")
        if main.size()==1:
            var handle:Dictionary=native.handles[main[0].id]
            var physical:Dictionary=Sockets.pose_point(world,world.visual_actors[identities.actor].row,"hand")
            var previous:Dictionary=Sockets.endpoints(world,main[0])
            check(physical.ready and handle.endpoints.hand==physical.point and not handle.endpoints.has("optical_anchor"),"Known hand follows its original measured authored registration exactly")
            check(handle.occurrence.receiving.weapon_binding.hand==physical.point,"Existing prepared binding retains the exact real hand and UV orientation input")
            check([previous.from,previous.hand,previous.to,previous.ground]==[handle.endpoints.from,handle.endpoints.hand,handle.endpoints.to,handle.endpoints.ground],"Complete old/new known-grip placement tuple remains exactly equal")
        await pixels(world,view,selected(world,identities),"idle-authored-hand")
    world.install_playback(Recording.restore(index,0.0))
    if await settle(world):check(not world.timeline.state.items.has(identities.main),"Reverse seek cannot retain the future created Mace")
    world.install_playback(Recording.restore(index,at))
    if await settle_items(world,identities):
        check(var_to_bytes(world.timeline.state)==expected,"Repeated actual Taunt cut restores identical public state")
        await pixels(world,view,selected(world,identities),"loop-taunt")
    check(var_to_bytes([index.initialization,index.groups])==original,"No test staging or native rendering rewrites the original recorded facts or clocks")
    await close_world(world,view);finish()

func selected(world:Node,ids:Dictionary)->Array:
    return Items.samples(world.timeline.item_effect_owners,world.timeline.state,world.timeline.display_ms).filter(func(component):
        return component.get("intrinsic_item_effect",false) and component.item_owner_uuid in [ids.main,ids.off])

func settle_items(world:Node,ids:Dictionary)->bool:
    var names:Array=selected(world,ids).map(func(component):return component.id)
    check(names.size()==2,"Actual current holdings publish both independent item decorations")
    var ready:bool=await Support.settle(self,world,names)
    check(ready,"Ordinary native preparation settles: "+str({"errors":world.presentation_errors,"media":world.media_issue,"native":world.component_renderer.native_spells.diagnostics} if not ready else names))
    return ready

func pixels(world:Node,view:SubViewport,components:Array,label:String)->void:
    var native=world.component_renderer.native_spells
    for component in components:
        var handle:Dictionary=native.handles[component.id]
        await frame();await frame();world.set_process(false)
        # Hide withdraws the source's real binding; retain only observed evidence.
        var binding:Dictionary=handle.occurrence.receiving.weapon_binding.duplicate(true)
        var slot:String=handle.endpoints.weapon_registration.weapon.render_slot
        var owner:Node3D=handle.occurrence
        check(binding.get("render_slot")==slot and binding.get("item_uuid")==component.item_owner_uuid \
            and binding.get("holder_uuid")==component.actor_uuid,"Pixel control starts from the exact admitted item/holder/slot")
        var shown:Image=view.get_texture().get_image()
        Effects.hide(handle);await frame();await frame()
        check(handle.occurrence.receiving.weapon_binding.is_empty() and not handle.occurrence.receiving.admitted_geometry,
            "Hide withdraws this measured item's actual receiver admission")
        var hidden:Image=view.get_texture().get_image();var count:int=changed(shown,hidden)
        check(count>0,"Exact real "+slot+" source contributes pixels: "+label)
        var stem:String="res://.runtime/weapon-surface-captures/"+label+"-"+slot
        shown.save_png(stem+"-shown.png");hidden.save_png(stem+"-hidden.png")
        evidence.append({"cut":label,"at_ms":world.timeline.display_ms,"item_uuid":component.item_owner_uuid,"pixels":count,
            "binding":binding,"capture":stem+"-shown.png"})
        world.set_process(true)
        var restored:bool=await Support.settle(self,world,[component.id])
        check(restored,"Ordinary presenter restores the withdrawn real item source: "+label+"/"+slot)
        if not restored:return
        check(native.handles[component.id].occurrence==owner \
            and native.handles[component.id].occurrence.receiving.weapon_binding==binding \
            and native.handles[component.id].occurrence.receiving.admitted_geometry,
            "Re-entry restores the same occurrence and exact actual binding after native draw")

func close_world(world:Node,view:SubViewport)->void:
    world.component_renderer.native_spells.close(world)
    check(world.component_renderer.native_spells.handles.is_empty(),"All private prepared item occurrences are released")
    check(world.presentation_errors.is_empty() and world.media_issue.is_empty(),"Replay/seek/view changes introduce no resource or presentation errors")
    view.queue_free();await frame();await frame()

func finish()->void:
    var report:Dictionary={"checks":checks,"failures":failures,"evidence":evidence,
        "scope":"Original party Mace/shield holdings and real Taunt/Idle source poses with client-test intrinsic measured decoration, actual source/item/geometry/native pixels/four views/seek. Shield tests offhand optics, not legal offhand weapon-coating gameplay. Event/FlameBlade lifetime outcomes and art approval remain independent."}
    FileAccess.open("res://.runtime/native-weapon-surface-anchor-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_WEAPON_SURFACE_ANCHOR ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
