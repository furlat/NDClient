shader_type spatial;uniform float fx_clock=0.;uniform float opacity=1.; render_mode unshaded,cull_disabled; uniform sampler2D source_tex:source_color; uniform vec4 source_tint:source_color=vec4(1.0); uniform bool use_vertex=true; void fragment(){vec4 c=texture(source_tex,UV)*source_tint; if(use_vertex)c*=COLOR; ALBEDO=c.rgb; ALPHA=c.a;float v=max(ALBEDO.r,max(ALBEDO.g,ALBEDO.b));ALBEDO=mix(vec3(.025,.14,.35),vec3(.20,.57,.82),clamp(v,0.,1.));ALPHA*=smoothstep(.018,.08,v);ALPHA*=opacity;}


