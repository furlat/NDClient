extends RefCounted
## Exact accepted bodyModifier through the existing condition_film receiver.
## Data selects source, ramp, tint and gain. No spell-name lookup or body proxy.
const Sources = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const Palette = preload("res://assets/vfx/sources/647f3fff65b8fa219c13/packed_colour.gd")
const FilmSource = preload("res://assets/vfx/sources/13ce1a6eecd7821eb0bb/accepted_film_source_v176.gd")
const Finish = "res://assets/vfx/sources/b81ae4efa9b7ea04cf05/accepted_film_finish_v176.gdshaderinc"
var shaders: Dictionary = {}
var surfaces: Dictionary = {}
var active_surfaces: Dictionary = {}


func prepare(original: ShaderMaterial, specification: Dictionary) -> Shader:
	assert(specification.has("source") and specification.has("colours"))
	var identity: Array = [original.shader.get_instance_id()]
	if shaders.has(identity):
		return shaders[identity]
	var code := Sources.expand_shader(original.shader.code, original.shader.resource_path.get_base_dir())
	var sampler := "texture(condition_film,vec2(cell_uv.x,(float(condition_film_frame%condition_film_frames)+cell_uv.y)/float(condition_film_frames))).r*255.0/239.0"
	assert(code.count(sampler) == 1, "Accepted Film requires the existing exact condition_film branch")
	code = code.replace(sampler, "factory_film_scalar(cell_uv)")
	var function_begin := code.find("vec4 character_material(")
	code = code.insert(function_begin, VfxPackageIO_acc2f171e4.text(Finish) + "\n")
	var shader := Shader.new()
	shader.code = code
	shader.set_meta("factory_actor_material", "rage_film")
	shaders[identity] = shader
	return shader


static func admitted(specification: Dictionary) -> bool:
	var owner: Dictionary = specification.get("owner_projection", {})
	if owner.get("admitted", false) != true or owner.get("suppressed", false) or str(owner.get("owner_uuid", "")).is_empty():
		return false
	if owner.get("behavior_id", "") != "class_feature.barbarian.raging" or owner.get("actor_id", "") != specification.get("actor", ""):
		return false
	if owner.owner_uuid != specification.get("owner_uuid", ""):
		return false
	if float(specification.get("begin", -1.0)) < float(owner.get("begin_seconds", 0.0)):
		return false
	var removed: Variant = owner.get("removed_seconds")
	if removed != null and (not (removed is float or removed is int) or not is_finite(float(removed))):
		return false
	if removed != null and float(removed) >= 0.0 and float(removed) < float(owner.get("begin_seconds", 0.0)):
		return false
	if specification.get("requires_frenzied_child", false):
		var child: Dictionary = owner.get("frenzied_child", {})
		return child.get("admitted", false) == true and not child.get("suppressed", false) and not str(child.get("owner_uuid", "")).is_empty() and child.get("behavior_id", "") == "class_feature.barbarian.frenzied" and child.get("parent_owner_uuid", "") == owner.owner_uuid
	return true


static func strength(specification: Dictionary, age: float) -> float:
	if not admitted(specification):
		return 0.0
	# Original preview.js gate: .18-second smooth rise and .35-second smooth
	# return. Application/removal times are supplied, never game durations.
	var begin := float(specification.begin)
	var removed: Variant = specification.owner_projection.get("removed_seconds")
	var has_removal: bool = removed != null and float(removed) >= 0.0
	var rise := maxf(.0001, float(specification.fade_in_seconds))
	var tail := maxf(.0001, float(specification.fade_out_seconds))
	var value := smoothstep(begin, begin + rise, age)
	if has_removal:
		value *= 1.0 - smoothstep(float(removed), float(removed) + tail, age)
	for interval in specification.get("suppression_intervals", []):
		if (has_removal and age >= float(removed) and float(removed) >= float(interval[0]) and float(removed) < float(interval[1])) or (age >= float(interval[0]) and age < float(interval[1])):
			return 0.0
	return value


func begin_sample() -> void:
	active_surfaces.clear()


func source_for(world: Node, specification: Dictionary, strength: float, local_age: float) -> Texture2D:
	if strength <= 0.0 or not admitted(specification):
		return null
	var identity: String = str(world.get_instance_id()) + ":" + str(specification.actor) + ":" + str(specification.owner_uuid) + ":" + JSON.stringify(specification.material.source)
	if not surfaces.has(identity):
		surfaces[identity] = FilmSource.make(world, specification.material.source)
	var surface: Dictionary = surfaces[identity]
	active_surfaces[identity] = true
	FilmSource.sample(surface, local_age)
	return surface.viewport.get_texture()


func end_sample() -> void:
	for identity in surfaces.keys():
		if not active_surfaces.has(identity):
			FilmSource.close(surfaces[identity])
			surfaces.erase(identity)


func bind(material: ShaderMaterial, specification: Dictionary, strength: float, local_age: float, texture: Texture2D) -> void:
	if not material.has_meta("factory_film_original_parameters"):
		var original := {}
		for name in ["condition_film_enabled", "condition_film_palette", "condition_film_strength", "condition_film_gain", "condition_film_weight"]:
			original[name] = material.get_shader_parameter(name)
		material.set_meta("factory_film_original_parameters", original)
	var palette := PackedVector3Array()
	for colour in specification.colours:
		palette.append(Palette.rgb(int(colour)))
	assert(palette.size() == 3, "Accepted Film uses three encoded RGB stops")
	palette.append(Palette.rgb(int(specification.tint)))
	material.set_shader_parameter("factory_rage_film_surface", texture)
	material.set_shader_parameter("factory_rage_film_strength", strength)
	material.set_shader_parameter("factory_rage_film_age", local_age)
	material.set_shader_parameter("condition_film_enabled", texture != null and strength > 0.0)
	material.set_shader_parameter("condition_film_palette", palette)
	material.set_shader_parameter("condition_film_strength", strength)
	material.set_shader_parameter("condition_film_gain", float(specification.gain))
	material.set_shader_parameter("condition_film_weight", float(specification.tint_weight))


func restore(material: ShaderMaterial) -> void:
	if not material.has_meta("factory_film_original_parameters"):
		return
	for name in material.get_meta("factory_film_original_parameters"):
		material.set_shader_parameter(name, material.get_meta("factory_film_original_parameters")[name])
	material.remove_meta("factory_film_original_parameters")
	material.set_shader_parameter("factory_rage_film_surface", null)


func reset() -> void:
	for surface in surfaces.values():
		FilmSource.close(surface)
	surfaces.clear()
	active_surfaces.clear()
	shaders.clear()

const VfxPackageIO_acc2f171e4 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
