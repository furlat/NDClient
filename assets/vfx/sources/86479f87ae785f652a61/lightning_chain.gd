@tool
extends "res://assets/vfx/sources/df180467412a5071502b/lightning_base.gd"

const ANIM_LEN := 2.0
const STRIKE_TIME := 0.28
const HOP_DELAY := 0.05
const CHAIN_WIDTH := 0.42

@export_group("Driven by AnimationPlayer")
@export var bolt_env := 0.0
@export var chain_points: Array[Vector3] = []

var _bolt: Dictionary


func _anim_name() -> String:
	return "chain"


func _anim_len() -> float:
	return ANIM_LEN


func _bind() -> void:
	_bolt = _bind_bolt("Bolt")


func _redraw() -> void:
	if _bolt.is_empty():
		return
	_bolt_clear(_bolt)
	if bolt_env <= 0.01 or chain_points.size() < 2:
		return
	var ts := _time() - STRIKE_TIME
	var revealed := 1
	if ts >= 0.0:
		revealed = clampi(int(ts / HOP_DELAY) + 1, 1, chain_points.size() - 1)
	for i in range(mini(revealed, chain_points.size() - 1)):
		_bolt_draw(_bolt, chain_points[i], chain_points[i + 1], CHAIN_WIDTH, true)
