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
