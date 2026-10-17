// The blood receiving page this replaces: an HDR canvas of white receivers lit
// by the frame's canvas lights over CanvasModulate 0.18, read per screen pixel.
#include "res://presentation/light_table.gdshaderinc"
uniform float blood_ambient = 0.18;
// A swatch shows its ambient only: it has no room lights.
uniform bool blood_room_lights = true;

float blood_half(float value) {
    return unpackHalf2x16(packHalf2x16(vec2(value, 0.0))).x;
}

vec3 blood_irradiance(vec2 screen_uv, vec2 viewport_size, vec3 n) {
    vec3 light = blood_room_lights ? table_light(floor(screen_uv * viewport_size) + 0.5, n, vec3(1.0), blood_ambient) : vec3(blood_ambient);
    return max(vec3(blood_half(light.r), blood_half(light.g), blood_half(light.b)), vec3(0.0));
}
