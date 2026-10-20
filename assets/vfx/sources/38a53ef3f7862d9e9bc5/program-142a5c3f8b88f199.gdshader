shader_type spatial;
uniform float support_clock=0.0;
uniform float support_envelope=0.0;
uniform float support_visibility=1.0;

render_mode unshaded;

group_uniforms Color;
uniform vec3 primary_color : source_color = vec3(1.0,0.8,0.2);
uniform vec3 secondary_color : source_color = vec3(1.0,0.4,0.1);
uniform vec3 tertiary_color : source_color = vec3(0.6,0.1,0.05);
uniform float emission = 2.0;
uniform float color_curve = 1.0;
uniform float hue_variation = 0.1;
uniform bool use_secondary = false;

group_uniforms Shape;
uniform sampler2D noise_texture;
uniform vec2 noise_scale = vec2(0.5);
uniform vec2 noise_scroll = vec2(0.0, 0.1);
uniform float shape_curve = 2.0;
uniform float noise_twist : hint_range(-1.0, 1.0, 0.05) = 0.0;
uniform float waviness : hint_range(0.0, 1.0, 0.01) = 0.2;

group_uniforms Transparency;
uniform float edge_hardness : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float edge_position : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform bool proximity_fade = false;
uniform float proximity_fade_distance : hint_range(0.0, 4096.0, 0.01);
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

vec3 shift_hue(vec3 color, float shift) {
	vec3 gray = vec3(0.57735);
	vec3 projection = gray * dot(gray, color.rgb);
	vec3 U = color.rgb - projection;
	vec3 V = cross(gray, U);
	vec3 shifted = U * cos(shift * 2.0 * PI) + V * sin(shift * 2.0 * PI) + projection;
	return shifted;
}

// Original high-level receiving paths. Current actor surface is uploaded only
// on a changed pose; all clock-dependent nearest-support paths execute here.
uniform sampler2D gpu_support_points : filter_nearest, repeat_disable;
uniform sampler2D gpu_support_fixed_queries : filter_nearest, repeat_disable;
uniform bool gpu_support_precise_queries = false;
uniform sampler2D gpu_support_holy_roots : filter_nearest, repeat_disable;
uniform int gpu_support_count = 0;
uniform int gpu_support_kind = 0;
uniform int gpu_support_part = 0;
uniform int gpu_support_mode = 0;
uniform vec3 gpu_support_centre;
uniform vec3 gpu_support_normal;
uniform vec3 gpu_support_up;
uniform vec3 gpu_support_side;
uniform float gpu_support_bottom;
uniform float gpu_support_height;
uniform float gpu_support_half_width;
uniform float gpu_support_seconds;
uniform float gpu_support_duration;
uniform float gpu_support_width;
uniform float gpu_support_radius;
uniform vec3 gpu_support_start;
uniform vec3 gpu_support_end;
uniform int gpu_support_piece_count = 1;

// Error-free float pairs preserve source query comparisons at sparse ties.
vec2 precise_add(vec2 a,vec2 b){
 float sum=a.x+b.x;float v=sum-a.x;
 float error=(a.x-(sum-v))+(b.x-v)+a.y+b.y;
 float high=sum+error;return vec2(high,error-(high-sum));
}
vec2 precise_square(vec2 a){
 float product=a.x*a.x;
 float error=fma(a.x,a.x,-product)+2.0*a.x*a.y+a.y*a.y;
 float first=product+error;return vec2(first,error-(first-product));
}

void gpu_support(float across, float elevation, out vec3 position, out vec3 normal, int fixed_query) {
	vec4 best = vec4(1e30);
	vec4 best_low = vec4(0.);
	vec4 query = vec4(0.);
	if (gpu_support_precise_queries && fixed_query >= 0) query = texelFetch(gpu_support_fixed_queries, ivec2(fixed_query, 0), 0);
	ivec4 nearest = ivec4(0);
	for (int index=0; index<gpu_support_count; index++) {
		vec3 point=texelFetch(gpu_support_points,ivec2(index,0),0).xyz;
		vec2 delta=vec2(dot(point-gpu_support_centre,gpu_support_side)-across,point.y-elevation);
		float distance=dot(delta,delta);
		float distance_low=0.;
		if (gpu_support_precise_queries && fixed_query >= 0) {
			vec2 coordinates=texelFetch(gpu_support_points,ivec2(index,2),0).xy;
			vec2 x=precise_add(vec2(coordinates.x,0.),-query.xy);
			vec2 y=precise_add(vec2(coordinates.y,0.),-query.zw);
			vec2 squared=precise_add(precise_square(x),precise_square(y));
			distance=squared.x;distance_low=squared.y;
		}
		if (distance<best.w || (distance==best.w && distance_low<best_low.w)) {
			int slot=3;
			for (int candidate=0;candidate<3;candidate++) {
				if (distance<best[candidate] || (distance==best[candidate] && distance_low<best_low[candidate])) {slot=candidate;break;}
			}
			for (int candidate=3;candidate>slot;candidate--) {
				best[candidate]=best[candidate-1]; best_low[candidate]=best_low[candidate-1]; nearest[candidate]=nearest[candidate-1];
			}
			best[slot]=distance; best_low[slot]=distance_low; nearest[slot]=index;
		}
	}
	position=vec3(0.); normal=vec3(0.); float total=0.;
	for (int index=0;index<4;index++) {
		float weight=1./(best[index]+.00015);
		position+=texelFetch(gpu_support_points,ivec2(nearest[index],0),0).xyz*weight;
		normal+=texelFetch(gpu_support_points,ivec2(nearest[index],1),0).xyz*weight;
		total+=weight;
	}
	position/=total; normal=normalize(normal);
}

// The original tangent query preserves the requested UV grid and changes only
// measured normal-space support. It uses the same four inverse-distance weights.
void gpu_tangent_support(vec3 centre, float across, float rise, out vec3 position, out vec3 normal) {
	vec4 best = vec4(1e30);
	ivec4 nearest = ivec4(0);
	for (int index = 0; index < gpu_support_count; index++) {
		vec3 point = texelFetch(gpu_support_points, ivec2(index, 0), 0).xyz;
		vec3 relative = point - centre;
		vec2 delta = vec2(dot(relative, gpu_support_side) - across, dot(relative, gpu_support_up) - rise);
		float distance = dot(delta, delta);
		if (distance < best.w) {
			int slot = 3;
			for (int candidate = 0; candidate < 3; candidate++) {
				if (distance < best[candidate]) { slot = candidate; break; }
			}
			for (int candidate = 3; candidate > slot; candidate--) {
				best[candidate] = best[candidate - 1];
				nearest[candidate] = nearest[candidate - 1];
			}
			best[slot] = distance;
			nearest[slot] = index;
		}
	}
	position = vec3(0.0);
	normal = vec3(0.0);
	float total = 0.0;
	for (int index = 0; index < 4; index++) {
		float weight = 1.0 / (best[index] + .00015);
		position += texelFetch(gpu_support_points, ivec2(nearest[index], 0), 0).xyz * weight;
		normal += texelFetch(gpu_support_points, ivec2(nearest[index], 1), 0).xyz * weight;
		total += weight;
	}
	position /= total;
	position += gpu_support_side * (across - dot(position - centre, gpu_support_side));
	position += gpu_support_up * (rise - dot(position - centre, gpu_support_up));
	normal = normalize(normal);
}

void gpu_support_station(float u,int piece,out vec3 point,out vec3 normal,out float width) {
	float number=float(piece);
	float parity=piece%2==0 ? -1. : 1.;
	float tier=floor(number/2.);
	float seconds=gpu_support_seconds;
	float wave=sin(u*3.14159265359);
	float height=gpu_support_height;
	float half_width=gpu_support_half_width;
	float bottom=gpu_support_bottom;
	vec3 up=gpu_support_up;
	vec3 side=gpu_support_side;
	normal=gpu_support_normal;
	width=gpu_support_width;
	if (gpu_support_kind==0) { // Aura of Life
		if (gpu_support_part==1) { // field
			float angle=number*6.28318530718/6.+(u-.5)*.66;
			float reach=gpu_support_radius*(.18+.80*wave);
			point=vec3(cos(angle)*reach,.024+.035*wave+.006*sin(seconds*.7+number+u*3.14159265359),sin(angle)*reach);
			normal=vec3(0.,1.,0.);
		} else if (gpu_support_part==2) { // hand windup
			float angle=u*3.14159265359+number*3.14159265359;
			point=gpu_support_start+side*cos(angle)*.10+up*sin(angle)*.13+normal*.03;
		} else {
			gpu_support(half_width*parity*(.30+.52*wave),bottom+height*(.18+.56*u+.055*tier),point,normal,-1);
			float bloom=wave*(gpu_support_part==3 ? .07*smoothstep(0.,.4,seconds) : .025);
			point+=normal*(.025+bloom)+side*parity*bloom*.35;
		}
	} else if (gpu_support_kind==1) { // Holy Aura
		if (gpu_support_part==1) {
			float angle=number*6.28318530718/12.; float radius=.18+u*.18;
			point=vec3(cos(angle)*radius,.025,sin(angle)*radius); normal=vec3(0.,1.,0.);
		} else {
			point=texelFetch(gpu_support_holy_roots,ivec2(piece,0),0).xyz;
			normal=texelFetch(gpu_support_holy_roots,ivec2(piece,1),0).xyz;
			float opening=gpu_support_mode==1 ? smoothstep(0.,.45,seconds) : 1.;
			point+=normal*(.035+.025*wave)+side*parity*u*(.13+tier*.035)*opening+up*u*(.17-tier*.04)*opening;
			width*=1.-.12*tier;
		}
	} else if (gpu_support_kind==2) { // Foresight
		vec3 centre=gpu_support_part==2 ? gpu_support_start : gpu_support_centre;
		float horizontal=min(.24,max(.115,half_width*1.8));
		float vertical=min(.085,max(.045,height*.40));
		if (piece<2) {
			float opening=gpu_support_mode==1 ? smoothstep(0.,.5,seconds) : 1.;
			float across=(u*2.-1.)*horizontal;
			float rise=wave*vertical*parity*opening;
			gpu_support(across,centre.y+rise,point,normal,-1);
			point+=normal*(.045+number*.012);
			point+=side*(across-dot(point-centre,side));
			point+=up*(rise-dot(point-centre,up));
			if (gpu_support_part==2) point=centre+side*across+up*rise+gpu_support_normal*.04;
		} else {
			point=centre+side*(horizontal+.035+float(piece-2)*.028)+up*((u-.5)*.05)+normal*.055;
			width*=.65;
		}
	} else if (gpu_support_kind==3) { // Dispel Evil and Good
		if (gpu_support_part==4) {
			point=mix(gpu_support_start,gpu_support_end,u)+up*wave*(.035+number*.016)+side*wave*.05*float(piece-1);
		} else {
			gpu_support(parity*half_width*(.95-.32*(1.-abs(u*2.-1.))),bottom+height*(.39+tier*.19+(u-.5)*.12),point,normal,piece*25+int(round(u*24.)));
			float separation=.03+.025*wave;
			if (gpu_support_mode==2) separation+=.05*smoothstep(0.,gpu_support_duration,seconds);
			point+=normal*separation+side*parity*.035;
		}
	} else if (gpu_support_kind==4) { // Power Word Heal
		if (gpu_support_part==5) { // voice word
			float radius=.075+number*.035+.035*smoothstep(.10,.60,seconds);
			float advance=.06+number*.045+.045*smoothstep(.10,.60,seconds);
			float angle=(u-.5)*3.14159265359*.9;
			point=gpu_support_start+normalize(gpu_support_end-gpu_support_start)*advance+side*sin(angle)*radius+up*(cos(angle)-.75)*radius*.62;
		} else {
			float join=smoothstep(0.,.72,seconds);
			gpu_support(parity*half_width*(.90-.72*u)*(.75+.25*(1.-join)),bottom+height*(.24+tier*.18+u*.18),point,normal,-1);
			point+=normal*(.028+.03*wave*(1.-join));
		}
	} else if (gpu_support_kind==5) { // Original Divine Intervention paths
		float progress = smoothstep(0.0, .65, seconds);
		if (gpu_support_part == 1) {
			float offset = number - 2.0;
			point = gpu_support_start + up * (.08 + .42 * u) * progress
				+ side * offset * .10 * sin(u * 3.14159265359 * .7)
				+ normal * (.04 + .07 * wave);
			width = .075;
		} else if (gpu_support_part >= 2 && gpu_support_part <= 6) {
			float count = float(gpu_support_piece_count);
			float offset = (number - (count - 1.0) * .5) / max(1.0, count - 1.0);
			float reach = min(.75, height * .62) * (gpu_support_part == 2 ? 1.0 : .46);
			point = gpu_support_centre + side * (offset * min(.42, half_width * 1.25) + wave * .025)
				+ up * (u - .45) * reach + normal * (.04 + wave * .07 * progress);
			width = gpu_support_part == 2 ? .115 : gpu_support_part == 3 ? .065 : .030;
		} else if (gpu_support_part == 7) {
			point = gpu_support_start + side * parity * (.10 + wave * .08)
				+ vec3(0.0, .03 + .31 * u, 0.0) + normal * wave * .045;
			width = .038;
		} else if (gpu_support_part == 8) {
			float angle = number * 3.14159265359 * .5 + 3.14159265359 * .25;
			vec3 radial = vec3(cos(angle), 0.0, sin(angle));
			vec3 first = gpu_support_start + radial * .07 + vec3(0.0, .03, 0.0);
			vec3 second = gpu_support_start + radial * (.20 + .08 * progress) + vec3(0.0, .03, 0.0);
			vec3 third = gpu_support_start + radial * (.20 + .08 * progress) + vec3(0.0, .16, 0.0);
			point = u < .5 ? mix(first, second, u * 2.0) : mix(second, third, (u - .5) * 2.0);
			normal = cross(radial, vec3(0.0, 1.0, 0.0));
			width = .018;
		} else {
			gpu_support(parity * half_width * (.10 + .70 * wave), bottom + height * (.12 + .70 * u + .045 * tier), point, normal, -1);
			point += normal * (.035 + .035 * wave * progress);
			width = gpu_support_part == 9 ? .070 : .085;
		}
	} else if (gpu_support_kind==6) { // Original Holy Nimbus shoulder rays
		gpu_support(parity * half_width * (.62 + .18 * wave + .12 * tier), bottom + height * (.33 + .30 * u + .075 * tier), point, normal, -1);
		point += normal * (.045 + .07 * wave) + side * parity * .065 * wave;
		width = .085 - .012 * tier;
	} else if (gpu_support_kind==7) { // Original five measured Sunder clefts
		float across = (number - 2.0) * half_width * .34 + sin(u * 6.28318530718) * half_width * .07;
		float rise = (-.85 + u * 1.70) * height;
		gpu_tangent_support(gpu_support_centre, across, rise, point, normal);
		point += normal * .070;
		width = min(.095, half_width * .29);
	}
}

void gpu_directed_vertex(inout vec3 point,inout vec3 normal,inout vec3 tangent,inout vec3 binormal) {
	if (gpu_support_kind == 4 && gpu_support_part == 6) {
		vec3 supported;
		vec3 supported_normal;
		gpu_tangent_support(gpu_support_centre, (point.x * 2.0 - 1.0) * .072, (point.y * 2.0 - 1.0) * .072, supported, supported_normal);
		point = supported + supported_normal * .035;
		normal = supported_normal;
		return;
	}
	int piece=int(point.z+.5);
	float u=point.x;
	float edge=point.y;
	int count=33;
	if (gpu_support_kind==0) count=gpu_support_part==1 ? 49 : (gpu_support_part==2 ? 25 : 33);
	if (gpu_support_kind==1) count=gpu_support_part==1 ? 17 : 33;
	if (gpu_support_kind==2) count=piece<2 ? 41 : 9;
	if (gpu_support_kind==3) count=gpu_support_part==4 ? 33 : 25;
	if (gpu_support_kind==4) count=gpu_support_part==5 ? 25 : 41;
	if (gpu_support_kind==5) count=gpu_support_part==7 ? 25 : gpu_support_part==8 ? 3 : 33;
	if (gpu_support_kind==6) count=25;
	if (gpu_support_kind==7) count=49;
	vec3 centre; vec3 before; vec3 after; vec3 source_normal; vec3 ignored;
	float width; float ignored_width;
	gpu_support_station(u,piece,centre,source_normal,width);
	gpu_support_station(max(0.,u-1./float(count-1)),piece,before,ignored,ignored_width);
	gpu_support_station(min(1.,u+1./float(count-1)),piece,after,ignored,ignored_width);
	vec3 across=normalize(cross(source_normal,normalize(after-before)));
	if (length(cross(source_normal,normalize(after-before)))<.000001) across=gpu_support_side;
	width*=pow(max(0.,sin(u*3.14159265359)),.65);
	point=centre+across*edge*width+source_normal*(1.-edge*edge)*width*.18;
	normal=source_normal;
}

void vertex() {gpu_directed_vertex(VERTEX,NORMAL,TANGENT,BINORMAL);
	// Called for every vertex the material is visible on.
}

void fragment() {
	float r = length(UV * 2.0 - 1.0);
	
	vec2 noise_uv = (vec2(UV.x + UV.y * noise_twist, UV.y) + COLOR.r) * noise_scale + (noise_scroll * support_clock);
	
	float wave = sin(UV.y * 20.0 + support_clock * 6.0);
	noise_uv.x += wave * 0.1 * waviness;
	
	float noise = texture(noise_texture, noise_uv).r;
	
	float value = pow(max(noise - r, 0.0), shape_curve) * COLOR.a;
	
	float color_value = pow(value, color_curve);
	color_value = mix(color_value, floor(color_value * 6.0) / 5.0, edge_hardness);
	vec3 main_color = use_secondary ? secondary_color : primary_color;
	vec3 color = mix(tertiary_color, main_color, color_value);
	color = shift_hue(color, (COLOR.r - 0.5) * hue_variation) * (0.5 + COLOR.r * 0.5);
	
	ALBEDO = color * emission;
	ALPHA = value;
	
	// Proximity Fade: Enabled
	if(proximity_fade){
		float proximity_depth_tex = textureLod(depth_texture, SCREEN_UV, 0.0).r;
		vec4 ndc = OUTPUT_IS_SRGB ? vec4(vec3(SCREEN_UV, proximity_depth_tex) * 2.0 - 1.0, 1.0) : vec4(SCREEN_UV * 2.0 - 1.0, proximity_depth_tex, 1.0);
		vec4 proximity_view_pos = INV_PROJECTION_MATRIX * ndc;
		proximity_view_pos.xyz /= proximity_view_pos.w;
		ALPHA *= clamp(1.0 - smoothstep(proximity_view_pos.z + proximity_fade_distance, proximity_view_pos.z, VERTEX.z), 0.0, 1.0);
	}
	
	ALPHA = clamp((ALPHA - edge_position) / (1.0 - edge_hardness), 0.0, 1.0);

ALPHA=clamp(ALPHA,0.0,1.0)*support_envelope*support_visibility*0.84;
ALBEDO*=1.0;
EMISSION*=0.0;
}

