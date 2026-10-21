extends Node3D
## Existing mist and14 frost quads owned only by the current observed child.
const ZoneInput=preload("res://assets/vfx/extensions/wall-child-v3-20261021/sources/93d7a4797fde307b9512/input.gd")
const Readiness=preload("res://assets/vfx/extensions/production-review-20261020/sources/7dd1897cdd5ee8a903b9/source_readiness.gd")
var bank: Resource
var owner_uuid := ""
var state := {}
var footprint := {}
var state_error := ""
var materials: Array[ShaderMaterial]=[]
var geometry: Array[GeometryInstance3D]=[]
var mist: MeshInstance3D
var flakes: Array[MeshInstance3D]=[]
var mask: ImageTexture
var source_age := 0.0
var placement_valid := false

static func preparation_resources(input: Dictionary) -> Array:
	return [str(input.get("frigid_air_bank",""))]

static func make_component(input: Dictionary) -> Node3D:
	var prepared: Resource=Readiness.resources.get(str(input.get("frigid_air_bank","")))
	if prepared==null or not prepared.interface_ready or str(input.get("owner_uuid","")).is_empty(): return null
	var node: Node3D=VfxPackageIO_39a8f882a0.resource("res://assets/vfx/extensions/wall-child-v3-20261021/sources/39a8f882a0878cd303e3/field.gd").new()
	node.bank=prepared
	node.owner_uuid=str(input.owner_uuid)
	for template: ShaderMaterial in prepared.materials: node.materials.append(template.duplicate(false))
	node.mask=ImageTexture.create_from_image(Image.create_empty(1,1,false,Image.FORMAT_R8))
	for material: ShaderMaterial in node.materials: material.set_shader_parameter("child_cells",node.mask)
	node.mist=node._draw(prepared.volume_mesh,node.materials[0],"FrigidMist")
	for index in prepared.flake_meshes.size():
		node.flakes.append(node._draw(prepared.flake_meshes[index],node.materials[1],"Frost%02d"%index))
	node.hide()
	return node

func _draw(mesh: Mesh, material: ShaderMaterial, label: String) -> MeshInstance3D:
	var draw:=MeshInstance3D.new()
	draw.name=label
	draw.mesh=mesh
	draw.material_override=material
	add_child(draw)
	geometry.append(draw)
	return draw

func prepare_source_layer_mask(value: int) -> void:
	for draw: GeometryInstance3D in geometry: draw.layers=value

func source_bindings() -> Dictionary:
	return {"geometry":geometry,"materials":materials,"players":[],"lights":[],
		"static_material_topology":true,"static_geometry_layers":true}

func set_zone_geometry(value: Dictionary) -> bool:
	var current:=ZoneInput.geometry(value,owner_uuid)
	state_error=current.error
	if not state_error.is_empty():
		footprint={}
		hide()
		return false
	if footprint.is_empty() or footprint.anchor!=current.anchor or footprint.elevation_steps!=current.elevation_steps:
		placement_valid=false
	footprint=current
	var image:=Image.create_empty(current.size.x,current.size.y,false,Image.FORMAT_R8)
	for cell: Vector2i in current.cells:
		var pixel: Vector2i=cell-current.minimum
		image.set_pixel(pixel.x,pixel.y,Color.WHITE)
	# Each occurrence owns its texture; a sibling's old frame is never updated.
	mask.set_image(image)
	var extent:=Vector3(current.size.x*ZoneInput.CELL,current.height,current.size.y*ZoneInput.CELL)
	var centre:=Vector3((float(current.minimum.x)+float(current.size.x-1)*.5)*ZoneInput.CELL,
		current.height*.5,(float(current.minimum.y)+float(current.size.y-1)*.5)*ZoneInput.CELL)
	mist.position=centre
	mist.scale=extent/bank.volume_mesh.get_aabb().size
	for material: ShaderMaterial in materials:
		material.set_shader_parameter("child_mask_origin",Vector2(current.minimum))
		material.set_shader_parameter("child_mask_size",Vector2(current.size))
	materials[0].set_shader_parameter("centre",centre)
	materials[0].set_shader_parameter("half_extent",extent*.5)
	return true

func set_owner_state(value: Dictionary) -> bool:
	state_error=ZoneInput.owner_state(value,owner_uuid)
	if not state_error.is_empty():
		state={}
		hide()
		return false
	state=value.duplicate(true)
	if not state.present or not state.observed or state.suppressed: hide()
	return true

func set_targets(value: Array) -> void:
	if value.is_empty() or not value[0] is Dictionary or not value[0].get("point") is Vector3 or not value[0].point.is_finite():
		placement_valid=false
		state_error="Actual optical anchor world point required"
		hide()
		return
	global_position=value[0].point
	placement_valid=true

func set_live_endpoints(value: Array) -> void: set_targets(value)

func refresh_live_inputs(seconds: float) -> void: sample(seconds)

func sample(seconds: float) -> void:
	if not is_finite(seconds) or seconds<0.:
		hide()
		return
	source_age=float(state.get("owner_age_seconds",0.0))
	visible=placement_valid and not state.is_empty() and not footprint.is_empty() and not footprint.cells.is_empty() \
		and state.present and state.observed and not state.suppressed
	if not visible: return
	# The original144Hz/4-second component clock, without wall birth/retirement.
	var clock:=float(int(round(source_age*144.0))%576)/144.0
	var inverse:=Projection(global_transform.affine_inverse())
	for material: ShaderMaterial in materials:
		material.set_shader_parameter("factory_world_to_source",inverse)
	materials[0].set_shader_parameter("wall_clock",clock)
	materials[0].set_shader_parameter("opacity",.25)
	materials[1].set_shader_parameter("opacity",1.0)
	for index in flakes.size():
		var phase:=fposmod(clock/4.0+float(index)*.61803398875,1.0)
		var u:=fposmod(float(index)*.754877666,1.0)
		var v:=fposmod(float(index)*.569840291,1.0)
		var cell: Vector2i=footprint.cells[index%footprint.cells.size()]
		flakes[index].position=Vector3((float(cell.x)+(u-.5)*.80)*ZoneInput.CELL+.07*sin(TAU*phase+float(index)*1.7),
			footprint.height*(1.0-phase),(float(cell.y)+(v-.5)*.68)*ZoneInput.CELL+.035*cos(TAU*phase+float(index)*2.1))
		var fade:=smoothstep(0.,.16,phase)*(1.0-smoothstep(.78,1.0,phase))
		flakes[index].set_instance_shader_parameter("solid_flake_opacity",.34*fade)

func capture_observation() -> Dictionary:
	return {"owner_uuid":owner_uuid,"state_error":state_error,"source_age":source_age,"visible":visible,
		"cells":footprint.get("cells",[]),"anchor":footprint.get("anchor"),"elevation_steps":footprint.get("elevation_steps"),
		"mist_draws":1,"frost_quads":flakes.size(),"wall_or_debris_nodes":0,"review_lease":false,"coverage_interpretation":"Disclosed-cell fog volumes; path/width do not reconstruct thin wall or dome shell"}

const VfxPackageIO_39a8f882a0 = preload("res://assets/vfx/extensions/wall-child-v3-20261021/scoped_resource_io.gd")
