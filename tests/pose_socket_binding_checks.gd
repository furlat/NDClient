extends SceneTree
## Measured source metadata and painted placement contracts only. The native
## creation gate separately qualifies real assembled optical geometry/pixels.
const Sockets=preload("res://presentation/spell_placement.gd")
const Inputs=preload("res://presentation/native_inputs.gd")
const Authoring=preload("res://presentation/authoring.gd")
const Placement=preload("res://placement.gd")
class Playback extends Node:
    var clip:String="Taunt"
    var sample_seconds:float=0.0
class World extends Node:
    var rigs:Dictionary={}
    var rig_config:Dictionary={}
    var playbacks:Dictionary={}
    var visual_actors:Dictionary={}
    var camera:Camera3D
    var quarter:int=0
var checks:int=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("POSE_SOCKET_BINDING_FAIL "+label)

func run()->void:
    var resource:Resource=load("res://authoring/characters/rigs/neuroclient.modular.tres")
    var measured:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/"+resource.measurements))
    check(not measured.pose_sockets.hand.has("Taunt") and measured.pose_sockets.clasped_hands.has("Taunt"),"Taunt explicitly has a measured clasped-hands channel, not a missing mace mesh")
    var equipment:Resource=load("res://authoring/abilities/contexts/equipment.tres")
    check(equipment.body.clip=="Taunt" and equipment.body.playback_speed==3.0,"Actual equipment context explains the temporary pose during Arm")
    var special:Resource=load("res://authoring/characters/gear/weapon.devotees_mace.tres")
    var ordinary:Resource=load("res://authoring/characters/gear/weapon.mace.tres")
    check(special.family==ordinary.id and ordinary.slots.weapon_melee_main.layers[0].part=="Melee9","Existing Devotee mace uses the supplied modular mace family")
    var arm:Resource=load("res://authoring/abilities/actions/action.class.cleric.divine_intervention.arm_thy_servant.tres")
    for effect in arm.effects:
        var endpoint:Dictionary=effect.extra.live_endpoints[0]
        check(endpoint.actor=="caster" and endpoint.socket=="cast_hand" and endpoint.pose_socket_by_clip=={"Taunt":"clasped_hands"},"Each Arm cue owns the explicit measured per-pose attachment")
    var rig={"cell_width":resource.cell.x,"cell_height":resource.cell.y,
        "origin_y_from_ground":resource.cell.y-resource.pivot.y,
        "body_anchor":{"x":resource.anchor.x,"y":resource.anchor.y},
        "pose_sockets":measured.pose_sockets,"facing_rows":{},"clips":{}}
    for index in resource.direction_order.size():rig.facing_rows[resource.direction_order[index]]=index
    for clip in resource.clips:rig.clips[clip.name]={"fps":clip.fps,"frames":clip.frames}
    var world:World=World.new();root.add_child(world)
    world.camera=Camera3D.new();world.add_child(world.camera)
    world.rig_config=Authoring.load_data("catalog/rig.json",{})
    world.rigs[resource.id]=rig
    var playback:Playback=Playback.new();world.add_child(playback);world.playbacks.actual_actor=playback
    var drawn:Node3D=Node3D.new();world.add_child(drawn)
    var row={"id":"actual_actor","rig":resource.id,"position":[10,10],"base_height_steps":2.0,
        "facing":"SW","scale":1.0,"scale_x":1.0}
    # An explicit painted-only fixture exercises attachment math. It contains
    # no source images or substitute depth maps and makes no draw assertion.
    world.visual_actors.actual_actor={"valid":true,"row":row,"entries":[{"role":"body","node":drawn,"actor_layer":{"slot":"body","paths":{}}}]}
    var component={"actor_uuid":"actual_actor","target_uuid":"actual_actor","from_position":[10,10],"to_position":[10,10],
        "from_elevation_feet":10.0,"to_elevation_feet":10.0,"cast_recipe":{"enabled":false},
        "native_cue":{"role":"attached","attachment":"recipient_ground","live_endpoints":arm.effects[0].extra.live_endpoints}}
    var inputs:RefCounted=Inputs.new()
    for quarter in 4:
        world.quarter=quarter
        world.camera.transform=Placement.camera_transform(Vector3.ZERO,quarter)
        for facing in resource.direction_order:
            row.facing=facing
            var view:String=Sockets.facing(world,row)
            var samples:Array=measured.pose_sockets.clasped_hands.Taunt[view]
            check(samples.size()==rig.clips.Taunt.frames and samples.all(func(point):return point!=null),"Complete measured Taunt registration "+view+" quarter"+str(quarter))
            for frame in int(rig.clips.Taunt.frames):
                playback.clip="Taunt";playback.sample_seconds=(float(frame)+.25)/float(rig.clips.Taunt.fps)
                var strict:Dictionary=Sockets.pose_point(world,row,"hand")
                check(not strict.ready and strict.reason=="native_spell_hand_socket_missing","Unmapped Taunt does not invent a main-hand socket")
                var registered:Dictionary=Sockets.pose_point(world,row,"hand",{"Taunt":"clasped_hands"})
                check(registered.ready and registered.pose_socket=="clasped_hands" and registered.frame==frame and registered.facing==view,"Authored selection uses the actual clip/frame/view")
                if not registered.ready:continue
                var point:Dictionary=samples[frame]
                var unit:float=128.0/float(world.rig_config.TILE_W)*row.scale/Placement.PIXELS_PER_UNIT
                var expected:Vector3=Placement.contact(row)+world.camera.basis.x*(float(point.x)-float(rig.cell_width)*.5)*unit \
                    +world.camera.basis.y*(float(rig.cell_height)-float(rig.origin_y_from_ground)-float(point.y))*unit
                check(registered.point.is_equal_approx(expected),"Measured clasped point keeps unchanged painted placement math")
                var preflight:Dictionary=Sockets.endpoints(world,component)
                check(preflight.ready and preflight.hand.is_equal_approx(registered.point),"Hand preflight honors the same explicit pose registration")
                if not preflight.ready:continue
                var packet:Dictionary=inputs.endpoint_packet(world,{"root":drawn},component,preflight,{})
                check(packet.reason.is_empty() and packet.rows[0].socket=="cast_hand" \
                    and packet.rows[0].point.is_equal_approx(preflight.hand),"Native endpoint retains logical cast_hand with the correctly registered point")
    playback.clip="Idle";playback.sample_seconds=0.0
    var idle:Dictionary=Sockets.pose_point(world,row,"hand")
    var selected_idle:Dictionary=Sockets.pose_point(world,row,"hand",{"Taunt":"clasped_hands"})
    check(idle==selected_idle and idle.ready,"Idle's existing hand channel and output metadata remain exactly unchanged")
    var wrong:Dictionary=Sockets.pose_point(world,row,"hand",{"Idle":"not_a_measured_socket"})
    check(not wrong.ready and wrong.reason=="native_spell_not_a_measured_socket_socket_missing","An explicit missing channel never falls through to a generic hand/ground point")
    var mapped_component:Dictionary=component.duplicate(true)
    mapped_component.native_cue.live_endpoints=[{"actor":"target","socket":"body_center","pose_socket":"hand","pose_socket_by_clip":{"Taunt":"clasped_hands"}}]
    playback.clip="Taunt"
    var mapped:Dictionary=Sockets.pose_point(world,row,"hand",{"Taunt":"clasped_hands"})
    var packet:Dictionary=inputs.endpoint_packet(world,{"root":drawn},mapped_component,{},{})
    check(packet.reason.is_empty() and packet.rows[0].point.is_equal_approx(mapped.point),"Other endpoint roles use the same per-clip socket contract")
    inputs.clear();world.queue_free()
    await process_frame
    print(JSON.stringify({"checks":checks,"failures":failures,"scope":"Actual modular socket metadata for Taunt all8views×15frames×4quarters, strict defaults and shared preflight/endpoint conversion; no optical-framebuffer claim"}))
    quit(0 if failures.is_empty() else 1)
