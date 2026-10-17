// The light atlas's receiving and storage, evaluated in the sprite's own pass.
// A source texel is lit once, at its screen centre on the painted plane, by the
// light table; the result then takes the atlas storage (RGBA16F with the light
// cap, RGBA8 without) and the former output shader's decode and transfer.
#include "light_table.gdshaderinc"
// CanvasModulate as the receiving canvas saw it: 0.30, converted under HDR.
global uniform float light_ambient;
// 0: LDR storage, per-channel clamp. Otherwise the brightest-channel cap.
global uniform float light_cap;
// Normals view: receiving normals, unshaded, LDR; shadow and flame roles omitted.
global uniform bool light_normals;
uniform vec2 source_quad_size = vec2(1.0);
uniform float wall_opacity : hint_range(0.0, 1.0) = 1.0;
uniform bool wall_mask_enabled = false;
uniform int wall_mask_id = 0;
uniform sampler2D wall_mask_texture : filter_nearest, repeat_disable;
varying vec2 source_screen_origin;
varying vec2 source_screen_axis_x;
varying vec2 source_screen_axis_y;

vec2 lit_projected_uv(mat4 projection, vec3 at) {
    vec4 projected = projection * vec4(at, 1.0);
    return projected.xy / projected.w * 0.5 + 0.5;
}

// Screen placement of the quad's UV square, for texel-centre positions:
// columns are the screen origin and the two axes, in screen UV.
mat3 lit_screen_quad(vec3 vertex, vec2 uv, mat4 modelview_projection) {
    vec3 top_left = vertex - vec3(uv.x * source_quad_size.x, -uv.y * source_quad_size.y, 0.0);
    vec2 screen_origin = lit_projected_uv(modelview_projection, top_left);
    vec2 axis_x = lit_projected_uv(modelview_projection, top_left + vec3(source_quad_size.x, 0.0, 0.0)) - screen_origin;
    vec2 axis_y = lit_projected_uv(modelview_projection, top_left - vec3(0.0, source_quad_size.y, 0.0)) - screen_origin;
    return mat3(vec3(screen_origin, 0.0), vec3(axis_x, 0.0), vec3(axis_y, 0.0));
}

vec2 lit_texel_uv(vec2 uv, vec2 texels) {
    return (floor(uv * texels) + 0.5) / texels;
}

vec2 lit_screen_uv(vec2 texel_uv) {
    return source_screen_origin + texel_uv.x * source_screen_axis_x + texel_uv.y * source_screen_axis_y;
}

// Rows are world right, screen-down, toward-camera.
mat3 lit_world_to_canvas(mat4 inverse_view) {
    return transpose(mat3(inverse_view[0].xyz, -inverse_view[1].xyz, inverse_view[2].xyz));
}

bool lit_hdr() {
    return light_cap > 0.0 && !light_normals;
}

float lit_half(float value) {
    return unpackHalf2x16(packHalf2x16(vec2(value, 0.0))).x;
}

vec3 lit_half3(vec3 value) {
    return vec3(lit_half(value.r), lit_half(value.g), lit_half(value.b));
}

vec3 lit_byte3(vec3 value) {
    return unpackUnorm4x8(packUnorm4x8(vec4(value, 1.0))).rgb;
}

float lit_stored_alpha(float alpha) {
    return lit_hdr() ? lit_half(alpha) : unpackUnorm4x8(packUnorm4x8(vec4(alpha))).a;
}

vec3 lit_encoded_to_linear(vec3 value) {
    return mix(pow((value + vec3(0.055)) / 1.055, vec3(2.4)), value / 12.92, lessThanEqual(value, vec3(0.04045)));
}

// A colour the atlas stored without lighting (shadow role, flames, Normals).
vec3 lit_unlit(vec3 encoded) {
    return lit_encoded_to_linear(lit_byte3(lit_hdr() ? lit_half3(encoded) : encoded));
}

// Atlas receiving at one texel: p in viewport pixels, n the canvas normal,
// source the encoded receiver colour. Returns linear colour.
global uniform int light_debug;
vec3 lit_received(vec3 source, vec2 p, vec3 n) {
    if (lit_hdr()) {
        vec3 irradiance = max(lit_half3(table_light(p, n, vec3(1.0), light_ambient)), vec3(0.0));
        if (light_debug == 1) return fract(irradiance * 16.0);
        if (light_debug == 2) return source;
        float peak = max(irradiance.r, max(irradiance.g, irradiance.b));
        float gain = peak > light_cap ? light_cap / peak : 1.0;
        vec3 encoded = clamp(source * irradiance * gain, vec3(0.0), vec3(1.0));
        return lit_encoded_to_linear(lit_byte3(encoded));
    }
    return lit_encoded_to_linear(lit_byte3(table_light(p, n, source, light_ambient)));
}

// Godot 4.7.2 Compatibility scene.glsl converts even unshaded ALBEDO with
// tonemap_inc.glsl's approximate cubic, then its power-based sRGB encode.
// Invert that engine transfer. Four Newton steps invert the monotone cubic.
// https://github.com/godotengine/godot/blob/4.7.2-stable/drivers/gles3/shaders/tonemap_inc.glsl
vec3 lit_encoded_for_spatial(vec3 encoded) {
    vec3 target = pow((encoded + vec3(0.055)) / 1.055, vec3(2.4));
    vec3 value = min(encoded + vec3(0.03), vec3(1.0));
    for (int i = 0; i < 4; i++) {
        vec3 cubic = value * (value * (value * 0.305306011 + 0.682171111) + 0.012522878);
        vec3 derivative = value * (value * 0.915918033 + 1.364342222) + 0.012522878;
        value -= (cubic - target) / derivative;
    }
    return mix(value, vec3(0.0), equal(encoded, vec3(0.0)));
}

vec3 lit_albedo(vec3 colour, bool output_is_srgb) {
    return output_is_srgb ? lit_encoded_for_spatial(colour) : colour;
}

// Only the front-most faded wall shows: erase where a later faded wall's mask
// surrounds this pixel; keep the boundary to avoid holes.
bool lit_wall_masked(vec2 screen_uv) {
    if (!wall_mask_enabled || wall_opacity >= 1.0) return false;
    vec4 owner = texture(wall_mask_texture, screen_uv);
    ivec3 bytes = ivec3(round(owner.rgb * 255.0));
    int later = bytes.r + (bytes.g << 8) + (bytes.b << 16);
    if (owner.a <= 0.5 || later <= wall_mask_id) return false;
    ivec2 dimensions = textureSize(wall_mask_texture, 0);
    ivec2 at = ivec2(screen_uv * vec2(dimensions));
    for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
        vec4 value = texelFetch(wall_mask_texture, clamp(at + ivec2(x, y), ivec2(0), dimensions - 1), 0);
        ivec3 b = ivec3(round(value.rgb * 255.0));
        if (value.a <= 0.5 || b.r + (b.g << 8) + (b.b << 16) <= wall_mask_id) return false;
    }
    return true;
}
