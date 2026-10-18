shader_type spatial;render_mode unshaded,cull_disabled;
uniform sampler2D frost:repeat_enable,filter_linear;
void fragment(){
 vec3 wn=normalize((INV_VIEW_MATRIX*vec4(NORMAL,0.)).xyz);float facet=.45+.55*max(dot(wn,normalize(vec3(-.3,.8,.5))),0.);
 float n=texture(frost,UV*2.).r;ALBEDO=mix(vec3(.28,.55,.70),vec3(.55,.76,.85),n)*facet;ALPHA=1.;
}

