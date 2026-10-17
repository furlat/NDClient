shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled, depth_draw_never, depth_test_disabled;
// Workshop (main.gd) only: lit by ordinary 3D lights, as before the game moved
// to presentation/lit_receiving.gdshaderinc.
// Port of the connected branches in the existing water material graph.
uniform sampler2D mask_texture : filter_nearest, repeat_disable;
uniform sampler2D ripple_texture : filter_nearest, repeat_enable;
uniform vec2 origin;
uniform vec3 placement_origin;
uniform int camera_quarter;
uniform float displayed_time_seconds = 0.0;
uniform float current_visibility : hint_range(0.0, 1.0) = 1.0;
varying vec2 instance_shift;
varying vec3 instance_origin;
void vertex() {
    instance_origin = MODEL_MATRIX[3].xyz;
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
    colour = mix(mix(vec3(grey),colour,0.35)*0.62,colour,current_visibility);
    // The original graph's colours are encoded RGB, like its source artwork.
    if (!OUTPUT_IS_SRGB) { colour = mix(colour / 12.92, pow((colour + 0.055) / 1.055,vec3(2.4)),step(vec3(0.04045),colour)); }
    ALBEDO = colour;
    // Optical receiving follows the already disclosed horizontal support plane;
    // the camera-facing artwork and its authored mask do not move.
    vec3 point = (INV_VIEW_MATRIX * vec4(VERTEX,1.0)).xyz;
    vec3 ray = -INV_VIEW_MATRIX[2].xyz;
    if (abs(ray.y) > 0.00001) { point += ray * ((instance_origin.y-point.y)/ray.y); }
    LIGHT_VERTEX = (VIEW_MATRIX * vec4(point,1.0)).xyz;
    NORMAL = normalize(mat3(VIEW_MATRIX) * vec3(0.0,1.0,0.0));
    ROUGHNESS = 1.0;
    ALPHA = clamp(mask+(depth-0.5)*alpha_strength,0.0,1.0)*overall_alpha*tint.a;
}
