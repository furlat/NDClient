// Archived pack.py: RGBA8 source capture, linear unpremultiplication, encoded
// channel mean, alpha-weighted 2x2 blocks in centre128 crop, nearest neutral.
uniform sampler2D factory_rage_film_surface:filter_nearest,repeat_disable;
uniform float factory_rage_film_strength=0.0;
uniform float factory_rage_film_age=0.0;
vec2 factory_film_energy(vec2 pixel) {
    vec4 raw=floor(clamp(texture(factory_rage_film_surface,(pixel+vec2(.5))/384.0),vec4(0.0),vec4(1.0))*255.0+.5)/255.0;
    vec3 linear=mix(raw.rgb/12.92,pow((raw.rgb+.055)/1.055,vec3(2.4)),greaterThan(raw.rgb,vec3(.04045)));
    linear=clamp(linear/max(raw.a,1.0/255.0),vec3(0.0),vec3(1.0));
    vec3 encoded=mix(linear*12.92,1.055*pow(linear,vec3(1.0/2.4))-.055,greaterThan(linear,vec3(.0031308)));
    return vec2(dot(encoded,vec3(1.0/3.0))*255.0*raw.a,raw.a);
}
float factory_film_scalar(vec2 cell_uv) {
    vec2 block=floor(clamp(cell_uv,vec2(0.0),vec2(.999999))*128.0/2.0)*2.0+vec2(128.0);
    vec2 sums=factory_film_energy(block)+factory_film_energy(block+vec2(1.0,0.0))+factory_film_energy(block+vec2(0.0,1.0))+factory_film_energy(block+vec2(1.0));
    float energy=sums.y>0.0?sums.x/sums.y:0.0;
    float levels[8]={26.0,49.0,78.0,109.0,143.0,177.0,211.0,239.0};
    float nearest=levels[0];
    float distance=abs(energy-nearest);
    for(int i=1;i<8;i++) {
        float candidate=abs(energy-levels[i]);
        if(candidate<distance) { nearest=levels[i]; distance=candidate; }
    }
    return nearest/239.0;
}
