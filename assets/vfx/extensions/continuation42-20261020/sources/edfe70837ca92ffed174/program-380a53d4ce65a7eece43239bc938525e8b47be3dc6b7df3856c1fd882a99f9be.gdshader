shader_type spatial;
global uniform sampler2D vfx_package_clock;
uniform int vfx_package_clock_slot=0;
float vfx_package_seconds(){return texelFetch(vfx_package_clock,ivec2(vfx_package_clock_slot,0),0).r;}
uniform float vfx_package_offset_age=0.0;

uniform mat4 factory_world_to_source=mat4(1.0);
render_mode cull_disabled;
uniform sampler2D noise_tex:repeat_enable;
uniform float age=0.;uniform float env=1.;
void fragment(){vec3 wp=(factory_world_to_source * INV_VIEW_MATRIX * vec4(VERTEX,1.0)).xyz;if(wp.y<.045)discard;
 float n=texture(noise_tex,UV*11.).r;
 float flow=1.-smoothstep(.02,.09,abs(sin(UV.y*35.-(vfx_package_seconds()+vfx_package_offset_age)*10.+n*5.)));
 ALBEDO=vec3(.42+.08*n);ROUGHNESS=.70;METALLIC=0.;
 EMISSION=vec3(.46)*flow*(.25+.75*smoothstep(.5,1.1,(vfx_package_seconds()+vfx_package_offset_age)));
 float seam=pow(1.-abs(dot(normalize(NORMAL),normalize(VIEW))),5.);
 EMISSION+=vec3(.35)*seam*(.5+.5*sin((vfx_package_seconds()+vfx_package_offset_age)*8.));
 ALPHA=env*smoothstep(-.1,.12,n+env-.8);
}


