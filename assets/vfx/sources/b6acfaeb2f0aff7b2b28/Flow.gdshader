shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, shadows_disabled, unshaded;
uniform sampler2D flow_tex : repeat_enable, filter_linear;
uniform float clock = 0.0;
uniform float seed = 0.0;
uniform float strength = 1.0;
uniform float broad = 0.0;
uniform float side = 0.0;
uniform vec2 camera_ground = vec2(1.0,1.0);
uniform vec3 source_origin=vec3(0.0);
varying vec3 world_p;
varying float requested_side;
void vertex(){ world_p = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; requested_side=(CAMERA_VISIBLE_LAYERS & (1u<<19u))!=0u ? 1.0 : ((CAMERA_VISIBLE_LAYERS & (1u<<18u))!=0u ? -1.0 : side); }
void fragment(){
 float dep = dot(world_p.xz-source_origin.xz,camera_ground);
 if ((requested_side < -0.5 && dep >= 0.0) || (requested_side > 0.5 && dep < 0.0)) discard;
 float phase = clock * 3.14159265359;
 vec2 motion = vec2(cos(phase),sin(phase))*.18;
 float n = texture(flow_tex, UV*vec2(2.8,.8)+motion+seed).r;
 float st = .5 + .5*sin(UV.x*25.132741 - phase*2.0+seed*10.0);
 float center = pow(max(0.0,1.0-abs(UV.y-.5)*2.0),mix(2.0,1.0,broad));
 float ends = smoothstep(0.0,.16,UV.x)*(1.0-smoothstep(.72,1.0,UV.x));
 float a = center*ends*(.32+.68*st)*(.6+.4*n)*strength;
 float v = .26+.57*st+.12*n;
 ALBEDO = vec3(v); ALPHA = a*mix(.8,.45,broad);
}
