extends SceneTree
## Presentation overlays must not intercept actual actor/object/floor clicks.
## Uses the real blood entry creator; no server, source rendering or FPS claim.
const Blood=preload("res://presentation/blood_renderer.gd")
var checks=0
var failures:Array=[]

class PickingPlayer extends "res://play.gd":
    func _ready()->void:
        add_child(context_menu)
        set_process(false)

func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("EFFECT_PICK_FAIL ",label)

func point(world:Node,entry:Dictionary,uv:Vector2)->Vector2:
    var mesh:QuadMesh=entry.node.mesh
    var local=mesh.center_offset+Vector3((uv.x-.5)*mesh.size.x,(.5-uv.y)*mesh.size.y,0)
    return world.camera.unproject_position(entry.node.global_transform*local)

func _initialize()->void:run.call_deferred()
func run()->void:
    root.size=Vector2i(1280,720)
    var world=PickingPlayer.new();root.add_child(world)
    world.camera=Camera3D.new();world.camera.projection=Camera3D.PROJECTION_ORTHOGONAL
    world.camera.size=8;world.add_child(world.camera);world.camera.current=true
    var actor={"id":"actor","kind":"actor","position":[0,0],"base_height_steps":0}
    var object={"id":"door","kind":"door","position":[0,0],"base_height_steps":0}
    world.timeline.state={"tiles":{"0,0":{"position":[0,0],"elevation_steps":0}},
        "actors":{"actor":{"name":"Actor"}},"objects":{"door":{"item":{"name":"Door","item_id":"door"}}}}
    world.actor_rows=[actor];world.placements=[object]
    var actor_image=Image.create(4,4,false,Image.FORMAT_RGBA8);actor_image.fill(Color.WHITE)
    actor_image.set_pixel(0,0,Color.TRANSPARENT)
    world.source_images["actor"]=actor_image
    world.add_entry(actor,"body",0,preload("res://modular.gdshader"))
    var body:Dictionary=world.entries.back();world.set_quad(body,Vector2(4,4),Vector2(2,2),32)
    body.texture_path="actor";body.material.set_shader_parameter("frame_uv",Vector4(0,0,1,1))
    var object_image=Image.create(8,4,false,Image.FORMAT_RGBA8);object_image.fill(Color.TRANSPARENT)
    for y in 4:
        for x in range(4,8):object_image.set_pixel(x,y,Color.WHITE)
    world.source_images["door"]=object_image
    world.add_entry(object,"body",0,world.ENVIRONMENT_SHADER,1)
    var door:Dictionary=world.entries.back();world.set_quad(door,Vector2(4,4),Vector2(2,2),32)
    door.record={"path":"door","native_size":[4,4],"rect":[4,0,4,4]}
    var blood=Blood.new()
    var plane=PlaneMesh.new();plane.size=Vector2.ONE
    var deposit:Dictionary=blood._entry(world,"blood:tile:0,0",plane,"covering",[0,0],0,1,Blood.Surface)
    # A native component may borrow the recipient actor's placement, but its
    # own mesh and UVs do not become that actor's clickable source sheet.
    var native_node=MultiMeshInstance3D.new();world.add_child(native_node)
    var native={"node":native_node,"placement":actor,"role":"native_effect"}
    for quarter in 4:
        world.camera.position=Basis(Vector3.UP,quarter*PI*.5)*Vector3(6,5,6)
        world.camera.look_at(Vector3.ZERO)
        for entry in [body,door]:entry.node.basis=world.camera.basis;entry.node.position=Vector3(0,.5,0)
        var opaque=point(world,body,Vector2(.375,.375))
        var clear=point(world,body,Vector2(.125,.125))
        world.draw_order=[door,body,deposit,native]
        check(not world._entry_contains(deposit,opaque),"Horizontal residue is not a sprite hit q%d"%quarter)
        check(world.pick_world(opaque).get("id")=="actor","Residue and native effect preserve underlying actor click q%d"%quarter)
        check(world.pick_actor(opaque)=="actor","Actor-only picking ignores effect-owned geometry q%d"%quarter)
        check(world.pick_actor(clear).is_empty(),"Transparent actor source pixels remain unselectable q%d"%quarter)
        check(world.pick_world(clear).get("id")=="door","Transparent actor pixel reaches exact atlas-backed object q%d"%quarter)
        world.draw_order=[deposit,native]
        var ground=world.camera.unproject_position(Vector3.ZERO)
        var picked=world.pick_world(ground)
        check(picked.get("kind")=="ground" and picked.get("position")==[0,0],"Residue-only ground remains a disclosed movement target q%d"%quarter)
    world.draw_order=[];world.queue_free();await process_frame
    var report={"checks":checks,"failures":failures,"scope":"Real pick_world/pick_actor paths, native blood PlaneMesh ownership and effect-owned geometry, exact actor alpha and environment atlas region, four camera quarters. No GPU or performance claim."}
    FileAccess.open("res://.runtime/player-effect-picking-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("PLAYER_EFFECT_PICKING ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
