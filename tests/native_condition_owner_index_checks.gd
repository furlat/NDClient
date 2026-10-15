extends SceneTree
const Spells=preload("res://presentation/native_spell_authoring.gd")
const Catalog=preload("res://source_catalog.gd")
var checks:int=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr(label)
func scan(id:String,cache:Dictionary)->Dictionary:
    var source:Dictionary=Spells.Authoring.load_data("native_effects/index.json",cache)
    for key in source.get("spells",{}):
        var lifecycle:Dictionary=source.spells[key].get("lifecycle",{})
        if lifecycle.get("owner_kind")=="condition" and id in lifecycle.get("owner_ids",[]):return Spells.selection(key,cache)
    return {}
func run()->void:
    var cache:Dictionary={}
    var source:Dictionary=Spells.Authoring.load_data("native_effects/index.json",cache)
    var before:Dictionary=source.duplicate(true)
    var names:Array=Spells.Authoring.load_data("catalog/condition_recipes.json",cache).keys()
    for entry in source.spells.values():names.append_array(entry.get("lifecycle",{}).get("owner_ids",[]))
    names.append("condition.not_authored")
    for id in names:
        check(Spells.condition(id,cache)==scan(id,cache),"Original selection for "+id)
    var worker:Dictionary=Catalog.source_snapshot(cache)
    check(not worker.has("__native_spell_owners"),"Worker starts without a shared derived cache")
    check(Spells.condition("condition.spell.shield",worker)==Spells.condition("condition.spell.shield",cache),"Worker independently resolves the admitted source")
    check(not is_same(worker.__native_spell_owners,cache.__native_spell_owners),"Derived owner indices are private to worker shells")
    var duplicate:Dictionary=source.duplicate(true)
    var shield:Dictionary=duplicate.spells["spell.shield"]
    var armor:Dictionary=duplicate.spells["spell.mage_armor"]
    armor.lifecycle.owner_ids=shield.lifecycle.owner_ids.duplicate()
    duplicate.spells={"spell.shield":shield,"spell.mage_armor":armor}
    cache["native_effects/index.json"]=duplicate
    check(Spells.condition("condition.spell.shield",cache)==scan("condition.spell.shield",cache),"Duplicate owners retain original first match")
    var held:Dictionary=cache.__native_spell_owners
    duplicate=duplicate.duplicate(true)
    duplicate.spells={"spell.mage_armor":armor,"spell.shield":shield}
    cache["native_effects/index.json"]=duplicate
    check(Spells.condition("condition.spell.shield",cache).id=="mage_armor","Reloaded order replaces the previous derived index")
    check(held.conditions["condition.spell.shield"]=="spell.shield","Previously published index remains immutable")
    cache["native_effects/index.json"]={"spells":{}}
    check(Spells.condition("condition.spell.shield",cache).is_empty(),"Reload removing an owner cannot return stale selection")
    check(Spells.condition("condition.spell.shield",worker).id=="shield","Private reload cannot alter another admitted worker")
    check(source==before,"Original source is unchanged")
    print("NATIVE_CONDITION_OWNER_INDEX ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
