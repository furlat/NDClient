shader_type spatial;
render_mode skip_vertex_transform, cull_disabled, diffuse_lambert, specular_disabled, depth_draw_never, depth_test_disabled;
uniform sampler2DArray colours : source_color, filter_nearest, repeat_disable;
uniform sampler2DArray numeric : filter_nearest, repeat_disable;
uniform sampler2D metadata : filter_nearest, repeat_disable;
uniform sampler2D instances : filter_nearest, repeat_disable;
uniform sampler2D placement_state : filter_nearest, repeat_disable;
uniform int block_base;
uniform int range_start = 0;
uniform int range_end = 1024;
uniform bool highlighted = false;
uniform bool use_source_depth = true;
uniform bool use_source_normals = true;
uniform int camera_quarter;
uniform sampler2D ripple_texture : filter_nearest, repeat_enable;
uniform vec4 shallow_color;
uniform vec4 deep_color;
uniform vec4 water_tint;
uniform vec2 ripple_pan;
uniform float uv_scale;
uniform float depth_strength;
uniform float ripple_tiling;
uniform float ripple_amount;
uniform float sheen_strength;
uniform float sheen_sharpness;
uniform float alpha_strength;
uniform float overall_alpha;
uniform float alpha_cutoff;
varying flat vec4 item;
varying flat vec3 instance_origin;
varying flat vec4 instance_tint;

vec4 field(int index) { return texelFetch(metadata,ivec2(index,int(item.x)),0); }
void vertex() {
    int index=block_base+INSTANCE_ID;
    item=texelFetch(instances,ivec2(index%256,index/256),0);
    int state_index=int(item.y);
    float hidden=texelFetch(placement_state,ivec2(state_index%256,state_index/256),0).r;
    instance_origin=MODEL_MATRIX[3].xyz;
    instance_tint=COLOR;
    if (INSTANCE_ID<range_start || INSTANCE_ID>=range_end || hidden>0.5) {
        // Collapse excluded instances before rasterization, including split ranges.
        VERTEX=vec3(0.0,0.0,1.0);
    } else {
        vec4 cell=field(0);
        vec4 affine=field(20);
        vec2 p=(UV*cell.xy-cell.zw)*field(1).x/90.5096679919;
        vec2 offset=vec2(affine.x*p.x+affine.z*p.y,affine.y*p.x+affine.w*p.y);
        VERTEX=(VIEW_MATRIX*vec4(instance_origin,1.0)).xyz+vec3(offset.x,-offset.y,0.0);
    }
    NORMAL=vec3(0.0,0.0,1.0);
}
vec3 oct_decode(vec2 encoded) {
    vec2 f=encoded*2.0-1.0;
    vec3 n=vec3(f,1.0-abs(f.x)-abs(f.y));
    float t=clamp(-n.z,0.0,1.0);
    n.x+=n.x>=0.0?-t:t;n.y+=n.y>=0.0?-t:t;
    return normalize(n);
}
void fragment() {
    vec4 cell=field(0);vec4 layers=field(1);
    vec2 pixel=floor(UV*cell.xy);
    vec4 colour=texelFetch(colours,ivec3(ivec2(field(2).xy+pixel),int(layers.y)),0);
    if(colour.a<=0.0)discard;
    vec4 mask=field(5);
    if(mask.w>=0.0) {
        bool selected=false;
        if(mask.w>0.5) {
            vec3 raw=colour.rgb;
            if(!OUTPUT_IS_SRGB)raw=mix(colour.rgb*12.92,1.055*pow(colour.rgb,vec3(1.0/2.4))-0.055,step(vec3(0.0031308),colour.rgb));
            vec4 bytes=vec4(round(raw*255.0),round(colour.a*255.0));
            selected=all(greaterThanEqual(bytes,field(17)))&&all(lessThanEqual(bytes,field(18)));
        } else {
            vec4 sampling=field(8);
            vec2 mp=floor(pixel*sampling.xy+sampling.zw);
            if(all(greaterThanEqual(mp,vec2(0.0)))&&all(lessThan(mp,mask.xy))) {
                float value=round(texelFetch(numeric,ivec3(ivec2(field(4).zw+mp),int(mask.z)),0).r*255.0);
                selected=any(lessThan(abs(field(19)-vec4(value)),vec4(0.5)));
            }
        }
        if(selected==(item.z>0.5))discard;
    }
    if(field(21).x>0.5) {
        if(colour.a<alpha_cutoff)discard;
        vec2 grid=instance_origin.xz;
        for(int q=0;q<camera_quarter;q++){grid=vec2(-grid.y,grid.x);}
        vec2 origin=vec2(64.0*(grid.x-grid.y),32.0*(grid.x+grid.y)-64.0*instance_origin.y/sqrt(2.0/3.0));
        vec2 world=(origin+(pixel-cell.zw)*layers.x)/128.0;world.y=-world.y;
        float ripple=texture(ripple_texture,world*uv_scale*ripple_tiling+ripple_pan*TIME).r;
        float depth=clamp(world.y*0.125*depth_strength+0.5,0.0,1.0);
        vec3 water=mix(shallow_color.rgb,deep_color.rgb,depth)+(ripple-0.5)*ripple_amount;
        vec2 edge=abs(SCREEN_UV-0.5)*2.0;
        water+=pow(clamp(max(edge.x,edge.y),0.0,1.0),sheen_sharpness)*sheen_strength;
        EMISSION=clamp(water,vec3(0.0),vec3(1.0))*water_tint.rgb;
        ALBEDO=vec3(0.0);
        ALPHA=clamp(colour.a+(depth-0.5)*alpha_strength,0.0,1.0)*overall_alpha*water_tint.a;
    } else {
        if(layers.z>=0.0) {
            vec4 sampling=field(6);
            vec2 gp=floor(pixel*sampling.xy+sampling.zw);
            if(all(greaterThanEqual(gp,vec2(0.0)))&&all(lessThan(gp,field(3).xy))) {
                vec4 packed=texelFetch(numeric,ivec3(ivec2(field(2).zw+gp),int(layers.z)),0);
                float code=round(packed.r*255.0)*256.0+round(packed.g*255.0);
                if(code>0.0) {
                    vec4 depth=field(9);
                    float ray_depth=mix(depth.x,depth.y,(code-1.0)/65534.0);
                    vec3 receiver=instance_origin+field(10).xyz*(gp.x+depth.z)+field(11).xyz*(gp.y+depth.w)+field(12).xyz+field(13).xyz*ray_depth;
                    if(use_source_depth)LIGHT_VERTEX=(VIEW_MATRIX*vec4(receiver,1.0)).xyz;
                    if(use_source_normals) {
                        vec4 ns=field(7);vec2 np=floor(pixel*ns.xy+ns.zw);
                        vec2 encoded=texelFetch(numeric,ivec3(ivec2(field(3).zw+np),int(layers.w)),0).ba;
                        vec3 normal=mat3(field(14).xyz,field(15).xyz,field(16).xyz)*oct_decode(encoded);
                        NORMAL=normalize(mat3(VIEW_MATRIX)*normal);
                    }
                }
            }
        }
        colour*=instance_tint;
        ALBEDO=item.z<0.5?vec3(0.0):colour.rgb;
        EMISSION=highlighted&&item.w>0.5?mix(colour.rgb,vec3(0.2,1.0,0.7),0.55):colour.rgb;
        ALPHA=colour.a;
    }
    ROUGHNESS=1.0;
}
