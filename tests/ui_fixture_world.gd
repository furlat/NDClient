extends Node3D
# Boundary harness, not a gameplay simulator. State comes from an actual SDK recording.
const FrameProfile = preload("res://frame_profile.gd")
var profile = FrameProfile.create()
var timeline = preload("res://presentation/timeline.gd").new()
var session = preload("res://presentation/session.gd").new()
var loot_object_uuid = ""
func close_storage() -> void: loot_object_uuid = ""
var available_actions: Dictionary = {}
var selected_action: Dictionary = {}
var target_selection: Dictionary = {}
var selection_preview: Dictionary = {}
var notice_text = ""
var command_busy = false
var camera: Camera3D
var grid_visible = false
var normals_visible = false
func set_normals_visible(enabled: bool) -> void: normals_visible = enabled
var wall_mode = "solid"
var visual_actors = {}
var allow_commands = true
var issued: Array = []
func command_ready() -> bool: return allow_commands
func select_action(row: Dictionary) -> void: issued.append(row.duplicate(true)); selected_action = row
func inventory_intent(intent: Dictionary) -> void: issued.append(intent.duplicate(true)); allow_commands = false
func cancel_selection() -> void: selected_action = {}
func confirm_selection() -> void: issued.append({"confirmed":true})
func end_turn() -> void: issued.append({"end_turn":true})
func pick_cell(_point: Vector2) -> Dictionary: return {}

var hover_hit: Dictionary = {}
var hover_preview: Dictionary = {}
func world_labels() -> Array: return []
func activate_world_label(id: String) -> void: issued.append({"world_label":id})

var attack_preference = "MELEE_MAIN"
func toggle_attack_preference() -> void: attack_preference = "RANGED_MAIN" if attack_preference == "MELEE_MAIN" else "MELEE_MAIN"
