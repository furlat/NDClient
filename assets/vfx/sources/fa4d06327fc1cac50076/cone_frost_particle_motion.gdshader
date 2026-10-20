shader_type particles;
render_mode disable_force, disable_velocity;

uniform sampler2D source_parameters : filter_nearest, repeat_disable;
uniform float cone_source_age = 0.0;
uniform int cone_source_kind = 0;

void process() {
	vec4 a = texelFetch(source_parameters, ivec2(int(INDEX), 0), 0);
	vec4 b = texelFetch(source_parameters, ivec2(int(INDEX), 1), 0);
	float age = cone_source_age - a.x;
	float x = 0.55 + max(0.0, age * a.y);
	float radius = x * sqrt(1.0 + a.z * a.z);
	COLOR = vec4(1.0);
	VELOCITY = vec3(0.0);
	ACTIVE = true;
	// The retained source creates visible identity-transformed MeshInstances
	// before its first advancing tick. Preserve that exact zero-age state too.
	if (cone_source_age == 0.0) {
		TRANSFORM = mat4(1.0);
		CUSTOM = cone_source_kind == 0 ? vec4(b.yz, 1.0, 1.0) : vec4(1.0);
	} else if (cone_source_kind == 0) {
		float fade = smoothstep(0.0, 0.12, age) * (1.0 - smoothstep(10.0, 12.0, radius));
		float y = max(0.18, 0.90 + sin(x * 0.63 + a.w) * min(0.30 + x * 0.1, 1.05));
		float z = -0.1 + a.z * (x - 0.55) + sin(x * 0.9 + a.w) * 0.08 * x;
		float sx = (0.6 + x * 0.16) * b.x;
		float sy = (0.5 + x * 0.11) * b.x;
		float c = cos(PI / 4.0);
		float s = sin(PI / 4.0);
		// Basis.scaled() is global-axis scale S*R, not local R*S.
		TRANSFORM = mat4(vec4(c * sx, 0.0, -s, 0.0),
			vec4(0.0, sy, 0.0, 0.0), vec4(s * sx, 0.0, c, 0.0), vec4(x, y, z, 1.0));
		CUSTOM = vec4(b.yz, age >= 0.0 && radius < 12.0 ? fade * 0.85 : 0.0, 1.0);
	} else {
		vec4 extra = texelFetch(source_parameters, ivec2(int(INDEX), 2), 0);
		float grow = smoothstep(0.0, 0.055, age) * (1.0 - smoothstep(11.0, 12.0, radius));
		if (age < 0.0 || radius >= 12.0) grow = 0.0;
		vec3 angles = b.xyz + vec3(1.0, 2.0, 1.0) * age;
		vec3 cs = cos(angles);
		vec3 sn = sin(angles);
		mat3 rx = mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, cs.x, sn.x), vec3(0.0, -sn.x, cs.x));
		mat3 ry = mat3(vec3(cs.y, 0.0, -sn.y), vec3(0.0, 1.0, 0.0), vec3(sn.y, 0.0, cs.y));
		mat3 rz = mat3(vec3(cs.z, sn.z, 0.0), vec3(-sn.z, cs.z, 0.0), vec3(0.0, 0.0, 1.0));
		mat3 spin = ry * rx * rz;
		float scale = b.w * grow;
		vec3 axis_scale = vec3(scale, scale * 0.55, scale);
		vec3 position = vec3(x, max(0.15, 0.90 + a.w * x * 0.17 + 0.12 * sin(x + extra.x)),
			-0.1 + a.z * (x - 0.55));
		TRANSFORM = mat4(vec4(spin[0] * axis_scale, 0.0), vec4(spin[1] * axis_scale, 0.0),
			vec4(spin[2] * axis_scale, 0.0), vec4(position, 1.0));
		CUSTOM = vec4(1.0);
	}
}

