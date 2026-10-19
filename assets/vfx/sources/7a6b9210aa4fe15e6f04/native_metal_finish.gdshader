shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled;

// Intrinsic source finish for the native VFX pass, which intentionally has no
// donor lamps or environment reflection. Geometry normals, not a flat carrier
// colour, distinguish each real flange/shaft facet. No optical light emitted.
uniform vec4 finish_colour : source_color = vec4(0.38, 0.43, 0.49, 1.0);
uniform float metal_fraction : hint_range(0.0, 1.0) = 0.82;

void fragment() {
	vec3 normal = normalize(NORMAL);
	// Closed owned meshes already supply outward normals on both sides.
	// Flipping by winding had erased/inverted their actual facet response.
	vec3 view_direction = normalize(VIEW);
	float facet = clamp(dot(normal, normalize(vec3(-0.48, 0.74, 0.46))), 0.0, 1.0);
	float view_edge = pow(1.0 - abs(dot(normal, view_direction)), 1.6);
	float narrow_sheen = pow(clamp(dot(normal, normalize(vec3(0.56, 0.24, 0.79))) * 0.5 + 0.5, 0.0, 1.0), 12.0);
	vec3 pigment = finish_colour.rgb;
	vec3 surface_colour = pigment * (0.26 + 0.86 * facet);
	vec3 metal_highlight = mix(pigment, vec3(0.90), 0.45);
	surface_colour += metal_highlight * metal_fraction * (0.38 * narrow_sheen + 0.08 * view_edge);
	ALBEDO = clamp(surface_colour, vec3(0.0), vec3(1.0));
	EMISSION = vec3(0.0);
}
