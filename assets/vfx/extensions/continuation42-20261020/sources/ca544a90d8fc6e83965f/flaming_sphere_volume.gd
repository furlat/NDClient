extends "res://assets/vfx/extensions/continuation42-20261020/sources/0393b1bb8b406965db34/flaming_sphere.gd"
## Intentional source-art candidate: native K1 fire volume, flame billows and
## embers. State/trajectory/aura/ram/trail ownership stay in their existing seams.
const DonorScene = preload("res://assets/vfx/sources/7fb2e55699a318c2dafb/donor_scene.gd")
const FIRE_SCENE = "res://assets/vfx/extensions/continuation42-20261020/sources/a683ff6d7af76bf1a716/VFX_FireBall_K1.tscn"
const PROJECTILE_TRAIL_SCRIPT = "res://assets/vfx/extensions/continuation42-20261020/sources/24b2128a6f0029adfe71/GPUTrail3D.gd"
var flame_root: Node3D
var emitters: Array[GPUParticles3D] = []
var flame_materials: Array[ShaderMaterial] = []


static func make_component(input: Dictionary) -> Node3D:
	assert(not str(input.get("entity_uuid", "")).is_empty())
	assert(not str(input.get("existence_condition_uuid", "")).is_empty())
	var node: Node3D = VfxPackageIO_ca544a90d8.resource("res://assets/vfx/extensions/continuation42-20261020/sources/ca544a90d8fc6e83965f/flaming_sphere_volume.gd").new()
	node.specification = input.duplicate(true)
	node.set_body_state(input.get("state", {}))
	node.prepare()
	return node


func prepare() -> void:
	super.prepare()
	var original: Node3D = DonorScene.instantiate(VfxPackageIO_ca544a90d8.resource(FIRE_SCENE), [PROJECTILE_TRAIL_SCRIPT])
	var resources: Dictionary = {}
	Fire.Graph.native_sampler_scopes += 1
	Fire.Graph.isolate_node(original, resources)
	Fire.Graph.native_sampler_scopes -= 1
	var volume: MeshInstance3D = original.get_node("sphere1")
	core.mesh = volume.mesh
	core_material = Fire.finite(volume.material_override, .11)
	core.material_override = core_material
	flame_root = Node3D.new()
	flame_root.name = "NativeVolumeFlames"
	add_child(flame_root)
	# Select the actual native emitter nodes. The projectile-history trail and
	# OmniLight are not part of this ground construct's body composition.
	for label in ["firex2", "smallparticles_constant"]:
		var emitter: GPUParticles3D = original.get_node(label)
		emitter.owner = null
		original.remove_child(emitter)
		flame_root.add_child(emitter)
		emitter.local_coords = true
		emitter.use_fixed_seed = true
		emitter.seed = 9275 + emitters.size()
		emitter.fixed_fps = 144
		emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		emitter.emitting = false
		if label == "firex2":
			var process: ParticleProcessMaterial = emitter.process_material
			process.emission_sphere_radius = .25
			process.scale_min = .75
			process.scale_max = 1.0
		var adapted: ShaderMaterial = Fire.finite(emitter.material_override, .32)
		emitter.material_override = adapted
		flame_materials.append(adapted)
		emitters.append(emitter)
	original.free()


func sample(seconds: float) -> void:
	super.sample(seconds)
	Fire.clock(core_material, seconds, envelope * .3)
	flame_root.position = center
	flame_root.scale = Vector3.ONE * .65
	for index in emitters.size():
		emitters[index].emitting = envelope > .001
		Fire.clock(flame_materials[index], seconds, envelope * .7)
	flame_root.visible = envelope > .001


func capture_observation() -> Dictionary:
	var result: Dictionary = super.capture_observation()
	result["volume_source_scene"] = FIRE_SCENE
	result["volume_layers"] = ["sphere1", "firex2", "smallparticles_constant"]
	result["optical_lights"] = 0
	result["trajectory_damage_and_trail_unchanged"] = true
	result["seek_qualified"] = false
	return result

const VfxPackageIO_ca544a90d8 = preload("res://assets/vfx/extensions/continuation42-20261020/scoped_resource_io.gd")
