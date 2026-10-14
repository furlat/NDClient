extends SceneTree
## Actual recorded rows must distinguish gameplay evidence from visual authorship.
const Recording=preload("res://studio/recording.gd")
const Studio=preload("res://studio/studio.gd")
var checks=0
var failures:Array=[]
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("PROVENANCE_FAIL ",label)
func _initialize()->void:
    var directory=""
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--recording="):directory=argument.trim_prefix("--recording=")
    if directory.is_empty():printerr("Requires --recording=<real Hide journal>");quit(2);return
    var index=Recording.read(directory)
    check(index.ok,"Actual recording admits through the shared SDK/compiler")
    if not index.ok:quit(1);return
    var found={"event":0,"body":0,"audio":0,"air":0,"residue":0,"condition":0}
    for row in index.rows:
        var key=""
        if row.kind=="event" and row.event.get("behavior_id")=="action.hide":key="event"
        elif row.kind=="body" and row.track.get("source")=="res://authoring/presentation/actions/hide.tres::clip":key="body"
        elif row.get("component",{}).get("cue_id")=="hide_transition":key="audio"
        elif row.get("component",{}).has("body_release"):key="air"
        elif row.get("requirement",{}).get("authority_source")=="DamageResultFact.body_release.regions":key="residue"
        elif row.kind=="condition" and row.owner.condition.behavior_id=="condition.hidden":key="condition"
        if key.is_empty():continue
        found[key]+=1
        var saved=row.duplicate(true)
        var text="\n".join(Studio.provenance_lines(row))
        check(row==saved,"Inspector labels leave recorded row unchanged: "+key)
        if key=="event":
            check(text.begins_with("Origin: recorded server event") and text.contains(row.event.event_uuid),"Real Hide event is identified by its actual server UUID")
        elif key in ["body","audio","air"]:
            check(text.begins_with("Origin: authored presentation") and text.contains("server does not select"),"Authored visual is not mislabeled as a server-selected appearance: "+key)
        if key=="body":check(text.contains("hide.tres::clip"),"Action body exposes editable assignment")
        elif key=="audio":check(text.contains("hide.tres::effect_audio_cue") and text.contains("audio/cues.json:"),"Audio exposes both authored assignment and selected cue source")
        elif key=="air":check(text.contains("DamageResultFact.body_release (body.blood)") and text.contains("creates no ground residue"),"Real release authority is separate from the selected airborne effect")
        elif key=="residue":
            check(text.contains("disclosed server state needs a renderer") and text.contains("DamageResultFact.body_release.regions"),"Residue work is anchored to an actual disclosed server field")
            check(text.contains("required renderer is missing") and not text.contains("assignment or ownership decision is missing"),"Missing residue renderer is not falsely reported as absent authoring or a displayed deposit")
        elif key=="condition":check(text.begins_with("Origin: recorded condition state/lifetime") and text.contains("Recorded condition: "+row.owner.id),"Condition state is server-owned and keeps its actual recorded instance")
    for key in found:check(found[key]>0,"Actual fixture covers provenance category: "+key)
    check(Studio.provenance_lines({}).is_empty(),"No selected row invents no provenance")
    var report={"checks":checks,"failures":failures,"recording":directory,"categories":found,"scope":"Readable inspector provenance from actual shared-index rows; no native visual or gameplay claim."}
    FileAccess.open("res://generated/studio_provenance_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("STUDIO_PROVENANCE ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
