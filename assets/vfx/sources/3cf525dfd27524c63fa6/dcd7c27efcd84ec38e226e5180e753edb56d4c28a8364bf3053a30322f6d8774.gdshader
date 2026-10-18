shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform sampler2D glow_tex : filter_linear;
uniform float strength = 0.0;
void fragment(){
 vec4 tex = texture(glow_tex,UV);
 float luminosity = max(tex.r,max(tex.g,tex.b));
 ALBEDO = vec3(.74 + luminosity*.16);
 ALPHA = luminosity*luminosity*tex.a*strength;
}
