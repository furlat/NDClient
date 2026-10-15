#[compute]
#version 450
layout(local_size_x=8,local_size_y=8,local_size_z=1) in;
layout(rgba16f,set=0,binding=0) uniform writeonly image2D colour;
layout(set=0,binding=1) uniform sampler2D scene_depth;
layout(set=0,binding=2) uniform sampler2D receiver_depth;
void main(){
    ivec2 p=ivec2(gl_GlobalInvocationID.xy);
    if(any(greaterThanEqual(p,imageSize(colour))))return;
    vec4 support=texelFetch(receiver_depth,p,0);
    vec3 bytes=round(support.rgb*255.);
    float receiver_z=dot(bytes,vec3(65536.,256.,1.))/16777215.;
    float scene_z=texelFetch(scene_depth,p,0).r;
    if(support.a>.5&&abs(scene_z-receiver_z)<=4./16777215.)imageStore(colour,p,vec4(0.));
}
