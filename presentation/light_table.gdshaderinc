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
        vec4 m = texelFetch(light_table, ivec2(1, i), 0);
        vec4 k = texelFetch(light_table, ivec2(2, i), 0);
        vec2 uv = (vec4(p, 0.0, 1.0) * mat4(vec4(m.x, m.y, 0.0, m.z), vec4(m.w, k.x, 0.0, k.y), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0))).xy;
        if (any(lessThan(uv, vec2(0.0))) || any(greaterThanEqual(uv, vec2(1.0)))) continue;
        vec4 at = texelFetch(light_table, ivec2(0, i), 0);
        vec4 tint = texelFetch(light_table, ivec2(3, i), 0);
        vec4 light = texelFetch(light_cookies, ivec3(ivec2(uv * vec2(cookie_size)), int(k.z)), 0);
        light.rgb *= tint.rgb * at.w;
        float lambert = max(0.0, dot(n, normalize(at.xyz - vec3(p, 0.0))));
        light.rgb = light.rgb * base * lambert;
        colour += light.rgb * light.a;
    }
    return colour;
}
