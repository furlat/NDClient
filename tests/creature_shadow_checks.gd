extends SceneTree
# Actual delivered source packets. Native caster coverage must equal original
# selected-body alpha ∩ raw support ∩ depth validity at each native cell size.
const SourceMaterial=preload("res://presentation/source_material.gd")
const Shadows=preload("res://presentation/canvas_shadows.gd")
const Geometry=preload("res://presentation/character_geometry.gd")
const Catalog=preload("res://source_catalog.gd")
const Placement=preload("res://placement.gd")
const Caster=preload("res://presentation/shadow_caster.gdshader")
const Body=preload("res://modular.gdshader")
const FACTORY="C:/Users/tommaso/Documents/assets/fantasy-unified-catalog/authored-creature-geometry-2026-10-12"
var checks:=0
var failures:Array=[]
var evidence:Array=[]
var cache:Dictionary={}
var images:Dictionary={}
var textures:Dictionary={}
var stage:Node3D
var camera:Camera3D
var viewport:SubViewport
var manager=Shadows.new()

func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);print("CREATURE_SHADOW_FAIL ",label)
func _initialize()->void:run.call_deferred()
func texture(path:String)->Texture2D:
    if not textures.has(path):
        images[path]=Image.load_from_file(Catalog.media_path(path) if path.begins_with("/media/") else path)
        textures[path]=ImageTexture.create_from_image(images[path])
    return textures[path]
func light_cookie(path:String)->Texture2D:
    # Light cookies carry their RGBA8 image, as generated cookies do.
    var result:Texture2D=texture(path)
    if not result.has_meta(&"cookie_image"):
        var pixels:Image=images[path].duplicate();pixels.convert(Image.FORMAT_RGBA8);result.set_meta(&"cookie_image",pixels)
    return result
func read(path:String)->Dictionary:return JSON.parse_string(FileAccess.get_file_as_string(path))
func capture(view:SubViewport)->Image:
    await process_frame;await RenderingServer.frame_post_draw
    await process_frame;await RenderingServer.frame_post_draw
    return view.get_texture().get_image()

func packet(table:Dictionary,folder:String,id:String)->Dictionary:
    var action:Dictionary=table.actions.filter(func(value):return value.id==id)[0]
    var family:Dictionary=table.families.filter(func(value):return value.family==action.family)[0]
    var size:Array=action.get("cell_size",[128,128])
    var cell=Vector2(size[0],size[1]);var pivot=Vector2(cell.x*.5,cell.y-family.placement.origin_y_from_ground)
    var origin:Array=action.get("canonical_mapping",{}).get("native_inferred_camera_origin",table.recipe.origin_xy)
    var ground=(origin[1]-pivot.y)/cos(deg_to_rad(table.recipe.elevation_degrees))
    var material=ShaderMaterial.new();material.shader=Body
    var entry=make_entry(id,material,cell,pivot)
    SourceMaterial.set_parameter(entry,"sheet",texture(folder.path_join(action.files["colour.png"].path)))
    SourceMaterial.set_parameter(entry,"component_depth",texture(folder.path_join(action.files["depth.png"].path)))
    SourceMaterial.set_parameter(entry,"component_support",texture(folder.path_join(action.files["raw-support.png"].path)))
    SourceMaterial.set_parameter(entry,"frame_uv",Vector4(0,0,1.0/action.frames,.125))
    SourceMaterial.set_parameter(entry,"component_depth_range",Vector2(table.recipe.common_depth_world_range[0],table.recipe.common_depth_world_range[1]))
    SourceMaterial.set_parameter(entry,"component_units",1.0/Placement.PIXELS_PER_UNIT)
    SourceMaterial.set_parameter(entry,"component_reconstruction_origin",Vector2(origin[0],origin[1]))
    SourceMaterial.set_parameter(entry,"component_elevation",deg_to_rad(table.recipe.elevation_degrees))
    SourceMaterial.set_parameter(entry,"has_component_geometry",true)
    entry.geometry_cell_size=cell;entry.geometry_ground_pixels=ground
    entry.frames=action.frames;entry.source_action=action
    return entry

func make_entry(id:String,material:ShaderMaterial,cell:Vector2,pivot:Vector2)->Dictionary:
    var node=MeshInstance3D.new();node.mesh=QuadMesh.new();node.mesh.size=cell/Placement.PIXELS_PER_UNIT
    node.mesh.center_offset=Vector3(0,pivot.y-cell.y*.5,0)/Placement.PIXELS_PER_UNIT
    node.basis=camera.basis;node.material_override=material;stage.add_child(node)
    return {"id":id,"node":node,"material":material,"role":"body","pivot":pivot,"scale":1.0,
        "placement":{"id":id,"position":[0,0],"base_height_steps":0,"scale_x":1.0},"actor_layer":{"slot":"body"},"cell":cell}

func modular()->Dictionary:
    var path="/media/smallscale/modular/Chest14/Idle.png"
    var material=ShaderMaterial.new();material.shader=Body
    var entry=make_entry("modular-Chest14",material,Vector2(128,128),Vector2(64,87));entry.actor_layer.slot="chest"
    SourceMaterial.set_parameter(entry,"sheet",texture(path));SourceMaterial.set_parameter(entry,"frame_uv",Vector4(0,0,1.0/15,.125))
    # The original sheet remains the optical input. Admit its registered
    # immutable metadata before the passive production geometry bind.
    var source:String="res://assets/art/media/smallscale/modular/Chest14/Idle.png"
    var admitted:Dictionary=Geometry.BodySources.prepare_descriptor(source,"chest",cache)
    check(not admitted.is_empty(),"Actual modular Chest14 native source metadata admits before geometry binding")
    Geometry.bind(entry,source,cache,texture,true,true,"reference")
    check(SourceMaterial.value(entry,"has_component_geometry") and SourceMaterial.value(entry,"component_depth")!=null and SourceMaterial.value(entry,"component_support")!=null,"Prepared modular source publishes its actual depth and support operands")
    entry.frames=15
    return entry

func selected_partition(entry:Dictionary)->void:
    if not entry.get("source_action",{}).get("visible_body_only",false):return
    var action:Dictionary=entry.source_action
    var original:Image=Image.load_from_file(Catalog.media_path(action.layers.combined.media))
    var body:Image=SourceMaterial.value(entry,"sheet").get_image()
    var removed:=0;var mismatch:=0
    var rule:Dictionary=action.component_definition.selection.rules[0]
    for y in int(entry.cell.y):
        for x in int(entry.cell.x):
            var c=original.get_pixel(x,y);var b=body.get_pixel(x,y)
            var v=[c.r8,c.g8,c.b8,c.a8];var selected:=true
            for channel in 4:selected=selected and v[channel]>=rule.minimum[channel] and v[channel]<=rule.maximum[channel]
            if selected:
                removed+=1
                if b.a8!=0:mismatch+=1
            elif b!=c:mismatch+=1
    check(removed>0 and mismatch==0,entry.id+" selected source is the exact original visible body partition, not baked shadow")
    evidence.append({"id":entry.id,"original_shadow_pixels_removed_first_cell":removed,"partition_mismatches":mismatch})

func coverage(entry:Dictionary,row:int)->void:
    var uv:Vector4=SourceMaterial.value(entry,"frame_uv");uv.y=float(row)/8;SourceMaterial.set_parameter(entry,"frame_uv",uv)
    var snapshot:Dictionary=Shadows._snapshots([entry],camera)[0]
    var cell:Vector2=snapshot.component_cell_size
    var units:float=snapshot.component_units;var ground:float=snapshot.ground_pixels*units
    var view=SubViewport.new();view.size=Vector2i(cell);view.world_3d=World3D.new();view.transparent_bg=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    var cam=Camera3D.new();cam.projection=Camera3D.PROJECTION_ORTHOGONAL;cam.size=cell.y*units
    var centre:Vector3=camera.basis*Vector3(cell.x*.5-entry.pivot.x,entry.pivot.y-cell.y*.5,0)*units
    cam.transform=Transform3D(camera.basis,centre+camera.basis.z*20);view.add_child(cam)
    var node=MeshInstance3D.new();node.mesh=manager._caster_mesh(cell);node.custom_aabb=AABB(Vector3(-10,-10,-10),Vector3(20,20,20));view.add_child(node)
    var mat=ShaderMaterial.new();mat.shader=Caster
    for name in Shadows.CASTER_PARAMETERS:mat.set_shader_parameter(name,snapshot[name])
    mat.set_shader_parameter("component_cell_size",cell);mat.set_shader_parameter("display_basis",camera.basis);mat.set_shader_parameter("sprite_pivot",entry.pivot);mat.set_shader_parameter("ground_height",ground)
    node.material_override=mat
    var native=await capture(view)
    var sheet:Image=snapshot.sheet.get_image();var support:Image=snapshot.component_support.get_image();var depth:Image=snapshot.component_depth.get_image()
    var missing:=0;var extra:=0;var admitted:=0;var unsupported:=0;var max_projection_error:=0.0
    for y in int(cell.y):
        for x in int(cell.x):
            var at=Vector2i(x,row*cell.y+y);var colour=sheet.get_pixelv(at)
            var valid:bool=colour.a>.5 and support.get_pixelv(at).r>.5 and depth.get_pixelv(at).a>.5
            var drawn:bool=native.get_pixel(x,y).a>.5
            if valid:admitted+=1
            elif colour.a>.5:unsupported+=1
            if valid and not drawn:missing+=1
            if drawn and not valid:extra+=1
            if valid:
                var d:float=snapshot.component_depth_range.x+(depth.get_pixelv(at).r8-32)*(snapshot.component_depth_range.y-snapshot.component_depth_range.x)/192
                var point=Shadows._caster_point(snapshot,x,y,d,ground)
                var painted:Vector3=camera.basis*Vector3(x-entry.pivot.x,entry.pivot.y-y,0)*units
                max_projection_error=maxf(max_projection_error,cam.unproject_position(point).distance_to(cam.unproject_position(painted)))
    check(admitted>0,entry.id+" row"+str(row)+" actual packet has supported body pixels")
    check(missing==0 and extra==0,entry.id+" row"+str(row)+" native caster matches exact alpha/support/depth source coverage: "+str([missing,extra]))
    check(max_projection_error<.001,entry.id+" camera-ray height compression preserves authored painted contact projection")
    check(node.mesh.subdivide_width==int(cell.x)-1 and node.mesh.subdivide_depth==int(cell.y)-1,entry.id+" native grid keeps original cell dimensions")
    check(manager._caster_mesh(cell)==node.mesh,entry.id+" native grid is reused without per-frame remeshing")
    evidence.append({"id":entry.id,"row":row,"cell":[cell.x,cell.y],"ground_pixels":snapshot.ground_pixels,"admitted":admitted,"unsupported_visible_pixels":unsupported,"missing":missing,"extra":extra,"max_projection_error_pixels":max_projection_error})
    native.save_png("res://.captures/creature-shadows/"+entry.id.validate_filename()+"-"+str(row)+"-caster.png")
    view.queue_free();await process_frame

func shadow(entry:Dictionary)->void:
    var row:Dictionary=entry.placement
    var actor={"valid":true,"row":row,"entries":[entry]}
    var zoom=1.0/Placement.PIXELS_PER_UNIT*camera.unproject_position(camera.basis.x).distance_to(camera.unproject_position(Vector3.ZERO))
    var cookie=light_cookie("C:/Users/tommaso/Documents/Dev/NDCharacterLight/.reference-template/scenes/vfx/textures/T_basic1_vfx.PNG")
    var sources=[{"id":"original-warm","screen_position":camera.unproject_position(Vector3.ZERO)+Vector2(14,42)*zoom,"span":Vector2(cookie.get_size())*19.36*zoom,"height":20*zoom,"texture":cookie,"energy":2.0,"color":Color(.809372,.429306,.269121),"enabled":true}]
    var produced=manager.sync([actor],camera,sources)
    check(produced.size()==1 and manager.issues.is_empty(),entry.id+" original body produces one generated shadow without fallback")
    if produced.is_empty():return
    var state:Dictionary=manager.actors[entry.id]
    var snapshot:Dictionary=Shadows._snapshots([entry],camera)[0]
    check(is_equal_approx(state.ground.position.y,snapshot.ground_pixels*snapshot.component_units),entry.id+" helper uses delivered optical ground")
    var caster:MeshInstance3D=state.casters[entry.id]
    check(caster.material_override.get_shader_parameter("sheet")==SourceMaterial.value(entry,"sheet"),entry.id+" shadow caster uses actual selected body source")
    var image=await capture(state.viewport);var blocked:=0
    for y in image.get_height():
        for x in image.get_width():
            if image.get_pixel(x,y).r<.99:blocked+=1
    check(blocked>0,entry.id+" native shadow measurement contains body occlusion")
    var prior:int=manager.diagnostics().updates
    var frame:Vector4=SourceMaterial.value(entry,"frame_uv");frame.x=1.0/entry.frames;SourceMaterial.set_parameter(entry,"frame_uv",frame)
    manager.sync([actor],camera,sources)
    check(manager.diagnostics().updates==prior+1,entry.id+" native shadow invalidates on authored frame change")
    var expected:int=2*int(snapshot.component_cell_size.x)*int(snapshot.component_cell_size.y)
    check(manager.diagnostics().caster_triangles_before_native_shadow_passes==expected,entry.id+" diagnostics report actual native caster triangles")
    manager.sync([],camera,sources)

func run()->void:
    if DisplayServer.get_name()=="headless":print("Creature shadow checks require native graphics");quit(2);return
    root.unfocusable=true;root.position=Vector2i(-16000,-16000)
    DirAccess.make_dir_recursive_absolute("res://.captures/creature-shadows")
    viewport=SubViewport.new();viewport.size=Vector2i(512,512);viewport.world_3d=World3D.new();viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
    stage=Node3D.new();viewport.add_child(stage);camera=Camera3D.new();stage.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=4
    camera.position=Vector3(12,12*Placement.HEIGHT_UNIT,12);camera.look_at(Vector3.ZERO);manager.attach(stage)
    var animals=read(FACTORY.path_join("animals/delivery/catalog.json"));var authored=read(FACTORY.path_join("delivery/catalog.json"))
    var entries:Array=[]
    for id in ["wolf/idle","boar/idle","stag/idle","elephant/idle","stag/die"]:entries.append(packet(animals,FACTORY.path_join("animals/delivery"),id))
    entries.append(packet(authored,FACTORY.path_join("delivery"),"goblin-01/idle"));entries.append(modular())
    for entry in entries:
        selected_partition(entry)
        await coverage(entry,0);await coverage(entry,7);await shadow(entry)
        entry.node.queue_free()
    var legacy=modular();var explicit=Shadows._snapshots([legacy],camera)[0]
    legacy.erase("geometry_cell_size");legacy.erase("geometry_ground_pixels")
    check(Shadows._snapshots([legacy],camera)[0]==explicit,"Unspecified modular metadata preserves exact128/19 snapshot defaults")
    legacy.node.queue_free();manager.close();viewport.queue_free();await process_frame
    var report={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Actual native64/84/96/128 animal/body geometry plus Goblin and modular control; source alpha/support/depth coverage, optical contact projection, native generated shadows, mesh reuse and authored frame invalidation. Original partition remains selected input; no hidden geometry or baked fallback."}
    FileAccess.open("res://generated/creature_shadow_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("CREATURE_SHADOW_CHECKS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
