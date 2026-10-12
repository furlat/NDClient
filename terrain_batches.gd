extends RefCounted
const Placement = preload("res://placement.gd")
# Batch only the lowest flat ground band. Upright pieces and raised supports
# retain individual semantic ordering, so the actor can pass between them.
static func clear(world: Node) -> void:
    for node in world.terrain_batches: node.queue_free()
    world.terrain_batches.clear()
    for entry in world.entries:
        if entry.get("batched",false):
            entry.node.visible = true
            entry.erase("batched")

static func rebuild(world: Node) -> void:
    var state=begin(world)
    while not step(world,state):pass

static func begin(world: Node) -> Dictionary:
    clear(world)
    if world.map_min_height<0:return {"done":true}
    for row in world.actor_rows:
        if row.base_height_steps < 0:return {"done":true}
    return {"done":false,"cursor":0,"groups":{},"phase":"group"}

static func step(world: Node, state: Dictionary) -> bool:
    if state.done:return true
    var started=Time.get_ticks_usec()
    while state.phase=="group" and state.cursor<world.draw_order.size():
        var entry: Dictionary=world.draw_order[state.cursor];state.cursor+=1
        var row: Dictionary = entry.placement
        if not row.has("source_sprite") or entry.role != "terrain" or row.base_height_steps != 0 or not row.get("batchable",false):continue
        if world.destruction.has(row.id):continue
        var group_key = [row.source_sprite,row.layer,roundi(Placement.sort_contact(row,world.quarter).y/32.0),row.get("tint",[]),row.get("affine",[])]
        if not state.groups.has(group_key):state.groups[group_key]=[]
        state.groups[group_key].append(entry)
        if Time.get_ticks_usec()-started>4000:
            world.FrameProfile.end_phase(world.profile,"terrain_batch_build",started)
            return false
    if state.phase=="group":state.phase="build";state.cursor=0;state.groups=state.groups.values()
    while state.cursor<state.groups.size():
        var group: Array=state.groups[state.cursor];state.cursor+=1
        if group.size()<3:continue
        var first: Dictionary = group[0]
        var multimesh = MultiMesh.new()
        multimesh.transform_format = MultiMesh.TRANSFORM_3D
        multimesh.mesh = first.node.mesh
        multimesh.instance_count = group.size()
        for i in range(group.size()):
            multimesh.set_instance_transform(i,group[i].node.transform)
            group[i].node.visible = false
            group[i].batched = true
        var node = MultiMeshInstance3D.new()
        node.multimesh = multimesh
        node.material_override = first.material
        node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        node.sorting_use_aabb_center = false
        node.sorting_offset = first.node.sorting_offset
        world.add_child(node)
        world.terrain_batches.append(node)
        if Time.get_ticks_usec()-started>4000:
            world.FrameProfile.end_phase(world.profile,"terrain_batch_build",started)
            return false
    world.FrameProfile.end_phase(world.profile,"terrain_batch_build",started)
    state.done=true
    return true
