extends "res://assets/vfx/sources/a4fd0883f0b17d893a03/base.gd"
## Accepted Sacred Flame donor palette, horizontal beam placement and source shader clock.
var mats = []
var axis = Vector3.RIGHT
var beam_origin = Vector3(-6.0, 0.0, 0.0)


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/3eeeebacf2494b475d88/sunbeam.gd", input)


func prepare_materials(_node: Node) -> void:
	pass


func apply_scene_edits(node: Node) -> void:
	var heading = float(settings.heading) * PI / 4.
	axis = Vector3(cos(heading), 0, sin(heading))
	node.scale.y = .81649658
	var donor = DonorScene.instantiate(VfxPackageIO_3eeeebacf2.resource(settings.source_path), [])
	ResourceGraph.isolate_node(donor, {})
	node.add_child(donor)
	donor.basis = Basis(Vector3.UP, -heading) * Basis(Vector3.FORWARD, PI / 2.)
	donor.scale = Vector3(.14, .24, .14)
	donor.position = -axis * 6.
	prepare_beam(donor)


func advance_lifecycle(_delta: float) -> void:
	tick += 1
	var age = float(tick - 1) / float(parameters.simulation_hz)
	for mat in mats:
		mat.set_shader_parameter("source_clock", age * 1.8)


func holy(c: Color) -> Color:
	if c.s < .12:
		return c
	return Color.from_hsv(.12, c.s * .8, c.v, c.a)


func recolor(r: Resource):
	if r == null or visited.has(r.get_instance_id()):
		return
	visited[r.get_instance_id()] = true
	for p in r.get_property_list():
		if not (int(p.usage) & PROPERTY_USAGE_STORAGE):
			continue
		var v = r.get(p.name)
		if v is Color:
			r.set(p.name, holy(v))
		elif v is PackedColorArray:
			var colors = PackedColorArray()
			for c in v:
				colors.append(holy(c))
			r.set(p.name, colors)
		elif v is Resource:
			recolor(v)


func prepare_beam(n: Node):
	n.set_script(null)
	for child in n.find_children("*", "", true, false):
		for p in child.get_property_list():
			if int(p.usage) & PROPERTY_USAGE_STORAGE:
				var v = child.get(p.name)
				if v is Resource:
					v = v.duplicate(true)
					child.set(p.name, v)
					recolor(v)
		if child is GPUParticles3D:
			child.speed_scale = 1.8
			child.use_fixed_seed = true
			child.seed = 7381
			child.visibility_aabb = AABB(Vector3(-80, -80, -80), Vector3(160, 160, 160))
		if child is GeometryInstance3D:
			child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# Same retired inner cylinder and soil decal as accepted Sacred Flame; launch flare retained separately.
			if (
				child.name
				in [
					"inner_base",
					"windsoil",
					"groundmark1",
					"floorflash",
					"floorflash2",
					"itemflash"
				]
			):
				child.layers = 0
			if child.material_override is ShaderMaterial:
				var m = child.material_override.duplicate(true)
				var original = m.shader
				var sh = Shader.new()
				var code = original.code.replace("TIME", "source_clock")
				code = (
					code
					. replace(
						"shader_type spatial;",
						"shader_type spatial; uniform float source_clock=0.; uniform vec3 beam_axis=vec3(1,0,0); uniform vec3 beam_origin=vec3(-6.,0.,0.);"
					)
				)
				var start = code.find("void fragment()")
				var at = code.find("{", start) + 1
				if start >= 0:
					code = (
						code
						. insert(
							at,
							"\nvec3 solar_world=(INV_VIEW_MATRIX*vec4(VERTEX,1.)).xyz;float along=dot(solar_world-beam_origin,beam_axis);if(along<0.||along>12.)discard;float reach=12.*smoothstep(.30,.62,source_clock);if(along>reach)discard;\n"
						)
					)
				var end = code.find("\n}", code.find("void fragment()"))
				if end < 0:
					end = code.rfind("}")
				code = (
					code
					. insert(
						end,
						"\nvec3 light_energy=ALBEDO+EMISSION;float energy=max(light_energy.r,max(light_energy.g,light_energy.b));ALPHA*=smoothstep(.025,.24,energy)*(1.-smoothstep(1.8,2.5,source_clock));float v=clamp(energy,0.,1.);vec3 gold=mix(vec3(.46,.32,.08),vec3(1.,.82,.31),smoothstep(.05,.7,v));gold=mix(gold,vec3(1.,.80,.36),smoothstep(.72,1.2,energy));ALBEDO=gold;EMISSION=vec3(0.);\n"
					)
				)
				sh.code = code
				NativeShaderBindings.replace_shader(m, sh)
				for u in original.get_shader_uniform_list():
					var tex = original.get_default_texture_parameter(u.name)
					if tex != null and m.get_shader_parameter(u.name) == null:
						m.set_shader_parameter(u.name, tex)
				m.set_shader_parameter("beam_axis", axis)
				m.set_shader_parameter("beam_origin", beam_origin)
				child.material_override = m
				mats.append(m)
	var flare = n.get_node("muzzle")
	flare.process_material = flare.process_material.duplicate(true)
	flare.process_material.scale_min *= .18
	flare.process_material.scale_max *= .18
	var ap = n.get_node("AnimationPlayer")
	var anim = ap.get_animation("Init").duplicate(true)
	for tr in range(anim.get_track_count()):
		for k in range(anim.track_get_key_count(tr)):
			var v = anim.track_get_key_value(tr, k)
			if v is Color:
				anim.track_set_key_value(tr, k, holy(v))
	var lib = ap.get_animation_library("")
	lib.remove_animation("Init")
	lib.add_animation("Init", anim)
	ap.speed_scale = 1.8
	ap.play("Init")

const VfxPackageIO_3eeeebacf2 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
