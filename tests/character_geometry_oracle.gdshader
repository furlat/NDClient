shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled, depth_draw_never, depth_test_disabled;
// Native light accumulation; independently supplied decoded source receivers.
uniform bool per_pixel_reference = false;
uniform sampler2D reference_points : filter_nearest, repeat_disable;
uniform sampler2D reference_normals : filter_nearest, repeat_disable;
vec3 linear_colour(vec3 c) { return mix(c/12.92,pow((c+0.055)/1.055,vec3(2.4)),step(vec3(0.04045),c)); }
uniform sampler2D sheet : filter_nearest, repeat_disable;
uniform vec4 frame_uv;
uniform vec3 tint = vec3(1.0);
uniform vec3 expected_normal;
uniform vec3 expected_point;
varying vec3 origin;
void vertex() { origin = (MODEL_MATRIX*vec4(0.0,0.0,0.0,1.0)).xyz; }
void fragment() {
    vec4 colour = texture(sheet,frame_uv.xy+UV*frame_uv.zw);
    if (colour.a<=0.0) { discard; }
    colour.rgb *= tint;
    if (!OUTPUT_IS_SRGB) { colour.rgb = linear_colour(colour.rgb); }
    vec3 normal = expected_normal;
    vec3 point = origin+expected_point;
    if (per_pixel_reference) {
        ivec2 pixel = clamp(ivec2(UV*vec2(textureSize(reference_points,0))),ivec2(0),textureSize(reference_points,0)-ivec2(1));
        point = texelFetch(reference_points,pixel,0).rgb;
        normal = texelFetch(reference_normals,pixel,0).rgb;
    }
    NORMAL = mat3(VIEW_MATRIX)*normal;
    LIGHT_VERTEX = (VIEW_MATRIX*vec4(point,1.0)).xyz;
    ALBEDO = colour.rgb;
    EMISSION = vec3(0.0);
    ALPHA = colour.a;
    ROUGHNESS = 1.0;
}

void light() { DIFFUSE_LIGHT += max(dot(NORMAL,LIGHT),0.0)*ATTENUATION*LIGHT_COLOR/PI; }
