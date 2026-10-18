extends RefCounted
## An optional host revision identifies unchanged local points/normals. Accept
## both existing string pose IDs and structured revisions. Missing keys never
## claim equality; world translation is deliberately separate from this key.
static func from_surface(surface: Dictionary) -> Array:
	var revision: Variant = surface.get("gpu_geometry_key", surface.get("pose_key", null))
	if revision == null or (revision is String and revision.is_empty()) or (revision is Array and revision.is_empty()):
		return []
	return [surface.get("actor", ""), surface.get("item_uuid", ""), revision]
