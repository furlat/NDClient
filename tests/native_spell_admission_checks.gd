extends SceneTree
## The native spell records the game admits are exactly what the abilities
## build makes from the source; workers share sources without sharing their
## mutable lazy-load cache shells.
const Builder=preload("res://tools/presentation_build/abilities.gd")
const Common=preload("res://tools/presentation_build/common.gd")
const Index=preload("res://presentation/resources/native_presentation_catalog.gd")
const Spells=preload("res://presentation/native_spell_authoring.gd")
const Sources=preload("res://presentation/native_presentation_sources.gd")
const Catalog=preload("res://source_catalog.gd")
var checks:int=0
var failures:Array=[]

func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->bool:
    checks+=1
    if not value:failures.append(label);printerr(label)
    return value

func run()->void:
    var cache:Dictionary={}
    var report:Dictionary=Common.report()
    var source:Dictionary=Common.load_root("res://authoring/abilities.tres",report)
    var built:Dictionary=Builder.documents(source.entries)
    var expected_records:Dictionary=built.native.records
    var samples:Array=[]
    check(Sources.admission(cache).index.spells.size()==expected_records.size(),"Every natively staged spell of the source is admitted")
    for id in expected_records:
        var expected:Resource=expected_records[id]
        var loaded:Resource=Sources.find(id,cache)
        if not check(loaded!=null,"Admitted current spell "+id):continue
        check(loaded.selection==expected.selection,"Exact selected staging/palette/lifecycle "+id)
        check(loaded.recipe==expected.recipe,"Exact cast/damage treatment "+id)
        check(loaded.hit==expected.hit,"Exact receiver material selection "+id)
        check(loaded.requirements==expected.requirements,"Exact requirements "+id)
        var selected:Dictionary=Spells.selection(id,cache)
        check(is_same(selected,loaded.selection),"Warm selection retains the admitted record "+id)
        var owner={"start":100.0,"prepare":150.0}
        for index in [0,2]:
            check(Spells.phases(selected,owner,1000,850,index,true)==Spells.phases(expected.selection,owner,1000,850,index,true),"Exact event-relative phase operands "+id+"/"+str(index))
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
    var replacement=Index.new();replacement.revision="different-admitted-revision"
    replacement.spells={};replacement.conditions={}
    Catalog.adopt_snapshot(displayed,{Sources.CACHE_KEY:Sources.make_admission(replacement,{})})
    check(is_same(Sources.find("spell.fireball",displayed),fireball),"Another revision cannot overwrite the displayed source owner")
    for id in ["aid","bless","false_life","sacred_flame"]:check(Spells.selection("spell."+id,cache).is_empty(),"Preserve user deferral "+id)
    var result={"checks":checks,"failures":failures,"warm_lookup_samples":samples,"scope":"Every natively staged spell of the abilities source: definitions, phases, receiver treatments and requirements as built; no native framebuffer or live latency claim."}
    FileAccess.open("res://generated/native_spell_admission_checks.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("NATIVE_SPELL_ADMISSION ",checks," failures=",JSON.stringify(failures))
    quit(0 if failures.is_empty() else 1)
