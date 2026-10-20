shader_type spatial;
uniform mat4 factory_world_to_source=mat4(1.0);render_mode unshaded,cull_disabled;
uniform float env=1.;
void fragment(){vec3 wp=(factory_world_to_source * INV_VIEW_MATRIX * vec4(VERTEX,1.0)).xyz;float edge=pow(1.-abs(dot(normalize(NORMAL),normalize(VIEW))),2.);ALBEDO=vec3(.50+.40*edge);EMISSION=vec3(.30);ALPHA=env;}


