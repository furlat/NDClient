@tool
extends Node3D

@export_group("Preview")
@export var preview := true:
	set(v):
		preview = v
		if Engine.is_editor_hint() and preview:
			_play()

@export_group("Palette")
@export var ring_color := Color(0.46, 0.83, 1.0, 1.0):
	set(v): ring_color = v; _refresh()
@export var hot_color := Color(0.9, 0.98, 1.0, 1.0):
	set(v): hot_color = v; _refresh()
@export var orb_color := Color(0.2, 0.5, 1.0, 1.0):
	set(v): orb_color = v; _refresh()
@export var rim_color := Color(0.6, 0.9, 1.0, 1.0):
	set(v): rim_color = v; _refresh()
@export var sparkle_color := Color(0.78, 0.92, 1.0, 1.0):
	set(v): sparkle_color = v; _refresh()

@export_group("Layout")
@export_range(0.1, 5.0, 0.01) var effect_scale := 1.0:
	set(v): effect_scale = v; _refresh()

@export_group("Speed")
@export_range(0.1, 3.0, 0.01) var effect_speed := 1.0:
	set(v): effect_speed = v; _refresh()

@export_group("Textures")
@export var rune_texture: Texture2D = preload("res://assets/vfx/sources/c76abe0e32b323e764b9/texture.res"):
	set(v): rune_texture = v; _refresh()
@export var sigil_outer_texture: Texture2D = preload("res://assets/vfx/sources/b33567c62d24d435bf9c/texture.res"):
	set(v): sigil_outer_texture = v; _refresh()
@export var sigil_inner_texture: Texture2D = preload("res://assets/vfx/sources/126bc0b3499cfbcf1cfc/texture.res"):
	set(v): sigil_inner_texture = v; _refresh()
@export var sparkle_texture: Texture2D = preload("res://assets/vfx/sources/f9dd93bb4d4682eac79f/texture.res"):
	set(v): sparkle_texture = v; _refresh()

var _band_mats: Array = []
var _sigil_mats: Array = []
var _orb_mat: ShaderMaterial


func _ready() -> void:
	_grab()
	_refresh()
	if Engine.is_editor_hint() and preview:
		_play()


func _grab() -> void:
	_band_mats.clear()
	_sigil_mats.clear()
	_orb_mat = null
	var spin := get_node_or_null("Breath/Spin")
	if spin != null:
		for ch in spin.get_children():
			if ch is MeshInstance3D and ch.material_override is ShaderMaterial:
				_band_mats.append(ch.material_override)
	var orb := get_node_or_null("Breath/Orb") as MeshInstance3D
	if orb != null and orb.material_override is ShaderMaterial:
		_orb_mat = orb.material_override
	var sigils := get_node_or_null("Breath/Sigils")
	if sigils != null:
		for ch in sigils.get_children():
			if ch is MeshInstance3D and ch.material_override is ShaderMaterial:
				_sigil_mats.append(ch.material_override)


func _play() -> void:
	var ap := get_node_or_null("AnimationPlayer") as AnimationPlayer
	if ap != null:
		ap.play("arcane_loop")


func _refresh() -> void:
	if not is_node_ready():
		return
	scale = Vector3.ONE * effect_scale
	var ap := get_node_or_null("AnimationPlayer") as AnimationPlayer
	if ap != null:
		ap.speed_scale = maxf(effect_speed, 0.0)
	for m in _band_mats:
		m.set_shader_parameter("ring_color", ring_color)
		m.set_shader_parameter("hot_color", hot_color)
		m.set_shader_parameter("rune_texture", rune_texture)
	for m in _sigil_mats:
		m.set_shader_parameter("ring_color", ring_color)
		m.set_shader_parameter("hot_color", hot_color)
	if _sigil_mats.size() > 0:
		_sigil_mats[0].set_shader_parameter("circle_texture", sigil_outer_texture)
	if _sigil_mats.size() > 1:
		_sigil_mats[1].set_shader_parameter("circle_texture", sigil_inner_texture)
	if _orb_mat != null:
		_orb_mat.set_shader_parameter("orb_color", orb_color)
		_orb_mat.set_shader_parameter("rim_color", rim_color)
	var sparkles := get_node_or_null("Sparkles") as GPUParticles3D
	if sparkles != null and sparkles.draw_pass_1 != null:
		var dm: Mesh = sparkles.draw_pass_1
		if dm.surface_get_material(0) is StandardMaterial3D:
			var sm := dm.surface_get_material(0) as StandardMaterial3D
			sm.albedo_color = sparkle_color
			sm.albedo_texture = sparkle_texture
		var pm := sparkles.process_material as ParticleProcessMaterial
		if pm != null:
			pm.color = sparkle_color
