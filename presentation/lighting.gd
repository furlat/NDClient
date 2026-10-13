extends RefCounted
## Disclosed item emitters only. Backend perception and source rules stay native.
const Placement = preload("res://placement.gd")
# Inventory-only portable lights have no authored hand/equipment binding. Keep
# their backend XY and radius, with an explicit above-avatar optical elevation.
const CARRIED_OPTICAL_LIFT_STEPS := 2.5
const UNREGISTERED_OPTICAL_LIFT_STEPS := 1.0
var carried_optical_lift_steps := CARRIED_OPTICAL_LIFT_STEPS
var sources: Array = []
var issues: Array = []
# The renderer owns light culling, attenuation and colour accumulation. Exact
# backend radii remain in sources for gameplay/debugging; optical falloff is
# Godot's spherical OmniLight3D falloff, not a second gameplay light solver.
const OPTICAL_ENERGY := 2.0
var nodes: Dictionary = {}
var sampled: Dictionary = {}
var _parent: Node3D

func attach(parent: Node3D) -> void:
    _parent = parent
    _sync_nodes()

func _sync_nodes() -> void:
    var wanted := {}
    for source in sources: wanted[source.item_uuid] = true
    for id in nodes.keys():
        if wanted.has(id): continue
        nodes[id].visible = false
        nodes[id].queue_free()
        nodes.erase(id)
        sampled.erase(id)
    if not is_instance_valid(_parent): return
    for source in sources:
        if nodes.has(source.item_uuid): continue
        var node := OmniLight3D.new()
        node.name = ("Emitter_"+source.item_uuid).validate_node_name()
        node.shadow_enabled = false
        node.omni_attenuation = 1.0
        _parent.add_child(node)
        nodes[source.item_uuid] = node

static func directionals(policy: Dictionary) -> Dictionary:
    var nodes: Array[DirectionalLight3D] = []
    var missing: Array = []
    for source in policy.get("directionalSources", []):
        var values: Array = source.get("directionToSource", [])
        var colour: Array = source.get("colorLinear", [])
        if values.size() != 3 or colour.size() != 3 or float(source.get("intensity", -1)) < 0:
            missing.append("Invalid authored directional light: " + str(source.get("id", "")))
            continue
        var direction := Vector3(values[0], values[1], values[2])
        if not direction.is_finite() or direction.is_zero_approx() or colour.any(func(value): return not is_finite(float(value)) or float(value) < 0) or not is_finite(float(source.intensity)):
            missing.append("Invalid authored directional light: " + str(source.get("id", "")))
            continue
        var node := DirectionalLight3D.new()
        node.name = str(source.id).validate_node_name()
        # Native lights emit down local -Z; authored direction points toward it.
        var up := Vector3.RIGHT if absf(direction.normalized().dot(Vector3.UP)) > 0.999 else Vector3.UP
        node.basis = Basis.looking_at(-direction.normalized(), up)
        node.light_color = Color(colour[0], colour[1], colour[2]).linear_to_srgb()
        node.light_energy = source.intensity
        node.shadow_enabled = false
        nodes.append(node)
    return {"nodes":nodes,"issues":missing}

static func _point(position: Array, height: float, lift: float = UNREGISTERED_OPTICAL_LIFT_STEPS) -> Vector3:
    return Vector3(position[0], (height + lift) * Placement.HEIGHT_UNIT, position[1])

static func _source(item: Dictionary, anchor: String, position: Vector3, output: Array, missing: Array, base_height: float = 0.0) -> void:
    if item.get("is_lit") != true: return
    for field in ["very_bright_radius_feet", "bright_radius_feet", "dim_radius_feet"]:
        if item.get(field) == null:
            missing.append({"item_uuid":item.item_uuid,"reason":"disclosed emitter lacks " + field})
            return
    # Preserve the exact backend feet values in the row. Gridmap._compute_light_tiles
    # floors bright/outer to cells (minimum one); very-bright is a fractional radius.
    var very := float(item.very_bright_radius_feet) / 5.0
    var bright := maxf(floor(float(item.bright_radius_feet) / 5.0), 1.0)
    var outer := maxf(floor(float(item.bright_radius_feet + item.dim_radius_feet) / 5.0), 1.0)
    output.append({"item_uuid":item.item_uuid,"item_id":item.get("item_id",""),"actor_uuid":anchor,"position":position,"base_height_steps":base_height,
        "very_bright_radius_feet":item.very_bright_radius_feet,"bright_radius_feet":item.bright_radius_feet,
        "dim_radius_feet":item.dim_radius_feet,"very":very,"bright":bright,"outer":outer})

static func resolve(state: Dictionary) -> Dictionary:
    var output: Array = []
    var missing: Array = []
    var senses: Dictionary = state.get("senses", {}) if state.get("senses") != null else {}
    var contacts: Dictionary = senses.get("objects", {})
    for id in state.get("objects", {}):
        var object: Dictionary = state.objects[id]
        # Remembered placements do not establish a currently visible emitter.
        if not contacts.get(id, {}).get("visual", false): continue
        var placement: Dictionary = object.placement
        _source(object.item, "", _point(placement.position, placement.base_height_steps), output, missing, placement.base_height_steps)
    var controlled: Array = state.get("audience", {}).get("controlled", [])
    for id in state.get("actors", {}):
        var actor: Dictionary = state.actors[id]
        if not actor.get("present", true) or actor.get("last_visual_position") == null or actor.get("spatial_disposition", "present") != "present": continue
        if id not in controlled and not senses.get("entities", {}).get(id, {}).get("visual", false): continue
        var position: Array = actor.last_visual_position
        var tile: Dictionary = state.get("tiles", {}).get("%d,%d" % [position[0], position[1]], {})
        if not tile.has("elevation_steps"):
            missing.append({"actor_uuid":id,"reason":"disclosed emitter anchor lacks support elevation"})
            continue
        var items: Array = actor.get("controlled_items", []) if id in controlled and actor.get("controlled_items") != null else actor.get("visual_loadout", {}).get("layers", [])
        var seen := {}
        for item in items:
            if seen.has(item.item_uuid): continue
            seen[item.item_uuid] = true
            _source(item, id, _point(position, tile.elevation_steps,CARRIED_OPTICAL_LIFT_STEPS), output, missing,tile.elevation_steps)
    output.sort_custom(func(a,b): return a.item_uuid < b.item_uuid)
    return {"sources":output,"issues":missing}

func sync(state: Dictionary) -> void:
    var result := resolve(state)
    sources = result.sources
    issues = result.issues
    _sync_nodes()
    sample({})

func sample(actor_rows: Dictionary, source_energy: Dictionary = {}, fixture_heights: Dictionary = {}) -> void:
    for source in sources:
        var position: Vector3 = source.position
        if not source.actor_uuid.is_empty() and actor_rows.has(source.actor_uuid):
            var row: Dictionary = actor_rows[source.actor_uuid]
            position = _point(row.position, row.base_height_steps + row.get("visual_height", 0.0),carried_optical_lift_steps)
        elif source.actor_uuid.is_empty() and fixture_heights.has(source.item_uuid):
            # Original flame registration owns optical height; XY remains the
            # native radial footprint, never shifted with the billboard camera.
            position.y = (source.base_height_steps+fixture_heights[source.item_uuid])*Placement.HEIGHT_UNIT
        var energy := float(source_energy.get(source.item_uuid,1.0)) * OPTICAL_ENERGY
        sampled[source.item_uuid] = {"position":position,"energy":energy,"range":source.outer}
        if nodes.has(source.item_uuid):
            var node: OmniLight3D = nodes[source.item_uuid]
            node.position = position
            node.omni_range = source.outer
            node.light_energy = energy

func apply(material: ShaderMaterial) -> void:
    material.set_shader_parameter("authored_base_light", 0.0)
