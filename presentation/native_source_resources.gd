extends RefCounted
## Immutable native programs are shared; uniforms, clocks and mutable graphs are not.
## Copied into the selected Factory namespace by the existing source importer.
const MAX_PROGRAMS=256
static var programs:Dictionary={}
static var last_compile_frame:int=-1
static var last_discovery_frame:int=-1

static func clock_code(shader:Shader,uniform:String,expand:bool)->String:
    var code:String=shader.code
    if expand:code=_expand(code,shader.resource_path.get_base_dir())
    var token=RegEx.new()
    token.compile("\\bTIME\\b")
    if token.search(code)==null:return ""
    return token.sub(code,uniform,true).replace("shader_type spatial;","shader_type spatial;\nuniform float "+uniform+"=0.0;")

static func program(code:String)->Dictionary:
    if programs.has(code):
        var existing:Dictionary=programs[code]
        programs.erase(code);programs[code]=existing
        return existing
    var shader=Shader.new()
    shader.code=code
    var result={"shader":shader,"uniforms":shader.get_shader_uniform_list()}
    programs[code]=result
    while programs.size()>MAX_PROGRAMS:programs.erase(programs.keys()[0])
    return result

static func apply_clock(material:ShaderMaterial,uniform:String,expand:bool)->bool:
    if material.shader==null:return false
    var original:Shader=material.shader
    var code:String=clock_code(original,uniform,expand)
    if code.is_empty():return false
    var replacement:Dictionary=program(code)
    # VisualShader defaults are source-instance data, never program-cache data.
    var defaults:Dictionary={}
    for field in replacement.uniforms:
        if int(field.type)!=TYPE_OBJECT:continue
        var texture:Texture2D=original.get_default_texture_parameter(field.name)
        if texture!=null and material.get_shader_parameter(field.name)==null:
            defaults[field.name]=texture
    material.shader=replacement.shader
    for name in defaults:material.set_shader_parameter(name,defaults[name])
    return true

static func _expand(code:String,base:String)->String:
    var result:String=""
    for line in code.split("\n"):
        if line.strip_edges().begins_with("#include"):
            var path:String=line.get_slice('"',1)
            if not path.begins_with("res://"):path=base.path_join(path)
            result+=_expand(FileAccess.get_file_as_string(path),path.get_base_dir())+"\n"
        else:result+=line+"\n"
    return result

static func collect(value:Variant,uniform:String,expand:bool,jobs:Dictionary,seen:Dictionary)->void:
    if value is Resource:
        if seen.has(value):return
        seen[value]=true
        if value is Shader:
            var code:String=clock_code(value,uniform,expand)
            if not code.is_empty():jobs[code]=true
            return
        if value is Texture2D or value is Script:return
        if value is Material:
            if value is ShaderMaterial:collect(value.shader,uniform,expand,jobs,seen)
            collect(value.next_pass,uniform,expand,jobs,seen)
            return
        if value is Mesh:
            for surface in value.get_surface_count():
                collect(value.surface_get_material(surface),uniform,expand,jobs,seen)
            return
        if value is PackedScene:
            var state:SceneState=value.get_state()
            var inherited:SceneState=state.get_base_scene_state()
            if inherited!=null:_collect_scene(inherited,uniform,expand,jobs,seen)
            _collect_scene(state,uniform,expand,jobs,seen)
            return
        for field in value.get_property_list():
            if int(field.usage)&PROPERTY_USAGE_STORAGE:
                collect(value.get(field.name),uniform,expand,jobs,seen)
    elif value is Array:
        for item in value:collect(item,uniform,expand,jobs,seen)
    elif value is Dictionary:
        for item in value.values():collect(item,uniform,expand,jobs,seen)

static func _collect_scene(state:SceneState,uniform:String,expand:bool,jobs:Dictionary,seen:Dictionary)->void:
    for node in state.get_node_count():
        collect(state.get_node_instance(node),uniform,expand,jobs,seen)
        for property in state.get_node_property_count(node):
            collect(state.get_node_property_value(node,property),uniform,expand,jobs,seen)

static func reserve_discovery()->bool:
    var frame:int=Engine.get_process_frames()
    if last_discovery_frame==frame or last_compile_frame==frame:return false
    last_discovery_frame=frame
    return true

static func prepare(jobs:Dictionary)->int:
    # Several owners may query readiness in one frame. Compilation has one
    # shared budget, before construction and without advancing source clocks.
    var frame:int=Engine.get_process_frames()
    var pending:int=0
    for code in jobs:
        if programs.has(code):continue
        if last_compile_frame!=frame and last_discovery_frame!=frame:
            last_compile_frame=frame
            program(code)
        else:pending+=1
    return pending

static func particle_leaf(scene:PackedScene,path:NodePath)->GPUParticles3D:
    # Ray Ice selects exactly this authored leaf. Do not instantiate unrelated
    # sibling particles, shaders or an autoplay controller only to discard them.
    var state:SceneState=scene.get_state()
    var found:int=-1
    for index in state.get_node_count():
        var candidate:NodePath=NodePath(str(state.get_node_path(index)).trim_prefix("./"))
        if candidate==path:found=index
        elif str(candidate).begins_with(str(path)+"/"):
            push_error("Native particle selection is no longer a leaf: "+str(path));return null
    if found<0 or state.get_node_type(found)!=&"GPUParticles3D" or state.get_node_instance(found)!=null:
        push_error("Native particle leaf missing or changed: "+str(path));return null
    for index in state.get_connection_count():
        if NodePath(str(state.get_connection_source(index)).trim_prefix("./"))==path or NodePath(str(state.get_connection_target(index)).trim_prefix("./"))==path:
            push_error("Native particle leaf acquired scene connections: "+str(path));return null
    var particle=GPUParticles3D.new()
    particle.name=state.get_node_name(found)
    for property in state.get_node_property_count(found):
        particle.set(state.get_node_property_name(found,property),state.get_node_property_value(found,property))
    return particle
