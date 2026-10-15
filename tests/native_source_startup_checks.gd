extends SceneTree
## Cold registered-source preparation, then exact private runtime instances.
## First-visible pipeline counts remain separate from construction CPU cost.
const Startup=preload("res://presentation/native_source_startup.gd")
const Factory=preload("res://presentation/native_factory_source.gd")
const Profile=preload("res://frame_profile.gd")
const Layer=preload("res://presentation/native_effect_layer.gd")
var checks:int=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr(label)
func delta(before:Dictionary,after:Dictionary)->Dictionary:
    var result:Dictionary={}
    for key in before:result[key]=after[key]-before[key]
    return result
func noise_resources(value:Variant,seen:Dictionary,result:Array)->void:
    if value is Resource:
        if seen.has(value):return
        seen[value]=true
        if value is NoiseTexture2D:
            result.append({"width":value.width,"height":value.height,"private":value.resource_local_to_scene});return
        if value is Shader or value is Script or value is Texture2D:return
        if value is Mesh:
            for i in value.get_surface_count():noise_resources(value.surface_get_material(i),seen,result)
        for property in value.get_property_list():
            if int(property.usage)&PROPERTY_USAGE_STORAGE:
                var child:Variant=value.get(property.name)
                if child is Resource or child is Array or child is Dictionary:noise_resources(child,seen,result)
    elif value is Array or value is Dictionary:
        for child in (value if value is Array else value.values()):noise_resources(child,seen,result)
func noise_inventory(clip:Dictionary)->Array:
    var result:Array=[]
    for spec in clip.components:
        var packet:Resource=Factory.admitted_packet(spec,clip)
        var textures:Array=[]
        if packet!=null:noise_resources(packet.scene,{},textures)
        result.append({"adapter":spec.script,"noise_textures":textures})
    return result
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(320,240)
    Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    create_timer(180).timeout.connect(func():printerr("Native startup deadline");quit(2))
    var host=Node3D.new();root.add_child(host)
    var cache:Dictionary={};var calls:Array=[];var frames:Array=[];var previous:int=Time.get_ticks_usec()
    var status:Dictionary={}
    while true:
        var begin:int=Time.get_ticks_usec();status=Startup.step(host,cache);calls.append((Time.get_ticks_usec()-begin)/1000.0)
        if status.ready or not status.errors.is_empty():break
        await process_frame;await RenderingServer.frame_post_draw
        var now:int=Time.get_ticks_usec();frames.append((now-previous)/1000.0);previous=now
    check(status.errors.is_empty(),"Registered source startup has no missing/stale/native preparation error")
    check(status.ready and status.completed==status.total and status.total>=60,"Every registered native phase completes finite startup")
    var initial_calls:int=status.construction_ms.size()
    var begin:int=Time.get_ticks_usec();var repeated:Dictionary=Startup.step(host,{});var reuse_ms:float=(Time.get_ticks_usec()-begin)/1000.0
    check(repeated.ready and repeated.construction_ms.size()==initial_calls,"A replacement host reuses retained prototype programs without reconstruction")
    check(Startup._state.active.is_empty() and Startup._state.owner==null,"All temporary startup source nodes retire after their draw")
    var all_sources:bool="--all-sources" in OS.get_cmdline_user_args()
    var rows:Array=[]
    if status.ready:
        var viewport=SubViewport.new();viewport.size=Vector2i(256,256);viewport.own_world_3d=true;viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
        var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=3;camera.near=.01;camera.far=100;camera.cull_mask=Layer.LAYER
        camera.environment=Environment.new();camera.environment.background_mode=Environment.BG_COLOR;camera.environment.background_color=Color.BLACK;camera.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;camera.environment.ambient_light_color=Color.WHITE
        viewport.add_child(camera);camera.basis=Basis.from_euler(Vector3(-atan(sqrt(.5)),PI/4,0));camera.position=camera.basis.z*10
        var owner=Node3D.new();viewport.add_child(owner)
        var wanted:Array=["spells/chill_touch/impact/impact","spells/fireball/fire/lifecycle","recovered/travelIce","spells/magic_missile/default/impact","spells/shield/back/hit_E","spells/sanctuary/back/lifecycle","spells/thunderwave_production_xyz/whole/lifecycle","spells/produce_flame/palm_back/palm"]
        var selected:Array=[]
        if all_sources:
            var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://authoring/sandbox/projectiles.json"))
            for spell in manifest.spells:
                for clip in spell.clips:selected.append({"clip":clip})
        else:
            for item in Startup._state.plan:
                if item.clip.id in wanted:selected.append(item)
        var isolated_cache:Dictionary={}
        for item in selected:
            var admission_begin:int=Time.get_ticks_usec()
            var ready:Dictionary=Factory.prepare([item.clip],isolated_cache)
            while not ready.ready and ready.errors.is_empty():
                await process_frame;await RenderingServer.frame_post_draw
                ready=Factory.prepare([item.clip],isolated_cache)
            var admission_ms:float=(Time.get_ticks_usec()-admission_begin)/1000.0
            check(ready.ready,"Prepared source admits in an independent occurrence owner: "+item.clip.id)
            if not ready.ready:failures.append_array(ready.errors);continue
            var noise:Array=noise_inventory(item.clip)
            var pipelines:Dictionary=Profile.pipeline_compilations();begin=Time.get_ticks_usec()
            var handle:Dictionary=Factory.make(owner,item.clip.duplicate(true),Layer.LAYER)
            var build_ms:float=(Time.get_ticks_usec()-begin)/1000.0
            check(handle.error.is_empty(),"Private source constructs: "+item.clip.id)
            if not handle.error.is_empty():continue
            handle.root.scale=Vector3.ONE*.18;handle.root.show()
            var build_pipelines:Dictionary=Profile.pipeline_compilations();var drawn:int=Time.get_ticks_usec()
            await process_frame;await RenderingServer.frame_post_draw
            var first_draw_ms:float=(Time.get_ticks_usec()-drawn)/1000.0
            var draw_pipelines:Dictionary=Profile.pipeline_compilations()
            var sample_frames:Array=[];var sample_calls:Array=[]
            for tick in 13:
                var frame_begin:int=Time.get_ticks_usec()
                await process_frame
                var sample_begin:int=Time.get_ticks_usec()
                Factory.sample(handle,tick/60.0,1.0/60.0)
                sample_calls.append((Time.get_ticks_usec()-sample_begin)/1000.0)
                await RenderingServer.frame_post_draw
                sample_frames.append((Time.get_ticks_usec()-frame_begin)/1000.0)
            check(handle.age==.2,"Startup did not replace the private source clock: "+item.clip.id)
            rows.append({"source":item.clip.id,"admission_ms":admission_ms,"noise_inventory":noise,"make_ms":build_ms,"first_draw_ms":first_draw_ms,
                "sample_frame_ms":Profile.distribution(sample_frames),"sample_cpu_ms":Profile.distribution(sample_calls),"construct_pipeline_delta":delta(pipelines,build_pipelines),"first_draw_pipeline_delta":delta(build_pipelines,draw_pipelines),"sample_pipeline_delta":delta(draw_pipelines,Profile.pipeline_compilations())})
            print("NATIVE_STARTUP_PRIVATE ",JSON.stringify(rows.back()))
            Factory.close(handle);await process_frame;await RenderingServer.frame_post_draw
        viewport.queue_free();await process_frame;await RenderingServer.frame_post_draw
        check(rows.size()==selected.size(),"Every selected source exercises a new private visible instance")
    var report={"checks":checks,"failures":failures,"startup":status,"step_ms":Profile.distribution(calls),"startup_frame_ms":Profile.distribution(frames),"replacement_host_step_ms":reuse_ms,"private_instances":rows,
        "scope":"Startup and first-visible private instance timing. No source time simulation is baked or shared. Pixel/source parity is qualified separately by native_source_variant_render_checks."}
    FileAccess.open("res://.runtime/native-source-startup"+("-all" if all_sources else "")+"-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_STARTUP_COMPLETE ",checks," failures=",failures," startup_ms=",status.elapsed_ms)
    quit(0 if failures.is_empty() else 1)
