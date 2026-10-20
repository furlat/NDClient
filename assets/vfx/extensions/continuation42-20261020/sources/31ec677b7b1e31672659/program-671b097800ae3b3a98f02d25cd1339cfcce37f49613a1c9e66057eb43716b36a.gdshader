shader_type spatial;
uniform mat4 factory_world_to_source=mat4(1.0);render_mode unshaded,cull_disabled;
uniform sampler2D sprite;uniform float env=1.;
void fragment(){vec3 wp=(factory_world_to_source * INV_VIEW_MATRIX * vec4(VERTEX,1.0)).xyz;vec4 t=texture(sprite,UV);ALBEDO=vec3(.66+.26*t.r);ALPHA=t.a*env;}


