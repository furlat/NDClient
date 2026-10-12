#include "source_colour_common.gdshaderinc"
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
