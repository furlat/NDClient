// Path of a moving baked occurrence. `root_history` holds the occurrence
// root's world transform per presentation frame (PATH_RATE per second, cue
// time 0 at column 0; rows are the 3x4 matrix rows), written by the CPU as
// the cue plays. The cue's own source/presentation mapping is uniform data.
const float PATH_RATE = 60.0;
uniform sampler2D root_history : filter_nearest, repeat_disable;
// 0: source = presentation * rate; 1: flight (charge, retimed travel, tail).
uniform int cue_mode = 0;
uniform float cue_launch = 0.0;
uniform float cue_contact = 0.0;
uniform float source_launch = 0.0;
uniform float source_contact = 0.0;
uniform float source_rate = 1.0;

float baked_presentation_of(float source) {
	if (cue_mode == 1) {
		if (source < source_launch) return cue_launch * source / max(source_launch, 0.0001);
		if (source < source_contact) return mix(cue_launch, cue_contact, (source - source_launch) / max(source_contact - source_launch, 0.0001));
		return cue_contact + source - source_contact;
	}
	return source / max(source_rate, 0.0001);
}

float baked_source_of(float presentation) {
	if (cue_mode == 1) {
		if (presentation < cue_launch) return source_launch * clamp(presentation / max(cue_launch, 0.0001), 0.0, 1.0);
		if (presentation < cue_contact) return mix(source_launch, source_contact, (presentation - cue_launch) / max(cue_contact - cue_launch, 0.0001));
		return source_contact + presentation - cue_contact;
	}
	return max(presentation, 0.0) * source_rate;
}

mat4 baked_rows(sampler2D rows, int column, int row) {
	vec4 x = texelFetch(rows, ivec2(column, row), 0);
	vec4 y = texelFetch(rows, ivec2(column, row + 1), 0);
	vec4 z = texelFetch(rows, ivec2(column, row + 2), 0);
	return mat4(vec4(x.x, y.x, z.x, 0.0), vec4(x.y, y.y, z.y, 0.0), vec4(x.z, y.z, z.z, 0.0), vec4(x.w, y.w, z.w, 1.0));
}

// Linear blend of two sampled transforms (adjacent frames differ little).
mat4 baked_rows_at(sampler2D rows, float column, int row) {
	int last = textureSize(rows, 0).x - 1;
	float c = clamp(column, 0.0, float(last));
	int c0 = int(floor(c));
	int c1 = min(c0 + 1, last);
	float w = c - float(c0);
	mat4 a = baked_rows(rows, c0, row), b = baked_rows(rows, c1, row);
	return mat4(mix(a[0], b[0], w), mix(a[1], b[1], w), mix(a[2], b[2], w), mix(a[3], b[3], w));
}

mat4 baked_root_at(float presentation) {
	return baked_rows_at(root_history, presentation * PATH_RATE, 0);
}
