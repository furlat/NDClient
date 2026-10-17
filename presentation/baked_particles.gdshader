shader_type particles;
// Baked particle playback. Every particle's recorded state is read at the
// effect's current source time (clock texel `clock_slot`); nothing is
// simulated, so any time draws directly. States are relative to the emitter
// node, which stays where the source had it.
render_mode disable_force, disable_velocity, keep_data;
#include "res://presentation/baked_vat.gdshaderinc"

global uniform sampler2D baked_effect_clock;
uniform int clock_slot = 0;

void start() {
	TRANSFORM = mat4(vec4(0.0), vec4(0.0), vec4(0.0), vec4(0.0, 0.0, 0.0, 1.0));
	COLOR = vec4(0.0);
}

void process() {
	float source = max(texelFetch(baked_effect_clock, ivec2(clock_slot, 0), 0).r, 0.0);
	mat4 state; vec3 velocity; vec4 colour; vec4 custom; float life_start;
	bool shown = baked_state(int(INDEX), source * vat_rate, state, velocity, colour, custom, life_start);
	TRANSFORM = state;
	VELOCITY = velocity;
	COLOR = colour;
	if (shown) CUSTOM = custom;
}
