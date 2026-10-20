extends SceneTree
## Original Devotee Mace membership, actual modular optical sources and private
## prepared effects. The coating is test staging, never accepted production art.
const Support=preload("res://tests/dynamic_weapon_support.gd")
const Recording=preload("res://studio/recording.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
const Items=preload("res://presentation/native_items.gd")
const Play=preload("res://play.gd")
const Effects=preload("res://presentation/effect_package.gd")
var checks:int=0
var failures:Array=[]
var evidence:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("DYNAMIC_ITEM_RENDER_FAIL ",label)
func frame()->void:await Support.frame(self)
func settle(world:Node,ids:Array=[])->bool:
    var ok:bool=await Support.settle(self,world,ids)
    check(ok,"Normal replay preparation and exact native inputs settle: "+str({"display_ms":world.timeline.display_ms,"errors":world.presentation_errors,"media":world.media_issue,"native":world.component_renderer.native_spells.diagnostics} if not ok else ids))
    return ok
func advance(world:Node,at_ms:float)->bool:
    var plan:Dictionary=world.timeline.replay_plan(at_ms)
    var deadline:int=Time.get_ticks_msec()+45000
    while Time.get_ticks_msec()<deadline and world.presentation_errors.is_empty() and world.media_issue.is_empty():
        if world.timeline.replay_prepare(plan) and world.can_publish_replay_advance(plan):
            var published:bool=world.publish_replay_advance(plan)
            await frame()
            check(published,"The actual equipment boundary publishes through ordinary replay preparation: "+str(at_ms))
            return published
        await frame()
    check(false,"Original equipment boundary cannot publish: "+str({"at_ms":at_ms,"errors":world.presentation_errors,"media":world.media_issue}))
    return false
func samples(world:Node)->Array:
    return Items.samples(world.timeline.item_effect_owners,world.timeline.state,world.timeline.display_ms).filter(func(component):return component.get("dynamic_item_effect",false))
func idle_cut(index:Dictionary,actor:String,begin:float,end:float)->Dictionary:
    # Inspect the original track boundaries and normal resting arbitration.
    # No clip, source frame, equipment row or authoritative clock is replaced.
    var candidates:Array=[begin,end]
    for entry in index.groups:
        candidates.append(float(entry.start_ms)+float(entry.group.duration_ms)+.01)
        for track in entry.group.actor_tracks:
            if track.actor_uuid==actor:candidates.append(float(entry.start_ms)+float(track.start_ms)+float(track.duration_ms)+.01)
    candidates.sort()
    var attempted:Array=[]
    for at in candidates:
        if at<begin or at>end:continue
        var timeline:RefCounted=Recording.restore(index,at)
        var actual:Dictionary=timeline.state.actors.get(actor,{})
        if actual.is_empty():continue
        var rig:Dictionary=Recording.Characters.rigs(index.cache)[Recording.Characters.rig_id(actual,index.cache)]
        var resting:Dictionary=Recording.Characters.rest_sample(actual,rig,index.cache)
        if not resting.ok:continue
        var clip:String=str(timeline.actor_samples().get(actor,{}).get("clip",resting.value.clip))
        attempted.append([at,clip])
        if clip.begins_with("Idle") and not rig.get("pose_sockets",{}).get("hand",{}).get(clip,{}).is_empty():
            return {"ready":true,"at_ms":at,"clip":clip,"attempted":attempted}
    return {"ready":false,"reason":"original_held_interval_has_no_registered_idle_pose","attempted":attempted}
func missing_grip(world:Node,ids:Array,actor:String)->void:
    var native:RefCounted=world.component_renderer.native_spells
    var clip:String=world.playbacks[actor].clip
    var rig:Dictionary=world.rigs[world.visual_actors[actor].row.rig]
    check(clip=="Taunt" and rig.get("pose_sockets",{}).get("hand",{}).get(clip,{}).is_empty(),"Original equip publishes the real Taunt pose with its missing authored weapon grip")
    check(ids.all(func(id):return native.diagnostics.get(id,{}).get("status")=="missing" and native.diagnostics[id].reason=="native_spell_hand_socket_missing"),"Missing Taunt weapon registration remains an exact unavailable diagnostic")
    check(ids.all(func(id):return not native.handles.has(id) or not native.handles[id].root.is_visible_in_tree()),"A pose with no real grip keeps both weapon effects hidden")
    check(world.presentation_errors.is_empty() and not world.publication_failed,"An authored weapon registration gap does not poison ordinary replay publication")
    evidence.append({"cut":"original-taunt-gap","at_ms":world.timeline.display_ms,"clip":clip,"reason":"native_spell_hand_socket_missing"})
func inspect(world:Node,current:Array,clock:float)->Array:
    var native:RefCounted=world.component_renderer.native_spells
    var result:Array=[]
    for component in current:
        check(native.handles.has(component.id),"Each real item/effect/authored use has an actual native occurrence")
        if not native.handles.has(component.id):continue
        var handle:Dictionary=native.handles[component.id]
        result.append(handle)
        var receiving:RefCounted=handle.occurrence.receiving
        var binding:Dictionary=receiving.weapon_binding
        check(receiving.admitted_geometry and binding.item_uuid==Support.ITEM and binding.effect_uuid==Support.EFFECT and binding.holder_uuid==component.actor_uuid,"Prepared source admits the exact original item/effect/current holder")
        check(binding.binding_origin=="observed_item_effect" and binding.contribution_uuid==Support.EFFECT and not binding.has("applied_source_event_cursor"),"Source binding preserves actual contribution and unknown source provenance")
        check(receiving.current_surface.item_uuid==Support.ITEM and receiving.current_surface.actor==component.actor_uuid and receiving.current_surface.points.all(func(point):return point.slot=="weapon"),"Actual modular Mace pixels alone supply the selected receiver")
        check(handle.occurrence.context.phase=="sustain" and is_equal_approx(float(handle.occurrence.context.owner_age_seconds),(world.timeline.display_ms-clock)/1000.0),"Private source uses the original membership clock through equipment intervals")
        check(component.start_ms==clock and component.item_effect_uuid==Support.EFFECT and not component.has("condition_uuid"),"Native component retains the public member without a fabricated condition")
        check(native.witnesses.any(func(witness):return witness.id==component.id+":weapon_surface" and witness.status=="rendered"),"Weapon-surface track has a witness from its actual admitted native draw")
    if result.size()==2:check(result[0].occurrence!=result[1].occurrence,"Two authored uses share immutable art and keep separate native occurrences")
    return result
func pixels(world:Node,view:SubViewport,handles:Array,label:String)->void:
    if handles.size()!=2:return
    await frame();await frame();world.set_process(false)
    var present:Image=view.get_texture().get_image()
    for handle in handles:Effects.hide(handle)
    await frame();await frame()
    var absent:Image=view.get_texture().get_image()
    var changed:int=Support.changed(present,absent)
    check(changed>0,"The two dynamic uses add actual framebuffer pixels: "+label)
    evidence.append({"cut":label,"display_ms":world.timeline.display_ms,"changed_pixels":changed,
        "item_uuid":Support.ITEM,"effect_uuid":Support.EFFECT,"owner_starts":handles.map(func(handle):return handle.component.start_ms),
        "construction":handles.map(func(handle):return handle.construction_phases)})
    DirAccess.make_dir_recursive_absolute("res://.captures/dynamic-weapon-effects")
    present.save_png("res://.captures/dynamic-weapon-effects/"+label+".png")
    for handle in handles:handle.root.show()
    world.set_process(true)
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(800,600)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    var index:Dictionary=Recording.read(Fixtures.journal("divine-arm","party"),{},{},Support.cache())
    check(index.ok,"Original party journal compiles with the shared test-only typed staging")
    if not index.ok:finish();return
    var rows:Array=index.rows.filter(func(row):return row.kind=="native_effect" and row.get("component",{}).get("dynamic_item_effect",false))
    var ids:Dictionary={}
    for row in rows:ids[row.component.id]=true
    check(rows.size()==4 and ids.size()==2,"Two dynamic uses expose both original equipped intervals")
    if rows.size()!=4 or ids.size()!=2:finish();return
    var commits:Dictionary={}
    for entry in index.groups:
        for commit in entry.group.commits:
            if commit.has("event_uuid"):commits[str(commit.event_uuid)]=float(entry.start_ms)+float(commit.at_ms)
    check(["237","239","240"].all(func(id):return commits.has(id)),"Original equip, unequip and re-equip commits remain distinct")
    if not ["237","239","240"].all(func(id):return commits.has(id)):finish();return
    var component:Dictionary=rows[0].component
    var source:Resource=load(Effects.choice(component.native_clip).approaches[0].source_phase)
    var before_source:PackedByteArray=var_to_bytes(source.to_clip())
    var before_recording:PackedByteArray=var_to_bytes([index.initialization,index.groups])
    var view:=SubViewport.new();view.size=Vector2i(800,600);view.own_world_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    var world=Play.new();world.external_playback=true;world.external_clock=true;world.media_warmup.budget_bytes=0
    world.catalog_cache=Play.Catalog.source_snapshot(index.cache);world.playback_end_ms=index.presentation_end_ms
    world.component_renderer.audio.set_enabled(false);view.add_child(world)
    var pre:float=maxf(0.0,commits["237"]-.01)
    world.install_playback(Recording.restore(index,pre))
    if not await settle(world):view.queue_free();await frame();finish();return
    check(samples(world).is_empty(),"Inventory membership does not draw a future equipped weapon")
    if not await advance(world,commits["237"]+.01):view.queue_free();await frame();finish();return
    var current:Array=samples(world)
    check(current.size()==2,"Original positive equipment admission publishes both dynamic uses")
    if current.size()!=2:view.queue_free();await frame();finish();return
    var clock:float=float(current[0].start_ms)
    var actor:String=str(current[0].actor_uuid)
    if not await settle(world):view.queue_free();await frame();finish();return
    missing_grip(world,ids.keys(),actor)
    var first_idle:Dictionary=idle_cut(index,actor,world.timeline.display_ms,commits["239"]-.01)
    check(first_idle.ready,"Original first-held interval contains a registered Idle recovery: "+str(first_idle))
    if not first_idle.ready:view.queue_free();await frame();finish();return
    var epoch:int=world.timeline.initialization_revision
    if not await advance(world,first_idle.at_ms):view.queue_free();await frame();finish();return
    if not await settle(world,ids.keys()):view.queue_free();await frame();finish();return
    check(world.timeline.initialization_revision==epoch and world.playbacks[actor].clip==first_idle.clip,"Ordinary replay recovers from Taunt to its original registered Idle without replacing the epoch or body pose")
    current=samples(world)
    world.camera_focus=Play.Placement.contact(world.visual_actors[actor].row);world.initial_focus=true
    world.camera.size=3.5;world.position_camera();world.grid_visible=false;world.wall_mode="hidden";world.update_wall_visibility()
    var handles:Array=inspect(world,current,clock)
    check(world.visual_actors[actor].entries.any(func(entry):return entry.role!="shadow" and entry.actor_layer.get("item_uuid")==Support.ITEM and entry.actor_layer.slot=="weapon" and entry.node.is_visible_in_tree()),"The real authored modular Mace body remains visible beneath its decoration")
    await pixels(world,view,handles,"first-held")
    if not await advance(world,commits["239"]+.01):view.queue_free();await frame();finish();return
    if not await settle(world):view.queue_free();await frame();finish();return
    check(samples(world).is_empty(),"Original unequip removes eligible optical output without removing membership")
    var native:RefCounted=world.component_renderer.native_spells
    check(ids.keys().all(func(id):return not native.handles.has(id) or not native.handles[id].root.is_visible_in_tree()) and native.witnesses.all(func(witness):return witness.id.trim_suffix(":weapon_surface") not in ids),"Future retained native instances remain hidden while the exact item is unequipped")
    check(ids.keys().all(func(id):return world.timeline.item_effect_owners[id].member_present and world.timeline.item_effect_owners[id].start_ms==clock),"Unequip preserves each actual public membership clock")
    var reequipped:float=minf(index.presentation_end_ms,commits["240"]+.01)
    if not await advance(world,reequipped):view.queue_free();await frame();finish();return
    if not await settle(world):view.queue_free();await frame();finish();return
    var last_idle:Dictionary=idle_cut(index,actor,reequipped,index.presentation_end_ms)
    check(last_idle.ready,"Original re-equipped interval contains registered Idle output: "+str(last_idle))
    if not last_idle.ready:view.queue_free();await frame();finish();return
    var last:float=last_idle.at_ms
    if not await advance(world,last):view.queue_free();await frame();finish();return
    if not await settle(world,ids.keys()):view.queue_free();await frame();finish();return
    handles=inspect(world,samples(world),clock)
    await pixels(world,view,handles,"re-equipped")
    var previous:Array=handles.map(func(handle):return weakref(handle.root))
    world.install_playback(Recording.restore(index,pre))
    if await settle(world):
        check(previous.all(func(reference):return reference.get_ref()==null),"Seeking replaces every old private source occurrence")
        check(samples(world).is_empty(),"Seeking to inventory restores membership without a future weapon draw")
    world.install_playback(Recording.restore(index,last))
    if await settle(world,ids.keys()):
        handles=inspect(world,samples(world),clock)
        await pixels(world,view,handles,"loop-held")
    check(var_to_bytes(source.to_clip())==before_source and var_to_bytes([index.initialization,index.groups])==before_recording,"Drawing, equipment transitions and seek/loop do not mutate authored art or original recording")
    native.close(world)
    check(native.handles.is_empty() and native.groups.is_empty() and native.prepared_layers.is_empty(),"Explicit teardown releases native owners and render passes")
    check(world.presentation_errors.is_empty() and world.media_issue.is_empty(),"Original equipment playback leaves no presentation/resource errors")
    view.queue_free();await frame();await frame();finish()
func finish()->void:
    var report:Dictionary={"checks":checks,"failures":failures,"evidence":evidence,
        "scope":"Original party Devotee membership, actual modular Mace receiving pixels, two private test-authored prepared uses, exact held/unequipped/re-equipped boundaries and source clocks, seek/loop/teardown. No accepted production art, enchantment cast, secondary faction or elemental impact attribution."}
    FileAccess.open("res://.runtime/dynamic-item-effect-render-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("DYNAMIC_ITEM_RENDER ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
