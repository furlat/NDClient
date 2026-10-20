extends SceneTree
## Actual recorded programs through raw Baked.make and production
## EffectPackage.prepare/make. Native pixels, private clocks and immutable
## source properties qualify the preparation seam; timings are evidence only.
const Effects=preload("res://presentation/effect_package.gd")
const Baked=preload("res://presentation/baked_effect.gd")
const Playback=preload("res://presentation/native_spell_playback.gd")
const SIZE=Vector2i(256,256)
const LAYER=1<<19
const CLIPS=["original-repairs/chill-touch/contact-layers","spells/magic_missile/default/cast","spells/fireball/fire/lifecycle"]
var checks:int=0
var failures:Array=[]
var evidence:Array=[]
var save_dir:String="res://.runtime/native-recorded-preparation"

func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->bool:
    checks+=1
    if not ok:failures.append(label);printerr("RECORDED_PREPARATION_FAIL ",label)
    return ok
func frame()->void:
    await process_frame;await RenderingServer.frame_post_draw
func view()->Dictionary:
    var viewport=SubViewport.new();viewport.size=SIZE;viewport.own_world_3d=true
    viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    var camera=Camera3D.new();camera.cull_mask=LAYER;camera.projection=Camera3D.PROJECTION_ORTHOGONAL
    camera.size=9.0;camera.near=.05;camera.far=200.0
    var environment=Environment.new();environment.background_mode=Environment.BG_CLEAR_COLOR
    camera.environment=environment;viewport.add_child(camera)
    var holder=Node3D.new();viewport.add_child(holder);root.add_child(viewport)
    camera.look_at_from_position(Vector3(0,6,10),Vector3(0,.5,0));camera.current=true
    return {"viewport":viewport,"holder":holder}
func image(side:Dictionary)->Image:
    var result:Image=side.viewport.get_texture().get_image();result.convert(Image.FORMAT_RGBA8)
    return result
func pixels(a:Image,b:Image)->Dictionary:
    var left:PackedByteArray=a.get_data();var right:PackedByteArray=b.get_data()
    var differences:int=0;var visible:int=0;var maximum:int=0
    if left.size()!=right.size():return {"different_pixels":-1,"visible_pixels":0,"max_byte_error":255}
    for index in range(0,left.size(),4):
        if left[index+3]>0:visible+=1
        var changed:bool=false
        for channel in 4:
            var delta:int=absi(int(left[index+channel])-int(right[index+channel]))
            maximum=maxi(maximum,delta);changed=changed or delta>0
        differences+=int(changed)
    return {"different_pixels":differences,"visible_pixels":visible,"max_byte_error":maximum}

func stored(object:Object)->Dictionary:
    var result:Dictionary={}
    for property in object.get_property_list():
        if (int(property.usage)&PROPERTY_USAGE_STORAGE)==0:continue
        var value:Variant=object.get(property.name)
        result[str(property.name)]=value.duplicate(true) if value is Array or value is Dictionary else value
    return result
func material_chain(first:Material,materials:Array)->void:
    var current:Material=first
    while current!=null and current not in materials:
        materials.append(current);current=current.next_pass
func source_state(scene:PackedScene,original:Node3D)->Dictionary:
    # Inspect the actual instantiated source independently of the production
    # SceneState collector, including hidden draw-pass mesh materials.
    var nodes:Array=[original];nodes.append_array(original.find_children("*","",true,false))
    var node_values:Dictionary={};var mesh_values:Dictionary={};var materials:Array=[]
    for node in nodes:
        var values:Dictionary=stored(node);node_values[str(original.get_path_to(node))]=values
        for value in values.values():
            if value is Material:material_chain(value,materials)
            elif value is Mesh and not mesh_values.has(value):
                var surfaces:Array=[]
                for surface in value.get_surface_count():
                    var material:Material=value.surface_get_material(surface)
                    surfaces.append(material);material_chain(material,materials)
                mesh_values[value]=surfaces
    var scene_values:Array=[];var state:SceneState=scene.get_state()
    for index in state.get_node_count():
        var properties:Dictionary={}
        for at in state.get_node_property_count(index):
            var value:Variant=state.get_node_property_value(index,at)
            properties[state.get_node_property_name(index,at)]=value
            if value is Mesh and not mesh_values.has(value):
                var surfaces:Array=[]
                for surface in value.get_surface_count():surfaces.append(value.surface_get_material(surface))
                mesh_values[value]=surfaces
        scene_values.append({"path":state.get_node_path(index),"type":state.get_node_type(index),"properties":properties})
    scene_materials(scene,materials)
    var material_values:Dictionary={};var shader_values:Dictionary={}
    for material in materials:
        material_values[material]=stored(material)
        if material is ShaderMaterial and material.shader!=null:shader_values[material.shader]=material.shader.code
    return {"nodes":node_values,"meshes":mesh_values,"materials":material_values,"shaders":shader_values,"scene":scene_values}
func scene_materials(scene:PackedScene,materials:Array)->void:
    # Exact source references, rather than resource_local_to_scene copies
    # produced by instantiation. The framebuffer below is the separate oracle.
    var state:SceneState=scene.get_state()
    for index in state.get_node_count():
        var nested:PackedScene=state.get_node_instance(index)
        if nested!=null:scene_materials(nested,materials)
        for at in state.get_node_property_count(index):
            var value:Variant=state.get_node_property_value(index,at)
            if value is Material:material_chain(value,materials)
            elif value is Mesh:
                for surface in value.get_surface_count():material_chain(value.surface_get_material(surface),materials)
func owner_state(handle:Dictionary)->Dictionary:
    var tracks:Array=[];var processes:Array=[]
    for entry in handle.tracks:
        var track:Dictionary=entry.track
        var value:Variant
        if track.kind=="bone":value=entry.target.get_bone_pose(int(track.property))
        elif entry.target is ShaderMaterial and track.kind!="node":value=entry.target.get_shader_parameter(track.property)
        else:value=entry.target.get(track.property)
        tracks.append(value.duplicate(true) if value is Array or value is Dictionary else value)
    for material in handle.process_materials+handle.path_materials:processes.append(stored(material))
    return {"age":handle.age,"slot":handle.slot,"clock":Baked._clock_image.get_pixel(handle.slot,0),"tracks":tracks,"processes":processes}
func cue(seconds:float)->Dictionary:
    return {"role":"flight","from":Vector3(-2,.5,0),"to":Vector3(2,.5,0),"bend":Vector2(0,.5),
        "begin":0.0,"launch":seconds*.2,"contact":seconds,"source_launch":seconds*.2,"source_contact":seconds,"scale":1.0,"end":seconds}
func sample(handle:Dictionary,seconds:float)->void:
    var flight:Dictionary=cue(float(handle.clip.seconds))
    Effects.place(handle,Playback.transform(flight,seconds,flight.from,1.0) if handle.bundle.moving else Transform3D.IDENTITY)
    Effects.sample(handle,seconds)
    if handle.bundle.moving:Baked.follow(handle,flight,seconds,func(at:float)->Transform3D:return Playback.transform(flight,at,flight.from,1.0))
    handle.root.show()

func clip_checks(id:String)->void:
    var clip:Dictionary=Effects.clip(id)
    if not check(not clip.is_empty() and Effects.choice(clip).kind=="recorded",id+": actual selected recorded source resolves"):return
    var bundle:Variant
    var deadline:int=Time.get_ticks_msec()+90000
    while Time.get_ticks_msec()<deadline:
        bundle=Baked.ready_for(clip,0,true)
        if bundle!=null:break
        await frame()
    if not check(bundle is Resource,id+": original recorded bundle and VAT textures admit"):return
    var original:Node3D=bundle.scene.instantiate()
    var before:Dictionary=source_state(bundle.scene,original)
    var sides:Array=[view(),view(),view(),view()]
    Baked._ensure_clock()
    var free_before:int=Baked._free_slots.size()
    var begin:int=Time.get_ticks_usec()
    # Raw recorded construction deliberately precedes material admission.
    var raw:Dictionary=Baked.make(sides[0].holder,bundle,clip,LAYER)
    var raw_ms:float=(Time.get_ticks_usec()-begin)/1000.0
    if not check(raw.error.is_empty(),id+": raw recorded constructor succeeds: "+raw.error):
        Effects.close(raw);original.free()
        for side in sides:side.viewport.free()
        return
    # A held playback has its own path/particle history. Its independent raw
    # oracle must follow that same prefix, rather than rewind the moving raw
    # oracle from a later time and compare two different trail histories.
    begin=Time.get_ticks_usec()
    var held_raw:Dictionary=Baked.make(sides[3].holder,bundle,clip,LAYER)
    var held_raw_ms:float=(Time.get_ticks_usec()-begin)/1000.0
    if not check(held_raw.error.is_empty(),id+": independent raw recorded constructor succeeds: "+held_raw.error):
        Effects.close(raw);Effects.close(held_raw);original.free()
        for side in sides:side.viewport.free()
        return
    var count_before:int=sides[0].holder.get_child_count()
    var slots_before:int=Baked._free_slots.size()
    var cache:Dictionary={};var admitted:Dictionary={"ready":false,"errors":[]}
    var fence_consumer:Dictionary={};var fence_witnessed:bool=false
    begin=Time.get_ticks_usec();deadline=Time.get_ticks_msec()+90000
    while Time.get_ticks_msec()<deadline:
        admitted=Effects.prepare([clip],cache,true)
        # Poll before post-draw: observe the real material worker's joined
        # packet while the native compiler fence still owns admission. A
        # second cache may borrow the programs, but not skip their fence.
        if not fence_witnessed and Effects.Admission.settling and cache.get("native_material_programs",{}).has(bundle):
            fence_witnessed=true
            check(Effects.Admission._material_job.is_empty(),id+": actual recorded program worker completed before native fence observation")
            check(not admitted.ready and admitted.pending>0 and admitted.errors.is_empty(),id+": original preparation consumer stays pending until actual native post-draw fence")
            var borrowed:Dictionary=Effects.prepare([clip],fence_consumer,true)
            check(fence_consumer.get("native_material_programs",{}).has(bundle),id+": second consumer borrows the actual worker-prepared source while its native fence is pending")
            check(Effects.Admission.settling and not borrowed.ready and borrowed.pending>0 and borrowed.errors.is_empty(),
                id+": borrowing prepared programs cannot bypass the actual native post-draw fence")
        if not admitted.errors.is_empty() or admitted.ready and not Effects.Admission.settling:break
        await process_frame
    var prepare_ms:float=(Time.get_ticks_usec()-begin)/1000.0
    check(fence_witnessed,id+": each actual recorded source witnesses worker completion before its native post-draw fence")
    check(admitted.ready and admitted.errors.is_empty(),id+": production recorded program preparation completes: "+str(admitted))
    check(sides[0].holder.get_child_count()==count_before and sides[1].holder.get_child_count()==0 and sides[2].holder.get_child_count()==0 and sides[3].holder.get_child_count()==1 \
        and Baked._free_slots.size()==slots_before,id+": program preparation creates no occurrence nodes or clock leases")
    var programs:Array[Material]=Baked.material_programs(bundle)
    var declared:Array=[];scene_materials(bundle.scene,declared)
    check(not declared.is_empty() and declared.all(func(material):return material in programs),
        id+": prepared programs include the original scene's exact material/mesh/pass/next-pass references")
    check(cache.get("native_material_programs",{}).has(bundle),id+": production admission acknowledges this actual recorded bundle")
    check(is_same(programs,Baked.material_programs(bundle)),id+": unchanged source retains its actual material program collection")
    check(source_state(bundle.scene,original)==before,id+": preparation preserves original scene, mesh, material and shader properties")
    if not admitted.ready or not admitted.errors.is_empty():
        Effects.close(raw);Effects.close(held_raw);original.free()
        for side in sides:side.viewport.free()
        return
    var second_cache:Dictionary={}
    var second_ready:Dictionary=Effects.prepare([clip],second_cache,true)
    check(second_ready.ready and second_cache.get("native_material_programs",{}).has(bundle),id+": another preparation consumer borrows this exact admitted bundle")
    var handles:Array=[raw,held_raw];var costs:Array=[]
    for at in [1,2]:
        begin=Time.get_ticks_usec()
        var made:Dictionary=Effects.make(sides[at].holder,clip,LAYER,0)
        costs.append((Time.get_ticks_usec()-begin)/1000.0)
        if check(made.error.is_empty(),id+": prepared occurrence "+str(at)+" constructs: "+made.error):handles.append(made)
        else:Effects.close(made)
    if handles.size()!=4:
        for handle in handles:Effects.close(handle)
        original.free()
        for side in sides:side.viewport.free()
        return
    var first:Dictionary=handles[2];var second:Dictionary=handles[3]
    check(first.effect_kind=="recorded" and second.effect_kind=="recorded" and is_same(raw.bundle,first.bundle) and is_same(first.bundle,second.bundle) and is_same(held_raw.bundle,second.bundle),
        id+": raw and prepared occurrences use the identical source bundle and recorded seed variant")
    check(first.root!=second.root and first.slot!=second.slot and raw.slot!=first.slot and raw.slot!=second.slot,id+": each occurrence owns a separate node tree and clock slot")
    check(handles.all(func(handle):return handles.filter(func(other):return handle.slot==other.slot or handle.root==other.root).size()==1),
        id+": both raw references and prepared occurrences retain four independent node/clock owners")
    var first_materials:Array=Baked.material_locations(first.root);var second_materials:Array=Baked.material_locations(second.root)
    for private_index in bundle.private_materials:
        var at:int=int(private_index)
        check(at<first_materials.size() and at<second_materials.size() and first_materials[at].material!=second_materials[at].material,
            id+": recorded material owner stays private at source index "+str(at))
    for at in first.process_materials.size():
        check(first.process_materials[at]!=second.process_materials[at] and first.process_materials[at]!=Baked._prototypes[bundle].systems[at],id+": particle process material remains occurrence-private")
        check(first.process_materials[at].get_shader_parameter("clock_slot")==first.slot and second.process_materials[at].get_shader_parameter("clock_slot")==second.slot,id+": process material addresses only its own clock texel")
    var comparisons:Array=[];var held_comparisons:Array=[];var maximum_visible:int=0
    for fraction in [.2,.45,.7]:
        var time:float=float(clip.seconds)*fraction
        sample(raw,time);sample(first,time);sample(held_raw,float(clip.seconds)*.3);sample(second,float(clip.seconds)*.3)
        await frame();await frame()
        var reference:Image=image(sides[0]);var actual:Image=image(sides[1])
        var compared:Dictionary=pixels(reference,actual);maximum_visible=maxi(maximum_visible,compared.visible_pixels)
        comparisons.append({"fraction":fraction,"pixels":compared})
        check(compared.different_pixels==0,id+": raw/prepared exact same-frame RGBA at source fraction "+str(fraction))
        var held_compared:Dictionary=pixels(image(sides[3]),image(sides[2]))
        held_comparisons.append({"peer_fraction":fraction,"pixels":held_compared})
        check(held_compared.different_pixels==0,id+": independent held raw/prepared exact RGBA with the same actual playback prefix at peer fraction "+str(fraction))
        if fraction==.45:
            reference.save_png(ProjectSettings.globalize_path(save_dir.path_join(id.replace("/","__")+"-raw.png")))
            actual.save_png(ProjectSettings.globalize_path(save_dir.path_join(id.replace("/","__")+"-prepared.png")))
    check(maximum_visible>0,id+": raw/prepared parity includes actual rendered source pixels")
    var held:Dictionary=owner_state(second)
    var raw_held:Dictionary=owner_state(held_raw)
    sample(raw,float(clip.seconds)*.8);sample(first,float(clip.seconds)*.8)
    check(owner_state(second)==held,id+": sampling the first occurrence changes none of the second owner's clock/track/material values")
    check(owner_state(held_raw)==raw_held,id+": moving raw/prepared peers change none of the held raw reference's clock/track/material values")
    await frame();await frame()
    var isolated:Dictionary=pixels(image(sides[3]),image(sides[2]))
    check(isolated.different_pixels==0,id+": independent second clock matches the raw constructor while the first plays another time")
    # Seek and loop use the same original source, not a newly generated event.
    sample(raw,float(clip.seconds)*.2);sample(first,float(clip.seconds)*.2)
    await frame();await frame()
    var rewound:Dictionary=pixels(image(sides[0]),image(sides[1]))
    check(rewound.different_pixels==0,id+": backward seek/loop preserves raw/prepared RGBA parity")
    check(source_state(bundle.scene,original)==before,id+": independent sampling and seeking preserve all original source properties")
    var roots:Array=handles.map(func(handle):return weakref(handle.root))
    for handle in handles:Effects.close(handle)
    check(Baked._free_slots.size()==free_before and roots.all(func(reference):return reference.get_ref()==null),id+": release returns every clock lease and frees all private occurrence nodes")
    check(source_state(bundle.scene,original)==before,id+": releasing occurrences preserves the reusable original source")
    evidence.append({"clip":id,"bundle":bundle.resource_path,"programs":programs.size(),"source_materials":before.materials.size(),
        "private_materials":bundle.private_materials.size(),"particle_systems":bundle.systems.size(),"raw_construction_ms":raw_ms,"held_raw_construction_ms":held_raw_ms,
        "preparation_ms":prepare_ms,"native_post_draw_fence_witnessed":fence_witnessed,"prepared_construction_ms":costs,"same_frame_comparisons":comparisons,"held_same_prefix_comparisons":held_comparisons,"independent_clock_pixels":isolated,"rewind_pixels":rewound})
    original.free()
    for side in sides:side.viewport.free()
    await frame()

func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(64,64)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    if not check(DisplayServer.get_name()!="headless" and RenderingServer.get_current_rendering_method()=="forward_plus","Actual Forward+/Vulkan native renderer is required"):
        quit(2);return
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--save="):save_dir=argument.trim_prefix("--save=")
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_dir))
    create_timer(270).timeout.connect(func():printerr("Recorded preparation native deadline");quit(2))
    var requested:String=Effects.requested;var background:bool=Baked.background_allowed
    Effects.set_requested("recorded");Baked.background_allowed=false
    for id in CLIPS:await clip_checks(id)
    Effects.set_requested(requested);Baked.background_allowed=background
    check(evidence.size()==3,"All three actual recorded source families reach native parity/isolation/release qualification")
    var result:Dictionary={"checks":checks,"failures":failures,"evidence":evidence,
        "scope":"Actual recorded source material-program admission and isolated raw/prepared framebuffer parity, private clocks/materials, seek/loop and release. Timings are diagnostic; no live frame-budget or artwork-acceptance claim."}
    FileAccess.open(save_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("NATIVE_RECORDED_PREPARATION ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
