shader_type spatial;render_mode unshaded,cull_disabled,depth_draw_never;
uniform sampler2D mask_tex;uniform sampler2D noise_tex:repeat_enable,filter_linear;
void fragment(){float m=texture(mask_tex,UV).r;float n=texture(noise_tex,UV*2.+vec2(-cold_age*1.6,cold_age*.2)).r;float dissolve=smoothstep(.18,.5,n)*m;
 ALBEDO=mix(vec3(.25,.60,.77),vec3(.69,.88,.91),dissolve);ALPHA=dissolve*.72;}

