extends SceneTree
## Native phase submission bounds, not GPU pixel or occlusion evidence.
const Renderer=preload("res://presentation/native_spell_renderer.gd")
var checks:=0
var failures:Array=[]

func _initialize()->void:run.call_deferred()

func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("NATIVE_SPELL_WITNESS_FAIL ",label)

func submitted(node:GeometryInstance3D,camera:Camera3D)->bool:
    return Renderer.submitted_geometry({"geometry":[{"node":node}]},camera.get_frustum(),2)

func run()->void:
    var viewport=SubViewport.new();viewport.size=Vector2i(640,480);root.add_child(viewport)
    var scene=Node3D.new();viewport.add_child(scene)
    var camera=Camera3D.new();scene.add_child(camera)
    camera.set_orthogonal(6.0,.1,30.0);camera.cull_mask=2
    var parent=Node3D.new();scene.add_child(parent)
    var mesh=MeshInstance3D.new();mesh.mesh=BoxMesh.new();mesh.layers=2;parent.add_child(mesh)
    for quarter in 4:
        camera.rotation.y=quarter*PI*.5
        var center:Vector3=camera.global_transform*Vector3(0,0,-5)
        mesh.global_position=center
        check(camera.is_position_in_frustum(center),"camera fixture center is in view "+str(quarter))
        check(submitted(mesh,camera),"on-screen geometry can witness submission "+str(quarter))
        mesh.global_position=camera.global_transform*Vector3(100,0,-5)
        check(not submitted(mesh,camera),"offscreen geometry cannot witness submission "+str(quarter))
        mesh.global_position=camera.global_transform*Vector3(0,0,5)
        check(not submitted(mesh,camera),"geometry behind camera cannot witness submission "+str(quarter))
        mesh.global_position=camera.global_transform*Vector3(0,0,-40)
        check(not submitted(mesh,camera),"geometry beyond far plane cannot witness submission "+str(quarter))
        mesh.global_position=center;mesh.hide()
        check(not submitted(mesh,camera),"hidden geometry cannot witness submission "+str(quarter))
        mesh.show();parent.hide()
        check(not submitted(mesh,camera),"hidden ancestor suppresses submission "+str(quarter))
        parent.show();mesh.layers=4
        check(not submitted(mesh,camera),"another appearance pass cannot witness submission "+str(quarter))
        mesh.layers=2
    camera.rotation=Vector3.ZERO;mesh.position=Vector3(0,0,-5)
    mesh.custom_aabb=AABB(Vector3(-50,-50,-.5),Vector3(100,100,1))
    var any_corner_inside:=false
    for index in 8:
        any_corner_inside=any_corner_inside or camera.is_position_in_frustum(mesh.global_transform*mesh.custom_aabb.get_endpoint(index))
    check(not any_corner_inside,"crossing-box fixture has no corner in view")
    check(submitted(mesh,camera),"large custom bounds crossing the view still witness submission")
    mesh.custom_aabb=AABB(Vector3(100,100,0),Vector3.ONE)
    check(not submitted(mesh,camera),"custom bounds replace the centered mesh bounds")
    mesh.custom_aabb=AABB();mesh.position=Vector3(6,0,-5)
    check(not submitted(mesh,camera),"unexpanded bounds are outside")
    mesh.extra_cull_margin=3
    check(submitted(mesh,camera),"native extra cull margin participates in submission bounds")
    mesh.extra_cull_margin=0;mesh.hide()
    var particles=GPUParticles3D.new();particles.emitting=false;particles.layers=2
    particles.visibility_aabb=AABB(Vector3(-.5,-.5,-.5),Vector3.ONE)
    scene.add_child(particles);particles.position=Vector3(0,0,-5)
    check(submitted(particles,camera),"stopped emitter retains possible live tail submission")
    particles.visibility_aabb=AABB(Vector3(100,0,0),Vector3.ONE)
    check(not submitted(particles,camera),"offscreen particle visibility bounds do not witness submission")
    particles.custom_aabb=AABB(Vector3(-.5,-.5,-.5),Vector3.ONE)
    check(submitted(particles,camera),"geometry custom bounds override particle visibility bounds")
    particles.hide()
    check(not submitted(particles,camera),"hidden stopped emitter cannot witness submission")
    viewport.free()
    var report={"checks":checks,"failures":failures,"boundary":"Conservative native submitted bounds only; no GPU fragments or occlusion claim."}
    FileAccess.open("res://.runtime/native-spell-witness-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_SPELL_WITNESS ",checks," checks, ",failures.size()," failures")
    quit(0 if failures.is_empty() else 1)
