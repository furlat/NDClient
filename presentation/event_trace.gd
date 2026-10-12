extends RefCounted
## Passive, bounded diagnostics. No canonical snapshots or packets are retained.
const Authoring = preload("res://presentation/authoring.gd")
const LIMIT = 2000

static func create() -> Dictionary:
    return {"rows":{},"order":[],"tracks":{},"logs":[],"log_ids":{},"revision":0,
        "evicted_events":0,"evicted_entries":0}

static func _component(kind: String, reason: String, source: String = "") -> Dictionary:
    return {"id":kind,"kind":kind,"trace_track_id":"","actor_uuid":"","rig":"","clip":"",
        "start_ms":0.0,"end_ms":0.0,"status":"missing","reason":reason,"source":source,
        "sample_count":0,"first_sample_ms":null,"last_sample_ms":null}

static func _base(node: Dictionary, sequence: int, group: String, versions: Array) -> Dictionary:
    var fact: Dictionary = node.fact if node.get("fact") != null else {}
    var history: Array = []
    var index = -1
    for version in versions:
        if version.lineage_uuid == node.lineage_uuid: history.append(version.duplicate())
        if version.event_uuid == node.uuid: index = int(version.source_index)
    return {"id":"%s:%s" % [sequence,node.uuid],"sequence":sequence,"group_id":group,
        "event_uuid":node.uuid,"lineage_uuid":node.lineage_uuid,"source_index":index,
        "parent_event":node.get("parent_event"),"parent_lineage":node.get("parent_lineage"),
        "kind":fact.get("kind","undisclosed"),"phase":node.get("phase",""),
        "name":fact.get("name",fact.get("behavior_id",fact.get("kind","undisclosed"))),
        "behavior_id":fact.get("behavior_id"),
        "actor_uuid":fact.get("source_entity_uuid",fact.get("entity_uuid")),"target_uuid":fact.get("target_entity_uuid"),
        "status":"state_only","reasons":[],"components":[],"committed":false,"completed":false,
        "committed_log":null,"versions":history,"parent_id":"",
        "first_source_index":int(history[0].source_index) if not history.is_empty() else index,
        "_log":node.get("combat_log"),"_end_ms":0.0}

static func initialization(initial: Dictionary) -> Array:
    var result: Array = []
    var native_logs = _node_logs(initial.nodes)
    for node in initial.nodes:
        var row = _base(node,0,"initialization",initial.version_rows)
        row._display_log = _unique_children(row._log,native_logs) if row._log != null else null
        row.reasons = ["initial_snapshot_no_animation_claim"]
        row.completed = true
        result.append(row)
    result.sort_custom(func(a,b): return a.source_index < b.source_index)
    _bind_parents(result)
    return result

static func _recipe_missing(row: Dictionary, recipe: Dictionary, source: String) -> void:
    if recipe.is_empty():
        row.reasons = ["unclassified_no_animation_claim"]; return
    if recipe.get("disposition") == "state_only": return
    if not recipe.get("media",[]).is_empty() or not recipe.get("actor",{}).get("media",[]).is_empty():
        row.components.append(_component("media","authored_media_not_implemented",source+".media"))
    if recipe.get("actor",{}).get("enabled",false):
        var component = _component("body","authored_body_not_implemented",source+".actor")
        component.clip = recipe.actor.get("clip","")
        row.components.append(component)
    if recipe.get("actionFeedback") != null:
        row.components.append(_component("feedback","authored_feedback_not_implemented",source+".actionFeedback"))

static func _requirements(row: Dictionary, node: Dictionary, actor: Dictionary, cache: Dictionary, attack_recipe: Dictionary) -> void:
    var fact: Dictionary = node.fact if node.get("fact") != null else {}
    if node.get("canceled",false): row.components = []; row.reasons = ["canceled"]; return
    if fact.is_empty(): row.reasons = ["fact_not_disclosed"]; return
    match row.kind:
        "movement": row.reasons = ["movement_container_visuals_belong_to_steps"]
        "step":
            if not fact.get("committed",false): row.components = []; row.reasons = ["uncommitted_step"]; return
            if row.components.is_empty(): row.components.append(_component("body","missing_authored_movement", "catalog/movement_context.json"))
        "attack":
            var recipe = attack_recipe.duplicate()
            if recipe.is_empty():
                row.components.append(_component("body","missing_authored_attack_recipe","catalog/attack_recipes.json"))
            else:
                for variant in recipe.get("variants",[]):
                    if variant.id == recipe.get("selected_variant",""):
                        for field in ["projectile","attackVfx","attackFeedback","weaponTrail"]:
                            if variant.has(field): recipe[field] = variant[field]
                var source = "catalog/attack_recipes.json:"+str(fact.behavior_id)
                if recipe.get("actor",{}).get("enabled",false) and row.components.is_empty():
                    row.components.append(_component("body","missing_authored_clip",source+".actor"))
                if recipe.get("projectile") != null:
                    row.components.append(_component("projectile","authored_projectile_not_implemented",source+".projectile"))
                var outcome: String = {"Hit":"hit","Miss":"miss","Crit":"critical","Crit Miss":"critical_miss"}.get(fact.get("attack_outcome"),"")
                var effect: String = "onCrit" if outcome == "critical" else ("onHit" if outcome == "hit" else "onMiss")
                if not recipe.get("attackVfx",{}).get(effect,{}).is_empty():
                    row.components.append(_component("attack_vfx","authored_attack_vfx_not_implemented",source+".attackVfx."+effect))
                if recipe.get("attackFeedback",{}) != null and recipe.get("attackFeedback",{}).get(outcome) != null:
                    row.components.append(_component("feedback","authored_attack_feedback_not_implemented",source+".attackFeedback."+outcome))
                var trail: Dictionary = recipe.get("weaponTrail",{}) if recipe.get("weaponTrail") != null else {}
                if fact.behavior_id in trail.get("behaviorIds",[]) or outcome in trail.get("outcomes",[]):
                    row.components.append(_component("weapon_trail","authored_weapon_trail_not_implemented",source+".weaponTrail"))
        "damage":
            if fact.get("stage") != "applied" or fact.get("applied_damage",0) <= 0:
                row.reasons = ["no_applied_damage_visual"]; return
            if row.components.is_empty(): row.components.append(_component("body","missing_authored_clip","catalog/damage_context.json.bodyClip"))
            var context = Authoring.load_data("catalog/damage_context.json",cache)
            for field in ["flashEnabled","numberEnabled"]:
                if context.get(field,false): row.components.append(_component(field,"authored_damage_feedback_not_implemented","catalog/damage_context.json."+field))
        "life":
            var role = "death" if fact.new_state == "dead" else "life"
            var body = Authoring.body(role,actor,fact,cache)
            if body.get("actor",{}).get("enabled",false) and row.components.is_empty():
                row.components.append(_component("body","missing_authored_clip","catalog/"+role+"_context.json"))
            if role == "death":
                if not Authoring.load_data("catalog/death_context.json",cache).get("silhouetteDust",{}).is_empty():
                    row.components.append(_component("death_dust","authored_death_dust_not_implemented","catalog/death_context.json.silhouetteDust"))
            else:
                var key: String = "revived" if fact.new_state == "alive" else fact.new_state
                if Authoring.load_data("catalog/life_state_context.json",cache).get(key,{}).get("enabled",false):
                    row.components.append(_component("feedback","authored_life_feedback_not_implemented","catalog/life_state_context.json."+key))
        "equipment":
            var context = Authoring.load_data("catalog/equipment_context.json",cache)
            if context.get("bodyEnabled",false): row.components.append(_component("body","authored_equipment_body_not_implemented","catalog/equipment_context.json"))
        "heal":
            if fact.get("actual_healing",0) > 0 and Authoring.load_data("catalog/healing_context.json",cache).get("feedbackEnabled",false):
                row.components.append(_component("feedback","authored_healing_feedback_not_implemented","catalog/healing_context.json"))
        "forced_movement":
            if fact.get("start_position") != fact.get("end_position"):
                row.components.append(_component("motion","authored_forced_movement_not_implemented","catalog/forced_movement_context.json"))
        "death_save":
            row.components.append(_component("feedback","authored_death_save_feedback_not_implemented","catalog/death_save_context.json"))
        "condition":
            var key: String = str(fact.condition.get("behavior_id",""))
            row.behavior_id = key
            row.name = fact.condition.get("name",key)
            var recipe: Dictionary = Authoring.load_data("catalog/condition_recipes.json",cache).get(key,{})
            var phase = "removal" if fact.event_type == "condition_removal" else "application"
            var change: Dictionary = recipe.get(phase,{})
            var persistent: Dictionary = recipe.get("persistent",{}) if phase == "application" else {}
            if change.get("feedbackEnabled",false) or not change.get("effects",[]).is_empty() or not persistent.get("layers",[]).is_empty() or persistent.has("bodyColor") or persistent.has("bodyRamp"):
                row.components.append(_component("condition","authored_condition_presentation_not_implemented","catalog/condition_recipes.json:"+key+"."+phase))
        "action", "shove":
            var file = "catalog/shove_recipes.json" if row.kind == "shove" else "catalog/body_action_recipes.json"
            var recipe_id: String = str(fact.get("behavior_id",""))
            if row.kind == "action":
                recipe_id = Authoring.load_data("catalog/body_action_bindings.json",cache).get(recipe_id,{}).get("source_recipe",recipe_id)
            _recipe_missing(row,Authoring.load_data(file,cache).get(recipe_id,{}),file+":"+recipe_id)
        "spell": row.components.append(_component("spell","spell_presentation_not_implemented"))
    if row.components.is_empty() and row.reasons.is_empty(): row.reasons = ["state_only_no_animation_claim"]
    # A visual actor was never disclosed; this is not evidence of missing art.
    if row.actor_uuid != null and actor.get("last_visual_position") == null and not row.components.is_empty():
        row.components = []; row.status = "not_visible"; row.reasons = ["actor_not_visually_disclosed"]

static func compile_rows(lineage: Dictionary, group: Dictionary, graph: Dictionary, cache: Dictionary) -> Array:
    var result: Array = []
    var commits = {}
    var native_logs = _node_logs(lineage.events)
    for commit_row in group.commits:
        if commit_row.has("event_uuid"): commits[commit_row.event_uuid] = float(commit_row.at_ms)
    for node in lineage.events:
        var row = _base(node,int(group.operation_sequence),group.id,lineage.version_rows)
        row._display_log = _unique_children(row._log,native_logs) if row._log != null else null
        row._end_ms = graph.ends.get(node.uuid,0.0)
        row._group_duration_ms = group.duration_ms
        row._admit_ms = commits.get(node.uuid,group.duration_ms)
        if row.kind in ["damage","condition","heal","forced_movement"]: row.actor_uuid = row.target_uuid
        for track in group.actor_tracks:
            if track.source_event_uuid != node.uuid or int(track.priority) < 10: continue
            row._admit_ms = minf(row._admit_ms,float(track.start_ms))
            var component = _component("body","", "catalog/rigs.json:"+track.rig+".clips."+track.clip)
            component.merge({"id":track.trace_track_id,"trace_track_id":track.trace_track_id,"actor_uuid":track.actor_uuid,
                "rig":track.rig,"clip":track.clip,"start_ms":track.start_ms,"end_ms":track.start_ms+track.duration_ms,
                "status":"playing","holding_pose":track.get("holding_pose",false)},true)
            row.components.append(component)
        var actor: Dictionary = graph.actor_inputs.get(node.uuid,{}).get(row.actor_uuid,{})
        _requirements(row,node,actor,cache,graph.recipes.get(node.uuid,{}))
        if row.components.is_empty(): row._admit_ms = commits.get(node.uuid,group.duration_ms)
        result.append(row)
    result.sort_custom(func(a,b): return a.source_index < b.source_index)
    _bind_parents(result)
    return result

static func _refresh(row: Dictionary) -> bool:
    var previous: Array = [row.status,row.reasons.duplicate()]
    if row.components.is_empty(): return false
    var missing: Array = []
    var hidden: Array = []
    var pending = false
    for component in row.components:
        if component.status == "missing": missing.append(component.reason)
        elif component.status == "not_visible": hidden.append(component.reason)
        elif component.status != "presented": pending = true
    row.reasons = missing if not missing.is_empty() else hidden
    if not missing.is_empty(): row.status = "missing"
    elif pending or not row.completed: row.status = "playing"
    elif not hidden.is_empty(): row.status = "not_visible"
    else: row.status = "presented"
    return previous != [row.status,row.reasons]

static func _append_log(trace: Dictionary, id: String, event: Dictionary, entry: Dictionary, flatten: bool) -> void:
    if trace.log_ids.has(id): return
    var copied = entry.duplicate(true)
    if flatten: copied.sub_entries = []
    trace.logs.append({"id":id,"event_id":event.get("id",""),"sequence":event.sequence,
        "source_index":event.source_index,"first_source_index":event.get("first_source_index",event.source_index),
        "parent_id":event.get("_log_parent_id",""),"entry":copied})
    trace.log_ids[id] = true
    while trace.logs.size() > LIMIT:
        trace.log_ids.erase(trace.logs.pop_front().id)
        trace.evicted_entries += 1
    trace.revision += 1

static func activate(trace: Dictionary, rows: Array, start_ms: float) -> void:
    for source in rows:
        if trace.rows.has(source.id): continue
        var row: Dictionary = source.duplicate(true)
        row._start_ms = start_ms
        row._admitted = float(row.get("_admit_ms",0.0)) <= 0.0
        _refresh(row)
        trace.rows[row.id] = row
        trace.order.append(row.id)
        for component in row.components:
            if not component.trace_track_id.is_empty(): trace.tracks[component.trace_track_id] = {"row":row,"component":component}
        while trace.order.size() > LIMIT:
            var expired: Dictionary = trace.rows[trace.order.pop_front()]
            for component in expired.components: trace.tracks.erase(component.trace_track_id)
            trace.rows.erase(expired.id)
            trace.evicted_events += 1
        trace.revision += 1

static func commit(trace: Dictionary, sequence: int, event_uuid: String) -> void:
    var row: Dictionary = trace.rows.get("%s:%s" % [sequence,event_uuid],{})
    if row.is_empty() or row.committed: return
    row.committed = true
    row._admitted = true
    if row._log != null:
        row.committed_log = row._log
        _append_log(trace,row.id,row,row.get("_display_log",row._log),false)
    row.erase("_log")
    row.erase("_display_log")
    trace.revision += 1

static func append_logs(trace: Dictionary, logs: Array) -> void:
    for record in logs:
        _append_log(trace,record.id,record,record.entry,record.get("flatten",false))

static func tick(trace: Dictionary, rows: Array, local_ms: float) -> void:
    for source in rows:
        var row: Dictionary = trace.rows.get(source.id,{})
        if row.is_empty(): continue
        if not row._admitted and local_ms+0.000001 >= float(row.get("_admit_ms",0.0)):
            row._admitted = true
            trace.revision += 1
        if row.completed or local_ms+0.000001 < float(row._end_ms): continue
        row.completed = true
        for component in row.components:
            if component.status == "playing":
                component.status = "missing"; component.reason = "no_rendered_sample"
        _refresh(row)
        trace.revision += 1

static func record(trace: Dictionary, evidence: Array) -> void:
    for sample in evidence:
        var found: Dictionary = trace.tracks.get(sample.get("trace_track_id",""),{})
        if found.is_empty(): continue
        var row: Dictionary = found.row
        if not row._admitted: continue
        var component: Dictionary = found.component
        var previous: Array = [component.status,component.reason]
        if sample.get("visible",false):
            var at = float(sample.get("display_ms",-1.0))
            var end = float(row._group_duration_ms) if component.get("holding_pose",false) else float(component.end_ms)
            if at < row._start_ms+component.start_ms or at > row._start_ms+end: continue
            if component.last_sample_ms != null and at <= float(component.last_sample_ms): continue
            component.status = "presented"; component.reason = ""
            component.sample_count += 1
            if component.first_sample_ms == null: component.first_sample_ms = at
            component.last_sample_ms = at
        elif component.sample_count == 0:
            var reason: String = sample.get("reason","renderer_missing")
            component.status = "not_visible" if reason in ["offscreen","not_visible"] else "missing"
            component.reason = reason
        var changed = _refresh(row)
        # Sampling statistics remain available on demand, without rebuilding a
        # visible UI every frame once the coverage status is unchanged.
        if changed or previous != [component.status,component.reason]: trace.revision += 1

static func snapshot(trace: Dictionary, limit: int, selected: String, queued: int, status_filter: String = "") -> Dictionary:
    var admitted = {}
    var counts = {}
    for id in trace.order:
        var row: Dictionary = trace.rows[id]
        if not row._admitted:
            queued += 1
            continue
        admitted[id] = row
        var public_status: String = _coverage(row).status
        counts[public_status] = int(counts.get(public_status,0))+1
    var ordered = _hierarchy(admitted,trace.rows)
    var events: Array = []
    var selection: Dictionary = {}
    for placement in ordered:
        if placement.row.id == selected:
            selection = _public(placement.row,true)
            selection.parent_id = placement.parent_id
            selection.depth = placement.depth
            break
    for placement in _window(ordered,limit,status_filter):
        var row = _public(placement.row,false)
        row.parent_id = placement.parent_id
        row.depth = placement.depth
        row.context = not status_filter.is_empty() and row.status != status_filter
        events.append(row)
    return {"revision":trace.revision,"events":events,"selected":selection,
        "counts":counts,"queued_events":queued,"retained_events":trace.order.size(),"evicted_events":trace.evicted_events}

static func _public(row: Dictionary, detailed: bool) -> Dictionary:
    var result = {}
    for key in row:
        if str(key).begins_with("_"): continue
        if not detailed and key in ["versions","committed_log"]: continue
        result[key] = row[key]
    var coverage = _coverage(row)
    for key in ["status","reasons","components","completed"]: result[key] = coverage[key]
    return result.duplicate(true)

static func _coverage(row: Dictionary) -> Dictionary:
    if row.committed or row.components.is_empty(): return row
    # A chosen attack recipe can encode a future hit/miss/critical result.
    # Before the native commit, expose only body tracks already scheduled for
    # presentation; even aggregate red/green counts must use this same view.
    var visible = {"components":row.components.filter(func(c): return c.kind == "body" and not c.trace_track_id.is_empty()),
        "status":"playing","reasons":[],"completed":false}
    _refresh(visible)
    return visible

static func logs(trace: Dictionary, limit: int) -> Dictionary:
    var admitted = {}
    var retained = {}
    for row in trace.logs: retained[row.id] = row
    for row in trace.logs:
        var parent: String = row.parent_id
        var seen = {}
        var ready = true
        # Native summaries can contain future results. Like the original
        # Pygame log, wait for known logged ancestors instead of showing their
        # children first or publishing a parent's summary prematurely.
        while not parent.is_empty() and not seen.has(parent):
            seen[parent] = true
            var ancestor: Dictionary = trace.rows.get(parent,{})
            if not ancestor.is_empty() and not ancestor.committed:
                ready = false; break
            parent = retained.get(parent,{}).get("parent_id","")
        if ready: admitted[row.id] = row
    var entries: Array = []
    for placement in _window(_hierarchy(admitted,retained),limit,""):
        var row: Dictionary = placement.row.duplicate(true)
        row.parent_id = placement.parent_id
        row.depth = placement.depth
        entries.append(row)
    return {"revision":trace.revision,"entries":entries,"evicted_entries":trace.evicted_entries}

static func _bind_parents(rows: Array) -> void:
    var by_lineage = {}
    var by_event = {}
    for row in rows:
        by_lineage[row.lineage_uuid] = row
        by_event[row.event_uuid] = row
        for version in row.versions: by_event[version.event_uuid] = row
    for row in rows:
        var parent: Dictionary = by_lineage.get(row.parent_lineage,by_event.get(row.parent_event,{}))
        row.parent_id = parent.get("id","")
        var seen = {row.id:true}
        while not parent.is_empty() and not seen.has(parent.id):
            seen[parent.id] = true
            if parent.get("_log") != null:
                row._log_parent_id = parent.id
                break
            parent = by_lineage.get(parent.parent_lineage,by_event.get(parent.parent_event,{}))

static func _hierarchy(admitted: Dictionary, retained: Dictionary) -> Array:
    var children = {}
    for row in admitted.values():
        var parent: String = row.get("parent_id","")
        var seen = {row.id:true}
        while not parent.is_empty() and not admitted.has(parent):
            if seen.has(parent): parent = ""; break
            seen[parent] = true
            parent = retained.get(parent,{}).get("parent_id","")
        if parent == row.id: parent = ""
        if not children.has(parent): children[parent] = []
        children[parent].append(row)
    for siblings in children.values():
        siblings.sort_custom(func(a,b):
            if a.sequence != b.sequence: return a.sequence < b.sequence
            var ai = a.get("first_source_index",a.source_index)
            var bi = b.get("first_source_index",b.source_index)
            return ai < bi if ai != bi else a.id < b.id)
    var result: Array = []
    var pending: Array = []
    var roots: Array = children.get("",[])
    for i in range(roots.size()-1,-1,-1): pending.append({"row":roots[i],"parent_id":"","depth":0})
    var visited = {}
    while not pending.is_empty():
        var placement: Dictionary = pending.pop_back()
        if visited.has(placement.row.id): continue
        visited[placement.row.id] = true
        result.append(placement)
        var nested: Array = children.get(placement.row.id,[])
        for i in range(nested.size()-1,-1,-1):
            pending.append({"row":nested[i],"parent_id":placement.row.id,"depth":placement.depth+1})
    return result

static func _window(ordered: Array, limit: int, status_filter: String) -> Array:
    var capacity = clampi(limit,0,LIMIT)
    var by_id = {}
    for placement in ordered: by_id[placement.row.id] = placement
    var included = {}
    for index in range(ordered.size()-1,-1,-1):
        var placement: Dictionary = ordered[index]
        if not status_filter.is_empty() and _coverage(placement.row).status != status_filter: continue
        var chain: Array = []
        while not included.has(placement.row.id):
            chain.append(placement.row.id)
            if not by_id.has(placement.parent_id): break
            placement = by_id[placement.parent_id]
        if included.size()+chain.size()>capacity: continue
        for id in chain: included[id] = true
    return ordered.filter(func(p):return included.has(p.row.id))

static func operation_logs(packet: Dictionary) -> Array:
    # The append protocol can repeat the native log already attached to a node.
    # Match within this operation only; repeated text in later actions is valid.
    var available: Array = []
    for lineage in packet.lineages:
        for node in lineage.events:
            if node.combat_log != null: available.append(node.combat_log)
    var native_logs = available.duplicate()
    var result: Array = []
    for append in packet.get("combat_log_appends",[]):
        var index = available.find(append.entry)
        if index >= 0: available.remove_at(index); continue
        result.append({"id":"append:%s:%s" % [append.generation,append.encounter_log_index],"event_id":"",
            "sequence":int(packet.cursor.sequence),"source_index":append.operation_end_cursor,"entry":_unique_children(append.entry,native_logs)})
    return result


static func _node_logs(nodes: Array) -> Array:
    var logs: Array = []
    for node in nodes:
        if node.get("combat_log") != null: logs.append(node.combat_log)
    return logs

static func _unique_children(entry: Dictionary, native_logs: Array) -> Dictionary:
    var result = entry.duplicate(true)
    result.sub_entries = []
    var unmatched: Array=native_logs.duplicate()
    for child in entry.get("sub_entries",[]):
        var match_index=-1
        for index in range(unmatched.size()):
            if _same_embedded_log(child,unmatched[index]): match_index=index; break
        if match_index>=0: unmatched.remove_at(match_index)
        else: result.sub_entries.append(_unique_children(child,unmatched))
    return result

static func _same_embedded_log(child: Dictionary, native: Dictionary) -> bool:
    if child == native: return true
    # Subjective projection gives standalone steps path_index=0, then numbers
    # the same children inside an aggregate movement (subjective_combat_log.py).
    # Only this finite, typed difference is normalized; source logs stay intact.
    if child.get("data") == null or native.get("data") == null: return false
    if child.data.get("kind") != "step_movement" or native.data.get("kind") != "step_movement": return false
    var compared = child.duplicate()
    compared.data = child.data.duplicate()
    compared.data.path_index = native.data.get("path_index")
    return compared == native
