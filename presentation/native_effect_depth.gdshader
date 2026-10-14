shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
// A half-float viewport cannot store reversed-Z directly at the original far
// distance. Pack its 24 significant depth bits into three exact byte values;
// the native source reconstructs depth before its original projection math.
void fragment(){
    uint depth=uint(round(FRAGCOORD.z*16777215.0));
    ALBEDO=vec3(float(depth>>16u),float((depth>>8u)&255u),float(depth&255u))/255.0;
}
