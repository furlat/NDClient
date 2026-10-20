shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled, depth_draw_never, depth_test_disabled;
// Production optical-height reconstruction; depth is composed in source painter
// order. Independent component packets never reorder face, shirt and weapon.
#define CAPPED_MODULAR
#include "res://assets/vfx/sources/8b80036d2399983b1265/source_colour_modular.gdshaderinc"
#include "res://assets/vfx/sources/f48a538ea24a6c156ef0/native_scene_vertex.gdshaderinc"
varying vec3 echo_world_origin;
void vertex() {
    echo_world_origin = MODEL_MATRIX[3].xyz;
    native_scene_model_basis = mat3(MODEL_MATRIX);
}
void fragment() {
    vec4 source = modular_source_colour(UV);
    if (source.a <= 0.0) discard;
    vec3 point = VERTEX;
    vec3 measured;
    if (native_scene_receiver(UV,VERTEX,VIEW_MATRIX,INV_VIEW_MATRIX,echo_world_origin,measured)) point = measured;
    // Unmeasured colour keeps its painted plane for optical ordering. This pass
    // publishes no scene receiver, physical blocker, shadow or gameplay entity.
    vec4 projected = PROJECTION_MATRIX*vec4(point,1.0);
    uint packed = uint(round(clamp(projected.z/projected.w,0.0,1.0)*16777215.0));
    ALBEDO = vec3(float(packed>>16u),float((packed>>8u)&255u),float(packed&255u))/255.0;
    // Packed depth must remain exact numeric bytes, never alpha-blended bytes.
    ALPHA = 1.0;
}
