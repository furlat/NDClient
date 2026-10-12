// Test-only original LDR path, frozen from local checkpoint542303f.
// Includes flattened so the new HDR implementation cannot become its own oracle.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never, depth_test_disabled;
uniform sampler2D received : source_color, filter_nearest, repeat_disable;
uniform vec4 atlas_region;
uniform vec4 source_crop = vec4(0.0,0.0,1.0,1.0);
uniform bool use_instance_atlas = false;
uniform vec2 atlas_cell_size;
uniform float wall_opacity = 1.0;
uniform bool wall_mask_enabled = false;
uniform int wall_mask_id = 0;
uniform sampler2D wall_mask_texture : filter_nearest, repeat_disable;
varying vec2 atlas_origin;
void vertex() {
    vec2 pixel = INSTANCE_CUSTOM.gb + vec2(mod(INSTANCE_CUSTOM.a,8.0),floor(INSTANCE_CUSTOM.a/8.0))*1024.0;
    atlas_origin = use_instance_atlas ? pixel/vec2(textureSize(received,0)) : atlas_region.xy;
}
// Godot4.7.2 Compatibility scene.glsl converts even unshaded ALBEDO with
// tonemap_inc.glsl's approximate cubic, then its power-based sRGB encode.
// Invert that engine transfer, not the native Canvas lighting: otherwise source
// codes1..7 become0. Four Newton steps invert the monotone cubic across RGBA8.
// https://github.com/godotengine/godot/blob/4.7.2-stable/drivers/gles3/shaders/tonemap_inc.glsl
vec3 canvas_encoded_for_spatial(vec3 encoded) {
    vec3 target = pow((encoded + vec3(0.055)) / 1.055, vec3(2.4));
    vec3 value = min(encoded + vec3(0.03), vec3(1.0));
    for (int i = 0; i < 4; i++) {
        vec3 cubic = value * (value * (value * 0.305306011 + 0.682171111) + 0.012522878);
        vec3 derivative = value * (value * 0.915918033 + 1.364342222) + 0.012522878;
        value -= (cubic - target) / derivative;
    }
    // Preserve true zero without adding a new ambient floor.
    return mix(value, vec3(0.0), equal(encoded, vec3(0.0)));
}
void fragment() {
    vec2 size = use_instance_atlas ? atlas_cell_size : atlas_region.zw;
    if (any(lessThan(UV,source_crop.xy)) || any(greaterThanEqual(UV,source_crop.xy+source_crop.zw))) discard;
    vec2 cell_uv = (UV-source_crop.xy)/source_crop.zw;
    vec4 colour = texture(received,atlas_origin+cell_uv*size);
    if (colour.a<=0.0 || wall_opacity<=0.0) discard;
    if (wall_mask_enabled && wall_opacity<1.0) {
        vec4 owner = texture(wall_mask_texture,SCREEN_UV);
        ivec3 bytes = ivec3(round(owner.rgb*255.0));
        int later = bytes.r+(bytes.g<<8)+(bytes.b<<16);
        if (owner.a>.5 && later>wall_mask_id) {
            ivec2 dimensions=textureSize(wall_mask_texture,0);
            ivec2 at=ivec2(SCREEN_UV*vec2(dimensions));
            bool covered=true;
            for(int y=-1;y<=1;y++) for(int x=-1;x<=1;x++) {
                vec4 value=texelFetch(wall_mask_texture,clamp(at+ivec2(x,y),ivec2(0),dimensions-1),0);
                ivec3 b=ivec3(round(value.rgb*255.0));
                if(value.a<=.5 || b.r+(b.g<<8)+(b.b<<16)<=wall_mask_id) covered=false;
            }
            if(covered) discard;
        }
    }
    // Native Canvas owns source tint, style, normals and light accumulation.
    // Preserve its bounded framebuffer result, like the supplied demo.
    ALBEDO=OUTPUT_IS_SRGB ? canvas_encoded_for_spatial(colour.rgb) : colour.rgb;
    ALPHA=colour.a*wall_opacity;
}

