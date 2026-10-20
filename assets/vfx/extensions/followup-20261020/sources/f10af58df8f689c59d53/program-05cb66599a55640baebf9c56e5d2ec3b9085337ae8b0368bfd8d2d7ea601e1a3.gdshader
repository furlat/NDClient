shader_type spatial;
render_mode blend_add, cull_disabled, depth_draw_never, shadows_disabled, unshaded;

uniform vec4 core_color : source_color = vec4(0.85, 0.95, 1.0, 1.0);
uniform vec4 glow_color : source_color = vec4(0.42, 0.52, 1.0, 1.0);
uniform float emission : hint_range(0.0, 12.0, 0.05) = 3.2;
uniform float alpha_mult : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform sampler2D noise_tex : repeat_enable;
uniform float noise_scale = 3.5;
uniform float noise_scroll = 1.6;

varying vec2 v_uv;

uniform float electric_clock = 0.;
uniform sampler2D gpu_contact_points : filter_nearest, repeat_disable;
uniform sampler2D gpu_contact_random : filter_nearest, repeat_disable;
uniform int gpu_contact_count = 0;
uniform vec3 gpu_contact_origin = vec3(0.0);
uniform mat4 gpu_contact_to_local = mat4(1.0);
uniform float gpu_contact_age = 0.0;
vec3 gpu_actor_point(int index) {
	int width=textureSize(gpu_contact_points,0).x;
	ivec2 address=ivec2(index%width,(index/width)*2);
	vec3 point=texelFetch(gpu_contact_points,address,0).xyz;
	vec3 normal=texelFetch(gpu_contact_points,address+ivec2(0,1),0).xyz;
	return (gpu_contact_to_local*vec4(gpu_contact_origin+point+normal*.035,1.0)).xyz;
}
vec3 gpu_contact_point(int strand,int index,vec3 start,vec3 end,int segments) {
	if(index<=0)return start;
	if(index>=segments)return end;
	float ratio=float(index)/float(segments);
	vec3 direction=end-start;
	vec3 side=cross(length(direction)>.000001?normalize(direction):vec3(0.0),vec3(0.0,1.0,0.0));
	side=length(side)>.000001?normalize(side):vec3(1.0,0.0,0.0);
	vec2 jitter=texelFetch(gpu_contact_random,ivec2(index,strand),0).xy;
	return mix(start,end,ratio)+(side*jitter.x+vec3(0.0,1.0,0.0)*jitter.y)*sin(ratio*3.14159265359);
}
void gpu_contact_deform(inout vec3 point,inout vec3 tangent,inout vec4 ribbon_color,inout vec2 source_uv) {
	int index=int(point.x+.5);
	int strand=int(point.y+.5);
	if(gpu_contact_count<=0) {
		point=vec3(0.0);tangent=vec3(0.0,1.0,0.0);ribbon_color=vec4(0.0);source_uv.y=0.0;
		return;
	}
	int start_index=(strand*97+int(floor(gpu_contact_age*8.0))*23)%gpu_contact_count;
	int end_index=(start_index+71+strand*11)%gpu_contact_count;
	vec3 start=gpu_actor_point(start_index);
	vec3 end=gpu_actor_point(end_index);
	int segments=max(2,int(ceil(length(end-start)/.23)));
	point=gpu_contact_point(strand,min(index,segments),start,end,segments);
	vec3 before=gpu_contact_point(strand,max(0,index-1),start,end,segments);
	vec3 after=gpu_contact_point(strand,min(segments,index+1),start,end,segments);
	tangent=length(after-before)>.0001?normalize(after-before):vec3(0.0,1.0,0.0);
	source_uv.y=min(1.0,float(index)/float(segments));
	ribbon_color=vec4(.035*(.55+.45*sin(source_uv.y*3.14159265359))*.5,0.0,0.0,1.0);
	if(index>segments)ribbon_color.r=0.0;
}

void vertex() {
gpu_contact_deform(VERTEX,NORMAL,COLOR,UV);

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
	float cu = abs(v_uv.x - 0.5) * 2.0;
	float edge = clamp(1.0 - cu, 0.0, 1.0);

	vec2 nuv = vec2(v_uv.x * 0.6, v_uv.y * noise_scale - electric_clock * noise_scroll);
	float n1 = texture(noise_tex, nuv).r;
	float n2 = texture(noise_tex, nuv * 2.3 + vec2(0.37, -electric_clock * noise_scroll * 1.9)).r;
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

