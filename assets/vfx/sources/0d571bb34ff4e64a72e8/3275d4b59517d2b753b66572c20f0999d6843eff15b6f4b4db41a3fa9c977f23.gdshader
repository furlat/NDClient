shader_type spatial;
render_mode unshaded,cull_disabled,blend_mix;
uniform sampler2D footprint:filter_nearest,repeat_disable;
uniform sampler2D marble:filter_linear,repeat_enable;
uniform float clock=0.0;
uniform vec4 fluid[160];
uniform int material_kind=0;
uniform vec4 dark:source_color=vec4(.17,.15,.13,1.0);
uniform vec4 mid:source_color=vec4(.32,.30,.25,1.0);
uniform vec4 light:source_color=vec4(.62,.59,.47,1.0);
uniform float body_alpha=.6;
void fragment(){
 // Shared world-space domain, never restart UV or animation at cell borders.
 vec2 world=UV*4.0-.5;
 float phase=(clock-1.0)*3.14159265359;
 float activity=mix(1.0,.10,smoothstep(.8,2.0,clock));
 vec2 drift=vec2(sin(phase),cos(phase))*.025*activity;
 vec2 point=world-1.5;
 float density=0.0;
 for(int i=0;i<160;i++){
  float on_floor=1.0-smoothstep(.03,.09,fluid[i].y);
  float d=length(point-fluid[i].xz)/.26;
  density+=max(0.0,1.0-d*d)*max(0.0,1.0-d*d)*on_floor;
 }
 float coverage_alpha=smoothstep(.48,.66,density);
 float edge_glint=exp(-pow((density-.72)/.25,2.0));
 float end=1.0;
 vec2 p=(world-1.5)/1.08;
 float n=texture(marble,world*.675+drift).r;
 // Low-contrast moving material texture; no repeated bright stripe highlights.
 float n2=texture(marble,world*.49-drift*.65+vec2(.27,.16)).r;
 float glint=.07*smoothstep(.65,.98,n*n2);
 float shade=.16+n*.35;
 if(material_kind==0){shade=n*.10;glint=.11*smoothstep(.55,.92,n2);}
 else if(material_kind==2){shade=n*.18;glint=.05*smoothstep(.65,.94,n2);}
 else if(material_kind==3){shade=n*.28;glint=.045*smoothstep(.63,.95,n2);}
 else if(material_kind==4){shade=.12+n*n2*.48;glint=.08*smoothstep(.60,.95,n2);}
 else if(material_kind==5){shade=n*.22;glint=.05*smoothstep(.68,.96,n2);}
 ALBEDO=mix(mix(dark.rgb,mid.rgb,shade),light.rgb,glint);
 ALPHA=coverage_alpha*end*min(1.0,body_alpha+glint*.48);
}
