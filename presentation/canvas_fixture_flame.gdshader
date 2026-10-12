shader_type canvas_item;
render_mode unshaded;
// Authored flame pixels are emissive artwork; native scene lights illuminate
// receivers separately. This pass preserves the original source frame/alpha.
uniform sampler2DArray frames : filter_nearest, repeat_disable;
uniform int frame_index = 0;
void fragment() {
    vec4 colour = texture(frames,vec3(UV,float(frame_index)));
    if (colour.a <= 0.0) { discard; }
    COLOR = colour;
}
