extends "res://assets/vfx/sources/397ef2a8907055317449/smite_common.gd"
const GpuRibbon = preload("res://assets/vfx/sources/34e0f9ed9a909885cd97/path_ribbon.gd")
## Automatic attributed on-hit accent: four broad pressed rays and one short
## impulse on the exact physical blade. No armed/cast condition is fabricated.
var blade: MeshInstance3D
var petals: Array[MeshInstance3D] = []

static func make_component(input: Dictionary) -> Node3D:
	var component: Node3D = VfxPackageIO_5667d04933.resource("res://assets/vfx/sources/5667d04933db041e08fd/divine_smite.gd").new()
	component.configure(input)
	# Native particle erosion alone left only 7–8 isolated pixels at v63 contact.
	# The authored continuous ray core owns shape; source threshold/noise remains
	# its moving detail. Smooth ribbon edges do not create a rectangular card.
	var material := SmiteMaterial.make(input.material,"","\nALPHA=(.30+.70*clamp(ALPHA,0.0,1.0))*sin(UV.x*3.14159265)*sin(UV.y*3.14159265)*smite_envelope*.70;\n")
	var blade_material := SmiteMaterial.make(input.material,"","\nALPHA=(.25+.75*clamp(ALPHA,0.0,1.0))*smoothstep(.48,.75,UV2.y)*smite_envelope*.46;\n")
	component.blade = component.make_mesh("AttributedActualWeaponImpulse",blade_material)
	for index in 4:
		component.petals.append(component.make_mesh("PressedRadiantRay"+str(index),material))
	return component

func payload_admitted() -> bool:
	return super.payload_admitted() \
		and str(strike.get("effective_handler_uuid","")) == str(settings.effective_handler_uuid) \
		and not str(strike.get("effective_handler_uuid","")).is_empty() \
		and str(strike.get("behavior_id","")) == "reaction.class_feature.paladin.divine_smite" \
		and str(strike.get("equipment_slot","")) in ["MELEE_MAIN","MELEE_OFF"]

func sample(seconds: float) -> void:
	_hide_all()
	var value := phase_envelope(seconds) if payload_admitted() else 0.0
	_sample_materials(seconds,value)
	if value <= .0001:
		return
	var measured := measure_weapon()
	var hit := contact()
	if measured.get("cells",0) == 0 or hit.is_empty():
		return
	blade.global_transform = Transform3D(Basis.IDENTITY,weapon.origin)
	blade.mesh = measured.mesh
	blade.show()
	var normal: Vector3 = hit.normal
	var axes := plane_axes(normal)
	var progress := clampf(seconds/float(settings.seconds),0.0,1.0)
	for index in 4:
		var angle := float(index)*PI*.5+.28
		var direction: Vector3 = axes[0]*cos(angle)+axes[1]*sin(angle)
		var points: Array[Vector3] = []
		var widths: Array[float] = []
		for vertex in 17:
			var along := float(vertex)/16.0
			var radius := (.12+.27*progress)*along
			points.append(hit.position+direction*radius+normal*(.02+.08*sin(along*PI)*(1.0-progress)))
			widths.append(.050*sin(along*PI)*(1.0-.30*progress))
		petals[index].global_transform = Transform3D.IDENTITY
		GpuRibbon.assign(petals[index],points,widths)
		petals[index].show()

const VfxPackageIO_5667d04933 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
