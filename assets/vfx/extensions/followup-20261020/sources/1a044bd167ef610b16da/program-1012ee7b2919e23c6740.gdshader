shader_type spatial;
uniform mat4 factory_world_to_source=mat4(1.0);
uniform float weather_clock=0.;
uniform float weather_age=0.;
uniform float weather_opacity=1.;
uniform float weather_mist=0.;
uniform sampler2D weather_edge_noise:repeat_enable,filter_linear;
render_mode unshaded,cull_disabled,depth_draw_never;
uniform sampler2D frost:repeat_enable,filter_linear;
uniform sampler2D noise_tex:repeat_enable,filter_linear;
void fragment(){
vec3 wp=(factory_world_to_source * INV_VIEW_MATRIX * vec4(VERTEX,1.0)).xyz;
if(length(wp.xz)>8.)discard;

 vec2 p=(UV-.5)*16.;float r=length(p);
 float n=texture(noise_tex,UV*3.).r;
 float f=texture(frost,UV*5.+vec2(.14,.38)).r;
 float edge=1.-smoothstep(6.9+n*.8,7.4+n*.6,r);
 float reveal=smoothstep(.15,1.,weather_age)*(1.-smoothstep(3.,4.,weather_age));
 float veins=smoothstep(.58,.77,f)*(.18+.2*n);
 ALBEDO=mix(vec3(.10,.27,.40),vec3(.50,.68,.79),veins*1.6);
 ALPHA=edge*(.13+.15*smoothstep(.25,.65,n)+veins)*reveal;

ALPHA*=weather_opacity * smoothstep(0.,.8,weather_age)*(1.-smoothstep(3.,4.,weather_age))*(1.-smoothstep(7.0+texture(weather_edge_noise,wp.xz*.23).r*.55,7.55+texture(weather_edge_noise,wp.xz*.23).r*.45,length(wp.xz)));
ALPHA*=mix(1.,smoothstep(.02,.55+texture(weather_edge_noise,wp.xz*.31).r*.60,wp.y)*(1.-smoothstep(2.6,3.266,wp.y)),weather_mist);
}





