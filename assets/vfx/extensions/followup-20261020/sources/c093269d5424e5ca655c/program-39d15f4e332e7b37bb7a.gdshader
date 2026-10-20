shader_type spatial;
uniform mat4 factory_world_to_source=mat4(1.0);
uniform float vfx_clock=0.0;
uniform float vfx_alpha=1.0; render_mode unshaded,cull_disabled; uniform sampler2D source_tex:source_color; uniform vec4 source_tint:source_color=vec4(1.0); uniform bool use_vertex=true; void fragment(){
vec3 wp=(factory_world_to_source * INV_VIEW_MATRIX * vec4(VERTEX,1.0)).xyz; 
vec4 c=texture(source_tex,UV)*source_tint; if(use_vertex)c*=COLOR; ALBEDO=c.rgb; ALPHA=c.a;
ALPHA *= vfx_alpha;
}


