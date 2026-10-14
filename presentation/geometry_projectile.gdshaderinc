uniform vec2 extent=vec2(16.0,6.0);
uniform float length_px=12.0;
uniform float stroke_width=2.0;
uniform float stroke_alpha=1.0;
uniform float head_radius=2.0;
uniform float head_alpha=.9;
uniform vec4 stroke_colour:source_color;
uniform vec4 head_colour:source_color;
vec4 geometry_projectile_colour(vec2 uv){
    vec2 p=uv*extent-vec2(extent.x-head_radius-1.0,extent.y*.5);
    float stroke=p.x>=-length_px && p.x<=0.0 && abs(p.y)<=stroke_width*.5?stroke_alpha:0.0;
    float head=length(p)<=head_radius?head_alpha:0.0;
    float alpha=head+stroke*(1.0-head);
    return vec4(alpha>0.0?(head_colour.rgb*head+stroke_colour.rgb*stroke*(1.0-head))/alpha:vec3(0.0),alpha);
}
