shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled, depth_draw_never, depth_test_disabled;
// Reuse production frame/palette/outfit operations. Whole-copy opacity belongs
// after composition; reducing each slot's alpha exposes hidden outfit layers.
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


vec4 modular_source_colour(vec2 uv) {
    vec4 colour = texture(sheet, frame_uv.xy + uv * frame_uv.zw);
    vec3 untinted = colour.rgb;
    colour.rgb *= tint;
    if(!shadow) colour=character_material(colour,uv,untinted);
    return vec4(shadow ? vec3(0.0) : colour.rgb, colour.a * layer_alpha);
}


uniform bool echo_receiving_enabled = false;
uniform sampler2D echo_received : source_color, filter_nearest, repeat_disable;
uniform vec4 echo_receiving_region;
uniform vec4 echo_receiving_crop = vec4(0.0,0.0,1.0,1.0);
uniform float echo_light_cap = 0.0;
vec3 echo_decode(vec3 value) {
    return mix(pow((value+vec3(.055))/1.055,vec3(2.4)),value/12.92,lessThanEqual(value,vec3(.04045)));
}
void fragment() {
    vec4 colour = modular_source_colour(UV);
    if (colour.a <= 0.0) discard;
    vec3 irradiance = vec3(1.0);
    if (echo_receiving_enabled && all(greaterThanEqual(UV,echo_receiving_crop.xy))
            && all(lessThan(UV,echo_receiving_crop.xy+echo_receiving_crop.zw))) {
        vec2 cell_uv = (UV-echo_receiving_crop.xy)/echo_receiving_crop.zw;
        vec4 received = texture(echo_received,echo_receiving_region.xy+cell_uv*echo_receiving_region.zw);
        // Retained source coverage owns an old pose. A later receiving crop must
        // never erase a historical limb or weapon outside that later pose.
        if (received.a > 0.0) irradiance = max(received.rgb,vec3(0.0));
        float peak = max(irradiance.r,max(irradiance.g,irradiance.b));
        if (echo_light_cap > 0.0 && peak > echo_light_cap) irradiance *= echo_light_cap/peak;
    }
    ALBEDO = echo_decode(clamp(colour.rgb*irradiance,vec3(0.0),vec3(1.0)));
    ALPHA = colour.a;
}

