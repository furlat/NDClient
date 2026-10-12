// A 1px-white Sprite2D's native region UV carries atlas storage pixels. Its local
// rectangle and MODEL_MATRIX still describe the actual cropped receiver, keeping
// native light culling correct without per-item uniform storage. source_crop is
// normalized within the ORIGINAL full cell; no source pixels are resampled.
uniform vec2 atlas_cell_size = vec2(1.0);
uniform float receiver_visibility = 1.0;
uniform vec3 receiver_world_origin = vec3(0.0);
uniform vec4 source_crop = vec4(0.0, 0.0, 1.0, 1.0);
varying vec2 atlas_receiving_pixel;
varying vec4 atlas_inverse_normal_basis;

vec4 atlas_normal_inverse(mat4 model) {
    // Godot applies normalized MODEL_MATRIX axes to NORMAL after fragment().
    // Cancel that transport: source decoding already produced Canvas normals.
    mat2 basis = mat2(normalize(model[0].xy), normalize(model[1].xy));
    mat2 inverse_basis = inverse(basis);
    return vec4(inverse_basis[0], inverse_basis[1]);
}

vec3 atlas_canvas_normal(vec3 normal) {
    return vec3(mat2(atlas_inverse_normal_basis.xy, atlas_inverse_normal_basis.zw) * normal.xy, normal.z);
}

// White receivers leave source alpha untouched. Native HDR storage retains its
// fractional coverage; the final spatial pass applies the original wall opacity.
uniform bool store_irradiance = false;
