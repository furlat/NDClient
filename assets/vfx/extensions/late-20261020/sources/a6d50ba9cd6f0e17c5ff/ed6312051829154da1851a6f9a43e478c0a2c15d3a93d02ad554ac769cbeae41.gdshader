shader_type spatial;
uniform sampler2D factory_liquid_clock_texture : filter_nearest, repeat_disable;
uniform sampler2D factory_liquid_field_texture : filter_nearest, repeat_disable;
vec4 factory_liquid_field(int index) { return texelFetch(factory_liquid_field_texture,ivec2(index,0),0); }
float factory_liquid_electric_clock() { return texelFetch(factory_liquid_clock_texture,ivec2(0,0),0).b; }

render_mode blend_add, cull_disabled, depth_draw_never, shadows_disabled, unshaded;

uniform vec4 core_color : source_color = vec4(0.85, 0.95, 1.0, 1.0);
uniform vec4 glow_color : source_color = vec4(0.42, 0.52, 1.0, 1.0);
uniform float emission : hint_range(0.0, 12.0, 0.05) = 3.2;
uniform float alpha_mult : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform sampler2D noise_tex : repeat_enable;
uniform float noise_scale = 3.5;
uniform float noise_scroll = 1.6;

varying vec2 v_uv;



varying vec2 field_point;
uniform vec3 gpu_hand_origin = vec3(0.0);
vec3 gpu_hand_point(float index,float loop_index) {
	float angle=6.28318530718*index/17.0+factory_liquid_electric_clock()*8.0;
	return gpu_hand_origin+vec3(cos(angle),sin(angle),sin(angle*2.0)*.4)*(.11+loop_index*.035);
}
void gpu_hand_deform(inout vec3 point,inout vec3 tangent,inout vec4 ribbon_color,inout vec2 source_uv) {
	float index=point.x;
	float loop_index=point.y;
	vec3 before=gpu_hand_point(max(0.0,index-1.0),loop_index);
	vec3 after=gpu_hand_point(min(17.0,index+1.0),loop_index);
	point=gpu_hand_point(index,loop_index);
	tangent=length(after-before)>.0001?normalize(after-before):vec3(0.0,1.0,0.0);
	source_uv.y=index/17.0;
	ribbon_color=vec4(.035*(.55+.45*sin(source_uv.y*3.14159265359))*.5,0.0,0.0,1.0);
}

void vertex() {
gpu_hand_deform(VERTEX,NORMAL,COLOR,UV);

	field_point=VERTEX.xz;
	vec4 vp = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 vt = (MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	float tl = length(vt);
	vt = tl > 0.0001 ? vt / tl : vec3(0.0, 1.0, 0.0);
	vec3 viewdir = normalize(-vp.xyz);
	vec3 right = cross(vt, viewdir);
	float rl = length(right);
	right = rl > 0.0001 ? right / rl : vec3(1.0, 0.0, 0.0);
	float side = (UV.x - 0.5) * 2.0;
	vp.xyz += right * side * COLOR.r;
	v_uv = UV;
	POSITION = PROJECTION_MATRIX * vp;
}

void fragment() {
	float density=0.;
	for(int i=0;i<160;i++){
		float on_floor=1.-smoothstep(.03,.09,factory_liquid_field(i).y);
		float d=length(field_point-factory_liquid_field(i).xz)/.26;
		density+=pow(max(0.,1.-d*d),2.)*on_floor;
	}
	if(density<.48)discard;
	float cu = abs(v_uv.x - 0.5) * 2.0;
	float edge = clamp(1.0 - cu, 0.0, 1.0);

	vec2 nuv = vec2(v_uv.x * 0.6, v_uv.y * noise_scale - factory_liquid_electric_clock() * noise_scroll);
	float n1 = texture(noise_tex, nuv).r;
	float n2 = texture(noise_tex, nuv * 2.3 + vec2(0.37, -factory_liquid_electric_clock() * noise_scroll * 1.9)).r;
	float flow = 0.55 + 0.9 * mix(n1, n2, 0.5);

	float halo = pow(edge, 1.1);
	float core = pow(edge, 2.4) * (0.7 + 0.55 * flow);
	float hot = pow(edge, 4.6) * (0.45 + 1.25 * flow);
	float ends = smoothstep(0.0, 0.05, v_uv.y) * smoothstep(1.0, 0.85, v_uv.y);

	vec3 col = glow_color.rgb * halo * 0.4;
	col += core_color.rgb * core * 0.6;
	col += vec3(0.60, 0.86, 1.0) * pow(edge, 14.0) * hot * 0.14;
	float a = max(halo * 0.42, core) * ends;

	ALBEDO = col;
	EMISSION = col * emission * (0.45 + core * 2.8);
	ALPHA = clamp(a, 0.0, 1.0) * alpha_mult;
}


