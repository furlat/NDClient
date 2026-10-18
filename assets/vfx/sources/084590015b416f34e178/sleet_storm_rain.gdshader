shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;
varying float fall;
varying float ice;
void vertex(){
 float p=fract(weather_clock*INSTANCE_CUSTOM.y*.5+INSTANCE_CUSTOM.x);
 fall=p;ice=INSTANCE_CUSTOM.z;
 VERTEX.y+=4.*(1.-p);
 VERTEX.x+=(.5-p)*.75;
 VERTEX.z+=(.5-p)*.18;
}
void fragment(){
 float stroke=smoothstep(0.,.22,UV.x)*(1.-smoothstep(.78,1.,UV.x));
 float end=smoothstep(0.,.15,UV.y)*(1.-smoothstep(.65,1.,UV.y));
 float fade=smoothstep(0.,.03,fall)*(1.-smoothstep(.92,1.,fall));
 ALBEDO=mix(vec3(.22,.40,.54),vec3(.62,.77,.83),ice);
 ALPHA=stroke*end*fade*.76;
}

