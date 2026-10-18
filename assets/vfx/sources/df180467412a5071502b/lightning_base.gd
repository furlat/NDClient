@tool
extends Node3D


@export_group("Preview")
@export var preview := true

@export_group("Palette")
@export var core_color := Color(1.0, 0.96, 0.88):
	set(v): core_color = v; _refresh()
@export var glow_color := Color(0.42, 0.6, 1.0):
	set(v): glow_color = v; _refresh()
@export var spark_color := Color(0.75, 0.86, 1.0):
	set(v): spark_color = v; _refresh()

@export_group("Look")
@export_range(0.0, 18.0, 0.1) var bolt_emission := 4.4:
	set(v): bolt_emission = v; _refresh()
@export_range(0.0, 8.0, 0.1) var glow_emission := 1.9:
	set(v): glow_emission = v; _refresh()
@export_range(0.0, 12.0, 0.1) var spark_emission := 5.5:
	set(v): spark_emission = v; _refresh()
@export_range(0.0, 0.3, 0.005) var bolt_jaggedness := 0.075:
	set(v): bolt_jaggedness = v; _refresh()
@export_range(0.2, 1.0, 0.01) var bolt_sharpness := 0.34:
	set(v): bolt_sharpness = v; _refresh()
@export_range(1.0, 3.5, 0.05) var glow_width := 1.7:
	set(v): glow_width = v; _refresh()
@export_range(0.005, 0.3, 0.005) var flicker_dt := 0.045:
	set(v): flicker_dt = v; _refresh()

@export_group("Layout")
@export_range(0.1, 5.0, 0.01) var effect_scale := 1.0:
	set(v): effect_scale = v; _refresh()

@export_group("Speed")
@export_range(0.1, 3.0, 0.01) var effect_speed := 1.0:
	set(v): effect_speed = v; _refresh()

@export_group("Textures")
@export var glow_texture: Texture2D = preload("res://assets/vfx/sources/33a49af5fbfca3c6ad50/texture.res"):
	set(v): glow_texture = v; _refresh()
@export var streak_texture: Texture2D = preload("res://assets/vfx/sources/7ba83c1f7b0e9719534f/texture.res"):
	set(v): streak_texture = v; _refresh()
@export var star_texture: Texture2D = preload("res://assets/vfx/sources/96d99f9415c238207665/texture.res"):
	set(v): star_texture = v; _refresh()
@export var spark_texture: Texture2D = preload("res://assets/vfx/sources/ee2f42f6d681cb4e2be0/texture.res"):
	set(v): spark_texture = v; _refresh()

var _anim: AnimationPlayer
var _et := 0.0
var _ft := 0.0
var _rng := RandomNumberGenerator.new()
var _bolts: Array = []


func _anim_name() -> String:
	return "strike"


func _anim_len() -> float:
	return 2.0


func _ready() -> void:
	_anim = get_node_or_null("AnimationPlayer")
	if _anim != null:
		_anim.assigned_animation = _anim_name()
	_bind()
	_apply_look()
	set_process(true)


func _bind() -> void:
	pass


func _redraw() -> void:
	pass


func _bind_bolt(prefix: String) -> Dictionary:
	var gmi := get_node_or_null(prefix + "Glow") as MeshInstance3D
	var cmi := get_node_or_null(prefix + "Core") as MeshInstance3D
	if gmi == null or cmi == null:
		return {}
	var h := {
		"glow_mi": gmi, "glow_im": gmi.mesh, "glow_mat": gmi.material_override,
		"core_mi": cmi, "core_im": cmi.mesh, "core_mat": cmi.material_override,
	}
	_bolts.append(h)
	return h


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
		if _et >= _anim_len():
			_et = 0.0
		if _anim != null:
			_anim.seek(_et, true)
	_ft += dt
	if _ft >= flicker_dt:
		_ft -= flicker_dt
		_redraw()


func _refresh() -> void:
	if is_node_ready():
		_apply_look()


func _apply_look() -> void:
	scale = Vector3.ONE * effect_scale
	if _anim != null:
		_anim.speed_scale = maxf(effect_speed, 0.0)
	for h in _bolts:
		if h.is_empty():
			continue
		var cm: ShaderMaterial = h["core_mat"]
		if cm != null:
			cm.set_shader_parameter("core_color", core_color)
			cm.set_shader_parameter("glow_color", core_color)
			cm.set_shader_parameter("emission", bolt_emission)
		var gm: ShaderMaterial = h["glow_mat"]
		if gm != null:
			gm.set_shader_parameter("color", glow_color)
			gm.set_shader_parameter("emission", glow_emission)
	for ch in get_children():
		if not (ch is MeshInstance3D):
			continue
		var m := (ch as MeshInstance3D).material_override
		if not (m is ShaderMaterial):
			continue
		var sm: ShaderMaterial = m
		var nm := String(ch.name)
		if nm.ends_with("Streak"):
			sm.set_shader_parameter("color", core_color)
			sm.set_shader_parameter("emission", spark_emission)
			sm.set_shader_parameter("tex", streak_texture)
		elif nm.ends_with("Star"):
			sm.set_shader_parameter("color", core_color)
			sm.set_shader_parameter("emission", spark_emission)
			sm.set_shader_parameter("tex", star_texture)
		elif nm.ends_with("FlareGlow"):
			sm.set_shader_parameter("color", glow_color)
			sm.set_shader_parameter("emission", spark_emission)
			sm.set_shader_parameter("tex", glow_texture)
		elif nm == "GroundGlow":
			sm.set_shader_parameter("tex", glow_texture)
		elif nm.begins_with("Glint") or nm.begins_with("Ember"):
			sm.set_shader_parameter("color", spark_color)
			sm.set_shader_parameter("emission", spark_emission)
			sm.set_shader_parameter("tex", spark_texture)


func _jagged3d(a: Vector3, b: Vector3, jag: float) -> Array:
	var d := b - a
	var length := d.length()
	if length < 0.001:
		return [a, b]
	var dir := d / length
	var ref := Vector3.UP
	if absf(dir.dot(ref)) > 0.9:
		ref = Vector3.RIGHT
	var u := dir.cross(ref).normalized()
	var v := dir.cross(u).normalized()
	var segs := clampi(int(length / lerpf(0.2, 0.5, bolt_sharpness)) + 2, 3, 15)
	var amp := jag * length
	var pts: Array = []
	for i in range(segs + 1):
		var t := float(i) / float(segs)
		var ej := 0.0 if (i == 0 or i == segs) else 1.0
		var off := (u * _rng.randf_range(-1.0, 1.0) + v * _rng.randf_range(-1.0, 1.0)) * amp * ej
		pts.append(a.lerp(b, t) + off)
	return pts


func _emit_trail(im: ImmediateMesh, pts: Array, width: float, taper: float) -> void:
	var segs := pts.size() - 1
	if segs < 1:
		return
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in range(segs + 1):
		var t := float(i) / segs
		var pa: Vector3 = pts[maxi(i - 1, 0)]
		var pb: Vector3 = pts[mini(i + 1, segs)]
		var tan := pb - pa
		if tan.length() < 0.0001:
			tan = Vector3(0.0, 1.0, 0.0)
		tan = tan.normalized()
		var hw := width * lerpf(0.55 + 0.45 * sin(t * PI), 1.0 - t, taper) * 0.5
		var col := Color(hw, 0.0, 0.0)
		im.surface_set_normal(tan)
		im.surface_set_color(col)
		im.surface_set_uv(Vector2(0.0, t))
		im.surface_add_vertex(pts[i])
		im.surface_set_normal(tan)
		im.surface_set_color(col)
		im.surface_set_uv(Vector2(1.0, t))
		im.surface_add_vertex(pts[i])
	im.surface_end()


func _bolt_clear(h: Dictionary) -> void:
	if h.is_empty():
		return
	h["glow_im"].clear_surfaces()
	h["core_im"].clear_surfaces()


func _bolt_draw(h: Dictionary, a: Vector3, b: Vector3, width: float, hot: bool) -> void:
	if h.is_empty():
		return
	var pts := _jagged3d(a, b, bolt_jaggedness)
	var d := b - a
	var dir := Vector3.UP
	if d.length() > 0.001:
		dir = d.normalized()
	var ref := Vector3.UP
	if absf(dir.dot(ref)) > 0.9:
		ref = Vector3.RIGHT
	var u := dir.cross(ref).normalized()
	var amp := bolt_jaggedness * d.length()
	var glow_pts: Array = [a, a.lerp(b, 0.5) + u * amp * 0.4, b]
	_emit_trail(h["glow_im"], glow_pts, glow_width * width, 0.0)
	_emit_trail(h["core_im"], pts, 0.5 * width, 0.0)
	_emit_trail(h["core_im"], pts, 0.28 * width, 0.0)
	if hot:
		_emit_trail(h["core_im"], pts, 0.13 * width, 0.4)


func _bolt_path(h: Dictionary, pts: Array, width: float, hot: bool, taper: float) -> void:
	if h.is_empty():
		return
	var full: Array = []
	for i in range(pts.size() - 1):
		var seg := _jagged3d(pts[i], pts[i + 1], bolt_jaggedness * 0.7)
		if i == 0:
			full.append_array(seg)
		else:
			for j in range(1, seg.size()):
				full.append(seg[j])
	if full.size() < 2:
		return
	_emit_trail(h["glow_im"], pts, glow_width * width, 0.0)
	_emit_trail(h["core_im"], full, 0.5 * width, taper)
	_emit_trail(h["core_im"], full, 0.28 * width, taper)
	if hot:
		_emit_trail(h["core_im"], full, 0.13 * width, maxf(taper, 0.35))
