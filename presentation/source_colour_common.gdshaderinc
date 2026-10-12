// Authored encoded colour appearance; illumination never owns these values.
vec3 source_remembered_colour(vec3 colour, float visibility) {
    float grey = dot(colour, vec3(0.2126, 0.7152, 0.0722));
    return mix(mix(vec3(grey), colour, 0.35) * 0.62, colour, visibility);
}
