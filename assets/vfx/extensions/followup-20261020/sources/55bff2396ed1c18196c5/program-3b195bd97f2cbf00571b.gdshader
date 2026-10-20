shader_type spatial;
uniform mat4 factory_world_to_source=mat4(1.0);
uniform float support_clock=0.0;
uniform float support_envelope=1.0;
uniform float support_age=0.0;
render_mode unshaded, blend_mix;

uniform vec3 primary_color : source_color;
uniform sampler2D particle_texture;
uniform bool use_texture = false;
uniform bool lock = false;
uniform float emission = 2.0;

void vertex(){
	VERTEX.y += sin(support_clock * 2.0 + float(INSTANCE_ID)) * 0.05;
}

void fragment() {
vec3 support_world=(factory_world_to_source * INV_VIEW_MATRIX * vec4(VERTEX,1.0)).xyz;


	float shape = 0.0;
	
	if(use_texture && !lock){
		shape = texture(particle_texture, UV).a;
		ALPHA = shape * COLOR.a;
	} else {
		vec2 tile_uv = fract(UV - 0.5);
		
		shape = length(tile_uv * 2.0 - 1.0);
		shape = smoothstep(1.0, 1.2, shape);
		ALPHA = shape * COLOR.a;
	}
	
	
	ALBEDO = primary_color * emission;

ALPHA *= support_envelope;
ALPHA *= 1.0-smoothstep(1.8,2.8,support_age)*(1.0-smoothstep(1.10,1.20,support_world.y));
}



