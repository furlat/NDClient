extends "res://assets/vfx/sources/43d964a5ab22cb82ad2d/retained_contact.gd"
const GpuTube = preload("res://assets/vfx/extensions/followup-20261020/sources/bf8982a2b5574ce024cf/contact_tube.gd")
## Three native bark vines follow measured recipient limbs/torso. The weapon
## attempt, save, restrained state and piercing tick remain authoritative inputs.
var vines: Array[MeshInstance3D] = []

static func make_component(input: Dictionary) -> Node3D:
	var component: Node3D = VfxPackageIO_c35ca443bf.resource("res://assets/vfx/extensions/followup-20261020/sources/c35ca443bf2367a11e75/ensnaring_strike.gd").new()
	component.configure(input)
	var material := ContactMaterial.make(input.material,"\nALPHA=clamp(ALPHA,0.0,1.0)*owned_envelope; ALPHA_SCISSOR_THRESHOLD=0.0;\n")
	for index in 3:
		component.vines.append(component.make_mesh("MeasuredBarkVine"+str(index),material))
	return component

func payload_admitted() -> bool:
	# This spell has no extra initial damage component: an accepted condition is
	# the magical payload. Do not fabricate a smite Damage UUID for its admission.
	return condition_admitted() \
		and str(strike.get("source_actor_uuid","")) == str(settings.source_actor_uuid) \
		and str(strike.get("recipient_uuid","")) == str(settings.recipient_uuid) \
		and str(strike.get("item_uuid","")) == str(settings.item_uuid) \
		and str(strike.get("attack_uuid","")) == str(settings.attack_uuid) \
		and str(strike.get("behavior_id","")) == "spell.ensnaring_strike" \
		and str(strike.get("source_kind","")) == "equipped" \
		and str(strike.get("attack_kind","")) == "weapon" \
		and str(strike.get("equipment_slot","")) == str(settings.equipment_slot) \
		and str(strike.get("equipment_slot","")) in ["MELEE_MAIN","RANGED_MAIN"] \
		and str(strike.get("outcome","")) in ["hit","critical"]

func sample(seconds: float) -> void:
	_hide_all()
	var phase := str(settings.phase)
	var admitted := payload_admitted() if phase == "application" else condition_admitted()
	if phase == "tick":
		admitted = tick_admitted() and str(tick.get("damage_type","")) == "piercing"
	var value := phase_envelope(seconds) if admitted else 0.0
	_sample_materials(seconds,value)
	if value <= .0001:
		return
	var growth := smoothstep(0.0,.38,seconds) if phase == "application" else 1.0
	# Open diagonal strands follow actual sampled skin/cloth/leg depth. They do
	# not form rings, a generic enclosing cylinder or an unrelated floor trap.
	for index in 3:
		var horizontal: Array = []
		var heights: Array = []
		for vertex in 30:
			var along := float(vertex)/29.0
			horizontal.append(lerpf(.12,.88,along) if index != 1 else lerpf(.88,.12,along))
			var low: float = [.17,.33,.49][index]
			heights.append(low+.10*sin(along*PI)+.09*along)
		var points := body_path(horizontal,heights,.018)
		if points.size() < 2:
			continue
		var radius := .013 if phase != "tick" else .019
		vines[index].global_transform = Transform3D.IDENTITY
		GpuTube.assign(vines[index],points,radius,growth)
		vines[index].show()
	for material in materials:
		material.set_shader_parameter("DisolverSTEP",1.0-value if phase == "retire" else -.2)

const VfxPackageIO_c35ca443bf = preload("res://assets/vfx/extensions/followup-20261020/scoped_resource_io.gd")
