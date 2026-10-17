shader_type particles;
// Baked world-space particles of a moving occurrence (a projectile's sparks
// and smoke stay where they were emitted). Recorded states are relative to
// the effect root as it was when each life began, so a particle is placed by
// the root's actual path at that moment (root_history), not where it is now.
render_mode disable_force, disable_velocity, keep_data;
#include "res://presentation/baked_vat.gdshaderinc"
#include "res://presentation/baked_path.gdshaderinc"

global uniform sampler2D baked_effect_clock;
uniform int clock_slot = 0;

void start() {
	TRANSFORM = mat4(vec4(0.0), vec4(0.0), vec4(0.0), vec4(0.0, 0.0, 0.0, 1.0));
	COLOR = vec4(0.0);
}

void process() {
	float source = max(texelFetch(baked_effect_clock, ivec2(clock_slot, 0), 0).r, 0.0);
	mat4 state; vec3 velocity; vec4 colour; vec4 custom; float life_start;
	if (baked_state(int(INDEX), source * vat_rate, state, velocity, colour, custom, life_start)) {
		mat4 root = baked_root_at(baked_presentation_of(life_start / vat_rate));
		TRANSFORM = root * state;
		VELOCITY = mat3(root) * velocity;
		COLOR = colour;
		CUSTOM = custom;
	} else {
		TRANSFORM = state;
		VELOCITY = velocity;
		COLOR = colour;
	}
}
