@tool
extends Resource
## Factory owns the actual visual choices; presentation remains explicit working data.

@export var spell_id: String = ""
@export var title: String = ""
## Original presentation provenance; active data is stored below, not read here.
@export_file("*.json") var choreography: String = ""
@export var casting_profile: String = "authored"
@export_range(0.01, 3.0, 0.01) var effect_scale: float = 0.18
@export var stage_scales: Dictionary = {"cast": 1.0, "travel": 1.0, "impact": 1.0, "delivery": 1.0}
@export_range(0.0, 1.0, 0.01) var lead_in_seconds: float = 0.15
@export_range(0.0, 1.0, 0.01) var tail_seconds: float = 0.15
@export var phases: Array[Resource] = []
@export var palette: Dictionary = {}
@export var staging: Dictionary = {}
@export var has_staging_override: bool = false
@export var choreography_data: Dictionary = {}
@export var options: Dictionary = {}
@export_multiline var provenance: String = ""
@export_multiline var review_status: String = "Working timing and positioning; native visual review required."
@export_multiline var research_notes: String = ""

func to_selection() -> Dictionary:
	var result := options.duplicate(true)
	result.merge({
		"id": spell_id,
		"title": title,
		"choreography": choreography,
		"palette": palette.duplicate(true),
		"clips": [],
	}, true)
	if has_staging_override:
		result.staging = staging.duplicate(true)
	for selected_phase in phases:
		result.clips.append(selected_phase.to_clip())
	return result

func validate() -> PackedStringArray:
	var issues := PackedStringArray()
	if spell_id.is_empty() or phases.is_empty():
		issues.append("Spell identity or visual phases missing: " + spell_id)
	if not choreography_data.has("cast"):
		issues.append("Casting presentation missing: " + spell_id)
	var identities := {}
	for selected_phase in phases:
		if selected_phase == null or not selected_phase.has_method("to_clip"):
			issues.append("Invalid phase in " + spell_id)
			continue
		issues.append_array(selected_phase.validate())
		if identities.has(selected_phase.clip_id):
			issues.append("Duplicate phase: " + selected_phase.clip_id)
		identities[selected_phase.clip_id] = true
	# A phase can be reused by many recipients. Repeated cue choices also need
	# distinct occurrence keys: the runtime suffix identifies delivery index,
	# not the choice within that delivery. Otherwise one handle replaces another.
	if has_staging_override:
		var occurrence_keys := {}
		for cue in staging.get("cues", []):
			if not cue is Dictionary:
				issues.append("Invalid native cue in " + spell_id)
				continue
			var key: String = str(cue.get("id", cue.get("clip", "")))
			if occurrence_keys.has(key):
				issues.append("Duplicate native occurrence key: " + key + " in " + spell_id + "; give repeated phase cues distinct IDs")
			occurrence_keys[key] = true
	return issues
