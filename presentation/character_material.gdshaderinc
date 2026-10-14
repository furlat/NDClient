// Ordinary outfit tint is applied by the caller. These are explicit authored
// effect/condition operations; the native receiving/output passes share them.
uniform bool effect_palette_enabled=false;
uniform vec3 effect_palette[16];
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
uniform vec3 flash_palette[16];
uniform int flash_palette_count=0;
uniform bool condition_film_enabled=false;
uniform sampler2D condition_film:filter_nearest,repeat_disable;
uniform int condition_film_frames=1;
uniform int condition_film_frame=0;
uniform vec3 condition_film_palette[4];
uniform float condition_film_strength=0.0;
uniform float condition_film_gain=0.0;
uniform float condition_film_weight=0.0;
vec4 character_material(vec4 source,vec2 cell_uv) {
    vec4 result=source;
    if(effect_palette_enabled && effect_palette_count>0) {
        float luminance=dot(source.rgb,vec3(.2126,.7152,.0722));
        float value=pow(clamp((luminance-effect_range.x)/max(effect_range.y-effect_range.x,1.0/255.0),0.0,1.0),effect_gamma);
        if(effect_has_noise) {
            vec2 noise_uv=vec2(cell_uv.x,fract(cell_uv.y-floor(effect_frame*128.0*.05/12.0)/128.0));
            float pattern=clamp((texture(effect_noise,noise_uv).r*255.0-52.0)/91.0,0.0,1.0);
            value=pattern<.10?0.0:clamp(pow(pattern,1.5)*.85+value*.15,0.0,1.0);
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
        if(flash_strength>0.0 && flash_palette_count>0) {
            float brightness=clamp(max(result.r,max(result.g,result.b)),0.0,1.0);
            vec3 painted=flash_palette[min(flash_palette_count-1,int(brightness*float(flash_palette_count)))];
            result.rgb=mix(result.rgb,painted,flash_strength);
        }
    }
    return result;
}
