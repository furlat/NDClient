extends RefCounted
## Selected native blood material adapter. One simulation supplies all views;
## its source fragment/COLOR/animation remains the coverage and colour owner.
const Receiver=preload("res://presentation/native_effect_receiver.gdshader")
const Depth=preload("res://presentation/native_effect_depth.gdshader")
const Specular=preload("res://presentation/native_effect_specular.gdshader")
const NORMAL_LAYER=1<<16
const MATERIAL_LAYER=1<<17
const SUPPORT_LAYER=1<<15

static func _body_end(code:String,name:String)->int:
    var expression=RegEx.new();expression.compile("void\\s+"+name+"\\s*\\(\\s*\\)\\s*\\{")
    var found=expression.search(code)
    if found==null:return -1
    var index=found.get_end();var depth=1
    while depth>0 and index<code.length():
        if code[index]=="{":depth+=1
        elif code[index]=="}":depth-=1
        index+=1
    return index-1 if depth==0 else -1

static func _standard(source:BaseMaterial3D)->Dictionary:
    # Selected mist is StandardMaterial's particle billboard. These are the
    # original Godot billboard/flipbook equations, not a replacement particle.
    if source.billboard_mode!=BaseMaterial3D.BILLBOARD_PARTICLES or source.normal_enabled:
        return {"error":"Selected native StandardMaterial mode needs an explicit source adapter"}
    var code="""shader_type spatial;
render_mode blend_mix,cull_back,unshaded;
uniform sampler2D source_texture:source_color;
uniform vec4 source_tint:source_color;
uniform vec2 source_frames;
uniform bool source_loop;
uniform bool source_keep_scale;
void vertex(){
    mat4 particle_world=mat4(normalize(INV_VIEW_MATRIX[0]),normalize(INV_VIEW_MATRIX[1]),normalize(INV_VIEW_MATRIX[2]),MODEL_MATRIX[3]);
    particle_world*=mat4(vec4(cos(INSTANCE_CUSTOM.x),-sin(INSTANCE_CUSTOM.x),0.,0.),vec4(sin(INSTANCE_CUSTOM.x),cos(INSTANCE_CUSTOM.x),0.,0.),vec4(0.,0.,1.,0.),vec4(0.,0.,0.,1.));
    MODELVIEW_MATRIX=VIEW_MATRIX*particle_world;
    if(source_keep_scale)MODELVIEW_MATRIX*=mat4(vec4(length(MODEL_MATRIX[0].xyz),0.,0.,0.),vec4(0.,length(MODEL_MATRIX[1].xyz),0.,0.),vec4(0.,0.,length(MODEL_MATRIX[2].xyz),0.),vec4(0.,0.,0.,1.));
    MODELVIEW_NORMAL_MATRIX=mat3(MODELVIEW_MATRIX);
    float total=source_frames.x*source_frames.y;
    float frame=floor(INSTANCE_CUSTOM.z*total);
    frame=source_loop ? mod(frame,total) : clamp(frame,0.,total-1.);
    UV/=source_frames;
    UV+=vec2(mod(frame,source_frames.x)/source_frames.x,floor((frame+.5)/source_frames.x)/source_frames.y);
    if(!OUTPUT_IS_SRGB)COLOR.rgb=mix(pow((COLOR.rgb+vec3(.055))/1.055,vec3(2.4)),COLOR.rgb/12.92,lessThanEqual(COLOR.rgb,vec3(.04045)));
}
void fragment(){vec4 source=texture(source_texture,UV)*source_tint*COLOR;ALBEDO=source.rgb;ALPHA=source.a;ROUGHNESS=1.;SPECULAR=0.;}
"""
    return {"code":code,"values":{"source_texture":source.albedo_texture,"source_tint":source.albedo_color,
        "source_frames":Vector2(source.particles_anim_h_frames,source.particles_anim_v_frames),
        "source_loop":source.particles_anim_loop,"source_keep_scale":source.billboard_keep_scale}}

static func adapt(handle:Dictionary,depth_texture:Texture2D)->String:
    for node in handle.subject.find_children("*","GeometryInstance3D",true,false):
        var source:Material=node.material_override
        if source==null:return "Native blood geometry has no declared source material: "+str(node.name)
        var code:String;var values={}
        if source is ShaderMaterial:
            code=source.shader.code
            for uniform in source.shader.get_shader_uniform_list():
                var value=source.get_shader_parameter(uniform.name)
                if value==null and uniform.type==TYPE_OBJECT:value=source.shader.get_default_texture_parameter(uniform.name)
                if value!=null:values[uniform.name]=value
            # VisualShader's generated curve samplers are default textures.
            var samplers=RegEx.new();samplers.compile("uniform\\s+sampler\\w*\\s+(\\w+)")
            for matched in samplers.search_all(code):
                var name=matched.get_string(1)
                var texture=source.shader.get_default_texture_parameter(name)
                if texture!=null and not values.has(name):values[name]=texture
        elif source is BaseMaterial3D:
            var translated=_standard(source)
            if translated.has("error"):return translated.error
            code=translated.code;values=translated.values
        else:return "Unsupported native blood material: "+source.get_class()
        var has_map="NORMAL_MAP =" in code or "NORMAL_MAP=" in code
        var modes=RegEx.new();modes.compile("render_mode([^;]*);")
        var found=modes.search(code)
        if found!=null:
            if "unshaded" not in found.get_string():code=modes.sub(code,"render_mode"+found.get_string(1)+",unshaded;",false)
        else:code=code.replace("shader_type spatial;","shader_type spatial;render_mode unshaded;")
        code=code.replace("hint_depth_texture","filter_nearest")
        if "uniform sampler2D DEPTH_TEXTURE" in code:
            if depth_texture==null:return "Depth-reading native source has no supporting receiver capture"
            values.DEPTH_TEXTURE=depth_texture
            code=code.replace("texture(DEPTH_TEXTURE, SCREEN_UV).x","native_source_depth(SCREEN_UV)")
            code=code.replace("void fragment()", "float native_source_depth(vec2 uv){vec3 b=round(texture(DEPTH_TEXTURE,uv).rgb*255.0);return dot(b,vec3(65536.0,256.0,1.0))/16777215.0;}\nvoid fragment()")
        code=code.replace("shader_type spatial;","shader_type spatial;varying flat uint native_capture_mode;\nuniform bool native_actor_partition=false;\nuniform vec3 native_actor_plane_origin;\nuniform vec3 native_actor_plane_normal;\n")
        var vertex_end=_body_end(code,"vertex")
        if vertex_end<0:code+="\nvoid vertex(){native_capture_mode=CAMERA_VISIBLE_LAYERS;}\n"
        else:code=code.insert(vertex_end,"native_capture_mode=CAMERA_VISIBLE_LAYERS;")
        var fragment_end=_body_end(code,"fragment")
        if fragment_end<0:return "Native source has no fragment function"
        var output="\nif(ALPHA<=0.)discard;"
        if handle.record.get("actor_partition",false):
            # Zero-thickness2.5D presentation plane through the actor foot.
            # Classification is on each original native fragment BEFORE blend,
            # not on a precomposited image or inferred optical body geometry.
            output+="bool native_back=(native_capture_mode&(1u<<18u))!=0u;bool native_front=(native_capture_mode&(1u<<19u))!=0u;"
            output+="if(native_back||native_front){vec3 native_point=(INV_VIEW_MATRIX*vec4(VERTEX,1.)).xyz;bool behind=native_actor_partition&&dot(native_point-native_actor_plane_origin,native_actor_plane_normal)<0.;if(behind!=native_back)discard;}"
        output+="vec3 native_normal=NORMAL;"
        if has_map:
            # Godot's native tangent-space mapping, evaluated from the source's
            # own sampled NORMAL_MAP and NORMAL_MAP_DEPTH before packing.
            output+="vec3 native_map=NORMAL_MAP*2.-1.;native_map.z=sqrt(max(0.,1.-dot(native_map.xy,native_map.xy)));native_normal=normalize(mix(NORMAL,TANGENT*native_map.x+BINORMAL*native_map.y+NORMAL*native_map.z,NORMAL_MAP_DEPTH));"
        output+="if((native_capture_mode&(1u<<16u))!=0u){ALBEDO=normalize(native_normal)*.5+.5;EMISSION=vec3(0.);}" 
        output+="else if((native_capture_mode&(1u<<17u))!=0u){ALBEDO=vec3(ROUGHNESS,METALLIC,SPECULAR);EMISSION=vec3(0.);}\n"
        if handle.record.get("source_surface","")=="plane":
            code=code.replace("shader_type spatial;","shader_type spatial;uniform sampler2D native_support_depth:filter_nearest;")
            values.native_support_depth=depth_texture
            fragment_end=_body_end(code,"fragment")
            output+="vec4 native_support=texture(native_support_depth,SCREEN_UV);vec3 native_depth_bytes=round(native_support.rgb*255.);float native_depth=dot(native_depth_bytes,vec3(65536.,256.,1.))/16777215.;if(native_support.a<=0. || abs(native_depth-FRAGCOORD.z)>2./16777215.)discard;"
        code=code.insert(fragment_end,output)
        var shader=Shader.new();shader.code=code
        var material:ShaderMaterial=source if source is ShaderMaterial else ShaderMaterial.new()
        material.shader=shader
        for name in values:material.set_shader_parameter(name,values[name])
        material.render_priority=source.render_priority
        node.material_override=material
    return ""

static func make(parent:Node,record:Dictionary,world:World3D,colour:SubViewport,lighting:RefCounted,partition_layer:int=0)->Dictionary:
    var state={"views":[],"supports":[],"lighting":lighting,"support_key":[],"error":""}
    for kind in ["normal","material","depth"]:
        var view=SubViewport.new();view.size=colour.size;view.world_3d=world
        view.transparent_bg=true;view.msaa_3d=colour.msaa_3d
        view.use_hdr_2d=kind=="depth"
        view.render_target_update_mode=SubViewport.UPDATE_DISABLED;parent.add_child(view)
        var camera=Camera3D.new();view.add_child(camera)
        camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.keep_aspect=Camera3D.KEEP_WIDTH
        camera.size=float(record.canvas[0])/float(record.pixels_per_unit)
        camera.cull_mask=SUPPORT_LAYER if kind=="depth" else ((1<<15)-1)|(NORMAL_LAYER if kind=="normal" else MATERIAL_LAYER)|partition_layer
        camera.current=true
        state.views.append({"viewport":view,"camera":camera,"kind":kind})
        state[kind]=view
    var specular=SubViewport.new();specular.size=colour.size;specular.disable_3d=true
    specular.use_hdr_2d=true;specular.transparent_bg=true
    specular.render_target_update_mode=SubViewport.UPDATE_DISABLED;parent.add_child(specular)
    var specular_rect=ColorRect.new();specular_rect.size=Vector2(colour.size)
    specular_rect.mouse_filter=Control.MOUSE_FILTER_IGNORE
    var specular_material=ShaderMaterial.new();specular_material.shader=Specular
    specular_material.set_shader_parameter("native_material",state.material.get_texture())
    specular_rect.material=specular_material;specular.add_child(specular_rect)
    state.specular=specular;state.specular_rect=specular_rect
    var output=SubViewport.new();output.size=colour.size;output.disable_3d=true
    output.transparent_bg=true;output.use_hdr_2d=true
    output.render_target_update_mode=SubViewport.UPDATE_DISABLED;parent.add_child(output)
    var ambient=CanvasModulate.new();ambient.color=Color(.18,.18,.18).linear_to_srgb();output.add_child(ambient)
    var rectangle=Sprite2D.new();rectangle.centered=false
    var white=Image.create(1,1,false,Image.FORMAT_RGBA8);white.fill(Color.WHITE)
    var canvas_texture=CanvasTexture.new();canvas_texture.diffuse_texture=ImageTexture.create_from_image(white)
    canvas_texture.specular_texture=specular.get_texture();canvas_texture.specular_shininess=1.0
    rectangle.texture=canvas_texture;rectangle.scale=Vector2(colour.size)
    var material=ShaderMaterial.new();material.shader=Receiver
    material.set_shader_parameter("native_colour",colour.get_texture())
    material.set_shader_parameter("native_normals",state.normal.get_texture())
    material.set_shader_parameter("native_material",state.material.get_texture())
    rectangle.material=material;output.add_child(rectangle)
    state.output=output;state.rectangle=rectangle;state.material_owner=material;state.colour=colour
    var support_owner=Node3D.new();state.depth.add_child(support_owner);state.support_owner=support_owner
    lighting.attach_page(output)
    return state

static func sample(state:Dictionary,camera_basis:Basis,target:Vector3,context:Dictionary)->String:
    if not context.has("screen_origin") or not context.has("pixel_scale"):return "Native receiving sample needs its actual screen registration"
    var size=Vector2i(state.colour.size)
    var scale:float=context.pixel_scale
    if scale<=0:return "Native receiving pixel scale must be positive"
    state.output.size=size
    var specular_resized=state.specular.size!=size
    # Godot4.7 CanvasTexture keeps its own list of native uniform sets. Clear
    # that owner BEFORE resizing its viewport texture invalidates those sets.
    var channels:CanvasTexture=state.rectangle.texture
    if specular_resized:channels.specular_texture=null
    state.specular.size=size;state.specular_rect.size=Vector2(size)
    if specular_resized:channels.specular_texture=state.specular.get_texture()
    state.specular.render_target_update_mode=SubViewport.UPDATE_ONCE
    # Only translation: native light heights and normals keep the same pixel
    # convention as the live Canvas page. Capture resolution follows zoom.
    state.output.global_canvas_transform=Transform2D(0,-Vector2(context.screen_origin))
    state.rectangle.position=context.screen_origin;state.rectangle.scale=Vector2(size)
    for row in state.views:
        row.viewport.size=size;row.camera.basis=camera_basis;row.camera.position=target+camera_basis.z*12.
        row.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
    var supports:Array=context.get("supports",[])
    if supports!=state.support_key:
        for node in state.supports:node.free()
        state.supports=[];state.support_key=supports.duplicate()
        for transform in supports:
            var node=MeshInstance3D.new();var mesh=PlaneMesh.new();mesh.size=Vector2.ONE
            node.mesh=mesh;node.transform=transform;node.layers=SUPPORT_LAYER
            var material=ShaderMaterial.new();material.shader=Depth;node.material_override=material
            state.support_owner.add_child(node);state.supports.append(node)
    state.output.render_target_update_mode=SubViewport.UPDATE_ONCE
    return ""

static func close(state:Dictionary)->void:
    if state.is_empty():return
    state.lighting.detach_page(state.output)
    # Destroy consumers before their viewport texture providers. CanvasTexture
    # keeps an RD uniform set for the specular page; freeing that page first
    # invalidates the set while its native Canvas consumer is still alive.
    state.rectangle.texture=null
    state.rectangle.material=null
    for name in ["native_colour","native_normals","native_material"]:
        state.material_owner.set_shader_parameter(name,null)
    state.specular_rect.material.set_shader_parameter("native_material",null)
    state.output.free()
    state.specular.free()
    for row in state.views:row.viewport.free()
    state.clear()
