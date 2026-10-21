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


render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never, depth_test_disabled;
// Modular actor layer, lit in its own pass with the receiving rules of the
// former light atlas: each cell texel is lit once at its screen centre on the
// painted plane (height 0) from the light table. See lit_receiving.gdshaderinc.
#define CAPPED_MODULAR
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
    // Visibility belongs to the actual layer, including a palette-painted
    // casting layer. Choosing its spell colours must not bypass Hidden alpha.
    result.a*=condition_alpha;
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

vec4 modular_source_colour(vec2 uv) {
    vec4 colour = texture(sheet, frame_uv.xy + uv * frame_uv.zw);
    vec3 untinted = colour.rgb;
    colour.rgb *= tint;
    if(!shadow) colour=character_material(colour,uv,untinted);
    return vec4(shadow ? vec3(0.0) : colour.rgb, colour.a * layer_alpha);
}

// The light atlas's receiving and storage, evaluated in the sprite's own pass.
// A source texel is lit once, at its screen centre on the painted plane, by the
// light table; the result then takes the former atlas storage (RGBA16F with the
// light cap, RGBA8 without) and the former output shader's decode and transfer,
// so the picture is the one the light atlas produced.
// Native PointLight2D receiving (Godot 4.7.2 canvas.glsl, lights without
// shadows or light() code), for one painted-plane point p in viewport pixels at
// height 0 with canvas normal n (x right, y down, z toward the camera). Rows
// come from presentation/light_table.gd; the operation order follows canvas.glsl.
// Receivers read the cookie with their own NEAREST sampler; outside [0,1) is unlit.
global uniform sampler2D light_table;
global uniform int light_count;
global uniform sampler2DArray light_cookies;

// base is the receiver colour (white when storing irradiance), ambient the
// CanvasModulate value as the canvas shader sees it.
vec3 table_light(vec2 p, vec3 n, vec3 base, float ambient) {
    vec3 colour = base * ambient;
    ivec2 cookie_size = textureSize(light_cookies, 0).xy;
    for (int i = 0; i < light_count; i++) {
        vec4 table_colour = texelFetch(light_table, ivec2(3, i), 0);
        if (table_colour.a > 0.5) {
            vec4 direction = texelFetch(light_table, ivec2(0, i), 0);
            vec3 light_vec = normalize(mix(vec3(direction.xy, 0.0), vec3(0.0, 0.0, 1.0), direction.z));
            colour += table_colour.rgb * base * max(0.0, dot(n, light_vec)) * direction.w;
            continue;
        }
        vec4 table_m = texelFetch(light_table, ivec2(1, i), 0);
        vec4 table_k = texelFetch(light_table, ivec2(2, i), 0);
        vec2 table_uv = (vec4(p, 0.0, 1.0) * mat4(vec4(table_m.x, table_m.y, 0.0, table_m.z), vec4(table_m.w, table_k.x, 0.0, table_k.y), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0))).xy;
        if (any(lessThan(table_uv, vec2(0.0))) || any(greaterThanEqual(table_uv, vec2(1.0)))) continue;
        vec4 table_at = texelFetch(light_table, ivec2(0, i), 0);
        vec4 table_cookie = texelFetch(light_cookies, ivec3(ivec2(table_uv * vec2(cookie_size)), int(table_k.z)), 0);
        table_cookie.rgb *= table_colour.rgb * table_at.w;
        float lambert = max(0.0, dot(n, normalize(table_at.xyz - vec3(p, 0.0))));
        table_cookie.rgb = table_cookie.rgb * base * lambert;
        colour += table_cookie.rgb * table_cookie.a;
    }
    return colour;
}

// CanvasModulate as the receiving canvas saw it: 0.30, converted under HDR.
global uniform float light_ambient;
// 0: LDR storage, per-channel clamp. Otherwise the brightest-channel cap.
global uniform float light_cap;
// Normals view: receiving normals, unshaded, LDR; shadow and flame roles omitted.
global uniform bool light_normals;
uniform vec2 source_quad_size = vec2(1.0);
uniform float wall_opacity : hint_range(0.0, 1.0) = 1.0;
uniform bool wall_mask_enabled = false;
uniform int wall_mask_id = 0;
uniform sampler2D wall_mask_texture : filter_nearest, repeat_disable;
varying vec2 source_screen_origin;
varying vec2 source_screen_axis_x;
varying vec2 source_screen_axis_y;

vec2 lit_projected_uv(mat4 projection, vec3 at) {
    vec4 projected = projection * vec4(at, 1.0);
    return projected.xy / projected.w * 0.5 + 0.5;
}

// Screen placement of the quad's UV square, for texel-centre positions:
// columns are the screen origin and the two axes, in screen UV.
mat3 lit_screen_quad(vec3 vertex, vec2 uv, mat4 modelview_projection) {
    vec3 top_left = vertex - vec3(uv.x * source_quad_size.x, -uv.y * source_quad_size.y, 0.0);
    vec2 screen_origin = lit_projected_uv(modelview_projection, top_left);
    vec2 axis_x = lit_projected_uv(modelview_projection, top_left + vec3(source_quad_size.x, 0.0, 0.0)) - screen_origin;
    vec2 axis_y = lit_projected_uv(modelview_projection, top_left - vec3(0.0, source_quad_size.y, 0.0)) - screen_origin;
    return mat3(vec3(screen_origin, 0.0), vec3(axis_x, 0.0), vec3(axis_y, 0.0));
}

vec2 lit_texel_uv(vec2 uv, vec2 texels) {
    return (floor(uv * texels) + 0.5) / texels;
}

vec2 lit_screen_uv(vec2 texel_uv) {
    return source_screen_origin + texel_uv.x * source_screen_axis_x + texel_uv.y * source_screen_axis_y;
}

// Rows are world right, screen-down, toward-camera.
mat3 lit_world_to_canvas(mat4 inverse_view) {
    return transpose(mat3(inverse_view[0].xyz, -inverse_view[1].xyz, inverse_view[2].xyz));
}

bool lit_hdr() {
    return light_cap > 0.0 && !light_normals;
}

float lit_half(float value) {
    return unpackHalf2x16(packHalf2x16(vec2(value, 0.0))).x;
}

vec3 lit_half3(vec3 value) {
    return vec3(lit_half(value.r), lit_half(value.g), lit_half(value.b));
}

vec3 lit_byte3(vec3 value) {
    return unpackUnorm4x8(packUnorm4x8(vec4(value, 1.0))).rgb;
}

float lit_stored_alpha(float alpha) {
    return lit_hdr() ? lit_half(alpha) : unpackUnorm4x8(packUnorm4x8(vec4(alpha))).a;
}

vec3 lit_encoded_to_linear(vec3 value) {
    return mix(pow((value + vec3(0.055)) / 1.055, vec3(2.4)), value / 12.92, lessThanEqual(value, vec3(0.04045)));
}

// A colour the atlas stored without lighting (shadow role, flames, Normals).
vec3 lit_unlit(vec3 encoded) {
    return lit_encoded_to_linear(lit_byte3(lit_hdr() ? lit_half3(encoded) : encoded));
}

// Atlas receiving at one texel: p in viewport pixels, n the canvas normal,
// source the encoded receiver colour. Returns linear colour.
vec3 lit_received(vec3 source, vec2 p, vec3 n) {
    if (lit_hdr()) {
        vec3 irradiance = max(lit_half3(table_light(p, n, vec3(1.0), light_ambient)), vec3(0.0));
        float peak = max(irradiance.r, max(irradiance.g, irradiance.b));
        float gain = peak > light_cap ? light_cap / peak : 1.0;
        vec3 encoded = clamp(source * irradiance * gain, vec3(0.0), vec3(1.0));
        return lit_encoded_to_linear(lit_byte3(encoded));
    }
    return lit_encoded_to_linear(lit_byte3(table_light(p, n, source, light_ambient)));
}

// Godot 4.7.2 Compatibility scene.glsl converts even unshaded ALBEDO with
// tonemap_inc.glsl's approximate cubic, then its power-based sRGB encode.
// Invert that engine transfer. Four Newton steps invert the monotone cubic.
// https://github.com/godotengine/godot/blob/4.7.2-stable/drivers/gles3/shaders/tonemap_inc.glsl
vec3 lit_encoded_for_spatial(vec3 encoded) {
    vec3 target = pow((encoded + vec3(0.055)) / 1.055, vec3(2.4));
    vec3 value = min(encoded + vec3(0.03), vec3(1.0));
    for (int i = 0; i < 4; i++) {
        vec3 cubic = value * (value * (value * 0.305306011 + 0.682171111) + 0.012522878);
        vec3 derivative = value * (value * 0.915918033 + 1.364342222) + 0.012522878;
        value -= (cubic - target) / derivative;
    }
    return mix(value, vec3(0.0), equal(encoded, vec3(0.0)));
}

vec3 lit_albedo(vec3 colour, bool output_is_srgb) {
    return output_is_srgb ? lit_encoded_for_spatial(colour) : colour;
}

// Only the front-most faded wall shows: erase where a later faded wall's mask
// surrounds this pixel; keep the boundary to avoid holes.
bool lit_wall_masked(vec2 screen_uv) {
    if (!wall_mask_enabled || wall_opacity >= 1.0) return false;
    vec4 owner = texture(wall_mask_texture, screen_uv);
    ivec3 bytes = ivec3(round(owner.rgb * 255.0));
    int later = bytes.r + (bytes.g << 8) + (bytes.b << 16);
    if (owner.a <= 0.5 || later <= wall_mask_id) return false;
    ivec2 dimensions = textureSize(wall_mask_texture, 0);
    ivec2 at = ivec2(screen_uv * vec2(dimensions));
    for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
        vec4 value = texelFetch(wall_mask_texture, clamp(at + ivec2(x, y), ivec2(0), dimensions - 1), 0);
        ivec3 b = ivec3(round(value.rgb * 255.0));
        if (value.a <= 0.5 || b.r + (b.g << 8) + (b.b << 16) <= wall_mask_id) return false;
    }
    return true;
}

// Native component packet: linear RGB normals + affine byte depth, with
// independent validity masks. It is not the environment RG16/oct packet.
// Opt-in spatial receiver coordinates for native scene effects. The existing
// Canvas atlas still owns colour, normals, opacity and the painted raster.
uniform bool native_scene_enabled = false;
uniform bool native_scene_plane = false;
uniform vec2 native_scene_pivot = vec2(64.0, 96.0);
uniform float native_scene_ground_height = 0.0;
uniform bool has_component_geometry = false;
uniform sampler2D component_depth : filter_nearest, repeat_disable;
uniform sampler2D component_support : filter_nearest, repeat_disable;
uniform sampler2D component_normal : filter_nearest, repeat_disable;
uniform sampler2D component_normal_valid : filter_nearest, repeat_disable;
uniform float component_scale_x = 1.0;
uniform vec2 component_depth_range;
uniform float component_units = 0.0;
uniform vec2 component_reconstruction_origin;
uniform float component_elevation;
#ifndef CAPPED_MODULAR
uniform vec4 frame_uv;
uniform vec2 material_cell_size = vec2(128.0);
#endif
varying mat3 native_scene_model_basis;

bool native_scene_receiver(vec2 source_uv, vec3 painted_view, mat4 view, mat4 inverse_view,
        vec3 world_origin, out vec3 point) {
    vec3 toward_camera = inverse_view[2].xyz;
    if (abs(toward_camera.y) < 0.00001) return false;
    if (native_scene_plane) {
        // The current production camera is orthographic. Intersect its ray,
        // not the upright painted quad, with this admitted floor's elevation.
        float z = (world_origin.y-inverse_view[3].y
            - inverse_view[0].y*painted_view.x-inverse_view[1].y*painted_view.y)/toward_camera.y;
        point = vec3(painted_view.xy, z);
        return true;
    }
    if (!has_component_geometry || component_units <= 0.0) return false;
    vec2 pixel = floor(source_uv * material_cell_size) + vec2(0.5);
    vec2 uv = frame_uv.xy + pixel / material_cell_size * frame_uv.zw;
    vec4 depth = texture(component_depth, uv);
    if (depth.a <= 0.5 || texture(component_support, uv).r <= 0.5) return false;
    float d = component_depth_range.x + (depth.r*255.0-32.0)
        * (component_depth_range.y-component_depth_range.x)/192.0;
    float height = ((component_reconstruction_origin.y-pixel.y)*cos(component_elevation)
        + d*sin(component_elevation))*component_units;
    // Native scene geometry uses the packet's actual optical height above its
    // authored ground. Shadow-caster compression is a separate presentation.
    height -= native_scene_ground_height;
    vec3 local = vec3(pixel.x-native_scene_pivot.x, native_scene_pivot.y-pixel.y, 0.0)*component_units;
    vec3 painted = mat3(inverse_view)*local;
    local.z = (height-painted.y)/toward_camera.y;
    // The sampled model basis already includes mirror and passage deformation;
    // apply it once, retaining the displayed origin and airborne lift.
    point = (view*vec4(world_origin + native_scene_model_basis*local, 1.0)).xyz;
    return true;
}

uniform float authored_base_light = 1.0;
uniform bool calibrated_component_receiver = true;
uniform bool use_component_depth = true;
uniform bool use_component_normals = true;
// Exact authored lower aperture lip, evaluated on the unchanged painted body.
// It is unrelated to native receiver/ray depth and never rewrites source pixels.
uniform bool body_aperture_enabled = false;
uniform bool body_aperture_diamond = false;
uniform vec3 body_aperture_center;
uniform vec3 body_aperture_x;
uniform vec3 body_aperture_y;
varying vec3 source_world_origin;
void vertex() {
    source_world_origin = MODEL_MATRIX[3].xyz;
    native_scene_model_basis = mat3(MODEL_MATRIX);
    mat3 screen = lit_screen_quad(VERTEX, UV, PROJECTION_MATRIX * MODELVIEW_MATRIX);
    source_screen_origin = screen[0].xy; source_screen_axis_x = screen[1].xy; source_screen_axis_y = screen[2].xy;
}
void fragment() {
    if (body_aperture_enabled) {
        if (shadow) { discard; }
        vec3 relative = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz - body_aperture_center;
        float x = abs(dot(relative, body_aperture_x));
        float lip = body_aperture_diamond ? 1.0-x : sqrt(max(0.0, 1.0-x*x));
        if (-dot(relative, body_aperture_y) > lip) { discard; }
    }
    // Animated sheets keep one authored cell; texels snap to that cell grid.
    vec2 texel = lit_texel_uv(UV, material_cell_size);
    vec4 colour = modular_source_colour(texel);
    if (colour.a <= 0.0) { discard; }
    float alpha = lit_stored_alpha(colour.a);
    if (alpha <= 0.0 || wall_opacity <= 0.0) { discard; }
    vec2 source_uv = frame_uv.xy + texel * frame_uv.zw;
    vec3 n = vec3(0.0, 0.0, 1.0);
    if (has_component_geometry && !shadow && use_component_normals && abs(component_scale_x) > 0.00001) {
        vec4 depth = texture(component_depth, source_uv);
        vec4 normal = texture(component_normal, source_uv);
        bool valid = texture(component_support, source_uv).r > 0.5
            && texture(component_normal_valid, source_uv).r > 0.5
            && depth.a > 0.5 && normal.a > 0.5;
        if (valid) {
            // All RGB channels are linear numeric data; facing is already
            // baked. Inverse horizontal component scale applies exactly once.
            n = normal.rgb * 2.0 - 1.0;
            n = normalize(vec3(n.x / component_scale_x, n.y, n.z));
        }
    }
    vec3 canvas_normal = vec3(n.x, -n.y, n.z);
    if (light_normals) {
        if (shadow) { discard; }
        colour.rgb = lit_unlit(canvas_normal * 0.5 + 0.5);
    } else if (shadow) {
        colour.rgb = lit_unlit(colour.rgb);
    } else {
        colour.rgb = lit_received(colour.rgb, lit_screen_uv(texel) * VIEWPORT_SIZE, canvas_normal);
    }
    if (body_surface_enabled && body_surface_count > 0 && has_component_geometry) {
        vec3 surface_point;
        vec4 packet_normal = texture(component_normal, source_uv);
        if (packet_normal.a > .5 && texture(component_normal_valid, source_uv).r > .5
            && native_scene_receiver(texel, VERTEX, VIEW_MATRIX, INV_VIEW_MATRIX, source_world_origin, surface_point)) {
            vec3 sn = packet_normal.rgb * 2.0 - 1.0;
            sn = normalize(vec3(sn.x / (abs(component_scale_x) > .00001 ? component_scale_x : 1.0), sn.y, sn.z));
            vec3 horizontal = normalize(vec3(INV_VIEW_MATRIX[2].x, 0.0, INV_VIEW_MATRIX[2].z));
            vec3 up = vec3(0.0, cos(component_elevation), 0.0) - horizontal * sin(component_elevation);
            vec3 toward = horizontal * cos(component_elevation) + vec3(0.0, sin(component_elevation), 0.0);
            vec3 normal_world = normalize(mat3(INV_VIEW_MATRIX[0].xyz, up, toward) * sn);
            vec3 relative = (INV_VIEW_MATRIX * vec4(surface_point, 1.0)).xyz - source_world_origin;
            colour.rgb = apply_body_surface(colour.rgb, relative, normal_world, normalize(mat3(VIEW_MATRIX) * normal_world));
        }
    }
    colour.rgb = native_body_colour(colour.rgb, texel);
    ALBEDO = lit_albedo(colour.rgb, OUTPUT_IS_SRGB);
    ALPHA = alpha * wall_opacity;
    if (native_scene_enabled) {
        vec3 receiver;
        if (native_scene_receiver(texel, VERTEX, VIEW_MATRIX, INV_VIEW_MATRIX, source_world_origin, receiver)) {
            LIGHT_VERTEX = receiver;
        }
    }

ALBEDO = weapon_material_colour(ALBEDO, texel);
ALPHA *= weapon_material_alpha();
}

