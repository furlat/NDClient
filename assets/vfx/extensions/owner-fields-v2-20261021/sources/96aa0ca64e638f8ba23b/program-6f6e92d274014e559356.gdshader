shader_type spatial;
global uniform sampler2D vfx_package_clock;
uniform int vfx_package_clock_slot=0;
float vfx_package_seconds(){return texelFetch(vfx_package_clock,ivec2(vfx_package_clock_slot,0),0).r;}
uniform float vfx_package_offset_weather_clock=0.0;
uniform float vfx_package_offset_weather_age=0.0;

uniform mat4 factory_world_to_source=mat4(1.0);
uniform sampler2D owner_cells : filter_nearest, repeat_disable;
uniform ivec2 owner_mask_origin = ivec2(0);

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
ivec2 owner_cell=ivec2(floor(wp.xz+vec2(0.5)))-owner_mask_origin;
ivec2 owner_size=textureSize(owner_cells,0);
if(any(lessThan(owner_cell,ivec2(0)))||any(greaterThanEqual(owner_cell,owner_size)))discard;
if(texelFetch(owner_cells,owner_cell,0).r<0.5)discard;

if(length(wp.xz)>8.)discard;

 vec2 p=(UV-.5)*16.;float r=length(p);
 float n=texture(noise_tex,UV*3.).r;
 float f=texture(frost,UV*5.+vec2(.14,.38)).r;
 float edge=1.-smoothstep(6.9+n*.8,7.4+n*.6,r);
 float reveal=smoothstep(.15,1.,(vfx_package_seconds()+vfx_package_offset_weather_age));
 float veins=smoothstep(.58,.77,f)*(.18+.2*n);
 ALBEDO=mix(vec3(.10,.27,.40),vec3(.50,.68,.79),veins*1.6);
 ALPHA=edge*(.13+.15*smoothstep(.25,.65,n)+veins)*reveal;

ALPHA*=weather_opacity * smoothstep(0.,.8,(vfx_package_seconds()+vfx_package_offset_weather_age))*(1.-smoothstep(7.0+texture(weather_edge_noise,wp.xz*.23).r*.55,7.55+texture(weather_edge_noise,wp.xz*.23).r*.45,length(wp.xz)));
ALPHA*=mix(1.,smoothstep(.02,.55+texture(weather_edge_noise,wp.xz*.31).r*.60,wp.y)*(1.-smoothstep(2.6,3.266,wp.y)),weather_mist);
}




