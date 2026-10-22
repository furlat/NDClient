extends SceneTree
## Actual native Camera3D projection: divider/window resize preserves pixel scale and focus.
const Layout=preload("res://studio/viewport_layout.gd")
var checks=0
var failures:Array=[]
var samples:Array=[]
class BodyFrameWorld extends Node3D:
    var camera:Camera3D
    var visual_actors:Dictionary={}

func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("STUDIO_VIEWPORT_FAIL ",label)

func _initialize()->void:run.call_deferred()

func projected(camera:Camera3D,focus:Vector3)->Array:
    var center=camera.unproject_position(focus)
    return [center,camera.unproject_position(focus+camera.basis.x)-center,
        camera.unproject_position(focus+camera.basis.y*.7)-center]

func prepared_body_framing()->void:
    var viewport=SubViewport.new();viewport.size=Vector2i(1600,439)
    viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(viewport)
    var world=BodyFrameWorld.new();viewport.add_child(world)
    var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;world.add_child(camera);world.camera=camera;camera.make_current()
    var mesh=QuadMesh.new();mesh.size=Vector2(14,10);mesh.center_offset=Vector3(2,3,0)
    var body=MeshInstance3D.new();body.mesh=mesh;body.custom_aabb=mesh.get_aabb().expand(Vector3(11,9,1));world.add_child(body)
    var hidden=MeshInstance3D.new();hidden.mesh=QuadMesh.new();hidden.mesh.size=Vector2(200,200);hidden.hide();world.add_child(hidden)
    var reference=QuadMesh.new();reference.size=Vector2(20,18)
    var entry={"node":body,"role":"body","actor_layer":{},"native_shapes":{"":{"mesh":reference}}}
    world.visual_actors={"actual visible owner":{"entries":[entry],"row":{"position":[3,4],"base_height_steps":0}},"undisclosed owner":{"entries":[{"node":hidden,"role":"body","actor_layer":{}}]}}
    var focus:=Vector3(3,.75,4)
    for aspect in [Camera3D.KEEP_HEIGHT,Camera3D.KEEP_WIDTH]:
        camera.keep_aspect=aspect
        for quarter in 4:
            camera.size=6;camera.position=focus+Basis(Vector3.UP,quarter*PI*.5)*Vector3(12,8,12);camera.look_at(focus)
            body.transform=Transform3D(camera.basis.scaled_local(Vector3(-1.2,1.1,1)),focus)
            var before:Transform3D=body.transform;var original_size:Vector2=mesh.size
            var bounds:Rect2=Layout.body_bounds(world)
            check(bounds.size.x<100 and bounds.size.y<100,"Hidden body does not enter automatic current-source bounds")
            var frame:Dictionary=Layout.body_frame(camera,viewport.size,bounds,focus,camera.size)
            var delta:Vector3=frame.focus-focus;camera.position+=delta;camera.size=frame.size
            var contained:bool=true
            for local in [body.custom_aabb,reference.get_aabb()]:
                for corner in 8:
                    var point:Vector2=camera.unproject_position(body.global_transform*local.get_endpoint(corner))
                    contained=contained and point.x>=-.01 and point.y>=-.01 and point.x<=viewport.size.x+.01 and point.y<=viewport.size.y+.01
            check(contained and frame.size>=6,"Prepared transformed body fits the actual short viewport q%d aspect%d"%[quarter,aspect])
            var again:Dictionary=Layout.body_frame(camera,viewport.size,bounds,frame.focus,camera.size)
            check(is_equal_approx(again.size,camera.size) and again.focus.is_equal_approx(frame.focus),"Already contained body does not shrink or recenter")
            check(body.transform==before and mesh.size==original_size,"Studio fit preserves actual body transform and source mesh scale")
    # An initially reduced body must also fit its already declared return to
    # ordinary size; a removal fade cannot require frame-by-frame projection.
    world.visual_actors["actual visible owner"].sampled_pose={"body_scale":{"factor":.5,"owners":[{"authored_factor":.5}]}}
    body.transform=Transform3D(camera.basis.scaled_local(Vector3.ONE*.5),Vector3(3,0,4))
    var returned:Rect2=Layout.body_bounds(world)
    check(returned.size.x>=reference.size.x-.01 and returned.size.y>=reference.size.y-.01,"Admitted reduced-body envelope contains its real ordinary-size restoration")
    viewport.free()

func run()->void:
    prepared_body_framing()
    var viewport=SubViewport.new();viewport.size=Vector2i(1280,320)
    viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
    root.add_child(viewport)
    var space=Node3D.new();viewport.add_child(space)
    var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL
    camera.size=6;space.add_child(camera);camera.make_current()
    var focus=Vector3(3,.75,4)
    camera.position=focus+Vector3(12,8,12);camera.look_at(focus)
    await process_frame
    var original=projected(camera,focus)
    # Reproduce the previous caller behavior independently: changing only height
    # changes the apparent world scale, despite leaving camera.size untouched.
    viewport.size=Vector2i(1280,640)
    await process_frame
    check(projected(camera,focus)[1].length()>original[1].length()*1.9,
        "Uncompensated divider resize reproduces apparent map zoom")
    viewport.size=Vector2i(1280,320)
    await process_frame
    for aspect in [Camera3D.KEEP_HEIGHT,Camera3D.KEEP_WIDTH]:
        camera.keep_aspect=aspect
        for quarter in 4:
            viewport.size=Vector2i(1280,320);camera.size=6
            camera.position=focus+Basis(Vector3.UP,quarter*PI*.5)*Vector3(12,8,12)
            camera.look_at(focus)
            await process_frame
            var before=projected(camera,focus)
            var transform=camera.transform
            for size in [Vector2(1280,160),Vector2(1280,560),Vector2(1920,560),
                    Vector2(1920,900),Vector2(1280,320)]:
                Layout.resize(viewport,camera,size)
                await process_frame
                var after=projected(camera,focus)
                var error=maxf((after[1]-before[1]).length(),(after[2]-before[2]).length())
                check(error<.01,"Projected body/grid scale survives pane resize q%d aspect%d %s"%[quarter,aspect,size])
                check(after[0].distance_to(Vector2(viewport.size)*.5)<.01 and camera.transform==transform,
                    "Pane resize preserves world focus and camera transform q%d aspect%d"%[quarter,aspect])
                samples.append({"quarter":quarter,"keep_aspect":aspect,"viewport":[viewport.size.x,viewport.size.y],
                    "max_projection_error_px":error,"camera_extent":camera.size})
            # Explicit zoom remains a separate user action, then survives resize.
            camera.size*=.9
            var zoomed=projected(camera,focus)
            check(zoomed[1].length()>before[1].length()*1.1,"Explicit wheel-scale zoom still changes projected size")
            Layout.resize(viewport,camera,Vector2(1400,480))
            await process_frame
            check(projected(camera,focus)[1].distance_to(zoomed[1])<.01,"Resize preserves a newly chosen user zoom")
            var extent=camera.size
            check(not Layout.resize(viewport,camera,Vector2(1400,480)) and camera.size==extent,
                "Unchanged pane does not accumulate camera-scale drift")
    # A pending seek owner has its own viewport extent. Resizing both from their
    # real previous sizes yields the same displayed projection at publication.
    var candidate_view=SubViewport.new();candidate_view.size=viewport.size
    candidate_view.own_world_3d=true;candidate_view.render_target_update_mode=SubViewport.UPDATE_DISABLED
    root.add_child(candidate_view)
    var candidate=Camera3D.new();candidate.projection=camera.projection;candidate.keep_aspect=camera.keep_aspect
    candidate.size=camera.size;candidate.transform=camera.transform;candidate_view.add_child(candidate);candidate.make_current()
    Layout.resize(viewport,camera,Vector2(1000,280))
    Layout.resize(candidate_view,candidate,Vector2(1000,280))
    await process_frame
    check(projected(camera,focus)==projected(candidate,focus),"Displayed and pending seek cameras retain identical projection after divider resize")
    candidate_view.queue_free();viewport.queue_free();await process_frame
    var report={"checks":checks,"failures":failures,"samples":samples,
        "scope":"Native Camera3D projection under pane/window changes; no game playback or rendered-pixel claim"}
    var file=FileAccess.open("res://generated/studio_viewport_layout_checks.json",FileAccess.WRITE)
    file.store_string(JSON.stringify(report,"  "));file.close()
    print("STUDIO_VIEWPORT_CHECKS ",checks," failures ",failures.size())
    quit(0 if failures.is_empty() else 1)
