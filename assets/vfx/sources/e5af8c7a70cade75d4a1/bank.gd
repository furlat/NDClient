extends Resource
## Original varied native meshes, material and Animation keys; no owner/contacts.
@export var meshes: Array[Mesh] = []
@export var material: ShaderMaterial
@export var mesh_transform := Transform3D.IDENTITY
@export var decal_properties: Dictionary = {}
@export var animation: Animation
@export var tracks: Dictionary = {}
@export var source_settings: Dictionary = {}
@export var provenance: Dictionary = {}

func prepare_immutable_interface() -> void:
	material.get_property_list()
