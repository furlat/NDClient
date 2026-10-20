extends Node3D
## One movable light owner, four decorative wisps. No donor demo actor or impact.
const Graph = preload("res://assets/vfx/sources/1d02b6d800655ef86df2/resource_graph.gd")
const Materials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const Palette = preload("res://assets/vfx/sources/386bc581a35eb3b9ee50/spatial_energy_palette.gd")
const DONOR = "res://assets/vfx/extensions/followup-20261020/sources/f7d5a777f01aebd9e6a4/VFX_Healing_Orb.tscn"
var specification: Dictionary = {}
var wisps: Array[MeshInstance3D] = []
var materials: Array[ShaderMaterial] = []
var corona_materials: Array[ShaderMaterial] = []
var light: OmniLight3D
var owner_state: Dictionary = {}
var age_seconds: float = 0.0
var current_owner: Dictionary = {}


static func make_component(input: Dictionary) -> Node3D:
	var effect: Node3D = VfxPackageIO_8289e80413.resource("res://assets/vfx/extensions/followup-20261020/sources/8289e804134694b54536/dancing_lights.gd").new()
	effect.specification = input.duplicate(true)
	return effect


func set_owner_state(value: Dictionary) -> bool:
	# Only an explicitly supplied matching occurrence may change this instance.
	var expected: String = str(specification.get("owner_uuid", ""))
	if not expected.is_empty() and str(value.get("owner_uuid", "")) != expected:
		return false
	owner_state = value.duplicate(true)
	if light != null:
		sample(age_seconds)
	return true


func observed_owner(seconds: float) -> Dictionary:
	# Fixture rows replay supplied observations; seconds never solve a rule/turn.
	var state: Dictionary = specification.get("state", {}).duplicate(true)
	for row in specification.get("review_owner_states", []):
		if seconds >= float(row.seconds):
			state.merge(row.state, true)
	if not owner_state.is_empty():
		state = owner_state.duplicate(true)
	var expected: String = str(specification.get("owner_uuid", ""))
	if expected.is_empty():
		return {"present": true, "observed": true, "suppressed": false, "visibility": 1.0}
	if str(state.get("owner_uuid", "")) != expected:
		return {"present": false, "observed": false, "suppressed": true, "visibility": 0.0}
	return state


func owner_visibility(state: Dictionary) -> float:
	if not bool(state.get("present", false)) or not bool(state.get("observed", false)) or bool(state.get("suppressed", true)):
		return 0.0
	return clampf(float(state.get("visibility", 1.0)), 0.0, 1.0)


func prepare() -> void:
	var source: Node3D = VfxPackageIO_8289e80413.resource(DONOR).instantiate()
	var selected: MeshInstance3D = source.get_node("sphere")
	var selected_corona: MeshInstance3D = source.get_node("objectflare")
	for index in 4:
		var wisp := MeshInstance3D.new()
		wisp.name = "Wisp" + str(index)
		wisp.mesh = selected.mesh
		wisp.material_override = Graph.clone_value(selected.material_override,{})
		var material: ShaderMaterial = wisp.material_override
		var shader := Shader.new()
		shader.code = Materials.expand_shader(material.shader.code,material.shader.resource_path.get_base_dir()).replace("TIME", "wisp_clock").replace("shader_type spatial;", "shader_type spatial;\nuniform float wisp_clock=0.0;")
		Materials.replace_shader(material,shader)
		material.set_shader_parameter("Color_Intensity2",0.7)
		material.set_shader_parameter("Base_noise2",VfxPackageIO_8289e80413.resource("res://assets/vfx/sources/900721c102c94ad02849/texture.res"))
		material.set_shader_parameter("Speed_XY2",Vector2(0,0.5))
		Palette.apply(material,specification.palette,specification.palette_options)
		wisp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(wisp)
		wisps.append(wisp)
		materials.append(material)
		var corona := MeshInstance3D.new()
		corona.name = "PolarCorona"
		corona.mesh = selected_corona.mesh
		corona.material_override = Graph.clone_value(selected_corona.material_override,{})
		var corona_material: ShaderMaterial = corona.material_override
		var corona_shader := Shader.new()
		corona_shader.code = Materials.expand_shader(corona_material.shader.code,corona_material.shader.resource_path.get_base_dir()).replace("TIME","wisp_clock").replace("shader_type spatial;","shader_type spatial;\nuniform float wisp_clock=0.0;")
		Materials.replace_shader(corona_material,corona_shader)
		corona_material.set_shader_parameter("Transparency",0.55)
		corona_material.set_shader_parameter("Intensity",1.0)
		corona_material.set_shader_parameter("Enable_Proximity_Fade",false)
		Palette.apply(corona_material,specification.palette,specification.palette_options)
		corona.scale = Vector3.ONE*3.0
		corona.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		wisp.add_child(corona)
		corona_materials.append(corona_material)
	# Geometry and its material are retained; all unrelated demonstration nodes,
	# the cast-to-demo-character travel, cylinder and healing payload are excluded.
	source.free()
	light = OmniLight3D.new()
	light.name = "OneOpticalOwner"
	light.position.y = 0.95
	light.omni_range = 6.0
	light.light_energy = 0.8
	light.light_color = Color("afd4e2")
	light.set_meta("factory_light_role","optical")
	add_child(light)


func sample(seconds: float) -> void:
	if wisps.is_empty(): prepare()
	age_seconds = seconds
	current_owner = observed_owner(seconds)
	var owner_alpha: float = owner_visibility(current_owner)
	var phase: String = specification.phase
	var envelope: float = 1.0
	if phase == "apply": envelope = smoothstep(0.0,0.5,seconds)
	elif phase == "remove": envelope = 1.0-smoothstep(0.0,0.5,seconds)
	var clock: float = float(current_owner.get("visual_age_seconds", seconds + float(specification.get("source_time_offset",0.0))))
	envelope *= owner_alpha
	for index in wisps.size():
		var angle: float = float(index)*TAU/4.0 + clock*PI
		var radius: float = 0.18 if index%2 == 0 else 0.26
		wisps[index].position = Vector3(cos(angle)*radius,0.95+float(index%2)*0.19+0.035*sin(clock*PI+float(index)),sin(angle)*radius)
		wisps[index].visible = envelope > 0.001
		wisps[index].scale = Vector3.ONE*(0.11+float(index%2)*0.025)*maxf(0.001,envelope)
		materials[index].set_shader_parameter("wisp_clock",clock+float(index)*0.25)
		corona_materials[index].set_shader_parameter("wisp_clock",clock+float(index)*0.25)
	light.light_energy = 0.8*envelope if bool(current_owner.get("optical_active", specification.get("optical_active", true))) else 0.0


func capture_observation() -> Dictionary:
	return {"source_scene": DONOR,"extracted_node":"sphere","decorative_wisps":wisps.size(),"optical_owners":1,"phase":specification.phase,"demo_actor_included":false, "owner_uuid":specification.get("owner_uuid", ""), "optical_source_uuid":specification.get("optical_source_uuid", ""), "state":current_owner.duplicate(true), "light_energy":light.light_energy if light != null else 0.0, "rule_solver":false, "active_optical_owners":1 if light != null and light.is_visible_in_tree() and light.light_energy > 0.001 else 0, "owner_ground_world":global_position, "optical_world_position":light.global_position if light != null else Vector3.ZERO}

const VfxPackageIO_8289e80413 = preload("res://assets/vfx/extensions/followup-20261020/scoped_resource_io.gd")
