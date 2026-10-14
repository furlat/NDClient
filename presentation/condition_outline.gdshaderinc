uniform sampler2D assembled:filter_nearest,repeat_disable;
uniform sampler2D pulse_mask:filter_nearest,repeat_disable;
uniform vec4 contour_colour:source_color;
uniform vec4 pulse_colour:source_color;
uniform float alpha_threshold=0.392156863;
uniform float opacity=.55;
uniform float pulse_opacity=.75;
uniform float age_ms=0.0;
uniform float period_ms=1400.0;
uniform float onset_ms=300.0;
uniform bool initialized=false;
uniform float fade_alpha=1.0;
vec4 condition_outline_colour(vec2 uv){
    vec2 size=vec2(textureSize(assembled,0));vec2 pixel=1.0/size;
    float a=texture(assembled,uv).a;
    bool occupied=a>=alpha_threshold;
    bool inside=texture(assembled,uv+vec2(pixel.x,0.0)).a>=alpha_threshold && texture(assembled,uv-vec2(pixel.x,0.0)).a>=alpha_threshold && texture(assembled,uv+vec2(0.0,pixel.y)).a>=alpha_threshold && texture(assembled,uv-vec2(0.0,pixel.y)).a>=alpha_threshold;
    float beat=pow(max(0.0,sin(max(0.0,age_ms)*6.28318530718/period_ms)),6.0);
    float onset=initialized?0.0:max(0.0,1.0-age_ms/onset_ms);
    float edge=occupied && !inside?min(1.0,opacity+.4*beat):0.0;
    float pulse=texture(pulse_mask,uv).r>.5?min(a,round(pulse_opacity*max(beat,onset)*255.0)/255.0):0.0;
    float alpha=edge+pulse*(1.0-edge);
    vec3 colour=alpha>0.0?(pulse_colour.rgb*pulse+contour_colour.rgb*edge*(1.0-pulse))/alpha:vec3(0.0);
    return vec4(colour,alpha*fade_alpha);
}
