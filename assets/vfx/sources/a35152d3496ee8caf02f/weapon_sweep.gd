extends Node3D
## A sweep of the actual equipped weapon's current geometry, not a recording of
## old screen-pixel paths. Supplied pose points and hand choose the blade ends.
const ShaderSource := "res://assets/vfx/sources/6459aca9863960ce7487/3d00a1eb3a5ee5705699e2171e509d832633a1e7645bebc9bb6e7513eca6bf89.gdshader"
var geometry: Dictionary = {}
var endpoints: Array = []
var history: Array = []
var trail: MeshInstance3D
var material: ShaderMaterial
var gpu_paths:=false
var history_texture: ImageTexture
var history_image: Image
var geometry_key: Array=[]
var relative_base:=Vector3.ZERO
var relative_tip:=Vector3.ZERO

static func make_component(input: Dictionary) -> Node3D:
	var node := VfxPackageIO_a35152d349.resource("res://assets/vfx/sources/a35152d3496ee8caf02f/weapon_sweep.gd").new() as Node3D
	node.gpu_paths=input.get("gpu_paths",false)
	node.trail=MeshInstance3D.new()
	node.material=ShaderMaterial.new()
	var shader := Shader.new()
	shader.code=VfxPackageIO_a35152d349.text(ShaderSource)
	node.material.shader=shader
	node.material.set_shader_parameter("impact",false)
	if node.gpu_paths:
		preload("res://assets/vfx/sources/801b495c0bd760a8e358/directed_program.gd").prepare(node.material,"weapon_history",false,"gpu_weapon_vertex(VERTEX,UV);")
		node.history_image=Image.create(128,2,false,Image.FORMAT_RGBAF)
		node.history_texture=ImageTexture.create_from_image(node.history_image)
		node.material.set_shader_parameter("gpu_weapon_history",node.history_texture)
		var surface:=SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for station in 127:
			for corner in [Vector2i(station,0),Vector2i(station,1),Vector2i(station+1,1),Vector2i(station,0),Vector2i(station+1,1),Vector2i(station+1,0)]:
				surface.set_uv(Vector2(float(corner.x)/127.,corner.y))
				surface.add_vertex(Vector3(corner.x,corner.y,0))
		node.trail.mesh=surface.commit()
	else:
		node.trail.mesh=PlaneMesh.new()
	node.trail.material_override=node.material
	node.trail.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(node.trail)
	return node

func set_entity_geometry(value: Dictionary) -> void:geometry=value
func set_live_endpoints(value: Array) -> void:endpoints=value

func sample(seconds: float) -> void:
	material.set_shader_parameter("clock",seconds)
	var points: Array=geometry.get("points",[])
	if points.size()<2 or endpoints.is_empty():trail.visible=false;return
	var hand: Vector3=endpoints[0].point
	var tip: Vector3=points[0].position
	var base: Vector3=points[0].position
	var pose: Array=preload("res://assets/vfx/sources/9c05cee00f7d74560348/geometry_key.gd").from_surface(geometry)
	var key: Array=[pose,hand-geometry.get("origin",Vector3.ZERO)]
	if not pose.is_empty() and key==geometry_key:
		base=geometry.origin+relative_base
		tip=geometry.origin+relative_tip
	else:
		for selected in points:
			if hand.distance_squared_to(selected.position)>hand.distance_squared_to(tip):tip=selected.position
			if hand.distance_squared_to(selected.position)<hand.distance_squared_to(base):base=selected.position
		geometry_key=key
		relative_base=base-geometry.get("origin",Vector3.ZERO)
		relative_tip=tip-geometry.get("origin",Vector3.ZERO)
	if not history.is_empty() and seconds<float(history[-1].at):history.clear()
	history.append({"at":seconds,"base":base,"tip":tip})
	while not history.is_empty() and float(history[0].at)<seconds-.16:history.pop_front()
	trail.visible=history.size()>1 and seconds<.94
	if not trail.visible:return
	if gpu_paths:
		assert(history.size()<=128,"Weapon sweep exceeds the admitted 128 source-history stations")
		var inverse:=global_transform.affine_inverse()
		var bounds:=AABB(inverse*history[0].base,Vector3.ZERO)
		for index in history.size():
			var a: Vector3=inverse*history[index].base
			var b: Vector3=inverse*history[index].tip
			history_image.set_pixel(index,0,Color(a.x,a.y,a.z,1))
			history_image.set_pixel(index,1,Color(b.x,b.y,b.z,1))
			bounds=bounds.expand(a).expand(b)
		history_texture.update(history_image)
		material.set_shader_parameter("gpu_weapon_count",history.size())
		trail.custom_aabb=bounds.grow(.01)
		return
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var inverse := global_transform.affine_inverse()
	for index in history.size()-1:
		for ij in [Vector2i(index,0),Vector2i(index,1),Vector2i(index+1,1),Vector2i(index,0),Vector2i(index+1,1),Vector2i(index+1,0)]:
			var sample_point: Dictionary=history[ij.x]
			var u := float(ij.x)/float(history.size()-1)
			surface.set_uv(Vector2(u,ij.y))
			surface.add_vertex(inverse*(sample_point.tip if ij.y else sample_point.base))
	trail.mesh=surface.commit()

func capture_observation() -> Dictionary:
	return {"weapon_points":geometry.get("points",[]).size(),"live_endpoints":endpoints.size(),"sweep_samples":history.size(),"sweep_visible":trail.visible}

const VfxPackageIO_a35152d349 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
