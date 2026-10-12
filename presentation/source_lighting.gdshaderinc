// Original source receivers are supplied through NORMAL/LIGHT_VERTEX. Native
// Godot lights own culling, attenuation and accumulation before alpha blending.
uniform bool two_sided_receiver = false;
float receiving_diffuse(vec3 normal, vec3 to_light) {
    float cosine = dot(normal, to_light);
    return two_sided_receiver ? abs(cosine) : max(cosine, 0.0);
}
