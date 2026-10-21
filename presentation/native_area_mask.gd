extends RefCounted
## A disclosed spatial-effect footprint clips its isolated native geometry.
## This is coverage admission, not another light, surface or gameplay mask.
const DECLARATIONS="\nuniform sampler2D native_area_cells:filter_nearest,repeat_disable;\nuniform vec2 native_area_origin=vec2(0.0);\nuniform vec2 native_area_size=vec2(1.0);\nvarying vec2 native_area_world;\n"
const VERTEX="\nnative_area_world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xz;\n"
const FRAGMENT="\nvec2 native_cell=floor(native_area_world+vec2(0.5));\nvec2 native_local=native_cell-native_area_origin;\nif(any(lessThan(native_local,vec2(0.0)))||any(greaterThanEqual(native_local,native_area_size)))discard;\nif(texture(native_area_cells,(native_local+vec2(0.5))/native_area_size).r<0.5)discard;\n"

static func _body_end(code:String,opening:int)->int:
    var depth:int=1
    var at:int=opening+1
    while at<code.length():
        if code[at]=="{":depth+=1
        elif code[at]=="}":
            depth-=1
            if depth==0:return at
        at+=1
    return -1

static func _shader(original:Shader,shaders:Dictionary)->Shader:
    var code:String=original.code
    if shaders.has(original):return shaders[original]
    var functions=RegEx.new();functions.compile("void\\s+(vertex|fragment)\\s*\\(\\s*\\)\\s*\\{")
    var insertions:Array=[]
    var has_vertex:bool=false;var has_fragment:bool=false
    for function in functions.search_all(code):
        if function.get_string(1)=="vertex":
            var end:int=_body_end(code,function.get_end()-1)
            if end<0:return null
            insertions.append({"at":end,"text":VERTEX});has_vertex=true
        else:
            insertions.append({"at":function.get_end(),"text":FRAGMENT});has_fragment=true
    if not has_fragment:return null
    insertions.sort_custom(func(a,b):return a.at>b.at)
    var adapted:String=code
    for insertion in insertions:adapted=adapted.insert(insertion.at,insertion.text)
    adapted=adapted.replace("shader_type spatial;","shader_type spatial;"+DECLARATIONS)
    if not has_vertex:adapted+="\nvoid vertex(){"+VERTEX+"}\n"
    var shader=Shader.new();shader.code=adapted
    # Replacing shader source must retain textures authored as shader defaults.
    for uniform in original.get_shader_uniform_list():
        if int(uniform.type)!=TYPE_OBJECT:continue
        var texture:Texture2D=original.get_default_texture_parameter(uniform.name)
        if texture!=null:shader.set_default_texture_parameter(uniform.name,texture)
    shaders[original]=shader
    return shader

static func _configure_materials(handle:Dictionary)->void:
    if handle.has("area_mask"):return
    var state={"materials":[],"shaders":{},"prepared":[],"positions":null,"texture":null,"image":null,"origin":Vector2.ZERO,"size":Vector2.ONE,"errors":[]}
    var seen:Dictionary={}
    for piece in handle.geometry:
        var node:GeometryInstance3D=piece.node
        if not piece.get("layer_enabled",true):continue
        var materials:Array=[]
        if node.material_override!=null:materials.append(node.material_override)
        elif node is MeshInstance3D and node.mesh!=null:
            for surface in node.mesh.get_surface_count():materials.append(node.get_active_material(surface))
        elif node is MultiMeshInstance3D and node.multimesh!=null and node.multimesh.mesh!=null:
            for surface in node.multimesh.mesh.get_surface_count():materials.append(node.multimesh.mesh.surface_get_material(surface))
        elif node is GPUParticles3D:
            for pass_index in node.draw_passes:
                var mesh:Mesh=node.get_draw_pass_mesh(pass_index)
                if mesh!=null:
                    for surface in mesh.get_surface_count():materials.append(mesh.surface_get_material(surface))
        for material in materials:
            if material==null or not material is ShaderMaterial or material.shader==null:
                state.errors.append("native_area_material_unsupported:"+str(piece.path));continue
            if seen.has(material):continue
            seen[material]=true
            var shader:Shader=_shader(material.shader,state.shaders)
            if shader==null:
                state.errors.append("native_area_shader_unsupported:"+str(piece.path));continue
            var values:Dictionary={}
            for uniform in material.shader.get_shader_uniform_list():
                var value:Variant=material.get_shader_parameter(uniform.name)
                if value!=null:values[uniform.name]=value
            material.shader=shader
            for uniform in values:material.set_shader_parameter(uniform,values[uniform])
            state.materials.append(material)
    if state.materials.is_empty():state.errors.append("native_area_no_supported_materials")
    handle.area_mask=state

static func prepare(handle:Dictionary,positions:Array)->Dictionary:
    _configure_materials(handle)
    var state:Dictionary=handle.area_mask
    if not state.errors.is_empty():return {"ready":false,"errors":state.errors,"changed":false}
    if prepared(handle,positions):return {"ready":true,"errors":[],"changed":false}
    var minimum=Vector2i.ZERO;var maximum=Vector2i.ZERO
    if not positions.is_empty():
        minimum=Vector2i(positions[0][0],positions[0][1]);maximum=minimum
        for point in positions:
            var cell=Vector2i(point[0],point[1]);minimum=minimum.min(cell);maximum=maximum.max(cell)
    var size:Vector2i=maximum-minimum+Vector2i.ONE
    var mask=Image.create(size.x,size.y,false,Image.FORMAT_R8);mask.fill(Color.BLACK)
    for point in positions:mask.set_pixel(int(point[0])-minimum.x,int(point[1])-minimum.y,Color.WHITE)
    var texture=ImageTexture.create_from_image(mask)
    state.prepared.append({"positions":positions.duplicate(true),"texture":texture,"image":mask,
        "origin":Vector2(minimum),"size":Vector2(size)})
    return {"ready":true,"errors":[],"changed":true}

static func prepared(handle:Dictionary,positions:Array)->bool:
    if not handle.has("area_mask"):return false
    var state:Dictionary=handle.area_mask
    if not state.errors.is_empty():return false
    if state.positions==positions:return true
    for value in state.prepared:
        if value.positions==positions:return true
    return false

static func retain(handle:Dictionary,positions:Array)->void:
    if not handle.has("area_mask"):return
    # Admission order may differ from cue order. Keep the displayed mask plus
    # variants still named by the current required/lookahead source owners.
    var state:Dictionary=handle.area_mask
    state.prepared=state.prepared.filter(func(value):return value.positions in positions)

static func publish(handle:Dictionary,positions:Array)->Dictionary:
    if not handle.has("area_mask"):
        return {"ready":false,"errors":["native_area_not_prepared"],"changed":false}
    var state:Dictionary=handle.area_mask
    if not state.errors.is_empty():return {"ready":false,"errors":state.errors,"changed":false}
    if state.positions==positions:return {"ready":true,"errors":[],"changed":false}
    for index in state.prepared.size():
        var value:Dictionary=state.prepared[index]
        if value.positions!=positions:continue
        for name in ["positions","texture","image","origin","size"]:state[name]=value[name]
        for material in state.materials:
            material.set_shader_parameter("native_area_cells",state.texture)
            material.set_shader_parameter("native_area_origin",state.origin)
            material.set_shader_parameter("native_area_size",state.size)
        # Optional later shapes can be prepared before a newly required one.
        # Interest pruning, not insertion order, owns their retirement.
        state.prepared.remove_at(index)
        return {"ready":true,"errors":[],"changed":true,"materials":state.materials.size()}
    return {"ready":false,"errors":["native_area_not_prepared"],"changed":false}

# Used by isolated source fixtures. Runtime preparation and sampling call the
# two phases separately so a future footprint never changes current coverage.
static func configure(handle:Dictionary,positions:Array)->Dictionary:
    return update(handle,positions)

static func update(handle:Dictionary,positions:Array)->Dictionary:
    var result:Dictionary=prepare(handle,positions)
    if not result.ready:return result
    return publish(handle,positions)
