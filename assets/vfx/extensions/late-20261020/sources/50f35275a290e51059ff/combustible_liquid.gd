extends "res://assets/vfx/extensions/late-20261020/sources/979ecf1a1d9d8264d287/reactive_liquid.gd"
## Original oil deposit, locally replaced by fire and retired by committed douse.
const Emitters = preload("res://assets/vfx/extensions/late-20261020/sources/640361420840ef7d5319/source_emitters.gd")
const Materials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
var flames: Array[GPUParticles3D] = []

static func make_component(input: Dictionary) -> Node3D:
	var instance := VfxPackageIO_50f35275a2.resource("res://assets/vfx/extensions/late-20261020/sources/50f35275a290e51059ff/combustible_liquid.gd").new() as Node3D
	instance.settings=input.duplicate(true)
	instance.settings.charge_at=0.
	instance.simulation=JSON.parse_string(VfxPackageIO_50f35275a2.text(input.simulation))
	instance._build()
	return instance

func _build() -> void:
	super._build()
	var shader := Shader.new()
	var code: String = material.shader.code
	code=code.insert(code.rfind("}"),"\nALBEDO=mix(ALBEDO,vec3(.07,.045,.025),state.z); ALPHA*=1.-state.z*.88;\n")
	shader.code=code
	Materials.replace_shader(material,shader)
	material.set_shader_parameter("material_kind",1)
	for index in 12:flames.append(Emitters.make(self,"fire",index))

func set_transition_events(value: Array) -> void:
	var error: String=transition_state.replace(value,["ignite","douse","clear"])
	if not error.is_empty():push_error(error);return
	events=transition_state.events
	contacts=transition_state.contacts
	regions=transition_state.regions
	operations=transition_state.operations
	transition_state.bind(material)
	for selected in electricity.materials:transition_state.bind(selected)

func sample(seconds: float) -> void:
	super.sample(seconds)
	for index in flames.size():
		var strength := 0.
		if not support_points.is_empty():
			var point: Vector3=support_points[(index*13+4)%support_points.size()]
			flames[index].position=point+Vector3.UP*.025
			var state: Vector4=transition_state.state_at(Vector2(point.x,point.z),seconds)
			strength=state.z*(1.-state.w)*float(state_values.retirement)
		Emitters.sample(flames[index],seconds,strength)
	state_values["fire_emitters"]=flames.size()

const VfxPackageIO_50f35275a2 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
