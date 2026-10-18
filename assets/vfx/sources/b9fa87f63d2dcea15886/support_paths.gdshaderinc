// Original high-level receiving paths. Current actor surface is uploaded only
// on a changed pose; all clock-dependent nearest-support paths execute here.
uniform sampler2D gpu_support_points : filter_nearest, repeat_disable;
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

void gpu_support(float across, float elevation, out vec3 position, out vec3 normal) {
	vec4 best = vec4(1e30);
	ivec4 nearest = ivec4(0);
	for (int index=0; index<gpu_support_count; index++) {
		vec3 point=texelFetch(gpu_support_points,ivec2(index,0),0).xyz;
		vec2 delta=vec2(dot(point-gpu_support_centre,gpu_support_side)-across,point.y-elevation);
		float distance=dot(delta,delta);
		if (distance<best.w) {
			int slot=3;
			for (int candidate=0;candidate<3;candidate++) {
				if (distance<best[candidate]) {slot=candidate;break;}
			}
			for (int candidate=3;candidate>slot;candidate--) {
				best[candidate]=best[candidate-1]; nearest[candidate]=nearest[candidate-1];
			}
			best[slot]=distance; nearest[slot]=index;
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
			gpu_support(half_width*parity*(.30+.52*wave),bottom+height*(.18+.56*u+.055*tier),point,normal);
			float bloom=wave*(gpu_support_part==3 ? .07*smoothstep(0.,.4,seconds) : .025);
			point+=normal*(.025+bloom)+side*parity*bloom*.35;
		}
	} else if (gpu_support_kind==1) { // Holy Aura
		if (gpu_support_part==1) {
			float angle=number*6.28318530718/12.; float radius=.18+u*.18;
			point=vec3(cos(angle)*radius,.025,sin(angle)*radius); normal=vec3(0.,1.,0.);
		} else {
			gpu_support(parity*half_width*.65,bottom+height*(.72-tier*.06),point,normal);
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
			gpu_support(across,centre.y+rise,point,normal);
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
			gpu_support(parity*half_width*(.95-.32*(1.-abs(u*2.-1.))),bottom+height*(.39+tier*.19+(u-.5)*.12),point,normal);
			float separation=.03+.025*wave;
			if (gpu_support_mode==2) separation+=.05*smoothstep(0.,gpu_support_duration,seconds);
			point+=normal*separation+side*parity*.035;
		}
	} else { // Power Word Heal
		if (gpu_support_part==5) { // voice word
			float radius=.075+number*.035+.035*smoothstep(.10,.60,seconds);
			float advance=.06+number*.045+.045*smoothstep(.10,.60,seconds);
			float angle=(u-.5)*3.14159265359*.9;
			point=gpu_support_start+normalize(gpu_support_end-gpu_support_start)*advance+side*sin(angle)*radius+up*(cos(angle)-.75)*radius*.62;
		} else {
			float join=smoothstep(0.,.72,seconds);
			gpu_support(parity*half_width*(.90-.72*u)*(.75+.25*(1.-join)),bottom+height*(.24+tier*.18+u*.18),point,normal);
			point+=normal*(.028+.03*wave*(1.-join));
		}
	}
}

void gpu_directed_vertex(inout vec3 point,inout vec3 normal,inout vec3 tangent,inout vec3 binormal) {
	int piece=int(point.z+.5);
	float u=point.x;
	float edge=point.y;
	int count=33;
	if (gpu_support_kind==0) count=gpu_support_part==1 ? 49 : (gpu_support_part==2 ? 25 : 33);
	if (gpu_support_kind==1) count=gpu_support_part==1 ? 17 : 33;
	if (gpu_support_kind==2) count=piece<2 ? 41 : 9;
	if (gpu_support_kind==3) count=gpu_support_part==4 ? 33 : 25;
	if (gpu_support_kind==4) count=gpu_support_part==5 ? 25 : 41;
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
