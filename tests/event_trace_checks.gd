extends SceneTree
# Fast public presentation boundary checks use real admitted journal packets.
# Renderer witness wiring is separately exercised by the native live scene.
const Journal = preload("res://sdk/journal.gd")
const Reducer = preload("res://sdk/reducer.gd")
const Compiler = preload("res://presentation/compiler.gd")
const Timeline = preload("res://presentation/timeline.gd")
const Trace = preload("res://presentation/event_trace.gd")
const Protocol = preload("res://sdk/protocol.gd")
var checks = 0
var failed = 0
var retained_missing_reference: Dictionary = {}
var retained_context_pair: Array = []
var native_nested_reference: Dictionary = {}
var evidence = {"nodes":0,"logs":0,"supported_tracks":0,"partial_attacks":0,"operations":0,"future_contacts":0,"preserved_nested_logs":0,"deduplicated_nested_logs":0,"conditions":0,"precommit_attack_privacy":0,"hierarchical_links":0,"lethal_chains":0,"jump_reactions":0}

func check(value: bool, label: String) -> void:
    checks += 1
    if not value: failed += 1; print("EVENT_TRACE_FAIL ",label)

func timeline_for(state: Dictionary, group: Dictionary) -> RefCounted:
    var result = Timeline.new()
    result.accept({"kind":"initialization","state":state.duplicate(true),"sequence":-1})
    result.accept({"kind":"operation","groups":[group]})
    return result

func verify(state: Dictionary, group: Dictionary, lineage: Dictionary) -> void:
    var events: Array = group.events
    check(events.size() == lineage.events.size(),"one disclosed event row per admitted node")
    var expected = {}
    var last = -1
    for node in lineage.events: expected["%s:%s" % [group.operation_sequence,node.uuid]] = node
    for event in events:
        evidence.nodes += 1
        check(expected.has(event.id) and event.source_index >= last,"exact event identity and source order")
        last = event.source_index
        var node: Dictionary = expected[event.id]
        if node.fact != null and node.fact.kind == "condition":
            check(event.behavior_id == node.fact.condition.behavior_id and event.actor_uuid == node.fact.target_entity_uuid,"condition uses nested native descriptor and target identity")
            evidence.conditions += 1
    for event in events:
        if event.kind not in ["damage","life"] or float(event._admit_ms) <= 0: continue
        var prior = timeline_for(state,group)
        prior.advance(float(event._admit_ms)*0.5)
        var snapshot = prior.event_trace(2000,event.id)
        check(snapshot.selected.is_empty() and not snapshot.events.any(func(r): return r.id == event.id),"later damage/death metadata stays hidden before contact")
        check(not prior.event_log(2000).entries.any(func(r): return r.event_id == event.id),"later contact log stays hidden")
        evidence.future_contacts += 1
    for track in group.actor_tracks:
        if track.priority != 20 or not track.has("contact_ms") or track.contact_ms <= track.start_ms: continue
        var id = "%s:%s" % [group.operation_sequence,track.source_event_uuid]
        var before_contact = timeline_for(state,group)
        before_contact.advance(lerpf(track.start_ms,track.contact_ms,0.5))
        var snapshot = before_contact.event_trace(2000,id)
        var visible_rows = snapshot.events.filter(func(r): return r.id == id)
        check(visible_rows.size() == 1 and not snapshot.selected.is_empty(),"scheduled attack body has an admitted diagnostic row")
        if visible_rows.is_empty() or snapshot.selected.is_empty(): continue
        for view in [visible_rows[0],snapshot.selected]:
            check(not view.committed and view.status == "playing" and view.reasons.is_empty(),"precommit attack status/reasons do not disclose future result")
            check(view.components.all(func(c): return c.kind == "body" and not c.trace_track_id.is_empty()),"precommit normal and selected rows show only scheduled body components")
        check(snapshot.selected.committed_log == null,"selected attack does not disclose original nested log before commit")
        var displayed_counts = {}
        for row in snapshot.events: displayed_counts[row.status] = int(displayed_counts.get(row.status,0))+1
        check(displayed_counts == snapshot.counts,"aggregate coverage counts use the same public statuses")
        before_contact.advance(group.duration_ms+1)
        check(before_contact.event_trace(2000,id).selected.components.size() >= snapshot.selected.components.size(),"native commit exposes complete required coverage")
        evidence.precommit_attack_privacy += 1
    var fast = timeline_for(state,group)
    check(fast.event_trace().events.is_empty() and fast.event_trace().queued_events == events.size(),"future events expose count only")
    check(fast.event_log().entries.is_empty(),"future log text stays hidden")
    fast.advance(float(group.duration_ms)+1)
    var rows: Array = fast.event_trace(2000).events
    check(rows.all(func(r): return r.status != "presented"),"advancing or skipping animation never proves rendering")
    for row in rows:
        if retained_missing_reference.is_empty() and row.status == "missing": retained_missing_reference = row.duplicate(true)
        check(row.committed and row.completed,"displayed event eventually commits and completes")
        check(not row.has("_log") and not row.has("_start_ms") and not row.has("versions"),"ordinary rows omit private/future payload")
    var public_ids: Array = rows.map(func(r):return r.id)
    for row in rows:
        if row.parent_id.is_empty(): continue
        check(public_ids.find(row.parent_id)<public_ids.find(row.id),"public parent precedes its descendant independent of completion cursor")
        evidence.hierarchical_links += 1
        var parents: Array = rows.filter(func(candidate):return candidate.id==row.parent_id)
        if retained_context_pair.is_empty() and row.status=="missing" and not parents.is_empty() and parents[0].status=="state_only":
            retained_context_pair=[parents[0].duplicate(true),row.duplicate(true)]
    if lineage.events.any(func(n):return n.fact != null and n.fact.get("behavior_id")=="reaction.opportunity_attack") and lineage.events.any(func(n):return n.fact != null and n.fact.get("trajectory")=="direct_arc"):
        var attack = rows.filter(func(r):return r.behavior_id=="reaction.opportunity_attack")[0]
        var ancestors = {}
        for row in rows: ancestors[row.id] = row
        var owner: Dictionary = attack
        var found_motion = false
        while not owner.parent_id.is_empty() and ancestors.has(owner.parent_id):
            owner = ancestors[owner.parent_id]
            if owner.kind in ["step","movement"]: found_motion = true
        check(found_motion,"actual jump opportunity attack stays nested under interrupted motion")
        evidence.jump_reactions += 1
    var logs: Array = fast.event_log(2000).entries
    evidence.logs += logs.size()
    var log_ids: Array = logs.map(func(r):return r.id)
    for row in logs:
        if not row.parent_id.is_empty(): check(log_ids.find(row.parent_id)<log_ids.find(row.id),"native log parent displays before committed child")
    for death in logs.filter(func(r):return r.entry.entry_type=="death"):
        var damage: Array = logs.filter(func(r):return r.id==death.parent_id)
        if damage.is_empty(): continue
        var attack: Array = logs.filter(func(r):return r.id==damage[0].parent_id)
        if attack.is_empty() or attack[0].entry.entry_type!="attack": continue
        check(log_ids.find(attack[0].id)<log_ids.find(damage[0].id) and log_ids.find(damage[0].id)<log_ids.find(death.id),"real lethal logs display attack then damage then death")
        check(attack[0].depth+1==damage[0].depth and damage[0].depth+1==death.depth,"real lethal results are nested subevents, not flat reordered labels")
        var pending = timeline_for(state,group)
        var attack_commit: Array = group.commits.filter(func(c):return c.get("event_uuid")==expected[attack[0].id].uuid)
        if not attack_commit.is_empty() and attack_commit[0].at_ms>0:
            pending.advance(float(attack_commit[0].at_ms)-0.001)
            check(not pending.event_log(2000).entries.any(func(r):return r.id in [attack[0].id,damage[0].id,death.id]),"child summaries wait for logged parent without revealing its future outcome")
        evidence.lethal_chains += 1
    var node_log_count = 0
    for node in lineage.events:
        if node.combat_log != null: node_log_count += 1
    check(logs.size() >= node_log_count,"native node logs all appear at commit")
    var native_logs: Array = []
    for node in lineage.events:
        if node.combat_log != null: native_logs.append(node.combat_log)
    for node in lineage.events:
        if node.combat_log == null: continue
        var id = "%s:%s" % [group.operation_sequence,node.uuid]
        var matching = logs.filter(func(r): return r.event_id == id)
        check(matching.size() == 1 and matching[0].entry.compact == node.combat_log.compact,"native text preserved exactly once")
        check(fast.event_trace(1,id).selected.committed_log==node.combat_log,"selected diagnostic preserves original native log including aggregate indices")
        if native_nested_reference.is_empty() and not node.combat_log.get("sub_entries",[]).is_empty():
            native_nested_reference=node.combat_log.duplicate(true)
        for child in node.combat_log.get("sub_entries",[]):
            var independently_logged: bool=child in native_logs
            if child.data.get("kind")=="step_movement":
                for native in native_logs:
                    if native.data.get("kind")!="step_movement": continue
                    var projected: Dictionary=child.duplicate(true)
                    projected.data.path_index=native.data.path_index
                    if projected==native: independently_logged=true; break
            if independently_logged:
                check(child not in matching[0].entry.sub_entries,"already-disclosed child log is not printed twice despite aggregate step numbering")
                evidence.deduplicated_nested_logs += 1
            else:
                check(child in matching[0].entry.sub_entries,"native nested log without its own node is preserved")
                evidence.preserved_nested_logs += 1
    var revision: int = fast.trace_revision
    fast.record_presented([{"trace_track_id":"wrong-occurrence","visible":true,"display_ms":0}])
    check(fast.trace_revision == revision,"unknown occurrence cannot claim rendering")
    if not rows.is_empty():
        var selected: Dictionary = fast.event_trace(1,rows[0].id).selected
        check(selected.has("versions"),"selected event retains admitted version references")
        selected.reasons.append("mutated caller copy")
        check("mutated caller copy" not in fast.event_trace(1,rows[0].id).selected.reasons,"export ownership is detached")
    # A real body track, sampled at its compiled time, can have a witness.
    # This tests evidence semantics, not that a native frame was displayed.
    for track in group.actor_tracks:
        if track.priority < 10: continue
        var id = "%s:%s" % [group.operation_sequence,track.source_event_uuid]
        var described: Array = events.filter(func(r): return r.id == id)
        if described.is_empty() or described[0].components.is_empty(): continue
        var played = timeline_for(state,group)
        var at: float = track.start_ms+track.duration_ms*0.5
        played.advance(at)
        var before: int = played.trace_revision
        played.record_presented([{"trace_track_id":track.trace_track_id,"visible":true,"display_ms":at}])
        check(played.trace_revision > before,"first exact witness updates diagnostic status")
        played.advance(float(group.duration_ms)+1)
        var event: Dictionary = played.event_trace(1,id).selected
        var component: Array = event.components.filter(func(c): return c.trace_track_id == track.trace_track_id)
        check(not component.is_empty() and component[0].sample_count == 1,"exact track sample retained")
        if event.components.size() == 1:
            check(event.status == "presented","completed single body event becomes green only with witness")
            evidence.supported_tracks += 1
        elif event.kind == "attack":
            check(event.status == "missing","body witness cannot hide missing projectile or effects")
            evidence.partial_attacks += 1
        var hidden = timeline_for(state,group)
        hidden.advance(at)
        hidden.record_render_issue(track.trace_track_id,"offscreen")
        hidden.advance(float(group.duration_ms)+1)
        if event.components.size() == 1:
            check(hidden.event_trace(1,id).selected.status == "not_visible","offscreen is neutral rather than missing art")
        # Post-draw evidence may arrive after a later advance completed a group.
        fast.record_presented([{"trace_track_id":track.trace_track_id,"visible":true,"display_ms":at}])
        check(fast.event_trace(1,id).selected.components.any(func(c): return c.trace_track_id == track.trace_track_id and c.sample_count == 1),"late exact frame witness survives group completion")
        break

func _initialize() -> void:
    var directory = "res://.runtime/player-runs/20261011T225557.695498Z/journal"
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--journal="): directory = arg.trim_prefix("--journal=")
    var journal = Journal.new()
    var opened = journal.open(directory,true,false)
    check(opened.ok,"historical recorded protocol opens")
    if not opened.ok: print(opened); quit(1); return
    var protocol = journal.protocol
    var decoded = protocol.decode("InitializationResponse",FileAccess.get_file_as_bytes(directory.path_join("0000000000000000.json")))
    check(decoded.ok,"real initialization admitted")
    if not decoded.ok: quit(1); return
    var packet: Dictionary = protocol.normalize("InitializationResponse",decoded.value)
    var state: Dictionary = Reducer.reduce_initialization(packet.initialization,packet.content_additions).value
    var initial_rows = Trace.initialization(packet.initialization)
    var initialized = Timeline.new()
    initialized.accept({"kind":"initialization","state":state.duplicate(true),"sequence":0,"events":initial_rows})
    check(initialized.event_trace().events.size() == packet.initialization.nodes.size(),"initial snapshot events enumerated")
    check(initialized.event_trace().events.all(func(r): return r.status == "state_only" and r.committed),"initial snapshot never claims animation")
    var init_revision: int = initialized.trace_revision
    initialized.accept({"kind":"initialization","state":state.duplicate(true),"sequence":0,"events":initial_rows})
    check(initialized.trace_revision == init_revision,"repeated initialization diagnostics deduplicate")
    var previous_journal = Journal.new()
    var previous_open = previous_journal.open("res://.runtime/gallery-route/journal",true,false)
    check(previous_open.ok,"pre-container-loot recording opens with its frozen identity")
    if previous_open.ok:
        var previous_raw = FileAccess.get_file_as_bytes("res://.runtime/gallery-route/journal/0000000000000000.json")
        var previous_packet = previous_journal.protocol.decode("InitializationResponse",previous_raw)
        check(previous_packet.ok,"prior source-lighting schema remains decodable without relabeling bytes")
        if previous_packet.ok: check(not Protocol.new().check_identity(previous_packet.value.protocol).ok,"current live protocol remains strict against previous schema")
    var cache = {}
    var first_group: Dictionary = {}
    for seq in range(1,61):
        var filename = "%016d.json" % seq
        var result = protocol.decode("PlayerOperation",FileAccess.get_file_as_bytes(directory.path_join(filename)))
        check(result.ok,"real operation admitted "+filename)
        if not result.ok: break
        var operation: Dictionary = protocol.normalize("PlayerOperation",result.value)
        var original = state.duplicate(true)
        var compiled = Compiler.compile(state,operation,cache)
        check(compiled.ok,"real operation compiled "+filename)
        if not compiled.ok: break
        var displayed = state.duplicate(true)
        for group in compiled.value.groups:
            var lineage = operation.lineages.filter(func(l): return l.lineage_uuid == group.id)
            if not lineage.is_empty(): verify(displayed,group,lineage[0])
            if first_group.is_empty() and not group.get("events",[]).is_empty(): first_group = group
            for commit in group.commits: Compiler.apply_delta(displayed,commit.delta)
        check(displayed == compiled.value.final_state and state == original,"diagnostics preserve canonical result and input ownership")
        state = compiled.value.final_state
        evidence.operations += 1
    check(evidence.supported_tracks > 0 and evidence.partial_attacks > 0 and evidence.future_contacts > 0,"real movement and partial attack covered")
    var stalled = timeline_for(state,first_group)
    stalled.record_preparation_issue("not-the-front-group","missing media")
    check(stalled.event_trace().events.is_empty(),"future media issue cannot reveal later groups")
    stalled.record_preparation_issue(first_group.id,"required_media_missing")
    var preparation: Dictionary = stalled.event_trace().events[0]
    check(preparation.status == "missing" and preparation.actor_uuid == null and preparation.event_uuid == "","stalled first media boundary diagnosable without future identities")
    stalled.advance(0)
    check(stalled.event_trace(200,preparation.id).selected.reasons == ["preparation_recovered"],"prepared boundary resolves explicitly")
    # Retention pressure uses copies of an actual disclosed metadata row, not
    # invented gameplay input or alternate animation behavior.
    var retained = Trace.create()
    var source: Dictionary = initial_rows[0].duplicate(true)
    for index in range(Trace.LIMIT+3):
        var row: Dictionary = source.duplicate(true)
        row.id = "retention:%s" % index
        Trace.activate(retained,[row],0)
    var snapshot = Trace.snapshot(retained,200,"",0)
    check(snapshot.retained_events == Trace.LIMIT and snapshot.evicted_events == 3 and snapshot.events.size() == 200,"trace is explicitly bounded with eviction count")
    var filtered = Timeline.new()
    check(not retained_missing_reference.is_empty(),"real missing event available for filtered retention regression")
    Trace.activate(filtered.trace,[retained_missing_reference],0)
    for index in range(205):
        var neutral: Dictionary = source.duplicate(true)
        neutral.id = "later-neutral:%s" % index
        neutral.sequence = int(retained_missing_reference.sequence)+index+1
        neutral.committed = true
        Trace.activate(filtered.trace,[neutral],0)
    var window = filtered.event_trace(200,retained_missing_reference.id)
    var missing_window = filtered.event_trace(200,retained_missing_reference.id,"missing")
    check(not window.events.any(func(r): return r.id == retained_missing_reference.id),"ordinary recent window excludes old retained event")
    check(missing_window.events.size() == 1 and missing_window.events[0].id == retained_missing_reference.id,"missing filter selects before recent-row limit")
    check(missing_window.counts == window.counts and missing_window.counts.missing == 1 and missing_window.counts.state_only == 205,"filtered view counts all retained public rows")
    check(window.selected.id == retained_missing_reference.id and missing_window.selected.id == retained_missing_reference.id,"selected details remain available outside recent window")
    var neutral_window = filtered.event_trace(1,retained_missing_reference.id,"state_only")
    check(neutral_window.events.size() == 1 and neutral_window.selected.id == retained_missing_reference.id,"selected details remain independent of active filter")
    check(not retained_context_pair.is_empty(),"actual neutral parent and missing descendant available")
    if not retained_context_pair.is_empty():
        var contextual = Timeline.new()
        Trace.activate(contextual.trace,retained_context_pair,0)
        for index in range(205):
            var later: Dictionary=source.duplicate(true)
            later.id="later-context:%s" % index
            later.sequence=int(retained_context_pair[1].sequence)+index+1
            later.committed=true
            Trace.activate(contextual.trace,[later],0)
        check(not contextual.event_trace(200).events.any(func(r):return r.id==retained_context_pair[0].id),"old parent can leave ordinary recent window")
        var context_view: Dictionary=contextual.event_trace(200,"","missing")
        check(context_view.events.size()==2 and context_view.events[0].id==retained_context_pair[0].id and context_view.events[0].context,"missing filter restores already admitted parent as neutral context")
        check(context_view.events[1].parent_id==context_view.events[0].id and context_view.counts.missing==1,"context preserves hierarchy without inflating missing count")
    var native_entry: Dictionary = {}
    for event in initial_rows:
        if event.get("_log") != null: native_entry = event._log; break
    if native_entry.is_empty():
        for event in first_group.events:
            if event.get("_log") != null: native_entry = event._log; break
    check(not native_entry.is_empty(),"actual source log available for append boundary")
    var append_packet = {"cursor":{"sequence":9},"lineages":[{"events":[{"combat_log":native_entry}]}],
        "combat_log_appends":[{"generation":1,"encounter_log_index":7,"operation_end_cursor":12,"entry":native_entry}]}
    check(Trace.operation_logs(append_packet).is_empty(),"node-attached and appended copy of same native log deduplicates")
    append_packet.lineages = []
    var appends = Trace.operation_logs(append_packet)
    check(appends.size() == 1 and appends[0].entry == native_entry,"standalone native log remains intact")
    check(not native_nested_reference.is_empty(),"actual source contains nested native entries")
    var nested_packet={"cursor":{"sequence":10},"lineages":[],"combat_log_appends":[{"generation":1,"encounter_log_index":8,"operation_end_cursor":13,"entry":native_nested_reference}]}
    var nested_trace=Trace.create()
    Trace.append_logs(nested_trace,Trace.operation_logs(nested_packet))
    check(Trace.logs(nested_trace,200).entries[0].entry==native_nested_reference,"unrepresented nested entries retain original native data/text exactly")
    # Finite log-composition boundary: one independently logged occurrence
    # can remove only one embedded copy, even when another repeats its route.
    var source_steps: Array=native_nested_reference.sub_entries.filter(func(child):return child.data.get("kind")=="step_movement")
    check(not source_steps.is_empty(),"actual nested movement source available for multiplicity boundary")
    if not source_steps.is_empty():
        var first_step: Dictionary=source_steps[0].duplicate(true)
        first_step.data.path_index=0
        var repeated_child: Dictionary=first_step.duplicate(true)
        repeated_child.data.path_index=2
        var aggregate: Dictionary=native_nested_reference.duplicate(true)
        aggregate.sub_entries=[first_step,repeated_child]
        var one_native={"cursor":{"sequence":11},"lineages":[{"events":[{"combat_log":first_step}]}],
            "combat_log_appends":[{"generation":1,"encounter_log_index":9,"operation_end_cursor":14,"entry":aggregate}]}
        var deduplicated: Array=Trace.operation_logs(one_native)
        check(deduplicated.size()==1 and deduplicated[0].entry.sub_entries==[repeated_child],"one native step consumes only one aggregate duplicate; repeated nested occurrence survives")
    # These two real Gallery operations repeat the same route steps. Their
    # native IDs remain separate even when aggregate duplicate text is removed.
    var repeated_step_rows={}
    for seq in [59,84]:
        var raw=FileAccess.get_file_as_bytes("res://.runtime/gallery-route/journal/%016d.json" % seq)
        var decoded_repeat=previous_journal.protocol.decode("PlayerOperation",raw)
        check(decoded_repeat.ok,"actual repeated route operation admitted")
        if not decoded_repeat.ok: continue
        var repeated_packet: Dictionary=previous_journal.protocol.normalize("PlayerOperation",decoded_repeat.value)
        for lineage in repeated_packet.lineages:
            for node in lineage.events:
                if node.combat_log==null or node.combat_log.data.get("kind")!="step_movement": continue
                var log: Dictionary=node.combat_log
                var key: String=JSON.stringify([log.source_uuid,log.data.from_position,log.data.to_position])
                if not repeated_step_rows.has(key): repeated_step_rows[key]=[]
                repeated_step_rows[key].append({"id":"%s:%s" % [seq,node.uuid],"sequence":seq,"source_index":0,"entry":log})
    var repeated_count=0
    for occurrences in repeated_step_rows.values():
        if occurrences.size()<2: continue
        var ids: Array=occurrences.map(func(r):return r.id)
        var unique={}
        for id in ids: unique[id]=true
        check(ids.size()==unique.size(),"repeated real moves have separate occurrence identities")
        var repeated_trace=Trace.create()
        Trace.append_logs(repeated_trace,occurrences)
        var repeated_logs: Array=Trace.logs(repeated_trace,200).entries
        check(repeated_logs.size()==occurrences.size() and repeated_logs.all(func(r):return r.id in ids),"nested dedup never merges independently logged repeated move occurrences")
        repeated_count+=1
    check(repeated_count>0,"actual Gallery recording includes repeated moves across operations")
    var log_trace = Trace.create()
    Trace.append_logs(log_trace,appends)
    Trace.append_logs(log_trace,appends)
    check(Trace.logs(log_trace,200).entries.size() == 1,"repeated stable append identity is idempotent")
    for index in range(Trace.LIMIT+2):
        var append: Dictionary = appends[0].duplicate(true)
        append.id = "retention-log:%s" % index
        Trace.append_logs(log_trace,[append])
    check(Trace.logs(log_trace,200).entries.size() == 200 and log_trace.logs.size() == Trace.LIMIT and log_trace.evicted_entries == 3,"native log retention is bounded with explicit count")
    check(evidence.lethal_chains>0 and evidence.jump_reactions>0,"actual lethal and jump opportunity-attack hierarchies exercised")
    # Parent references outside retention are promoted without inventing data.
    var absent_parent = Trace.create()
    var orphan: Dictionary = retained_missing_reference.duplicate(true)
    orphan.parent_id = "not-disclosed-or-evicted"
    Trace.activate(absent_parent,[orphan],0)
    check(Trace.snapshot(absent_parent,200,"",0).events[0].parent_id=="","absent or evicted event parent cannot hide an admitted child")
    var orphan_log: Dictionary = appends[0].duplicate(true)
    orphan_log._log_parent_id = "not-disclosed-or-evicted"
    Trace.append_logs(absent_parent,[orphan_log])
    check(Trace.logs(absent_parent,200).entries[0].parent_id=="","absent or evicted log parent cannot block retained child forever")
    var report = {"checks":checks,"failures":failed,"evidence":evidence}
    var file = FileAccess.open("res://generated/event_trace_checks.json",FileAccess.WRITE)
    file.store_string(JSON.stringify(report,"  ")+"\n")
    print("EVENT_TRACE_CHECKS ",JSON.stringify(report))
    quit(1 if failed else 0)
