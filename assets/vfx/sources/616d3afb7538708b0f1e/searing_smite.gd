extends "res://assets/vfx/sources/397ef2a8907055317449/smite_common.gd"
const GpuRibbon = preload("res://assets/vfx/sources/34e0f9ed9a909885cd97/path_ribbon.gd")
## One actual fire hit, then source-shaped tongues only on an admitted burn.
## Subsequent pulses require a disclosed damage fact; no turn timer rolls damage.
var blade: MeshInstance3D
var tongues: Array[MeshInstance3D] = []
var scorch: MeshInstance3D

static func make_component(input: Dictionary) -> Node3D:
	var component: Node3D = VfxPackageIO_616d3afb75.resource("res://assets/vfx/sources/616d3afb7538708b0f1e/searing_smite.gd").new()
	component.configure(input)
	var flame := SmiteMaterial.make(input.material,"","\nALPHA=sqrt(clamp(ALPHA,0.0,1.0))*smite_envelope*.70;\n")
	var surface_material := SmiteMaterial.make(input.material,"","\nALPHA=clamp(ALPHA,0.0,1.0)*smite_envelope*.32;\n")
	component.blade = component.make_mesh("ExactWeaponFireContact",flame)
	component.scorch = component.make_mesh("MeasuredRecipientScorch",surface_material)
	for index in 3:
		component.tongues.append(component.make_mesh("SourceFireTongue"+str(index),flame))
	return component

func payload_admitted() -> bool:
	return super.payload_admitted() and str(strike.get("equipment_slot","")) == "MELEE_MAIN"

func sample(seconds: float) -> void:
	_hide_all()
	var phase := str(settings.phase)
	var admitted := payload_admitted() if phase == "impact" else condition_admitted()
	if phase == "tick":
		admitted = tick_admitted() and str(tick.get("damage_type","")) == "fire"
	var value := phase_envelope(seconds) if admitted else 0.0
	if phase == "condition":
		value *= .58
	_sample_materials(seconds,value)
	if value <= .0001:
		return
	var hit := contact()
	if hit.is_empty():
		return
	if phase == "impact":
		var measured := measure_weapon()
		if measured.get("cells",0) == 0:
			return
		blade.global_transform = Transform3D(Basis.IDENTITY,weapon.origin)
		blade.mesh = measured.mesh
		blade.show()
	var patch := recipient_patch()
	var measured_patch := MeasuredSurface.build(patch,"recipient_patch",hit.position,.009)
	if measured_patch.cells > 0:
		scorch.global_transform = Transform3D(Basis.IDENTITY,patch.origin)
		scorch.mesh = measured_patch.mesh
		scorch.show()
	# The host's body_center can fall on the high outer silhouette in this
	# facing. Use the actual torso patch's centre and nearest real depth sample
	# for a retained burn; do not keep a face-side floating contact as its base.
	if not patch.points.is_empty():
		var centre := Vector3.ZERO
		for point in patch.points:
			centre += point.position
		centre /= float(patch.points.size())
		var nearest: Dictionary = patch.points[0]
		for point in patch.points:
			if point.position.distance_squared_to(centre) < nearest.position.distance_squared_to(centre):
				nearest = point
		hit = {"position":nearest.position+nearest.normal*.018,"normal":nearest.normal.normalized()}
	var normal: Vector3 = hit.normal
	var axes := plane_axes(normal)
	# Three coherent flame surfaces rise from the real torso/contact. Each has
	# its own steady phase; no orbit, solid enclosing mesh or per-pixel sparks.
	for index in 3:
		var points: Array[Vector3] = []
		var widths: Array[float] = []
		var offset := (float(index)-1.0)*.075
		var phase_offset := float(index)*2.1
		for vertex in 19:
			var along := float(vertex)/18.0
			var rise := .20 if phase == "condition" else .32
			var bend := sin(along*5.2-seconds*3.0+phase_offset)*.018*along
			points.append(hit.position+axes[0]*(offset+bend)+Vector3.UP*(along*rise-.06)+normal*(.025+along*.045))
			widths.append((.041+.024*sin(along*PI))*(1.0-along)*sin(minf(1.0,along*4.0)*PI*.5))
		tongues[index].global_transform = Transform3D.IDENTITY
		GpuRibbon.assign(tongues[index],points,widths)
		tongues[index].show()

const VfxPackageIO_616d3afb75 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
