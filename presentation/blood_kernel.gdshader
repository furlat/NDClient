shader_type canvas_item;
render_mode unshaded, blend_add;
varying float mass;
varying float fragment_primitive;
void vertex(){mass=INSTANCE_CUSTOM.r;fragment_primitive=INSTANCE_CUSTOM.g;}
void fragment(){if(fragment_primitive>.5){if(UV.x+UV.y>1.)discard;COLOR=vec4(1.,0.,0.,1.);}else{vec2 p=(UV*2.-1.)*sqrt(1.5);float q=dot(p,p);float value=mass*pow(max(0.,1.-q/1.5),2.);COLOR=vec4(value,0.,0.,1.);}}
