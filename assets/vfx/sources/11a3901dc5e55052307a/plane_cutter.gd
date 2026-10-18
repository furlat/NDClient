@tool
extends Node3D
#class_name SimplePlaneCutter

@export var target_mesh: MeshInstance3D:
	set(value):
		target_mesh = value
		update_shader()

func _ready() -> void:
	set_notify_transform(true)
	update_shader()
	#if Engine.is_editor_hint():
		#update_shader()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		update_shader()

func update_shader() -> void:
	if not is_instance_valid(target_mesh):
		return
		
	var mat: ShaderMaterial = null
	
	if target_mesh.material_override is ShaderMaterial:
		mat = target_mesh.material_override
	
	elif target_mesh.get_surface_override_material(0) is ShaderMaterial:
		mat = target_mesh.get_surface_override_material(0)
	
	elif target_mesh.mesh != null and target_mesh.mesh.get_surface_count() > 0:
		var mesh_mat = target_mesh.mesh.surface_get_material(0)
		if mesh_mat is ShaderMaterial:
			mat = mesh_mat
			
	
	if not mat:
		return
	
	mat.set_shader_parameter("cutplane", global_transform)
