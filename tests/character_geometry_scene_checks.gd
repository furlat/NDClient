extends "res://tests/native_2d_source_checks.gd"
## Actual prepared Crypt actor cells and disclosed lights against the existing
## independent native Canvas oracle. No light-table receiving implementation
## is copied into the reference, and the canonical recording is unchanged.
const Player=preload("res://play.tscn")
const FixturePublication=preload("res://tests/prepared_world_fixture.gd")
const Media=preload("res://presentation/media_warmup.gd")
const CATEGORIES=["Chest7","Chest14","Head15"]

func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);print("GEOMETRY_SCENE_FAIL ",label)

func publish_scene_lights(lights:Array,directionals:Array)->void:
    light_table.publish(lights,cookie_image,directionals)
    check(light_table.issues.is_empty(),"Every actually disclosed projected light reaches the receiving table")
    # Keep the old scene control's zero ambient and use native LDR storage.
    # The brightest-channel cap is a separate display policy, not an Omni law.
    RenderingServer.global_shader_parameter_set(&"light_ambient",0.0)
    RenderingServer.global_shader_parameter_set(&"light_cap",0.0)
    RenderingServer.global_shader_parameter_set(&"light_normals",false)

func native_directionals(view:SubViewport,sources:Array)->void:
    for source in sources:
        var lamp=DirectionalLight2D.new()
        lamp.rotation=atan2(source.direction.x,-source.direction.y)
        lamp.height=source.height;lamp.color=source.color;lamp.energy=source.energy
        lamp.enabled=source.enabled;lamp.shadow_enabled=false;view.add_child(lamp)

func source_fixture(scene:Node,entry:Dictionary)->Dictionary:
    var source:Dictionary=Geometry.record(entry.texture_path,entry.actor_layer.slot,scene.catalog_cache)
    check(not source.is_empty(),"Prepared actual "+entry.actor_layer.category+" has a delivered optical descriptor")
    if source.is_empty():return {}
    var profile:String=Geometry.effective_profile(source,str(entry.geometry_binding[5]))
    var normal_paths:Dictionary=Geometry.normal_paths(entry.texture_path,entry.actor_layer.slot,scene.catalog_cache).value
    check(normal_paths.has(profile),"Actual selected source profile has its own normal companion")
    if not normal_paths.has(profile):return {}
    var geometry_root:String=Geometry._root(source)
    var paths:Dictionary={"depth":geometry_root.path_join(source.files.depth),"normal":normal_paths[profile],
        "support":geometry_root.path_join(source.files.support),"normal_valid":geometry_root.path_join(source.files.normal_valid)}
    var descriptor:Dictionary=Geometry.BodySources.descriptor(entry.texture_path,entry.actor_layer.slot,scene.catalog_cache)
    var source_roles:Dictionary=descriptor.get("source_records",{}).get(profile,{}).get("roles",{})
    var owner:Dictionary=Media.physical(scene.media_warmup)
    var planes:Dictionary={};var residency:Dictionary={}
    for field in paths:
        var path:String=paths[field]
        var resident:Dictionary=owner.resident.get(path,{})
        var cpu_present:bool=scene.source_images.has(path)
        var cpu_needed:bool=Media._needs_cpu(owner,path)
        var prior_cpu_use:bool=resident.get("cpu_required",false)
        var retiring_cpu:bool=owner.cpu_release.has(path)
        check(scene.textures.has(path) and int(resident.get("gpu_bytes",0))>0,
            "Production "+entry.actor_layer.category+" retains the actual uploaded "+field+" companion")
        check(source_roles.has(path) and int(source_roles[path][1])==0,
            "The ordinary authored "+field+" selector needs GPU bytes without requiring CPU pixels")
        check(cpu_present==(int(resident.get("cpu_bytes",0))>0) and (not cpu_needed or cpu_present) \
            and (not cpu_present or cpu_needed or prior_cpu_use or retiring_cpu),
            "Actual shared "+field+" CPU pixels have current, retained-use or queued-retirement ownership and exact accounting")
        residency[field]={"path":path,"cpu_present":cpu_present,"cpu_needed":cpu_needed,
            "prior_cpu_use":prior_cpu_use,"retiring_cpu":retiring_cpu,
            "roles":owner.interests.get(path,[]).duplicate(),"cpu_bytes":resident.get("cpu_bytes",0),"gpu_bytes":resident.get("gpu_bytes",0)}
        check(entry.material.get_shader_parameter(Geometry.PARAMETERS[field])==scene.textures.get(path),
            "Actual "+field+" source texture is bound to the prepared actor material")
        planes[field]=Image.load_from_file(path)
        check(planes[field]!=null and not planes[field].is_empty(),"Reference can independently decode delivered "+field)
        if planes[field]==null or planes[field].is_empty():return {}
    check(entry.geometry_status==source.status and entry.material.get_shader_parameter("has_component_geometry") \
        and entry.material.get_shader_parameter("use_component_depth") and entry.material.get_shader_parameter("use_component_normals"),
        "Actual prepared entry preserves the declared geometry status and enabled depth/normal bindings")
    check(entry.material.get_shader_parameter("component_reconstruction_origin")==Vector2(source.optical_camera.origin[0],source.optical_camera.origin[1]) \
        and is_equal_approx(entry.material.get_shader_parameter("component_elevation"),deg_to_rad(source.optical_camera.elevation_degrees)) \
        and entry.material.get_shader_parameter("component_depth_range")==Vector2(source.depth_range[0],source.depth_range[1]),
        "Delivered optical camera and byte-depth range survive ordinary preparation")
    if source.get("optical_ground_pixels")!=null:
        check(entry.geometry_ground_pixels==float(source.optical_ground_pixels),"Authored optical ground, including exact zero, is preserved")
    check(scene.source_images.has(entry.texture_path),"Actual color alpha remains available to original actor picking")
    if not scene.source_images.has(entry.texture_path):return {}
    var original:Image=scene.source_images[entry.texture_path]
    var uv:Vector4=entry.material.get_shader_parameter("frame_uv")
    var cell:Vector2i=Vector2i(entry.cell)
    var offset:Vector2i=Vector2i(roundi(uv.x*original.get_width()),roundi(uv.y*original.get_height()))
    var colour:Image=original.get_region(Rect2i(offset,cell))
    var decoded:Image=Image.create(cell.x,cell.y,false,Image.FORMAT_RGBAF)
    var supported:int=0;var pixels:int=0;var picked:bool=false
    var scale_x:float=float(entry.placement.get("scale_x",1.0))
    check(absf(scale_x)>.00001,"Actual original source has a nonsingular registered horizontal scale")
    if absf(scale_x)<=.00001:return {}
    for y in cell.y:
        for x in cell.x:
            var at:Vector2i=offset+Vector2i(x,y)
            var n:Vector3=Vector3(0,0,1)
            var packed:Color=planes.normal.get_pixelv(at)
            var valid:bool=planes.support.get_pixelv(at).r>.5 and planes.normal_valid.get_pixelv(at).r>.5 \
                and planes.depth.get_pixelv(at).a>.5 and packed.a>.5
            if valid:
                # Delivered numeric RGB normal, inverse registered X scale,
                # and source screen-up to native Canvas screen-down.
                n=Vector3((packed.r*2-1)/scale_x,-(packed.g*2-1),packed.b*2-1).normalized()
                if colour.get_pixel(x,y).a>0:supported+=1
            decoded.set_pixel(x,y,Color(n.x,n.y,n.z,1))
            if colour.get_pixel(x,y).a<=0:continue
            pixels+=1
            if not picked:
                var local:Vector3=Vector3((x+.5-entry.pivot.x)*entry.scale/Placement.PIXELS_PER_UNIT,
                    (entry.pivot.y-y-.5)*entry.scale/Placement.PIXELS_PER_UNIT,0)
                check(scene.pick_actor(scene.camera.unproject_position(entry.node.global_transform*local))==entry.placement.id,
                    "Production "+entry.actor_layer.category+" still picks its original source color alpha")
                picked=true
    check(pixels>0 and supported>0,"Actual original cell contains painted and delivered-normal receiver pixels")
    # The original initialization is an ordinary outfit, not a palette/film
    # study. Refuse rather than clearing an actual selected material operation.
    var material:ShaderMaterial=entry.material
    var wall_opacity:Variant=material.get_shader_parameter("wall_opacity")
    if wall_opacity==null:
        # ShaderMaterial returns only overrides. Read the actual shader's
        # declared value rather than inventing a neutral test-only override.
        wall_opacity=RenderingServer.shader_get_parameter_default(material.shader.get_rid(),&"wall_opacity")
    check(not material.get_shader_parameter("effect_palette_enabled") and not material.get_shader_parameter("condition_film_enabled") \
        and not material.get_shader_parameter("native_body_enabled") and not material.get_shader_parameter("body_surface_enabled") \
        and not material.get_shader_parameter("body_aperture_enabled") and material.get_shader_parameter("flash_strength")==0.0 \
        and wall_opacity==1.0 and material.get_shader_parameter("condition_tint")==Vector3.ONE and material.get_shader_parameter("condition_saturation")==1.0 \
        and material.get_shader_parameter("condition_brightness")==1.0 and material.get_shader_parameter("condition_alpha")==1.0,
        "Recorded initialization provides an unchanged ordinary outfit source for the independent color oracle")
    var tint:Vector3=material.get_shader_parameter("tint")
    return {"id":entry.placement.id+"/"+entry.actor_layer.category,"colour":colour,"normals":decoded,
        "tint":Color(tint.x,tint.y,tint.z,material.get_shader_parameter("layer_alpha")),"visible":1.0,
        "supported":supported,"source_pixels":pixels,"profile":profile,"paths":paths,"uv":uv,"residency":residency,"wall_opacity":wall_opacity}

func compare_entry(scene:Node,entry:Dictionary)->Dictionary:
    var fixture:Dictionary=source_fixture(scene,entry)
    if fixture.is_empty():return {}
    var view:SubViewport=lit_view(Vector2i(128,128),scene.camera.global_basis)
    var camera:Camera3D=view.get_meta("camera")
    var node:MeshInstance3D=MeshInstance3D.new();node.mesh=entry.node.mesh
    node.transform=entry.node.global_transform;node.custom_aabb=entry.node.custom_aabb
    var material:ShaderMaterial=entry.material.duplicate();node.material_override=material;view.add_child(node)
    camera.size=128.0*entry.scale/Placement.PIXELS_PER_UNIT
    camera.position=node.transform*node.mesh.center_offset+camera.basis.z*10.0
    scene.source_lighting.project(camera)
    var lights:Array=scene.source_lighting.canvas_sources().filter(func(source):return source.enabled)
    var directionals:Array=scene.source_lighting.canvas_directionals().filter(func(source):return source.enabled)
    check(not lights.is_empty(),"Actual disclosed Crypt emitters are available at the isolated source camera")
    publish_scene_lights(lights,directionals)
    var half:Vector2=node.mesh.size*.5;var center:Vector3=node.mesh.center_offset
    var a:Vector2=camera.unproject_position(node.transform*(center+Vector3(-half.x,half.y,0)))
    var b:Vector2=camera.unproject_position(node.transform*(center+Vector3(half.x,half.y,0)))
    var c:Vector2=camera.unproject_position(node.transform*(center+Vector3(-half.x,-half.y,0)))
    var transform:Transform2D=Transform2D(b-a,c-a,a)
    var reference:SubViewport=reference_page(fixture,transform,true,lights,view.size)
    reference.get_child(0).color=Color(0,0,0,1)
    native_directionals(reference,directionals)
    var actual:Image=await capture(view)
    var straight:Image=await capture(reference)
    var expected:Image=linear_alpha_reference(straight)
    var result:Dictionary=compare(actual,expected)
    var rounding_flips:int=0
    for y in actual.get_height():
        for x in actual.get_width():
            if actual.get_pixel(x,y).a8==expected.get_pixel(x,y).a8:continue
            var uv:Vector2=transform.affine_inverse()*(Vector2(x,y)+Vector2(.5,.5))
            if uv.x<0 or uv.y<0 or uv.x>=1 or uv.y>=1:continue
            var source:Color=fixture.colour.get_pixelv(Vector2i((uv*Vector2(fixture.colour.get_size())).floor()))
            var stored:float=source.a*fixture.tint.a*255.0
            if absi(actual.get_pixel(x,y).a8-expected.get_pixel(x,y).a8)==1 and absf(stored-floorf(stored)-.5)<.05:rounding_flips+=1
    check(result.alpha_mismatches==rounding_flips,"Production "+entry.actor_layer.category+" preserves independent native source alpha, apart from named half-byte target rounding")
    check(result.maximum_byte_error<=3,"Production "+entry.actor_layer.category+" matches independent decoded native Canvas receiving within the original three-byte limit: "+str(result))
    check(has_source_colour(actual),"Native light comparison contains actual rendered receiver pixels")
    var name:String=entry.actor_layer.category
    actual.save_png("res://.captures/character-geometry/actual-"+name+".png")
    expected.save_png("res://.captures/character-geometry/cpu-"+name+".png")
    material.set_shader_parameter("use_component_depth",false)
    (await capture(view)).save_png("res://.captures/character-geometry/depth-off-"+name+".png")
    material.set_shader_parameter("has_component_geometry",false)
    (await capture(view)).save_png("res://.captures/character-geometry/flat-"+name+".png")
    result.merge({"category":name,"actor":entry.placement.id,"original_pixels":fixture.source_pixels,"supported":fixture.supported,
        "profile":fixture.profile,"source":entry.texture_path,"uv":str(fixture.uv),"paths":fixture.paths,
        "residency":fixture.residency,"effective_wall_opacity":fixture.wall_opacity,
        "alpha_half_byte_rounding_flips":rounding_flips,"lights":lights.map(func(source):return source.id),
        "directionals":directionals.map(func(source):return source.id)})
    reference.queue_free();view.queue_free();await process_frame
    return result

func has_source_colour(image:Image)->bool:
    for y in image.get_height():
        for x in image.get_width():
            var colour:Color=image.get_pixel(x,y)
            if colour.r+colour.g+colour.b>.001:return true
    return false

func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000)
    var scene=Player.instantiate();scene.timeline.paused=true;root.add_child(scene)
    var opened:Dictionary=FixturePublication.open(scene)
    check(opened.ok,"Explicit durable original schema16 Crypt/Door recording opens")
    var admitted:bool=false
    if opened.ok:admitted=await FixturePublication.initial_ready(scene)
    check(admitted and scene.playback_prepared() and scene.presentation_errors.is_empty(),
        "Actual original world, actors and exact companion resources finish prepared publication before capture")
    if not admitted or not scene.playback_prepared():
        scene.session.close();scene.queue_free();await process_frame;quit(1);return
    scene.session.close();scene.set_process(false);scene.hud.hide();scene.grid_visible=false
    var canonical:PackedByteArray=var_to_bytes(scene.timeline.state)
    scene._sample_actors();scene.update_wall_visibility();scene._sort_draws()
    var entries:Array=scene.actor_entries.filter(func(entry):return entry.get("actor_layer",{}).get("category","") in CATEGORIES and entry.node.visible)
    DirAccess.make_dir_recursive_absolute("res://.captures/character-geometry")
    await process_frame;await process_frame;await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://.captures/character-geometry/actual-crypt.png")
    scene.hide();scene.publishes_receiving=false
    var one:Image=Image.create(1,1,false,Image.FORMAT_RGBA8);one.fill(Color.WHITE);white=ImageTexture.create_from_image(one)
    reference_shader=Shader.new();reference_shader.code=REFERENCE
    var found:Dictionary={};var rows:Array=[]
    for entry in entries:
        found[entry.actor_layer.category]=true
        var result:Dictionary=await compare_entry(scene,entry)
        if not result.is_empty():rows.append(result)
    check(CATEGORIES.all(func(category):return found.has(category)) and rows.size()>=CATEGORIES.size(),
        "Actual Crypt contains every original Chest7, Chest14 and Head15 scene receiver duty")
    check(var_to_bytes(scene.timeline.state)==canonical,"Independent optical comparisons never mutate the actual original canonical state")
    var report:Dictionary={"checks":checks,"failures":failures,"actual_receiver_comparisons":rows,
        "camera_basis":str(scene.camera.basis),"scope":"Explicit authentic Crypt initialization through current prepared actor publication. Production material and actual source-profile normal companions versus existing independent direct native PointLight2D/DirectionalLight2D Canvas oracle, exact actual projected cookies/energy/placement and zero ambient. Original RGB tolerance three bytes; alpha half-byte target rounding counted separately. Retired Omni/depth receiving law is not asserted: ordinary lighting now uses painted-plane Canvas receiving. Depth/status/optical registration/GPU companion bindings remain exact source checks; ordinary source roles remain GPU-only while shared CPU residency follows actual current/retained-use/retirement ownership. Shader defaults are read from the actual program without changing material operands. Source pixels and canonical state unchanged. No artwork acceptance or live backend claim."}
    FileAccess.open("res://generated/character_geometry_scene_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("CHARACTER_GEOMETRY_SCENE_CHECKS ",JSON.stringify(report))
    scene.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
