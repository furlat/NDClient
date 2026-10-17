extends RefCounted
## Offline readback of GPU particle state. Each emitter's draw passes are
## replaced by a mesh of one-pixel quads; the capture shader writes the
## particle's transform (relative to a reference node), colour and custom
## data into rows of a float viewport. Inactive particles read back as zero.
const TEXELS:=7
const CAPTURE_LAYER:=1<<19
var viewport:SubViewport
var world:Node3D
var camera:Camera3D
var _systems:Array=[]
var _material_shader:Shader
var _mesh:ArrayMesh

func _init()->void:
    viewport=SubViewport.new()
    viewport.own_world_3d=true;viewport.use_hdr_2d=true;viewport.transparent_bg=false
    viewport.msaa_3d=Viewport.MSAA_DISABLED;viewport.screen_space_aa=Viewport.SCREEN_SPACE_AA_DISABLED
    viewport.use_taa=false;viewport.use_debanding=false;viewport.scaling_3d_scale=1.0
    viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    viewport.size=Vector2i(8,8)
    world=Node3D.new();viewport.add_child(world)
    camera=Camera3D.new();camera.cull_mask=CAPTURE_LAYER
    var environment=Environment.new()
    environment.background_mode=Environment.BG_COLOR;environment.background_color=Color(0,0,0,1)
    environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR;environment.tonemap_exposure=1.0
    camera.environment=environment
    camera.position=Vector3(0,0,100)
    viewport.add_child(camera)
    _material_shader=Shader.new()
    _material_shader.code=SHADER
    _mesh=_capture_mesh()

## Replace every emitter's draw passes with the capture pass.
func bind(emitters:Array)->void:
    _systems.clear()
    var width:int=1
    for particles in emitters:width=maxi(width,particles.amount)
    viewport.size=Vector2i(width,maxi(1,emitters.size()*TEXELS))
    for index in emitters.size():
        var particles:GPUParticles3D=emitters[index]
        var material=ShaderMaterial.new();material.shader=_material_shader
        material.set_shader_parameter("target_size",Vector2(viewport.size))
        material.set_shader_parameter("row_base",float(index*TEXELS))
        particles.draw_passes=1;particles.draw_pass_1=_mesh
        particles.material_override=material
        particles.layers=CAPTURE_LAYER
        particles.draw_order=GPUParticles3D.DRAW_ORDER_INDEX
        particles.transform_align=GPUParticles3D.TRANSFORM_ALIGN_DISABLED
        particles.trail_enabled=false
        particles.visibility_aabb=AABB(Vector3(-1e5,-1e5,-1e5),Vector3(2e5,2e5,2e5))
        _systems.append({"node":particles,"material":material})

## Call before each render: particles are read relative to their own emitter
## node (playback keeps that node where the source had it, so transparent
## sorting is unchanged), and source sampling reassigns render layers.
func update_reference()->void:
    for system in _systems:
        system.node.layers=CAPTURE_LAYER
        system.material.set_shader_parameter("capture_from_world",Projection(system.node.global_transform.affine_inverse()))

## The whole capture as RGBA floats, row-major (width = viewport width).
func read_floats()->PackedFloat32Array:
    var image:Image=viewport.get_texture().get_image()
    image.convert(Image.FORMAT_RGBAF)
    return image.get_data().to_float32_array()

## Particle `particle` of system `index` from read_floats(): 20 values
## (basis x/y/z, origin, colour, custom) and whether it is alive.
func particle(data:PackedFloat32Array,index:int,particle:int)->Dictionary:
    var width:int=viewport.size.x
    var v:PackedFloat32Array=PackedFloat32Array()
    for k in TEXELS:
        var at:int=((index*TEXELS+k)*width+particle)*4
        v.append(data[at]);v.append(data[at+1]);v.append(data[at+2])
    var origin:=Vector3(v[9],v[10],v[11])
    var alive:bool=v[20]>0.5 and is_finite(origin.x) and is_finite(origin.y) and is_finite(origin.z)
    return {"alive":alive,"values":v.slice(0,20)}

func read()->Array:
    var data:PackedFloat32Array=read_floats()
    var result:Array=[]
    for index in _systems.size():
        var states:Array=[]
        for number in int(_systems[index].node.amount):
            var state:Dictionary=particle(data,index,number)
            var v:PackedFloat32Array=state.values
            states.append({"written":state.alive,"transform":Transform3D(Basis(Vector3(v[0],v[1],v[2]),Vector3(v[3],v[4],v[5]),Vector3(v[6],v[7],v[8])),Vector3(v[9],v[10],v[11])),
                "colour":Color(v[12],v[13],v[14],v[15]),"custom":Vector4(v[16],v[17],v[18],v[19])})
        result.append(states)
    return result

static func _capture_mesh()->ArrayMesh:
    var vertices=PackedVector3Array();var uvs=PackedVector2Array();var corners=PackedVector2Array()
    for k in TEXELS:
        for corner in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]:
            vertices.append(Vector3(corner.x,corner.y,0)*0.01);uvs.append(Vector2(k,0));corners.append(corner)
    var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_TEX_UV2]=corners
    var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
    mesh.custom_aabb=AABB(Vector3(-1e5,-1e5,-1e5),Vector3(2e5,2e5,2e5))
    return mesh

const SHADER:="""
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, skip_vertex_transform, fog_disabled, shadows_disabled;
uniform vec2 target_size;
uniform float row_base;
uniform mat4 capture_from_world = mat4(1.0);
varying flat vec3 value;
void vertex() {
	int k = int(UV.x + 0.5);
	vec2 pixel = vec2(float(INSTANCE_ID), row_base + float(k)) + UV2;
	vec2 ndc = pixel / target_size * 2.0 - 1.0;
	POSITION = vec4(ndc.x, ndc.y, 0.5, 1.0);
	mat4 m = capture_from_world * MODEL_MATRIX;
	vec4 c = COLOR;
	vec4 u = INSTANCE_CUSTOM;
	if (k == 0) value = m[0].xyz;
	else if (k == 1) value = m[1].xyz;
	else if (k == 2) value = m[2].xyz;
	else if (k == 3) value = m[3].xyz;
	else if (k == 4) value = c.rgb;
	else if (k == 5) value = vec3(c.a, u.x, u.y);
	else value = vec3(u.z, u.w, 1.0);
}
void fragment() {
	ALBEDO = value;
}
"""
