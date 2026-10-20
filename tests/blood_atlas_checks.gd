extends SceneTree
## Field atlas and pooled droplet halves versus the saved pre-edit renderer
## (one viewport, two meshes and two materials per tile; per-frame per-particle
## painter keys). Actual Gallery and Dash releases, four quarters, landing and
## settled ages, with and without a recipient actor. Exact: painter entries
## (id, role, layer, placement), the sorted painter order, droplet instance
## buffers and split planes, stain operands, field bytes and final pixels.
## The oracle is the pre-edit renderer with its shaders, e.g.
##   git show f77f83d:presentation/blood_renderer.gd > .runtime/blood-l6-oracle/blood_renderer.gd
## plus blood.gd and the three shaders beside it, preload paths pointed there.
const Preview=preload("res://presentation/blood_preview.gd")
const Recording=preload("res://studio/recording.gd")
const Order=preload("res://grid_order.gd")
const Profile=preload("res://frame_profile.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
var checks:int=0
var failures:Array=[]
var timing:Dictionary={"old_sample":[],"new_sample":[],"old_flight":[],"new_flight":[],"old_fields":[],"new_fields":[]}
var counts:Dictionary={}
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr("BLOOD_ATLAS_FAIL ",label)
func frame()->void:
    await process_frame;await RenderingServer.frame_post_draw
func fixture(renderer:Script)->Node3D:
    var viewport=SubViewport.new();viewport.size=Vector2i(384,256);viewport.own_world_3d=true
    viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
    var world=Preview.new();world.renderer=renderer.new();viewport.add_child(world)
    return world
func field(world:Node3D,key:String)->Image:
    var handle:Dictionary=world.renderer.deposits[key]
    return handle.field.get_texture().get_image() if handle.has("field") else world.renderer.field_image(handle)
func painter_order(world:Node3D,quarter:int)->Array:
    var shown:Array=world.actor_entries.filter(func(entry):return entry.node.visible)
    for entry in shown:entry.order_key=Order.key(entry.placement,entry.role,entry.layer,quarter,true)
    shown.sort_custom(func(a,b):return Order.less(a.order_key,b.order_key) if a.order_key!=b.order_key else a.id<b.id)
    return shown.map(func(entry):return entry.id)
func census(world:Node3D,tiles:int,label:String)->void:
    var classes:Dictionary={}
    for node in world.find_children("*","",true,false):classes[node.get_class()]=classes.get(node.get_class(),0)+1
    var materials:Dictionary={}
    for node in world.find_children("*","",true,false):
        if node is GeometryInstance3D and node.material_override!=null:materials[node.material_override.get_instance_id()]=true
        if node is CanvasItem and node.material!=null:materials[node.material.get_instance_id()]=true
    counts[label]={"tiles":tiles,"nodes":classes,"materials":materials.size(),"flights":world.renderer.flights.size()}
func compare(old:Node3D,new:Node3D,quarter:int,label:String)->void:
    var a:Dictionary=old.renderer.flights;var b:Dictionary=new.renderer.flights
    var keys:Array=a.keys();keys.sort();var other:Array=b.keys();other.sort()
    check(keys==other,"Same droplet bucket halves "+label)
    if keys==other:
        for key in keys:
            var x:Dictionary=a[key];var y:Dictionary=b[key]
            check(x.id==y.id and x.role==y.role and x.layer==y.layer and x.placement==y.placement,"Same droplet painter entry "+label+" "+key)
            check(x.node.visible==y.node.visible and x.node.multimesh.instance_count==y.node.multimesh.instance_count and x.node.multimesh.buffer==y.node.multimesh.buffer,"Same droplet instance transforms and colours "+label+" "+key)
            var same:bool=true
            for name in ["partition","back","plane_origin","plane_normal"]:same=same and x.material.get_shader_parameter(name)==y.node.get_instance_shader_parameter(name)
            for name in ["light_cap","normals_visible","blood_ambient","blood_room_lights"]:same=same and x.material.get_shader_parameter(name)==y.material.get_shader_parameter(name)
            check(same,"Same droplet split plane and room operands "+label+" "+key)
    var deposits:Array=old.renderer.deposits.keys();deposits.sort();var mine:Array=new.renderer.deposits.keys();mine.sort()
    check(deposits==mine,"Same retained stain tiles "+label)
    if deposits==mine:
        for key in deposits:
            var x:Dictionary=old.renderer.deposits[key].entry;var y:Dictionary=new.renderer.deposits[key].entry
            check(x.id==y.id and x.role==y.role and x.layer==y.layer and x.placement==y.placement and x.node.visible==y.node.visible and x.node.position==y.node.position,"Same stain painter entry "+label+" "+key)
            if not x.node.visible:continue
            var same:bool=x.material.get_shader_parameter("visibility")==y.node.get_instance_shader_parameter("visibility") and x.material.get_shader_parameter("tile_position")==y.node.get_instance_shader_parameter("tile_position")
            for name in ["light_cap","normals_visible","receiving_normal","blood_ambient","blood_room_lights"]:same=same and x.material.get_shader_parameter(name)==y.material.get_shader_parameter(name)
            check(same,"Same stain operands "+label+" "+key)
    check(painter_order(old,quarter)==painter_order(new,quarter),"Same painter order of every visible blood draw "+label)
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(384,256)
    create_timer(600).timeout.connect(func():printerr("Blood atlas test deadline");quit(2))
    var oracle:String=""
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--oracle="):oracle=argument.trim_prefix("--oracle=")
    if oracle.is_empty() or not FileAccess.file_exists(oracle):printerr("Provide the saved pre-edit blood renderer with --oracle");quit(2);return
    var original:Script=load(oracle);var current:Script=preload("res://presentation/blood_renderer.gd")
    # The oracle folder also keeps the pre-edit blood.gd (per-frame particles).
    var old_blood:Script=original.Blood;var new_blood:Script=current.Blood
    var occurrences:Array=[]
    for path in [Fixtures.journal("dash"),Fixtures.journal("gallery")]:
        var index:Dictionary=Recording.read(path)
        check(index.ok,"Actual recording admits "+path)
        if not index.ok:continue
        for item in index.groups:
            for component in item.group.components:
                if component.kind=="residue_deposit":occurrences.append({"component":component,"group":item.group,"cache":index.cache})
    check(occurrences.size()>5,"Multiple actual releases exercised")
    var frames:int=0
    for number in occurrences.size():
        var occurrence:Dictionary=occurrences[number];var component:Dictionary=occurrence.component
        # Every other release lands on a recipient: its painter cell takes the
        # actor's exact contact key and the halves split at its foot.
        var actor:Dictionary={}
        if number%2==0:actor={"row":{"id":"recipient","kind":"actor","position":[roundi(component.position[0]),roundi(component.position[1])],"base_height_steps":component.elevation_steps}}
        var pair:Array=[]
        for script in [original,current]:
            var world:Node3D=fixture(script);world.catalog_cache=occurrence.cache;world.timeline.queue=[occurrence.group]
            world.camera=Camera3D.new();world.add_child(world.camera)
            var ready:bool=false
            for attempt in 60:
                ready=world.renderer.prepare(world,[occurrence.group],{"used_usec":0,"limit_usec":100000})
                world.sample();await frame()
                if ready:break
            check(ready,"Release prepares its fields "+str(number))
            world.timeline.world_revision+=1;world.camera.free()
            if not actor.is_empty():world.visual_actors[component.actor_uuid]=actor
            world.configure(component,occurrence.cache,0.,0,world.source_lighting)
            pair.append(world)
        var old:Node3D=pair[0];var new:Node3D=pair[1]
        var ages:Array=[]
        for step in 13:ages.append(step*component.duration_ms/12.)
        ages.append(component.duration_ms+1.)
        var source:Dictionary=new.renderer.source;var plan:Array=new_blood.flight_plan(component,source)
        for step in 61:
            var age:float=(step-1)*component.duration_ms/59000.
            var expected:Array=old_blood.particles(component,source,age)
            check(new_blood.particles(component,source,age)==expected and new_blood.particles(component,source,age,plan)==expected,"Planned flight particles equal per-frame evaluation "+str([number,age]))
        for quarter in 4:
            for age in ages:
                var swap:bool=frames%2==1
                for world in ([new,old] if swap else [old,new]):
                    world.camera.basis=Basis.from_euler(Vector3(-atan(sqrt(.5)),PI/4+quarter*PI/2,0))
                    world.camera.position=Vector3(component.position[0],.4,component.position[1])+world.camera.basis.z*12.
                    world.samples[0].age_ms=age;world.sample()
                    for entry in world.actor_entries:entry.material.render_priority=0 if entry.role=="covering" else 1
                    var side:String="old" if world==old else "new"
                    timing[side+"_sample"].append(world.renderer.last_sample_usec/1000.)
                    timing[side+"_flight"].append(world.renderer.sample_phases.get("flight",0.))
                    timing[side+"_fields"].append(world.renderer.sample_phases.get("fields",0.))
                frames+=1
                var label:String=str([number,quarter,age])
                compare(old,new,quarter,label)
                # Fields and pixels exist once both hosts have drawn this sample.
                await frame();await frame()
                for key in old.renderer.deposits:
                    if new.renderer.deposits.has(key):check(field(old,key).get_data()==field(new,key).get_data(),"Same field bytes "+label+" "+key)
                check(old.get_viewport().get_texture().get_image().get_data()==new.get_viewport().get_texture().get_image().get_data(),"Same final pixels "+label)
        if number==0:
            census(old,old.renderer.deposits.size(),"pre-edit")
            census(new,new.renderer.deposits.size(),"atlas")
        for world in pair:world.close();world.get_viewport().queue_free()
        await frame()
    var report={"checks":checks,"failures":failures,"releases":occurrences.size(),"frames":frames,"counts":counts,
        "sample_ms":{"old":Profile.distribution(timing.old_sample),"new":Profile.distribution(timing.new_sample)},
        "flight_ms":{"old":Profile.distribution(timing.old_flight),"new":Profile.distribution(timing.new_flight)},
        "fields_ms":{"old":Profile.distribution(timing.old_fields),"new":Profile.distribution(timing.new_fields)},
        "scope":"Actual recorded releases through the swatch host, old and new renderers side by side. Exact painter entries/order, instance buffers, operands, field bytes and pixels; isolated renderer CPU only."}
    FileAccess.open("res://.runtime/blood-atlas-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("BLOOD_ATLAS_CHECKS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
