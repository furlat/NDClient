extends Node3D
## Original native 160-particle deposit and density field, with state fronts.
## Freeze/thaw retains particle positions and exactly the same coverage function.
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const Electric = preload("res://assets/vfx/extensions/late-20261020/sources/038f154b06649f707e70/live_network.gd")
const Conduction = preload("res://assets/vfx/extensions/late-20261020/sources/cf721dfb3774a72b8d38/liquid_conduction.gd")
const SOURCE_SHADER := "res://assets/vfx/extensions/late-20261020/sources/0d571bb34ff4e64a72e8/3275d4b59517d2b753b66572c20f0999d6843eff15b6f4b4db41a3fa9c977f23.gdshader"

var settings: Dictionary = {}
var simulation: Dictionary = {}
var plane: MeshInstance3D
var droplets: MultiMeshInstance3D
var material: ShaderMaterial
var fluid := PackedVector4Array()
var support_points: Array[Vector3] = []
var state_values: Dictionary = {}
var electricity: Node3D
var conduction_fluid := PackedVector4Array()
var conduction_layout: Dictionary = {}

static func make_component(input: Dictionary) -> Node3D:
	var instance := VfxPackageIO_e590c9ae3b.resource("res://assets/vfx/extensions/late-20261020/sources/e590c9ae3baae472d4aa/liquid_state.gd").new() as Node3D
	instance.settings = input.duplicate(true)
	instance.simulation = JSON.parse_string(VfxPackageIO_e590c9ae3b.text(input.simulation))
	instance._build()
	return instance

func _build() -> void:
	var shader := Shader.new()
	var code := VfxPackageIO_e590c9ae3b.text(SOURCE_SHADER)
	code = code.replace("void fragment(){", """uniform sampler2D frost : repeat_enable, filter_linear;
uniform float freeze_fraction = 0.;
uniform float thaw_fraction = 0.;
uniform float transition_seconds = 0.;
uniform vec2 contact_point = vec2(0.);
uniform bool frozen_blood = false;
uniform float retirement = 1.;
void fragment(){""")
	code = code.replace("ALBEDO=mix(mix(dark.rgb,mid.rgb,shade),light.rgb,glint);", """vec3 liquid = mix(mix(dark.rgb,mid.rgb,shade),light.rgb,glint);
 float distance_from_contact = length(point-contact_point);
 float ice_noise = texture(frost,point*.7).r;
 float freeze_front = smoothstep(0.,.4,transition_seconds-distance_from_contact*.38-ice_noise*.12);
 float frozen = freeze_fraction*freeze_front*(1.-thaw_fraction);
 float crystal = texture(frost,point*.39+vec2(.17,.31)).r;
 vec3 icy = mix(vec3(.18,.37,.53),vec3(.55,.76,.86),crystal*.8);
 icy = frozen_blood ? mix(liquid,icy,.43) : icy;
 ALBEDO = mix(liquid,icy,frozen);
 EMISSION = icy * frozen * .035;""")
	code = code.replace("ALPHA=coverage_alpha*end*min(1.0,body_alpha+glint*.48);", "ALPHA=coverage_alpha*end*min(1.0,body_alpha+glint*.48)*retirement;")
	shader.code = code
	material = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("marble", VfxPackageIO_e590c9ae3b.resource("res://assets/vfx/extensions/late-20261020/sources/d9693b7f9e0749d03a88/texture.res"))
	material.set_shader_parameter("frost", SourceMaterials.raw_texture("res://assets/vfx/sources/9dd4b1e9c98d16632575/texture.res"))
	var colours: Array = settings.get("colours", ["315464", "548695", "9db5ba"])
	for index in 3:
		material.set_shader_parameter(["dark", "mid", "light"][index], Color(colours[index]))
	material.set_shader_parameter("body_alpha", float(settings.get("opacity", .65)))
	material.set_shader_parameter("material_kind", 0 if settings.get("kind", "water") == "water" else 2)
	material.set_shader_parameter("frozen_blood", settings.get("kind") == "blood")
	plane = MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(4,4)
	plane.mesh = mesh
	plane.material_override = material
	plane.position.y = .012
	plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(plane)
	droplets = MultiMeshInstance3D.new()
	var spheres := MultiMesh.new()
	spheres.transform_format = MultiMesh.TRANSFORM_3D
	var ball := SphereMesh.new()
	ball.radius = .04
	ball.height = .08
	ball.radial_segments = 8
	ball.rings = 4
	var drop_material := StandardMaterial3D.new()
	drop_material.albedo_color = Color(colours[1])
	drop_material.roughness = .25
	ball.material = drop_material
	spheres.mesh = ball
	spheres.instance_count = 160
	droplets.multimesh = spheres
	droplets.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(droplets)
	fluid.resize(160)
	if settings.has("charge_at"):
		var edges: Array = []
		var interior: bool = settings.get("charge_pattern", "") == "interior_network"
		for index in (Conduction.EDGE_COUNT if interior else 12):
			edges.append({"from":index,"to":(index+1)%12,"delay":float(index%3)*.025})
		electricity = _make_electricity({"edges":edges,
			"endpoint_count":Conduction.ANCHOR_COUNT if interior else 12,
			"width":.10 if interior else .20,"persistent":true,"density_mask":true,"charge_coil":false,
			"plane_y":.018 if interior else null,"contact_from_edges":not interior,
			"core_color":"198fe1","glow_color":"07499f"})
		add_child(electricity)

func sample(seconds: float) -> void:
	var freeze_at: float = settings.get("freeze_at", 6.0)
	var thaw_at: float = settings.get("thaw_at", 8.0)
	var remove_at: float = settings.get("remove_at", 10.0)
	var source_time := minf(seconds, freeze_at)
	var cursor := clampf(source_time * float(simulation.fps), 0.0, simulation.frames.size() - 1.0)
	var frame: Array = simulation.frames[floori(cursor)]
	var next: Array = simulation.frames[mini(simulation.frames.size() - 1, floori(cursor) + 1)]
	var blend := fposmod(cursor, 1.0)
	var values := PackedVector4Array()
	values.resize(160)
	for index in 160:
		var a: Array = frame[index]
		var b: Array = next[index]
		var point := Vector3(a[0], a[1], a[2]).lerp(Vector3(b[0], b[1], b[2]), blend)
		values[index] = Vector4(point.x, point.y, point.z, 1.0)
	_set_fluid(values)
	var thaw := smoothstep(thaw_at, thaw_at + .75, seconds)
	var retirement := 1.0 - smoothstep(remove_at, remove_at + .6, seconds)
	material.set_shader_parameter("clock", source_time)
	material.set_shader_parameter("freeze_fraction", float(seconds >= freeze_at))
	material.set_shader_parameter("transition_seconds", maxf(0.0, seconds - freeze_at))
	material.set_shader_parameter("thaw_fraction", thaw)
	material.set_shader_parameter("retirement", retirement)
	_sample_electricity(seconds, retirement)
	state_values = {"source_frame": cursor, "frozen": seconds >= freeze_at and thaw < 1.0,
		"thaw": thaw, "retirement": retirement, "source_particles": 160,
		"coverage": "original density smoothstep(.48,.66), independent of material state"}

func _make_electricity(input: Dictionary) -> Node3D:
	return Electric.make_component(input)


func _set_fluid(value: PackedVector4Array) -> void:
	fluid = value
	support_points.clear()
	for index in fluid.size():
		var point := Vector3(fluid[index].x, fluid[index].y, fluid[index].z)
		var radius := 0.0 if point.y < .03 else 1.0
		droplets.multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * radius), point))
		if point.y < .03:
			support_points.append(point)
	material.set_shader_parameter("fluid", fluid)


func _conduction_layout(support: Array[Vector3], values: PackedVector4Array) -> Dictionary:
	return Conduction.layout(support, values)


func _sample_electricity(seconds: float, retirement: float) -> void:
	if electricity != null:
		var charge_age := seconds - float(settings.charge_at)
		electricity.visible = charge_age >= 0.0 and retirement > .01
		var interior: bool = settings.get("charge_pattern", "") == "interior_network"
		if interior and support_points.size() < 2:
			electricity.hide()
			return
		if electricity.visible and support_points.size() >= (2 if interior else 12):
			var endpoints: Array = []
			if settings.get("charge_pattern", "") == "interior_network":
				if conduction_fluid != fluid:
					conduction_fluid = fluid.duplicate()
					conduction_layout = _conduction_layout(support_points, fluid)
				for point in conduction_layout.get("points", []):
					endpoints.append({"point": global_transform * point, "contact_enabled": false})
				var branches: Array = conduction_layout.get("edges", [])
				for index in electricity.ribbons.size():
					var edge := Vector2i(-1, -1) if index >= branches.size() else Vector2i(branches[index])
					electricity.ribbons[index].edge.from = edge.x
					electricity.ribbons[index].edge.to = edge.y
				electricity.set_live_endpoints(endpoints)
				electricity.set_density_field(fluid)
				electricity.settings.opacity = retirement
				electricity.sample(charge_age)
				return
			for index in 12:
				var angle := TAU * float(index) / 12.0
				var desired := Vector3(cos(angle)*1.15,0,sin(angle)*1.15)
				var nearest: Vector3 = support_points[0]
				for candidate in support_points:
					if candidate.distance_squared_to(desired) < nearest.distance_squared_to(desired):
						nearest = candidate
				var point := nearest + Vector3.UP * .04
				endpoints.append({"point": global_transform * point})
			electricity.set_live_endpoints(endpoints)
			electricity.set_density_field(fluid)
			electricity.sample(charge_age)

func capture_observation() -> Dictionary:
	return state_values.duplicate(true)

const VfxPackageIO_e590c9ae3b = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
