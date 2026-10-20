#ifndef BODY_SURFACE_INCLUDED
#define BODY_SURFACE_INCLUDED
// Eight resident surface layers; composition/overflow is explicit in
// body_surfaces.gd. Reconstruct geometry once, preserve each source's own clock.
uniform bool body_surface_enabled=false;
uniform int body_surface_count=0;
uniform sampler2D body_surface_texture[8]:filter_linear,repeat_enable;
uniform vec3 body_surface_primary[8];
uniform vec3 body_surface_secondary[8];
uniform vec3 body_surface_tertiary[8];
uniform float body_surface_scale[8];
uniform float body_surface_strength[8];
uniform float body_surface_clock[8];
uniform vec2 body_surface_noise_scale[8];
uniform vec2 body_surface_scroll[8];
uniform float body_surface_twist[8];
uniform float body_surface_waviness[8];
uniform float body_surface_emission[8];

float body_surface_noise(vec2 uv,int layer) {
    // Same source texture, twist, wave and scroll as aura_sphere.gdshader.
    // The sphere's UV edge mask is replaced by the body's existing alpha.
    uv.x+=sin(uv.y*40.0-body_surface_clock[layer])*0.1*body_surface_waviness[layer];
    vec2 sample_uv=vec2(uv.x-uv.y*body_surface_twist[layer],uv.y)*body_surface_noise_scale[layer]
        +body_surface_clock[layer]*body_surface_scroll[layer];
    return texture(body_surface_texture[layer],sample_uv).r;
}

vec3 apply_body_surface(vec3 colour,vec3 position_world_relative,vec3 normal_world,vec3 view_normal) {
    if(!body_surface_enabled || body_surface_count<=0
        || dot(normal_world,normal_world)<0.0001 || dot(view_normal,view_normal)<0.0001)return colour;
    vec3 n=normalize(normal_world);
    vec3 weights=abs(n);weights*=weights;weights*=weights;
    weights/=max(weights.x+weights.y+weights.z,0.0001);
    for(int layer=0;layer<min(body_surface_count,8);layer++) {
        vec3 p=position_world_relative*body_surface_scale[layer];
        float noise_value=body_surface_noise(p.zy,layer)*weights.x
            +body_surface_noise(p.xz,layer)*weights.y+body_surface_noise(p.xy,layer)*weights.z;
        float coverage=smoothstep(0.5,0.8,noise_value);
        vec3 film=mix(body_surface_secondary[layer],body_surface_primary[layer],coverage);
        // The downward facet colour is independent of camera quarter.
        film=mix(film,body_surface_tertiary[layer],max(0.0,-n.y));
        film*=max(0.0,body_surface_emission[layer]);
        film/=max(1.0,max(film.r,max(film.g,film.b)));
        // Source-over is bounded; stacking does not sum emission into white.
        colour=mix(colour,film,clamp(body_surface_strength[layer]*coverage,0.0,1.0));
    }
    return colour;
}
#endif
