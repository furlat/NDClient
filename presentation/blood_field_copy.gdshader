shader_type canvas_item;
render_mode unshaded, blend_disabled;
// One painter's 64x64 field lands unchanged in its atlas slot: raw RGBA16F texels, no blend.
void fragment(){COLOR=texelFetch(TEXTURE,ivec2(UV*64.),0);}
