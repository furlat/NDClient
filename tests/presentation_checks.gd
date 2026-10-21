extends SceneTree
const Compiler = preload("res://presentation/compiler.gd")
const Journal = preload("res://sdk/journal.gd")
const Reducer = preload("res://sdk/reducer.gd")
const Timeline = preload("res://presentation/timeline.gd")
const Occurrences=preload("res://presentation/occurrences.gd")
const Authoring = preload("res://presentation/authoring.gd")
var evidence = {"committed_steps":0,"uncommitted_steps":0,"jump_segments":0,"oa":0,"damage_contacts":0,"canceled":0}
var failed := 0
var checks := 0

func check(value: bool, label: String) -> void:
    checks += 1
    if not value: failed += 1; print("PRESENTATION_FAIL ",label)

func at_time(before: Dictionary, group: Dictionary, time: float) -> RefCounted:
    var timeline = Timeline.new()
    timeline.accept({"kind":"initialization","state":before.duplicate(true),"sequence":-1})
    timeline.accept({"kind":"operation","groups":[group]})
    timeline.advance(time)
    return timeline

func verify_group(before: Dictionary, group: Dictionary, lineage: Dictionary, cache: Dictionary) -> void:
    for key in group.staged_tiles:
        check(not before.tiles.has(key),"staged support never replaces existing terrain")
        check(group.staged_tile_at_ms.has(key),"staged support has admission time")
    var by_lineage = {}
    for node in lineage.events: by_lineage[node.lineage_id] = node
    var occurrences = {}
    for node in lineage.events:
        if node.fact != null and node.fact.kind == "attack" and node.fact.behavior_id == "reaction.opportunity_attack": evidence.oa += 1
    for track in group.actor_tracks:
        if track.priority == 20:
            check(not occurrences.has(track.occurrence),"distinct attack occurrence")
            occurrences[track.occurrence] = true
    var gait = {}
    for track in group.actor_tracks:
        if track.get("motion",false) and track.trajectory == "path":
            if gait.has(track.occurrence): check(is_equal_approx(gait[track.occurrence].source_end_seconds,track.source_start_seconds),"continuous Run phase across cells")
            gait[track.occurrence] = track
    var flights = {}
    for track in group.actor_tracks:
        if track.get("motion",false) and track.trajectory == "direct_arc":
            if flights.has(track.occurrence):
                var previous: Dictionary = flights[track.occurrence]
                check(previous.to_position == track.from_position,"jump segments preserve admitted connectivity")
                check(is_equal_approx(previous.source_end_seconds,track.source_start_seconds),"one continuous authored jump clock")
                check(is_equal_approx(previous.motion_fraction_to,track.motion_fraction_from),"one continuous jump arc")
                check(is_equal_approx(previous.arc_height_px,track.arc_height_px),"jump keeps authored arc height")
            flights[track.occurrence] = track
    for node in lineage.events:
        if node.canceled:
            evidence.canceled += 1
            check(not group.actor_tracks.any(func(t): return t.source_lineage == node.lineage_id and t.priority >= 10),"canceled body is not played")
        if node.fact == null: continue
        var fact: Dictionary = node.fact
        if fact.kind == "step":
            var motions = group.actor_tracks.filter(func(t): return t.get("motion",false) and t.actor_uuid == fact.source_entity_uuid and t.from_position == fact.from_position and t.to_position == fact.to_position)
            if not fact.committed or node.canceled:
                evidence.uncommitted_steps += 1
                check(motions.is_empty(),"uncommitted edge never played")
                for identity in node.children_lineages:
                    var attacks = group.actor_tracks.filter(func(t): return t.occurrence == identity and t.priority == 20)
                    if attacks.is_empty(): continue
                    var attack: Dictionary = attacks[0]
                    var held = at_time(before,group,attack.start_ms+attack.duration_ms*.5).actor_samples().get(fact.source_entity_uuid,{})
                    check(not held.is_empty() and held.get("position") != null and Vector2(held.position[0],held.position[1]).is_equal_approx(Vector2(fact.from_position[0],fact.from_position[1])),"interrupted mover stays at last committed contact")
                continue
            evidence.committed_steps += 1
            check(motions.size() == 1,"one track per committed edge")
            if motions.is_empty(): continue
            var track: Dictionary = motions[0]
            if fact.trajectory == "path":
                var context = Authoring.load_data("catalog/movement_context.json",cache)
                var distance = Vector2(fact.from_position[0],fact.from_position[1]).distance_to(Vector2(fact.to_position[0],fact.to_position[1]))
                var speed_scale = fact.resolved_speed_feet / Authoring.movement_reference_speed(cache) if fact.resolved_speed_feet != null and fact.resolved_speed_feet > 0 else 1.0
                check(is_equal_approx(track.duration_ms,context.walkStepDurationMs*distance/speed_scale),"recorded speed and distance own traversal time")
            if fact.trajectory == "direct_arc": evidence.jump_segments += 1
            for fraction in [.25,.5,.75]:
                var timeline = at_time(before,group,track.start_ms+track.duration_ms*fraction)
                var sample: Dictionary = timeline.actor_samples().get(track.actor_uuid,{})
                check(not sample.is_empty(),"committed movement sample exists")
                if sample.is_empty(): continue
                check(Vector2(sample.position[0],sample.position[1]).is_equal_approx(Vector2(fact.from_position[0],fact.from_position[1]).lerp(Vector2(fact.to_position[0],fact.to_position[1]),fraction)),"movement samples actual edge")
                check(is_equal_approx(sample.base_height_steps,lerpf(fact.from_elevation_feet,fact.to_elevation_feet,fraction)/5),"elevation comes from recorded feet")
                var expected_clock = lerpf(track.source_start_seconds,track.source_end_seconds,fraction)
                if track.has("source_time_keys"): expected_clock = Compiler.Tracks._source_at(track.source_time_keys,fraction)
                check(is_equal_approx(sample.source_seconds,expected_clock),"sample follows authored source clock")
                if fact.trajectory == "direct_arc":
                    var progress = lerpf(track.motion_fraction_from,track.motion_fraction_to,fraction)
                    check(is_equal_approx(sample.lift_pixels,sin(PI*progress)*track.arc_height_px),"sample follows continuous authored jump arc")
            for identity in node.children_lineages:
                var child: Dictionary = by_lineage.get(identity,{})
                if child.is_empty() or child.fact == null or child.fact.kind != "attack": continue
                var attacks = group.actor_tracks.filter(func(t): return t.occurrence == child.lineage_id and t.priority == 20)
                if attacks.is_empty(): continue
                var attack: Dictionary = attacks[0]
                check(track.start_ms >= attack.start_ms+attack.duration_ms,"OA completes before entry")
                var held = at_time(before,group,attack.start_ms+attack.duration_ms*.5).actor_samples().get(track.actor_uuid,{})
                check(not held.is_empty() and held.get("position") != null and Vector2(held.position[0],held.position[1]).is_equal_approx(Vector2(fact.from_position[0],fact.from_position[1])),"mover held at recorded source during OA")
        if fact.kind == "damage" and fact.stage == "applied" and fact.applied_damage > 0 and not node.canceled:
            var ancestor = node
            while ancestor.get("parent_lineage") != null and by_lineage.has(ancestor.parent_lineage):
                ancestor = by_lineage[ancestor.parent_lineage]
                if ancestor.fact != null and ancestor.fact.kind == "attack": break
            if ancestor.fact == null or ancestor.fact.kind != "attack": continue
            var attacks = group.actor_tracks.filter(func(t): return t.occurrence == ancestor.lineage_id and t.priority == 20)
            if attacks.is_empty(): continue
            evidence.damage_contacts += 1
            var attack: Dictionary = attacks[0]
            var commits = group.commits.filter(func(c): return c.get("event_uuid") == node.id)
            check(commits.size() == 1 and is_equal_approx(commits[0].at_ms,attack.contact_ms),"HP commits exactly at authored contact/release")
            check(attack.contact_ms > attack.start_ms,"contact/release is after attack start")
            var prior = at_time(before,group,maxf(0,attack.contact_ms-.001))
            var after = at_time(before,group,attack.contact_ms)
            check(after.state.actors[fact.target_entity_uuid].normal_hp == fact.resulting_normal_hp,"contact exposes recorded HP after-value")
            if before.actors.has(fact.target_entity_uuid) and before.actors[fact.target_entity_uuid].normal_hp != fact.resulting_normal_hp:
                check(prior.state.actors[fact.target_entity_uuid].normal_hp != fact.resulting_normal_hp,"HP after-value not visible before contact")

func _initialize() -> void:
    var directory = ""
    var limit = 12
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--journal="): directory = arg.trim_prefix("--journal=")
        if arg.begins_with("--limit="): limit = int(arg.trim_prefix("--limit="))
    if directory.is_empty():printerr("Requires --journal=<actual schema16 journal>");quit(2);return
    var names = DirAccess.get_files_at(directory)
    names.sort()
    var journal = Journal.new()
    var opened = journal.open(directory,true,false)
    check(opened.ok,"Recording carries its admitted historical protocol")
    if not opened.ok: quit(1); return
    var protocol = journal.protocol
    var state: Dictionary = {}
    var cache = {}
    var operations = 0
    var tracks = 0
    var kinds = {}
    for name in names:
        if not name.ends_with(".json"): continue
        var decoded = protocol.decode("InitializationResponse" if state.is_empty() else "PlayerOperation",FileAccess.get_file_as_bytes(directory.path_join(name)))
        check(decoded.ok,"decode "+name)
        if not decoded.ok: break
        var packet: Dictionary = protocol.normalize("InitializationResponse" if state.is_empty() else "PlayerOperation",decoded.value)
        if state.is_empty():
            state = Reducer.reduce_initialization(packet.initialization,packet.content_additions).value
            continue
        var prior = state.duplicate(true)
        var compiled = Compiler.compile(state,packet,cache)
        check(compiled.ok,"compile "+name)
        if not compiled.ok: print(compiled); break
        check(state == prior,"input immutable "+name)
        var reused = Compiler.compile_admitted(state,packet,cache,compiled.value.final_state)
        check(reused.ok and reused.value == compiled.value,"Journal-admitted compilation preserves every track and commit "+name)
        var displayed = state.duplicate(true)
        for group in compiled.value.groups:
            var source = packet.lineages.filter(func(l): return str(l.lineage) == str(group.id))
            if not source.is_empty(): verify_group(displayed,group,Occurrences.group(source[0]),cache)
            var last = -1.0
            for commit in group.commits:
                check(commit.at_ms >= last,"ordered commits "+name)
                last = commit.at_ms
                Compiler.apply_delta(displayed,commit.delta)
            for track in group.actor_tracks:
                tracks += 1
                kinds[track.trajectory] = true
                check(track.duration_ms > 0 and track.source_end_seconds >= 0 and track.source_start_seconds >= 0,"authored timing "+name)
                check(not track.occurrence.is_empty(),"occurrence identity "+name)
        check(displayed == compiled.value.final_state,"all sparse commits equal SDK state "+name)
        state = compiled.value.final_state
        operations += 1
        if operations >= limit: break
    check(operations > 0,"real operations loaded")
    print("PRESENTATION_CHECKS checks=",checks," failures=",failed," operations=",operations," tracks=",tracks," kinds=",kinds.keys()," evidence=",evidence)
    quit(1 if failed else 0)
