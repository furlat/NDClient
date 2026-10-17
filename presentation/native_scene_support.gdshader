shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled, depth_test_disabled, depth_draw_never;
// Compose packet depth in the SAME source-over order as the painted outfit.
// Independently inferred component depths must never reorder that outfit.
uniform bool has_geometry=false;
uniform sampler2D sheet:filter_nearest,repeat_disable;
uniform sampler2D component_depth:filter_nearest,repeat_disable;
uniform sampler2D component_support:filter_nearest,repeat_disable;
uniform sampler2D component_solid:filter_nearest,repeat_disable;
uniform vec4 frame_uv;
uniform vec2 component_depth_range;
uniform float component_units;
uniform vec2 component_reconstruction_origin;
uniform vec2 component_cell_size=vec2(128.0);
uniform float component_elevation;
uniform mat3 display_basis;
uniform vec2 sprite_pivot;
uniform float ground_height;
void fragment(){
    // The sprite lights one cell texel per fragment; address the same texel.
    vec2 selected_uv=(floor(UV*component_cell_size)+.5)/component_cell_size;
    vec2 pixel=floor(selected_uv*component_cell_size)+.5;
    vec2 uv=frame_uv.xy+pixel/component_cell_size*frame_uv.zw;
    if(texture(sheet,uv).a<1.0)discard;
    // A visible opaque owner with no admitted geometry clears covered support.
    // Zero is reversed-Z's far plane, so it invents no solid surface.
    ALPHA=1.0;
    ALBEDO=vec3(0.0);
    if(has_geometry){
    vec4 depth=texture(component_depth,uv);
    if(texture(component_solid,uv).r>.5 && texture(component_support,uv).r>.5 && depth.a>.5){
    float d=component_depth_range.x+(depth.r*255.-32.)*(component_depth_range.y-component_depth_range.x)/192.;
    float height=((component_reconstruction_origin.y-pixel.y)*cos(component_elevation)+d*sin(component_elevation))*component_units;
    // Optical packets place the soles at an authored nonzero optical ground.
    // Scene support is actor-local: subtract that origin, with no shadow-only
    // height compression. The model transform adds the actual world elevation.
    height-=ground_height;
    vec3 local_painted=vec3(pixel.x-sprite_pivot.x,sprite_pivot.y-pixel.y,0.)*component_units;
    float view_depth=(height-(display_basis*local_painted).y)/display_basis[2].y;
    vec3 point=(MODEL_MATRIX*vec4(local_painted+vec3(0.,0.,view_depth),1.)).xyz;
    vec4 projected=PROJECTION_MATRIX*VIEW_MATRIX*vec4(point,1.);
    float scene_depth=projected.z/projected.w;
    uint packed=uint(round(scene_depth*16777215.));
    ALBEDO=vec3(float(packed>>16u),float((packed>>8u)&255u),float(packed&255u))/255.;
    }
    }
}
