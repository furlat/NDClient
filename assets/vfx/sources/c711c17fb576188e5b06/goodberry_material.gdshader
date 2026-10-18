shader_type spatial;
render_mode unshaded, blend_mix, shadows_disabled;
uniform sampler2D native_noise : repeat_enable, filter_linear;
uniform vec4 berry_shadow : source_color;
uniform vec4 berry_skin : source_color;
uniform vec4 berry_crest : source_color;
uniform float local_clock_seconds = 0.;
uniform float presence = 1.;
uniform float cue_opacity = 1.;
void fragment() {
	float detail = texture(native_noise, UV * 3. + vec2(local_clock_seconds * .05, 0.)).r;
	float body = clamp(dot(NORMAL, normalize(vec3(.3, .65, .8))), 0., 1.);
	vec3 skin = mix(berry_shadow.rgb, berry_skin.rgb, body);
	skin = mix(skin, berry_crest.rgb, smoothstep(.72, 1., body) * .4);
	ALBEDO = skin * (.85 + detail * .15);
	EMISSION = skin * .10 * detail;
	ALPHA = presence * cue_opacity;
}
