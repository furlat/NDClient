shader_type spatial;
global uniform sampler2D vfx_package_clock;
uniform int vfx_package_clock_slot=0;
float vfx_package_seconds(){return texelFetch(vfx_package_clock,ivec2(vfx_package_clock_slot,0),0).r;}
uniform float vfx_package_offset_phase=0.0;

uniform float factory_occurrence_alpha=1.0;

uniform mat4 factory_world_to_source=mat4(1.0);uniform float phase=0.0;uniform float envelope=0.0;uniform vec2 actor_ground=vec2(0.0);uniform vec2 camera_ground=vec2(.70710678);uniform bool foreground=false;uniform bool split_layers=false;
render_mode blend_mix, depth_draw_never, unshaded, cull_disabled;

uniform sampler2D sprite_sheet;
uniform sampler2D normal_sprite    :hint_normal;
uniform float     normal_intensity :hint_range(-8.0, 8.0, 0.01) = 0.0;
uniform sampler2D rought_sprite    :hint_roughness_r;
uniform vec2 frame_count = vec2(4.0, 3.0); // Columns, Rows

varying vec2 anim_UV;

void vertex() {
    // Calculate frame offset (your original method)
    float last_cell = (frame_count.x * frame_count.y) - 1.0;
    float frame_index = floor((vfx_package_seconds()+vfx_package_offset_phase) * last_cell);
    vec2 frame_offset = vec2(
        mod(frame_index, frame_count.x) / frame_count.x,
        floor(frame_index / frame_count.x) / frame_count.y
    );

    // Apply texture scaling
    vec2 frame_size = vec2(1.0) / frame_count;
    anim_UV = (UV * frame_size + frame_offset);
}

void fragment() {
    vec4  tex = texture(sprite_sheet, anim_UV);
	vec3  tex_norm = texture(normal_sprite, anim_UV).rgb;
	float tex_r    = texture(rought_sprite, anim_UV).r;

	ALBEDO = vec3(.78,.87,.91);
	ALPHA = tex.a*envelope*.72;vec3 wp=(factory_world_to_source * INV_VIEW_MATRIX * vec4(VERTEX,1.0)).xyz;
	ROUGHNESS = tex_r;
	NORMAL_MAP = tex_norm;
	NORMAL_MAP_DEPTH = normal_intensity;


ALPHA *= factory_occurrence_alpha;
}



