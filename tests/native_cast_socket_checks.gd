extends SceneTree
## Imported typed BodyUse poses resolve the admitted rig's actual hand channel.
const Sockets=preload("res://presentation/spell_placement.gd")
const Characters=preload("res://presentation/characters.gd")
const Records=preload("res://tools/presentation_build/ability_records.gd")
const Native=preload("res://presentation/native_spell_renderer.gd")
const Timeline=preload("res://presentation/timeline.gd")
class Lighting extends RefCounted:
    var native_preparation_ready:bool=true
    func sample_handles(_handles:Dictionary)->void:pass
class Playback extends Node:
    var clip:String="Attack5"
    var sample_seconds:float=0.0
class World extends Node3D:
    var visual_actors:Dictionary={}
    var rigs:Dictionary={}
    var rig_config:Dictionary={"TILE_W":128,"FACING_CYCLE":["E","SE","S","SW","W","NW","N","NE"]}
    var playbacks:Dictionary={}
    var camera:Camera3D
    var quarter:int=0
    var source_images:Dictionary={}
    var catalog_cache:Dictionary={}
    var character_light_profile:String="reference"
    var profile:Dictionary={"phases":{}}
    var timeline:RefCounted=Timeline.new()
    var source_lighting:Lighting=Lighting.new()
    func _facing(_direction:Vector2)->String:return "SW"
var checks:int=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("CAST_SOCKET_FAIL "+label)
func projected(world:World,point:Variant)->Vector3:
    var row:Dictionary=world.visual_actors.caster.row
    var rig:Dictionary=world.rigs[row.rig]
    var unit:float=128.0/float(world.rig_config.TILE_W)*row.scale/Sockets.Placement.PIXELS_PER_UNIT
    return Sockets.Placement.contact(row)+world.camera.basis.x*(point.x-rig.cell_width*.5)*unit*row.get("scale_x",1.0)+world.camera.basis.y*(rig.cell_height-rig.origin_y_from_ground-point.y)*unit
func component(recipe:Dictionary)->Dictionary:
    return {"id":"cast","kind":"native_effect","native_spell":true,"actor_uuid":"caster","target_uuid":null,"age_ms":0.0,
        "from_position":[3,4],"to_position":[3,4],"from_elevation_feet":10.0,"to_elevation_feet":10.0,
        "cast_recipe":recipe.cast,"recipe":recipe.get("projectile",{}),
        "native_cue":{"role":"attached","attachment":"caster_ground","launch":1.0,"live_endpoints":[{"actor":"caster","socket":"cast_hand"}]}}
func run()->void:
    var world:World=World.new();root.add_child(world)
    world.camera=Camera3D.new();world.add_child(world.camera)
    world.rigs=Characters.rigs(world.catalog_cache)
    var rig_id:String="neuroclient.modular"
    check(world.rigs.has(rig_id),"Test uses the actual shipping modular rig")
    if not world.rigs.has(rig_id):finish(world);return
    var rig:Dictionary=world.rigs[rig_id]
    var mesh:MeshInstance3D=MeshInstance3D.new();mesh.mesh=QuadMesh.new();world.add_child(mesh)
    var entry:Dictionary={"id":"caster:body","node":mesh,"role":"body","actor_layer":{"slot":"body","effect":{},"paths":{}}}
    world.visual_actors.caster={"valid":true,"row":{"id":"caster","rig":rig_id,"position":[3,4],"base_height_steps":2.0,"scale":1.0,"facing":"SW"},"entries":[entry]}
    var body:Playback=Playback.new();world.add_child(body);world.playbacks.caster=body
    var current:Dictionary={}
    for id in ["acid_arrow","aid","animal_friendship","arcane_sword"]:
        var spell:Resource=load("res://authoring/abilities/spells/spell."+id+".tres")
        var recipe:Dictionary=Records.spell_recipe(spell,{})
        current=component(recipe)
        var frame:int=int(recipe.cast.releaseFrame)
        var view:String="SW"
        var expected:Variant=rig.pose_sockets.hand[recipe.cast.actionClip][view][frame]
        var release:Dictionary=Sockets.cast_point(world,current,"release",frame,view)
        check(release.ready and release.point.is_equal_approx(projected(world,expected)),id+": real BodyUse release frame selects its authored rig hand")
        body.clip=recipe.cast.actionClip
        body.sample_seconds=2.0/float(rig.clips[body.clip].fps)
        var points:Dictionary=Sockets.endpoints(world,current)
        var prepare:Variant=rig.pose_sockets.hand[body.clip][view][2]
        check(points.ready and points.hand.is_equal_approx(projected(world,prepare)) and points.from.is_equal_approx(release.point),id+": preparation follows the current body frame while release remains fixed")
    for view in rig.facing_rows:
        world.visual_actors.caster.row.facing=view
        var release:Dictionary=Sockets.cast_point(world,current,"release",7,view)
        check(release.ready and release.point.is_equal_approx(projected(world,rig.pose_sockets.hand.Attack5[view][7])),"Exact measured casting view "+view)
    world.visual_actors.caster.row.facing="SW"
    world.quarter=1
    var rotated:Dictionary=Sockets.endpoints(world,current,{},false)
    var rotated_view:String=Sockets.facing(world,world.visual_actors.caster.row)
    check(rotated.ready and rotated.from.is_equal_approx(projected(world,rig.pose_sockets.hand.Attack5[rotated_view][7])),"Camera rotation selects the actual pose's corresponding view")
    world.quarter=0
    current.recipe={"sourceSockets":{"release":{"SW":{"x":36.0,"y":45.0}}}}
    var explicit:Dictionary=Sockets.cast_point(world,current,"release",7,"SW")
    check(explicit.ready and explicit.point.is_equal_approx(projected(world,Vector2(36,45))),"Explicit measured spell socket retains precedence over the rig hand")
    current.recipe={"sourceSockets":{"sources":["hand","face"]}}
    var pair:Dictionary=Sockets.cast_point(world,current,"release",7,"SW")
    var mean:Vector3=(projected(world,rig.pose_sockets.hand.Attack5.SW[7])+projected(world,rig.pose_sockets.face.Attack5.SW[7]))*.5
    check(pair.ready and pair.point.is_equal_approx(mean),"Explicit multiple authored sockets preserve their exact mean")
    current.recipe={"sourceSockets":{"release":{"SW":[{"x":36.0,"y":45.0}]}}}
    var short:Dictionary=Sockets.cast_point(world,current,"release",7,"SW")
    check(not short.ready and not short.get("pending",false) and short.reason=="native_spell_release_socket_missing","A short explicit registration is a permanent missing cue, never an Array treated as a point")
    current.recipe={"sourceSocketsByRig":{"other-rig":{"sources":["hand"]}}}
    var other:Dictionary=Sockets.cast_point(world,current,"release",7,"SW")
    check(not other.ready and not other.get("pending",false),"An explicit registration for a different rig cannot silently borrow the default hand")
    current.recipe={}
    var missing:Dictionary=Sockets.cast_point(world,current,"release",999,"SW")
    check(not missing.ready and not missing.get("pending",false),"A missing authored release frame cannot become an endless preparation wait")
    var native:RefCounted=Native.new()
    native._owner=world;native._epoch=0
    native.groups[Native._profile_key({})]={"layer_mask":2}
    current.recipe={"sourceSockets":{}}
    native.handles.cast={"root":mesh,"component":current,"endpoint_views":{}}
    native.sample(world,[current],1.0/60.0)
    check(native.ready and native.issues.size()==1 and not mesh.visible,"A permanent unsupported cue is diagnosed and hidden without holding the authoritative clock")
    current.recipe={};mesh.show();entry.actor_layer.paths.Attack5="res://not-admitted-cast-image.png"
    native.sample(world,[current],1.0/60.0)
    check(not native.ready and native.issues.is_empty() and native.diagnostics.cast.status=="pending","An actually unprepared admitted socket image still holds presentation readiness")
    var item_spell:Resource=load("res://authoring/abilities/spells/spell.continual_flame.tres")
    var item_cue:Dictionary=Records.cue_from_effect(item_spell.effects[0],0)
    current.native_cue=item_cue
    current.native_cue.launch=1.0
    var item_points:Dictionary=Sockets.endpoints(world,current)
    check(item_cue.attachment=="item" and not item_points.ready and item_points.unavailable and item_points.reason=="native_item_registration_not_bound","An actual item-attached source explicitly requires item registration instead of falling through to a body point")
    mesh.show();native.sample(world,[current],1.0/60.0)
    check(native.ready and not mesh.visible and native.issues.is_empty() and native.diagnostics.cast.status=="missing" and native.diagnostics.cast.reason=="native_item_registration_not_bound","Missing item placement stays explicitly missing without per-frame errors or holding canonical state")
    native.handles={};native.groups={};native._owner=null
    finish(world)
func finish(world:World)->void:
    world.free()
    print(JSON.stringify({"checks":checks,"failures":failures,"scope":"Typed imported cast poses, actual shipping rig sockets, explicit registration precedence and permanent/pending readiness"}))
    quit(0 if failures.is_empty() else 1)
