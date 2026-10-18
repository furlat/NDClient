extends "res://assets/vfx/sources/08327bdb7a95631435c4/moonbeam.gd"
## A supplied Moonbeam exposure, fitted to this recipient's measured silhouette.
## The maintained field and exposure membership remain separate caller-owned facts.
var recipient_geometry: Dictionary = {}

static func make_component(input: Dictionary) -> Node3D:
	var effect: Node3D = VfxPackageIO_c9c6017fcf.resource("res://assets/vfx/sources/c9c6017fcf31a5168ab1/moonbeam_contact.gd").new()
	effect.specification = input.duplicate(true)
	return effect

func set_entity_geometry(value: Dictionary) -> void:
	recipient_geometry = value

func sample(seconds: float) -> void:
	super.sample(seconds)
	var points: Array = recipient_geometry.get("points", [])
	if points.is_empty():
		field.hide()
		return
	var inverse := global_transform.affine_inverse()
	var ground: Vector3 = inverse * recipient_geometry.origin
	var centre := Vector3.ZERO
	var height := 0.0
	for point in points:
		var local: Vector3 = inverse * point.position
		centre += local
		height = maxf(height, local.y-ground.y)
	centre /= float(points.size())
	var radius := 0.0
	for point in points:
		var local: Vector3 = inverse * point.position
		radius = maxf(radius, Vector2(local.x-centre.x,local.z-centre.z).length())
	field.position = Vector3(centre.x,ground.y,centre.z)
	var envelope: float = smoothstep(0.0,0.06,seconds)*(1.0-smoothstep(0.16,0.55,seconds))
	for index in layers.size():
		var draw: MeshInstance3D = layers[index].node
		var bounds: AABB = draw.mesh.get_aabb()
		if specification.layers[index].get("shaft",false):
			draw.scale = Vector3(radius*1.5/maxf(bounds.size.x,0.001),height/maxf(bounds.size.y,0.001),radius*1.5/maxf(bounds.size.z,0.001))
			draw.position.y = -bounds.position.y*draw.scale.y+0.025
		layers[index].material.set_shader_parameter("moon_opacity",envelope*float(layers[index].opacity))
	field.visible = envelope>0.001

func capture_observation() -> Dictionary:
	return {"source_scene":specification.scene,"recipient_points":recipient_geometry.get("points",[]).size(),
		"owned_field_created":false,"optical_lights":0,"exposure_membership_supplied":true}

const VfxPackageIO_c9c6017fcf = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
