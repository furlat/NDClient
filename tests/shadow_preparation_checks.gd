extends "res://tests/creature_shadow_checks.gd"
## Preparation/publication ownership is an explicit architecture contract; the
## independent sync-only helper supplies the native pixel oracle.

func clone_source(source:Dictionary,owner:Node3D)->Dictionary:
    var result:Dictionary=source.duplicate()
    var node=MeshInstance3D.new();node.mesh=source.node.mesh.duplicate()
    node.transform=source.node.transform;owner.add_child(node)
    var material=ShaderMaterial.new();material.shader=source.material.shader
    node.material_override=material;result.node=node;result.material=material
    SourceMaterial.initialize(result);SourceMaterial.apply(result,source.source_parameters)
    return result

func private_actor(source:Dictionary)->Dictionary:
    var owner=Node3D.new();owner.hide();stage.add_child(owner)
    var copy=clone_source(source,owner)
    var prepared:Dictionary={"row":copy.placement,"entries":[copy]}
    var complete:=false
    for step in 8:
        if manager.prepare_actor_step(owner,prepared):complete=true;break
    check(complete,source.id+" private shadow construction finishes in bounded steps")
    check(prepared.has("shadow_state"),source.id+" actual geometry has a prepared shadow")
    return {"owner":owner,"prepared":prepared,"source":copy}

func lights()->Array:
    var zoom=1.0/Placement.PIXELS_PER_UNIT*camera.unproject_position(camera.basis.x).distance_to(camera.unproject_position(Vector3.ZERO))
    var cookie=texture("C:/Users/tommaso/Documents/Dev/NDCharacterLight/.reference-template/scenes/vfx/textures/T_basic1_vfx.PNG")
    return [{"id":"original-warm","screen_position":camera.unproject_position(Vector3.ZERO)+Vector2(14,42)*zoom,
        "span":Vector2(cookie.get_size())*19.36*zoom,"height":20*zoom,"texture":cookie,"energy":2.0,
        "color":Color(.809372,.429306,.269121),"enabled":true}]

func actor(source:Dictionary)->Dictionary:return {"valid":true,"row":source.placement,"entries":[source]}

func blocked(image:Image)->int:
    var count:=0
    for y in image.get_height():
        for x in image.get_width():
            if image.get_pixel(x,y).r<.99:count+=1
    return count

func qualify(source:Dictionary)->void:
    var produced:Array=manager.sync([actor(source)],camera,lights())
    check(produced.size()==1 and manager.issues.is_empty(),source.id+" actual source produces an initial live shadow")
    if produced.is_empty():return
    var live:Dictionary=manager.actors[source.id]
    var before:Image=await capture(live.viewport)
    var cancelled=private_actor(source)
    var private_state:Dictionary=cancelled.prepared.shadow_state
    check(private_state.viewport.get_parent()==cancelled.owner and private_state.entry.node.get_parent()==cancelled.owner,
        source.id+" private candidate owns both shadow measurement and output")
    check(private_state.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED and not private_state.entry.node.visible,
        source.id+" candidate has a disabled measurement target and hidden output")
    check(is_same(manager.actors[source.id],live),source.id+" construction does not replace the published shadow")
    var cancelled_view:WeakRef=weakref(private_state.viewport);var cancelled_output:WeakRef=weakref(private_state.entry.node)
    cancelled.owner.queue_free();await process_frame;await process_frame
    check(cancelled_view.get_ref()==null and cancelled_output.get_ref()==null,source.id+" cancellation releases private native objects")
    var after:Image=await capture(live.viewport)
    check(is_same(manager.actors[source.id],live) and before.get_data()==after.get_data(),
        source.id+" cancellation preserves the exact displayed shadow")
    cancelled={};private_state={}

    var candidate=private_actor(source)
    var prepared:Dictionary=candidate.prepared
    var ready_view:SubViewport=prepared.shadow_state.viewport
    var ready_caster:MeshInstance3D=prepared.shadow_state.casters[source.id]
    var retired:Array=manager.adopt_actor(prepared)
    check(retired.size()==2 and not live.entry.node.visible and live.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,
        source.id+" publication retires the old exact output and viewport")
    check(not prepared.has("shadow_state") and ready_view.get_parent()==stage,source.id+" publication transfers private ownership once")
    var current:Dictionary=candidate.source
    current.node.reparent(stage,false);current.node.show()
    candidate.owner.queue_free();source.node.hide()
    for node in retired:node.queue_free()
    await process_frame
    var reference_parent=Node3D.new();stage.add_child(reference_parent)
    var reference=Shadows.new();reference.attach(reference_parent)
    var reference_source=clone_source(source,reference_parent);reference_source.node.show()
    var distinct_samples:Dictionary={}
    for quarter in 4:
        camera.position=Vector3(12,12*Placement.HEIGHT_UNIT,12).rotated(Vector3.UP,quarter*PI*.5)
        camera.look_at(Vector3.ZERO)
        current.node.basis=camera.basis;reference_source.node.basis=camera.basis
        for frame in 2:
            var uv=Vector4(float(frame)/source.frames,float(quarter*2)/8,1.0/source.frames,.125)
            SourceMaterial.set_parameter(current,"frame_uv",uv);SourceMaterial.set_parameter(reference_source,"frame_uv",uv)
            var outputs:Array=manager.sync([actor(current)],camera,lights())
            var counts:Dictionary=manager.diagnostics().sync_counts
            check(outputs.size()==1 and counts.new_actors==0 and counts.new_casters==0 and counts.new_meshes==0,
                source.id+" q"+str(quarter)+" frame"+str(frame)+" sampling uses prepared native objects")
            check(manager.actors[source.id].viewport==ready_view and manager.actors[source.id].casters[source.id]==ready_caster,
                source.id+" sampling preserves the admitted viewport and caster")
            var expected:Array=reference.sync([actor(reference_source)],camera,lights())
            check(expected.size()==1 and reference.issues.is_empty(),source.id+" independent sync-only reference produces a shadow")
            var actual:Image=await capture(ready_view)
            var expected_image:Image=reference.actors[source.id].viewport.get_texture().get_image()
            var equal:bool=actual.get_size()==expected_image.get_size() and actual.get_data()==expected_image.get_data()
            check(equal,source.id+" q"+str(quarter)+" frame"+str(frame)+" exact shadow pixels match sync-only construction")
            check(blocked(actual)>0,source.id+" q"+str(quarter)+" frame"+str(frame)+" comparison contains actual body occlusion")
            distinct_samples[actual.get_data()]=true
            evidence.append({"id":source.id,"quarter":quarter,"frame":frame,"size":[actual.get_width(),actual.get_height()],"exact_pixels":equal,"construction":counts})
    check(distinct_samples.size()>1,source.id+" quarter and authored UV samples produce distinct native shadows")
    var retained_pixels:PackedByteArray=ready_view.get_texture().get_image().get_data()
    for reason in ["unlit","disabled","invisible","offscreen"]:
        var camera_position:Vector3=camera.position
        var sources:Array=lights()
        if reason=="unlit":sources=[]
        elif reason=="disabled":manager.enabled=false
        elif reason=="invisible":current.node.hide()
        else:camera.position+=Vector3(1000,0,1000)
        var hidden:Array=manager.sync([actor(current)],camera,sources)
        check(hidden.is_empty() and manager.actors.has(source.id) and manager.actors[source.id].viewport==ready_view
            and not manager.actors[source.id].entry.node.visible and ready_view.render_target_update_mode==SubViewport.UPDATE_DISABLED,
            source.id+" "+reason+" preserves disabled owned shadow resources")
        camera.position=camera_position;manager.enabled=true;current.node.show()
        manager.sync([actor(current)],camera,lights())
        var resumed:Dictionary=manager.diagnostics().sync_counts
        check(resumed.new_actors==0 and resumed.new_casters==0 and manager.actors[source.id].casters[source.id]==ready_caster,
            source.id+" resumes from "+reason+" without reconstructing the native actor/caster")
        var resumed_image:Image=await capture(ready_view)
        check(resumed_image.get_data()==retained_pixels,source.id+" resumes the exact native shadow pixels after "+reason)
    var retired_view:WeakRef=weakref(ready_view);var retired_caster:WeakRef=weakref(ready_caster)
    manager.sync([],camera,[])
    check(manager.actors.is_empty() and retired_view.get_ref()==null and retired_caster.get_ref()==null,
        source.id+" actual actor removal retires its native resources even while unlit")
    reference.close();reference_parent.queue_free();current.node.queue_free();source.node.queue_free()
    await process_frame

func run()->void:
    if DisplayServer.get_name()=="headless":print("Shadow preparation requires native graphics");quit(2);return
    root.unfocusable=true;root.position=Vector2i(-16000,-16000)
    viewport=SubViewport.new();viewport.size=Vector2i(512,512);viewport.world_3d=World3D.new();viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
    stage=Node3D.new();viewport.add_child(stage);camera=Camera3D.new();stage.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=4
    camera.position=Vector3(12,12*Placement.HEIGHT_UNIT,12);camera.look_at(Vector3.ZERO);manager.attach(stage)
    var animals=read(FACTORY.path_join("animals/delivery/catalog.json"))
    await qualify(packet(animals,FACTORY.path_join("animals/delivery"),"wolf/idle"))
    camera.position=Vector3(12,12*Placement.HEIGHT_UNIT,12);camera.look_at(Vector3.ZERO)
    await qualify(modular())
    manager.close();viewport.queue_free();await process_frame;await process_frame
    var report={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Actual wolf and Chest14 optical sources: private native ownership, cancellation, publication, construction-free first sample, and byte-exact native shadow viewport parity with independent sync-only construction across four quarters and two authored frames."}
    FileAccess.open("res://.runtime/shadow-preparation-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("SHADOW_PREPARATION_CHECKS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
