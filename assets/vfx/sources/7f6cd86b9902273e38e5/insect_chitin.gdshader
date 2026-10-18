shader_type spatial;
render_mode unshaded,cull_disabled;
uniform vec4 chitin_color:source_color=vec4(.2,.2,.1,1.0);
void fragment(){
 vec3 world_normal=normalize((INV_VIEW_MATRIX*vec4(NORMAL,0.0)).xyz);
 float facet=.48+.52*max(0.0,dot(world_normal,normalize(vec3(-.4,.8,.6))));
 ALBEDO=chitin_color.rgb*facet;
}
