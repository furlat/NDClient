shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled, depth_draw_never, depth_test_disabled;
#include "res://presentation/source_lighting.gdshaderinc"
uniform sampler2D sheet : filter_nearest, repeat_disable;
uniform vec4 frame_uv;
uniform vec3 tint = vec3(1.0);
uniform float layer_alpha = 1.0;
uniform bool shadow = false;
#include "res://presentation/character_material.gdshaderinc"
uniform float authored_base_light = 1.0;
// Native component packet: linear RGB normals + affine byte depth, with
// independent validity masks. It is not the environment RG16/oct packet.
uniform sampler2D component_depth : filter_nearest, repeat_disable;
uniform sampler2D component_normal : filter_nearest, repeat_disable;
uniform sampler2D component_support : filter_nearest, repeat_disable;
uniform sampler2D component_normal_valid : filter_nearest, repeat_disable;
uniform vec2 component_depth_range;
uniform float component_units = 0.0;
uniform float component_scale_x = 1.0;
uniform vec2 component_reconstruction_origin = vec2(64.0,96.0);
uniform float component_elevation = 0.7853981633974483;
uniform bool calibrated_component_receiver = true;
uniform bool has_component_geometry = false;
varying vec3 component_world_origin;
void vertex() { component_world_origin = (MODEL_MATRIX * vec4(0.0,0.0,0.0,1.0)).xyz; }
uniform bool use_component_depth = true;
uniform bool use_component_normals = true;
vec3 linear_colour(vec3 c) { return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c)); }
void fragment() {
    vec2 source_uv = frame_uv.xy + UV * frame_uv.zw;
    vec4 colour = texture(sheet, source_uv);
    if (colour.a <= 0.0) { discard; }
    // Ordinary authored layer tint multiplies every source shade exactly once.
    // Do this in encoded colour before the existing receiving-light boundary.
    vec3 untinted = colour.rgb;
    colour.rgb *= tint;
    if(!shadow) colour=character_material(colour,UV,untinted);
    // Compatibility linearizes shader outputs itself; Forward+/Mobile require
    // linear values from this raw, unpremultiplied source sampler.
    if (!OUTPUT_IS_SRGB) { colour.rgb = linear_colour(colour.rgb); }
    ALBEDO = shadow ? vec3(0.0) : colour.rgb;
    vec3 receiving_vertex = VERTEX;
    if (has_component_geometry && !shadow) {
        vec4 depth = texture(component_depth, source_uv);
        vec4 normal = texture(component_normal, source_uv);
        bool valid = texture(component_support, source_uv).r > 0.5
            && texture(component_normal_valid, source_uv).r > 0.5
            && depth.a > 0.5 && normal.a > 0.5;
        // Unsupported colour still draws with the original flat receiver.
        if (valid) {
            vec3 camera_right = normalize(INV_VIEW_MATRIX[0].xyz);
            vec3 horizontal_toward = normalize(vec3(INV_VIEW_MATRIX[2].x,0.0,INV_VIEW_MATRIX[2].z));
            vec3 source_up = vec3(0.0,cos(component_elevation),0.0) - horizontal_toward * sin(component_elevation);
            vec3 source_toward = horizontal_toward * cos(component_elevation) + vec3(0.0,sin(component_elevation),0.0);
            mat3 source_basis = mat3(camera_right,source_up,source_toward);
            if (use_component_normals && abs(component_scale_x) > 0.00001) {
                vec3 n = normal.rgb * 2.0 - 1.0;
                // Facing is already baked in camera axes. Apply only the
                // quad's inverse horizontal scale (including a mirror).
                n = normalize(vec3(n.x / component_scale_x, n.y, n.z));
                NORMAL = calibrated_component_receiver ? normalize(mat3(VIEW_MATRIX) * source_basis * n) : n;
            }
            if (use_component_depth) {
                float d = component_depth_range.x + (depth.r * 255.0 - 32.0)
                    * (component_depth_range.y - component_depth_range.x) / 192.0;
                if (calibrated_component_receiver) {
                    // Source reconstruction has its own origin/elevation. This
                    // receiving point never moves the painted quad or game Z.
                    vec2 pixel = mod(floor(source_uv * vec2(textureSize(sheet,0))),vec2(128.0));
                    vec3 point = vec3((pixel.x-component_reconstruction_origin.x)*component_scale_x,
                        component_reconstruction_origin.y-pixel.y,d)*component_units;
                    receiving_vertex = (VIEW_MATRIX * vec4(component_world_origin + source_basis*point,1.0)).xyz;
                } else { receiving_vertex.z += d * component_units; }
            }
        }
    }
    LIGHT_VERTEX = receiving_vertex;
    EMISSION = colour.rgb * authored_base_light;
    ALPHA = colour.a * layer_alpha;
    ROUGHNESS = 1.0;
}
