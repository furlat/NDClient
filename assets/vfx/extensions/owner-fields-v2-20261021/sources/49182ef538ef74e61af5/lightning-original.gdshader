shader_type spatial;
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
render_mode unshaded;

group_uniforms Color;
uniform vec3 primary_color : source_color = vec3(1.0,0.8,0.2);
uniform vec3 secondary_color : source_color = vec3(1.0,0.4,0.1);
uniform vec3 tertiary_color : source_color = vec3(0.6,0.1,0.05);
uniform float emission = 2.0;
uniform float color_curve = 1.0;

group_uniforms Shape;
uniform sampler2D noise_texture;
uniform vec2 noise_scale = vec2(1.0);
uniform vec2 noise_scroll = vec2(0.1, 0.3);
uniform float grow_amount : hint_range(0.0, 1.0, 0.05) = 1.0;

group_uniforms Transparency;
uniform float edge_hardness : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float edge_position : hint_range(0.0, 1.0, 0.01) = 0.2;

uniform sampler2D gradient_texture;

float overlay(float base, float blend){
	float limit = step(0.5, base);
	return mix(2.0 * base * blend, 1.0 - 2.0 * (1.0 - base) * (1.0 - blend), limit);
}

vec2 to_polar(vec2 uv)
{
	vec2 dir = uv - 0.5;
	float radius = length(dir) * 2.0;
	float angle = atan(dir.y, dir.x) * 1.0/(3.1416 * 2.0);
	return vec2(radius, angle * 2.0);
}

void vertex() {
	// Called for every vertex the material is visible on.

observed_local_xz=VERTEX.xz;
}

void fragment() {
	float gradient = texture(gradient_texture, UV).r * grow_amount;
	gradient = max(pow(gradient, 8.0), 0.0);
	
	vec2 uv = UV - 0.5;
	vec2 noise_uv = to_polar(UV) - vec2(orb_burst_seconds * 0.2, 0.0);
	float noise = texture(noise_texture, noise_uv).r;
	gradient = mix(overlay(gradient, noise), gradient, 0.5);
	float value = mix(gradient, floor(gradient * 3.0) / 3.0, edge_hardness);
	
	vec3 color = mix(secondary_color, primary_color, pow(value, color_curve));
	
	ALBEDO = color * emission;
	
	float alpha = smoothstep(edge_hardness * edge_position, 1.01 - edge_hardness * (1.0 - edge_position), gradient);
	ALPHA = alpha;

ALPHA*=orb_burst_envelope;

	float observed_noise=texture(observed_perimeter_texture,observed_local_xz*0.43+vec2(orb_burst_seconds*0.008)).r;
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
	float observed_native_pattern=texture(observed_perimeter_texture,observed_local_xz*0.8+vec2(orb_burst_seconds*0.008)).r;
	float observed_material_weight=mix(1.0,0.35+0.65*observed_native_pattern*observed_native_pattern,observed_source_contrast);
	ALBEDO*=observed_material_weight;
	ALPHA*=mix(1.0,0.5+0.5*observed_native_pattern,observed_source_contrast);
	EMISSION*=observed_emission_gain;
}
