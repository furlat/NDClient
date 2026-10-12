// Test-only original LDR path, frozen from local checkpoint542303f.
// Includes flattened so the new HDR implementation cannot become its own oracle.
shader_type canvas_item;
render_mode skip_vertex_transform, blend_disabled;
// A 1px-white Sprite2D's native region UV carries atlas storage pixels. Its local
// rectangle and MODEL_MATRIX still describe the actual cropped receiver, keeping
// native light culling correct without per-item uniform storage. source_crop is
// normalized within the ORIGINAL full cell; no source pixels are resampled.
uniform vec2 atlas_cell_size = vec2(1.0);
uniform float receiver_visibility = 1.0;
uniform vec3 receiver_world_origin = vec3(0.0);
uniform vec4 source_crop = vec4(0.0, 0.0, 1.0, 1.0);
varying vec2 atlas_receiving_pixel;
varying vec4 atlas_inverse_normal_basis;

vec4 atlas_normal_inverse(mat4 model) {
    // Godot applies normalized MODEL_MATRIX axes to NORMAL after fragment().
    // Cancel that transport: source decoding already produced Canvas normals.
    mat2 basis = mat2(normalize(model[0].xy), normalize(model[1].xy));
    mat2 inverse_basis = inverse(basis);
    return vec4(inverse_basis[0], inverse_basis[1]);
}

vec3 atlas_canvas_normal(vec3 normal) {
    return vec3(mat2(atlas_inverse_normal_basis.xy, atlas_inverse_normal_basis.zw) * normal.xy, normal.z);
}

uniform vec2 actual_scene_viewport_size = vec2(1.0);
// Existing authored water graph, received by native Canvas lights.
// Port of the connected branches in the existing water material graph.
// Authored encoded colour appearance; illumination never owns these values.
vec3 source_remembered_colour(vec3 colour, float visibility) {
    float grey = dot(colour, vec3(0.2126, 0.7152, 0.0722));
    return mix(mix(vec3(grey), colour, 0.35) * 0.62, colour, visibility);
}

uniform sampler2D mask_texture : filter_nearest, repeat_disable;
uniform sampler2D ripple_texture : filter_nearest, repeat_enable;
uniform vec2 origin;
uniform vec3 placement_origin;
uniform int camera_quarter;
uniform float displayed_time_seconds = 0.0;
uniform vec2 cell;
uniform float image_scale;
uniform vec4 shallow_color;
uniform vec4 deep_color;
uniform vec4 tint;
uniform float uv_scale;
uniform float depth_strength;
uniform vec2 ripple_pan;
uniform float ripple_tiling;
uniform float ripple_amount;
uniform float sheen_strength;
uniform float sheen_sharpness;
uniform float alpha_strength;
uniform float overall_alpha;
uniform float alpha_cutoff;
vec2 water_source_shift(vec3 world_origin) {
    vec3 delta = world_origin-placement_origin;
    vec2 grid=delta.xz;
    for (int q=0;q<camera_quarter;q++) { grid=vec2(-grid.y,grid.x); }
    return vec2(64.0*(grid.x-grid.y),32.0*(grid.x+grid.y)-64.0*delta.y/sqrt(2.0/3.0));
}
vec4 water_source_colour(vec2 uv, vec2 instance_shift, vec2 screen_uv, float visibility) {
    float mask = texture(mask_texture,uv).a;
    if (mask < alpha_cutoff) { return vec4(0.0); }
    vec2 world = (origin + instance_shift + floor(uv*cell)*image_scale)/128.0;
    world.y = -world.y;
    float ripple = texture(ripple_texture,world*uv_scale*ripple_tiling + ripple_pan*displayed_time_seconds).r;
    float depth = clamp(world.y*0.125*depth_strength+0.5,0.0,1.0);
    vec3 colour = mix(shallow_color.rgb,deep_color.rgb,depth)+(ripple-0.5)*ripple_amount;
    vec2 edge = abs(screen_uv-0.5)*2.0;
    colour += pow(clamp(max(edge.x,edge.y),0.0,1.0),sheen_sharpness)*sheen_strength;
    colour = clamp(colour,vec3(0.0),vec3(1.0))*tint.rgb;
    colour = source_remembered_colour(colour, visibility);
    return vec4(colour,clamp(mask+(depth-0.5)*alpha_strength,0.0,1.0)*overall_alpha*tint.a);
}

uniform float current_visibility : hint_range(0.0, 1.0) = 1.0;
uniform bool use_instance_visibility = false;
uniform vec3 canvas_instance_origin;
uniform mat3 world_to_canvas;
uniform float canvas_pixels_per_unit = 90.509667991878;
varying float scenery_visibility;
varying vec2 instance_shift;
varying vec3 instance_origin;
void vertex() {
    atlas_receiving_pixel = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
    atlas_inverse_normal_basis = atlas_normal_inverse(MODEL_MATRIX);
    vec2 local_uv = VERTEX / atlas_cell_size;
    VERTEX = UV;
    UV = source_crop.xy + local_uv * source_crop.zw;
    COLOR = vec4(1.0);
    instance_origin = receiver_world_origin;
    scenery_visibility = receiver_visibility;
    instance_shift = water_source_shift(instance_origin);
}
void fragment() {
    VERTEX = atlas_receiving_pixel;
    LIGHT_VERTEX = vec3(atlas_receiving_pixel, 0.0);
    vec4 colour = water_source_colour(UV, instance_shift, atlas_receiving_pixel / actual_scene_viewport_size, scenery_visibility);
    if (colour.a <= 0.0) { discard; }
    NORMAL = atlas_canvas_normal(normalize(world_to_canvas * vec3(0.0,1.0,0.0)));
#ifdef SHOW_SOURCE_NORMALS
    COLOR = vec4(normalize(world_to_canvas*vec3(0.0,1.0,0.0))*0.5+0.5,colour.a);
#else
    COLOR = colour;
#endif
}
