extends SceneTree
## Actual recorded rows must distinguish gameplay evidence from visual authorship.
const Recording=preload("res://studio/recording.gd")
const Studio=preload("res://studio/studio.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
var checks=0
var failures:Array=[]
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("PROVENANCE_FAIL ",label)
func _initialize()->void:run.call_deferred()
func run()->void:
    var directories:Array=[]
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--recording="):directories.append(argument.trim_prefix("--recording="))
    if directories.is_empty():
        for id in ["hide","gallery","oa-jump-late-lethal"]:directories.append(Fixtures.journal(id))
    var found={"event":0,"body":0,"audio":0,"air":0,"residue":0,"condition":0}
    for directory in directories:
        var index=Recording.read(directory)
        check(index.ok,"Actual recording admits through the shared SDK/compiler: "+directory)
        if not index.ok:continue
        for row in index.rows:
            var key=""
            if row.kind=="event" and row.event.get("behavior_id")=="action.hide":key="event"
            elif row.kind=="body" and row.track.get("source")=="res://authoring/abilities/actions/action.hide.tres::body/clip":key="body"
            elif row.get("component",{}).get("cue_id")=="hide_transition":key="audio"
            elif row.kind=="residue_deposit" and row.get("component",{}).has("body_release"):key="residue"
            elif row.get("component",{}).has("body_release"):key="air"
            elif row.kind=="condition" and row.owner.condition.behavior_id=="condition.hidden":key="condition"
            if key.is_empty():continue
            found[key]+=1
            var saved=row.duplicate(true)
            var text="\n".join(Studio.provenance_lines(row))
            check(row==saved,"Inspector labels leave recorded row unchanged: "+key)
            if key=="event":
                check(text.begins_with("Origin: recorded server event") and text.contains(row.event.event_uuid),"Real Hide event is identified by its actual server UUID")
            elif key in ["body","audio","air","residue"]:
                check(text.begins_with("Origin: authored presentation") and text.contains("server does not select"),"Authored visual is not mislabeled as a server-selected appearance: "+key)
            if key=="body":check(text.contains("action.hide.tres::body/clip"),"Action body exposes editable assignment")
            elif key=="audio":check(text.contains("action.hide.tres::sounds/0/cue") and text.contains("audio/cues.json:"),"Audio exposes both authored assignment and selected cue source")
            elif key=="air":check(text.contains("DamageResultFact.body_release ("+row.component.body_release.release_id+")") and text.contains("creates no ground residue"),"Real release authority is separate from the selected airborne effect")
            elif key=="residue":
                check(row.component.authority_source=="DamageResultFact.body_release.regions + WorldTileState.residues" and text.contains("Server regions and tile after-values own the stain"),"Implemented residue remains anchored to actual disclosed regions and world after-values")
                check(not row.component.reveals.is_empty() and row.status=="available" and not text.contains("required renderer is missing"),"Actual implemented residue is not relabeled as a fabricated missing renderer")
            elif key=="condition":check(text.begins_with("Origin: recorded condition state/lifetime") and text.contains("Recorded condition: "+row.owner.id),"Condition state is server-owned and keeps its actual recorded instance")
    for key in found:check(found[key]>0,"Actual fixture covers provenance category: "+key)
    check(Studio.provenance_lines({}).is_empty(),"No selected row invents no provenance")
    var report={"checks":checks,"failures":failures,"recordings":directories,"categories":found,"scope":"Readable inspector provenance from separate actual shared-index rows; real body release/deposit authority is distinct from selected art. No native visual or gameplay claim."}
    FileAccess.open("res://generated/studio_provenance_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("STUDIO_PROVENANCE ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
