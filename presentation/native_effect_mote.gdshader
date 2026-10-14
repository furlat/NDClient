shader_type spatial;
render_mode blend_mix, unshaded, depth_draw_opaque;
// Original ClassComponents StandardMaterial sphere colour; the only extra
// operation is the SAME authored rear/front half-plane, selected per camera.
uniform vec4 source_colour : source_color = vec4(0.88,0.88,0.88,1.0);
uniform vec2 camera_ground = vec2(1.0,1.0);
uniform vec3 source_origin = vec3(0.0);
varying vec3 world_p;
varying float requested_side;
void vertex() {
    world_p=MODEL_MATRIX[3].xyz; // Original source selects the whole mote by its centre.
    requested_side=(CAMERA_VISIBLE_LAYERS & (1u<<19u))!=0u ? 1.0 : ((CAMERA_VISIBLE_LAYERS & (1u<<18u))!=0u ? -1.0 : 0.0);
}
void fragment() {
    float depth=dot(world_p.xz-source_origin.xz,camera_ground);
    if((requested_side<-.5 && depth>=0.0) || (requested_side>.5 && depth<0.0)) discard;
    ALBEDO=source_colour.rgb;
    ALPHA=source_colour.a;
}
