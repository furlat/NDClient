shader_type canvas_item;
// Existing authored water graph, received by native Canvas lights.
// Port of the connected branches in the existing water material graph.
uniform sampler2D mask_texture : filter_nearest, repeat_disable;
uniform sampler2D ripple_texture : filter_nearest, repeat_enable;
uniform vec2 origin;
uniform vec3 placement_origin;
uniform int camera_quarter;
uniform float displayed_time_seconds = 0.0;
uniform float current_visibility : hint_range(0.0, 1.0) = 1.0;
uniform bool use_instance_visibility = false;
uniform vec3 canvas_instance_origin;
uniform mat3 world_to_canvas;
uniform float canvas_pixels_per_unit = 90.509667991878;
varying float scenery_visibility;
varying vec2 instance_shift;
varying vec3 instance_origin;
void vertex() {
    instance_origin = use_instance_visibility ? INSTANCE_CUSTOM.gba : canvas_instance_origin;
    scenery_visibility = use_instance_visibility ? INSTANCE_CUSTOM.r : current_visibility;
    vec3 delta = instance_origin-placement_origin;
    vec2 grid=delta.xz;
    for (int q=0;q<camera_quarter;q++) { grid=vec2(-grid.y,grid.x); }
    instance_shift=vec2(64.0*(grid.x-grid.y),32.0*(grid.x+grid.y)-64.0*delta.y/sqrt(2.0/3.0));
}
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
void fragment() {
    float mask = texture(mask_texture,UV).a;
    if (mask < alpha_cutoff) discard;
    vec2 world = (origin + instance_shift + floor(UV*cell)*image_scale)/128.0;
    world.y = -world.y;
    float ripple = texture(ripple_texture,world*uv_scale*ripple_tiling + ripple_pan*displayed_time_seconds).r;
    float depth = clamp(world.y*0.125*depth_strength+0.5,0.0,1.0);
    vec3 colour = mix(shallow_color.rgb,deep_color.rgb,depth)+(ripple-0.5)*ripple_amount;
    vec2 edge = abs(SCREEN_UV-0.5)*2.0;
    colour += pow(clamp(max(edge.x,edge.y),0.0,1.0),sheen_sharpness)*sheen_strength;
    colour = clamp(colour,vec3(0.0),vec3(1.0))*tint.rgb;
    float grey = dot(colour,vec3(0.2126,0.7152,0.0722));
    colour = mix(mix(vec3(grey),colour,0.35)*0.62,colour,scenery_visibility);
    // Colours stay encoded exactly as in the source graph; CanvasModulate and
    // native Canvas lights own illumination. The painted receiving plane stays
    // at LIGHT_VERTEX.z=0, which is screen-normal height rather than world Y.
    NORMAL = normalize(world_to_canvas * vec3(0.0,1.0,0.0));
    COLOR = vec4(colour,clamp(mask+(depth-0.5)*alpha_strength,0.0,1.0)*overall_alpha*tint.a);
}
