extends SceneTree
# Offline Studio contract: recorded input -> full presentation index -> target-time
# state/samples. No server, texture upload, native pixels, audio or UI claim.
const Recording = preload("res://studio/recording.gd")
const Journal = preload("res://sdk/journal.gd")
const Compiler = preload("res://presentation/compiler.gd")
const Timeline = preload("res://presentation/timeline.gd")
const Conditions = preload("res://presentation/conditions.gd")
const Authoring = preload("res://presentation/authoring.gd")
var checks = 0
var failures: Array = []
var evidence: Array = []
var seek_differences: Array = []
var output = "res://generated/studio_seek_checks.json"
var reverse_steps = 0
var sample_cache: Dictionary = {}
var condition_evidence: Array = []

func _initialize() -> void:
    run.call_deferred()

func check(value: bool, label: String) -> void:
    checks += 1
    if not value:
        failures.append(label)
        print("STUDIO_SEEK_FAIL ",label)

func _timeline(index: Dictionary) -> RefCounted:
    var value = Timeline.new()
    var initial: Dictionary = index.initialization.duplicate()
    initial.state = index.initialization.state.duplicate(true)
    value.accept(initial)
    var groups: Array = []
    for item in index.groups: groups.append(item.group)
    value.accept({"kind":"operation","groups":groups})
    return value

func _snapshot(timeline: RefCounted) -> Dictionary:
    var log: Dictionary = timeline.event_log(100000).duplicate(true)
    # This is a redraw/change notification counter, not recorded semantic time.
    # Different sampling cadences may tick the same coverage through more phases.
    log.erase("revision")
    # Expired one-shot crossing candidates are interval notifications consumed
    # by AudioPresenter, not active target-time samples. Silent seek intentionally
    # carries no historical sound; the separate audio lifecycle test owns that.
    var active_components=timeline.component_samples(sample_cache).filter(func(row):return row.kind!="audio" or row.age_ms<row.duration_ms)
    return {"state":timeline.state.duplicate(true),"display_ms":timeline.display_ms,
        "sequence":timeline.sequence,"current":timeline.current.get("id",""),
        "commits":timeline.commit_index,"samples":timeline.actor_samples().duplicate(true),
        "directions":timeline.actor_directions().duplicate(true),
        "components":active_components.duplicate(true),
        "logs":log}

func _state_at(index: Dictionary, time_ms: float) -> Dictionary:
    var state: Dictionary = index.initialization.state.duplicate(true)
    for item in index.groups:
        if item.start_ms>time_ms: break
        var local: float = minf(time_ms-item.start_ms,item.group.duration_ms)
        for commit in item.group.commits:
            if commit.at_ms>local+.000001: break
            Compiler.apply_delta(state,commit.delta)
        if time_ms<item.start_ms+item.group.duration_ms: break
    return state

func _add_boundary(boundaries: Array, time_ms: float) -> void:
    if time_ms not in boundaries and boundaries.size()<96: boundaries.append(time_ms)

func _same_snapshot(actual: Dictionary, expected: Dictionary) -> bool:
    for field in actual:
        # Adding many forward deltas can round the double clock differently from
        # one absolute seek. This bound is 100,000 times below the boundary probe.
        if field=="display_ms":
            if absf(actual[field]-expected[field])>.00000001: return false
        elif actual[field]!=expected[field]: return false
    return true

func _stepping() -> void:
    var index = {"duration_ms":2000.0,"presentation_end_ms":2000.0}
    var row = {"start_ms":100.0,"end_ms":1100.0,"source_fps":10.0,
        "track":{"rig":"typed","clip":"sample","duration_ms":1000.0,"source_start_seconds":0.0,"source_end_seconds":1.0}}
    check(is_equal_approx(Recording.step_time(index,row,100,1),200),"Linear source step selects the next authored frame")
    check(is_equal_approx(Recording.step_time(index,row,600,-1),500),"Linear reverse control selects the preceding authored frame")
    row.track.source_start_seconds=1.0;row.track.source_end_seconds=0.0
    check(is_equal_approx(Recording.step_time(index,row,100,1),200),"Reversed clip moves forward one source frame without the negative-rate jump")
    check(is_equal_approx(Recording.step_time(index,row,600,-1),500),"Reversed clip steps backward through display time")
    row.track.source_time_keys=[[0.0,0.0],[.2,.4],[.6,.4],[1.0,1.2]]
    check(is_equal_approx(Recording.step_time(index,row,350,1),750),"Nonlinear source step skips a held source frame to its next authored crossing")
    check(is_equal_approx(Recording.step_time(index,row,350,-1),250),"Nonlinear backward step returns the prior source frame before a hold")
    check(Recording.step_time(index,row,1200,1)>=1200,"Forward source stepping beyond selected occurrence cannot rewind")
    check(Recording.step_time(index,row,50,-1)<=50,"Backward source stepping before selected occurrence cannot advance")
    check(Recording.step_time(index,{},2000,1)==2000 and Recording.step_time(index,{},0,-1)==0,"Sample controls respect recording interval ends")

func _metadata(index: Dictionary, label: String) -> Dictionary:
    var rows = {}
    for row in index.rows:
        check(not rows.has(row.id),label+" unique inspectable row "+str(row.id))
        rows[row.id] = row
        check(float(row.start_ms)>=0 and float(row.end_ms)>=float(row.start_ms),label+" ordered row interval "+str(row.id))
    var events = 0
    var bodies = 0
    var components = 0
    var group_start = 0.0
    for item in index.groups:
        var group: Dictionary = item.group
        check(item.start_ms>=group_start and is_equal_approx(item.start_ms,group.get("preview_start_ms",group_start)),label+" ordered presentation group with explicit inspection spacing "+str(group.id))
        for event in group.events:
            events += 1
            check(rows.has(event.id),label+" full index retains event "+str(event.id))
            if not rows.has(event.id): continue
            var row: Dictionary = rows[event.id]
            check(row.parent==event.parent_id and row.event==event,label+" event source and parent preserved "+str(event.id))
            check(is_equal_approx(row.start_ms,item.start_ms+event._start_ms) and is_equal_approx(row.end_ms,item.start_ms+event._end_ms),label+" event local-to-recording clock "+str(event.id))
            if event.kind=="spell" and event.has("cast_owner_event"):
                check(group.events.any(func(owner):return owner.event_uuid==event.cast_owner_event),label+" shared cast owner is a real occurrence in its compiled group "+event.id)
                if event.cast_owner_event!=event.event_uuid:
                    check(not event.components.any(func(component):return component.reason in ["missing_authored_cast_body","authored_cast_layer_not_implemented"]),label+" repeated spell application does not fabricate another cast requirement "+event.id)
        for track in group.actor_tracks:
            bodies += 1
            check(rows.has(track.trace_track_id),label+" full index retains body "+str(track.trace_track_id))
            if not rows.has(track.trace_track_id): continue
            var row: Dictionary = rows[track.trace_track_id]
            check(row.track==track and row.parent=="%s:%s" % [group.operation_sequence,track.source_event_uuid],label+" body has exact occurrence owner "+str(track.trace_track_id))
            check(is_equal_approx(row.start_ms,item.start_ms+track.start_ms) and is_equal_approx(row.end_ms,row.start_ms+track.duration_ms),label+" body retains authored interval "+str(track.trace_track_id))
            check(not row.actor.is_empty() or row.status!="available",label+" unresolved body cannot claim available "+str(track.trace_track_id))
        for component in group.get("components",[]):
            components += 1
            check(rows.has(component.id),label+" full index retains dependent component "+str(component.id))
            if not rows.has(component.id): continue
            var row: Dictionary = rows[component.id]
            check(row.parent==component.parent_id,label+" component preserves cause "+str(component.id))
            check(is_equal_approx(row.start_ms,item.start_ms+component.start_ms),label+" component preserves local start "+str(component.id))
            if component.has("source_track"):
                check(is_same(row.get("source_track"),component.source_track),label+" component index retains exact source-pose metadata "+str(component.id))
                if not component.has("body_track_id"):
                    var sampled=Compiler.Tracks.samples(group.actor_tracks,component.start_ms).get(component.get("actor_uuid"),{})
                    if not sampled.is_empty():
                        check(component.source_track.trace_track_id==sampled.trace_track_id,label+" component pose agrees with production priority/tie/holding selection "+str(component.id))
            if not row.get("actor",{}).is_empty():
                check(row.actor.id==component.get("actor_uuid"),label+" component preview keeps actual recipient identity "+str(component.id))
        group_start = item.start_ms+float(group.duration_ms)
    check(is_equal_approx(group_start,index.duration_ms),label+" recording extent includes every compiled group")
    check(index.rows.filter(func(row):return row.kind=="event").size()==events,label+" event index is complete, independent of bounded trace")
    return {"events":events,"bodies":bodies,"components":components,"rows":index.rows.size(),"groups":index.groups.size()}


func _condition_members(state: Dictionary) -> Dictionary:
    var result={}
    for actor_id in state.actors:
        for condition in state.actors[actor_id].get("conditions",[]):
            result[condition.condition_uuid]={"actor":actor_id,"condition":condition}
    return result

func _condition_index(index: Dictionary, label: String) -> Dictionary:
    var rows={}
    for row in index.rows: rows[row.id]=row
    var members=0
    var kinds={}
    var sampled={}
    for row in index.rows:
        if not ":member:" in row.id or not row.has("owner"): continue
        members+=1
        kinds[row.kind]=int(kinds.get(row.kind,0))+1
        var parent: Dictionary=rows.get(row.parent,{})
        check(not parent.is_empty() and parent.kind in ["condition","condition_exit"],label+" condition mechanism has its actual lifecycle parent "+row.id)
        if parent.is_empty(): continue
        check(row.start_ms>=parent.start_ms and row.end_ms<=parent.end_ms,label+" condition mechanism stays within its lifetime or authored fade "+row.id)
        check(not str(row.get("source","")).is_empty() and not row.get("component",{}).is_empty(),label+" condition mechanism retains real source and resolved component "+row.id)
        var component: Dictionary=row.get("component",{})
        check(component.get("actor_uuid")==row.owner.actor_uuid and row.owner.id==parent.owner.id,label+" condition mechanism keeps exact instance/recipient "+row.id)
        check(row.get("source_start_ms")==component.get("absolute_start_ms",component.get("start_ms")),label+" condition source clock survives suppression interval boundaries "+row.id)
        for state_row in index.rows:
            if state_row.kind!="condition_state" or state_row.parent!="condition:"+row.owner.id or state_row.providers.is_empty(): continue
            check(row.end_ms<=state_row.start_ms or row.start_ms>=state_row.end_ms,label+" executing condition mechanism never overlaps suppressed interval "+row.id)
        var at: float=(row.start_ms+row.end_ms)*.5
        if not sampled.has(at):sampled[at]=Recording.restore(index,at).component_samples(index.cache)
        var active: Array=sampled[at]
        if row.kind=="condition_material":
            var selected=Conditions.select_recipes(row.owner.actor_uuid,active)
            check(selected.any(func(sample):return sample.condition_uuid==row.owner.id),label+" material track names a selected composed owner at its midpoint "+row.id)
            var persistent: Dictionary=component.recipe.get("persistent",{})
            check(not row.get("operations",{}).is_empty(),label+" material track names actual operations "+row.id)
            for field in row.get("operations",{}):
                check(persistent.get(field)==row.operations[field],label+" material track operation is exact authoring "+row.id+":"+field)
        elif row.kind=="condition_pose":
            var persistent: Dictionary=component.recipe.get("persistent",{})
            if row.get("legacy_source","").contains("/activityPoses/"):
                check(persistent.get("activityPoses",[]).any(func(pose):return pose.rigId==row.actor.rig and pose.activity==row.activity and pose.clip==row.selected_pose.clip),label+" activity pose track retains selected authored rig/clip "+row.id)
            else:
                check(row.pose==persistent.get("frozenPose",persistent.get("bodyPose")),label+" pose track retains authored condition pose "+row.id)
        else:
            check(row.kind in ["native_effect","registered_media","audio"] and row.kind==component.kind,label+" condition child preserves its actual finite mechanism "+row.id)
            if row.get("selection_policy")=="sampled":
                var playback=Recording.restore(index,at)
                var activities={}
                for id in playback.actor_samples():activities[id]=playback.actor_samples()[id].get("activity","idle")
                var candidates=Conditions.samples(playback.condition_owners.duplicate(),at,index.cache,activities,false)
                check(candidates.any(func(sample):return sample.id==component.id),label+" indexed candidate retains its real owner/source before sample-time arbitration "+row.id)
                var chosen=Conditions.select_layers(candidates.filter(func(sample):return sample.has("layer")),at,activities)
                var expected=chosen.any(func(sample):return sample.id==component.id)
                var witnessed=active.any(func(sample):return sample.id==component.id or (sample.get("trace_keys",[]) as Array).has("condition:"+row.owner.id+":layer:"+component.layer.id))
                check(witnessed==expected,label+" candidate execution follows shared activity/marker selection at its midpoint "+row.id)
            else:check(active.any(func(sample):return sample.id==component.id),label+" condition child is sampled by production at its indexed midpoint "+row.id)
    return {"members":members,"kinds":kinds}

func _condition_lifecycle(index: Dictionary, label: String) -> void:
    # Expected ownership comes from the independently folded authoritative actor
    # conditions, not Timeline's retained presentation owner table.
    var initial=_condition_members(index.initialization.state)
    var prior=initial
    var times: Array=[0.0]
    var removed: Array=[]
    var applied=0
    var suppressed_count=0
    for item in index.groups:
        for commit in item.group.commits:
            if commit.delta.get("actors",{}).is_empty(): continue
            var at: float=item.start_ms+commit.at_ms
            var current=_condition_members(_state_at(index,at))
            for id in current:
                if not prior.has(id): applied+=1
            for id in prior:
                if not current.has(id): removed.append({"id":id,"at":at,"condition":prior[id].condition})
            if current!=prior:
                for sample_at in [maxf(0,at-.001),at,at+.001]:
                    if sample_at not in times: times.append(sample_at)
            prior=current
    var state_rows=index.rows.filter(func(row):return row.kind=="condition_state")
    for row in state_rows:
        var id: String=row.parent.trim_prefix("condition:")
        var members=_condition_members(_state_at(index,row.start_ms))
        check(members.has(id),label+" indexed condition state belongs to a live recorded instance "+row.id)
        if members.has(id):
            var providers: Array=members[id].condition.get("state",{}).get("suppression_provider_uuids",[])
            check(row.providers==providers,label+" indexed suppression provider set equals authoritative state "+row.id)
        check(row.end_ms>=row.start_ms,label+" suppression interval preserves causal order "+row.id)
    var sampled=0
    var recipes=Authoring.load_data("catalog/condition_recipes.json",index.cache)
    for at in times:
        var playback=Recording.restore(index,at)
        var expected=_condition_members(_state_at(index,at))
        var samples=playback.component_samples(index.cache)
        var conditions={}
        for sample in samples:
            if sample.kind=="condition": conditions[sample.condition_uuid]=sample
        for id in expected:
            var member: Dictionary=expected[id]
            var config: Dictionary=recipes.get(member.condition.behavior_id,{})
            if config.is_empty() or config.get("disposition")=="state_only": continue
            var suppressed=not member.condition.get("state",{}).get("suppression_provider_uuids",[]).is_empty()
            check(conditions.has(id)!=suppressed,label+" condition presentation follows due active/suppressed state "+id+" at "+str(at))
            if suppressed: suppressed_count+=1;continue
            if not conditions.has(id): continue
            var sample: Dictionary=conditions[id]
            check(sample.actor_uuid==member.actor and sample.condition==member.condition,label+" condition sample retains exact recipient and admitted instance "+id)
            check(sample.initial==initial.has(id),label+" existing condition sustains without invented application "+id)
            check(sample.age_ms>=0 and sample.absolute_start_ms<=at,label+" condition uses causal shared display age "+id)
            sampled+=1
        for id in conditions:
            if expected.has(id): continue
            var sample: Dictionary=conditions[id]
            check(not is_inf(sample.duration_ms) and sample.alpha>=0 and sample.alpha<=1 and at<=sample.absolute_start_ms+sample.duration_ms+Conditions.fade_ms(sample.condition,index.cache),label+" removed condition has only its bounded presentation tail "+id)
    var fade_checks=0
    for removal in removed:
        var at: float=removal.at+Conditions.fade_ms(removal.condition,index.cache)+.001
        if _condition_members(_state_at(index,at)).has(removal.id): continue
        var restored=Recording.restore(index,at)
        var ids={}
        for sample in restored.component_samples(index.cache):
            if sample.kind=="condition": ids[sample.condition_uuid]=true
        check(not ids.has(removal.id),label+" removed condition disappears after authored fade "+removal.id)
        fade_checks+=1
    condition_evidence.append({"recording":index.directory,"initial":initial.size(),"applications":applied,"removals":removed.size(),"active_samples":sampled,"suppressed_samples":suppressed_count,"expired_tail_checks":fade_checks,"indexed_state_intervals":state_rows.size(),"indexed_mechanisms":_condition_index(index,label)})

func _condition_composition() -> void:
    var recipe: Dictionary=Authoring.load_data("catalog/condition_recipes.json",sample_cache)["condition.poisoned"]
    var one={"id":"condition:owner-a","kind":"condition","actor_uuid":"recipient","condition_uuid":"owner-a","recipe":recipe,"alpha":1.0,"age_ms":400.0}
    var two=one.duplicate();two.id="condition:owner-b";two.condition_uuid="owner-b"
    var single=Conditions.material("recipient",[one])
    check(Conditions.material("recipient",[one,two])==single,"Distinct source owners keep one authored Poisoned material contribution")
    check(Conditions.material("recipient",[two])==single,"Removing one source preserves the surviving same-recipe material")
    check(Conditions.material("recipient",[]).tint==Vector3.ONE,"Removing last source restores the underlying body material")

func _recording(directory: String) -> void:
    var label = directory.trim_suffix("/journal").trim_suffix("/amber").trim_suffix("/blue").get_file()
    var index: Dictionary = Recording.read(directory)
    check(index.get("ok",false),label+" valid recording indexes: "+str(index.get("error","")))
    if not index.get("ok",false): return
    sample_cache=index.cache
    var metadata = _metadata(index,label)
    _condition_lifecycle(index,label)
    for row in index.rows:
        if not row.has("track") or row.source_fps<=0: continue
        var track: Dictionary = row.track
        if track.source_end_seconds>=track.source_start_seconds or track.has("source_time_keys"): continue
        var frame_ms: float = track.duration_ms/((track.source_start_seconds-track.source_end_seconds)*row.source_fps)
        var time: float = row.start_ms+frame_ms*2
        check(is_equal_approx(Recording.step_time(index,row,time,1),time+frame_ms),label+" real reversed authored body advances one sample")
        check(is_equal_approx(Recording.step_time(index,row,time,-1),time-frame_ms),label+" real reversed authored body reverses one sample")
        reverse_steps += 2
    var token: Dictionary = Recording.cancellation()
    Recording.cancel(token)
    var canceled: Dictionary = Recording.read(directory,token)
    check(not canceled.ok and canceled.get("canceled",false),label+" canceled recording never publishes an index")
    check(Recording.restore(index,index.duration_ms,token)==null,label+" canceled seek never publishes a replacement")
    var retained_initial: Dictionary = index.initialization.duplicate(true)
    var retained_groups: Array = index.groups.duplicate(true)
    var retained_rows: Array = index.rows.duplicate(true)
    var forward = _timeline(index)
    var expected: Dictionary = index.initialization.state.duplicate(true)
    var boundaries: Array = [0.0,index.duration_ms]
    var commit_count = 0
    var facing_count = 0
    var endpoint_count = 0
    var journal = Journal.new()
    var opened: Dictionary = journal.open(directory,true,false)
    check(opened.ok,label+" public journal opens")
    if not opened.ok: return
    for item in index.groups:
        var group: Dictionary = item.group
        var previous_commit = -INF
        for commit in group.commits:
            check(float(commit.at_ms)>=previous_commit,label+" authored commit order "+str(group.id))
            previous_commit = float(commit.at_ms)
            # Equal-time commits are one observable boundary. Preserve their
            # original array order in the independent state fold.
            Compiler.apply_delta(expected,commit.delta)
            commit_count += 1
            var absolute: float = item.start_ms+commit.at_ms
            _add_boundary(boundaries,maxf(0.0,absolute-.001))
            _add_boundary(boundaries,absolute)
        var endpoint: float = item.start_ms+group.duration_ms
        forward.advance(maxf(0.0,endpoint-forward.display_ms))
        # The next zero-duration group may also commit at this exact timestamp;
        # canonical operation checks below use an isolated completed prefix.
        if group.get("operation_end",false):
            var replayed: Dictionary = journal.replay(int(group.operation_sequence))
            check(replayed.ok,label+" canonical prefix "+str(group.operation_sequence))
            if replayed.ok: check(expected==journal.state,label+" all ordered commits equal public canonical prefix "+str(group.operation_sequence))
            endpoint_count += 1
        _add_boundary(boundaries,maxf(0.0,endpoint-.001))
        _add_boundary(boundaries,endpoint)
        for track in group.actor_tracks:
            if track.get("motion",false) and track.get("from_position")!=null and track.get("to_position")!=null and track.from_position!=track.to_position:
                var at: float = item.start_ms+track.start_ms+minf(track.duration_ms*.5,1.0)
                _add_boundary(boundaries,at)
                var sample = Recording.restore(index,at)
                var body: Dictionary = sample.actor_samples().get(track.actor_uuid,{})
                # Only the visible winning movement owns facing here; suppressed
                # tracks are deliberately not treated as displayed evidence.
                if body.get("trace_track_id")==track.trace_track_id:
                    var directions: Dictionary = sample.actor_directions()
                    check(directions.has(track.actor_uuid) and directions[track.actor_uuid]==[track.from_position,track.to_position],label+" sampled movement keeps its recorded heading "+str(track.trace_track_id))
                    facing_count += 1
    check(not forward.busy(),label+" forward playback drains the complete retained index")
    check(forward.state==expected,label+" forward final state equals ordered commit fold")
    check(forward.sequence==index.operations,label+" every recorded operation reaches display")
    # Sequential playback is the reference for random access, including each
    # side of a semantic boundary. Requests intentionally run out of order.
    boundaries.sort()
    var references = {}
    var linear = _timeline(index)
    for time in boundaries:
        linear.advance(maxf(0.0,float(time)-linear.display_ms))
        references[time] = _snapshot(linear)
    boundaries.reverse()
    for time in boundaries:
        var restored = Recording.restore(index,time)
        check(restored.paused,label+" scrub is paused at "+str(time))
        var actual: Dictionary = _snapshot(restored)
        check(actual.state==_state_at(index,time),label+" only causally due commits are visible at "+str(time))
        if not _same_snapshot(actual,references[time]):
            var fields: Array = []
            for field in actual:
                if actual[field]!=references[time][field]: fields.append(field)
            seek_differences.append({"recording":directory,"time_ms":time,"fields":fields,
                "actual_samples":actual.samples,"expected_samples":references[time].samples,
                "actual_components":actual.components,"expected_components":references[time].components,
                "actual_logs":actual.logs,"expected_logs":references[time].logs,
                "actual_clock":actual.display_ms,"expected_clock":references[time].display_ms})
        check(_same_snapshot(actual,references[time]),label+" backward seek exactly restores target state/samples/log at "+str(time))
    for time in [0.0,index.duration_ms*.5,index.duration_ms,0.0]:
        var a = Recording.restore(index,time)
        var b = Recording.restore(index,time)
        check(_snapshot(a)==_snapshot(b),label+" repeated seek is deterministic at "+str(time))
    var end = Recording.restore(index,index.duration_ms)
    var terminal_state: Dictionary = end.state.duplicate(true)
    var terminal_sequence: int = end.sequence
    var terminal_directions: Dictionary = end.actor_directions().duplicate(true)
    end.advance(250)
    check(is_equal_approx(end.display_ms,index.duration_ms),label+" pause freezes the shared terminal clock")
    end.paused = false
    end.advance(250)
    check(is_equal_approx(end.display_ms,index.duration_ms+250) and end.state==terminal_state and end.sequence==terminal_sequence,label+" terminal idle advances display time without replaying semantic state")
    check(end.actor_directions()==terminal_directions,label+" terminal idle preserves the last displayed heading")
    # A restored playback owns its mutable top-level state, while its published
    # actor/row after-values and compiled groups remain immutable shared data.
    end.state.actors.clear()
    end.state.tiles.clear()
    end.state.combat_log_appends.clear()
    check(Recording.restore(index,index.duration_ms).state==terminal_state,label+" discarding one restored state does not damage later seeks")
    var initial = _timeline(index)
    if initial.state.actors.size()>0:
        initial.state.actors.values()[0].last_visual_position=[123456,-654321]
    check(index.initialization==retained_initial and index.groups==retained_groups and index.rows==retained_rows,label+" seeking/advancing/teardown preserves retained index and source snapshots")
    metadata.merge({"recording":directory,"duration_ms":index.duration_ms,"operations":index.operations,
        "commits":commit_count,"canonical_endpoints":endpoint_count,"facing_observations":facing_count,
        "seek_samples":boundaries.size()},true)
    evidence.append(metadata)

func run() -> void:
    var directories: Array = []
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--recording="): directories.append(argument.trim_prefix("--recording="))
        elif argument.begins_with("--output="): output=argument.trim_prefix("--output=")
    if directories.is_empty():
        print("Usage: --script res://tests/studio_seek_checks.gd -- --recording=<actual journal> [--recording=<another journal>] [--output=<report>]")
        quit(2); return
    for directory in directories: _recording(directory)
    _stepping()
    _condition_composition()
    var report = {"checks":checks,"failed":failures.size(),"failures":failures,"recordings":evidence,"seek_differences":seek_differences,"real_reverse_steps":reverse_steps,"condition_lifecycle":condition_evidence,
        "scope":"Offline real-recording index/commit/seek ownership and source metadata. Native frame, media gating, material/particle/audio and UI appearance require separate integration evidence.",
        "invocation":{"script":"res://tests/studio_seek_checks.gd","arguments":Array(OS.get_cmdline_user_args())}}
    FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("STUDIO_SEEK ",JSON.stringify({"checks":checks,"failed":failures.size(),"recordings":evidence.size(),"output":output}))
    quit(0 if failures.is_empty() else 1)
