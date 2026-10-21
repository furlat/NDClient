#[compute]
#version 450
#extension GL_ARB_gpu_shader_fp64 : require

layout(local_size_x=1,local_size_y=1,local_size_z=1) in;
layout(set=0,binding=0,std430) readonly buffer Points { float values[]; } points;
layout(rgba32f,set=0,binding=1) uniform image2D body_frame;
layout(push_constant,std430) uniform Parameters {
	uvec4 counts;
	vec4 centre;
	vec4 normal;
	vec4 axis;
	vec4 bearing;
} parameters;

vec3 source_point(uint index) {
	uint stride = parameters.counts.w == 1u ? 3u : 4u;
	uint offset = index * stride;
	return vec3(points.values[offset], points.values[offset + 1u], points.values[offset + 2u]);
}

float source_dot(vec3 first, vec3 second) {
	precise float x = first.x * second.x;
	precise float y = first.y * second.y;
	precise float z = first.z * second.z;
	precise float xy = x + y;
	return xy + z;
}

vec3 source_normalize(vec3 value) {
	precise float squared = source_dot(value,value);
	if (squared == 0.0) return vec3(0.0);
	float magnitude = float(sqrt(double(squared)));
	return vec3(float(double(value.x)/double(magnitude)),
		float(double(value.y)/double(magnitude)),float(double(value.z)/double(magnitude)));
}

vec3 source_cross(vec3 first, vec3 second) {
	precise vec3 forward = first.yzx * second.zxy;
	precise vec3 reverse = first.zxy * second.yzx;
	return forward - reverse;
}

bool source_zero(vec3 value) {
	return all(lessThan(abs(value),vec3(0.00001)));
}

void orient(inout vec3 principal, inout vec3 transverse) {
	vec3 bearing = vec3(0.0,1.0,0.0);
	if (abs(principal.y)<0.3 && parameters.counts.z!=0u) bearing=parameters.bearing.xyz;
	if (source_dot(principal,bearing)<0.0) {
		principal=-principal;
		transverse=-transverse;
	}
}

void main() {
	if (parameters.counts.y!=0u) {
		if (imageLoad(body_frame,ivec2(3,2)).x<0.5) return;
		vec3 principal=imageLoad(body_frame,ivec2(0,2)).xyz;
		vec3 transverse=imageLoad(body_frame,ivec2(1,2)).xyz;
		orient(principal,transverse);
		imageStore(body_frame,ivec2(0,2),vec4(principal,1.0));
		imageStore(body_frame,ivec2(1,2),vec4(transverse,1.0));
		return;
	}
	precise vec3 first=vec3(0.0);
	precise vec3 second=vec3(0.0);
	precise vec3 third=vec3(0.0);
	for (uint index=0u;index<parameters.counts.x;index++) {
		precise vec3 delta=source_point(index)-parameters.centre.xyz;
		precise vec3 projected=delta-parameters.normal.xyz*source_dot(delta,parameters.normal.xyz);
		first+=projected*projected.x;
		second+=projected*projected.y;
		third+=projected*projected.z;
		imageStore(body_frame,ivec2(index,0),vec4(delta,1.0));
		imageStore(body_frame,ivec2(index,1),vec4(source_point(parameters.counts.x+index),1.0));
	}
	precise vec3 axis=parameters.axis.xyz;
	for (int iteration=0;iteration<12;iteration++) {
		precise vec3 left=first*axis.x;
		precise vec3 middle=second*axis.y;
		precise vec3 right=third*axis.z;
		precise vec3 multiplied=(left+middle)+right;
		if (source_zero(multiplied)) {
			imageStore(body_frame,ivec2(3,2),vec4(0.0));
			return;
		}
		axis=source_normalize(multiplied);
	}
	vec3 principal=axis;
	vec3 ignored=vec3(0.0);
	orient(principal,ignored);
	vec3 transverse=source_normalize(source_cross(parameters.normal.xyz,principal));
	float long_radius=0.04;
	float cross_radius=0.04;
	for (uint index=0u;index<parameters.counts.x;index++) {
		precise vec3 delta=source_point(index)-parameters.centre.xyz;
		long_radius=max(long_radius,abs(source_dot(delta,principal)));
		cross_radius=max(cross_radius,abs(source_dot(delta,transverse)));
	}
	imageStore(body_frame,ivec2(0,2),vec4(principal,1.0));
	imageStore(body_frame,ivec2(1,2),vec4(transverse,1.0));
	imageStore(body_frame,ivec2(2,2),vec4(long_radius,cross_radius,0.0,1.0));
	imageStore(body_frame,ivec2(3,2),vec4(1.0));
}
