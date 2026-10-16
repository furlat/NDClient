extends SceneTree
## Real receiver pixels: batched terrain versus independent single-cell controls.
const Support=preload("res://presentation/native_scene_support.gd")
const Placement=preload("res://placement.gd")
class Host extends Node3D:
    var camera:Camera3D
var checks=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr("FLOOR_BATCH_FAIL ",label)
func scene()->Dictionary:
    var view=SubViewport.new();view.size=Vector2i(256,192);view.own_world_3d=true
    view.transparent_bg=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    var host=Host.new();view.add_child(host)
    host.camera=Camera3D.new();host.camera.projection=Camera3D.PROJECTION_ORTHOGONAL
    host.camera.near=.01;host.camera.far=50;host.add_child(host.camera)
    var support=Support.new();support.attach_shared(host)
    return {"view":view,"host":host,"support":support,"entries":[]}
func publish(value:Dictionary,rows:Array,batched:bool)->void:
    if batched:
        if value.entries.is_empty():
            var node=MultiMeshInstance3D.new();node.multimesh=MultiMesh.new()
            node.multimesh.transform_format=MultiMesh.TRANSFORM_3D
            node.multimesh.mesh=PlaneMesh.new();value.host.add_child(node)
            value.entries.append({"id":"batch","role":"terrain","node":node,"ground_version":0})
        var entry:Dictionary=value.entries[0]
        entry.ground_version+=1;entry.batch_rows=rows.duplicate(true);entry.placement=rows[0]
        entry.node.multimesh.instance_count=rows.size()
        for index in rows.size():entry.node.multimesh.set_instance_transform(index,Transform3D(Basis.IDENTITY,Placement.contact(rows[index])))
    else:
        for entry in value.entries:entry.node.free()
        value.entries=[]
        for row in rows:
            var node=MeshInstance3D.new();node.mesh=PlaneMesh.new();node.position=Placement.contact(row);value.host.add_child(node)
            value.entries.append({"id":row.id,"role":"terrain","node":node,"placement":row.duplicate(true)})
func view(value:Dictionary,quarter:int,zoom:float)->void:
    var camera:Camera3D=value.host.camera
    camera.basis=Basis(Vector3.UP,quarter*PI*.5)*Basis.from_euler(Vector3(-atan(sqrt(.5)),PI/4,0))
    camera.position=Vector3(1.5,0,0)+camera.basis.z*10;camera.size=zoom
func sync(value:Dictionary)->void:
    check(value.support.prepare_membership(value.entries,{}).ready,"Exact receiver membership prepares before sync")
    value.support.sync(value.entries,{},value.host.camera)
func draw()->void:
    await process_frame;await RenderingServer.frame_post_draw
    await process_frame;await RenderingServer.frame_post_draw
func compare(batch:Dictionary,single:Dictionary,rows:Array,visible:bool,label:String)->void:
    var actual:Image=batch.support.viewport.get_texture().get_image()
    var expected:Image=single.support.viewport.get_texture().get_image()
    check(actual.get_data()==expected.get_data(),label+" exact depth for all source cells")
    for row in rows:
        var at:Vector2=batch.support.camera.unproject_position(Placement.contact(row))
        var alpha=actual.get_pixelv(Vector2i(at)).a
        check((alpha>0.0)==visible,label+" admitted contact coverage "+row.id)
func private_boundary(batch:Dictionary,single:Dictionary,original:Array)->void:
    publish(batch,original,true);publish(single,original,false)
    for value in [batch,single]:view(value,0,5.0);sync(value)
    await draw()
    var before:PackedByteArray=batch.support.viewport.get_texture().get_image().get_data()
    var source:Dictionary=batch.entries[0]
    var raised:Array=original.duplicate(true);raised[1].base_height_steps=1
    var snapshot:Dictionary=source.duplicate();snapshot.batch_rows=raised;snapshot.ground_version=source.ground_version+1
    var candidate=Node3D.new();candidate.visible=false;batch.host.add_child(candidate)
    var state:Dictionary={}
    check(batch.support.prepare_boundary(candidate,[{"entry":source,"prepared":{"snapshot":snapshot}}],state,{"used_usec":0,"limit_usec":1000000}),"Future receiver prepares privately")
    await draw()
    check(batch.support.viewport.get_texture().get_image().get_data()==before,"Unpublished future receiver leaves displayed depth unchanged")
    candidate.free();state.clear()
    await draw()
    check(batch.support.viewport.get_texture().get_image().get_data()==before,"Cancelled receiver leaves displayed depth unchanged")
    candidate=Node3D.new();candidate.visible=false;batch.host.add_child(candidate)
    check(batch.support.prepare_boundary(candidate,[{"entry":source,"prepared":{"snapshot":snapshot}}],state,{"used_usec":0,"limit_usec":1000000}),"Replacement receiver prepares privately")
    publish(batch,raised,true);publish(single,raised,false)
    batch.support.publish_boundary(state)
    batch.support.sync(batch.entries,{},batch.host.camera)
    check(batch.support.ready,"Publication needs no receiver constructor")
    sync(single);candidate.free();await draw()
    compare(batch,single,raised,true,"Private raised receiver publication")

func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(64,64)
    create_timer(30).timeout.connect(func():printerr("Floor batch check deadline");quit(2))
    var batch=scene();var single=scene()
    var original=[{"id":"a","position":[0,0],"base_height_steps":0},{"id":"b","position":[3,0],"base_height_steps":0}]
    for quarter in 4:
        for zoom in [5.0,7.0]:
            var rows=original.duplicate(true)
            for label in ["initial","raised","reordered","removed","hidden","revealed"]:
                if label=="raised":rows[1].base_height_steps=1
                elif label=="reordered":rows.reverse()
                elif label=="removed":rows=rows.slice(0,1)
                elif label=="revealed":rows=original.duplicate(true)
                publish(batch,rows,true);publish(single,rows,false)
                for value in [batch,single]:
                    for entry in value.entries:entry.node.visible=label!="hidden"
                    view(value,quarter,zoom);sync(value)
                await draw()
                compare(batch,single,rows,label!="hidden","q%d zoom%.0f %s"%[quarter,zoom,label])
            # Hidden warmup must prepare the same complete batch as live sync.
            batch.support.set_enabled(false);batch.support.prepare_hidden(batch.entries,{})
            batch.support.set_enabled(true);sync(batch);await draw()
            compare(batch,single,rows,true,"q%d hidden preparation"%quarter)
    await private_boundary(batch,single,original)
    for value in [batch,single]:value.support.close();value.view.queue_free()
    await process_frame
    var report={"checks":checks,"failures":failures,"scope":"Native packed receiver pixels against equivalent unbatched cells across four quarters/two zooms, elevation, representative reorder, member removal, hide/reveal and hidden preparation. No gameplay or frame-time claim."}
    FileAccess.open("res://generated/native_floor_batch_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_FLOOR_BATCH_CHECKS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
