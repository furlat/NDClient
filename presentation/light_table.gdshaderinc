// Native PointLight2D receiving (Godot 4.7.2 canvas.glsl, lights without
// shadows or light() code), for one painted-plane point p in viewport pixels at
// height 0 with canvas normal n (x right, y down, z toward the camera). Rows
// come from presentation/light_table.gd; the operation order follows canvas.glsl.
// Receivers read the cookie with their own NEAREST sampler; outside [0,1) is unlit.
global uniform sampler2D light_table;
global uniform int light_count;
global uniform sampler2DArray light_cookies;

// base is the receiver colour (white when storing irradiance), ambient the
// CanvasModulate value as the canvas shader sees it.
vec3 table_light(vec2 p, vec3 n, vec3 base, float ambient) {
    vec3 colour = base * ambient;
    ivec2 cookie_size = textureSize(light_cookies, 0).xy;
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
        vec4 table_cookie = texelFetch(light_cookies, ivec3(ivec2(table_uv * vec2(cookie_size)), int(table_k.z)), 0);
        table_cookie.rgb *= table_colour.rgb * table_at.w;
        float lambert = max(0.0, dot(n, normalize(table_at.xyz - vec3(p, 0.0))));
        table_cookie.rgb = table_cookie.rgb * base * lambert;
        colour += table_cookie.rgb * table_cookie.a;
    }
    return colour;
}
