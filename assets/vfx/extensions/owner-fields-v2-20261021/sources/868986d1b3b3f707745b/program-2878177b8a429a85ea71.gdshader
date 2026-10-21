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
varying float fall;
varying float ice;
void vertex(){
 float p=fract((vfx_package_seconds()+vfx_package_offset_weather_clock)*INSTANCE_CUSTOM.y*.5+INSTANCE_CUSTOM.x);
 fall=p;ice=INSTANCE_CUSTOM.z;
 VERTEX.y+=4.*(1.-p);
 VERTEX.x+=(.5-p)*.75;
 VERTEX.z+=(.5-p)*.18;
}
void fragment(){
vec3 wp=(factory_world_to_source * INV_VIEW_MATRIX * vec4(VERTEX,1.0)).xyz;
ivec2 owner_cell=ivec2(floor(wp.xz+vec2(0.5)))-owner_mask_origin;
ivec2 owner_size=textureSize(owner_cells,0);
if(any(lessThan(owner_cell,ivec2(0)))||any(greaterThanEqual(owner_cell,owner_size)))discard;
if(texelFetch(owner_cells,owner_cell,0).r<0.5)discard;

if(length(wp.xz)>8.)discard;
if(wp.y<0. || wp.y>3.266)discard;

 float stroke=smoothstep(0.,.22,UV.x)*(1.-smoothstep(.78,1.,UV.x));
 float end=smoothstep(0.,.15,UV.y)*(1.-smoothstep(.65,1.,UV.y));
 float fade=smoothstep(0.,.03,fall)*(1.-smoothstep(.92,1.,fall));
 ALBEDO=mix(vec3(.22,.40,.54),vec3(.62,.77,.83),ice);
 ALPHA=stroke*end*fade*.76;

ALPHA*=weather_opacity * smoothstep(0.,.8,(vfx_package_seconds()+vfx_package_offset_weather_age))*(1.-smoothstep(7.0+texture(weather_edge_noise,wp.xz*.23).r*.55,7.55+texture(weather_edge_noise,wp.xz*.23).r*.45,length(wp.xz)));
ALPHA*=mix(1.,smoothstep(.02,.55+texture(weather_edge_noise,wp.xz*.31).r*.60,wp.y)*(1.-smoothstep(2.6,3.266,wp.y)),weather_mist);
}




