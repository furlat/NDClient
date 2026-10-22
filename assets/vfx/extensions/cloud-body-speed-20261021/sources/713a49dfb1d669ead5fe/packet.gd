extends Resource
## Patches-only optical transport v2. Captured data is not a gameplay fact.
## Publication is ephemeral: serialized snapshots cannot claim live readiness.
const VERSION := "factory.patches_packed_geometry.v2"
const GeometryKey = preload("res://assets/vfx/sources/9c05cee00f7d74560348/geometry_key.gd")
const PointView = preload("res://assets/vfx/extensions/speed-completion-20261021/sources/24740997d533fc6e3ec5/point_view.gd")
@export var format_version := VERSION
@export var header: Dictionary = {}
@export var positions := PackedVector3Array()
@export var normals := PackedVector3Array()
@export var groups: Array[Dictionary] = []
var _published := false
var _count := 0
var _centre := Vector3.ZERO
var _normal := Vector3.ZERO
var _legacy_rows: Array = []
var _legacy_ready := false
var _typed_legacy: Dictionary = {}
var _plain_legacy: Dictionary = {}
var legacy_materializations := 0


static func publish(actual_header: Dictionary, actual_positions: PackedVector3Array,
		actual_normals: PackedVector3Array, actual_groups: Array[Dictionary],
		ordered_position_sum: Vector3, ordered_normal_sum: Vector3) -> Resource:
	var packet: Resource = VfxPackageIO_713a49dfb1.resource("res://assets/vfx/extensions/cloud-body-speed-20261021/sources/713a49dfb1d669ead5fe/packet.gd").new()
	packet.header = actual_header
	packet.positions = actual_positions
	packet.normals = actual_normals
	packet.groups = actual_groups
	packet._count = actual_positions.size()
	if packet._count > 0:
		packet._centre = ordered_position_sum / float(packet._count)
		packet._normal = ordered_normal_sum.normalized()
	packet._published = true
	packet.header.make_read_only()
	for group: Dictionary in packet.groups:
		group.make_read_only()
	packet.groups.make_read_only()
	return packet


func admitted() -> bool:
	return _published and format_version == VERSION and header.get("ready", false) \
		and header.get("reason", "").is_empty() and _count >= 8 \
		and positions.size() == _count and normals.size() == _count \
		and not GeometryKey.from_surface(header).is_empty() \
		and _centre.is_finite() and _normal.is_finite() and not _normal.is_zero_approx()


func point_count() -> int:
	return _count if _published else 0


func frame() -> Dictionary:
	if not admitted():
		return {"valid": false}
	var bytes := positions.to_byte_array()
	bytes.append_array(normals.to_byte_array())
	bytes.resize(_count * 32)
	return {"valid": true, "count": _count, "points": bytes, "typed": true,
		"centre": _centre, "normal": _normal,
		"axis": Vector3(.31, 1., .17).slide(_normal).normalized()}


func legacy(typed: bool = true) -> Dictionary:
	if not _published:
		return {"actor": header.get("actor", ""), "points": [], "origin": Vector3.ZERO,
			"ready": false, "reason": "packed_snapshot_not_live", "gpu_geometry_key": []}
	if not _legacy_ready:
		var ordinal := 0
		for group: Dictionary in groups:
			var pixels: Array[Vector2i] = group.pixels
			var uvs: PackedVector2Array = group.uvs
			for source_ordinal: int in group.accepted:
				_legacy_rows.append({"position": positions[ordinal], "normal": normals[ordinal],
					"uv": uvs[source_ordinal], "pixel": pixels[source_ordinal], "slot": group.slot})
				ordinal += 1
		_plain_legacy = {"actor": header.actor, "actor_uuid": header.actor_uuid,
			"entity_uuid": header.entity_uuid, "points": _legacy_rows, "origin": header.origin,
			"pose_key": header.pose_key, "gpu_geometry_key": header.gpu_geometry_key,
			"ready": header.ready, "reason": header.reason}
		if header.ready:
			_plain_legacy.optical_anchor = _centre
		_legacy_ready = true
		legacy_materializations += 1
	if not typed:
		return _plain_legacy.duplicate(false)
	if _typed_legacy.is_empty():
		_typed_legacy = _plain_legacy.duplicate(false)
		_typed_legacy[PointView.FIELD] = PointView.finish(_typed_legacy, positions, normals)
	return _typed_legacy.duplicate(false)

const VfxPackageIO_713a49dfb1 = preload("res://assets/vfx/extensions/cloud-body-speed-20261021/scoped_resource_io.gd")
