shader_type spatial;

// Preserved exporter palette, expressed in the native linear working space.
vec3 fire_finish_decode(vec3 encoded) {
	return mix(encoded / 12.92, pow((encoded + vec3(0.055)) / 1.055, vec3(2.4)), step(vec3(0.04045), encoded));
}
float fire_finish_encode(float linear_value) {
	return linear_value <= 0.0031308 ? linear_value * 12.92 : 1.055 * pow(linear_value, 1.0 / 2.4) - 0.055;
}
vec3 fire_finish_palette(int index) {
	if (index == 0) return fire_finish_decode(vec3(56.0,35.0,42.0)/255.0);
	if (index == 1) return fire_finish_decode(vec3(121.0,49.0,41.0)/255.0);
	if (index == 2) return fire_finish_decode(vec3(188.0,72.0,38.0)/255.0);
	if (index == 3) return fire_finish_decode(vec3(232.0,120.0,41.0)/255.0);
	if (index == 4) return fire_finish_decode(vec3(246.0,184.0,76.0)/255.0);
	return fire_finish_decode(vec3(246.0,223.0,149.0)/255.0);
}

uniform mat4 factory_world_to_source=mat4(1.0);
uniform float factory_occurrence_alpha=1.0;

varying float flame_rise;

uniform float support_clock=0.0;
uniform float support_envelope=1.0;
uniform float support_age=0.0;
render_mode unshaded, cull_disabled;

uniform sampler2D sprite_sheet;
uniform sampler2D gradient_1d_texture:repeat_disable;
uniform vec2 frame_count = vec2(4.0, 3.0); // Columns, Rows
uniform bool is_loop = false;
uniform vec2 uv_offset = vec2(0.0);

varying vec2 anim_UV;

void vertex() {float birth = 0.08 + clamp(dot(MODEL_MATRIX[3].xz, vec2(0.70710678118655,0.70710678118655)) * 0.23 + 0.28,0.0,0.6); float rising=smoothstep(birth,birth+0.55,support_age); flame_rise=rising; VERTEX.y *= max(0.008,rising);

    // Calculate frame offset (your original method)
    float last_cell = (frame_count.x * frame_count.y) - 1.0;
	
	float timex = COLOR.a;
	if (is_loop){ timex = fract(support_clock * 0.5 + fract(dot(MODEL_MATRIX[3].xz,vec2(13.47,19.31))) + INSTANCE_CUSTOM.y * 0.13);}
    float frame_index = floor(timex * last_cell);
    vec2 frame_offset = vec2(
        mod(frame_index, frame_count.x) / frame_count.x,
        floor(frame_index / frame_count.x) / frame_count.y
    );

    // Apply texture scaling
    vec2 frame_size = vec2(1.0) / frame_count;
    anim_UV = (UV * frame_size + frame_offset);
}

void fragment() {
vec3 support_world=(factory_world_to_source * INV_VIEW_MATRIX * vec4(VERTEX,1.0)).xyz;


	
    float img = texture(sprite_sheet, anim_UV+ uv_offset ).r;
	vec4 tex = texture(gradient_1d_texture,vec2(img));
    ALBEDO = tex.rgb * COLOR.rgb;
	
	float alphad = tex.a;
	if (is_loop){alphad=alphad*COLOR.a;}
    ALPHA = alphad;


ALPHA *= support_envelope;
ALPHA *= smoothstep(0.12,0.38,flame_rise);

float fire_finish_gray=clamp(dot(ALBEDO,vec3(0.2126,0.7152,0.0722))*0.65,0.05,0.85);
// The original byte-image finish did not unpremultiply its energy sample.
// Here this is the isolated draw's coverage, not the unavailable composite.
float fire_finish_coverage=clamp(ALPHA*factory_occurrence_alpha,0.0,1.0);
float fire_finish_energy=floor(clamp(fire_finish_encode(fire_finish_gray*fire_finish_coverage),0.0,1.0)*255.0+0.5);
int fire_finish_index=int(clamp(floor(pow(fire_finish_energy/255.0,1.15)*5.0+0.5),0.0,5.0));
ALBEDO=fire_finish_palette(fire_finish_index);
EMISSION=vec3(0.0);


ALPHA *= factory_occurrence_alpha;
}




