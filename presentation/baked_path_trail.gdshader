shader_type particles;
// Ribbon trail of a moving baked occurrence, computed from its path instead
// of a frame-by-frame history: particle k is the segment between the emitter
// positions k and k+1 trail steps ago, laid out as GPUTrail3D's draw pass
// reads them (columns = left top, right top, right bottom, left bottom;
// CUSTOM.w = place in the trail + 2, CUSTOM.z = amount). Before the trail's
// release every point is the release point, so no segment has width.
render_mode disable_force, disable_velocity, keep_data;
#include "res://presentation/baked_path.gdshaderinc"

global uniform sampler2D baked_effect_clock;
uniform int clock_slot = 0;
// Emitter relative to the root: per source frame when the source moves it
// (rows, 3 per frame, from `emitter_first`), otherwise `emitter_offset`.
uniform bool emitter_tracked = false;
uniform sampler2D emitter_track : filter_nearest, repeat_disable;
uniform float emitter_rate = 60.0;
uniform mat4 emitter_offset = mat4(1.0);
uniform float trail_step = 0.0133333;
uniform float release_time = -1000000.0;
// GPUTrail3D billboard: the two edges lie along the motion (the emitter and
// one up-axis length ahead); the draw pass then widens them toward the camera.
uniform bool billboard = false;

mat4 emitter_at(float presentation) {
	mat4 offset = emitter_tracked ? baked_rows_at(emitter_track, baked_source_of(presentation) * emitter_rate, 0) : emitter_offset;
	return baked_root_at(presentation) * offset;
}

void edges(float time, out vec4 top, out vec4 bottom) {
	mat4 emitter = emitter_at(time);
	top = emitter * vec4(0.0, 1.0, 0.0, 1.0);
	bottom = emitter * vec4(0.0, -1.0, 0.0, 1.0);
	if (billboard) {
		// The direction of the last motion: a stopped emitter keeps it, as
		// GPUTrail3D keeps its last billboard transform.
		vec3 motion = vec3(0.0);
		float back = 1.0 / PATH_RATE;
		for (int attempt = 0; attempt < 6 && length(motion) <= 0.00001; attempt++) {
			motion = emitter[3].xyz - emitter_at(time - back)[3].xyz;
			back *= 4.0;
		}
		if (length(motion) > 0.00001) {
			top = vec4(emitter[3].xyz + length(emitter[1].xyz) * normalize(motion), 1.0);
			bottom = vec4(emitter[3].xyz, 1.0);
		}
	}
}

void process() {
	float now = texelFetch(baked_effect_clock, ivec2(clock_slot, 0), 0).g;
	int k = int(INDEX);
	// GPUTrail3D keeps its lifetime equal to its particle count.
	float amount = LIFETIME;
	vec4 rt, rb, lt, lb;
	edges(max(now - float(max(k - 1, 0)) * trail_step, release_time), rt, rb);
	edges(max(now - float(k) * trail_step, release_time), lt, lb);
	TRANSFORM = k == 0 ? mat4(rt, rt, rb, rb) : mat4(lt, rt, rb, lb);
	CUSTOM.z = amount;
	CUSTOM.w = float(k + 2);
	if (now < release_time) {
		TRANSFORM = mat4(rt, rt, rb, rb);
	}
}
