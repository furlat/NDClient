shader_type canvas_item;
render_mode blend_disabled;
// Preserved class-actions-roar-cast-v5 pack.py and preview.js colorAt operator.
// This runs ONCE after the complete native composition, never on each ribbon.
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest, repeat_disable;
uniform vec3 palette_low = vec3(0.28627451,0.42352941,0.51764706);
uniform vec3 palette_middle = vec3(0.57254902,0.72549020,0.79607843);
uniform vec3 palette_high = vec3(0.86666667,0.73725490,0.53725490);
const float levels[8] = float[8](26.0,49.0,78.0,109.0,143.0,177.0,211.0,239.0);
vec3 decode(vec3 v) {
    return mix(pow((v+vec3(0.055))/1.055,vec3(2.4)),v/12.92,lessThanEqual(v,vec3(0.04045)));
}
vec3 encode(vec3 v) {
    return mix(1.055*pow(v,vec3(1.0/2.4))-vec3(0.055),12.92*v,lessThanEqual(v,vec3(0.0031308)));
}
void fragment() {
    ivec2 size = textureSize(screen_texture,0);
    ivec2 pixel = clamp(ivec2(SCREEN_UV*vec2(size)),ivec2(0),size-1);
    vec4 original = texelFetch(screen_texture,pixel,0);
    if (original.a*255.0<3.0) { COLOR=vec4(0.0); }
    else {
        ivec2 block = (pixel/2)*2;
        float weighted = 0.0;
        float weight = 0.0;
        for (int y=0;y<2;y++) for (int x=0;x<2;x++) {
            vec4 value=texelFetch(screen_texture,min(block+ivec2(x,y),size-1),0);
            vec3 straight=encode(clamp(decode(value.rgb)/max(value.a,1.0/255.0),vec3(0.0),vec3(1.0)));
            weighted+=(straight.r+straight.g+straight.b)/3.0*255.0*value.a;
            weight+=value.a;
        }
        float energy=weight>0.0 ? weighted/weight : 0.0;
        float nearest=levels[0];
        float distance=abs(energy-nearest);
        for(int i=1;i<8;i++) if(abs(energy-levels[i])<distance) {
            nearest=levels[i]; distance=abs(energy-nearest);
        }
        float position=clamp(nearest/239.0,0.0,1.0)*2.0;
        vec3 color=position<1.0 ? mix(palette_low,palette_middle,position) : mix(palette_middle,palette_high,position-1.0);
        COLOR=vec4(floor(color*255.0+0.5)/255.0,original.a);
    }
}
