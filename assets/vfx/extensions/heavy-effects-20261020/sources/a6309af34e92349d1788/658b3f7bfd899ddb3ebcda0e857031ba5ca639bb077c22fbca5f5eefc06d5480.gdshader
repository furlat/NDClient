shader_type spatial;
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
ALBEDO=vec3(clamp(dot(ALBEDO,vec3(0.2126,0.7152,0.0722))*0.65,0.05,0.85));EMISSION=vec3(0.0);

ALPHA *= factory_occurrence_alpha;
}




