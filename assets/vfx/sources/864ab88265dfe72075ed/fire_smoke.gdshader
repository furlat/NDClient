shader_type spatial;
render_mode blend_mix, unshaded;
uniform float cloud_clock=0.;
uniform float cloud_age=0.;
uniform float cloud_opacity=1.;
uniform float cloud_radius=4.;
uniform float roll_weight=0.;
varying vec3 cloud_world;

uniform sampler2D noise_texture_1;
uniform sampler2D noise_texture_2;
uniform sampler2D texture_mask;
uniform float edge_softness = 1.0;
uniform vec2 texture_scale = vec2(1.0,1.0);

uniform vec4 smoke_color : source_color;
uniform float lightness = 0.0;

uniform vec2 mask_from = vec2(0.5);
uniform float mask_scale = 0.4;

void vertex() {
	mat4 modified_model_view = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0],
		INV_VIEW_MATRIX[1],
		INV_VIEW_MATRIX[2],
		MODEL_MATRIX[3]
		);
	MODELVIEW_MATRIX = modified_model_view;

	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
 cloud_world=(INV_VIEW_MATRIX*MODELVIEW_MATRIX*vec4(VERTEX,1.)).xyz;
}

void fragment() {
	float lifetime = 0.5 + COLOR.a * 0.5;

	float warp_noise = 1.0-(texture(noise_texture_2,(UV + vec2(-cloud_clock * 0.5, 0.0))).r * .0003);

	vec2 uv_offset = vec2(COLOR.r * 2.0);
	uv_offset = uv_offset + (vec2(sin(cloud_clock*1.0)*.1,COLOR.a*.1)*warp_noise);
	float noise = texture(noise_texture_1,(UV*.3*texture_scale) + uv_offset).r;

	float mask = smoothstep(1.0-mask_scale,1.0,1.0-distance(mask_from, UV));

	float masked_noise = mask * noise;

	vec3 main_color = vec3(1.0, lightness+(pow(COLOR.a, 8.0)*.1), (pow(COLOR.a, 16.0)*lightness));
	main_color = mix(smoke_color.rgb, main_color, pow(COLOR.a, 8.0));

	ALBEDO = main_color;
	EMISSION=vec3(0.);
 float heat_macro=texture(noise_texture_1,cloud_world.xz*.13+vec2(sin(cloud_clock*.19)*.06,cos(cloud_clock*.19)*.06)).r;
 float hot_fraction=pow(COLOR.a,4.)*mix(.30,1.,smoothstep(.30,.64,heat_macro));
 ALBEDO=mix(vec3(.07,.055,.05),mix(vec3(.52,.045,.006),vec3(1.,.55,.05),smoothstep(.2,.9,noise)),hot_fraction);

	float r=length(cloud_world.xz);
 float spread=smoothstep(r/4.,r/4.+.16,cloud_age/1.05);
 ALPHA=smoothstep(.16,.4,masked_noise)*pow(COLOR.a,.8)*cloud_opacity*spread;
 ALPHA*=1.-smoothstep(3.75,4.,length(vec3(cloud_world.x,max(0.,cloud_world.y),cloud_world.z)));
 // Zero opacity at the actual floor before many overlapping particles are
 // accumulated; a negative lower edge left opaque horizontal slab contacts.
 ALPHA*=smoothstep(0.0,.55,cloud_world.y);
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
