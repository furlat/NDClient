// Recover the original source texel selected by the nearest light-atlas read.
// Raw quad UV can select its neighbour after float32 atlas-address rounding.
vec2 source_atlas_uv(vec2 cell_uv, vec2 atlas_origin, vec2 atlas_size,
        vec2 atlas_dimensions, vec4 crop) {
    vec2 selected_pixel = floor((atlas_origin+cell_uv*atlas_size)*atlas_dimensions);
    return crop.xy + (selected_pixel+vec2(0.5)-atlas_origin*atlas_dimensions)
        / (atlas_size*atlas_dimensions)*crop.zw;
}
