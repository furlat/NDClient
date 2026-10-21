shader_type spatial;
global uniform sampler2D vfx_package_clock;
uniform int vfx_package_clock_slot=0;
float vfx_package_seconds(){return texelFetch(vfx_package_clock,ivec2(vfx_package_clock_slot,0),0).r;}
uniform float vfx_package_offset_source_clock=0.0;
uniform float vfx_package_offset_gpu_gust_time=0.0;

uniform sampler2D owner_cells : filter_nearest, repeat_disable;
uniform ivec2 owner_mask_origin = ivec2(0);
uniform vec3 owner_world_anchor = vec3(0.0);

uniform float source_clock=0.0;uniform float opacity=1.0;
render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_disabled, diffuse_lambert, specular_schlick_ggx, depth_prepass_alpha;

uniform vec2 Scale = vec2(1.000000, 1.000000);
uniform vec2 Speed_XY;
uniform sampler2D Disolver_Texture : source_color, repeat_enable;
uniform sampler2D Multiply_Texture : source_color, repeat_disable;
uniform sampler2D Color_1D_Gradient : source_color, repeat_disable;
uniform bool UseFresnel = false;
uniform vec2 Screen_Distortion_Speed;
uniform vec2 Screen_Distortion_Scale = vec2(1.000000, 1.000000);
uniform bool FresnelInver = false;
uniform float FresnelPower = 1.0;
uniform sampler2D Metallic_Texture : source_color, repeat_disable;
uniform sampler2D Texture_Roughtness : source_color, repeat_enable;
uniform sampler2D Roughtness_1D_Gradient : source_color, repeat_disable;
uniform float Ambient_light : hint_range(0.0, 1.0) = 0.30000001192093;
uniform sampler2D Normal_Texture : hint_normal, repeat_enable;
uniform float Normal_Map_Depth = 1.0;



uniform int gpu_gust_piece = 0;
uniform float gpu_gust_time = 0.0;
uniform float gpu_gust_reach = 0.0;
uniform vec3 gpu_gust_hand = vec3(0.0);
uniform vec3 gpu_gust_direction = vec3(1.0,0.0,0.0);
uniform vec3 gpu_gust_across = vec3(0.0,0.0,1.0);
vec3 gpu_gust_point(float station,float edge) {
	float u=station/64.0;
	float which=float(gpu_gust_piece);
	float lengths[3]={13.0,9.3,6.2};
	float widths[3]={1.15,.83,.61};
	float offsets[3]={-.85,.75,.15};
	float start=mix(max(0.0,gpu_gust_reach-lengths[gpu_gust_piece]),0.0,smoothstep(1.3,1.7,(vfx_package_seconds()+vfx_package_offset_gpu_gust_time)));
	float along=mix(start,gpu_gust_reach,u);
	float off=offsets[gpu_gust_piece]+.38*sin(u*8.0-(vfx_package_seconds()+vfx_package_offset_gpu_gust_time)*2.3+which*2.0)+.15*sin(u*17.0-(vfx_package_seconds()+vfx_package_offset_gpu_gust_time)*3.1);
	float height=.8+which*.30+.38*sin(u*8.0-(vfx_package_seconds()+vfx_package_offset_gpu_gust_time)*2.5+which);
	float width=widths[gpu_gust_piece]*pow(max(0.0,sin(3.14159265359*u)),.7)*(.72+.28*sin(u*19.0-(vfx_package_seconds()+vfx_package_offset_gpu_gust_time)*4.0+which));
	float roll=.8+.45*sin(u*9.0-(vfx_package_seconds()+vfx_package_offset_gpu_gust_time)*1.3+which);
	vec3 axis=gpu_gust_across*cos(roll)+vec3(0.0,1.0,0.0)*sin(roll);
	float blend=1.0-smoothstep(0.0,4.0,along);
	return gpu_gust_direction*along+(vec3(gpu_gust_hand.x,0.0,gpu_gust_hand.z)+vec3(0.0,gpu_gust_hand.y-height,0.0))*blend+gpu_gust_across*off*(1.0-blend)+vec3(0.0,height,0.0)+axis*width*edge;
}
void gpu_directed_vertex(inout vec3 point,inout vec3 normal,inout vec3 tangent,inout vec3 binormal) {
	float station=point.x;
	float edge=point.y;
	vec3 previous=gpu_gust_point(max(0.0,station-1.0),0.0);
	vec3 following=gpu_gust_point(min(64.0,station+1.0),0.0);
	vec3 along=following-previous;
	along=length(along)>.000001?normalize(along):vec3(0.0);
	vec3 across=gpu_gust_point(station,1.0)-gpu_gust_point(station,-1.0);
	across=length(across)>.000001?normalize(across):vec3(1.0,0.0,0.0);
	normal=cross(across,along);
	normal=length(normal)>.000001?normalize(normal):vec3(0.0,1.0,0.0);
	tangent=across;
	binormal=normalize(cross(normal,tangent));
	point=gpu_gust_point(station,edge);
}

void vertex() {gpu_directed_vertex(VERTEX,NORMAL,TANGENT,BINORMAL);
// GetBillboardMatrix:2
	// Node is disabled and code is not generated.
}

void fragment() {
// Vector2Parameter:16
	vec2 n_out16p0 = Scale;


// UVFunc:15
	vec2 n_in15p2 = vec2(0.00000, 0.00000);
	vec2 n_out15p0 = (UV - n_in15p2) * n_out16p0 + n_in15p2;


// Vector2Parameter:21
	vec2 n_out21p0 = Speed_XY;


// Input:31
	float n_out31p0 = (vfx_package_seconds()+vfx_package_offset_source_clock);


// VectorOp:32
	vec2 n_out32p0 = n_out21p0 * vec2(n_out31p0);


// UVFunc:20
	vec2 n_in20p1 = vec2(1.00000, 1.00000);
	vec2 n_out20p0 = n_out32p0 * n_in20p1 + n_out15p0;


	vec4 n_out10p0;
// Texture2D:10
	n_out10p0 = texture(Disolver_Texture, n_out20p0);
	float n_out10p1 = n_out10p0.r;


	vec4 n_out91p0;
// Texture2D:91
	n_out91p0 = texture(Multiply_Texture, UV);
	float n_out91p1 = n_out91p0.r;


// FloatOp:92
	float n_out92p0 = n_out10p1 * n_out91p1;


	vec4 n_out30p0;
// Texture2D:30
	n_out30p0 = texture(Color_1D_Gradient, vec2(n_out92p0));
	float n_out30p4 = n_out30p0.a;


// Input:36
	vec4 n_out36p0 = COLOR;


// VectorOp:35
	vec3 n_out35p0 = vec3(n_out30p0.xyz) * vec3(n_out36p0.xyz);


// BooleanParameter:85
	bool n_out85p0 = UseFresnel;


// Vector2Parameter:80
	vec2 n_out80p0 = Screen_Distortion_Speed;


// Input:79
	float n_out79p0 = (vfx_package_seconds()+vfx_package_offset_source_clock);


// VectorOp:81
	vec2 n_out81p0 = n_out80p0 * vec2(n_out79p0);


// UVFunc:76
	vec2 n_in76p1 = vec2(1.00000, 1.00000);
	vec2 n_out76p0 = n_out81p0 * n_in76p1 + UV;


// Vector2Parameter:78
	vec2 n_out78p0 = Screen_Distortion_Scale;


// UVFunc:77
	vec2 n_in77p2 = vec2(0.00000, 0.00000);
	vec2 n_out77p0 = (n_out76p0 - n_in77p2) * n_out78p0 + n_in77p2;


// Input:87
	vec3 n_out87p0 = NORMAL;


// VectorOp:88
	vec3 n_out88p0 = vec3(n_out77p0, 0.0) + n_out87p0;


// BooleanParameter:82
	bool n_out82p0 = FresnelInver;


// FloatParameter:83
	float n_out83p0 = FresnelPower;


// Fresnel:84
	float n_out84p0 = n_out82p0 ? (pow(clamp(dot(n_out88p0, VIEW), 0.0, 1.0), n_out83p0)) : (pow(1.0 - clamp(dot(n_out88p0, VIEW), 0.0, 1.0), n_out83p0));


	float n_out86p0;
// Switch:86
	float n_in86p2 = 1.00000;
	n_out86p0 = mix(n_in86p2, n_out84p0, float(n_out85p0));


// Input:4
	vec4 n_out4p0 = COLOR;
	float n_out4p4 = n_out4p0.a;


// Step:74
	float n_out74p0 = smoothstep(.08,.68,n_out92p0);


// FloatOp:75
	float n_out75p0 = n_out30p4 * n_out74p0;


// FloatOp:89
	float n_out89p0 = n_out86p0 * n_out75p0;


// Reroute:28
	vec2 n_out28p0 = n_out20p0;


	vec4 n_out26p0;
// Texture2D:26
	n_out26p0 = texture(Metallic_Texture, n_out28p0);
	float n_out26p1 = n_out26p0.r;


	vec4 n_out25p0;
// Texture2D:25
	n_out25p0 = texture(Texture_Roughtness, n_out28p0);
	float n_out25p1 = n_out25p0.r;


	vec4 n_out34p0;
// Texture2D:34
	n_out34p0 = texture(Roughtness_1D_Gradient, vec2(n_out25p1));
	float n_out34p1 = n_out34p0.r;


// FloatParameter:65
	float n_out65p0 = Ambient_light;


// VectorOp:66
	vec3 n_out66p0 = n_out35p0 * vec3(n_out65p0);


	vec4 n_out23p0;
// Texture2D:23
	n_out23p0 = texture(Normal_Texture, n_out28p0);


// FloatParameter:37
	float n_out37p0 = Normal_Map_Depth;


// Output:0
	ALBEDO = n_out35p0;
	ALPHA = n_out89p0;
	METALLIC = n_out26p1;
	ROUGHNESS = n_out34p1;
	EMISSION = n_out66p0;
	NORMAL_MAP = vec3(n_out23p0.xyz);
	NORMAL_MAP_DEPTH = n_out37p0;



ALBEDO=vec3(dot(ALBEDO,vec3(0.2126,0.7152,0.0722)))*vec3(0.96,0.98,0.96);ALPHA*=opacity;

ALPHA*=smoothstep(0.0,.16,UV.x)*(1.-smoothstep(.84,1.0,UV.x));

vec3 owner_world=(INV_VIEW_MATRIX*vec4(VERTEX,1.0)).xyz-owner_world_anchor;
ivec2 owner_cell=ivec2(floor(owner_world.xz+vec2(0.5)))-owner_mask_origin;
ivec2 owner_size=textureSize(owner_cells,0);
if(any(lessThan(owner_cell,ivec2(0)))||any(greaterThanEqual(owner_cell,owner_size)))discard;
if(texelFetch(owner_cells,owner_cell,0).r<0.5)discard;
}

