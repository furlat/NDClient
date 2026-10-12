extends RefCounted
# Passive draw cache and native GPU handles. Gameplay state is not owned here.
const Order=preload("res://grid_order.gd")
const Placement=preload("res://placement.gd")
const Catalog=preload("res://source_catalog.gd")
const SHADER=preload("res://grid.gdshader")
const ROOT="res://generated/render_cache/"
const SORT_SPACING=8.0

static func create(world: Node) -> Dictionary:
    var manifest=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"manifest.json"))
    assert(manifest.row_ids.size()==world.placements.size(),"Recompile the render cache after changing the source map")
    var state_image=Image.create(256,ceili(manifest.row_ids.size()/256.0),false,Image.FORMAT_R8)
    var state={"views":[],"quarter":-1,"row_slots":{},"state_image":state_image,
        "state_texture":ImageTexture.create_from_image(state_image),"affected":{},"signature":[],"manifest":manifest}
    for i in range(manifest.row_ids.size()):
        assert(manifest.row_ids[i]==world.placements[i].id,"Source placement order changed; recompile the render cache")
        state.row_slots[manifest.row_ids[i]]=i
    var material=ShaderMaterial.new();material.shader=SHADER
    material.set_shader_parameter("colours",load(ROOT+"colour.res"))
    material.set_shader_parameter("numeric",load(ROOT+"numeric.res"))
    material.set_shader_parameter("metadata",load(ROOT+"metadata.res"))
    material.set_shader_parameter("placement_state",state.state_texture)
    var assets=Catalog.read_file("assets.json",world.catalog_cache)
    var water: Dictionary=assets.water
    material.set_shader_parameter("ripple_texture",world.texture(assets.resources[water.ripple].path))
    material.set_shader_parameter("ripple_pan",world.v2(water.ripplePan))
    for mapping in [["shallow_color","shallowColor"],["deep_color","deepColor"],["water_tint","tint"]]:
        material.set_shader_parameter(mapping[0],world.v4(water[mapping[1]]))
    for mapping in [["uv_scale","uvScale"],["depth_strength","depthBlendStrength"],["ripple_tiling","rippleTilingMultiplier"],["ripple_amount","rippleAmount"],["sheen_strength","sheenStrength"],["sheen_sharpness","sheenSharpness"],["alpha_strength","alphaDepthStrength"],["overall_alpha","overallAlpha"],["alpha_cutoff","alphaCutoff"]]:
        material.set_shader_parameter(mapping[0],water[mapping[1]])
    var mesh=QuadMesh.new();mesh.size=Vector2.ONE
    for q in range(4):
        var file=FileAccess.open(ROOT+"view-"+str(q)+".bin",FileAccess.READ)
        var data: Dictionary=file.get_var()
        var parent=Node3D.new();parent.visible=false;world.add_child(parent)
        var table=load(ROOT+"instances-"+str(q)+".res")
        var blocks=[]
        for block in data.blocks:
            var multi=MultiMesh.new()
            multi.transform_format=MultiMesh.TRANSFORM_3D;multi.use_colors=true
            multi.mesh=mesh;multi.instance_count=block.buffer.size()/16;multi.buffer=block.buffer
            multi.custom_aabb=block.bounds
            var mat: ShaderMaterial=material.duplicate()
            mat.set_shader_parameter("instances",table)
            mat.set_shader_parameter("camera_quarter",q)
            mat.set_shader_parameter("block_base",int(block.base))
            var node=make_pass(parent,multi,mat,0,multi.instance_count,block.base,SORT_SPACING)
            blocks.append({"base":int(block.base),"count":multi.instance_count,"node":node,"slices":[]})
        state.views.append({"parent":parent,"blocks":blocks,"keys":data.keys,"rows":data.rows,"roles":data.roles})
    return state

static func make_pass(parent: Node,multi: MultiMesh,material: ShaderMaterial,start: int,end: int,base: int,spacing: float) -> MultiMeshInstance3D:
    var node=MultiMeshInstance3D.new();node.multimesh=multi;node.material_override=material
    node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    node.sorting_use_aabb_center=false
    node.sorting_offset=(base+start+0.5)*spacing
    material.set_shader_parameter("range_start",start);material.set_shader_parameter("range_end",end)
    parent.add_child(node)
    return node

static func camera_changed(world: Node) -> void:
    var state: Dictionary=world.gpu_grid
    if state.quarter!=world.quarter:
        if state.quarter>=0:state.views[state.quarter].parent.visible=false
        state.views[world.quarter].parent.visible=true
        state.quarter=world.quarter
        state.signature.clear()
    for view in state.views:
        for block in view.blocks:
            for node in [block.node]+block.slices:
                node.material_override.set_shader_parameter("use_source_depth",world.source_depth)
                node.material_override.set_shader_parameter("use_source_normals",world.source_normals)
    insert_dynamic(world)

static func restore_block(block: Dictionary) -> void:
    for node in block.slices:node.queue_free()
    block.slices.clear()
    block.node.visible=true
    block.node.material_override.set_shader_parameter("range_start",0)
    block.node.material_override.set_shader_parameter("range_end",block.count)

static func insert_dynamic(world: Node) -> void:
    var state: Dictionary=world.gpu_grid
    var view: Dictionary=state.views[world.quarter]
    var packets=[];var signature=[world.quarter]
    for entry in world.entries:
        if not entry.node.visible:continue
        var key=Order.key(entry.placement,entry.role,entry.layer,world.quarter)
        var cut=Order.insertion(view.keys,key)
        packets.append({"entry":entry,"cut":cut,"key":key})
    packets.sort_custom(func(a,b):return Order.less(a.key,b.key) if a.key!=b.key else a.entry.id<b.entry.id)
    for packet in packets:signature.append([packet.entry.id,packet.cut])
    var cut_counts={}
    for packet in packets:cut_counts[packet.cut]=cut_counts.get(packet.cut,0)+1
    var previous=-1;var within=0
    for packet in packets:
        if packet.cut!=previous:previous=packet.cut;within=0
        within+=1
        var origin_depth=(-world.camera.global_basis.z).dot(packet.entry.node.global_position)
        packet.entry.node.sorting_offset=(packet.cut-0.4+0.8*within/float(cut_counts[packet.cut]+1))*SORT_SPACING+origin_depth
    if signature==state.signature:return
    for identity in state.affected:
        restore_block(state.views[identity.x].blocks[identity.y])
    state.affected.clear();state.signature=signature
    var splits={}
    for packet in packets:
        var block_index=mini(packet.cut/int(state.manifest.block_size),view.blocks.size()-1)
        if not splits.has(block_index):splits[block_index]=[]
        var local=packet.cut-view.blocks[block_index].base
        if local>0 and local<view.blocks[block_index].count and not local in splits[block_index]:splits[block_index].append(local)
    for index in splits:
        var block: Dictionary=view.blocks[index]
        if splits[index].is_empty():continue
        var cuts: Array=splits[index];cuts.sort();cuts.push_front(0);cuts.append(block.count)
        block.node.visible=false
        for i in range(cuts.size()-1):
            var mat: ShaderMaterial=block.node.material_override.duplicate()
            block.slices.append(make_pass(view.parent,block.node.multimesh,mat,cuts[i],cuts[i+1],block.base,SORT_SPACING))
        state.affected[Vector2i(world.quarter,index)]=true
    world.draw_order=packets.map(func(packet):return packet.entry)

static func hide_placement(world: Node,id: String,hidden: bool) -> void:
    var state: Dictionary=world.gpu_grid
    var slot: int=state.row_slots[id]
    state.state_image.set_pixel(slot%256,slot/256,Color.WHITE if hidden else Color.BLACK)
    state.state_texture.update(state.state_image)

static func highlight(world: Node) -> void:
    var state: Dictionary=world.gpu_grid
    for view in state.views:
        for block in view.blocks:
            for node in [block.node]+block.slices:
                node.material_override.set_shader_parameter("highlighted",Input.is_physical_key_pressed(KEY_ALT))

static func pick(world: Node,screen: Vector2) -> Dictionary:
    var rect: Rect2=world.view_rect()
    var pixel=rect.position+screen/get_viewport_size(world)*rect.size
    var bucket=Vector2i((pixel/512.0).floor())
    var candidates: Array=world.placement_buckets[world.quarter].get(bucket,[]).duplicate()
    candidates.sort_custom(func(a,b):return Order.less(Order.key(b,b.get("sort_role","body"),int(b.get("layer",0))*10+2,world.quarter),Order.key(a,a.get("sort_role","body"),int(a.get("layer",0))*10+2,world.quarter)))
    for row in candidates:
        if world.destruction.has(row.id):continue
        if Catalog.break_duration(row,world.catalog_cache)<=0:continue
        var record=Catalog.environment(row,world.quarter,world.catalog_cache)
        var contact=Placement.project(Vector2(row.position[0],row.position[1]),row.base_height_steps,world.quarter)
        var uv=(pixel-contact)/record.scale+world.v2(record.pivot)
        var cell=world.v2(record.native_size)
        if uv.x<0 or uv.y<0 or uv.x>=cell.x or uv.y>=cell.y:continue
        world.texture(record.path)
        var region: Array=record.get("rect",[0,0,cell.x,cell.y])
        var colour: Color=world.source_images[record.path].get_pixelv(Vector2i(uv)+Vector2i(region[0],region[1]))
        if colour.a<0.05:continue
        var shadow=false
        for role in record.get("roles",[]):
            if role.role!="ground_shadow":continue
            if role.selection.kind=="mask":world.texture(role.selection.mask.region.path)
            if world.pixel_selected(role.selection,uv,colour):shadow=true;break
        if not shadow:return row
    return {}

static func get_viewport_size(world: Node) -> Vector2:return world.get_viewport().get_visible_rect().size
