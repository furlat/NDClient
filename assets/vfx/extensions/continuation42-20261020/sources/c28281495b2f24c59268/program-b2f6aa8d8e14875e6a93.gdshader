shader_type spatial;
global uniform sampler2D vfx_package_clock;
uniform int vfx_package_clock_slot=0;
float vfx_package_seconds(){return texelFetch(vfx_package_clock,ivec2(vfx_package_clock_slot,0),0).r;}
uniform float vfx_package_offset_orb_burst_seconds=0.0;

varying vec2 observed_local_xz;
uniform sampler2D observed_perimeter_texture;
uniform vec2 observed_cells[32];
uniform vec4 observed_open_edges[32];
uniform int observed_cell_count=0;
uniform float observed_emission_gain=0.1;
uniform float observed_alpha_response=1.0;
uniform float observed_source_contrast=0.0;
uniform float observed_base_film=0.0;

uniform float orb_burst_seconds=0.0;
uniform float orb_burst_envelope=0.0;
varying vec3 actual_trail_world;
render_mode unshaded,cull_disabled; // or alpha_hash

uniform float speed = 2.0;
uniform float wobble_strength = 0.2;
uniform sampler2D noise_texture;

uniform vec2 noise_scale_xy = vec2(1.000000, 1.000000);

uniform vec2 Scale_XY2 = vec2(1.000000, 1.000000);
uniform vec2 Speed_XY2;

uniform vec2 substract_Speed_XY;

uniform sampler2D Base_noise2 : source_color, repeat_enable;
uniform sampler2D Texture_add : source_color, hint_default_black, repeat_disable;
uniform sampler2D Texture_substract : source_color, repeat_enable;
uniform sampler2D Gradient_Color_1D2 : source_color, repeat_disable;
uniform float Color_Intensity2 = 1;
uniform float Fill : hint_range(0, 1) = 1;
uniform sampler2D tex_frg_58 : source_color;

uniform bool enable_vertex_movement = true;

void vertex() {
vec4 actual_trail_world4=MODEL_MATRIX*vec4(VERTEX,1.0);actual_trail_world=actual_trail_world4.xyz;
	if (enable_vertex_movement){
			

	    // Use polar coordinates for more natural circular wobble
	    float radius = length(vec2(VERTEX.x, VERTEX.z));
	    float angle = atan(VERTEX.z, VERTEX.x);

	    // Sample noise using polar coordinates
	    vec2 noise_uv = vec2(angle * 0.5 + (vfx_package_seconds()+vfx_package_offset_orb_burst_seconds) * speed, radius * 0.5);
	    vec4 noise = texture(noise_texture, noise_uv * noise_scale_xy);

	    // Height-based intensity
	    float height_effect = VERTEX.y * wobble_strength;

	    // Circular wobble - push vertices outward based on noise
	    float push_strength = (noise.r - 0.5) * height_effect;

	    VERTEX.x += push_strength * cos(angle);
	    VERTEX.z += push_strength * sin(angle);

	    // Add some vertical flicker
	    VERTEX.y += (noise.g - 0.5) * height_effect * 0.5;
	}

observed_local_xz=VERTEX.xz;
}
void fragment() {


	vec2 n_out39p0 = (actual_trail_world.xz*0.42+vec2(0.25,0.5)) * Scale_XY2 ;

	vec2 n_out38p0 = Speed_XY2 * vec2((vfx_package_seconds()+vfx_package_offset_orb_burst_seconds)) + n_out39p0;

	float n_out44p0 = texture(Base_noise2, n_out38p0).r + texture(Texture_add, (actual_trail_world.xz*0.42+vec2(0.25,0.5))).r;

	float n_out36p1 = texture(Texture_substract, (actual_trail_world.xz*0.42+vec2(0.25,0.5)) + substract_Speed_XY * vec2((vfx_package_seconds()+vfx_package_offset_orb_burst_seconds)) ).r;

	float n_out45p0 = n_out44p0 - n_out36p1;

	float n_out57p0 = clamp(n_out45p0, 0.0, 1.0);

	vec4 n_out48p0 = texture(Gradient_Color_1D2, vec2(n_out57p0));


	vec3 n_out49p0 = vec3(n_out48p0.xyz) * vec3(Color_Intensity2);

	float n_out58p1 = texture(tex_frg_58, (actual_trail_world.xz*0.42+vec2(0.25,0.5))).r;

	float n_out59p0 = (1.0-smoothstep(0.0,max(Fill,0.0001),n_out58p1));


	float n_out61p0 = n_out48p0.a * n_out59p0;

// Output:0
	ALBEDO = n_out49p0;
	ALPHA = n_out61p0*smoothstep(0.06,0.40,n_out57p0);
	//ALPHA_SCISSOR_THRESHOLD = alpha_threshold;
	//ALPHA_HASH_SCALE = alpha_threshold;


ALPHA*=orb_burst_envelope;

	float observed_noise=texture(observed_perimeter_texture,observed_local_xz*0.43+vec2((vfx_package_seconds()+vfx_package_offset_orb_burst_seconds)*0.008)).r;
	float observed_width=0.09+0.03*observed_noise;
	float observed_inset=0.015+0.14*observed_noise;
	float observed_radius=0.22+0.06*observed_noise;
	float observed_membership=0.0;
	for(int i=0;i<32;i++){
		if(i>=observed_cell_count)break;
		vec2 observed_relative=observed_local_xz-observed_cells[i];
		vec2 observed_distance=abs(observed_relative);
		float observed_inside=1.0-step(0.50001,max(observed_distance.x,observed_distance.y));
		vec4 observed_edges=observed_open_edges[i];
		float observed_edge_x=observed_relative.x<0.0?observed_edges.x:observed_edges.y;
		float observed_edge_z=observed_relative.y<0.0?observed_edges.z:observed_edges.w;
		float observed_soft_x=mix(1.0,smoothstep(observed_inset,observed_inset+observed_width,0.5-observed_distance.x),observed_edge_x);
		float observed_soft_z=mix(1.0,smoothstep(observed_inset,observed_inset+observed_width,0.5-observed_distance.y),observed_edge_z);
		vec2 observed_corner=max(observed_distance-vec2(0.5-observed_radius),vec2(0.0));
		float observed_round=1.0-smoothstep(observed_radius-observed_width*0.45,observed_radius,length(observed_corner));
		observed_round=mix(1.0,observed_round,observed_edge_x*observed_edge_z);
		observed_membership=max(observed_membership,observed_inside*observed_soft_x*observed_soft_z*observed_round);
	}
	// Mask response precedes the occurrence envelope so birth/death stay finite.
	ALPHA=max(observed_base_film,pow(clamp(ALPHA/max(orb_burst_envelope,0.0001),0.0,1.0),observed_alpha_response))*orb_burst_envelope*observed_membership;
	float observed_native_pattern=texture(observed_perimeter_texture,observed_local_xz*0.8+vec2((vfx_package_seconds()+vfx_package_offset_orb_burst_seconds)*0.008)).r;
	float observed_material_weight=mix(1.0,0.35+0.65*observed_native_pattern*observed_native_pattern,observed_source_contrast);
	ALBEDO*=observed_material_weight;
	ALPHA*=mix(1.0,0.5+0.5*observed_native_pattern,observed_source_contrast);
	EMISSION*=observed_emission_gain;
}

