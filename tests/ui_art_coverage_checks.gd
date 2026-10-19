extends SceneTree
## Shipping HUD maps must retain exact typed owners and every installed assignment.
const Common=preload("res://tools/presentation_build/common.gd")
const Build=preload("res://tools/presentation_build/abilities.gd")
const Coverage=preload("res://tools/ui_art_coverage.gd")
const UI=preload("res://presentation/ui_catalog.gd")
const Library=preload("res://studio/case_library.gd")
var checks=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("UI_ART_FAIL "+label)
func run()->void:
    var report:Dictionary=Common.report()
    var source:Dictionary=Common.load_root("res://authoring/abilities.tres",report)
    var abilities:Dictionary=source.entries
    var characters:Dictionary=Common.load_root("res://authoring/characters.tres",report).entries
    var ids:Dictionary=Common.server_ids().ids
    var built:Dictionary=Build.icons(abilities)
    check(built["spell.false_life"].path==abilities.spells["spell.false_life"].icon.path,"Actual False Life spell icon survives its legacy condition alias")
    check(built["spell.false_life"].path!=abilities.conditions["spell.false_life"].icon.path,"A different lifecycle image cannot overwrite a spell owner")
    var changed:Dictionary=abilities.duplicate();changed.conditions=abilities.conditions.duplicate()
    var alias:Resource=abilities.conditions["spell.false_life"].duplicate();alias.icon=alias.icon.duplicate();alias.icon.status="ready";alias.icon.path="not-the-spell.png";changed.conditions["spell.false_life"]=alias
    check(Build.icons(changed)["spell.false_life"].path==abilities.spells["spell.false_life"].icon.path,"Typed identity ownership still wins when the wrong-domain alias claims ready")
    var maps:Dictionary=UI.icon_maps()
    var inventory:Dictionary=Coverage.inventory(abilities,characters,ids,maps)
    check(report.errors.is_empty() and inventory.errors.is_empty(),"Every current native UI assignment resolves through the actual shipping HUD maps")
    var declared:Dictionary=Library.declared(source.root)
    for kind in inventory.icons:
        for id in declared.get(kind,{}):
            var row:Dictionary=inventory.icons[kind].get(id,{})
            check(not row.is_empty() and row.authoring==declared[kind][id].source_path,"Every Studio capability retains its canonical typed UI requirement: "+id)
    for id in abilities.conditions:
        if not str(id).begins_with("class_feature.") or abilities.actions.has(id):continue
        var row:Dictionary=inventory.icons.class_feature.get(id,{})
        var image:Resource=abilities.conditions[id].icon
        check(not row.is_empty() and row.exists and row.built_matches and row.status==image.status,
            "Lifecycle-only feature retains its actual supplied artwork and status: "+id)
        if image.reuses=="condition.generic":check(row.art=="placeholder" and row.status=="stand_in","Generic lifecycle artwork remains explicitly incomplete: "+id)
    check(inventory.icons.class_feature["class_feature.barbarian.reckless_attacking"].authoring==abilities.actions["class_feature.barbarian.reckless_attacking"].resource_path,
        "A class-feature lifecycle alias cannot overwrite its canonical action artwork")
    for id in abilities.actions:
        var entry:Resource=abilities.actions[id]
        var row:Dictionary=inventory.icons[entry.kind][id]
        check(row.exists and row.built_matches,"Typed capability remains visible even when absent from the static server catalog: "+id)
        check((row.availability=="server_id")==ids.get(entry.kind,{}).has(id),"Typed-only capability does not claim static server availability: "+id)
    for id in ["action.class.fighter.action_surge","action.class.fighter.second_wind","action.class.sorcerer.quickened_spell","action.class.sorcerer.twinned_spell"]:
        check(inventory.icons.action[id].art=="assigned","Existing exact class action artwork is assigned: "+id)
    for id in ids.spell:
        var row:Dictionary=inventory.icons.spell[id]
        check(row.exists and row.built_matches,"Current spell image is shipped: "+id)
        check(row.status=="ready" or row.owner_status=="internal","Non-internal spell has assigned artwork: "+id)
        if row.status=="ready":check(row.size==[48,48],"Spell icon retains its delivered 48px image: "+id)
    for id in ids.creature:
        var row:Dictionary=inventory.portraits[id]
        check(row.exists and row.built_matches and row.size==[192,256],"Current character's full portrait is shipped: "+id)
        var actor:Dictionary={"creature_content_ref":"content.test:creature:"+id+"@1"}
        check(UI.portrait_key(actor,{},{},{"player_ui":{"maps":maps}})==row.portrait,"Native ContentRef selects the character's actual portrait: "+id)
    for kind in ["action","reaction","class_feature","trait","feat","condition"]:
        for id in ids[kind]:
            var row:Dictionary=inventory.icons[kind][id]
            check(row.exists and row.built_matches,"Current UI capability has a readable explicit assignment: "+id)
            if row.art=="placeholder":check(row.status=="stand_in","A generic placeholder cannot pretend to be completed art: "+id)
    for id in inventory.player_portraits:
        var row:Dictionary=inventory.player_portraits[id]
        check(row.exists and row.built_matches and row.size==[192,256],"Selectable player portrait retains its full image: "+id)
    print(JSON.stringify({"checks":checks,"failures":failures,"summary":inventory.summary}));quit(0 if failures.is_empty() else 1)
