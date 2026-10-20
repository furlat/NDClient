shader_type spatial;
#ifndef FACTORY_WEAPON_LAYERS_INCLUDED
#define FACTORY_WEAPON_LAYERS_INCLUDED
#include "res://assets/vfx/sources/923689de2051b7ed9b64/element_material.gdshaderinc"
#include "res://assets/vfx/sources/e4eb6fc0555192afd006/material.gdshaderinc"
#include "res://assets/vfx/sources/d761107faea637232d05/material.gdshaderinc"
// Explicit appearance mode: normal enhancement, pure blade, or exterior-only.
// The real actor layer remains present and supplies current pose/depth.
uniform int weapon_receiver_draw_mode = 0;
uniform bool weapon_receiver_draw_enabled = false;
float weapon_material_alpha() {
    return weapon_receiver_draw_enabled && weapon_receiver_draw_mode == 2 ? 0.0 : 1.0;
}
// The equipped sprite owns alpha, frame UV, geometry, normals and painter order.
// Fields contain live native material output, not a replacement weapon image.
uniform int weapon_material_count = 0;
uniform sampler2D weapon_material_fields[8] : filter_linear, repeat_disable;
uniform float weapon_material_strengths[8];
uniform int weapon_material_modes[8];
// Optional direct material study on the equipped draw itself. The receiving
// sprite still owns coverage: no fragment is grown across a missing blade.
uniform bool weapon_blade_enabled = false;
uniform float weapon_blade_seconds = 0.0;
uniform float weapon_blade_strength = 1.0;
uniform int weapon_blade_variant = 0;
uniform sampler2D weapon_blade_source : filter_nearest, repeat_disable;
uniform vec4 weapon_blade_frame;
uniform sampler2D weapon_blade_noise : filter_linear, repeat_enable;
uniform vec4 weapon_blade_hilt_tip = vec4(0.0);
uniform bool weapon_blade_axis_valid = false;
uniform sampler2D weapon_blade_normals : filter_nearest, repeat_disable;
uniform bool weapon_blade_has_normals = false;
uniform sampler2D weapon_blade_normal_valid : filter_nearest, repeat_disable;
uniform bool weapon_blade_has_normal_valid = false;
vec3 weapon_blade_colour(vec3 original, vec2 cell_uv) {
    if (!weapon_blade_enabled) return original;
    vec3 source = texture(weapon_blade_source,
        weapon_blade_frame.xy + cell_uv * weapon_blade_frame.zw).rgb;
    float high = max(source.r, max(source.g, source.b));
    float low = min(source.r, min(source.g, source.b));
    float metal = (1.0 - smoothstep(0.07, 0.22, high - low))
        * smoothstep(0.10, 0.28, high);
    // LeLu Weapon Effects: UV/Aura_Divide + time*Speed, then sample the
    // original tiled Perlin texture. The real blade replaces the donor mask.
    vec2 axis = weapon_blade_hilt_tip.zw - weapon_blade_hilt_tip.xy;
    vec2 direction = axis / max(length(axis), 0.00001);
    vec2 delta = cell_uv - weapon_blade_hilt_tip.xy;
    vec2 blade_uv = vec2(dot(delta, vec2(-direction.y, direction.x)) * 32.0,
        dot(delta, direction) / max(length(axis), 0.00001));
    vec2 flow_uv = vec2(blade_uv.x * 0.45, blade_uv.y * 0.8)
        - vec2(0.0, weapon_blade_seconds * 1.1);
    float source_noise = texture(weapon_blade_noise, flow_uv).r;
    if (!weapon_blade_axis_valid) source_noise = 0.5;
    float heat = clamp(high * 0.68 + source_noise * 0.45, 0.0, 1.0);
    vec3 pigment = mix(vec3(0.17, 0.009, 0.001),
        vec3(1.0, 0.34, 0.018), smoothstep(0.12, 0.90, heat));
    if (weapon_blade_variant == 1) {
        // Forged ember variant: preserve dark metal between incandescent veins.
        // This is a surface mechanism, not a recoloured copy of the fire coat.
        float vein = smoothstep(0.54, 0.72, source_noise);
        pigment = mix(original * vec3(0.45, 0.22, 0.15),
            vec3(1.0, 0.23, 0.009), vein * 0.88);
    }
    return mix(original, pigment, metal * weapon_blade_strength);
}
vec3 weapon_material_colour(vec3 original, vec2 cell_uv) {
    vec3 colour = original;
    for (int layer = 0; layer < min(weapon_material_count, 8); layer++) {
        vec4 field = texture(weapon_material_fields[layer], cell_uv);
        vec3 pigment = field.a > 0.0001 ? field.rgb / field.a : field.rgb;
        float coverage = clamp(max(field.a, max(field.r, max(field.g, field.b)))
            * weapon_material_strengths[layer], 0.0, 1.0);
        vec3 result = pigment;
        if (weapon_material_modes[layer] == 1) {
            result = vec3(1.0) - (vec3(1.0) - clamp(colour, vec3(0.0), vec3(1.0)))
                * (vec3(1.0) - clamp(pigment, vec3(0.0), vec3(1.0)));
        } else if (weapon_material_modes[layer] == 2) {
            result = colour * pigment;
        }
        colour = mix(colour, result, coverage);
    }
    colour = weapon_blade_colour(colour, cell_uv);
    vec3 source_normal = vec3(0.0, 0.0, 1.0);
    if (weapon_blade_has_normals && (weapon_element_enabled || weapon_auxiliary_enabled || weapon_pure_enabled)) {
        vec4 sample_normal = texture(weapon_blade_normals,
            weapon_blade_frame.xy + cell_uv * weapon_blade_frame.zw);
        vec3 decoded = sample_normal.rgb * 2.0 - 1.0;
        if (sample_normal.a > 0.5 && length(decoded) > 0.001
            && (!weapon_blade_has_normal_valid || texture(weapon_blade_normal_valid,
                weapon_blade_frame.xy + cell_uv * weapon_blade_frame.zw).r > 0.5))
            source_normal = normalize(decoded);
    }
    colour = weapon_element_colour(colour, cell_uv, source_normal);
    colour = weapon_auxiliary_colour(colour, cell_uv, source_normal);
    return weapon_pure_colour(colour, cell_uv, source_normal);
}
#endif


render_mode cull_disabled, diffuse_lambert, specular_disabled, depth_draw_never, depth_test_disabled;
// Original source receivers are supplied through NORMAL/LIGHT_VERTEX. Native
// Godot lights own culling, attenuation and accumulation before alpha blending.
uniform bool two_sided_receiver = false;
float receiving_diffuse(vec3 normal, vec3 to_light) {
    float cosine = dot(normal, to_light);
    return two_sided_receiver ? abs(cosine) : max(cosine, 0.0);
}


uniform sampler2D sheet : filter_nearest, repeat_disable;
uniform vec4 frame_uv;
uniform vec3 tint = vec3(1.0);
uniform float layer_alpha = 1.0;
uniform bool shadow = false;
// Ordinary outfit tint is applied by the caller. These are explicit authored
// effect/condition operations; the native receiving/output passes share them.
#ifndef NATIVE_BODY_MATERIAL_INCLUDED
#define NATIVE_BODY_MATERIAL_INCLUDED
// Live native material colour, evaluated by Godot in a small viewport.
// Coverage belongs exclusively to the painted character, never to this texture.
uniform bool native_body_enabled=false;
uniform sampler2D native_body_surface:filter_linear,repeat_disable;
uniform float native_body_strength=0.0;
uniform sampler2D native_body_ramp:filter_linear,repeat_disable;
uniform int native_body_ramp_count=0;
uniform float native_body_ramp_floor=0.0;
uniform float native_body_ramp_ceiling=1.0;
uniform bool native_body_ramp_uses_luma=false;
// Shared native spell finishing. Input and output are the same encoded,
// premultiplied viewport colour used by the sandbox's visible VFX composition.
vec4 finish_native_spell(vec4 source,sampler2D ramp,int count,float low,float high,bool use_luma) {
    float weight=max(source.a,max(max(source.r,source.g),source.b));
    if(count>=2 && weight>0.0) {
        vec3 colour=source.rgb/weight;
        float energy=use_luma?dot(colour,vec3(.2126,.7152,.0722)):max(max(colour.r,colour.g),colour.b);
        float position=clamp((energy-low)/max(.00001,high-low),0.0,1.0);
        float u=(.5+position*float(count-1))/float(count);
        source.rgb=texture(ramp,vec2(u,.5)).rgb*weight;
    }
    return source;
}


vec3 native_body_colour(vec3 lit_colour,vec2 cell_uv) {
    if(!native_body_enabled || native_body_strength<=0.0)return lit_colour;
    vec4 surface=texture(native_body_surface,cell_uv);
    surface=finish_native_spell(surface,native_body_ramp,native_body_ramp_count,native_body_ramp_floor,native_body_ramp_ceiling,native_body_ramp_uses_luma);
    // A transparent viewport stores premultiplied colour. Pure additive native
    // materials can carry radiance with zero alpha. Neither changes body alpha.
    vec3 material_colour=surface.a>0.0001?surface.rgb/surface.a:surface.rgb;
    material_colour=mix(material_colour/12.92,pow((material_colour+.055)/1.055,vec3(2.4)),greaterThan(material_colour,vec3(.04045)));
    return mix(lit_colour,material_colour,native_body_strength);
}
#endif


#ifndef BODY_SURFACE_INCLUDED
#define BODY_SURFACE_INCLUDED
// Eight resident surface layers; composition/overflow is explicit in
// body_surfaces.gd. Reconstruct geometry once, preserve each source's own clock.
uniform bool body_surface_enabled=false;
uniform int body_surface_count=0;
uniform sampler2D body_surface_texture[8]:filter_linear,repeat_enable;
uniform vec3 body_surface_primary[8];
uniform vec3 body_surface_secondary[8];
uniform vec3 body_surface_tertiary[8];
uniform float body_surface_scale[8];
uniform float body_surface_strength[8];
uniform float body_surface_clock[8];
uniform vec2 body_surface_noise_scale[8];
uniform vec2 body_surface_scroll[8];
uniform float body_surface_twist[8];
uniform float body_surface_waviness[8];
uniform float body_surface_emission[8];

float body_surface_noise(vec2 uv,int layer) {
    // Same source texture, twist, wave and scroll as aura_sphere.gdshader.
    // The sphere's UV edge mask is replaced by the body's existing alpha.
    uv.x+=sin(uv.y*40.0-body_surface_clock[layer])*0.1*body_surface_waviness[layer];
    vec2 sample_uv=vec2(uv.x-uv.y*body_surface_twist[layer],uv.y)*body_surface_noise_scale[layer]
        +body_surface_clock[layer]*body_surface_scroll[layer];
    return texture(body_surface_texture[layer],sample_uv).r;
}

vec3 apply_body_surface(vec3 colour,vec3 position_world_relative,vec3 normal_world,vec3 view_normal) {
    if(!body_surface_enabled || body_surface_count<=0
        || dot(normal_world,normal_world)<0.0001 || dot(view_normal,view_normal)<0.0001)return colour;
    vec3 n=normalize(normal_world);
    vec3 weights=abs(n);weights*=weights;weights*=weights;
    weights/=max(weights.x+weights.y+weights.z,0.0001);
    for(int layer=0;layer<min(body_surface_count,8);layer++) {
        vec3 p=position_world_relative*body_surface_scale[layer];
        float noise_value=body_surface_noise(p.zy,layer)*weights.x
            +body_surface_noise(p.xz,layer)*weights.y+body_surface_noise(p.xy,layer)*weights.z;
        float coverage=smoothstep(0.5,0.8,noise_value);
        vec3 film=mix(body_surface_secondary[layer],body_surface_primary[layer],coverage);
        // The downward facet colour is independent of camera quarter.
        film=mix(film,body_surface_tertiary[layer],max(0.0,-n.y));
        film*=max(0.0,body_surface_emission[layer]);
        film/=max(1.0,max(film.r,max(film.g,film.b)));
        // Source-over is bounded; stacking does not sum emission into white.
        colour=mix(colour,film,clamp(body_surface_strength[layer]*coverage,0.0,1.0));
    }
    return colour;
}
#endif


uniform bool effect_palette_enabled=false;
uniform vec3 effect_palette[32];
uniform int effect_palette_count=0;
uniform vec2 effect_range=vec2(0.0,1.0);
uniform float effect_gamma=1.0;
uniform float effect_frame=0.0;
uniform bool effect_has_noise=false;
uniform sampler2D effect_noise: filter_nearest,repeat_disable;
uniform vec3 condition_tint=vec3(1.0);
uniform float condition_saturation=1.0;
uniform float condition_brightness=1.0;
uniform float condition_alpha=1.0;
uniform vec2 material_cell_size=vec2(128.0);
uniform float flash_strength=0.0;
uniform vec3 flash_palette[32];
uniform int flash_palette_count=0;
uniform bool flash_has_noise=false;
uniform sampler2D flash_noise:filter_nearest,repeat_disable;
uniform float flash_gamma=1.0;
uniform bool flash_untinted=false;
uniform float flash_frame=0.0;
uniform bool flash_screen_blend=false;
uniform bool condition_film_enabled=false;
uniform sampler2D condition_film:filter_nearest,repeat_disable;
uniform int condition_film_frames=1;
uniform int condition_film_frame=0;
uniform vec3 condition_film_palette[4];
uniform float condition_film_strength=0.0;
uniform float condition_film_gain=0.0;
uniform float condition_film_weight=0.0;
// Both hand magic and receiver feedback use the delivered cell-local material
// pattern. Original component alpha remains the body mask throughout.
float spell_pattern(float value,vec2 cell_uv,sampler2D pattern_texture,float frame) {
    vec2 noise_uv=vec2(cell_uv.x,fract(cell_uv.y-floor(frame*128.0*.05/12.0)/128.0));
    float pattern=clamp((texture(pattern_texture,noise_uv).r*255.0-52.0)/91.0,0.0,1.0);
    return pattern<.10?0.0:clamp(pow(pattern,1.5)*.85+value*.15,0.0,1.0);
}
vec4 character_material(vec4 source,vec2 cell_uv,vec3 untinted_source) {
    vec4 result=source;
    if(effect_palette_enabled && effect_palette_count>0) {
        float luminance=dot(source.rgb,vec3(.2126,.7152,.0722));
        float value=pow(clamp((luminance-effect_range.x)/max(effect_range.y-effect_range.x,1.0/255.0),0.0,1.0),effect_gamma);
        if(effect_has_noise) {
            value=spell_pattern(value,cell_uv,effect_noise,effect_frame);
        }
        result.rgb=effect_palette[min(effect_palette_count-1,int(value*float(effect_palette_count)))];
    } else {
        float value=(result.r+result.g+result.b)/3.0;
        result.rgb=mix(vec3(value),result.rgb,condition_saturation)*condition_tint*condition_brightness;
        result.a*=condition_alpha;
        if(condition_film_enabled) {
            result.rgb=round(clamp(result.rgb,vec3(0.0),vec3(1.0))*255.0)/255.0;
            float scalar=texture(condition_film,vec2(cell_uv.x,(float(condition_film_frame%condition_film_frames)+cell_uv.y)/float(condition_film_frames))).r*255.0/239.0;
            float v=clamp(scalar,0.0,1.0);
            vec3 film=v<.5?mix(condition_film_palette[0],condition_film_palette[1],v*2.0):mix(condition_film_palette[1],condition_film_palette[2],v*2.0-1.0);
            film=floor(film*255.0+.5)/255.0;
            float source_y=floor(cell_uv.y*material_cell_size.y)*128.0/material_cell_size.y;
            float chest=smoothstep(35.0,48.0,source_y)*(1.0-smoothstep(84.0,94.0,source_y));
            float amount=clamp(condition_film_strength*condition_film_gain*chest*(.2+.8*scalar*scalar),0.0,1.0);
            result.rgb*=mix(vec3(1.0),condition_film_palette[3],condition_film_strength*condition_film_weight);
            float added_alpha=result.a*amount;
            float combined_alpha=added_alpha+result.a*(1.0-added_alpha);
            result.rgb=combined_alpha>0.0?(film*added_alpha+result.rgb*result.a*(1.0-added_alpha))/combined_alpha:vec3(0.0);
            result.a=combined_alpha;
        }
        if(!native_body_enabled && flash_strength>0.0 && flash_palette_count>0) {
            vec3 base=flash_untinted?untinted_source:source.rgb;
            float brightness=pow(clamp(flash_has_noise?dot(base,vec3(.2126,.7152,.0722)):max(base.r,max(base.g,base.b)),0.0,1.0),flash_gamma);
            if(flash_has_noise) brightness=spell_pattern(brightness,cell_uv,flash_noise,flash_frame);
            vec3 painted=flash_palette[min(min(flash_palette_count,32)-1,int(brightness*float(min(flash_palette_count,32))))];
            if(flash_screen_blend) painted=vec3(1.0)-(vec3(1.0)-result.rgb)*(vec3(1.0)-painted);
            result.rgb=mix(result.rgb,painted,flash_strength);
        }
    }
    return result;
}


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

ALBEDO = weapon_material_colour(ALBEDO, UV);
ALPHA *= weapon_material_alpha();
}

