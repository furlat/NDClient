shader_type spatial;
render_mode cull_disabled, ambient_light_disabled, specular_disabled, fog_disabled;
// This isolated viewport measures a single native shadow. It never receives
// production painted-world illumination, nor substitutes a ground colour.
uniform vec3 helper_position;
uniform float helper_range;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() { ALBEDO=vec3(1.0); ROUGHNESS=1.0; }
void light() {
    float distance_to_light=length(helper_position-world_position);
    float normalized_distance=distance_to_light/max(helper_range,0.0001);
    float falloff=max(1.0-pow(normalized_distance,4.0),0.0);
    falloff=falloff*falloff/max(distance_to_light,0.0001);
    float visibility=falloff>0.000001 ? clamp(ATTENUATION/falloff,0.0,1.0) : 1.0;
    // Compatibility encodes the custom light pass. Invert that transfer so
    // the render target contains numeric visibility, not encoded light energy.
    DIFFUSE_LIGHT=vec3(OUTPUT_IS_SRGB ? pow((visibility+0.055)/1.055,2.4) : visibility);
}
