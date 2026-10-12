shader_type canvas_item;
render_mode unshaded, blend_disabled;
// A numeric 2D target avoids the spatial renderer's colour/lighting conversion.
uniform sampler2D colour_texture : filter_nearest, repeat_disable;
uniform vec2 colour_size;
uniform vec4 colour_rect;
uniform bool use_selection = false;
uniform bool invert_selection = false;
uniform int selection_kind = 0;
uniform vec4 rgba_min;
uniform vec4 rgba_max;
uniform sampler2D selection_mask : filter_nearest, repeat_disable;
uniform vec4 selection_rect;
uniform vec2 selection_scale;
uniform vec2 selection_offset;
uniform vec4 selection_values;
uniform int wall_mask_id;

void fragment() {
    vec2 pixel = floor(UV * colour_size);
    vec4 colour = texture(colour_texture, (colour_rect.xy + UV * colour_rect.zw) / vec2(textureSize(colour_texture, 0)));
    // A translucent edge cannot erase an earlier sprite. It keeps source-over.
    if (colour.a < 0.999) { discard; }
    if (use_selection) {
        bool selected = false;
        if (selection_kind == 1) {
            vec4 value = round(colour * 255.0);
            selected = all(greaterThanEqual(value, rgba_min)) && all(lessThanEqual(value, rgba_max));
        } else {
            vec2 mp = floor(pixel * selection_scale + selection_offset);
            if (all(greaterThanEqual(mp, vec2(0.0))) && all(lessThan(mp, selection_rect.zw))) {
                float value = round(texelFetch(selection_mask, ivec2(selection_rect.xy + mp), 0).r * 255.0);
                selected = any(lessThan(abs(selection_values - vec4(value)), vec4(0.5)));
            }
        }
        if (selected == invert_selection) { discard; }
    }
    COLOR = vec4(vec3(float(wall_mask_id & 255), float((wall_mask_id >> 8) & 255), float((wall_mask_id >> 16) & 255)) / 255.0, 1.0);
}
