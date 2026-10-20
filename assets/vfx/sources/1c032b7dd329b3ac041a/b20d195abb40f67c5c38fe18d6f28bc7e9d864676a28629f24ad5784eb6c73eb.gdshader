shader_type spatial;
#include "res://assets/vfx/sources/eb06cc2929dc57d35d5b/cie_d65_v1.gdshaderinc"
uniform sampler2D native_palette_texture:filter_nearest,repeat_disable;
uniform int native_palette_count=1;
uniform bool native_palette_quantize=true;
uniform float native_emission_gain=0.0;
uniform float native_palette_exposure=1.0;
render_mode world_vertex_coords, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 wake_inner[4];
uniform vec4 wake_tip[4];
uniform int wake_count = 0;
uniform float wake_seconds = 0.0;
uniform float wake_history_seconds = .075;
uniform float wake_maximum_reach_cells = .16;
uniform int wake_mode = 0;
uniform float wake_opacity = .75;
uniform sampler2D wake_source : filter_linear, repeat_disable;
uniform sampler2D wake_detail : filter_linear, repeat_enable;
uniform vec3 wake_dark : source_color = vec3(.24,.015,.004);
uniform vec3 wake_body : source_color = vec3(.95,.18,.015);
uniform vec3 wake_edge : source_color = vec3(1.0,.59,.13);
varying float wake_birth;
varying float wake_admitted;

void vertex() {
    int pair = clamp(int(round(UV2.x)), 0, 2);
    vec4 new_inner = wake_inner[pair];
    vec4 old_inner = wake_inner[pair + 1];
    vec4 new_tip = wake_tip[pair];
    vec4 old_tip = wake_tip[pair + 1];
    float actual_distance = max(length(old_inner.xyz-new_inner.xyz), length(old_tip.xyz-new_tip.xyz));
    // Clip the rendered wake to a short reach of the current actual edge.
    // History retains exact samples, not these clipped rendering coordinates.
    // This prevents several small strips accumulating into a broad old fan.
    float new_distance=max(length(new_inner.xyz-wake_inner[0].xyz),length(new_tip.xyz-wake_tip[0].xyz));
    float old_distance=max(length(old_inner.xyz-wake_inner[0].xyz),length(old_tip.xyz-wake_tip[0].xyz));
    float new_bound=min(1.0,wake_maximum_reach_cells/max(new_distance,.000001));
    float old_bound=min(1.0,wake_maximum_reach_cells/max(old_distance,.000001));
    vec3 newer_inner=mix(wake_inner[0].xyz,new_inner.xyz,new_bound);
    vec3 newer_tip=mix(wake_tip[0].xyz,new_tip.xyz,new_bound);
    vec3 older_inner=mix(wake_inner[0].xyz,old_inner.xyz,old_bound);
    vec3 older_tip=mix(wake_tip[0].xyz,old_tip.xyz,old_bound);
    vec3 newer = mix(newer_inner,newer_tip,UV.x);
    vec3 older = mix(older_inner,older_tip,UV.x);
    VERTEX = mix(newer,older,UV.y);
    float new_birth=pair==0 ? wake_seconds : new_inner.w;
    wake_birth = mix(mix(wake_seconds,new_birth,new_bound),mix(wake_seconds,old_inner.w,old_bound),UV.y);
    wake_admitted = float(pair+1<wake_count && actual_distance>.002);
}

float electric_frame(float frame,vec2 uv) {
    float cell=mod(frame,4.0);
    vec2 tile=vec2(mod(cell,2.0),floor(cell/2.0));
    vec4 source=texture(wake_source,(tile+clamp(uv,vec2(.003),vec2(.997)))*.5);
    return source.r*source.a;
}

void fragment() {
    float age=max(wake_seconds-wake_birth,0.0)/max(wake_history_seconds,.001);
    float lifetime=1.0-smoothstep(.12,1.0,age);
    float side=smoothstep(0.0,.13,UV.x)*(1.0-smoothstep(.90,1.0,UV.x));
    float density=0.0;
    float energy=0.0;
    if(wake_mode==0) {
        // The inspected Stylized Fire mask has tapered flame tongues. The
        // sword donor's explosion flipbook made this tiny wake a round puff.
        // Distortion advects along exact base->tip; it never changes the axis.
        float detail=texture(wake_detail,vec2(UV.y*1.2,UV.x*.9-wake_seconds*1.4)).r;
        vec2 source_uv=vec2(clamp(.5+(UV.y-.5)*.86+(detail-.4)*.13,.002,.998),1.0-UV.x);
        float flame=texture(wake_source,source_uv).r;
        density=smoothstep(.08,.60,flame*(.88+detail*.45));
        energy=clamp(flame*.86+detail*.30,0.0,1.0);
    } else if(wake_mode==1) {
        // The actual Magic Projectiles desaturated fire trail supplies fine
        // filaments. Its former four-point flare input had almost no coverage.
        vec2 source_uv=vec2(fract(UV.x*.72-wake_seconds*.26),.18+UV.y*.63);
        vec4 source=texture(wake_source,source_uv);
        float pattern=source.r*source.a;
        float detail=texture(wake_detail,vec2(UV.x*1.8-wake_seconds*.6,UV.y*.7)).r;
        density=pow(clamp(pattern,0.0,1.0),.62)*(.82+detail*.25);
        energy=clamp(pattern*1.15+.12,0.0,1.0);
    } else if(wake_mode==2) {
        // Binbun Manhattan source cells make separated crystalline rakes.
        float cells=texture(wake_source,vec2(UV.x*.80,UV.y*.70)).r;
        float detail=texture(wake_detail,vec2(UV.x*1.4+.13,UV.y*.9)).r;
        float crack=1.0-smoothstep(.012,.085,abs(cells-.50));
        density=clamp(crack*.8+smoothstep(.60,.78,detail)*.48,0.0,1.0);
        energy=clamp(crack*.8+detail*.45,0.0,1.0);
    } else if(wake_mode==3) {
        // A distinct lower-fill rime wisp combines the native two cell fields;
        // no falling confetti, rigid ice movement or recoloured fire flipbook.
        float cells=texture(wake_source,vec2(UV.x*.55+.11,UV.y*.45)).r;
        float detail=texture(wake_detail,vec2(UV.x*.8,UV.y*.6+.21)).r;
        density=smoothstep(.25,.68,cells*.65+detail*.35)*.62;
        energy=cells*.5+detail*.35;
    } else {
        // The four actual native branching textures remain intact. Axial
        // threads and cross-discharge use different mappings, not white boosts.
        float clock=wake_seconds*3.0;
        vec2 source_uv=wake_mode==4 ? vec2(UV.y,1.0-UV.x) : vec2(UV.x,UV.y);
        float first=electric_frame(floor(clock),source_uv);
        float second=electric_frame(floor(clock)+1.0,source_uv);
        float arc=mix(first,second,smoothstep(.2,.8,fract(clock)));
        if(wake_mode==5) arc=max(arc,electric_frame(floor(clock)+2.0,vec2(1.0-UV.x,UV.y))*.65);
        density=pow(clamp(arc,0.0,1.0),.70);
        energy=clamp(arc,0.0,1.0);
    }
    float alpha=clamp(density*side*lifetime*wake_opacity*wake_admitted,0.0,1.0);
    vec3 colour=mix(wake_dark,wake_body,smoothstep(.01,.55,energy));
    colour=mix(colour,wake_edge,smoothstep(.48,.98,energy)*.72);
    ALBEDO=colour*step(.00001,alpha);
    ALPHA=alpha;

	float native_raw_energy = max(max(ALBEDO.r + EMISSION.r, ALBEDO.g + EMISSION.g), ALBEDO.b + EMISSION.b);
	native_raw_energy *= native_palette_exposure;
	float native_energy = native_raw_energy / (1.0 + native_raw_energy);
	float native_position = native_energy * float(native_palette_count - 1);
	int native_first = int(floor(native_position));
	int native_second = min(native_first + 1, native_palette_count - 1);
	vec3 native_a = texture(native_palette_texture, vec2((float(native_first) + 0.5) / float(native_palette_count), 0.5)).rgb;
	vec3 native_b = texture(native_palette_texture, vec2((float(native_second) + 0.5) / float(native_palette_count), 0.5)).rgb;
	vec3 native_choice = mix(native_a, native_b, fract(native_position));
	if (native_palette_quantize) native_choice = cie_nearest(native_choice, native_palette_texture, native_palette_count, 0.0, 0.0);
	ALBEDO = vec3(cie_linear_channel(native_choice.r), cie_linear_channel(native_choice.g), cie_linear_channel(native_choice.b));
	EMISSION = ALBEDO * min(native_raw_energy, 2.0) * native_emission_gain;
	}

