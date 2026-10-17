extends Node
## Actual renderer boundary checks. The small coloured probe is a test surface,
## not an authored spell replacement; source light checks use Factory nodes.
const FX_LAYER=1<<19
const Placement=preload("res://placement.gd")
var checks:=0
var failures:Array=[]
var observations:Array=[]
var images:Dictionary={}
var probe:MeshInstance3D

func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);push_error(label)

func frame()->void:
    await get_tree().process_frame
    await RenderingServer.frame_post_draw

func settled()->void:
    # Actor/floor receiving pages, their spatial output, then final viewport.
    await frame();await frame();await frame()

func image(texture:Texture2D)->Image:
    var id=texture.get_rid()
    if not images.has(id):images[id]=texture.get_image()
    return images[id]

func material(code:String)->ShaderMaterial:
    var shader=Shader.new();shader.code=code
    var value=ShaderMaterial.new();value.shader=shader
    return value

func pause(world:Node)->void:
    world.playing=false;world.loop=false;world.set_process(false)

func select(world:Node,id:String)->void:
    for index in world.spells.size():
        if world.spells[index].spell_id==id:
            world.select_spell(index);pause(world);return
    check(false,"Missing fixture spell: "+id)

func sample(world:Node,seconds:float)->void:
    while world.elapsed<seconds:
        await get_tree().process_frame
        world.elapsed=minf(seconds,world.elapsed+1./60.)
        world._sample_frame(1./60.);await RenderingServer.frame_post_draw
    await settled()

func save(world:Node,name:String)->void:
    world.get_viewport().get_texture().get_image().save_png("res://.captures/scene-integration/"+name+".png")

func screen_mask(world:Node,id:String)->Dictionary:
    var opaque={};var supported={};var rectangle=Rect2i();var first=true
    var screen_size:Vector2i=world.effect_layer.viewport.size
    for entry in world.visual_actors[id].entries:
        if entry.role=="shadow" or not entry.node.visible:continue
        if not entry.actor_layer.get("effect",{}).is_empty():continue
        var source:Texture2D=entry.material.get_shader_parameter("sheet")
        var colour=image(source)
        var cell:Vector4=entry.material.get_shader_parameter("frame_uv")
        var has_geometry:bool=entry.material.get_shader_parameter("has_component_geometry")
        var support:Image=image(entry.material.get_shader_parameter("component_support")) if has_geometry else null
        var depth:Image=image(entry.material.get_shader_parameter("component_depth")) if has_geometry else null
        var mesh:QuadMesh=entry.node.mesh
        var transform:Transform3D=entry.node.global_transform
        var start:Vector2=world.camera.unproject_position(transform*(mesh.center_offset+Vector3(-mesh.size.x*.5,mesh.size.y*.5,0)))
        var end:Vector2=world.camera.unproject_position(transform*(mesh.center_offset+Vector3(mesh.size.x*.5,-mesh.size.y*.5,0)))
        var lo=Vector2i(start.min(end).floor()).max(Vector2i.ZERO)
        var hi=Vector2i(start.max(end).ceil()).min(screen_size)
        for y in range(lo.y,hi.y):
            for x in range(lo.x,hi.x):
                var uv=(Vector2(x+.5,y+.5)-start)/(end-start)
                var source_uv=Vector2(cell.x,cell.y)+uv*Vector2(cell.z,cell.w)
                var pixel=Vector2i((source_uv*Vector2(colour.get_size())).floor()).clamp(Vector2i.ZERO,colour.get_size()-Vector2i.ONE)
                if colour.get_pixelv(pixel).a<=.5:continue
                var at=Vector2i(x,y);opaque[at]=true
                rectangle=Rect2i(at,Vector2i.ONE) if first else rectangle.expand(at)
                first=false
                if has_geometry and support.get_pixelv(pixel).r>.5 and depth.get_pixelv(pixel).a>.5:supported[at]=true
    return {"opaque":opaque,"supported":supported,"rect":rectangle}

func packed_depth(value:Color)->float:
    return (roundf(value.r*255.)*65536.+roundf(value.g*255.)*256.+roundf(value.b*255.))/16777215.

func nontransparent_pixels(value:Image)->int:
    var count=0
    for y in value.get_height():
        for x in value.get_width():
            if value.get_pixel(x,y).a!=0.0:count+=1
    return count

func point_at_depth(camera:Camera3D,pixel:Vector2i,depth:float)->Vector3:
    # Orthographic reversed-Z device depth. This is camera projection math;
    # the packet reconstruction stays entirely inside the renderer under test.
    var at=Vector2(pixel)+Vector2(.5,.5)
    var distance=lerpf(camera.far,camera.near,depth)
    return camera.project_ray_origin(at)+camera.project_ray_normal(at)*(distance-camera.near)

func interior(mask:Dictionary,pixel:Vector2i)->bool:
    for offset in [Vector2i.ZERO,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
        if not mask.has(pixel+offset):return false
    return true

func selected_pixels(mask:Dictionary,depth:Image,ground:float,camera:Camera3D)->Array:
    var result:Array=[]
    var rect:Rect2i=mask.rect
    for fraction in [.2,.5,.8]:
        var aim=Vector2(rect.position)+Vector2(rect.size)*Vector2(.5,fraction)
        var best=Vector2i(-1,-1);var score=INF
        for pixel in mask.supported:
            if not interior(mask.opaque,pixel):continue
            var value=depth.get_pixelv(pixel)
            if value.a<.5:continue
            var point=point_at_depth(camera,pixel,packed_depth(value))
            if point.y<ground+.12:continue
            var distance=Vector2(pixel).distance_squared_to(aim)
            if distance<score:score=distance;best=pixel
        if best.x>=0 and best not in result:result.append(best)
    return result

func transparent_pixel(mask:Dictionary)->Vector2i:
    var rect:Rect2i=mask.rect
    # Prefer an interior gap, then a transparent contour pixel inside the sprite
    # bounding box. Both must have opaque source pixels nearby on the same row.
    var fallback=Vector2i(-1,-1)
    for y in range(rect.position.y+2,rect.position.y+int(rect.size.y*.75)):
        for x in range(rect.position.x+2,rect.end.x-2):
            var at=Vector2i(x,y)
            if mask.opaque.has(at) or mask.opaque.has(at+Vector2i.LEFT) or mask.opaque.has(at+Vector2i.RIGHT):continue
            var left=false;var right=false
            for distance in range(2,13):
                left=left or mask.opaque.has(at+Vector2i(-distance,0))
                right=right or mask.opaque.has(at+Vector2i(distance,0))
            if left and right:return at
            if (left or right) and fallback.x<0:fallback=at
    return fallback

func put_probe(world:Node,point:Vector3,transparent:bool=false)->Vector2i:
    var camera:Camera3D=world.camera
    var ppu=camera.unproject_position(point+camera.global_basis.x).distance_to(camera.unproject_position(point))
    var mesh:QuadMesh=probe.mesh;mesh.size=Vector2.ONE*3./ppu
    probe.global_transform=Transform3D(camera.global_basis,point)
    probe.material_override=material("shader_type spatial;render_mode unshaded,cull_disabled;void fragment(){ALBEDO=vec3(1.,0.,0.);"+("ALPHA=.8;" if transparent else "")+"}")
    probe.show()
    return Vector2i(camera.unproject_position(point).floor())

func probe_pixel(world:Node,pixel:Vector2i)->Color:
    return world.effect_layer.viewport.get_texture().get_image().get_pixelv(pixel)

func character_occlusion(world:Node,quarter:int)->void:
    var view_label="View%d zoom %.2f"%[quarter,world.camera.size]
    var mask=screen_mask(world,"caster")
    # Read the actual actor depth without floor depth hiding a below-ground
    # reconstruction. Restore floors before testing the composed scene.
    for floor in world.native_support.floors.values():floor.hide()
    await frame()
    var depth:Image=world.native_support.viewport.get_texture().get_image()
    for floor in world.native_support.floors.values():floor.show()
    await frame()
    var ground:float=world.get_node("Caster").position.y
    var pixels=selected_pixels(mask,depth,ground,world.camera)
    var unsupported=0
    for pixel in mask.opaque:
        if not mask.supported.has(pixel):unsupported+=1
    var sole_height=INF
    for pixel in mask.supported:
        if pixel.y<mask.rect.end.y-mask.rect.size.y*.1:continue
        var value=depth.get_pixelv(pixel)
        if value.a>.5:sole_height=minf(sole_height,point_at_depth(world.camera,pixel,packed_depth(value)).y-ground)
    var tolerance=.01
    for entry in world.visual_actors.caster.entries:
        if not entry.material.get_shader_parameter("has_component_geometry"):continue
        var units:float=entry.material.get_shader_parameter("component_units")
        var bounds:Vector2=entry.material.get_shader_parameter("component_depth_range")
        var elevation:float=entry.material.get_shader_parameter("component_elevation")
        tolerance=maxf(tolerance,units*(2.+absf(bounds.y-bounds.x)/192.*absf(sin(elevation))))
    check(is_finite(sole_height) and absf(sole_height)<=tolerance,view_label+": reconstructed soles meet authored floor within packet pixel precision")
    observations.append({"view":quarter,"zoom":world.camera.size,"actor_opaque_pixels":mask.opaque.size(),"actor_supported_pixels":mask.supported.size(),"unsupported_opaque_pixels":unsupported,"probe_pixels":pixels,"lowest_sole_height":sole_height,"sole_tolerance":tolerance})
    check(pixels.size()==3,view_label+": body/head/leg have three supported interior samples")
    for index in pixels.size():
        var pixel:Vector2i=pixels[index]
        var point=point_at_depth(world.camera,pixel,packed_depth(depth.get_pixelv(pixel)))
        for transparent in [false,true]:
            var label="%s %s actor sample%d"%[view_label,"transparent" if transparent else "opaque",index]
            var at=put_probe(world,point+world.camera.global_basis.z*.1,transparent)
            await frame()
            var colour=probe_pixel(world,at)
            check(colour.r>.7 and colour.a>.5,label+": native effect in front survives")
            at=put_probe(world,point-world.camera.global_basis.z*.1,transparent)
            await frame()
            colour=probe_pixel(world,at)
            check(colour.a<.01,label+": native effect behind is occluded")
    if not pixels.is_empty():
        var gap=transparent_pixel(mask)
        check(gap.x>=0,view_label+": source sprite has a transparent pixel to inspect")
        if gap.x>=0:
            var near_depth=packed_depth(depth.get_pixelv(pixels[0]))
            var point=point_at_depth(world.camera,gap,near_depth)-world.camera.global_basis.z*.1
            var at=put_probe(world,point,true);await frame()
            check(probe_pixel(world,at).a>.5,view_label+": transparent sprite gap does not become a solid quad")
            save(world,"q%d-zoom%.2f-transparent-gap"%[quarter,world.camera.size])
    probe.hide();await frame()

func rendered_owner_alignment(world:Node,label:String)->void:
    # Reuse the actual final materials in an actor-only view. This is an image
    # oracle, not another implementation of the source texel address calculation.
    var layer=1<<12
    var original_mask:int=world.camera.cull_mask
    world.camera.cull_mask&=~layer
    var viewport=SubViewport.new();viewport.size=world.native_support.viewport.size
    viewport.world_3d=world.get_world_3d();viewport.transparent_bg=true
    viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    world.add_child(viewport)
    var camera=Camera3D.new();camera.cull_mask=layer;viewport.add_child(camera)
    camera.global_transform=world.camera.global_transform
    for property in ["projection","keep_aspect","size","near","far"]:camera.set(property,world.camera.get(property))
    var copies:Array=[]
    for visual in world.visual_actors.values():
        for entry in visual.entries:
            if not entry.node.visible or entry.role=="shadow" or not entry.actor_layer.get("effect",{}).is_empty():continue
            var node=MeshInstance3D.new();node.mesh=entry.node.mesh
            node.material_override=entry.node.get_active_material(0);node.layers=layer
            node.sorting_use_aabb_center=entry.node.sorting_use_aabb_center
            node.sorting_offset=entry.node.sorting_offset
            node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            world.add_child(node);node.global_transform=entry.node.global_transform;copies.append(node)
    for floor in world.native_support.floors.values():floor.hide()
    await settled()
    var painted:Image=viewport.get_texture().get_image()
    var support:Image=world.native_support.viewport.get_texture().get_image()
    var missing=0;var outside=0;var opaque=0;var valid_depth=0
    for y in painted.get_height():
        for x in painted.get_width():
            var source_alpha=painted.get_pixel(x,y).a
            var depth=support.get_pixel(x,y)
            if source_alpha==1.0:
                opaque+=1
                if depth.a<.99:missing+=1
            if depth.a>.99 and source_alpha<.99:outside+=1
            if depth.a>.99 and packed_depth(depth)>0:valid_depth+=1
    check(opaque>0,label+": original received materials render opaque actor pixels")
    check(missing==0 and outside==0,label+": rendered opaque ownership and support coverage align pixel for pixel")
    observations.append({"alignment":label,"painted_opaque_pixels":opaque,"supported_depth_pixels":valid_depth,"missing_owner_pixels":missing,"support_outside_painted_owner_pixels":outside})
    for floor in world.native_support.floors.values():floor.show()
    for node in copies:node.free()
    viewport.free();world.camera.cull_mask=original_mask
    await frame()

func fractional_zoom_checks(world:Node)->void:
    var original_size:float=world.camera.size
    for size in [6.35,8.7]:
        world.camera.size=size
        for quarter in 4:
            while world.quarter!=quarter:world.rotate_view(1)
            world._sample_frame(0);await settled()
            var label="View%d zoom %.2f"%[quarter,size]
            check(nontransparent_pixels(world.effect_layer.viewport.get_texture().get_image())==0,label+": actual compositor produces zero alpha when no effect is active")
            await character_occlusion(world,quarter)
            await rendered_owner_alignment(world,label)
    world.camera.size=original_size;world._sample_frame(0);await settled()

func floor_occlusion(world:Node,point:Vector3,label:String)->void:
    for height in [.12,-.12]:
        var at=put_probe(world,point+Vector3.UP*height,true);await frame()
        var colour=probe_pixel(world,at)
        check(colour.a>.5 if height>0 else colour.a<.01,label+(": above support visible" if height>0 else ": below support occluded"))
    probe.hide();await frame()
    var pixel=Vector2i(world.camera.unproject_position(point).floor())
    var depth:Image=world.native_support.viewport.get_texture().get_image()
    var reconstructed=point_at_depth(world.camera,pixel,packed_depth(depth.get_pixelv(pixel)))
    check(absf(reconstructed.y-point.y)<.01,label+": captured depth agrees with authored tile height")

func depth_reader(world:Node)->void:
    var at=put_probe(world,Vector3(0,1,0),true)
    probe.material_override=material("shader_type spatial;render_mode unshaded,depth_test_disabled;uniform sampler2D native_depth:hint_depth_texture,filter_nearest;uniform sampler2D expected_depth:filter_nearest;void fragment(){vec4 p=texture(expected_depth,SCREEN_UV);vec3 b=round(p.rgb*255.);float expected=dot(b,vec3(65536.,256.,1.))/16777215.;float actual=texture(native_depth,SCREEN_UV).r;ALBEDO=p.a>.5&&abs(actual-expected)<=4./16777215.?vec3(0.,1.,0.):vec3(1.,0.,0.);ALPHA=1.;}")
    probe.material_override.set_shader_parameter("expected_depth",world.native_support.viewport.get_texture())
    await frame()
    var colour=probe_pixel(world,at)
    check(colour.g>.8 and colour.r<.1,"Native hint_depth_texture reads the same published receiver depth")
    probe.hide();await frame()

func changed(before:Image,after:Image,pixels:Dictionary)->Dictionary:
    var count=0;var peak=0.0
    for pixel in pixels:
        if pixel.x<0 or pixel.y<0 or pixel.x>=before.get_width() or pixel.y>=before.get_height():continue
        var a=before.get_pixelv(pixel);var b=after.get_pixelv(pixel)
        var delta=maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))
        peak=maxf(peak,delta)
        if delta>=2./255.:count+=1
    return {"pixels":count,"peak":peak}

func floor_pixels(world:Node,centre:Vector3,exclude:Dictionary)->Dictionary:
    var polygon=PackedVector2Array()
    for offset in [Vector3(-.65,0,-.65),Vector3(.65,0,-.65),Vector3(.65,0,.65),Vector3(-.65,0,.65)]:polygon.append(world.camera.unproject_position(centre+offset))
    var bounds=Rect2(polygon[0],Vector2.ZERO)
    for point in polygon:bounds=bounds.expand(point)
    var result={}
    for y in range(floori(bounds.position.y),ceili(bounds.end.y)):
        for x in range(floori(bounds.position.x),ceili(bounds.end.x)):
            var pixel=Vector2i(x,y)
            if not exclude.has(pixel) and Geometry2D.is_point_in_polygon(Vector2(pixel)+Vector2(.5,.5),polygon):result[pixel]=true
    return result

func sync_lights(world:Node)->void:
    world.source_lighting.sample_handles(world.handles)
    world._sync_native_lighting();world._sort_draws()

func sheet_pixel(entry:Dictionary,local:Vector2i)->Vector2i:
    var uv:Vector4=entry.material.get_shader_parameter("frame_uv")
    var sheet:Texture2D=entry.material.get_shader_parameter("sheet")
    return Vector2i(Vector2(uv.x,uv.y)*Vector2(sheet.get_size()))+local

func opaque_layers(layers:Array,local:Vector2i)->Array:
    var result:Array=[]
    for entry in layers:
        if image(entry.material.get_shader_parameter("sheet")).get_pixelv(sheet_pixel(entry,local)).a==1.0:result.append(entry)
    return result

func supported_source(world:Node,entry:Dictionary,local:Vector2i)->bool:
    if not entry.material.get_shader_parameter("has_component_geometry"):return false
    var solid:Texture2D=world.native_support.solid_masks.get(entry.texture_path)
    if solid==null:return false
    var at=sheet_pixel(entry,local)
    return image(solid).get_pixelv(at).r>.5 and image(entry.material.get_shader_parameter("component_support")).get_pixelv(at).r>.5 and image(entry.material.get_shader_parameter("component_depth")).get_pixelv(at).a>.5

func source_screen_position(world:Node,entry:Dictionary,local:Vector2i)->Vector2:
    var mesh:QuadMesh=entry.node.mesh
    var cell:Vector2=entry.get("geometry_cell_size",entry.cell)
    var uv=(Vector2(local)+Vector2(.5,.5))/cell
    var local_point=mesh.center_offset+Vector3((uv.x-.5)*mesh.size.x,(.5-uv.y)*mesh.size.y,0.)
    return world.camera.unproject_position(entry.node.global_transform*local_point)

func source_screen(world:Node,entry:Dictionary,local:Vector2i)->Vector2i:
    return Vector2i(source_screen_position(world,entry,local).floor())

func source_expected_depth(world:Node,entry:Dictionary,local:Vector2i)->float:
    # Independent numeric oracle: decode the delivered optical height, then
    # intersect the camera ray with that height. Never sample the support shader
    # or take the nearest depth from hidden outfit components as expected output.
    var encoded=image(entry.material.get_shader_parameter("component_depth")).get_pixelv(sheet_pixel(entry,local)).r
    var bounds:Vector2=entry.material.get_shader_parameter("component_depth_range")
    var optical_depth=lerpf(bounds.x,bounds.y,(encoded*255.-32.)/192.)
    var origin:Vector2=entry.material.get_shader_parameter("component_reconstruction_origin")
    var elevation:float=entry.material.get_shader_parameter("component_elevation")
    var units:float=entry.material.get_shader_parameter("component_units")
    var height=entry.node.global_position.y+((origin.y-local.y-.5)*cos(elevation)+optical_depth*sin(elevation)-float(entry.get("geometry_ground_pixels",19.0)))*units
    var camera:Camera3D=world.camera
    # Packet samples are defined at source texel centres; rounding this ray to
    # an output pixel would add an unrelated subpixel projection error.
    var at=source_screen_position(world,entry,local)
    var start=camera.project_ray_origin(at);var direction=camera.project_ray_normal(at)
    var point=start+direction*((height-start.y)/direction.y)
    var distance=(camera.global_position-point).dot(camera.global_basis.z)
    return (camera.far-distance)/(camera.far-camera.near)

func outfit_owner_depth(world:Node)->void:
    select(world,"fire_bolt")
    while world.quarter!=0:world.rotate_view(1)
    var rig:Dictionary=world.rigs["neuroclient.modular"]
    var origin:Vector2=Vector2(world.get_node("Caster").position.x,world.get_node("Caster").position.z)
    var facing=Vector2.ZERO
    for direction in [Vector2(1,0),Vector2(1,1),Vector2(0,1),Vector2(-1,1),Vector2(-1,0),Vector2(-1,-1),Vector2(0,-1),Vector2(1,-1)]:
        if world._facing(direction)=="SW":facing=direction
    check(not facing.is_zero_approx(),"Outfit regression resolves the authored SW facing")
    world.displayed_samples.caster={"clip":"Attack5","source_seconds":7./float(rig.clips.Attack5.fps)+.00001,
        "occurrence":"outfit-owner-depth-check","from_position":[origin.x,origin.y],
        "target_position":[origin.x+facing.x,origin.y+facing.y]}
    world.displayed_components=[]
    world._sample_actors();sync_lights(world)
    world.native_support.sync(world.static_entries,world.visual_actors,world.camera)
    await settled()
    var layers:Array=[]
    for entry in world.visual_actors.caster.entries:
        if entry.node.visible and entry.role!="shadow" and entry.actor_layer.get("effect",{}).is_empty():layers.append(entry)
    layers.sort_custom(func(a,b):return rig.slot_order.find(a.actor_layer.slot)<rig.slot_order.find(b.actor_layer.slot))
    var local=Vector2i(69,71)
    var owners=opaque_layers(layers,local)
    check(owners.size()>=2,"Actual Attack5 SW pixel contains overlapping outfit components")
    if owners.is_empty():return
    var owner:Dictionary=owners.back()
    check("/Legs2/Attack5.png" in owner.texture_path,"Actual top-painted regression pixel belongs to Legs2")
    check(supported_source(world,owner,local),"Top-painted regression pixel has delivered solid depth")
    var screen=source_screen(world,owner,local)
    var expected=source_expected_depth(world,owner,local)
    var hidden_depth=expected
    var hidden_owner=""
    for entry in owners:
        if entry.id==owner.id or not supported_source(world,entry,local):continue
        var candidate=source_expected_depth(world,entry,local)
        if candidate>hidden_depth:hidden_depth=candidate;hidden_owner=entry.texture_path
    var tolerance=8./16777215.
    check(hidden_depth>expected+tolerance*4.,"Regression contains a hidden component nearer than the painted Legs2 owner")
    var capture:Image=world.native_support.viewport.get_texture().get_image()
    var measured=packed_depth(capture.get_pixelv(screen))
    check(absf(measured-expected)<=tolerance,"Receiver depth comes from the actual painted outfit owner")
    check(absf(measured-hidden_depth)>tolerance,"Hidden body geometry cannot replace the visible outfit surface")
    observations.append({"outfit_owner":"Attack5/frame7/SW/pixel69,71","painted_owner":owner.texture_path,
        "expected_depth":expected,"measured_depth":measured,"hidden_owner":hidden_owner,"hidden_depth":hidden_depth})
    var unsupported:Dictionary={}
    for y in range(20,115):
        if not unsupported.is_empty():break
        for x in range(15,115):
            var pixel=Vector2i(x,y);var stack=opaque_layers(layers,pixel)
            if stack.size()<2 or supported_source(world,stack.back(),pixel):continue
            var lower=false
            for index in stack.size()-1:
                if supported_source(world,stack[index],pixel):lower=true;break
            if lower:unsupported={"pixel":pixel,"owner":stack.back()};break
    check(not unsupported.is_empty(),"Real outfit includes unsupported painted ownership over a supported hidden layer")
    if not unsupported.is_empty():
        var at=source_screen(world,unsupported.owner,unsupported.pixel)
        var value=capture.get_pixelv(at)
        check(value.a>.99 and packed_depth(value)<=1./16777215.,"Unsupported top-painted pixel clears covered depth instead of borrowing hidden geometry")
        observations.append({"unsupported_owner":unsupported.owner.texture_path,"source_pixel":unsupported.pixel,"published_depth":packed_depth(value),"published_alpha":value.a})
    check(nontransparent_pixels(world.effect_layer.viewport.get_texture().get_image())==0,"Actual compositor clears all outfit support, including unsupported zero-depth owners, when no effect is active")
    save(world,"outfit-owner-attack5-sw")
    world._sample_frame(0);await settled()

func source_light_response(world:Node)->void:
    select(world,"fire_bolt")
    await sample(world,world.release-.02)
    world.effect_layer.output.visible=false
    var sources:Array=[]
    for handle in world.handles.values():
        for node in handle.root.find_children("*","Light3D",true,false):
            if node.is_visible_in_tree() and node.light_energy>0:sources.append({"node":node,"visible":node.visible})
    check(not sources.is_empty(),"Fire Bolt has active original Factory lights at release")
    var actor_mask=screen_mask(world,"caster").opaque
    var all_actors={}
    for id in world.visual_actors:all_actors.merge(screen_mask(world,id).opaque)
    var floor_mask=floor_pixels(world,world.get_node("Caster").global_position,all_actors)
    await settled();var on=world.get_viewport().get_texture().get_image()
    for source in sources:source.node.visible=false
    sync_lights(world);await settled()
    var off=world.get_viewport().get_texture().get_image()
    var actor_difference=changed(on,off,actor_mask)
    var floor_difference=changed(on,off,floor_mask)
    observations.append({"source_lights":sources.size(),"actor_light_difference":actor_difference,"floor_light_difference":floor_difference})
    check(actor_difference.pixels>0,"Original Factory lights visibly illuminate the assembled actor")
    check(floor_difference.pixels>0,"Original Factory lights visibly illuminate the actual floor")
    on.save_png("res://.captures/scene-integration/source-light-on.png")
    off.save_png("res://.captures/scene-integration/source-light-off.png")
    for source in sources:source.node.visible=source.visible
    sync_lights(world);world.effect_layer.output.visible=true
    await settled()

func run(world:Node)->void:
    DirAccess.make_dir_recursive_absolute("res://.captures/scene-integration")
    select(world,"fire_bolt");world.elapsed=0;world._sample_frame(0);pause(world)
    world.controls.hide()
    var finishing:Material=world.effect_layer.output.material
    world.effect_layer.output.material=null
    probe=MeshInstance3D.new();probe.mesh=QuadMesh.new();probe.layers=FX_LAYER
    probe.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;world.add_child(probe);probe.hide()
    await settled()
    check(world.native_support.viewport.get_parent()==world.effect_layer.viewport,"Receiver capture precedes effects through native child viewport order")
    for quarter in 4:
        while world.quarter!=quarter:world.rotate_view(1)
        world._sample_frame(0);await settled()
        check(nontransparent_pixels(world.effect_layer.viewport.get_texture().get_image())==0,"View%d: actual compositor produces zero alpha when no effect is active"%quarter)
        world.effect_layer.output.hide()
        var before=world.get_viewport().get_texture().get_image()
        world.native_support.owner.hide();await settled()
        var after=world.get_viewport().get_texture().get_image()
        check(before.get_data()==after.get_data(),"View%d: receiver depth leaves approved base rendering unchanged"%quarter)
        world.native_support.owner.show();world.effect_layer.output.show();await settled()
        await character_occlusion(world,quarter)
        await floor_occlusion(world,Vector3.ZERO,"View%d ground floor"%quarter)
        await depth_reader(world)
        save(world,"q%d-integrated"%quarter)
    await fractional_zoom_checks(world)
    var raised:Dictionary={}
    for entry in world.static_entries:
        if entry.role=="terrain" and entry.placement.position==[0,1]:raised=entry;break
    check(not raised.is_empty(),"Elevated fixture uses an existing authored floor entry")
    if not raised.is_empty():
        var previous=raised.placement.base_height_steps
        raised.placement.base_height_steps=1
        world.initialize_entry(raised);world.static_order_dirty=true;world.scenery_revision+=1
        world._sample_frame(0);await settled()
        await floor_occlusion(world,Placement.contact(raised.placement),"Elevated actual floor")
        raised.placement.base_height_steps=previous
        world.initialize_entry(raised);world.static_order_dirty=true;world.scenery_revision+=1
        world._sample_frame(0);await settled()
    probe.hide();world.effect_layer.output.material=finishing
    await outfit_owner_depth(world)
    await source_light_response(world)
    check(world.presentation_errors.is_empty(),"Scene integration adds no renderer errors")
    var report={"checks":checks,"failures":failures,"observations":observations,
        "scope":"Native source materials and existing sprite/floor receiving paths. Character optical calibration, gameplay collision and native Decal colour are separate claims."}
    FileAccess.open("res://.runtime/sandbox-scene-integration-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("SANDBOX_SCENE_INTEGRATION ",JSON.stringify(report));get_tree().quit(0 if failures.is_empty() else 1)
