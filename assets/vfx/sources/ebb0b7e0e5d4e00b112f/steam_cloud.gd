extends Node3D
## Maintained secondary owner, separate from the finite vaporization accent.
## Its admitted cells and lifetime are supplied; no gameplay clock is inferred.
const Emitters = preload("res://assets/vfx/sources/640361420840ef7d5319/source_emitters.gd")
var settings: Dictionary
var plumes: Array[GPUParticles3D] = []
var positions: Array[Vector3] = []
var layout_dirty := true

static func make_component(input: Dictionary) -> Node3D:
	var node := VfxPackageIO_ebb0b7e0e5.resource("res://assets/vfx/sources/ebb0b7e0e5d4e00b112f/steam_cloud.gd").new() as Node3D
	node.settings=input.duplicate(true)
	node.set_admitted_cells(input.get("cells",[]))
	for index in int(input.get("emitter_count", 18)):
		var plume: GPUParticles3D=Emitters.make(node,"steam",index)
		var process: ParticleProcessMaterial=plume.process_material
		plume.amount=int(input.get("particles_per_emitter", 14))
		process.scale_min=float(input.get("particle_scale_min", .75))
		process.scale_max=float(input.get("particle_scale_max", 1.15))
		process.gravity=Vector3(0,.55,0)
		node.plumes.append(plume)
	return node

func set_admitted_cells(cells: Array) -> void:
	if cells.is_empty() or cells.size()>32:
		push_error("Steam owner needs 1–32 explicitly admitted local cells")
		return
	layout_dirty=true
	positions.clear()
	for cell in cells:
		positions.append(Vector3(cell[0],.06,cell[1]))

func sample(seconds: float) -> void:
	var retire_at := float(settings.get("retire_at",INF))
	var retirement := 1.-smoothstep(retire_at,retire_at+.7,seconds) if is_finite(retire_at) else 1.
	var strength := smoothstep(0.,.5,seconds)*retirement
	if layout_dirty:
		_arrange()
	for plume in plumes:
		Emitters.sample(plume,seconds,strength)

func _arrange() -> void:
	layout_dirty=false
	for index in plumes.size():
		if positions.is_empty():continue
		var jitter := Vector3(sin(index*17.3),0,cos(index*11.8))*.23
		if settings.has("cell_fill_radius_cells"):
			var cell_index := index % positions.size()
			var slot := floori(float(index) / float(positions.size()))
			var count := ceili(float(plumes.size()) / float(positions.size()))
			var angle := float(slot) * 2.39996323 + float(cell_index) * .71
			var radius := sqrt((float(slot) + .5) / float(count)) * float(settings.cell_fill_radius_cells)
			jitter = Vector3(cos(angle) * radius, .06 * sin(float(index) * 1.7), sin(angle) * radius)
		plumes[index].position=positions[index%positions.size()]+jitter

func set_retirement_time(seconds: float) -> void:
	settings.retire_at=seconds

const VfxPackageIO_ebb0b7e0e5 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
