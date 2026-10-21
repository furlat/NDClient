#[compute]
#version 450
#extension GL_ARB_gpu_shader_fp64 : require

// One immutable actual-pose resolution, not a per-frame vertex search.
layout(local_size_x = 13, local_size_y = 1, local_size_z = 1) in;
layout(set=0,binding=0,std430) readonly buffer Points { vec4 values[]; } points;
layout(set=0,binding=1,std430) readonly buffer Coordinates { dvec2 values[]; } coordinates;
layout(set=0,binding=2,std430) readonly buffer Queries { dvec2 values[]; } queries;
layout(set=0,binding=3,std430) readonly buffer Clearances { float values[]; } clearances;
layout(rgba32f,set=0,binding=4) uniform writeonly image2D station_image;
layout(set=0,binding=5,std430) writeonly buffer Neighbours { uvec4 values[]; } neighbours;
layout(set=0,binding=6,std430) writeonly buffer Diagnostics { double values[]; } diagnostics;
layout(push_constant,std430) uniform Parameters { uvec4 counts; vec4 origin; } parameters;

float source_divide(float numerator, float denominator) {
	// The source performs native real_t division, not a shader fast reciprocal.
	return float(double(numerator) / double(denominator));
}

vec3 source_normalize(vec3 value) {
	precise float xx = value.x * value.x;
	precise float yy = value.y * value.y;
	precise float zz = value.z * value.z;
	precise float xy = xx + yy;
	precise float squared = xy + zz;
	if (squared == 0.0) return vec3(0.0);
	float length_value = float(sqrt(double(squared)));
	return vec3(source_divide(value.x,length_value), source_divide(value.y,length_value), source_divide(value.z,length_value));
}

void main() {
	uint station = gl_GlobalInvocationID.x;
	uint curve = gl_GlobalInvocationID.y;
	if (station >= 13u || curve >= parameters.counts.y) return;
	uint query_index = curve * 13u + station;
	dvec2 query = queries.values[query_index];
	double best[4];
	uint selected[4];
	for (int index=0;index<4;index++) { best[index]=1.0e300LF; selected[index]=0u; }
	uint admitted = 0u;
	for (uint index=0u;index<parameters.counts.x;index++) {
		precise double dx = coordinates.values[index].x - query.x;
		precise double dy = coordinates.values[index].y - query.y;
		// Original scalar pow(x,2) is checked against these actual f64 squares
		// by the mathematical witness before any effect is admitted.
		precise double xx = dx * dx;
		precise double yy = dy * dy;
		precise double distance = xx + yy;
		if (admitted < 4u || distance < best[3]) {
			int slot = int(min(admitted,3u));
			for (int candidate=0;candidate<int(min(admitted,4u));candidate++) {
				if (distance < best[candidate]) { slot=candidate; break; }
			}
			for (int candidate=int(min(admitted,3u));candidate>slot;candidate--) {
				best[candidate]=best[candidate-1]; selected[candidate]=selected[candidate-1];
			}
			best[slot]=distance; selected[slot]=index;
			admitted=min(admitted+1u,4u);
		}
	}
	precise vec3 position = vec3(0.0);
	precise vec3 normal = vec3(0.0);
	precise double total = 0.0LF;
	for (int candidate=0;candidate<4;candidate++) {
		precise double denominator = best[candidate] + 0.00015LF;
		precise double weight = 1.0LF / denominator;
		float native_weight = float(weight);
		precise vec3 weighted_position = points.values[selected[candidate]].xyz * native_weight;
		precise vec3 weighted_normal = points.values[parameters.counts.x + selected[candidate]].xyz * native_weight;
		position = position + weighted_position;
		normal = normal + weighted_normal;
		total = total + weight;
		if (parameters.counts.z != 0u) {
			diagnostics.values[query_index*9u+uint(candidate)] = best[candidate];
			diagnostics.values[query_index*9u+4u+uint(candidate)] = weight;
		}
	}
	float native_total = float(total);
	position=vec3(source_divide(position.x,native_total),source_divide(position.y,native_total),source_divide(position.z,native_total));
	normal=source_normalize(normal);
	precise vec3 relative = position - parameters.origin.xyz;
	precise vec3 offset = normal * clearances.values[query_index];
	precise vec3 base = relative + offset;
	imageStore(station_image,ivec2(station,curve*2u),vec4(base,1.0));
	imageStore(station_image,ivec2(station,curve*2u+1u),vec4(normal,1.0));
	if (parameters.counts.z != 0u) {
		neighbours.values[query_index]=uvec4(selected[0],selected[1],selected[2],selected[3]);
		diagnostics.values[query_index*9u+8u]=total;
	}
}
