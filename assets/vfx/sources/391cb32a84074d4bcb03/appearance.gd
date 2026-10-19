extends Node3D
## Native item publication, separate from enchantment/coating and inventory art.
## Art identity is immutable; observed holder/hand/world placement is live.
const Meshes=preload("res://assets/vfx/sources/7fdb065636384c27c4a5/meshes.gd")
const Fire=preload("res://assets/vfx/sources/cb6c8716b8516ba846d5/native_fire.gd")
const FlameMaterials = preload("res://assets/vfx/sources/b0884bd569da02e14dce/flame_materials.gd")
var kind: String
var identity: Dictionary={}
var binding: Dictionary={}
var rejection: String="unbound"
var construction_error: String=""
var visual: Node3D
var draws: Array[MeshInstance3D]=[]
var fire_materials: Array[ShaderMaterial]=[]
var admitted:=false
var prepared:=false
var appearance_revision:=0
var render_layer_mask: int = 1 << 19
var ground_support_offset_cells: float = 0.0

static func make(kind_value: String,input: Dictionary) -> Node3D:
	var node: Node3D=VfxPackageIO_391cb32a84.resource("res://assets/vfx/sources/391cb32a84074d4bcb03/appearance.gd").new()
	node.kind=kind_value
	var layer_value: Variant = input.get("layer_mask", 1 << 19)
	if not layer_value is int or int(layer_value) <= 0 or int(layer_value) >= (1 << 20):
		node.construction_error = "Invalid native item render layer mask"
		return node
	node.render_layer_mask = int(layer_value)
	if kind_value not in ["flame_blade", "devotees_mace"]:
		node.construction_error = "Unsupported created weapon appearance kind"
		return node
	var required: Array=["created_item_uuid","caster_uuid","lifetime_condition_uuid"] if kind_value=="flame_blade" else ["created_item_uuid","creator_uuid"]
	for name in required:
		if not input.get(name) is String or str(input[name]).strip_edges().is_empty():
			node.construction_error="Missing immutable created item operand: "+name
			return node
	node.identity={"item_uuid":input.created_item_uuid,"item_id":"weapon.flame_blade" if kind_value=="flame_blade" else "weapon.devotees_mace","creator_uuid":input.caster_uuid if kind_value=="flame_blade" else input.creator_uuid}
	if kind_value=="flame_blade":
		node.identity.lifetime_condition_uuid=input.lifetime_condition_uuid
	return node

func _ready() -> void:
	if construction_error.is_empty():
		prepare()

func steel(colour: Color, metallic: float) -> ShaderMaterial:
	# Private intrinsic finish retains actual 3D normals in the native pass.
	# A fully metallic PBR reflection had no donor light/environment to sample.
	var material := ShaderMaterial.new()
	material.shader = VfxPackageIO_391cb32a84.resource("res://assets/vfx/sources/7a6b9210aa4fe15e6f04/native_metal_finish.gdshader")
	material.set_shader_parameter("finish_colour", colour)
	material.set_shader_parameter("metal_fraction", clampf(metallic, 0.0, 1.0))
	return material

func draw(label: String,mesh: Mesh,material: Material,position: Vector3=Vector3.ZERO) -> MeshInstance3D:
	var node:=MeshInstance3D.new()
	node.name=label
	node.layers=render_layer_mask
	node.mesh=mesh
	node.material_override=material
	node.position=position
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.add_child(node)
	draws.append(node)
	return node

func prepare() -> void:
	if prepared or not construction_error.is_empty():
		return
	prepared=true
	visual=Node3D.new()
	visual.name="ExactCreatedItemAppearance"
	visual.hide()
	add_child(visual)
	if kind=="flame_blade":
		# Original torch field/masks and six native cones, privately adapted
		# to the owned curved blade with a warm ramp and root-to-tip UVs.
		var material: ShaderMaterial = FlameMaterials.make(true)
		fire_materials.append(material)
		draw("CreatedFlameBladeBody",Meshes.blade(),material)
		for i in 6:
			var tongue: ShaderMaterial = FlameMaterials.make(false)
			fire_materials.append(tongue)
			var fraction: float=.14+.135*float(i)
			var along := Vector3(.145 * fraction * fraction, .10 + .74 * fraction, 0)
			var axis: Vector3=(Vector3(.18,.73,0).normalized()+Vector3.FORWARD*(.22 if i%2==0 else -.12)).normalized()
			var node:=draw("AttachedNativeBladeFlame"+str(i),VfxPackageIO_391cb32a84.resource(Fire.CONE),tongue,along)
			node.basis=Basis(Quaternion(Vector3.UP,axis))*Basis.from_scale(Vector3(.014 + .002 * float(i % 3), .031 + .005 * float(i % 3), .014))
		draw("CreatedFlameBladeGrip",Meshes.cylinder("blade_grip",.023,.18),steel(Color(.12,.075,.045),.25),Vector3(0,0,0))
	else:
		var metal: ShaderMaterial = steel(Color(.34, .39, .45), .82)
		var core: ShaderMaterial = steel(Color(.16, .19, .23), .72)
		var brass: ShaderMaterial = steel(Color(.52, .34, .12), .76)
		draw("DevoteesMaceGrip", Meshes.cylinder("mace_grip", .027, .25), steel(Color(.10, .052, .025), .1), Vector3(0, .025, 0))
		draw("DevoteesMaceShaft", Meshes.cylinder("mace_shaft", .018, .42), metal, Vector3(0, .33, 0))
		draw("DevoteesMaceCore", Meshes.cylinder("mace_core", .032, .25), core, Vector3(0, .56, 0))
		for index in 6:
			var flange: MeshInstance3D = draw("DevoteesMaceFlange" + str(index), Meshes.mace_flange(), metal)
			flange.rotation.y = TAU * float(index) / 6.0
		draw("DevoteesMaceLowerCollar", Meshes.cylinder("mace_lower_collar", .040, .018), brass, Vector3(0, .435, 0))
		draw("DevoteesMaceCrown", Meshes.cylinder("mace_crown", .037, .018), brass, Vector3(0, .690, 0))

	# Geometry's grip-centred local origin is distinct from a supplied ground
	# contact frame. Derive support from the exact owned geometry once.
	var minimum_y: float = INF
	for node in draws:
		var bounds: AABB = node.mesh.get_aabb()
		for corner_index in 8:
			var corner: Vector3 = node.transform * bounds.get_endpoint(corner_index)
			minimum_y = minf(minimum_y, corner.y)
	ground_support_offset_cells = -minimum_y if is_finite(minimum_y) else 0.0
	apply_binding_transform()

func set_render_layer_mask(value: int) -> bool:
	if value <= 0 or value >= (1 << 20):
		return false
	render_layer_mask = value
	for node in draws:
		node.layers = value
	return true

func ground_registration(contact: Transform3D) -> Transform3D:
	var result: Transform3D = contact
	result.origin += contact.basis.y * ground_support_offset_cells
	return result

func apply_binding_transform() -> void:
	if visual==null or not is_inside_tree():
		return
	visual.visible=admitted
	if admitted:
		visual.global_transform=binding.hand_transform if binding.location_kind=="held" else ground_registration(binding.world_transform)

func finite_transform(value: Variant) -> bool:
	if not value is Transform3D:
		return false
	var transform: Transform3D=value
	return transform.origin.is_finite() and transform.basis.x.is_finite() and transform.basis.y.is_finite() and transform.basis.z.is_finite() and absf(transform.basis.determinant())>.000001

func _reject(message: String) -> bool:
	rejection=message
	binding={}
	admitted=false
	if visual!=null:
		visual.hide()
	return false

func set_created_item_binding(value: Dictionary) -> bool:
	if not construction_error.is_empty():
		return _reject(construction_error)
	for name in ["item_uuid","item_id"]:
		if str(value.get(name,""))!=str(identity[name]):
			return _reject("Wrong "+name)
	var creator_key: String="caster_uuid" if kind=="flame_blade" else "creator_uuid"
	if str(value.get(creator_key,""))!=str(identity.creator_uuid):
		return _reject("Wrong creator/caster")
	for name in ["present","observed","suppressed","item_exists","equipped"]:
		if not value.get(name) is bool:
			return _reject("Missing explicit boolean "+name)
	if kind=="flame_blade":
		if str(value.get("lifetime_condition_uuid",""))!=str(identity.lifetime_condition_uuid):
			return _reject("Wrong lifetime owner")
		if not value.get("lifetime_present") is bool or not value.get("item_in_caster_holdings") is bool:
			return _reject("Missing lifetime/holdings evidence")
	var location: String=str(value.get("location_kind",""))
	if location=="held":
		var slot: String=str(value.get("render_slot",""))
		var hand: String=str(value.get("hand",""))
		if not value.equipped or str(value.get("holder_uuid","")).is_empty():
			return _reject("Missing exact equipped holder")
		if (slot=="weapon" and hand!="main") or (slot=="offhand" and hand!="off") or slot not in ["weapon","offhand"]:
			return _reject("Mismatched hand/slot")
		if kind=="flame_blade" and str(value.holder_uuid)!=str(identity.creator_uuid):
			return _reject("Flame Blade left caster holdings")
		if not finite_transform(value.get("hand_transform")):
			return _reject("Missing actual authored hand transform")
	elif location=="ground":
		if value.equipped or not str(value.get("holder_uuid","")).is_empty() or not str(value.get("hand","")).is_empty() or not str(value.get("render_slot","")).is_empty() or not finite_transform(value.get("world_transform")):
			return _reject("Invalid dropped-item transform/holder")
	elif location=="inventory":
		if value.equipped:
			return _reject("Inventory item cannot be equipped")
	else:
		return _reject("Missing exact item location")
	binding=value.duplicate()
	admitted=value.present and value.observed and value.item_exists and not value.suppressed
	if kind=="flame_blade":
		admitted=admitted and value.lifetime_present and value.item_in_caster_holdings and location=="held"
	admitted=admitted and location!="inventory"
	if prepared:
		apply_binding_transform()
	rejection="" if admitted else "Authoritative item state hides appearance"
	appearance_revision+=1
	return true

func sample(seconds: float) -> void:
	if not prepared:
		prepare()
	if visual==null:
		return
	visual.visible=admitted
	if admitted:
		var alpha: float=clampf(float(binding.get("visibility",1.0)),0.,1.)
		for i in fire_materials.size():
			Fire.clock(fire_materials[i],seconds+float(maxi(0,i-1))*.16,alpha*(.98 if i==0 else .78))

func clear() -> void:
	binding={}
	admitted=false
	if visual!=null:
		visual.hide()
	rejection="cleared"

func capture_observation() -> Dictionary:
	return {"item_uuid":identity.get("item_uuid",""),"item_id":identity.get("item_id",""),"creator_uuid":identity.get("creator_uuid",""),"lifetime_condition_uuid":identity.get("lifetime_condition_uuid",""),"admitted":admitted,"rejection":rejection,"construction_error":construction_error,"source_kind":"native_created_item_appearance","source_geometry":"new Factory scimitar body" if kind=="flame_blade" else "new Factory six-flanged mace","source_fire":Fire.TORCH if kind=="flame_blade" else "none","native_flame_details":6 if kind=="flame_blade" else 0,"optical_lights":0,"art_status":"candidate_unaccepted","appearance_revision":appearance_revision,"render_layer_mask":render_layer_mask,"ground_support_offset_cells":ground_support_offset_cells}

func _exit_tree() -> void:
	clear()

const VfxPackageIO_391cb32a84 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
