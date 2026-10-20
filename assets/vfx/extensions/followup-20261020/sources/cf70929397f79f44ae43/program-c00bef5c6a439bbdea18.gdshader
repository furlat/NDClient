shader_type spatial;
uniform mat4 factory_world_to_source=mat4(1.0);
uniform float support_clock=0.0;
uniform float support_envelope=1.0;
render_mode unshaded; // or alpha_hash

varying vec3 hellish_local;
uniform float break_strip=0.0;
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

void vertex() { hellish_local=VERTEX;
	if (enable_vertex_movement){
			

	    // Use polar coordinates for more natural circular wobble
	    float radius = length(vec2(VERTEX.x, VERTEX.z));
	    float angle = atan(VERTEX.z, VERTEX.x);

	    // Sample noise using polar coordinates
	    vec2 noise_uv = vec2(angle * 0.5 + support_clock * speed, radius * 0.5);
	    vec4 noise = texture(noise_texture, noise_uv * noise_scale_xy);

	    // Height-based intensity
	    float height_effect = VERTEX.y * wobble_strength;

	    // Circular wobble - push vertices outward based on noise
	    float push_strength = (noise.r - 0.5) * height_effect;

	    VERTEX.x += push_strength * cos(angle);
	    VERTEX.z += push_strength * sin(angle);

	    // Add some vertical flicker
	    VERTEX.y += (noise.g - 0.5) * height_effect * 0.5; VERTEX.x += sin(VERTEX.y*1.4 + support_clock*7.0)*pow(max(VERTEX.y,0.0)/4.0,1.6)*0.9;
	}
}
void fragment() {
vec3 support_world=(factory_world_to_source * INV_VIEW_MATRIX * vec4(VERTEX,1.0)).xyz;




	vec2 n_out39p0 = UV * Scale_XY2 ;

	vec2 n_out38p0 = Speed_XY2 * vec2(support_clock) + n_out39p0;

	float n_out44p0 = texture(Base_noise2, n_out38p0).r * 1.6 + texture(Texture_add, UV).r * 0.48;

	float n_out36p1 = texture(Texture_substract, UV + substract_Speed_XY * vec2(support_clock) ).r;

	float n_out45p0 = n_out44p0 - n_out36p1;

	float n_out57p0 = clamp(n_out45p0, 0.0, 1.0);

	vec4 n_out48p0 = texture(Gradient_Color_1D2, vec2(n_out57p0));


	vec3 n_out49p0 = vec3(n_out48p0.xyz) * vec3(Color_Intensity2);

	float n_out58p1 = texture(tex_frg_58, UV).r;

	float n_out59p0 = smoothstep(Fill,0.0,n_out58p1);


	float n_out61p0 = n_out48p0.a * n_out59p0;

// Output:0
	ALBEDO = n_out49p0;
	float lower_cut=0.95 + 0.35*sin(atan(hellish_local.z,hellish_local.x)*2.0 + 0.7); float root_open=smoothstep(lower_cut,lower_cut+0.34,hellish_local.y); float crown=1.0-smoothstep(2.85,3.5,hellish_local.y); ALPHA = n_out61p0 * smoothstep(0.08,0.28,n_out57p0) * root_open * crown * (1.0-break_strip*(1.0-smoothstep(0.08,0.30,abs(hellish_local.y-(2.05+0.16*sin(hellish_local.x*7.0+support_clock*5.0))))));
	//ALPHA_SCISSOR_THRESHOLD = alpha_threshold;
	//ALPHA_HASH_SCALE = alpha_threshold;


ALPHA *= support_envelope;
}



