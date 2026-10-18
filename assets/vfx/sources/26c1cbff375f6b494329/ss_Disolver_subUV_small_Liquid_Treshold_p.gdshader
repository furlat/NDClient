shader_type spatial;
render_mode blend_mix, cull_back, diffuse_lambert, specular_schlick_ggx;

uniform vec2 Scale = vec2(1.0, 1.0);
uniform vec2 Speed_XY;
uniform sampler2D Disolver_Texture : source_color, repeat_enable;
uniform sampler2D Color_1D_Gradient : source_color, repeat_disable;
uniform sampler2D Metallic_Texture : source_color, repeat_disable;
uniform sampler2D Texture_Roughtness : source_color, repeat_enable;
uniform sampler2D Roughtness_1D_Gradient : source_color, repeat_disable;
uniform sampler2D Normal_Texture : hint_normal, repeat_enable;
uniform float Normal_Map_Depth = 1.0;
uniform float Color_Intensity = 1.0;
uniform sampler2D ColorTime_1D_Gradient : source_color, repeat_disable;

// SubUV parameters
uniform ivec2 subuv_grid = ivec2(1, 1); // Columns x Rows
uniform bool use_subuv = false;

float random(float seed) {
    return fract(sin(dot(vec2(seed, seed * 2.0), vec2(12.9898, 78.233))) * 43758.5453);
}

vec2 get_subuv_coordinates(vec2 original_uv, ivec2 grid, float random_seed) {
    if (!use_subuv || (grid.x <= 1 && grid.y <= 1)) {
        return original_uv;
    }
    
    int total_frames = grid.x * grid.y;
    int frame_index = int(random_seed * float(total_frames));
    frame_index = clamp(frame_index, 0, total_frames - 1);
    
    ivec2 cell = ivec2(frame_index % grid.x, frame_index / grid.x);
    
    vec2 cell_size = vec2(1.0 / float(grid.x), 1.0 / float(grid.y));
    vec2 cell_offset = vec2(cell) * cell_size;
    
    // Scale UV to fit within the cell
    vec2 sub_uv = original_uv * cell_size + cell_offset;
    
    return sub_uv;
}

void fragment() {
    // Calculate base UV coordinates
    vec2 base_uv = UV * Scale;
    vec2 animated_uv = base_uv + Speed_XY * TIME;
    
    // Get random seed from particle properties
    float random_seed = COLOR.r;  
    
    // Apply subUV transformation if enabled
    vec2 final_uv = use_subuv ? get_subuv_coordinates(animated_uv, subuv_grid, random_seed) : animated_uv;
    
    // Sample dissolution texture and gradient
    float dissolution_value = texture(Disolver_Texture, final_uv).r;
    vec3 gradient_color = texture(Color_1D_Gradient, vec2(dissolution_value)).rgb;
    
	float gradient_time_color = texture(ColorTime_1D_Gradient, vec2(COLOR.a,UV.y) ).r;
	
    // Apply vertex color tint 
    vec3 albedo_color = gradient_color * gradient_time_color;
	
    
    // Sample material textures (using the same subUV coordinates for consistency)
    vec2 material_uv = use_subuv ? get_subuv_coordinates(animated_uv, subuv_grid, random_seed) : animated_uv;
    float metallic = texture(Metallic_Texture, material_uv).r;
    float roughness_raw = texture(Texture_Roughtness, material_uv).r;
    float roughness = texture(Roughtness_1D_Gradient, vec2(roughness_raw)).r;
    vec3 normal_map = texture(Normal_Texture, material_uv).rgb;
    
    // Set output parameters
    ALBEDO = albedo_color * Color_Intensity;
    ALPHA = dissolution_value;
    METALLIC = metallic;
    ROUGHNESS = roughness;
    NORMAL_MAP = normal_map;
    NORMAL_MAP_DEPTH = Normal_Map_Depth;
    ALPHA_SCISSOR_THRESHOLD = COLOR.a;
}