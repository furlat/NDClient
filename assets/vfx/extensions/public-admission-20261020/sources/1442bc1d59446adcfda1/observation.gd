extends RefCounted
## Only current normalized native occurrences; no item/condition reconstruction.
const THROW := "action.spell.payload.throw"


static func _identity(value: Variant) -> bool:
	return value is String and not value.is_empty()


static func _cell(value: Variant) -> bool:
	if not value is Array or value.size() != 2: return false
	for coordinate: Variant in value:
		if typeof(coordinate) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(coordinate)) or float(coordinate) != floor(float(coordinate)): return false
	return true


static func _node(value: Variant) -> bool:
	return value is Dictionary and _identity(value.get("id")) and _identity(value.get("lineage_id")) \
		and value.get("phase") == "completion" and value.get("canceled") is bool and not value.canceled \
		and value.get("fact") is Dictionary and value.get("children_lineages") is Array


static func resolve(value: Dictionary, owner: String, caster: String) -> Dictionary:
	var explosion: Variant = value.get("explosion")
	if not _node(explosion) or explosion.id != owner:
		return {"error":"actual_completed_explosion_owner_missing"}
	var fact: Dictionary = explosion.fact
	if fact.get("kind") != "spell" or fact.get("behavior_id") != THROW or fact.get("source_entity_uuid") != caster:
		return {"error":"actual_explosion_source_mismatch"}
	var origin: Variant = fact.get("aoe_position")
	if not _cell(origin) or fact.has("source_position") and fact.source_position != null and fact.source_position != origin:
		return {"error":"actual_explosion_origin_missing_or_conflicting"}
	var geometry: Variant = fact.get("area_geometry")
	if not geometry is Dictionary or geometry.get("shape") != "sphere" or geometry.get("center") != origin or fact.get("area_propagation") != "line_of_effect":
		return {"error":"actual_freezing_area_geometry_missing"}
	var cells: Variant = fact.get("resolved_area_positions")
	if not cells is Array or cells.is_empty() or cells.size() > 128:
		return {"error":"actual_resolved_cells_missing_or_unsupported"}
	var relative := []
	var seen := {}
	for cell: Variant in cells:
		if not _cell(cell): return {"error":"invalid_resolved_cell"}
		var key := Vector2i(int(cell[0]),int(cell[1]))
		if seen.has(key): return {"error":"duplicate_resolved_cell"}
		seen[key] = true
		# Existing consumer interpretation: actual global cells minus origin.
		relative.append([int(cell[0])-int(origin[0]),int(cell[1])-int(origin[1])])
	var ancestors: Variant = value.get("ancestors")
	if not ancestors is Array or ancestors.is_empty(): return {"error":"accepted_throw_ancestry_missing"}
	var child: Dictionary = explosion
	var visited := {str(explosion.lineage_id):true}
	for index in ancestors.size():
		var ancestor: Variant = ancestors[index]
		if not _node(ancestor) or visited.has(str(ancestor.lineage_id)) or child.get("parent_lineage") != ancestor.lineage_id or child.lineage_id not in ancestor.children_lineages:
			return {"error":"accepted_throw_ancestry_broken_or_canceled"}
		visited[str(ancestor.lineage_id)] = true
		if index == ancestors.size()-1:
			if ancestor.fact.get("kind") != "action" or ancestor.fact.get("behavior_id") != THROW or not _identity(ancestor.fact.get("source_entity_uuid")) or ancestor.fact.get("target_position") != origin:
				return {"error":"accepted_throw_destination_missing_or_conflicting"}
		else:
			if ancestor.fact.get("kind") in ["action","spell","attack"]:
				return {"error":"different_nearer_action_owns_explosion"}
		child = ancestor
	return {"error":"","origin":origin.duplicate(),"admitted_cells":relative,
		"explosion_occurrence":explosion.id,"explosion_lineage":explosion.lineage_id,
		"accepted_throw_occurrence":child.id,"accepted_throw_lineage":child.lineage_id,
		"throw_actor_uuid":child.fact.source_entity_uuid,"source_caster_uuid":caster,
		"ancestry_occurrences":ancestors.map(func(node:Dictionary)->String:return node.id)}
