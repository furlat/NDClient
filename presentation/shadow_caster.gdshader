shader_type spatial;
render_mode cull_disabled, unshaded;
// Only the native shadow pass draws this mesh. No invented back surface.
uniform sampler2D sheet : filter_nearest, repeat_disable;
uniform sampler2D component_depth : filter_nearest, repeat_disable;
uniform sampler2D component_support : filter_nearest, repeat_disable;
uniform vec4 frame_uv;
uniform vec2 component_depth_range;
uniform float component_units;
uniform vec2 component_reconstruction_origin;
uniform float component_elevation;
uniform mat3 display_basis;
uniform vec2 sprite_pivot;
uniform float ground_height;
uniform float height_scale = 0.5;
uniform float horizontal_scale = 1.0;

vec2 map_uv(vec2 pixel) {
    return frame_uv.xy + (clamp(pixel, vec2(0.0), vec2(127.0)) + 0.5) / 128.0 * frame_uv.zw;
}
vec2 depth_sample(vec2 pixel) {
    vec2 uv = map_uv(pixel);
    vec4 depth = textureLod(component_depth, uv, 0.0);
    float valid = float(textureLod(sheet, uv, 0.0).a > 0.5
        && textureLod(component_support, uv, 0.0).r > 0.5 && depth.a > 0.5);
    float d = component_depth_range.x + (depth.r * 255.0 - 32.0)
        * (component_depth_range.y - component_depth_range.x) / 192.0;
    return vec2(d * valid, valid);
}
void vertex() {
    vec2 pixel = UV * 128.0;
    // Interpolate only supported adjacent texels at each cell corner, so
    // transparent/background depth never pulls an edge into a spike.
    vec2 sum = depth_sample(pixel-vec2(1.0,1.0)) + depth_sample(pixel-vec2(0.0,1.0))
        + depth_sample(pixel-vec2(1.0,0.0)) + depth_sample(pixel);
    float d = sum.x / max(sum.y,1.0);
    float height = ((component_reconstruction_origin.y-pixel.y) * cos(component_elevation)
        + d * sin(component_elevation)) * component_units;
    // Compress height only. A global shrink would move each painted foot
    // toward one shared pivot and detach the rear leg from its ground contact.
    height = ground_height + (height-ground_height) * height_scale;
    vec3 painted = display_basis * vec3((pixel.x-sprite_pivot.x)*horizontal_scale, sprite_pivot.y-pixel.y,0.0) * component_units;
    // Preserve the original painted projection at the demo's 30-degree camera,
    // using the source's 45-degree optical height after vertical compression.
    // Explicit basis: INV_VIEW_MATRIX here would be the LIGHT camera.
    VERTEX = painted + display_basis[2] * ((height-painted.y) / display_basis[2].y);
}
void fragment() {
    vec2 uv = map_uv(floor(UV*128.0));
    if (texture(sheet,uv).a <= 0.5 || texture(component_support,uv).r <= 0.5
        || texture(component_depth,uv).a <= 0.5) { discard; }
    ALBEDO = vec3(0.0);
}
