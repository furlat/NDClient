// table_light for a canvas receiver with a linear texture filter: Godot reads
// the light atlas with the receiver's own sampler, so the cookie is filtered.
// A native receiving page with a CanvasTexture specular map adds no specular
// term (tests/light_table_checks.gd proves it byte for byte), so none is here.
#include "res://presentation/light_table.gdshaderinc"

vec3 table_light_linear(vec2 p, vec3 n, vec3 base, float ambient) {
    vec3 colour = base * ambient;
    for (int i = 0; i < light_count; i++) {
        vec4 table_colour = texelFetch(light_table, ivec2(3, i), 0);
        if (table_colour.a > 0.5) {
            vec4 direction = texelFetch(light_table, ivec2(0, i), 0);
            vec3 light_vec = normalize(mix(vec3(direction.xy, 0.0), vec3(0.0, 0.0, 1.0), direction.z));
            colour += table_colour.rgb * base * max(0.0, dot(n, light_vec)) * direction.w;
            continue;
        }
        vec4 table_m = texelFetch(light_table, ivec2(1, i), 0);
        vec4 table_k = texelFetch(light_table, ivec2(2, i), 0);
        vec2 table_uv = (vec4(p, 0.0, 1.0) * mat4(vec4(table_m.x, table_m.y, 0.0, table_m.z), vec4(table_m.w, table_k.x, 0.0, table_k.y), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0))).xy;
        if (any(lessThan(table_uv, vec2(0.0))) || any(greaterThanEqual(table_uv, vec2(1.0)))) continue;
        vec4 table_at = texelFetch(light_table, ivec2(0, i), 0);
        vec4 table_cookie = textureLod(light_cookies, vec3(table_uv, table_k.z), 0.0);
        table_cookie.rgb *= table_colour.rgb * table_at.w;
        float lambert = max(0.0, dot(n, normalize(table_at.xyz - vec3(p, 0.0))));
        table_cookie.rgb = table_cookie.rgb * base * lambert;
        colour += table_cookie.rgb * table_cookie.a;
    }
    return colour;
}
