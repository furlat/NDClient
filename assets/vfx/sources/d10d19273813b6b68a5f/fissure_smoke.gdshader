shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;
uniform sampler2D noise_tex:repeat_enable,filter_linear;
uniform sampler2D detail_tex:repeat_enable,filter_linear;
uniform float radial=.89;
uniform float seed=0.;
void vertex(){
 float rise=smoothstep(.02,.42,TIME-.015-radial*.30);
 VERTEX.y=.06+(VERTEX.y-.06)*rise;
}
void fragment(){
 float local_age=TIME-.015-radial*.30;
 float n=texture(noise_tex,vec2(UV.x*1.4+seed,UV.y*1.5-TIME*.30)).r;
 float fine=texture(detail_tex,UV*vec2(2.,3.)+vec2(seed,-TIME*.18)).r;
 float width=pow(max(0.,sin(UV.x*3.14159265)),1.25);
 float top=(1.-smoothstep(.35,1.,UV.y));
 float forming=smoothstep(0.,.15,local_age);
 float fade=1.-smoothstep(1.10,1.75,TIME);
 float wisps=smoothstep(.25,.58,n*.78+fine*.22);
 vec3 charcoal=vec3(.065,.025,.031);vec3 ash=vec3(.21,.10,.12);
 float embers=(.30+.70*smoothstep(.38,.70,n))*pow(1.-UV.y,1.25);
 ALBEDO=mix(charcoal,ash,wisps*.7);
 EMISSION=vec3(.42,.070,.040)*embers*.85;
 ALPHA=width*top*wisps*.85*forming*fade;
}
