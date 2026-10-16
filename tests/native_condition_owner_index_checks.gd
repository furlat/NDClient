extends SceneTree
## Condition ownership follows the admitted native source revision. A reload
## must not alter the source bindings retained by another replay/reducer.
const Spells=preload("res://presentation/native_spell_authoring.gd")
const Sources=preload("res://presentation/native_presentation_sources.gd")
const Index=preload("res://presentation/resources/native_presentation_catalog.gd")
const Catalog=preload("res://source_catalog.gd")
var checks:int=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr(label)
func run()->void:
    var cache:Dictionary={}
    var source:Resource=Sources.admission(cache).index
    for condition_id in source.conditions:
        var expected:Dictionary=Spells.selection(source.conditions[condition_id],cache)
        check(Spells.condition(condition_id,cache)==expected,"Admitted source owner for "+condition_id)
    check(Spells.condition("condition.not_authored",cache).is_empty(),"Unregistered condition stays explicitly unimplemented")
    var worker:Dictionary=Catalog.source_snapshot(cache)
    check(Spells.condition("condition.spell.shield",worker).id=="shield","Worker retains original admitted owner")
    var revised=Index.new();revised.spells=source.spells.duplicate();revised.conditions=source.conditions.duplicate()
    revised.conditions["condition.spell.shield"]="spell.mage_armor"
    cache[Sources.CACHE_KEY]={"index":revised,"loaded":{}}
    check(Spells.condition("condition.spell.shield",cache).id=="mage_armor","New admitted revision selects its new owner")
    check(Spells.condition("condition.spell.shield",worker).id=="shield","Existing worker keeps its original source after reload")
    var removed=Index.new();removed.spells=revised.spells;removed.conditions={}
    cache[Sources.CACHE_KEY]={"index":removed,"loaded":{}}
    check(Spells.condition("condition.spell.shield",cache).is_empty(),"New revision can remove an owner")
    check(Spells.condition("condition.spell.shield",worker).id=="shield","Removing owner cannot alter retained replay source")
    check(source.conditions["condition.spell.shield"]=="spell.shield","Original admitted catalog remains unchanged")
    print("NATIVE_CONDITION_OWNER_INDEX ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
