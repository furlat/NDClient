extends SceneTree
# Named boundary fixture: reuse a captured attacker/support row and actual attack
# occurrence, but defer their first admission. This is not a new gameplay capture.
const Compiler = preload("res://presentation/compiler.gd")
const Timeline = preload("res://presentation/timeline.gd")
const Characters = preload("res://presentation/characters.gd")
const Protocol = preload("res://sdk/protocol.gd")
const Reducer = preload("res://sdk/reducer.gd")
var checks = 0
var failures = 0

func check(value: bool, label: String) -> void:
    checks += 1
    if not value: failures += 1; print("STAGING_FIXTURE_FAIL ",label)

func _initialize() -> void:
    var directory = "C:/Users/tommaso/AppData/Local/Temp/ndclient-presentation-attack/amber/journal"
    var protocol = Protocol.new()
    var state = {}
    var names = DirAccess.get_files_at(directory); names.sort()
    for name in names:
        if not name.ends_with(".json"): continue
        var root = "InitializationResponse" if state.is_empty() else "PlayerOperation"
        var decoded = protocol.decode(root,FileAccess.get_file_as_bytes(directory.path_join(name)))
        if not decoded.ok: check(false,"captured packet decodes"); break
        var packet: Dictionary = protocol.normalize(root,decoded.value)
        if state.is_empty(): state = Reducer.reduce_initialization(packet.initialization,packet.content_additions).value; continue
        var selected = {}
        for lineage in packet.lineages:
            for node in lineage.events:
                if node.fact != null and node.fact.kind == "attack": selected = {"lineage":lineage,"node":node}; break
            if not selected.is_empty(): break
        if selected.is_empty(): state = Reducer.reduce_operation(state,packet).value; continue
        run_fixture(state,packet,selected,protocol)
        break
    check(checks > 0,"captured attack boundary found")
    print("PRESENTATION_STAGING_BOUNDARY_FIXTURE checks=",checks," failures=",failures)
    quit(1 if failures else 0)

func run_fixture(before: Dictionary, packet: Dictionary, selected: Dictionary, protocol: RefCounted) -> void:
    var actor: Dictionary = before.actors[selected.node.fact.source_entity_uuid].duplicate(true)
    var key = Reducer.Audience.point_key(actor.last_visual_position)
    var tile: Dictionary = before.tiles[key].duplicate(true)
    var captured_support = false
    for world in selected.lineage.world_updates:
        for candidate in world.tiles:
            if Reducer.Audience.point_key(candidate.position) == key:
                tile = candidate.duplicate(true)
                captured_support = true
                break
        if captured_support: break
    var fixture = packet.duplicate(true)
    var lineage: Dictionary = fixture.lineages.filter(func(row): return row.lineage_uuid == selected.lineage.lineage_uuid)[0]
    lineage.observations = lineage.observations.filter(func(row): return row.actor.uuid != actor.uuid)
    lineage.observations.push_front({"event_uuid":selected.node.uuid,"actor":actor,"contact":null})
    var update = {"event_uuid":selected.node.uuid,"tiles":[tile],"objects":[],"objects_removed":[],"connectors":before.connectors.duplicate(true)}
    lineage.world_updates = lineage.world_updates.filter(func(row): return row.event_uuid != selected.node.uuid)
    lineage.world_updates.append(update)
    check(protocol.validate("PlayerOperation",fixture).ok,"fixture retains valid typed operation shape")
    var absent = before.duplicate(true)
    absent.actors.erase(actor.uuid); absent.tiles.erase(key)
    var cache = {}
    var compiled = Compiler.compile(absent,fixture,cache)
    check(compiled.ok,"compiler accepts deferred captured admission")
    if not compiled.ok: return
    var group: Dictionary = compiled.value.groups.filter(func(row): return row.id == lineage.lineage_uuid)[0]
    check(group.staged_actors.get(actor.uuid) == actor,"staged actor is first captured admission")
    check(group.staged_tiles.get(key) == tile,"staged support is first captured world row")
    check(group.staged_tile_at_ms[key] <= group.staged_at_ms[actor.uuid],"support ready when actor is presented")
    var timeline = Timeline.new()
    timeline.accept({"kind":"initialization","state":absent.duplicate(true),"sequence":-1})
    timeline.accept({"kind":"operation","groups":compiled.value.groups})
    timeline.advance(.001)
    check(timeline.staged_actors().has(actor.uuid),"actor available before final attack commit")
    check(timeline.staged_tiles().has(key),"support available before canonical world commit")
    check(not timeline.state.actors.has(actor.uuid) and not timeline.state.tiles.has(key),"staging does not mutate canonical state")
    var resolved = Characters.resolve(actor,timeline.presentation_state(),cache)
    check(resolved.ok and resolved.value != null,"real actor authoring resolves against staged support")
    if resolved.ok and resolved.value != null: check(resolved.value.base_height_steps == tile.elevation_steps,"staged support retains captured elevation")
    var sample: Dictionary = timeline.actor_samples().get(actor.uuid,{})
    check(not sample.is_empty() and is_equal_approx(sample.base_height_steps,tile.elevation_steps),"stationary attack uses captured staged support elevation")
    timeline.advance(100000)
    check(timeline.state == compiled.value.final_state,"canonical final state remains exact")
    var existing = Compiler.compile(before,fixture,cache)
    check(existing.ok,"existing-support comparison compiles")
    if existing.ok:
        for row in existing.value.groups: check(not row.staged_tiles.has(key),"staging never replaces existing support")
