uniform sampler2D gpu_web_source : filter_nearest, repeat_disable;
uniform sampler2D gpu_web_owners : filter_nearest, repeat_disable;
uniform sampler2D gpu_web_contacts : filter_nearest, repeat_disable;
uniform int gpu_web_owner_count = 0;
uniform int gpu_web_columns = 17;
uniform int gpu_web_rows = 25;
uniform float gpu_web_clock = 0.0;
uniform float gpu_web_rise = 1.0;
uniform float gpu_web_release = .65;
uniform float gpu_web_margin = .2;
uniform float gpu_web_clearance = .012;
uniform float gpu_web_wrap_height = 1.0;
uniform mat4 gpu_web_to_world = mat4(1.0);
uniform mat4 gpu_web_to_local = mat4(1.0);

vec3 gpu_web_contact(int owner,float across,float height,vec3 origin) {
	vec2 at=clamp(vec2((across+1.0)*.5,height*gpu_web_wrap_height)*vec2(float(gpu_web_columns-1),float(gpu_web_rows-1)),vec2(0.0),vec2(float(gpu_web_columns-1),float(gpu_web_rows-1)));
	ivec2 first=ivec2(floor(at));
	vec2 ratio=fract(at);
	vec3 position=vec3(0.0);
	vec3 normal=vec3(0.0);
	for(int y=0;y<2;y++)for(int x=0;x<2;x++) {
		ivec2 cell=min(first+ivec2(x,y),ivec2(gpu_web_columns-1,gpu_web_rows-1));
		float weight=(x==0?1.0-ratio.x:ratio.x)*(y==0?1.0-ratio.y:ratio.y);
		ivec2 address=ivec2(cell.x*2,cell.y+owner*gpu_web_rows);
		position+=texelFetch(gpu_web_contacts,address,0).xyz*weight;
		normal+=texelFetch(gpu_web_contacts,address+ivec2(1,0),0).xyz*weight;
	}
	float size=length(normal);
	return origin+position+(size>.000001?normal/size:vec3(0.0))*gpu_web_clearance;
}

void gpu_web_deform(inout vec3 vertex,vec2 source_uv,vec2 vertex_id) {
	int index=int(vertex_id.x+.5);
	int width=textureSize(gpu_web_source,0).x;
	ivec2 address=ivec2(index%width,(index/width)*3);
	vec4 rest=texelFetch(gpu_web_source,address,0);
	vec4 folded=texelFetch(gpu_web_source,address+ivec2(0,1),0);
	vec4 motion=texelFetch(gpu_web_source,address+ivec2(0,2),0);
	float phase=smoothstep(rest.w,rest.w+folded.w,gpu_web_clock);
	phase=clamp(phase+.075*sin(phase*6.28318530718)*motion.x,0.0,1.0);
	vertex=mix(folded.xyz,rest.xyz,phase);
	vertex.y+=sin(phase*3.14159265359)*motion.y;
	if(gpu_web_clock<0.0)vertex.y+=sin(gpu_web_clock*15.0+motion.z*2.0)*.025*motion.w*min(1.0,-gpu_web_clock*8.0);
	float boundary=min(min(source_uv.x,1.0-source_uv.x),min(source_uv.y,1.0-source_uv.y));
	if(boundary<=.02)return;
	float strongest=0.0;
	vec3 chosen=vec3(0.0);
	for(int owner=0;owner<gpu_web_owner_count;owner++) {
		vec4 profile=texelFetch(gpu_web_owners,ivec2(0,owner),0);
		if(profile.w<.5)continue;
		vec4 timing=texelFetch(gpu_web_owners,ivec2(4,owner),0);
		float strength=smoothstep(timing.x,timing.x+gpu_web_rise,gpu_web_clock);
		if(timing.y>=0.0)strength*=1.0-smoothstep(timing.y,timing.y+gpu_web_release,gpu_web_clock);
		if(strength<=strongest)continue;
		mat4 anchored=mat4(texelFetch(gpu_web_owners,ivec2(5,owner),0),texelFetch(gpu_web_owners,ivec2(6,owner),0),texelFetch(gpu_web_owners,ivec2(7,owner),0),texelFetch(gpu_web_owners,ivec2(8,owner),0));
		vec3 original_floor=(anchored*vec4(rest.xyz,1.0)).xyz;
		vec4 origin_run=texelFetch(gpu_web_owners,ivec2(1,owner),0);
		vec4 side_width=texelFetch(gpu_web_owners,ivec2(2,owner),0);
		vec3 facing=texelFetch(gpu_web_owners,ivec2(3,owner),0).xyz;
		vec3 delta=original_floor-origin_run.xyz;
		float across=dot(delta,side_width.xyz);
		float t=(dot(delta,facing)+origin_run.w)/(2.0*origin_run.w);
		float transverse=1.0-smoothstep(side_width.w,side_width.w+gpu_web_margin,abs(across));
		strength*=transverse;
		if(t<=0.0||t>=1.0||strength<=strongest)continue;
		float fraction=clamp(across/side_width.w,-1.0,1.0);
		if(t<.5) {
			vec3 crest=gpu_web_contact(owner,fraction,1.0,profile.xyz);
			vec3 floor_anchor=origin_run.xyz+side_width.xyz*across-facing*origin_run.w;
			floor_anchor.y=original_floor.y;
			chosen=mix(floor_anchor,crest,smoothstep(0.0,.5,t));
		} else {
			vec3 support=gpu_web_contact(owner,fraction,1.0-smoothstep(.5,1.0,t),profile.xyz);
			chosen=mix(support,original_floor,smoothstep(.88,1.0,t));
		}
		strongest=strength;
	}
	if(strongest>0.0)vertex=(gpu_web_to_local*vec4(mix((gpu_web_to_world*vec4(vertex,1.0)).xyz,chosen,strongest*phase),1.0)).xyz;
}
