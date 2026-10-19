extends SceneTree
## Whole installed package and actual typed spell owners; no backend or GPU fixture.
const Common=preload("res://tools/presentation_build/common.gd")
const Build=preload("res://tools/presentation_build/abilities.gd")
const Records=preload("res://tools/presentation_build/ability_records.gd")
const Spells=preload("res://presentation/native_spell_authoring.gd")
var checks=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("HANDOVER_FAIL "+label)
func run()->void:
    var report:Dictionary=Common.report();var source:Dictionary=Common.load_root("res://authoring/abilities.tres",report)
    var entries:Dictionary=source.entries;var package:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/vfx/index.json"))
    var baseline:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/schema16/condition_handover_baseline.json"))
    var body:Dictionary={};var owners:Dictionary={};var families:int=0
    for selection in package.selections:
        var lifecycle:Dictionary=selection.get("condition",{})
        if lifecycle.is_empty():continue
        families+=1
        for owner in lifecycle.get("owner_ids",[]):
            owners[owner]=true
            if lifecycle.get("body_channel_included",false):body[owner]=true
    check(families==155,"All 155 delivered families participate in the same owner policy")
    for owner in owners:
        if owner.begins_with("spatial_effect."):continue
        var condition:Resource=entries.conditions.get(owner)
        check(condition!=null and condition.play_package_lifecycle,"Exact delivered owner is enabled through existing condition policy: "+owner)
    var migrated:int=0;var candidates:Dictionary={}
    for id in entries.spells:
        var entry:Resource=entries.spells[id]
        if entry.native_staging:candidates[id]=true
        if baseline.existing.has(id):
            var previous:Dictionary=baseline.existing[id]
            var previous_cues:Array=previous.owner_cues.map(func(cue):return int(cue))
            check(entry.owner_kind==previous.owner_kind and Array(entry.owner_ids)==previous.owner_ids and Array(entry.owner_cues)==previous_cues,"Existing explicit handover is preserved: "+id)
        if baseline.rejected.has(id):
            var previous:Dictionary=baseline.rejected[id]
            check(entry.native_staging==previous.native_staging and entry.status==previous.status and entry.notes==previous.notes,"User-rejected spell acceptance flags and notes are preserved: "+id)
        var applicable:Array=[]
        for owner in entry.applies_conditions:
            if body.has(owner):applicable.append(owner)
        var attached:Array=[]
        for index in entry.effects.size():
            var effect:Resource=entry.effects[index]
            if effect.role=="attached" and effect.attachment.begins_with("recipient_") and index not in entry.excluded_cues and (not entry.explicit_event_cues or index in entry.event_cues):attached.append(index)
        if entry.delivery=="summon" or not entry.summons.is_empty():
            check(entry.owner_kind.is_empty(),"Transitive summon rider conditions cannot suppress the summon-creation cast: "+id)
            continue
        if not applicable.is_empty() and not attached.is_empty() and not baseline.existing.has(id):
            migrated+=1
            check(entry.owner_kind=="condition" and Array(entry.owner_ids)==applicable and Array(entry.owner_cues)==attached,"Every compatible recipient-body spell hands over actual declared owners/cues: "+id)
        if entry.owner_kind!="condition":continue
        for owner in entry.owner_ids:
            check(owner in entry.applies_conditions or owner in baseline.existing.get(id,{}).get("owner_ids",[]),"No condition owner was guessed from a spell name: "+id+":"+owner)
        var selected:Dictionary=Records.spell_selection(entry,id.trim_prefix("spell."),{})
        var carried:Array=Spells.owned_cues(selected)
        check(carried==Array(entry.owner_cues),"Actual package body channels suppress precisely the authored attached cues: "+id)
        var event_clips:Array=Spells.effect_clips(selected)
        var old_only:Dictionary={}
        for cue in entry.owner_cues:
            check(cue>=0 and cue<entry.effects.size() and entry.effects[cue].role=="attached","Handover leaves cast/projectile/impact/area cues intact: "+id+":"+str(cue))
            old_only[entry.effects[cue].clip]=true
        for index in entry.effects.size():
            if index not in entry.owner_cues:old_only.erase(entry.effects[index].clip)
        check(event_clips.all(func(clip):return not old_only.has(clip.id)),"First-use preparation does not warm superseded body cues: "+id)
    check(migrated==50,"All 50 newly compatible body handovers are represented")
    var haste:Resource=entries.spells["spell.haste"]
    check(Array(haste.owner_ids)==["condition.spell.haste"] and Array(haste.owner_cues)==[0,1,2],"Haste has one actual body owner, independent of its later lethargy marker")
    var ownership:Dictionary=Build.condition_owners(entries.spells,entries.conditions,candidates)
    check(not ownership.owners.has("condition.charmed") and ownership.conflicts.has("condition.charmed"),"A shared charmed condition cannot inherit the first alphabetic spell's finish")
    var altered:Dictionary=entries.conditions.duplicate();var explicit:Resource=altered["condition.charmed"].duplicate();explicit.owner_spell="spell.hypnotic_pattern";altered["condition.charmed"]=explicit
    check(Build.condition_owners(entries.spells,altered,candidates).owners.get("condition.charmed")=="spell.hypnotic_pattern","An explicit typed shared-condition owner resolves the ambiguity")
    check(ownership.owners.get("condition.spell.haste")=="spell.haste","Summon transitive capabilities do not steal Haste's owner finish")
    check(report.errors.is_empty(),"Actual typed roots load without errors")
    print(JSON.stringify({"checks":checks,"failures":failures,"families":families,"owners":owners.size(),"new_handovers":migrated,"condition_conflicts":ownership.conflicts}));quit(0 if failures.is_empty() else 1)
