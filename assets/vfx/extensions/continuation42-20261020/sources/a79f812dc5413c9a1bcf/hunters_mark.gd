extends "res://assets/vfx/sources/1dc77e979e0f18992748/quarry_common.gd"
const GpuRibbon = preload("res://assets/vfx/extensions/continuation42-20261020/sources/34e0f9ed9a909885cd97/path_ribbon.gd")
## Two forked tracking cuts are clipped to the actual quarry torso. One eligible
## weapon hit accents the current actual item footprint; the mark owns no item.
var mark: MeshInstance3D
var weapon_cut: MeshInstance3D
var forks: Array[MeshInstance3D] = []

static func make_component(input: Dictionary) -> Node3D:
	var component: Node3D = VfxPackageIO_a79f812dc5.resource("res://assets/vfx/extensions/continuation42-20261020/sources/a79f812dc5413c9a1bcf/hunters_mark.gd").new()
	component.configure(input)
	var finish := """
	float q_y=UV2.y; float q_x=abs(UV2.x-.5);
	float q_stem=1.0-smoothstep(.025,.055,abs(q_x-(.19+.10*sin(q_y*PI))));
	float q_branch=1.0-smoothstep(.025,.05,min(abs(q_y-(.35+(q_x-.24)*.8)),abs(q_y-(.63+(q_x-.24)*.8))));
	q_branch*=smoothstep(.23,.27,q_x)*(1.0-smoothstep(.40,.45,q_x));
	float q_shape=max(q_stem,q_branch)*smoothstep(.12,.20,q_y)*(1.0-smoothstep(.82,.90,q_y));
	ALPHA=(.24+.76*clamp(ALPHA,0.0,1.0))*q_shape*owned_envelope*.55;
	"""
	var body_material := ContactMaterial.make(input.material,finish)
	var source_material := ContactMaterial.make(input.material,"\nALPHA=(.25+.75*clamp(ALPHA,0.0,1.0))*sin(UV.x*PI)*sin(UV.y*PI)*owned_envelope*.50;\n")
	component.mark = component.make_mesh("ActualQuarryForkedTrackingCuts",body_material)
	component.weapon_cut = component.make_mesh("ActualQualifiedWeaponFootprint",source_material)
	for index in 2:
		component.forks.append(component.make_mesh("SourceHandTrackingFork"+str(index),source_material))
	return component

func payload_admitted() -> bool:
	return rider_admitted() and str(strike.get("attack_kind","")) == "weapon" \
		and str(strike.get("source_kind","")) == "equipped" and not str(strike.get("item_uuid","")).is_empty()

func sample(seconds: float) -> void:
	_hide_all()
	if mark_envelope(seconds) <= .0001:
		return
	var phase := str(settings.phase)
	if phase == "windup":
		if endpoints.is_empty():
			return
		var hand: Vector3 = endpoints[0].point
		for index in 2:
			var points: Array[Vector3] = []
			var widths: Array[float] = []
			for vertex in 15:
				var along := float(vertex)/14.0
				var side := -1.0 if index == 0 else 1.0
				points.append(hand+Vector3(side*along*.045,along*.08,sin(along*PI)*.015))
				widths.append(.010*sin(along*PI))
			forks[index].global_transform = Transform3D.IDENTITY
			GpuRibbon.assign(forks[index],points,widths)
			forks[index].show()
		return
	if not measured_mark(mark):
		return
	if phase == "hit" and str(weapon.get("actor","")) == str(settings.source_actor_uuid):
		var measured := measure_weapon()
		if measured.get("cells",0) > 0:
			weapon_cut.global_transform = Transform3D(Basis.IDENTITY,weapon.origin)
			weapon_cut.mesh = measured.mesh
			weapon_cut.show()

const VfxPackageIO_a79f812dc5 = preload("res://assets/vfx/extensions/continuation42-20261020/scoped_resource_io.gd")
