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
uniform float current_visibility = 1.0;
uniform bool use_instance_visibility = false;
varying float source_visibility;
#ifdef SOURCE_WATER
varying vec2 source_water_shift;
#endif
void vertex() {
    atlas_origin = use_instance_atlas ? INSTANCE_CUSTOM.gb : atlas_region.xy;
    source_visibility = use_instance_visibility ? INSTANCE_CUSTOM.r : current_visibility;
#ifdef SOURCE_WATER
    source_water_shift = water_source_shift(MODEL_MATRIX[3].xyz);
#endif
}
vec3 source_cap_space(vec3 encoded_colour) {
    if (!OUTPUT_IS_SRGB) {
        return mix(encoded_colour/12.92, pow((encoded_colour+0.055)/1.055,vec3(2.4)),step(vec3(0.04045),encoded_colour));
    }
    return encoded_colour;
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
    // Native Canvas has already accumulated all sources. For nonnegative
    // authored C<=1, min(saturate(C*L),C) == C*min(L,1). This caps total gain,
    // preserving dim light and source colour without another lighting pass.
#ifdef SOURCE_ENVIRONMENT
    vec3 bound = environment_source_colour(environment_source_sample(UV),source_visibility).rgb;
    colour.rgb = min(colour.rgb,source_cap_space(bound));
#endif
#ifdef SOURCE_MODULAR
    colour.rgb = min(colour.rgb,source_cap_space(modular_source_colour(UV).rgb));
#endif
#ifdef SOURCE_WATER
    vec3 bound = water_source_colour(UV,source_water_shift,SCREEN_UV,source_visibility).rgb;
    colour.rgb = min(colour.rgb,source_cap_space(bound));
#endif
    ALBEDO=colour.rgb;
    ALPHA=colour.a*wall_opacity;
}
