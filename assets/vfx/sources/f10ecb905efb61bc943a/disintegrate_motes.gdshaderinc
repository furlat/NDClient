uniform sampler2D gpu_mote_data : filter_nearest,repeat_disable;
uniform bool gpu_mote_flight = false;
uniform int gpu_mote_offset = 0;
uniform float gpu_mote_age = 0.0;
uniform vec3 gpu_mote_ray_start = vec3(0.0);
uniform vec3 gpu_mote_ray_end = vec3(0.0);
uniform vec2 gpu_mote_camera_sign = vec2(.70710678);
varying flat float gpu_instance_gate;

void gpu_instance_vertex(inout vec3 point,inout vec3 normal,inout vec3 tangent,inout vec3 binormal,int mote_index,out float gate){
	int index=mote_index+gpu_mote_offset;
	vec3 velocity=texelFetch(gpu_mote_data,ivec2(index,1),0).xyz;
	vec3 face=normalize(vec3(gpu_mote_camera_sign.x,.70710678,gpu_mote_camera_sign.y));
	vec3 origin;
	vec3 right;
	vec3 up;
	vec3 forward;
	vec2 size;
	if(gpu_mote_flight){
		float birth=3.72+float(index)/48.0*.38;
		float elapsed=gpu_mote_age-birth;
		gate=elapsed>=0.0&&elapsed<.40?1.0:0.0;
		origin=mix(gpu_mote_ray_start,gpu_mote_ray_end,clamp((birth-3.72)/.38,0.0,1.0))+velocity*elapsed+vec3(0.0,-.6*elapsed*elapsed,0.0);
		right=normalize(cross(normalize(velocity),face));
		up=normalize(cross(face,right));
		forward=face;
		size=vec2(.10,.30)*(1.0+float(index%4)*.2)*(1.0-smoothstep(.12,.40,elapsed));
	}else{
		float elapsed=max(0.0,gpu_mote_age-4.1);
		gate=gpu_mote_age>=4.1&&gpu_mote_age<5.3?1.0:0.0;
		origin=gpu_mote_ray_end+texelFetch(gpu_mote_data,ivec2(index,0),0).xyz+velocity*elapsed;
		forward=-face;
		right=normalize(cross(vec3(0.0,1.0,0.0),forward));
		up=normalize(cross(forward,right));
		size=vec2(.065,.16)*(1.0+float(index%3)*.25);
	}
	mat3 rotation=mat3(right,up,forward);
	point=origin+rotation*vec3(point.x*size.x,point.y*size.y,point.z);
	normal=rotation*normal;
	tangent=rotation*tangent;
	binormal=rotation*binormal;
}
