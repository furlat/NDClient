extends "res://assets/vfx/sources/1dc77e979e0f18992748/quarry_common.gd"
const GpuRibbon = preload("res://assets/vfx/extensions/continuation42-20261020/sources/34e0f9ed9a909885cd97/path_ribbon.gd")
## Three inward curling curse cuts use the original dark-hit dissolving line
## graph, clipped to the current recipient. Any explicitly qualified attack-roll
## hit can accent them; automatic damage has no invented Hex activation.
var mark: MeshInstance3D
var claws: Array[MeshInstance3D] = []

static func make_component(input: Dictionary) -> Node3D:
	var component: Node3D = VfxPackageIO_7ad647fcc0.resource("res://assets/vfx/extensions/continuation42-20261020/sources/7ad647fcc09f7a163ed6/hex.gd").new()
	component.configure(input)
	var finish := """
	vec2 q_p=UV2-vec2(.5);float q_r=length(q_p);float q_a=atan(q_p.y,q_p.x);
	float q_cut=1.0-smoothstep(.13,.27,abs(sin(q_a*1.5+q_r*5.0)));
	float q_shape=q_cut*smoothstep(.09,.16,q_r)*(1.0-smoothstep(.34,.42,q_r));
	ALPHA=(.24+.76*n_out14p0)*q_shape*owned_envelope*.58;
	"""
	var body_material := ContactMaterial.make(input.material,finish)
	var source_material := ContactMaterial.make(input.material,"\nALPHA=(.24+.76*n_out14p0)*sin(UV.x*PI)*sin(UV.y*PI)*owned_envelope*.45;\n")
	component.mark = component.make_mesh("ActualQuarryThreeCurseCuts",body_material)
	for index in 3:
		component.claws.append(component.make_mesh("InwardCurseContact"+str(index),source_material))
	return component

func payload_admitted() -> bool:
	return rider_admitted() and str(strike.get("attack_kind","")) in ["weapon","spell","unarmed","natural"] \
		and bool(strike.get("attack_roll_observed",false))

func sample(seconds: float) -> void:
	_hide_all()
	if mark_envelope(seconds) <= .0001:
		return
	var phase := str(settings.phase)
	for material in materials:
		material.set_shader_parameter("owned_source_colour",Color(.45,.3,.35,.32+.07*sin(seconds*2.0)))
	var centre: Vector3
	var normal := Vector3.FORWARD
	if phase == "windup":
		if endpoints.is_empty():
			return
		centre = endpoints[0].point
	else:
		if not measured_mark(mark):
			return
		if not phase in ["application","reapply","hit"]:
			return
		var hit := contact()
		centre = hit.position
		normal = hit.normal
	var axes := plane_axes(normal)
	var radius := .07 if phase == "windup" else .15
	var contraction := smoothstep(0.0,float(settings.seconds),seconds)
	for index in 3:
		var points: Array[Vector3] = []
		var widths: Array[float] = []
		for vertex in 18:
			var along := float(vertex)/17.0
			var angle := TAU*float(index)/3.0+along*.70
			var reach := radius*(1.0-along*.70)*(1.0-contraction*.25)
			points.append(centre+(axes[0]*cos(angle)+axes[1]*sin(angle))*reach+normal*.018)
			widths.append(.014*sin(along*PI))
		claws[index].global_transform = Transform3D.IDENTITY
		GpuRibbon.assign(claws[index],points,widths)
		claws[index].show()

const VfxPackageIO_7ad647fcc0 = preload("res://assets/vfx/extensions/continuation42-20261020/scoped_resource_io.gd")
