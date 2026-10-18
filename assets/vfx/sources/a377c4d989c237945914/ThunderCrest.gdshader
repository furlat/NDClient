shader_type spatial;
render_mode unshaded,blend_mix,cull_disabled,depth_draw_never;
uniform sampler2D authored_noise: repeat_enable,filter_linear;
uniform sampler2D authored_mask: repeat_disable,filter_linear;
uniform bool echo_layer=false;
varying float height_band;
varying float crest_x;
void vertex() {
 height_band=clamp(VERTEX.y/3.1,0.0,1.0);
 crest_x=VERTEX.x;
}
void fragment() {
 float clock=TIME;
 float rise=smoothstep(0.0,0.08,clock);
 float fade=1.0-smoothstep(0.60,0.86,clock);
 float noise=texture(authored_noise,UV*vec2(1.2,1.0)+vec2(0.0,-clock*1.1)).r;
 float mask=texture(authored_mask,UV).r;
 float folds=sin(UV.y*27.0+noise*7.0-clock*13.0)*0.5+0.5;
 float rim=smoothstep(0.89,0.99,UV.y);
 float hot=max(rim*0.85,smoothstep(0.47,0.86,noise*0.45+folds*0.55));
 vec3 deep=vec3(0.12,0.025,0.29);
 vec3 mid=vec3(0.46,0.14,0.80);
 vec3 light=vec3(0.79,0.55,1.0);
 float pulse=pow(max(0.0,sin(UV.y*48.0-clock*32.0+noise*4.0)),9.0);
 ALBEDO=mix(mix(deep,mid,clamp(noise*0.7+height_band*0.4,0.0,1.0)),light,hot*0.9);
 ALBEDO=mix(ALBEDO,light, pulse*0.65);
 float breakup=smoothstep(0.0,0.18,noise-(1.0-fade)*0.7);
 ALPHA=(echo_layer?0.30+0.35*pulse:0.64+hot*0.34)*mix(0.7,1.0,smoothstep(0.04,0.28,mask))*breakup*rise*fade;
}
