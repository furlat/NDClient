extends Resource
## Art choices only; no sample attack, target, condition or damage result.
@export var element := ""
@export var strength := "medium"
@export var duration_seconds := .32
@export var use_optical_surface := false
@export var layers: Array[Resource] = []
@export var provenance: Array = []
@export var art_status := "native_candidate_not_visually_approved"


func validate() -> PackedStringArray:
	var issues := PackedStringArray()
	if element not in ["fire", "ice", "electric", "psychic", "poison", "radiant", "necrotic"]:
		issues.append("Unknown weapon contact art family")
	if strength not in ["lesser", "medium", "greater"]:
		issues.append("Unknown weapon contact art strength")
	if not is_finite(duration_seconds) or duration_seconds < .2 or duration_seconds > .5:
		issues.append("Weapon contact must have a finite .2–.5 second source span")
	if layers.is_empty() or layers.size() > 5:
		issues.append("Weapon contact must retain its one to five declared native layers")
	for layer in layers:
		issues.append_array(layer.validate())
	return issues
