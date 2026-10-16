extends SceneTree
## Current approved source operands survive offline Resource admission exactly;
## workers share sources without sharing their mutable lazy-load cache shells.
const Import=preload("res://tools/native_spell_import.gd")
const Spells=preload("res://presentation/native_spell_authoring.gd")
const Sources=preload("res://presentation/native_presentation_sources.gd")
const Catalog=preload("res://source_catalog.gd")
const Variants=preload("res://presentation/native_source_variants.gd")
var checks:int=0
var failures:Array=[]

func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->bool:
    checks+=1
    if not value:failures.append(label);printerr(label)
    return value

func source_operands(value:Variant)->Variant:
    if value is Dictionary:
        var result:Dictionary={}
        for key in value:
            if key not in ["prepared_components","clip_by_id","source_identity","source_resource_paths"]:result[key]=source_operands(value[key])
        return result
    if value is Array:return value.map(source_operands)
    return value

func run()->void:
    var old_cache:Dictionary={};var cache:Dictionary={}
    var source:Dictionary=Import.Authoring.load_data("native_effects/index.json",old_cache)
    var samples:Array=[]
    for id in source.spells:
        var expected:Resource=Import.definition(id,old_cache)
        var loaded:Resource=Sources.find(id,cache)
        if not check(loaded!=null,"Admitted current spell "+id):continue
        check(source_operands(loaded.selection)==Import.select(id,old_cache),"Exact selected source/staging/palette "+id)
        check(source_operands(loaded.recipe)==expected.recipe,"Exact cast/damage treatment "+id)
        check(source_operands(loaded.hit)==source_operands(expected.hit),"Exact receiver material selection "+id)
        var selected:Dictionary=Spells.selection(id,cache)
        check(is_same(selected,loaded.selection),"Warm selection retains the admitted record "+id)
        var baseline:Dictionary=source_operands(selected)
        baseline.clip_by_id={}
        for clip in baseline.clips:baseline.clip_by_id[clip.id]=clip
        var owner={"start":100.0,"prepare":150.0}
        for index in [0,2]:
            var old_phases:Array=Spells.phases(baseline,owner,1000,850,index,true)
            var phases:Array=Spells.phases(selected,owner,1000,850,index,true)
            check(source_operands(phases)==source_operands(old_phases),"Exact event-relative phase operands "+id+"/"+str(index))
        for clip in selected.clips:
            for component in clip.components:
                var admitted:Dictionary=Variants.component_spec(component,clip)
                check(is_same(admitted,clip.prepared_components[component.id]),"Direct component source reference "+id+"/"+component.id)
                check(Variants.path_for(admitted)==Variants.path_for(Import.Variants.component_spec(component,baseline.clip_by_id[clip.id])),"Exact previously baked native variant "+id+"/"+component.id)
        var begin:int=Time.get_ticks_usec()
        for repeat in 1000:Spells.selection(id,cache)
        samples.append({"spell":id,"warm_selection_usec":(Time.get_ticks_usec()-begin)/1000.0})
    check(not cache.has("native_effects/index.json") and not cache.has("sandbox/feedback.json"),"Runtime spell source admission does not read legacy JSON")
    var worker:Dictionary=Catalog.source_snapshot(cache)
    check(is_same(Sources.find("spell.fireball",worker),Sources.find("spell.fireball",cache)),"Independent workers share the same admitted source Resource")
    check(worker[Sources.CACHE_KEY].loaded.is_read_only() and cache[Sources.CACHE_KEY].loaded.is_read_only(),"Workers share immutable admission maps")
    check(Spells.condition("condition.spell.shield",worker).id=="shield","Condition lookup retains its admitted spell owner")
    var displayed:Dictionary={}
    var fireball:Resource=Sources.find("spell.fireball",displayed)
    var future:Dictionary=Catalog.source_snapshot(displayed)
    var shield:Resource=Sources.find("spell.shield",future)
    var ice:Resource=Sources.find("spell.ice_knife",displayed)
    check(not displayed[Sources.CACHE_KEY].loaded.has("spell.shield"),"Worker admission does not mutate displayed source references")
    Catalog.adopt_snapshot(displayed,Catalog.source_snapshot(future))
    check(is_same(Sources.find("spell.shield",displayed),shield),"Publication adopts the worker's already loaded source")
    check(is_same(Sources.find("spell.ice_knife",displayed),ice) and is_same(Sources.find("spell.fireball",displayed),fireball),"Publication retains independently prepared current sources")
    var replacement=Import.Index.new();replacement.revision="different-admitted-revision"
    replacement.spells={};replacement.conditions={}
    Catalog.adopt_snapshot(displayed,{Sources.CACHE_KEY:Sources.make_admission(replacement,{})})
    check(is_same(Sources.find("spell.fireball",displayed),fireball),"Another revision cannot overwrite the displayed source owner")
    for id in ["aid","bless","false_life","sacred_flame"]:check(Spells.selection("spell."+id,cache).is_empty(),"Preserve user deferral "+id)
    var result={"checks":checks,"failures":failures,"warm_lookup_samples":samples,"scope":"All 30 current client-approved spell definitions, phases, receiver treatments and existing baked variants; no native framebuffer or live latency claim."}
    FileAccess.open("res://generated/native_spell_admission_checks.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("NATIVE_SPELL_ADMISSION ",checks," failures=",JSON.stringify(failures))
    quit(0 if failures.is_empty() else 1)
