@tool
extends Resource
## Authored phase data resolves to the existing native Factory clip contract.

@export var clip_id: String = ""
@export var label: String = ""
@export var phase: String = ""
@export var variant: String = "default"
@export var source_recipe: String = ""
@export var components: Array[Resource] = []
@export var bindings: Array = []
@export var emitters: Array = []
@export_range(0.0, 60.0, 0.001) var seconds: float = 1.0
## Zero retains a source whose legacy contract did not declare a fixed clock.
@export_range(0.0, 1000.0, 1.0) var simulation_hz: float = 0.0
## Existing contract-specific fields (registration, stage, material clocks, etc.).
@export var options: Dictionary = {}

func to_clip() -> Dictionary:
	var result := options.duplicate(true)
	result.merge({
		"id": clip_id,
		"label": label,
		"phase": phase,
		"variant": variant,
		"source_recipe": source_recipe,
		"bindings": bindings.duplicate(true),
		"emitters": emitters.duplicate(true),
		"seconds": seconds,
		"components": [],
	}, true)
	if simulation_hz > 0.0:
		result.simulation_hz = simulation_hz
	for component in components:
		result.components.append(component.to_component())
	return result

func validate() -> PackedStringArray:
	var issues := PackedStringArray()
	if clip_id.is_empty():
		issues.append("Phase identity is empty.")
	if components.is_empty():
		issues.append("No components selected: " + clip_id)
	var ids := {}
	for component in components:
		if component == null or not component.has_method("to_component"):
			issues.append("Invalid component in " + clip_id)
			continue
		issues.append_array(component.validate())
		if ids.has(component.component_id):
			issues.append("Duplicate component identity: " + component.component_id)
		ids[component.component_id] = true
	for binding in bindings:
		if not ids.has(binding.get("component", "")):
			issues.append("Binding references absent component in " + clip_id)
		if binding.get("kind", "") == "sample":
			# These are mandatory inputs of the actual native source sampler,
			# including a deliberate zero rate for held source time.
			for key in ["rate", "offset_seconds"]:
				var value: Variant = binding.get(key)
				if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)):
					issues.append("Missing/non-finite sample clock " + key + " in " + clip_id)
	if not is_finite(seconds) or seconds <= 0.0 or not is_finite(simulation_hz) or simulation_hz < 0.0:
		issues.append("Invalid source clock: " + clip_id)
	return issues
