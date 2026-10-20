shader_type spatial;
global uniform sampler2D vfx_package_clock;
uniform int vfx_package_clock_slot=0;
float vfx_package_seconds(){return texelFetch(vfx_package_clock,ivec2(vfx_package_clock_slot,0),0).r;}
uniform float vfx_package_offset_clock=0.0;

render_mode unshaded, cull_disabled, depth_draw_never;
uniform sampler2D flow_noise : repeat_enable, filter_linear;
uniform vec4 deep : source_color;
uniform vec4 energy : source_color;
uniform float clock = 0.;
uniform float envelope = 1.;
uniform float emission_strength = .14;
uniform float opacity_scale = 1.;
uniform bool ambient_shadow = false;
void fragment(){
 vec2 p=(UV-.5)*2.;
 float radius=length(p);
 float angle=atan(p.y,p.x);
 vec2 flow=vec2(angle/6.28318*3.-(vfx_package_seconds()+vfx_package_offset_clock)*.09,radius*1.4-(vfx_package_seconds()+vfx_package_offset_clock)*.025);
 if(ambient_shadow)flow=UV*2.2+vec2((vfx_package_seconds()+vfx_package_offset_clock)*.018,-(vfx_package_seconds()+vfx_package_offset_clock)*.012);
 float n=texture(flow_noise,flow).r;
 float n2=texture(flow_noise,UV*2.2+vec2((vfx_package_seconds()+vfx_package_offset_clock)*.03,-(vfx_package_seconds()+vfx_package_offset_clock)*.02)).r;
 float area=(1.-smoothstep(.82,.99,radius))*(.09+.20*n*n2);
 float current=smoothstep(.24,.72,n)*(.3+.7*smoothstep(.1,.9,radius));
 ALBEDO=mix(deep.rgb,energy.rgb,current);
 EMISSION=energy.rgb*current*emission_strength;
 ALPHA=area*envelope*opacity_scale;
}

