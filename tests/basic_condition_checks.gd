extends SceneTree
## Three real action journals: new indicator authorship cannot change their outcomes or schedule.
const Recording=preload("res://studio/recording.gd")
const Catalog=preload("res://source_catalog.gd")
const Conditions=preload("res://presentation/conditions.gd")
const Coverage=preload("res://presentation/condition_coverage.gd")
const Journal=preload("res://sdk/journal.gd")
const Compiler=preload("res://presentation/compiler.gd")
const Document=preload("res://presentation/resources/ability_document.gd")
const AbilityDocuments=preload("res://presentation/ability_documents.gd")
const Builder=preload("res://tools/presentation_build/abilities.gd")
const Common=preload("res://tools/presentation_build/common.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
var checks=0
var failures:Array=[]
var evidence:Array=[]
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);print("BASIC_CONDITION_FAIL ",label)
func _initialize()->void:run.call_deferred()
func run()->void:
    var directory=""
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--cases="):directory=arg.trim_prefix("--cases=")
    for row in [["dash","dashing",0xe458b1],["dodge","dodging",0x5895e4],["disengage","disengaging",0x6658e4]]:
        examine(Fixtures.journal(row[0]) if directory.is_empty() else directory.path_join(row[0]+"-seed3/amber/journal"),row[0],row[1],row[2])
    reload_check()
    var report={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Real recorded Dash/Dodge/Disengage; authoritative lifetime and commits, no new body/duration, current authored Dash has no contour; Dodge/Disengage contour selection, Resource reload rejection. Pixel rendering is a separate gate."}
    FileAccess.open("res://generated/basic_condition_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("BASIC_CONDITION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
func examine(directory:String,action:String,name:String,color:int)->void:
    var id="condition."+name
    var index=Recording.read(directory)
    check(index.ok,"Actual "+action+" journal compiles")
    if not index.ok:return
    var recipe:Dictionary=Catalog.read_file("catalog/condition_recipes.json",index.cache)[id]
    var action_recipe:Dictionary=Catalog.read_file("catalog/body_action_recipes.json",index.cache)["action."+action]
    check(not action_recipe.actor.enabled,"Body-disabled "+action+" remains body-disabled")
    var outlined:bool=action!="dash"
    if outlined:check(recipe.persistent.bodyOutline.color==color and recipe.persistent.bodyOutline.pulseOpacity==0,"Explicit palette uses original feedback colour without Paralyzed stripe: "+name)
    else:check(not recipe.persistent.has("bodyOutline"),"Current authored Dash explicitly omits the retired pink contour")
    check(recipe.persistent.get("bodyColor")==null and recipe.persistent.alphaMultiplier==1 and not recipe.persistent.has("activityPoses"),"Indicator keeps original body pose, colour and alpha: "+name)
    var entry:Resource=load("res://authoring/abilities/conditions/"+id+".tres")
    check(entry!=null and entry.look.steps.any(func(step):return step.kind=="outline")==outlined,"The actual editable source explicitly owns the selected contour policy: "+name)
    check(entry.look.steps.any(func(step):return step.kind=="body_adjust"),"Actual condition source retains its body-adjustment declaration: "+name)
    var rows=index.rows.filter(func(row):return row.kind=="condition_material" and row.owner.condition.behavior_id==id)
    check(not rows.is_empty() if outlined else rows.all(func(row):return not row.operations.has("bodyOutline")),"Recorded material spans follow explicit source contour policy: "+name)
    var lifetime:Array=index.rows.filter(func(row):return row.kind=="condition" and row.owner.condition.behavior_id==id)
    check(lifetime.size()==1,"Original application has one authoritative indexed condition owner: "+name)
    var owner:Dictionary={} if lifetime.is_empty() else lifetime[0].owner
    for row in rows:
        owner=row.owner
        if outlined:check(row.operations.has("bodyOutline") and row.source_fields.bodyOutline=="res://authoring/abilities/conditions/condition."+name+".tres::look","Exact editable Resource provenance: "+name)
        var at:float=(row.start_ms+row.end_ms)*.5
        var timeline=Recording.restore(index,at)
        var original=timeline.state.duplicate(true)
        var material=Conditions.material(row.owner.actor_uuid,timeline.component_samples(index.cache))
        check(material.outline.get("color")==color if outlined else material.outline.is_empty(),"Shared live selection follows actual owner/source policy at indexed time: "+name)
        check(material.tint==Vector3.ONE and material.alpha==1,"Contour does not dim or tint assembled source: "+name)
        check(timeline.state==original,"Presentation sampling leaves canonical state unchanged: "+name)
    check(not owner.is_empty() and owner.start_ms>0 and is_finite(owner.end_ms) and owner.end_ms>owner.start_ms,"Actual application and removal, not fabricated lifespan: "+name)
    if not owner.is_empty():
        for at in [maxf(0,owner.start_ms-.01),owner.end_ms+.01]:
            var timeline=Recording.restore(index,at)
            check(not timeline.component_samples(index.cache).any(func(sample):return sample.get("condition_uuid")==owner.id),"No contour outside actual owner lifespan: "+name+" at "+str(at))
        var badge_rows=index.rows.filter(func(row):return row.kind=="feedback_text" and row.component.get("legacy_source",row.source).begins_with("catalog/condition_recipes.json:/"+id+"/"))
        check(badge_rows.any(func(row):return row.component.text.begins_with("+")) and badge_rows.any(func(row):return row.component.text.begins_with("−")),"Application and removal feedback both recorded: "+name)
        evidence.append({"action":action,"condition":id,"condition_uuid":owner.id,"start_ms":owner.start_ms,"end_ms":owner.end_ms,"material_spans":rows.size(),"source":entry.resource_path})
    var requirements=Coverage.build(index.cache,index.rows,{id:true}).entries[0].requirements
    check(not requirements.any(func(row):return row.get("gap_kind")=="authoring_assignment"),"Persistent assignment exists, not status suppression: "+name)
    check(requirements.any(func(row):return row.mechanism=="bodyOutline" and not row.evidence.is_empty()) if outlined else not requirements.any(func(row):return row.mechanism=="bodyOutline"),"Coverage follows the explicit current authored contour requirement: "+name)
    var baseline_cache=index.cache.duplicate()
    baseline_cache["catalog/condition_recipes.json"]=Catalog.read_file("catalog/condition_recipes.json",index.cache).duplicate(true)
    baseline_cache["catalog/condition_recipes.json"][id].persistent.erase("bodyOutline")
    var journal=Journal.new();var opened=journal.open(directory,true,false)
    check(opened.ok,"Historical schema opens explicitly: "+action)
    if not opened.ok:return
    var files:Array=[]
    for file in DirAccess.get_files_at(directory):
        if file.ends_with(".json") and file.get_basename().is_valid_int():files.append(file)
    files.sort();var operation=0
    for file in files:
        var raw=FileAccess.get_file_as_bytes(directory.path_join(file))
        var decoded=journal.decode_record(int(file.get_basename()),raw)
        check(decoded.ok,"Actual packet admits "+action+"/"+file)
        if not decoded.ok:break
        var before:Dictionary=journal.state
        var admitted=journal._consume_admitted(decoded.value,raw,true)
        check(admitted.ok,"Actual packet reduces "+action+"/"+file)
        if not admitted.ok:break
        if operation>0:
            var current=Compiler.compile_recorded(before,admitted.normalized,index.cache,journal.state,admitted.transitions)
            var prior=Compiler.compile_recorded(before,admitted.normalized,baseline_cache,journal.state,admitted.transitions)
            check(current.ok and prior.ok,"Both indicator selections compile "+action+"/"+file)
            if current.ok and prior.ok:
                check(current.value.groups.size()==prior.value.groups.size(),"No new causal groups "+action+"/"+file)
                for n in current.value.groups.size():
                    var a=current.value.groups[n];var b=prior.value.groups[n]
                    check(a.commits==b.commits and a.duration_ms==b.duration_ms and a.actor_tracks==b.actor_tracks,"Every event commit, body track and duration unchanged "+action+"/"+file+"/"+str(n))
        operation+=1
func reload_check()->void:
    # The build rejects an invalid contour; a rebuilt table never replaces the
    # snapshot a displayed recording admitted.
    var entry:Resource=load("res://authoring/abilities/conditions/condition.dodging.tres")
    var valid:Dictionary=Common.report();Builder._validate_condition(entry,"dodging",valid)
    check(valid.errors.is_empty(),"Valid outline source admits")
    var cache={};check(Catalog.validate_native(cache).is_empty(),"Valid outline build admits")
    var retained=Catalog.source_snapshot(cache)
    var recipes:Dictionary=Catalog.read_file("catalog/condition_recipes.json",cache).duplicate(true)
    var directory="res://.runtime/basic-condition-reload"
    var prior=ProjectSettings.get_setting("source_data/abilities_build",AbilityDocuments.ROOT)
    for field in ["opacity","period_ms","alpha_threshold","color"]:
        var candidate:Resource=entry.duplicate(true)
        var outline:Resource=candidate.look.steps.filter(func(step):return step.kind=="outline")[0]
        var persistent:Dictionary=candidate.unported.get("persistent",{})
        match field:
            "opacity":outline.alpha=-1.0
            "color":outline.rgb=Color(NAN,0,0)
            "period_ms":persistent.bodyOutline.periodMs=0.0
            "alpha_threshold":persistent.bodyOutline.alphaThreshold=0.0
        var report:Dictionary=Common.report();Builder._validate_condition(candidate,"dodging",report)
        check(not report.errors.is_empty(),"Invalid outline candidate rejects "+field)
        var rebuilt:Dictionary=recipes.duplicate(true);rebuilt["condition.dodging"].persistent.bodyOutline.color=0
        var document:=Document.new();document.data=rebuilt
        var file:=directory.path_join("abilities/docs/catalog/condition_recipes.res")
        DirAccess.make_dir_recursive_absolute(file.get_base_dir());ResourceSaver.save(document,file)
        ProjectSettings.set_setting("source_data/abilities_build",directory.path_join("abilities"))
        Catalog.invalidate_source_indexes()
        check(Catalog.validate_native(retained).is_empty() and Catalog.read_file("catalog/condition_recipes.json",retained)["condition.dodging"].persistent.bodyOutline.color==0x5895e4,"Rejected edit retains admitted source snapshot "+field)
        ProjectSettings.set_setting("source_data/abilities_build",prior)
        Catalog.invalidate_source_indexes()
        DirAccess.remove_absolute(file)
