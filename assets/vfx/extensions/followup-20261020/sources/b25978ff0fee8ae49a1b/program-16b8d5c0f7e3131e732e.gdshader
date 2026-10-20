shader_type spatial;
uniform mat4 factory_world_to_source=mat4(1.0);
uniform float source_clock=0.0;
render_mode blend_mix,  cull_back, unshaded;

uniform float fresnelpower = 1.0;
uniform vec2 Details_scale = vec2(1.0, 1.0);
uniform vec2 Details_speed = vec2(0.0, 0.0);
uniform sampler2D DetailsTexture : source_color, hint_default_black, repeat_enable;
uniform sampler2D Color1DGradient : source_color, repeat_disable;
uniform float ColorIntensity = 1.0;



uniform mat4 cutplane;
uniform vec4 rim_color : source_color = vec4(1.0, 0.5, 0.2, 1.0);
uniform float rim_width = 0.05;
uniform float rim_intensity = 2.0;

varying vec3 wvtx;

void vertex() {
    wvtx = (factory_world_to_source * MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
}

void fragment() {
	
	vec3 planeNormal = normalize(cutplane[2].xyz);
	float planeDistance = dot(planeNormal, cutplane[3].xyz);
	float vertexDistance = dot(planeNormal, wvtx);
	float dist = (vertexDistance - planeDistance) / max(length(cutplane[2].xyz), 0.000001);
	
	if (dist < 0.0) {
		discard;
	}
	
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), fresnelpower);
	vec2 detail_uv = (UV * Details_scale) + (source_clock * Details_speed);
	float detail_noise = texture(DetailsTexture, detail_uv).r;
	float gradient_pos = fresnel + (detail_noise);
	
	vec3 base_color = texture(Color1DGradient, vec2(gradient_pos, 0.0)).rgb;
	
	float rim = smoothstep(0.0, rim_width, dist);
	float rim_strength = (1.0 - rim) * rim_intensity;
	
	ALBEDO = base_color * ColorIntensity - (rim_color.rgb * rim_strength * rim_color.a);
}


