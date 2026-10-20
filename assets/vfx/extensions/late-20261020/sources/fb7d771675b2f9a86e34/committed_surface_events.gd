extends RefCounted
## Presentation-only committed cell records. Invalid replacement is atomic.
const Names := ["", "freeze", "thaw", "charge", "vaporize", "clear", "uncharge", "ignite", "douse"]
var contacts := PackedVector4Array()
var regions := PackedVector4Array()
var operations := PackedInt32Array()
var events: Array = []

func replace(value: Array, allowed: Array = Names) -> String:
	var next_contacts := PackedVector4Array()
	var next_regions := PackedVector4Array()
	var next_operations := PackedInt32Array()
	var previous := -INF
	for event in value:
		if event is not Dictionary:return "Surface event must be a Dictionary"
		var operation: int = Names.find(event.get("operation", ""))
		if operation<=0 or not event.get("operation") in allowed:return "Unsupported surface presentation operation"
		var cells: Variant = event.get("cells")
		var contact: Variant = event.get("contact")
		if cells is not Array or cells.is_empty():return "Surface event requires admitted cells"
		if contact is not Array or contact.size()!=2:return "Surface event requires a local contact [x,z]"
		var at := float(event.get("at", -INF))
		var front := float(event.get("front_seconds", .35))
		if not is_finite(at) or at<previous or not is_finite(front) or front<=0.:return "Surface events require finite ordered times and a positive front duration"
		previous=at
		if not is_finite(float(contact[0])) or not is_finite(float(contact[1])):return "Surface contact must be finite"
		for cell in cells:
			if cell is not Array or cell.size()!=2:return "Surface cell must be [x,z]"
			var x := float(cell[0])
			var z := float(cell[1])
			if not is_finite(x) or not is_finite(z):return "Surface cell must be finite"
			next_contacts.append(Vector4(contact[0],contact[1],at,front))
			next_regions.append(Vector4(x-.5,z-.5,x+.5,z+.5))
			next_operations.append(operation)
	if next_contacts.size()>32:return "At most 32 surface operation/cell records per patch; partition explicitly"
	contacts=next_contacts
	regions=next_regions
	operations=next_operations
	events=value.duplicate(true)
	return ""

func bind(material: ShaderMaterial) -> void:
	material.set_shader_parameter("surface_contacts",contacts)
	material.set_shader_parameter("surface_regions",regions)
	material.set_shader_parameter("surface_operations",operations)
	material.set_shader_parameter("surface_event_count",contacts.size())

func state_at(point: Vector2, seconds: float, detail: float=0.) -> Vector4:
	# CPU emitter gates mirror surface_states.gdshaderinc; geometry owns coverage.
	var state := Vector4.ZERO
	for index in contacts.size():
		var contact := contacts[index]
		var region := regions[index]
		if seconds<contact.z or point.x<region.x or point.y<region.y or point.x>region.z or point.y>region.w:continue
		var front := smoothstep(0.,maxf(.03,contact.w),seconds-contact.z-point.distance_to(Vector2(contact.x,contact.y))*.19-detail*.035)
		match operations[index]:
			1:state.x=lerpf(state.x,1.,front);state.y*=1.-front
			2:state.x*=1.-front
			3:state.y=lerpf(state.y,1.,front)*(1.-state.x)*(1.-state.w)
			4:state.z=0.;state.w=maxf(state.w,front);state.y*=1.-front
			5:state.w=maxf(state.w,front);state.y*=1.-front;state.z*=1.-front
			6:state.y*=1.-front
			7:state.z=lerpf(state.z,1.,front)*(1.-state.w)
			8:state.w=maxf(state.w,front);state.z*=1.-front;state.y*=1.-front
	return state
