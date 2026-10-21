extends SceneTree
const Recording=preload("res://studio/recording.gd")
var checks=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);print("FRENZY_PRESENTATION_FAIL ",label)
func run()->void:
    var directory=""
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--recording="):directory=arg.trim_prefix("--recording=")
    if directory.is_empty():print("Use --recording=<actual Frenzy journal>");quit(2);return
    var index=Recording.read(directory)
    check(index.ok,"Actual Frenzy journal compiles")
    if not index.ok:finish({});return
    var found:int=0
    for item in index.groups:
        for event in item.group.events:
            if event.get("behavior_id")!="action.class.barbarian.frenzy":continue
            var components:Array=item.group.components.filter(func(row):return row.source_event_uuid==event.event_uuid and row.get("ability_id")=="action.class.barbarian.frenzy")
            check(components.size()==1,"One actual Frenzy action owns one finite selected onset")
            for component in components:
                found+=1
                check(component.native_clip.id=="barbarian_frenzy_onset_v191_pressure","Actual action selects the delivered pressure onset, with no retired ground-source substitute")
                check(is_equal_approx(component.start_ms,event._start_ms+100.0) and is_equal_approx(component.duration_ms,1100.0),"Actual onset retains its authored100ms delay and1100ms finite clock")
                check(component.native_cue.attachment=="caster_ground" and component.actor_uuid==event.actor_uuid,"Actual caster owns the onset ground registration")
                check(component.native_cue.get("entity_geometry",{}).get("actor")=="caster" and not component.native_cue.get("entity_geometry",{}).get("slots",[]).is_empty(),"Onset requests the real receiving caster geometry")
                check(component.status=="missing" and component.reason=="native_condition_parent_link_unavailable","Actual onset truthfully refuses the undisclosed Rage/Frenzy parent relation")
                check(component.get("native_inputs",{}).is_empty() and "native_condition_parent_link_unavailable" in component.get("native_input_gaps",[]),"No fabricated parent or arbitrary one-of-two member enters the constructor")
    check(found>0,"Original recording exercises the selected current Frenzy onset")
    finish({"recording":directory,"finite_onsets":found,"output_status":"unavailable","parent_gap":"Both finite foot pressure and retained Frenzy require the actual undisclosed Rage/Frenzy parent link"})
func finish(evidence:Dictionary)->void:
    var report={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Actual Frenzy action ownership, selected native onset metadata and exact missing-parent refusal. This does not prove finite or retained Frenzy pixels; both require the undisclosed native parent relationship."}
    FileAccess.open("res://generated/frenzy_presentation_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("FRENZY_PRESENTATION ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
