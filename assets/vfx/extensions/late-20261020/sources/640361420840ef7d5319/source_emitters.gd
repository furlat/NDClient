extends RefCounted
## Reuse actual LeLu emission, texture, erosion and colour resources. All nodes
## are pre-created before native scene registration; each owns its material.
const Donor = preload("res://assets/vfx/sources/7fb2e55699a318c2dafb/donor_scene.gd")
const Graph = preload("res://assets/vfx/sources/1d02b6d800655ef86df2/resource_graph.gd")
const Materials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const Fire := "res://assets/vfx/extensions/late-20261020/sources/9a1c22123583a7ddc0cd/VFX_FireDynamic_T1_cheap.tscn"
const Smoke := "res://assets/vfx/extensions/late-20261020/sources/246006a26aff271396e2/VFX_Smoke_z_puff.tscn"

static func make(parent: Node3D, kind: String, index: int) -> GPUParticles3D:
	var source: Node = Donor.instantiate(VfxPackageIO_6403614208.resource(Fire if kind=="fire" else Smoke),[])
	Graph.isolate_node(source,{})
	var emitter: GPUParticles3D = source if source is GPUParticles3D else source.find_child("firex_cheap",true,false)
	if emitter!=source:
		source.remove_child(emitter)
		source.free()
	emitter.name="Source"+kind.capitalize()+str(index)
	emitter.layers=1
	emitter.position=Vector3.ZERO
	emitter.scale=Vector3.ONE
	emitter.use_fixed_seed=true
	emitter.seed=51293+index*31
	emitter.fixed_fps=60
	emitter.local_coords=true
	emitter.emitting=false
	emitter.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var process: ParticleProcessMaterial = emitter.process_material
	if kind=="fire":
		emitter.amount=18
		emitter.scale=Vector3(.43,.8,.43)
		process.emission_ring_radius=.18
		process.emission_ring_inner_radius=0.
	else:
		emitter.amount=14
		emitter.lifetime=2.
		process.radial_velocity_min=.06
		process.radial_velocity_max=.16
		process.angular_velocity_min=-16.
		process.angular_velocity_max=16.
		process.gravity=Vector3(0,.35,0)
		process.scale_min=.45
		process.scale_max=.8
	var material: ShaderMaterial = emitter.material_override
	var shader := Shader.new()
	var code := Materials.expand_shader(material.shader.code,material.shader.resource_path.get_base_dir())
	var token := RegEx.new()
	token.compile("\\bTIME\\b")
	code=token.sub(code,"surface_source_clock",true)
	code=code.replace("shader_type spatial;","shader_type spatial;\nuniform float surface_source_clock=0.;\nuniform float emitter_envelope=0.;")
	code=code.insert(code.rfind("}"),"\nALPHA*=emitter_envelope;\n")
	shader.code=code
	Materials.replace_shader(material,shader)
	if kind!="fire":
		material.set_shader_parameter("Color",Color("b7ada0"))
		material.set_shader_parameter("Enable_Proximity_Fade",false)
	parent.add_child(emitter)
	return emitter

static func sample(emitter: GPUParticles3D, seconds: float, strength: float) -> void:
	var active := strength>.01
	if active and not emitter.emitting:emitter.restart()
	emitter.emitting=active
	emitter.visible=active
	var selected: ShaderMaterial=emitter.material_override
	selected.set_shader_parameter("surface_source_clock",seconds)
	selected.set_shader_parameter("emitter_envelope",clampf(strength,0.,1.))

const VfxPackageIO_6403614208 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
