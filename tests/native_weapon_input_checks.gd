extends SceneTree
## Public item/loadout and displayed source identity -> actual Factory setters.
## Native framebuffer output, real server ownership publication and timing are
## separate qualification gates, never inferred from these headless checks.
const Weapons=preload("res://presentation/native_weapon_inputs.gd")
const Inputs=preload("res://presentation/native_inputs.gd")
const Effects=preload("res://presentation/effect_package.gd")
const Construction=preload("res://presentation/actor_construction.gd")
class State extends RefCounted:
    var state:Dictionary={"actors":{},"items":{}}
class World extends Node3D:
    var timeline:RefCounted=State.new()
    var visual_actors:Dictionary={}
    var rigs:Dictionary={"shared-knight":{"cell_width":128,"cell_height":128,"origin_y_from_ground":32,"facing_rows":{"SW":0},
        "clips":{"Idle":{"fps":1.0,"frames":1}},"pose_sockets":{"hand":{"Idle":{"SW":[Vector2(72,64)]}}}}}
    var rig_config:Dictionary={"TILE_W":128,"FACING_CYCLE":["E","SE","S","SW","W","NW","N","NE"]}
    var playbacks:Dictionary={}
    var camera:Node3D
    var quarter:int=0
    var source_images:Dictionary={}
    var catalog_cache:Dictionary={}
class OpticalSources extends RefCounted:
    var revision:int=0
    var selected:Array=[]
    var interests:Array=[]
    func sample(world:Node,actor:String,slots:Array)->Dictionary:
        selected=[actor,slots]
        var origin:Vector3=world.visual_actors[actor].entries[0].node.global_position
        var points:Array=[]
        for y in 3:
            for x in 3:points.append({"position":origin+Vector3(x*.02,1+y*.02,0),"normal":Vector3.BACK,"pixel":Vector2i(x,y),"slot":slots[0]})
        return {"actor":actor,"actor_uuid":actor,"entity_uuid":actor,"origin":origin,"optical_anchor":origin,"points":points,"ready":true,"reason":"","gpu_geometry_key":["one-shared-physical-sheet",revision]}
    func prepare(_world:Node,actors:Array,slots:Array,priority:bool)->void:interests.append([actors,slots,priority])
    func clear()->void:pass
var checks:int=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr("WEAPON_INPUT_FAIL "+label)
func add_actor(world:World,id:String,item:String,x:int)->void:
    var node=MeshInstance3D.new();node.mesh=QuadMesh.new();node.position=Vector3(x,0,0);world.add_child(node)
    var row:Dictionary={"id":id,"rig":"shared-knight","position":[x,0],"base_height_steps":0,"scale":1.0,"facing":"SW"}
    var shape:Dictionary=Construction.layer_shape(world.rigs[row.rig],128.0/float(world.rig_config.TILE_W)*row.scale)
    node.mesh=Construction.QuadShapes.mesh(shape.mesh_size,shape.mesh_center);node.basis=world.camera.basis;node.position=Inputs.Sockets.Placement.contact(row)
    var entry={"id":id+":weapon","node":node,"role":"body","pivot":shape.pivot,"scale":shape.scale,"actor_layer":{"slot":"weapon","item_uuid":item,"paths":{},"effect":{}},"texture_path":"same-knight-weapon-sheet"}
    world.visual_actors[id]={"valid":true,"entries":[entry],"row":row}
    world.timeline.state.actors[id]={"uuid":id,"present":true,"visual_loadout":{"active_weapon_set":"melee","layers":[{"slot":"MELEE_MAIN","item_uuid":item,"item_id":"weapon.club"}]}}
    world.timeline.state.items[item]={"item_uuid":item,"look":{"item_id":"weapon.club"},"effects":[]}
func component(actor:String,item:Variant,clip:Dictionary)->Dictionary:
    return {"actor_uuid":actor,"target_uuid":actor,"condition_uuid":"condition-owned-by-"+actor,"condition":{"condition_uuid":"condition-owned-by-"+actor,"state":{"affected_item_uuid":item}},
        "persistent_owner":true,"lifecycle_phases":{},"native_clip":clip,"native_cue":{"role":"attached","attachment":"recipient_weapon","anchor":"weapon","launch":0.0,"contact":0.0},
        "native_inputs":{}}
func run()->void:
    var world=World.new();root.add_child(world);world.camera=Node3D.new();world.add_child(world.camera)
    add_actor(world,"a","item-a",0);add_actor(world,"b","item-b",3)
    var clip:Dictionary=Effects.clip("conditions/continuation/condition_shillelagh_persistent/application")
    var a:Dictionary=component("a","item-a",clip)
    var original:Dictionary=world.timeline.state.duplicate(true)
    var resolved:Dictionary=Weapons.resolve(world,a)
    check(resolved.ready and resolved.binding.item_uuid=="item-a" and resolved.binding.holder_uuid=="a" and resolved.binding.equipment_slot=="MELEE_MAIN","Affected item binds exact UUID, holder and canonical equipment slot")
    check(resolved.slots==["weapon"] and resolved.binding.render_slot=="weapon","Declared weapon registration selects its exact optical channel")
    check(not resolved.binding.suppressed and resolved.public_gaps==["contribution_active","decoration_admitted"],"Schema16 has no retired Antimagic gate; legacy-only admission operands remain separate")
    var b:Dictionary=component("b","item-b",clip)
    var other:Dictionary=Weapons.resolve(world,b)
    check(other.binding.item_uuid=="item-b" and other.binding.holder_uuid=="b","Actors sharing one rig keep independent item and holder identities")
    var wrong:Dictionary=component("a","item-b",clip)
    check(not Weapons.resolve(world,wrong).ready,"Actor-owned condition cannot coat another holder's weapon")
    var unknown:Dictionary=a.duplicate(true);unknown.condition.state.affected_item_uuid="not-disclosed"
    check(not Weapons.resolve(world,unknown).ready,"Unknown item cannot borrow the current main weapon")
    var item_target:Dictionary=component("a",null,clip);item_target.target_uuid="item-b";item_target.native_cue.entity_geometry={"actor":"caster","slots":["weapon"]}
    check(not Weapons.resolve(world,item_target).ready,"An exact native item target cannot be replaced by authored fixture caster geometry")
    var no_owner:Dictionary=a.duplicate(true);no_owner.erase("condition_uuid");no_owner.condition.erase("condition_uuid")
    check(Weapons.resolve(world,no_owner).reason=="weapon_effect_identity_not_disclosed","Missing condition/effect membership is explicit, not a fabricated lifetime")
    var favor:Dictionary=component("a",null,clip)
    check(Weapons.resolve(world,favor).binding.item_uuid=="item-a","Actor-owned coating uses authored current render slot rather than a guessed first item")
    var off=MeshInstance3D.new();off.mesh=QuadMesh.new();world.add_child(off)
    var off_shape:Dictionary=Construction.layer_shape(world.rigs[world.visual_actors.a.row.rig],128.0/float(world.rig_config.TILE_W)*world.visual_actors.a.row.scale)
    off.mesh=Construction.QuadShapes.mesh(off_shape.mesh_size,off_shape.mesh_center);off.basis=world.camera.basis;off.position=Inputs.Sockets.Placement.contact(world.visual_actors.a.row)
    world.visual_actors.a.entries.append({"id":"a:offhand","node":off,"role":"body","pivot":off_shape.pivot,"scale":off_shape.scale,"actor_layer":{"slot":"offhand","item_uuid":"offhand-a","paths":{},"effect":{}}})
    world.timeline.state.actors.a.visual_loadout.layers.append({"slot":"MELEE_OFF","item_uuid":"offhand-a","item_id":"weapon.dagger"})
    world.timeline.state.items["offhand-a"]={"item_uuid":"offhand-a","look":{"item_id":"weapon.dagger"},"effects":[]}
    var ambiguous:Dictionary=favor.duplicate(true);ambiguous.native_cue.entity_geometry={"slots":["weapon","offhand"]}
    check(Weapons.resolve(world,ambiguous).reason=="weapon_binding_ambiguous","Multiple authored eligible slots remain ambiguous instead of selecting the first weapon")
    var offhand:Dictionary=component("a","offhand-a",clip);offhand.native_cue.anchor="offhand"
    check(Weapons.resolve(world,offhand).binding.equipment_slot=="MELEE_OFF","Explicit offhand retains its own canonical item/slot")
    check(Inputs.Sockets.endpoints(world,offhand).reason=="weapon_offhand_socket_not_authored","Absent offhand hand registration remains explicit rather than borrowing the main hand")
    var ownership:RefCounted=load("res://assets/vfx/sources/6ee57b6fb1e6037a0826/ownership.gd").new()
    ownership.configure({"owner_kind":"caster","owner_uuid":"a","effect_uuid":a.condition_uuid})
    check(ownership.bind(resolved.binding) and not ownership.visible(),"Legacy consumer does not turn physical setter admission into an active contribution")
    var complete:Dictionary=resolved.binding.duplicate();complete.contribution_active=true;complete.decoration_admitted=true
    check(ownership.bind(complete) and ownership.visible(),"Explicitly supplied contribution fields preserve the actual owner/item relation")
    var fixture_owner:RefCounted=load("res://assets/vfx/sources/6ee57b6fb1e6037a0826/ownership.gd").new()
    fixture_owner.configure({"owner_kind":"caster","owner_uuid":"factory-fixture-owner","effect_uuid":"factory-fixture-effect"})
    check(not fixture_owner.bind(complete) and not fixture_owner.visible(),"A fixture-bound constructor still rejects actual production identity; provider success is not visible integration")
    var bridge:RefCounted=Inputs.new();var optical:OpticalSources=OpticalSources.new();bridge.surfaces=optical
    bridge.prepare(world,[a])
    check(optical.interests==[[["a"],["weapon"],true]],"Early preparation requests only the exact holder and weapon slot")
    var placed:Dictionary=Inputs.Sockets.endpoints(world,a)
    check(placed.ready and placed.item_uuid=="item-a" and placed.holder_uuid=="a" and placed.to==placed.hand,"Recipient weapon registration uses the actual holder's pose hand")
    Effects._ensure_clock()
    var source_nodes:Array=world.visual_actors.a.entries.map(func(entry):return entry.node)
    var children_before:int=world.get_child_count()
    var handles:Array=[]
    for family in ["condition_magic_weapon_persistent","condition_divine_favor_persistent","condition_sacred_weapon_persistent","condition_shillelagh_persistent"]:
        var source:Script=load("res://assets/vfx/conditions/"+family+"/application.gd")
        var occurrence:Node3D=source.make_component({"layer_mask":0});world.add_child(occurrence)
        var handle={"clip":Effects.clip("conditions/continuation/"+family+"/application"),"occurrence":occurrence,"root":occurrence}
        var current:Dictionary=a.duplicate(true);current.native_clip=handle.clip
        var status:Dictionary=bridge.sync(world,handle,current,placed)
        check(status.unavailable.is_empty() and occurrence.receiving.admitted_geometry,family+": actual prepared setter accepts exact equipped weapon surface")
        check(occurrence.receiving.current_surface.item_uuid=="item-a" and occurrence.receiving.current_surface.equipment_slot=="MELEE_MAIN",family+": surface retains exact item/slot identity")
        check(occurrence.receiving.current_surface.points.all(func(point):return point.slot=="weapon"),family+": no body support is substituted for weapon pixels")
        var uploads:int=occurrence.receiving.uploads
        bridge.sync(world,handle,current,placed)
        check(occurrence.receiving.uploads==uploads,family+": unchanged source/ownership avoids receiver rebuild/upload")
        handles.append(handle)
    var handle:Dictionary=handles[-1];var occurrence:Node3D=handle.occurrence
    var held:Array=world.timeline.state.actors.a.visual_loadout.layers
    world.timeline.state.actors.a.visual_loadout.layers=[]
    var status:Dictionary=bridge.sync(world,handle,a,placed)
    check(status.unavailable.weapon_binding=="exact_weapon_not_currently_displayed" and not occurrence.receiving.admitted_geometry,"Unequip clears the old Factory coating and reports unavailable binding")
    world.timeline.state.actors.a.visual_loadout.layers=held
    bridge.sync(world,handle,a,placed)
    check(occurrence.receiving.admitted_geometry,"Restoring the exact item restores only its own receiver")
    var suppressed:Dictionary=a.duplicate(true);suppressed.native_inputs={"weapon_binding":{"suppressed":true}}
    bridge.sync(world,handle,suppressed,placed)
    check(not occurrence.receiving.admitted_geometry,"Actual disclosed suppression clears coating without altering the physical source")
    var unsuppressed:Dictionary=a.duplicate(true);unsuppressed.native_inputs={"weapon_binding":{"suppressed":false}}
    bridge.sync(world,handle,unsuppressed,placed)
    check(occurrence.receiving.admitted_geometry,"An explicit unsuppressed override restores the same exact item")
    var missing_suppression:Dictionary=a.duplicate(true);missing_suppression.native_inputs={}
    status=bridge.sync(world,handle,missing_suppression,placed)
    check(status.unavailable.is_empty() and occurrence.receiving.admitted_geometry and not occurrence.receiving.weapon_binding.suppressed,"Prepared effects need no retired suppression field or legacy contribution/decoration operands")
    bridge.sync(world,handle,a,placed)
    var uploads:int=occurrence.receiving.uploads
    world.visual_actors.a.entries[0].node.position+=Vector3.RIGHT
    world.visual_actors.a.row.position=[1,0];occurrence.position+=Vector3.RIGHT
    placed=Inputs.Sockets.endpoints(world,a)
    bridge.sync(world,handle,a,placed)
    check(occurrence.receiving.uploads==uploads,"Co-moving prepared item/owner retains its receiver-relative optical upload")
    optical.revision+=1
    bridge.sync(world,handle,a,placed)
    check(occurrence.receiving.weapon_binding.get("hand")==placed.hand,"A new pose refreshes the actual world hand before rebuilding its optical table")
    var b_handle:Dictionary=handles[0];var b_placed:Dictionary=Inputs.Sockets.endpoints(world,b)
    bridge.sync(world,b_handle,b,b_placed)
    check(b_handle.occurrence.receiving.current_surface.actor=="b" and b_handle.occurrence.receiving.current_surface.item_uuid=="item-b","Shared source pose cannot borrow another recipient's private weapon packet")
    check(handle.occurrence.receiving.current_surface.item_uuid=="item-a","Updating the second recipient does not mutate the first recipient")
    check(world.timeline.state.items["item-a"]==original.items["item-a"] and a.condition.state.affected_item_uuid=="item-a","Provider/setter flow leaves canonical item and condition identity unchanged")
    equipped_contract(world,bridge,a,offhand)
    for value in handles:value.occurrence.free()
    check(world.get_child_count()==children_before and source_nodes.all(func(node):return is_instance_valid(node) and node.visible),"Removing all coating owners frees private effects and retains the actual physical weapon layers")
    world.free();await process_frame
    print(JSON.stringify({"checks":checks,"failures":failures,"scope":"Actual current item/loadout identity and Factory setter admission/restoration; no native output or undeclared gameplay ownership claim"}))
    quit(0 if failures.is_empty() else 1)

func equipped_contract(world:World,bridge:RefCounted,current:Dictionary,offhand:Dictionary)->void:
    # This headless contract never installs the known-stale receiver program.
    # Blank material owners exercise packet routing without claiming pixels.
    for visual in world.visual_actors.values():
        for entry in visual.entries:entry.material=ShaderMaterial.new()
    var clip:Dictionary=Effects.clip("weapons/equipped/fire/ember_sheath/medium/sustain")
    check(not Effects.choice(clip).approaches[0].get("condition_prepared",false),"Delivered equipped source does not borrow the prepared-condition flag")
    var handle:Dictionary=Effects.make(world,clip,0)
    check(handle.error.is_empty(),"Actual packaged equipped occurrence constructs: "+str(handle.error))
    if not handle.error.is_empty():Effects.close(handle);return
    check(Weapons.equipped_source(handle),"Instantiated public equipped_weapon component selects its own admission contract")
    var source:Node3D=handle.occurrence.handle.components.equipped_weapon
    var registration:Dictionary=bridge.weapon_registration(world,handle,current)
    var placed:Dictionary=Inputs.Sockets.endpoints(world,current,{},true,registration)
    placed.erase("weapon_registration") # Later controls use their own current membership.
    var result:Dictionary=bridge.sync(world,handle,current,placed)
    check(not result.unavailable.has("weapon_binding") and source._binding_valid(),"Exact actual member is admitted without unused legacy contribution/decoration fields")
    check(result.weapon_public_gaps.is_empty(),"Equipped contract does not report unused legacy operands as missing public facts")
    check(not source.binding.has("contribution_active") and not source.binding.has("decoration_admitted"),"Adapter fabricates no legacy gameplay operands")
    var hands:Dictionary=world.rigs["shared-knight"].pose_sockets.hand
    world.rigs["shared-knight"].pose_sockets.hand={}
    registration=bridge.weapon_registration(world,handle,current)
    check(registration.ready and registration.has("optical_anchor") and not registration.packet.binding.has("hand"),"Equipped source can use the exact optical registration without inventing a grip or axis")
    var explicit_grip:Dictionary=current.duplicate(true)
    explicit_grip.native_cue.live_endpoints=[{"actor":"caster","socket":"hand"}]
    check(not bridge.weapon_registration(world,handle,explicit_grip).ready,"An explicitly authored grip remains required")
    check(not bridge.weapon_registration(world,handle,offhand).ready,"New main-hand contract cannot admit the unsupported offhand")
    world.rigs["shared-knight"].pose_sockets.hand=hands
    var hidden:Dictionary=current.duplicate(true);hidden.native_inputs={"weapon_binding":{"suppressed":true}}
    bridge.sync(world,handle,hidden,placed)
    check(not source._binding_valid(),"Real suppression is still delivered to source admission")
    bridge.sync(world,handle,current,placed)
    check(source._binding_valid(),"Clearing actual suppression restores only the exact member")
    var bad:Dictionary=source.binding.duplicate();bad.item_uuid="other-item"
    source.set_weapon_binding(bad)
    check(not source._receiver_identity_valid(),"A different item cannot retain the original exact optical receiver")
    var item:Dictionary=current.duplicate(true)
    item.native_item=true;item.intrinsic_item_effect=true;item.item_owner_uuid="item-a"
    item.source="res://authoring/characters/gear/weapon.roster.ember_longsword.tres::effects/0"
    item.start_ms=0.0;item.age_ms=42000.0
    handle.started=false;handle.weapon_source_age=Weapons.source_time(handle,42.0)
    bridge.sync(world,handle,item,placed);Effects.sample(handle,handle.weapon_source_age)
    check(source.owner_state.owner_age_seconds==42.0 and source.owner_state.source_age_seconds==0.0 \
        and handle.occurrence.previous_age==0.0,"Cold optical admission preserves actual membership age and starts no invented earlier motion")
    handle.started=true;item.age_ms=42016.0
    handle.weapon_source_age=Weapons.source_time(handle,42.016)
    bridge.sync(world,handle,item,placed);Effects.sample(handle,handle.weapon_source_age)
    check(is_equal_approx(source.owner_state.owner_age_seconds,42.016) and is_equal_approx(source.owner_state.source_age_seconds,.016) \
        and is_equal_approx(handle.occurrence.previous_age,.016),"Observed pose advances component and occurrence on the same private source clock")
    check(not Weapons.equipped_source({"baked":true}) and not Weapons.equipped_source({"inner":{"components":{}}}),"Recorded and unrelated sources cannot acquire the equipped history policy")
    Effects.close(handle)
