extends RefCounted
## Exact existing ±.5axis inclusion against the actual integral Vector2i set.
## A nearest integer is unique except at a half-cell tie; those ties retain
## both possible source cells. No footprint approximation or cell creation.


static func contains(point: Vector2, admitted: Dictionary) -> bool:
	# The original abs comparison cannot match a nonfinite point, or any point
	# farther than half a unit from the entire native Vector2i coordinate range.
	if not point.is_finite() or point.x < -2147483648.5 or point.x > 2147483647.5 or point.y < -2147483648.5 or point.y > 2147483647.5:
		return false
	var nearest := Vector2i(roundi(point.x), roundi(point.y))
	if admitted.has(nearest):
		return true
	var delta_x := float(point.x) - float(nearest.x)
	var delta_y := float(point.y) - float(nearest.y)
	var tie_x := int(signf(delta_x)) if absf(delta_x) == .5 else 0
	var tie_y := int(signf(delta_y)) if absf(delta_y) == .5 else 0
	if tie_x != 0 and admitted.has(nearest + Vector2i(tie_x, 0)):
		return true
	if tie_y != 0 and admitted.has(nearest + Vector2i(0, tie_y)):
		return true
	return tie_x != 0 and tie_y != 0 and admitted.has(nearest + Vector2i(tie_x, tie_y))
