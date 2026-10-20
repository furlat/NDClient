shader_type spatial;
uniform mat4 factory_world_to_source=mat4(1.0);
uniform float factory_occurrence_alpha=1.0;

render_mode unshaded,cull_back,depth_draw_never,shadows_disabled;
uniform sampler2D authored_noise:repeat_enable,filter_linear;
uniform float clock=0.0;
uniform bool front=true;
void fragment(){
 vec3 w=(factory_world_to_source * INV_VIEW_MATRIX * vec4(VERTEX,1.0)).xyz;
 if(w.y<0.0)discard;
 float dep=dot(w,vec3(.70710678,0,.70710678));
 
 vec3 p=normalize(w);
 float f=0.5*texture(authored_noise,p.xy*1.8+vec2(clock*.02,0.0)).r+0.5*texture(authored_noise,p.zy*2.1+vec2(.31,-clock*.015)).r;
 float detail=texture(authored_noise,p.xz*3.2+vec2(clock*.015,-clock*.025)).r;
 float patches=smoothstep(.38,.64,f)*(.5+.5*smoothstep(.20,.60,detail));
 float edge=pow(1.0-abs(dot(normalize(NORMAL),normalize(VIEW))),1.6);
 float assembly=(1.0-smoothstep(.55,1.0,clock))*smoothstep(0.0,.4,clock);
 float contour=pow(edge,2.5)*smoothstep(.1,.4,f)*assembly;
 float envelope=smoothstep(0.0,.4,clock)*(1.0-smoothstep(3.4,4.0,clock));
 ALBEDO=vec3(.80,.88,.89);
 ALPHA=(patches*(.10+.46*edge)+contour*.18+pow(edge,3.0)*.10)*envelope;

ALPHA *= factory_occurrence_alpha;
}




