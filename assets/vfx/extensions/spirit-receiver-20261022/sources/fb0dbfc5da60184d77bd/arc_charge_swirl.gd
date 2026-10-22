@tool
extends Node3D

const ANIM_LEN := 3.2
const DURATION := 3.2
const BUILD_START := 0.12
const CHARGE_AT := 1.95
const RIBBON_EMISSION_DEFAULT := 1.55
const RIBBON_COUNT := 9
const DIR := "factory-path:integrations/ndclient/assets/native_effects/class_actions/vfx_1/arc_charge/textures/"

@export_group("Preview")
@export var preview := true

@export_group("Palette")
@export var base_color := Color(0.85, 0.015, 0.04):
	set(v): base_color = v; _refresh()
@export var core_color := Color(1.0, 0.3, 0.32):
	set(v): core_color = v; _refresh()
@export var hot_color := Color(1.0, 0.82, 0.8):
	set(v): hot_color = v; _refresh()
@export var ember_color := Color(1.0, 0.2, 0.13):
	set(v): ember_color = v; _refresh()
@export var spark_color := Color(1.0, 0.55, 0.45):
	set(v): spark_color = v; _refresh()
@export var glow_color := Color(0.95, 0.06, 0.08):
	set(v): glow_color = v; _refresh()
@export var light_color := Color(1.0, 0.12, 0.1):
	set(v): light_color = v; _refresh()

@export_group("Look")
@export_range(0.0, 8.0, 0.05) var ribbon_emission := 1.55:
	set(v): ribbon_emission = v; _refresh()
@export_range(0, 240, 1) var ember_amount := 64:
	set(v): ember_amount = v; _refresh()
@export_range(0, 240, 1) var spark_amount := 46:
	set(v): spark_amount = v; _refresh()
@export_range(0.0, 4.0, 0.05) var light_power := 1.2:
	set(v): light_power = v; _refresh()

@export_group("Layout")
@export_range(0.1, 5.0, 0.01) var effect_scale := 1.0:
	set(v): effect_scale = v; _refresh()

@export_group("Speed")
@export_range(0.1, 3.0, 0.01) var effect_speed := 1.0:
	set(v): effect_speed = v; _refresh()

@export_group("Textures")
@export var flow_noise: Texture2D = preload("res://assets/vfx/sources/745374b8d1de2c2b0161/flow_noise.tres"):
	set(v): flow_noise = v; _refresh()
@export var glow_texture: Texture2D = preload("res://assets/vfx/sources/0153d00f65f7d8626351/texture.res"):
	set(v): glow_texture = v; _refresh()
@export var ember_texture: Texture2D = preload("res://assets/vfx/sources/c143513f7154cf2a9322/texture.res"):
	set(v): ember_texture = v; _refresh()
@export var star_texture: Texture2D = preload("res://assets/vfx/sources/a5a94d4fd20b2794485c/texture.res"):
	set(v): star_texture = v; _refresh()

@export_group("Driven by AnimationPlayer")
@export var glow_alpha := 0.0
@export var core_alpha := 0.0
@export var light_pulse := 0.0

var _anim: AnimationPlayer
var _et := 0.0
var _ribbon_mats: Array = []
var _ribbon_base: Array = []

var _glow_mat: StandardMaterial3D
var _core_mat: StandardMaterial3D
var _embers: GPUParticles3D
var _sparks: GPUParticles3D
var _light: OmniLight3D


func _ready() -> void:
	_anim = get_node_or_null("AnimationPlayer")
	if _anim != null:
		_anim.assigned_animation = "erupt"
	_ribbon_mats.clear()
	_ribbon_base.clear()
	for i in range(RIBBON_COUNT):
		var n := get_node_or_null("Ribbon%d" % i) as MeshInstance3D
		var mat: ShaderMaterial = n.material_override if n != null else null
		_ribbon_mats.append(mat)
		var base_i: float = 1.55
		if mat != null:
			base_i = float(mat.get_shader_parameter("intensity"))
		_ribbon_base.append(base_i)
	_glow_mat = _matof("Glow")
	_core_mat = _matof("Core")
	_embers = get_node_or_null("Embers") as GPUParticles3D
	_sparks = get_node_or_null("Sparks") as GPUParticles3D
	_light = get_node_or_null("OmniLight3D") as OmniLight3D
	_apply_look()
	set_process(true)


func _matof(path: String) -> Material:
	var n := get_node_or_null(path) as GeometryInstance3D
	if n == null:
		return null
	return n.material_override


func _time() -> float:
	if Engine.is_editor_hint():
		if preview:
			return _et
		if _anim != null:
			return _anim.current_animation_position
		return _et
	if _anim != null and _anim.is_playing():
		return _anim.current_animation_position
	return _et


func _process(dt: float) -> void:
	if Engine.is_editor_hint() and preview:
		_et += dt * effect_speed
		if _et >= ANIM_LEN:
			_et = 0.0
		if _anim != null:
			_anim.seek(_et, true)
	var t := _time()
	var ramp := clampf((t - BUILD_START) / maxf(CHARGE_AT - BUILD_START, 0.01), 0.0, 1.0)
	var spike := exp(-pow((t - CHARGE_AT) / 0.22, 2.0))
	var charge := 0.65 + 0.42 * ramp + 0.26 * spike
	for mat in _ribbon_mats:
		if mat != null:
			mat.set_shader_parameter("charge", charge)
	if _glow_mat != null:
		_glow_mat.albedo_color = Color(glow_color.r, glow_color.g, glow_color.b, glow_alpha)
	if _core_mat != null:
		_core_mat.albedo_color = Color(core_color.r, core_color.g, core_color.b, core_alpha)
	if _light != null:
		_light.light_energy = light_pulse * light_power


func _refresh() -> void:
	if is_node_ready():
		_apply_look()


func _apply_look() -> void:
	scale = Vector3.ONE * effect_scale
	if _anim != null:
		_anim.speed_scale = maxf(effect_speed, 0.0)
	var mul := ribbon_emission / RIBBON_EMISSION_DEFAULT
	for i in range(_ribbon_mats.size()):
		var mat: ShaderMaterial = _ribbon_mats[i]
		if mat == null:
			continue
		mat.set_shader_parameter("base_color", base_color)
		mat.set_shader_parameter("core_color", core_color)
		mat.set_shader_parameter("hot_color", hot_color)
		mat.set_shader_parameter("intensity", float(_ribbon_base[i]) * mul)
		mat.set_shader_parameter("flow_tex", flow_noise)
	_tex(_glow_mat, glow_texture)
	_tex(_core_mat, glow_texture)
	if _embers != null:
		_embers.amount = ember_amount
		_pcolor(_embers.process_material, ember_color)
		_tex(_embers.material_override, ember_texture)
	if _sparks != null:
		_sparks.amount = spark_amount
		_pcolor(_sparks.process_material, spark_color)
		_tex(_sparks.material_override, star_texture)
	if _light != null:
		_light.light_color = light_color


func _tex(mat: Material, tex: Texture2D) -> void:
	if mat is StandardMaterial3D:
		mat.albedo_texture = tex


func _pcolor(proc: ParticleProcessMaterial, col: Color) -> void:
	if proc != null:
		proc.color = col
