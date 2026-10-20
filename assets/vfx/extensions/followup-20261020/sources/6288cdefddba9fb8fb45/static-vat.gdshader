shader_type particles;
// Baked particle playback. Every particle's recorded state is read at the
// effect's current source time (clock texel `clock_slot`); nothing is
// simulated, so any time draws directly. States are relative to the emitter
// node, which stays where the source had it.
render_mode disable_force, disable_velocity, keep_data;
// Recorded particle states (tools/bake_native_effects.gd). Rows per particle
// (RGBA half): 0..2 = basis column xyz + origin component, 3 = colour,
// 4 = custom, 5 = (alive, life start frame); columns are recording frames
// from `vat_first`. Lives that start after `emission_stop_frame` are hidden,
// which is what stopping emission does to a simulation.
uniform sampler2D vat : filter_nearest, repeat_disable;
uniform float vat_rate = 60.0;
uniform int vat_frames = 1;
uniform int vat_first = 0;
uniform float emission_stop_frame = 1000000.0;

const int VAT_TEXELS = 6;

// The recorded state of particle `index` at recording frame `frame`
// (fractional). False when the particle shows nothing at that time.
bool baked_state(int index, float frame, out mat4 transform, out vec3 velocity, out vec4 colour, out vec4 custom, out float life_start) {
	float local = frame - float(vat_first);
	int f0 = int(floor(local));
	int f1 = f0 + 1;
	float w = local - float(f0);
	bool in0 = f0 >= 0 && f0 < vat_frames;
	bool in1 = f1 >= 0 && f1 < vat_frames;
	f0 = clamp(f0, 0, vat_frames - 1);
	f1 = clamp(f1, 0, vat_frames - 1);
	int row = index * VAT_TEXELS;
	vec4 life0 = texelFetch(vat, ivec2(f0, row + 5), 0);
	vec4 life1 = texelFetch(vat, ivec2(f1, row + 5), 0);
	bool alive0 = in0 && life0.x > 0.5 && life0.y <= emission_stop_frame;
	bool alive1 = in1 && life1.x > 0.5 && life1.y <= emission_stop_frame;
	// A death or birth between samples, or a new life, takes the nearest sample.
	if (alive0 && alive1 && life0.y != life1.y) {
		alive0 = w < 0.5;
		alive1 = !alive0;
	}
	transform = mat4(vec4(0.0), vec4(0.0), vec4(0.0), vec4(0.0, 0.0, 0.0, 1.0));
	velocity = vec3(0.0);
	colour = vec4(0.0);
	custom = vec4(0.0);
	life_start = 0.0;
	if (!((alive0 && alive1) || (alive0 && w < 0.5) || (alive1 && w >= 0.5))) return false;
	float t = (alive0 && alive1) ? w : (alive0 ? 0.0 : 1.0);
	vec4 x0 = texelFetch(vat, ivec2(f0, row), 0), x1 = texelFetch(vat, ivec2(f1, row), 0);
	vec4 y0 = texelFetch(vat, ivec2(f0, row + 1), 0), y1 = texelFetch(vat, ivec2(f1, row + 1), 0);
	vec4 z0 = texelFetch(vat, ivec2(f0, row + 2), 0), z1 = texelFetch(vat, ivec2(f1, row + 2), 0);
	vec4 x = mix(x0, x1, t), y = mix(y0, y1, t), z = mix(z0, z1, t);
	transform = mat4(vec4(x.xyz, 0.0), vec4(y.xyz, 0.0), vec4(z.xyz, 0.0), vec4(x.w, y.w, z.w, 1.0));
	velocity = (alive0 && alive1) ? (vec3(x1.w, y1.w, z1.w) - vec3(x0.w, y0.w, z0.w)) * vat_rate : vec3(0.0);
	colour = mix(texelFetch(vat, ivec2(f0, row + 3), 0), texelFetch(vat, ivec2(f1, row + 3), 0), t);
	custom = mix(texelFetch(vat, ivec2(f0, row + 4), 0), texelFetch(vat, ivec2(f1, row + 4), 0), t);
	life_start = (alive0 ? life0 : life1).y;
	return true;
}



uniform float factory_recorded_age = 0.0;

void start() {
	TRANSFORM = mat4(vec4(0.0), vec4(0.0), vec4(0.0), vec4(0.0, 0.0, 0.0, 1.0));
	COLOR = vec4(0.0);
}

void process() {
	float source = max(factory_recorded_age, 0.0);
	mat4 state; vec3 velocity; vec4 colour; vec4 custom; float life_start;
	bool shown = baked_state(int(INDEX), source * vat_rate, state, velocity, colour, custom, life_start);
	TRANSFORM = state;
	VELOCITY = velocity;
	COLOR = colour;
	if (shown) CUSTOM = custom;
}

