uniform sampler2D received : source_color, filter_nearest, repeat_disable;
// Float atlas values have no sRGB texture format: these are encoded numeric
// data, or white native irradiance for the capped receiving families.
uniform bool received_is_encoded_hdr = false;
uniform float light_cap = 0.0;
uniform vec2 source_quad_size = vec2(1.0);
global uniform int light_debug;
uniform float current_visibility = 1.0;
uniform bool use_instance_visibility = false;
#include "native_body_material.gdshaderinc"
#include "body_surface.gdshaderinc"
varying float source_visibility;
varying vec3 source_world_origin;
varying vec2 source_screen_origin;
varying vec2 source_screen_axis_x;
varying vec2 source_screen_axis_y;
#include "native_scene_vertex.gdshaderinc"
#include "source_atlas_uv.gdshaderinc"
vec2 source_projected_uv(mat4 projection, vec3 at) {
    vec4 projected = projection * vec4(at,1.0);
    return projected.xy/projected.w*0.5+0.5;
}
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
    source_visibility = use_instance_visibility ? INSTANCE_CUSTOM.r : current_visibility;
    source_world_origin = MODEL_MATRIX[3].xyz;
    native_scene_model_basis = mat3(MODEL_MATRIX);
    vec3 top_left = VERTEX - vec3(UV.x*source_quad_size.x,-UV.y*source_quad_size.y,0.0);
    source_screen_origin = source_projected_uv(PROJECTION_MATRIX * MODELVIEW_MATRIX,top_left);
    source_screen_axis_x = source_projected_uv(PROJECTION_MATRIX * MODELVIEW_MATRIX,top_left+vec3(source_quad_size.x,0.0,0.0))-source_screen_origin;
    source_screen_axis_y = source_projected_uv(PROJECTION_MATRIX * MODELVIEW_MATRIX,top_left-vec3(0.0,source_quad_size.y,0.0))-source_screen_origin;
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
vec3 received_encoded_to_linear(vec3 value) {
    return mix(pow((value+vec3(0.055))/1.055,vec3(2.4)),value/12.92,lessThanEqual(value,vec3(0.04045)));
}
#ifdef CAPPED_RECEIVING
vec3 received_source_colour(vec2 uv,vec2 screen_uv) {
#ifdef CAPPED_ENVIRONMENT
    return environment_source_colour(environment_source_sample(uv),source_visibility).rgb;
#endif
#ifdef CAPPED_MODULAR
    return modular_source_colour(uv).rgb;
#endif
#ifdef CAPPED_WATER
    return water_source_colour(uv,water_source_shift(source_world_origin),screen_uv,source_visibility).rgb;
#endif
}
#endif
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
    // Address the SAME nearest atlas texel for colour reconstruction. Raw UV
    // can select an adjacent original texel at fractional zoom/crop boundaries.
    vec2 dimensions = vec2(textureSize(received,0));
    vec2 selected_uv = source_atlas_uv(cell_uv,atlas_origin,size,dimensions,source_crop);
    vec3 debug_albedo = vec3(-1.0);
#ifdef CAPPED_RECEIVING
    vec2 selected_screen = source_screen_origin+selected_uv.x*source_screen_axis_x+selected_uv.y*source_screen_axis_y;
    vec3 irradiance = max(colour.rgb,vec3(0.0));
    if (light_debug == 1) debug_albedo = fract(irradiance * 16.0);
    if (light_debug == 2) debug_albedo = received_source_colour(selected_uv,selected_screen);
    float peak = max(irradiance.r,max(irradiance.g,irradiance.b));
    float gain = light_cap>0.0 && peak>light_cap ? light_cap/peak : 1.0;
    vec3 encoded = clamp(received_source_colour(selected_uv,selected_screen)*irradiance*gain,vec3(0.0),vec3(1.0));
    colour.rgb = received_encoded_to_linear(unpackUnorm4x8(packUnorm4x8(vec4(encoded,1.0))).rgb);
#else
    // Emissive/source-shadow/Normals pixels bypass the accumulated-light cap.
    // Match their former LDR storage quantization before the existing 3D blend.
    if (received_is_encoded_hdr) {
        colour.rgb = unpackUnorm4x8(packUnorm4x8(vec4(colour.rgb,1.0))).rgb;
        colour.rgb = received_encoded_to_linear(colour.rgb);
    }
#endif
    // Off retains the original native LDR texture/3D transfer path.
    if (body_surface_enabled && body_surface_count>0 && has_component_geometry) {
        vec3 surface_point;
        vec2 normal_uv=frame_uv.xy+selected_uv*frame_uv.zw;
        vec4 packet_normal=texture(component_normal,normal_uv);
        if (packet_normal.a>.5 && texture(component_normal_valid,normal_uv).r>.5
            && native_scene_receiver(selected_uv,VERTEX,VIEW_MATRIX,INV_VIEW_MATRIX,source_world_origin,surface_point)) {
            vec3 n=packet_normal.rgb*2.0-1.0;
            n=normalize(vec3(n.x/(abs(component_scale_x)>.00001?component_scale_x:1.0),n.y,n.z));
            vec3 horizontal=normalize(vec3(INV_VIEW_MATRIX[2].x,0.0,INV_VIEW_MATRIX[2].z));
            vec3 up=vec3(0.0,cos(component_elevation),0.0)-horizontal*sin(component_elevation);
            vec3 toward=horizontal*cos(component_elevation)+vec3(0.0,sin(component_elevation),0.0);
            vec3 normal_world=normalize(mat3(INV_VIEW_MATRIX[0].xyz,up,toward)*n);
            vec3 relative=(INV_VIEW_MATRIX*vec4(surface_point,1.0)).xyz-source_world_origin;
            colour.rgb=apply_body_surface(colour.rgb,relative,normal_world,normalize(mat3(VIEW_MATRIX)*normal_world));
        }
    }
    colour.rgb=native_body_colour(colour.rgb,selected_uv);
    ALBEDO=OUTPUT_IS_SRGB ? canvas_encoded_for_spatial(colour.rgb) : colour.rgb;
    if (debug_albedo.r >= 0.0) ALBEDO = debug_albedo;
    ALPHA=colour.a*wall_opacity;
    if (native_scene_enabled) {
        vec3 receiver;
        if (native_scene_receiver(selected_uv, VERTEX, VIEW_MATRIX, INV_VIEW_MATRIX, source_world_origin, receiver)) {
            LIGHT_VERTEX = receiver;
        }
    }
}
