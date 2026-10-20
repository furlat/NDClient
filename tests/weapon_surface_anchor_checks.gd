extends SceneTree
## Real original holdings/loadout; optical vectors are explicit CPU controls.
## The receiving decoration is client test authoring, never a server condition.
const Inputs=preload("res://presentation/native_inputs.gd")
const Weapons=preload("res://presentation/native_weapon_inputs.gd")
const Effects=preload("res://presentation/effect_package.gd")
const Sources=preload("res://presentation/body_sources.gd")
const Characters=preload("res://presentation/characters.gd")
const Authoring=preload("res://presentation/authoring.gd")
const Construction=preload("res://presentation/actor_construction.gd")
const Journal=preload("res://sdk/journal.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
const Builder=preload("res://tools/presentation_build/characters.gd")
const BodyIndex=preload("res://presentation/resources/body_source_index.gd")
const EffectUse=preload("res://presentation/source/effect_use.gd")
const CLIP="conditions/continuation/condition_shillelagh_persistent/sustain"
const FAMILIES=["magic_weapon","divine_favor","sacred_weapon","shillelagh","coating_fire","coating_lightning","coating_poison","flame_blade",
    "elemental_multiattack_shocked_event","elemental_multiattack_prone_event","elemental_multiattack_burning_event","elemental_multiattack_chilled_event",
    "myrmidon_strike_lightning_event","myrmidon_strike_fire_event","myrmidon_strike_cold_event"]
class State extends RefCounted:
    var state:Dictionary={}
    var display_ms:float=1000.0
class Pose extends Node:
    var clip:String="Taunt"
    var sample_seconds:float=0.0
class World extends Node3D:
    var timeline:RefCounted=State.new()
    var visual_actors:Dictionary={}
    var rigs:Dictionary={}
    var rig_config:Dictionary={}
    var playbacks:Dictionary={}
    var camera:Node3D
    var quarter:int=0
    var source_images:Dictionary={}
    var catalog_cache:Dictionary={}
class OpticalVectors extends RefCounted:
    var builds:int=0
    var packets:Dictionary={}
    var available:bool=true
    func sample(_world:Node,actor:String,slots:Array)->Dictionary:
        if not available:return {"actor":actor,"points":[],"ready":false,"reason":"surface_source_preparing","gpu_geometry_key":[]}
        var key:Array=[actor,slots]
        if packets.has(key):return packets[key]
        var points:Array=[];var centre:=Vector3.ZERO
        for y in 3:
            for x in 3:
                var point:=Vector3(3.0+x*.02,1.0+y*.02,7.0)
                points.append({"position":point,"normal":Vector3.BACK,"pixel":Vector2i(x,y),"slot":slots[0]});centre+=point
        var packet:Dictionary={"actor":actor,"actor_uuid":actor,"entity_uuid":actor,"origin":Vector3(3,0,7),"points":points,
            "optical_anchor":centre/float(points.size()),"ready":true,"reason":"","gpu_geometry_key":["optical-vector-control",slots]}
        packets[key]=packet;builds+=1;return packet
    func clear()->void:packets.clear()
var checks:int=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("WEAPON_SURFACE_ANCHOR_FAIL ",label)

static func source_cache()->Dictionary:
    var current:Dictionary=Sources.admission({})
    var selected:Resource=current.index.duplicate(false)
    var staged:Resource=BodyIndex.new();var entries:Dictionary={}
    for spec in [["weapon.devotees_mace","weapon_melee_main","weapon"],["shield.shield","weapon_melee_off","offhand"]]:
        var gear:Resource=load("res://authoring/characters/gear/"+spec[0]+".tres").duplicate(false)
        var cue:Resource=EffectUse.new()
        cue.clip=CLIP;cue.role="sustain";cue.at="owner_start";cue.attachment="recipient_weapon"
        cue.recipient_slots=PackedStringArray([spec[2]]);cue.follow=true;cue.light_multiplier=0.0
        cue.extra={"equipment_slots":[spec[1]]};cue.staging_from="test-only intrinsic exact-surface decoration; no condition, damage or art acceptance"
        gear.effects=gear.effects.duplicate();gear.effects.clear();gear.effects.append(cue);entries[gear.id]=gear
    Builder._equipment({"index":staged},entries)
    selected.item_effects=staged.item_effects
    return {Sources.KEY:{"index":selected,"loaded":current.loaded}}

static func identities(state:Dictionary)->Dictionary:
    for actor in state.actors.values():
        var result:Dictionary={"actor":actor.uuid}
        for item in actor.visual_loadout.layers:
            if item.item_id=="weapon.devotees_mace" and item.slot=="MELEE_MAIN":result.main=item.item_uuid
            if item.item_id=="shield.shield" and item.slot=="MELEE_OFF":result.off=item.item_uuid
        if result.has("main") and result.has("off"):return result
    return {}

func component(actor:String,item:String,slot:String,clip:Dictionary)->Dictionary:
    return {"id":"optical-control:"+item,"actor_uuid":actor,"target_uuid":actor,"native_item":true,"intrinsic_item_effect":true,"start_ms":0.0,
        "item_owner_uuid":item,"source":"test-only intrinsic receiving control","native_inputs":{},"native_clip":clip,
        "native_cue":{"role":"attached","attachment":"recipient_weapon","anchor":slot,"entity_geometry":{"actor":"recipient","slots":[slot]}}}

func run()->void:
    var journal:RefCounted=Journal.new()
    check(journal.open(Fixtures.journal("divine-arm","party"),true,true).ok,"Actual original creation/equipment journal reduces")
    var state:Dictionary=journal.state;var ids:Dictionary=identities(state)
    check(not ids.is_empty(),"Original actual holder has both Devotee Mace and separate offhand shield")
    if ids.is_empty():finish();return
    var immutable:PackedByteArray=var_to_bytes(state)
    var world=World.new();root.add_child(world);world.timeline.state=state
    world.catalog_cache=source_cache();world.rigs=Characters.rigs(world.catalog_cache)
    world.rig_config=Authoring.load_data("catalog/rig.json",world.catalog_cache)
    world.camera=Node3D.new();world.add_child(world.camera)
    var actor:Dictionary=state.actors[ids.actor]
    var resolved:Dictionary=Characters.resolve(actor,state,world.catalog_cache)
    check(resolved.ok,"Actual recorded outfit resolves through existing character authoring")
    if not resolved.ok:world.free();finish();return
    var row:Dictionary=resolved.value;var entries:Array=[]
    for original_layer in row.equipment_layers:
        if original_layer.slot not in ["weapon","offhand"]:continue
        var layer:Dictionary=original_layer.duplicate(false);layer.paths={}
        var node:=MeshInstance3D.new();node.mesh=QuadMesh.new();node.position=Inputs.Sockets.Placement.contact(row);world.add_child(node)
        var shape:Dictionary=Construction.layer_shape(world.rigs[row.rig],128.0/world.rig_config.TILE_W*row.scale)
        node.mesh=Construction.QuadShapes.mesh(shape.mesh_size,shape.mesh_center)
        entries.append({"node":node,"role":"body","actor_layer":layer,"pivot":shape.pivot,"scale":shape.scale})
    world.visual_actors[ids.actor]={"valid":true,"row":row,"entries":entries}
    var pose=Pose.new();world.add_child(pose);world.playbacks[ids.actor]=pose
    check(world.rigs[row.rig].pose_sockets.hand.get("Taunt",{}).is_empty(),"Real authored Taunt has no hand grip; none is manufactured")
    var bridge:RefCounted=Inputs.new();var vectors=OpticalVectors.new();bridge.surfaces=vectors
    var handles:Array=[]
    Effects._ensure_clock()
    for family in FAMILIES:
        var key:String="condition_"+family+("" if family.ends_with("_event") else "_persistent")
        for phase in ["application","sustain","removal"]:
            var clip:Dictionary=Effects.clip("conditions/continuation/"+key+"/"+phase)
            var source:Node3D=load(Effects.choice(clip).approaches[0].path).make_component({})
            var handle:Dictionary={"clip":clip,"occurrence":source}
            check(Inputs.measured_weapon_source(handle),key+"/"+phase+": actual constructor declares measured or FlameBlade receiving")
            source.free()
    for spec in [["main","weapon"],["off","offhand"]]:
        var clip:Dictionary=Effects.clip(CLIP)
        var source:Node3D=load(Effects.choice(clip).approaches[0].path).make_component({"layer_mask":0})
        world.add_child(source)
        var handle:Dictionary={"clip":clip,"occurrence":source,"root":source}
        var cue:Dictionary=component(ids.actor,ids[spec[0]],spec[1],clip)
        var registration:Dictionary=bridge.weapon_registration(world,handle,cue)
        check(registration.ready and registration.measured and not registration.hand.ready,"Prepared "+spec[0]+" missing-grip uses only its actual measured surface")
        check(registration.optical_anchor==Vector3(3.02,1.02,7.0) or registration.optical_anchor.is_equal_approx(Vector3(3.02,1.02,7.0)),"Cached support centroid is the named optical anchor")
        check(not registration.packet.binding.has("hand") and registration.packet.binding.item_uuid==ids[spec[0]],"Actual item binding has no fabricated hand field")
        var points:Dictionary=Inputs.Sockets.endpoints(world,cue,{},true,registration)
        check(points.ready and points.optical_anchor==registration.optical_anchor and not points.has("hand"),"Placement keeps optical anchor separate from missing authored grip")
        var before:int=vectors.builds
        var result:Dictionary=bridge.sync(world,handle,cue,points)
        check(result.unavailable.is_empty() and source.receiving.admitted_geometry,"Prepared source admits exact current item/slot without grip or legacy contribution flags")
        check(vectors.builds==before and source.receiving.current_surface.item_uuid==ids[spec[0]],"Sync reuses the exact cached packet selected before placement")
        check(source.receiving.current_surface.points.all(func(point):return point.slot==spec[1]),"Main/offhand optical supports never borrow one another or the body")
        vectors.available=false
        var waiting:Dictionary=bridge.weapon_registration(world,handle,cue)
        check(waiting.packet.ready and not waiting.ready and waiting.pending and not waiting.has("optical_anchor"),"Identity admission alone cannot place a source while its actual optical surface is pending")
        check(not Inputs.Sockets.endpoints(world,cue,{},true,waiting).ready,"Placement rejects the complete pending registration even when the item packet is ready")
        vectors.available=true
        var grip:Dictionary=cue.duplicate(true);grip.native_cue.live_endpoints=[{"actor":"caster","socket":"hand"}]
        check(not bridge.weapon_registration(world,handle,grip).ready,"An explicitly authored grip requirement is not erased by prepared surface support")
        var legacy:Dictionary=handle.duplicate();legacy.clip=Effects.clip("bg3-36/magic-weapon/magic_weapon_native/sustain")
        check(not Inputs.measured_weapon_source(legacy) and not bridge.weapon_registration(world,legacy,cue).ready,"Legacy hand/contribution contract cannot borrow prepared support policy")
        handles.append(handle)
    pose.clip="Idle"
    var main:Dictionary=component(ids.actor,ids.main,"weapon",Effects.clip(CLIP))
    var hand:Dictionary=Inputs.Sockets.pose_point(world,row,"hand")
    check(hand.ready,"Actual authored Idle still has its real painted grip")
    var known:Dictionary=bridge.weapon_registration(world,handles[0],main)
    var old:Dictionary=Inputs.Sockets.endpoints(world,main)
    var preserved:Dictionary=Inputs.Sockets.endpoints(world,main,{},true,known)
    check(known.ready and known.packet.binding.hand==hand.point and not known.has("optical_anchor"),"Existing authored hand remains exact, never replaced by a centroid")
    check([old.from,old.hand,old.to,old.ground,old.caster_ground]==[preserved.from,preserved.hand,preserved.to,preserved.ground,preserved.caster_ground],"Known-grip placement tuple is byte-equivalent to the unchanged path")
    # Restore the exact admitted source paths while withholding their CPU
    # images. This is a real known-grip preparation boundary, not authoring
    # absence; an already ready weapon support must not replace that hand.
    for entry in world.visual_actors[ids.actor].entries:
        var metadata:Resource=Sources.prepare_layer(entry.actor_layer.source_path,world.catalog_cache)
        entry.actor_layer.paths=metadata.paths_by_slot[entry.actor_layer.slot]
    var pending:Dictionary=bridge.weapon_registration(world,handles[0],main)
    check(not pending.ready and pending.get("pending",false) and pending.hand.get("pending",false),"Known grip with unprepared actual source images retains its original preparation wait")
    check(not pending.has("optical_anchor") and not pending.packet.ready,"Ready measured vectors cannot temporarily replace a still-preparing authored grip")
    check(var_to_bytes(state)==immutable,"All original public state, inventory, loadout and effect membership remain unchanged")
    for handle in handles:handle.occurrence.free()
    world.free();finish()

func finish()->void:
    print("WEAPON_SURFACE_ANCHOR ",JSON.stringify({"checks":checks,"failures":failures,
        "scope":"Original item/loadout identity plus explicit optical CPU controls and sealed prepared source admission. Shield is an offhand geometry control, not a recorded weapon-coating action; pixels/real offhand weapon scenario/art approval remain separate."}))
    quit(0 if failures.is_empty() else 1)
