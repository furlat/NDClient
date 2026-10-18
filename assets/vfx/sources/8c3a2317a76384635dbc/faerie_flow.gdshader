shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, shadows_disabled;

// The two selected LeLu Wind Premium masks retain continuous panning and
// subtractive flow. Geometry/UVs are a new source-silhouette composition.
uniform sampler2D native_wind_mask : repeat_enable, filter_linear;
uniform sampler2D native_flow_mask : repeat_enable, filter_linear;
uniform vec4 deep_colour : source_color;
uniform vec4 flow_colour : source_color;
uniform vec4 crest_colour : source_color;
uniform float local_clock_seconds = 0.0;
uniform float presence_alpha = 1.0;
uniform float cue_opacity = 1.0;

void fragment() {
	float wind = texture(native_wind_mask, UV * vec2(.27, .41) + vec2(0., -local_clock_seconds * .42)).r;
	float counterflow = texture(native_flow_mask, UV * vec2(.5, .9) + vec2(0., local_clock_seconds * .50)).r;
	float energy = clamp(wind - counterflow * .35, 0., 1.);
	vec3 tint = mix(deep_colour.rgb, flow_colour.rgb, smoothstep(.12, .62, energy));
	tint = mix(tint, crest_colour.rgb, smoothstep(.62, .93, energy));
	ALBEDO = tint;
	EMISSION = tint * .18;
	float edge = pow(max(0., 1. - abs(UV.x * 2. - 1.)), .65);
	ALPHA = edge * (.48 + energy * .40) * presence_alpha * cue_opacity;
}
