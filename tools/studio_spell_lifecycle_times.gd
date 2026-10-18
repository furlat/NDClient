extends SceneTree
## Published Studio times for the recorded spell lifecycle events, read through
## the same single-faction index the Studio opens (Recording.read + view_index),
## then sought with Recording.restore. Offline; no server, pixels or media.
##   --inventory=res://generated/studio_spell_case_inventory.json  cases with "lifecycle" events
##   --output=<path>   JSON report (times per case/perspective/event and seek checks)
##   --case=<id>       optional filter, repeatable
##   --dump            also list every indexed event row with its published interval
const Recording=preload("res://studio/recording.gd")
var checks=0
var failures:Array=[]

func _initialize()->void:run.call_deferred()

func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);print("SPELL_LIFECYCLE_FAIL ",label)

func _studio_view(perspective:Dictionary)->Dictionary:
    # Identical to Studio._inspection_index: one independent audience, no peer retiming.
    var index=Recording.read(perspective.journal)
    if not index.get("ok",false):return index
    index.perspective_id=perspective.id
    var bundle={"ok":true,"case_id":"lifecycle","perspectives":[perspective],"views":{perspective.id:index},
        "default_perspective_id":perspective.id,"comparison":false}
    return Recording.view_index(bundle,perspective.id)

func _conditions(state:Dictionary,actor:String)->Array:
    return state.get("actors",{}).get(actor,{}).get("conditions",[]).map(func(row):return str(row.get("condition_uuid","")))

func _position(state:Dictionary,actor:String)->Variant:
    return state.get("actors",{}).get(actor,{}).get("last_visual_position")

func _perspective(item:Dictionary,perspective:Dictionary,dump:bool)->Dictionary:
    var label=str(item.id)+" / "+str(perspective.id)
    var view=_studio_view(perspective)
    check(view.get("ok",false),label+": Studio opens the recorded faction journal")
    if not view.get("ok",false):return {"error":str(view.get("error",""))}
    var events={}
    for row in view.rows:
        if row.kind=="event" and row.get("visible_here",true):events[str(row.event.event_uuid)]=row
    var result={"duration_ms":view.duration_ms,"presentation_end_ms":view.presentation_end_ms,"operations":view.operations,"events":[]}
    var ended_ms=-1.0
    for wanted in item.get("lifecycle",[]):
        var row:Dictionary=events.get(str(wanted.event_uuid),{})
        var entry={"role":wanted.role,"event_uuid":wanted.event_uuid,"visible":not row.is_empty()}
        if row.is_empty():
            # A faction may not observe a peer's private event; record that fact.
            check(perspective.id!="amber" or wanted.get("audience","both")!="both",label+": lifecycle event is indexed "+str(wanted.role))
            result.events.append(entry);continue
        var commit=-1.0
        for marker in row.get("markers",[]):
            if marker.kind=="commit":commit=marker.at_ms;break
        # Starts for the cast and walks, the commit for impacts and condition
        # changes, the arrival for a finished walk.
        var at:float=row.start_ms if wanted.role in ["cast","move_start","tail_start"] else row.end_ms if wanted.role in ["moved","tail"] else commit if commit>=0 else row.start_ms
        entry.merge({"start_ms":row.start_ms,"end_ms":row.end_ms,"commit_ms":commit,"published_ms":at,"label":row.label})
        # The event's own presentation rows (body, delivery, impact, condition
        # entry) with their published intervals and contact markers.
        entry.rows=[]
        for child in view.rows:
            if child.get("parent","")!=row.id or child.kind in ["event","requirement"] or not child.get("visible_here",true):continue
            entry.rows.append({"kind":child.kind,"label":child.label,"start_ms":child.start_ms,"end_ms":child.end_ms,
                "markers":child.get("markers",[]).map(func(marker):return {"kind":marker.kind,"at_ms":marker.at_ms})})
        var restored=Recording.restore(view,at+.001)
        check(restored!=null and is_equal_approx(restored.display_ms,at+.001),label+": seek reaches "+str(wanted.role)+" at "+str(at))
        if restored!=null:
            var state:Dictionary=restored.state
            if wanted.has("condition_uuid") and wanted.has("recipient_uuid"):
                # A walk is checked halfway through its step: a removal at the next
                # turn boundary can share the arrival instant (turns take no time).
                if wanted.role in ["moved","move_start"]:state=Recording.restore(view,(row.start_ms+row.end_ms)*.5).state
                var present=str(wanted.condition_uuid) in _conditions(state,str(wanted.recipient_uuid))
                entry.condition_present_after=present
                if wanted.role in ["applied","moved","move_start"]:check(present,label+": condition held after "+str(wanted.role))
                if wanted.role=="ended":check(not present,label+": condition gone after its removal commit")
            if wanted.has("temporary_hp") and wanted.has("recipient_uuid"):
                entry.temporary_hp_after=state.get("actors",{}).get(str(wanted.recipient_uuid),{}).get("temporary_hp")
                check(entry.temporary_hp_after!=null and int(entry.temporary_hp_after)==int(wanted.temporary_hp),label+": temporary hit points after "+str(wanted.role))
            if wanted.has("to_position") and wanted.has("actor_uuid"):
                var reached=Recording.restore(view,row.end_ms+.001)
                entry.position_after=_position(reached.state,str(wanted.actor_uuid))
                check(entry.position_after is Array and entry.position_after.map(func(value):return int(value))==wanted.to_position.map(func(value):return int(value)),label+": seek after "+str(wanted.role)+" shows the recorded position")
        if wanted.role=="ended" and ended_ms<0:ended_ms=at
        result.events.append(entry)
    if ended_ms>=0:result.after_end_ms=view.presentation_end_ms-ended_ms
    var restored_end=Recording.restore(view,view.presentation_end_ms)
    check(restored_end!=null and is_equal_approx(restored_end.display_ms,view.presentation_end_ms),label+": seek reaches the presentation end")
    if dump:
        result.rows=[]
        for row in view.rows:
            if row.kind!="event" or not row.get("visible_here",true):continue
            var commit=-1.0
            for marker in row.get("markers",[]):
                if marker.kind=="commit":commit=marker.at_ms;break
            result.rows.append({"kind":row.event.kind,"label":row.label,"event_uuid":row.event.event_uuid,"start_ms":row.start_ms,"end_ms":row.end_ms,"commit_ms":commit,"parent":row.parent})
    return result

func run()->void:
    var inventory_path="res://generated/studio_spell_case_inventory.json"
    var output=""
    var wanted:Array=[]
    var dump=false
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--inventory="):inventory_path=argument.trim_prefix("--inventory=")
        elif argument.begins_with("--output="):output=argument.trim_prefix("--output=")
        elif argument.begins_with("--case="):wanted.append(argument.trim_prefix("--case="))
        elif argument=="--dump":dump=true
    var inventory=JSON.parse_string(FileAccess.get_file_as_string(inventory_path))
    if not inventory is Dictionary or output.is_empty():
        print("Usage: --script res://tools/studio_spell_lifecycle_times.gd -- --output=<report> [--inventory=<inventory>] [--case=<id>] [--dump]")
        quit(2);return
    var cases={}
    for item in inventory.get("cases",[]):
        if not wanted.is_empty() and not item.id in wanted:continue
        var views={}
        for perspective in item.perspectives:views[perspective.id]=_perspective(item,perspective,dump)
        cases[item.id]=views
        print("SPELL_LIFECYCLE_CASE ",item.id," ",JSON.stringify(views.values().map(func(view):return {"end":view.get("presentation_end_ms"),"after_end":view.get("after_end_ms")})))
    var report={"checks":checks,"failed":failures.size(),"failures":failures,"inventory":inventory_path,"cases":cases,
        "scope":"Studio single-faction index (Recording.read + view_index) and Recording.restore seeks at each recorded lifecycle event. No pixels, media or UI."}
    var file=FileAccess.open(output,FileAccess.WRITE)
    file.store_string(JSON.stringify(report,"  "));file.close()
    print("SPELL_LIFECYCLE ",JSON.stringify({"checks":checks,"failed":failures.size(),"cases":cases.size(),"output":output}))
    quit(0 if failures.is_empty() else 1)
