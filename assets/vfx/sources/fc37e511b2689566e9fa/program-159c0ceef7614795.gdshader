shader_type spatial;
uniform float ward_seconds=0.0;
uniform float ward_alpha=0.0;
uniform vec3 cone_origin=vec3(0.0);
uniform vec3 cone_forward=vec3(0.0,0.0,-1.0);
uniform float cone_length=3.0;
varying vec3 cone_world;
render_mode unshaded, blend_add;

group_uniforms Color;
uniform vec3 primary_color : source_color = vec3(1.0,0.8,0.2);
uniform vec3 secondary_color : source_color = vec3(1.0,0.4,0.1);
uniform vec3 tertiary_color : source_color = vec3(0.6,0.1,0.05);
uniform float emission = 2.0;

group_uniforms Shape;
uniform sampler2D noise_texture;
uniform vec2 noise_scale = vec2(1.0);
uniform vec2 noise_scroll = vec2(0.1, 0.5);
uniform float tail_length : hint_range(0.0, 1.0, 0.01) = 0.7;
uniform float grow_amount : hint_range(0.0, 1.0, 0.05) = 1.0;

group_uniforms Transparency;
uniform float edge_hardness : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float edge_position : hint_range(0.0, 1.0, 0.01) = 0.2;

void fragment() {
	float noise = texture(noise_texture, UV + (ward_seconds * noise_scroll)).r;
	
	float value = noise;
	value -= (1.0 - UV.y) * (1.0 + (1.0 - tail_length));
	value *= grow_amount;
	value = max(value, 0.0);
	value = smoothstep(0.0, 0.5, value);
	
	
	ALBEDO = mix(secondary_color, primary_color, value);
	
	float alpha = smoothstep(edge_hardness * edge_position, 1.01 - edge_hardness * (1.0 - edge_position), value);
	ALPHA = alpha;

ALBEDO*=0.42;
EMISSION*=0.42;
ALPHA*=ward_alpha;

   vec3 relative=cone_world-cone_origin;
   float along=dot(relative,cone_forward);
   float across=length(relative-cone_forward*along);
   float width=max(0.04,along*0.5);
   float end_cover=1.0-smoothstep(cone_length-0.22,cone_length,along);
   float side_cover=1.0-smoothstep(max(0.0,width-0.10),width,across);
   ALPHA*=smoothstep(-0.02,0.025,along)*end_cover*side_cover;
  }


void vertex(){
vec4 actual_cone_world4=MODEL_MATRIX*vec4(VERTEX,1.0);cone_world=actual_cone_world4.xyz;
}

