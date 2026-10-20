extends Resource
## Exact source-native operands; no actual recipients, trajectories or poses.
const Materials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
@export var source_phase := ""
@export var source_sha256 := ""
@export var specification: Dictionary = {}
@export var layers: Array[Dictionary] = []
@export var receipt: Dictionary = {}
@export var stable_paths_verified:=false
var interface_prepared := false

func prepare_immutable_interface() -> void:
	if interface_prepared:return
	var shaders := {}
	for entry in layers:
		var material: ShaderMaterial=entry.material
		if not shaders.has(material.shader):
			shaders[material.shader]=true
			material.shader.get_shader_uniform_list()
			Materials.declared_uniforms(material.shader)
		material.get_property_list()
		entry.mesh.get_rid()
	interface_prepared=true

func restore(owner: Node3D) -> Dictionary:
	var field:=Node3D.new()
	field.name="OneMoonbeamOwner"
	owner.add_child(field)
	var restored:=[]
	var geometry:=[]
	var materials:=[]
	for entry in layers:
		var draw:=MeshInstance3D.new()
		draw.name=entry.name
		draw.mesh=entry.mesh
		draw.material_override=entry.material.duplicate(false)
		# Exact original setters and order, including their native decomposition.
		draw.scale=entry.scale
		draw.position=entry.position
		draw.cast_shadow=entry.cast_shadow
		field.add_child(draw)
		restored.append({"node":draw,"material":draw.material_override,"opacity":entry.opacity})
		geometry.append(draw)
		materials.append(draw.material_override)
	return {"field":field,"layers":restored,"geometry":geometry,"materials":materials}


static func gradient_recipe(texture: Texture2D) -> Dictionary:
	assert(texture is GradientTexture1D or texture is GradientTexture2D)
	var fields:={}
	for property in texture.get_property_list():
		var name: String=property.name
		if name in ["width","height","use_hdr","fill","fill_from","fill_to","repeat"]:
			fields[name]=texture.get(name)
	var gradient: Gradient=texture.gradient
	return {"class":texture.get_class(),"fields":fields,"gradient_offsets":gradient.offsets,
		"gradient_colors":gradient.colors,"gradient_interpolation":gradient.interpolation_mode,
		"gradient_color_space":gradient.interpolation_color_space}
