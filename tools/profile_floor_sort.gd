extends SceneTree
# Exact source-order diagnostic on the recorded Gallery tile after-values.
# No renderer or SDK mutation; timings include key construction and row mapping.
const Sources = preload("res://presentation/sprite_sources.gd")
var checks := 0
var failures: Array = []

func _initialize() -> void: run.call_deferred()

func original(rows: Array, packets: Dictionary, probe: Node) -> void:
    for row in rows:
        if not packets.has(row.id) or packets[row.id].row != row:
            packets[row.id] = {"row":row,"y":probe.Placement.project(Vector2(row.position[0],row.position[1]),0,probe.quarter).y}
    rows.sort_custom(func(a,b):return packets[a.id].y < packets[b.id].y)

func candidate(rows: Array, packets: Dictionary, probe: Node) -> void:
    var keys := PackedFloat64Array()
    keys.resize(rows.size())
    for i in range(rows.size()):
        var row: Dictionary = rows[i]
        if not packets.has(row.id) or packets[row.id].row != row:
            packets[row.id] = {"row":row,"y":probe.Placement.project(Vector2(row.position[0],row.position[1]),0,probe.quarter).y}
        keys[i] = packets[row.id].y
    var order: Array = range(rows.size())
    order.sort_custom(func(a,b):return keys[a] < keys[b])
    var sorted: Array = []
    sorted.resize(rows.size())
    for i in range(order.size()): sorted[i] = rows[order[i]]
    rows.assign(sorted)

func check(value: bool, label: String) -> void:
    checks += 1
    if not value: failures.append(label)

func run() -> void:
    var tiles := {}
    var snapshots: Array = []
    var directory := "res://.runtime/gallery-route/journal"
    for sequence in range(102):
        var packet: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("%016d.json" % sequence)))
        var parts: Array = [packet.initialization] if sequence == 0 else packet.lineages
        for part in parts:
            var updates := {}
            for update in part.world_updates: updates[update.event_uuid] = update
            for node in part.get("nodes",part.get("events",[])):
                if not updates.has(node.uuid): continue
                for tile in updates[node.uuid].tiles: tiles["%d,%d" % tile.position] = tile
                if sequence == 99:
                    var rows: Array = []
                    for tile in tiles.values():
                        if tile.elevation_steps == 0 and tile.surface.base_material == "stone":
                            rows.append({"id":tile.tile_uuid,"position":tile.position,"base_height_steps":0,"kind":"terrain","material":"stone","layer":0,"orientation":"east","boundaries":[]})
                    snapshots.append(rows)
    # A remove/readd before one scene consume changes Dictionary insertion order
    # even when this same immutable row and all its source fields are retained.
    var reordered: Array = snapshots.back().duplicate()
    reordered.append(reordered.pop_front())
    snapshots.append(reordered)
    var evidence: Array = []
    var probe = Sources.new()
    for quarter in range(4):
        probe.quarter = quarter
        for index in range(snapshots.size()):
            var input: Array = snapshots[index]
            var baseline: Array = input.duplicate()
            var alternate: Array = input.duplicate()
            var before := Time.get_ticks_usec(); original(baseline,{},probe)
            var old_cold := Time.get_ticks_usec()-before
            before = Time.get_ticks_usec(); candidate(alternate,{},probe)
            var new_cold := Time.get_ticks_usec()-before
            check(baseline == alternate,"Exact original unstable-Y permutation q%d source99/%d" % [quarter,index])
            var production: Array = input.duplicate(); probe._ground_sort(production,{})
            check(production == baseline,"Production matches original permutation q%d source99/%d" % [quarter,index])
            var old_packets := {}; var new_packets := {}
            original(input.duplicate(),old_packets,probe); candidate(input.duplicate(),new_packets,probe)
            var old_warm: Array = []; var new_warm: Array = []
            for repeat in range(5):
                baseline = input.duplicate(); alternate = input.duplicate()
                before = Time.get_ticks_usec(); original(baseline,old_packets,probe); old_warm.append((Time.get_ticks_usec()-before)/1000.0)
                before = Time.get_ticks_usec(); candidate(alternate,new_packets,probe); new_warm.append((Time.get_ticks_usec()-before)/1000.0)
                check(baseline == alternate,"Warm retained-packet permutation q%d source99/%d repeat%d" % [quarter,index,repeat])
            evidence.append({"quarter":quarter,"source_update":index if index<10 else "remove_readd_fixture","rows":input.size(),"old_cold_ms":old_cold/1000.0,"candidate_cold_ms":new_cold/1000.0,"old_warm_ms":old_warm,"candidate_warm_ms":new_warm})
    probe.free()
    var report := {"checks":checks,"failures":failures,"scope":"Actual operation99 stone floor input order at all10 sensory updates plus a same-row remove/readd-before-consume fixture,4quarters; identical native Array.sort_custom comparator/ties. CPU includes packet/key setup, index sorting and final row mapping. No GPU or frame-speed claim.","cases":evidence}
    FileAccess.open("res://generated/floor_sort_cpu.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("FLOOR_SORT_CPU ",checks," checks; ",failures.size()," failures")
    quit(0 if failures.is_empty() else 1)
