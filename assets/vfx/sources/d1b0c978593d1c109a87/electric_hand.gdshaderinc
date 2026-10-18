uniform vec3 gpu_hand_origin = vec3(0.0);
vec3 gpu_hand_point(float index,float loop_index) {
	float angle=6.28318530718*index/17.0+electric_clock*8.0;
	return gpu_hand_origin+vec3(cos(angle),sin(angle),sin(angle*2.0)*.4)*(.11+loop_index*.035);
}
void gpu_hand_deform(inout vec3 point,inout vec3 tangent,inout vec4 ribbon_color,inout vec2 source_uv) {
	float index=point.x;
	float loop_index=point.y;
	vec3 before=gpu_hand_point(max(0.0,index-1.0),loop_index);
	vec3 after=gpu_hand_point(min(17.0,index+1.0),loop_index);
	point=gpu_hand_point(index,loop_index);
	tangent=length(after-before)>.0001?normalize(after-before):vec3(0.0,1.0,0.0);
	source_uv.y=index/17.0;
	ribbon_color=vec4(.035*(.55+.45*sin(source_uv.y*3.14159265359))*.5,0.0,0.0,1.0);
}
