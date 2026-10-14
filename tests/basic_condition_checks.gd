extends SceneTree
## Three real action journals: new indicator authorship cannot change their outcomes or schedule.
const Recording=preload("res://studio/recording.gd")
const Catalog=preload("res://source_catalog.gd")
const Conditions=preload("res://presentation/conditions.gd")
const Coverage=preload("res://presentation/condition_coverage.gd")
const Journal=preload("res://sdk/journal.gd")
const Compiler=preload("res://presentation/compiler.gd")
const ConditionResource=preload("res://presentation/resources/condition_presentation.gd")
const CatalogResource=preload("res://presentation/resources/catalog.gd")
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
    if directory.is_empty():print("Use --cases=<actual captured Studio cases directory>");quit(2);return
    for row in [["dash","dashing",0xe458b1],["dodge","dodging",0x5895e4],["disengage","disengaging",0x6658e4]]:
        examine(directory.path_join(row[0]+"-seed3/amber/journal"),row[0],row[1],row[2])
    reload_check()
    var report={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Real recorded Dash/Dodge/Disengage; authoritative lifetime and commits, no new body/duration, shared contour selection, Resource reload rejection. Pixel rendering is a separate gate."}
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
    check(recipe.persistent.bodyOutline.color==color and recipe.persistent.bodyOutline.pulseOpacity==0,"Explicit new palette uses original feedback colour without Paralyzed stripe: "+name)
    check(recipe.persistent.get("bodyColor")==null and recipe.persistent.alphaMultiplier==1 and not recipe.persistent.has("activityPoses"),"Indicator keeps original body pose, colour and alpha: "+name)
    var legacy=JSON.parse_string(FileAccess.get_file_as_string(str(ProjectSettings.get_setting("source_data/authoring_root")).path_join("catalog/condition_recipes.json")))[id]
    check(not legacy.persistent.has("bodyOutline"),"Original migration recipe untouched: "+name)
    var rows=index.rows.filter(func(row):return row.kind=="condition_material" and row.owner.condition.behavior_id==id)
    check(not rows.is_empty(),"Recorded owner has indexed persistent contour: "+name)
    var owner={}
    for row in rows:
        owner=row.owner
        check(row.operations.has("bodyOutline") and row.source_fields.bodyOutline=="res://authoring/presentation/conditions/"+name+".tres::body_outline","Exact editable Resource provenance: "+name)
        var at:float=(row.start_ms+row.end_ms)*.5
        var timeline=Recording.restore(index,at)
        var original=timeline.state.duplicate(true)
        var material=Conditions.material(row.owner.actor_uuid,timeline.component_samples(index.cache))
        check(material.outline.get("color")==color,"Shared live selection applies real owner at indexed time: "+name)
        check(material.tint==Vector3.ONE and material.alpha==1,"Contour does not dim or tint assembled source: "+name)
        check(timeline.state==original,"Presentation sampling leaves canonical state unchanged: "+name)
    check(not owner.is_empty() and owner.start_ms>0 and is_finite(owner.end_ms) and owner.end_ms>owner.start_ms,"Actual application and removal, not fabricated lifespan: "+name)
    if not owner.is_empty():
        for at in [maxf(0,owner.start_ms-.01),owner.end_ms+.01]:
            var timeline=Recording.restore(index,at)
            check(not timeline.component_samples(index.cache).any(func(sample):return sample.get("condition_uuid")==owner.id),"No contour outside actual owner lifespan: "+name+" at "+str(at))
        var badge_rows=index.rows.filter(func(row):return row.kind=="feedback_text" and row.component.get("legacy_source",row.source).begins_with("catalog/condition_recipes.json:/"+id+"/"))
        check(badge_rows.any(func(row):return row.component.text.begins_with("+")) and badge_rows.any(func(row):return row.component.text.begins_with("−")),"Application and removal feedback both recorded: "+name)
        evidence.append({"action":action,"condition":id,"condition_uuid":owner.id,"start_ms":owner.start_ms,"end_ms":owner.end_ms,"material_spans":rows.size(),"source":recipe._resource_source})
    var requirements=Coverage.build(index.cache,index.rows,{id:true}).entries[0].requirements
    check(not requirements.any(func(row):return row.get("gap_kind")=="authoring_assignment"),"Persistent assignment exists, not status suppression: "+name)
    check(requirements.any(func(row):return row.mechanism=="bodyOutline" and not row.evidence.is_empty()),"Coverage cites actual recorded contour spans: "+name)
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
        var decoded=journal.protocol.decode("InitializationResponse" if operation==0 else "PlayerOperation",raw)
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
    var directory="res://.runtime/basic-condition-reload"
    DirAccess.make_dir_recursive_absolute(directory)
    var path=directory.path_join("condition.tres");var catalog_path=directory.path_join("catalog.tres")
    var selected:ConditionResource=ResourceLoader.load("res://authoring/presentation/conditions/dodging.tres","",ResourceLoader.CACHE_MODE_IGNORE_DEEP)
    var catalog=CatalogResource.new();catalog.condition_recipes["condition.dodging"]=path
    ResourceSaver.save(catalog,catalog_path);ResourceSaver.save(selected,path)
    var prior=ProjectSettings.get_setting("source_data/presentation_catalog",Catalog.NativeAuthoring.INDEX)
    ProjectSettings.set_setting("source_data/presentation_catalog",catalog_path)
    var cache={};check(Catalog.validate_native(cache).is_empty(),"Valid outline Resource candidate admits")
    var retained=Catalog.source_snapshot(cache)
    for field in ["opacity","period_ms","alpha_threshold","color"]:
        var original=selected.body_outline.get(field)
        selected.body_outline.set(field,Color(NAN,0,0) if field=="color" else (-1 if field=="opacity" else 0))
        ResourceSaver.save(selected,path)
        check(not Catalog.validate_native({}).is_empty(),"Invalid outline candidate rejects "+field)
        check(Catalog.validate_native(retained).is_empty() and Catalog.read_file("catalog/condition_recipes.json",retained)["condition.dodging"].persistent.bodyOutline.color==0x5895e4,"Rejected edit retains admitted source snapshot "+field)
        selected.body_outline.set(field,original)
    ProjectSettings.set_setting("source_data/presentation_catalog",prior)
    DirAccess.remove_absolute(path);DirAccess.remove_absolute(catalog_path)
