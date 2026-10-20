shader_type spatial;
// Shared numerical contract: encoded sRGB -> D65 CIELAB, CIE76 distance.
// Constants and branch boundaries preserve the selected CodexFX profile.
// Alpha, RGB snapping, ramps and energy keys belong to the caller.
float cie_linear_channel(float channel) {
	return channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4);
}
float cie_encoded_channel(float channel) {
	return channel <= 0.0031308 ? channel * 12.92 : 1.055 * pow(max(channel, 0.0), 1.0 / 2.4) - 0.055;
}
float cie_lab_curve(float value) {
	return value > 0.00885645167 ? pow(value, 1.0 / 3.0) : 7.78703703704 * value + 16.0 / 116.0;
}
vec3 cie_lab(vec3 encoded_rgb) {
	vec3 linear_rgb = vec3(cie_linear_channel(encoded_rgb.r), cie_linear_channel(encoded_rgb.g), cie_linear_channel(encoded_rgb.b));
	float x = linear_rgb.r * 0.4124564 + linear_rgb.g * 0.3575761 + linear_rgb.b * 0.1804375;
	float y = linear_rgb.r * 0.2126729 + linear_rgb.g * 0.7151522 + linear_rgb.b * 0.0721750;
	float z = linear_rgb.r * 0.0193339 + linear_rgb.g * 0.1191920 + linear_rgb.b * 0.9503041;
	float fx = cie_lab_curve(x / 0.95047);
	float fy = cie_lab_curve(y);
	float fz = cie_lab_curve(z / 1.08883);
	return vec3(116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz));
}
vec3 cie_nearest(vec3 encoded_rgb, sampler2D palette_texture, int count, float energy_floor, float luma_floor) {
	vec3 subject_lab = cie_lab(encoded_rgb);
	float best_distance = 999999.0;
	vec3 best_rgb = encoded_rgb;
	for (int index = 0; index < 64; index++) {
		if (index >= count) { break; }
		vec3 candidate = texture(palette_texture, vec2((float(index) + 0.5) / float(count), 0.5)).rgb;
		if (max(max(candidate.r, candidate.g), candidate.b) < energy_floor || dot(candidate, vec3(0.2126, 0.7152, 0.0722)) < luma_floor) { continue; }
		float candidate_distance = distance(subject_lab, cie_lab(candidate));
		// Strict less-than deliberately keeps the first palette entry on ties.
		if (candidate_distance < best_distance) {
			best_distance = candidate_distance;
			best_rgb = candidate;
		}
	}
	return best_rgb;
}


uniform sampler2D native_palette_texture:filter_nearest,repeat_disable;
uniform int native_palette_count=1;
uniform bool native_palette_quantize=true;
uniform float native_emission_gain=0.0;
uniform float native_palette_exposure=1.0;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float contact_seconds = 0.0;
uniform float contact_delay = 0.0;
uniform float contact_span = 0.30;
uniform float contact_alpha = 1.0;
uniform float contact_variant = 0.0;
uniform vec2 contact_extent_cells = vec2(.4, .4);
uniform vec2 contact_offset_cells = vec2(0.0);
uniform vec2 contact_drift_cells = vec2(0.0);
uniform float contact_angle = 0.0;
uniform float contact_expansion = .15;

float contact_progress() {
	return clamp((contact_seconds - contact_delay) / max(contact_span, .001), 0.0, 1.0);
}

float contact_envelope() {
	float age = contact_seconds - contact_delay;
	float progress = contact_progress();
	return step(0.0, age) * (1.0 - step(contact_span, age))
		* smoothstep(0.0, .07, progress) * (1.0 - smoothstep(.42, 1.0, progress)) * contact_alpha;
}

vec3 contact_vertex(vec3 original) {
	float progress = contact_progress();
	float angle = contact_angle + (contact_variant - .5) * .32;
	vec2 local = original.xy * contact_extent_cells * mix(1.0 - contact_expansion, 1.0 + contact_expansion, progress);
	local = mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle))) * local;
	local += contact_offset_cells + contact_drift_cells * progress;
	return vec3(local, original.z);
}

mat4 contact_billboard(mat4 model, mat4 view, mat4 inverse_view) {
	// Native camera-facing contact card, scaled by the supplied root. This
	// creates no camera, inferred hit point or source/target movement history.
	return view * mat4(
		inverse_view[0] * vec4(vec3(length(model[0].xyz)), 1.0),
		inverse_view[1] * vec4(vec3(length(model[1].xyz)), 1.0),
		inverse_view[2] * vec4(vec3(length(model[2].xyz)), 1.0), model[3]);
}


// LeLu Stylized Fire: the actual tapered T_FireF_1 red channel supplies
// tongues. Its PNG alpha is opaque everywhere; never use it as coverage.
// One finite source clock advects that mask toward the top, with restrained
// owned-pack Perlin breakup. No source particle, full-body cloud or lamp.
uniform sampler2D contact_flame : filter_linear, repeat_disable;
uniform sampler2D contact_detail : filter_linear, repeat_enable;
uniform vec3 primary_color : source_color = vec3(1.0, .60, .10);
uniform vec3 secondary_color : source_color = vec3(.33, .03, .006);
// Bound once from the exact selected recipient optical point. Zero means
// missing geometry: keep the raw card, explicitly unqualified by the host.
uniform vec3 contact_surface_normal_world = vec3(0.0);

void vertex() {
	VERTEX = contact_vertex(VERTEX);
	MODELVIEW_MATRIX = contact_billboard(MODEL_MATRIX, VIEW_MATRIX, INV_VIEW_MATRIX);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	if (dot(contact_surface_normal_world, contact_surface_normal_world) > .000001) {
		// Billboard vertices are in view-oriented local coordinates, whereas
		// the actual optical normal is world-space. Convert through VIEW,
		// then remove the exact per-axis model scales carried by the billboard.
		vec3 view_normal = (VIEW_MATRIX * vec4(normalize(contact_surface_normal_world), 0.0)).xyz;
		vec3 model_scale = max(vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz),
			length(MODEL_MATRIX[2].xyz)), vec3(.000001));
		float progress = contact_progress();
		float tip_weight = pow(clamp(1.0 - UV.y, 0.0, 1.0), .75);
		float impulse = .68 + .32 * smoothstep(0.0, .40, progress);
		float curl = .5 + .5 * sin(UV.x * 6.2831853 + progress * 3.0 + contact_variant * 3.14159265);
		// A small finite outward flame impulse, not a translated contact:
		// the base stays at .015, while the furthest tip can reach .18 cells.
		float lift_cells = .015 + .165 * tip_weight * impulse * (.90 + .10 * curl);
		VERTEX += (view_normal / model_scale) * lift_cells;
	}
}

void fragment() {
	float progress = contact_progress();
	vec2 detail_uv = UV * vec2(1.7, 1.2) + vec2(contact_variant * .37, contact_seconds * .85);
	float noise = texture(contact_detail, detail_uv).r;
	vec2 flame_uv = UV;
	flame_uv.x += (noise - .5) * .12 * (1.0 - UV.y);
	flame_uv.y += progress * .16;
	float source = texture(contact_flame, clamp(flame_uv, vec2(0.0), vec2(1.0))).r;
	float border = (1.0 - smoothstep(.45, .50, abs(UV.x - .5)))
		* smoothstep(0.0, .055, UV.y) * (1.0 - smoothstep(.94, 1.0, UV.y));
	float coverage = source * smoothstep(.025, .18 + progress * .08, source) * border;
	ALBEDO = mix(secondary_color, primary_color, smoothstep(.08, .78, source));
	ALPHA = coverage * contact_envelope();

	float native_raw_energy = max(max(ALBEDO.r + EMISSION.r, ALBEDO.g + EMISSION.g), ALBEDO.b + EMISSION.b);
	native_raw_energy *= native_palette_exposure;
	float native_energy = native_raw_energy / (1.0 + native_raw_energy);
	float native_position = native_energy * float(native_palette_count - 1);
	int native_first = int(floor(native_position));
	int native_second = min(native_first + 1, native_palette_count - 1);
	vec3 native_a = texture(native_palette_texture, vec2((float(native_first) + 0.5) / float(native_palette_count), 0.5)).rgb;
	vec3 native_b = texture(native_palette_texture, vec2((float(native_second) + 0.5) / float(native_palette_count), 0.5)).rgb;
	vec3 native_choice = mix(native_a, native_b, fract(native_position));
	if (native_palette_quantize) native_choice = cie_nearest(native_choice, native_palette_texture, native_palette_count, 0.0, 0.0);
	ALBEDO = vec3(cie_linear_channel(native_choice.r), cie_linear_channel(native_choice.g), cie_linear_channel(native_choice.b));
	EMISSION = ALBEDO * min(native_raw_energy, 2.0) * native_emission_gain;
	}


