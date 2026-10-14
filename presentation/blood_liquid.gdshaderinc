// Existing game_obsolete/surface_residue.py liquid artwork. All noise is in
// common world coordinates so adjacent server-clipped tiles retain one shape.
float blood_random(ivec2 p,uint seed){uint n=(uint(p.x)+uint(p.y)*4099u+seed*65537u+101u)*1597334677u;n^=n>>16u;return float(n*2246822519u)/4294967296.;}
float blood_noise(vec2 p,uint seed){ivec2 i=ivec2(floor(p));vec2 u=fract(p);u=u*u*(3.-2.*u);return mix(mix(blood_random(i,seed),blood_random(i+ivec2(1,0),seed),u.x),mix(blood_random(i+ivec2(0,1),seed),blood_random(i+ivec2(1,1),seed),u.x),u.y);}
vec4 blood_liquid(float field,vec2 world){
    vec2 w=world*64.;float n=blood_noise(w/9.,0u),fine=blood_noise(w/2.8,3u);
    field*=.72+n*.65;float threshold=.13+(fine-.5)*.045;
    float depth=clamp((field-threshold)*1.6,0.,1.);float rim=max(0.,1.-depth*5.);
    float wet=blood_noise(w/vec2(17.,13.),9u);
    float hi=float(depth>.12&&depth<.5&&wet>.66&&blood_noise(w/4.,8u)>.56);
    vec3 colour=round(vec3(88.-38.*depth+rim*24.+(n-.5)*27.+hi*37.,8.-3.*depth+hi*10.,15.-5.*depth+hi*9.))/255.;
    float alpha=field>=threshold?round(min(246.,120.+depth*150.))/255.:0.;
    return vec4(colour,alpha);
}
