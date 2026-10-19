extends SceneTree
const Support=preload("res://tests/weapon_effect_support.gd")
const Recording=preload("res://studio/recording.gd")
const Items=preload("res://presentation/native_items.gd")
const ITEM="d581a8b1-8878-4765-ae96-0d882c6310fc"
var checks:int=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("WEAPON_EFFECT_FAIL "+label)
func run()->void:
    for faction in ["amber","blue"]:
        var index:Dictionary=Recording.read("res://tests/fixtures/schema16/created-flame-blade/"+faction,{},{},Support.cache())
        check(index.ok,"Original "+faction+" journal indexes with test-only typed decorations")
        if not index.ok:continue
        var rows:Array=index.rows.filter(func(row):return row.kind=="native_effect" and row.get("component",{}).get("intrinsic_item_effect",false))
        check(rows.size()==2,"Studio retains both distinct attached uses on one actual item, "+faction)
        check(index.rows.filter(func(row):return row.kind=="native_material" and row.get("component",{}).get("intrinsic_item_effect",false)).size()==2,"Each use exposes its actual weapon surface track, "+faction)
        if rows.size()!=2:continue
        check(rows[0].component.id!=rows[1].component.id and rows.all(func(row):return row.component.item_owner_uuid==ITEM and row.source.begins_with("res://tests/fixtures/wielded_weapon_overlay.tres::effects/")),"Item plus actual authored locator identifies each use, "+faction)
        var preparations:Array=[]
        for group in index.groups:
            preparations.append_array(group.group.native_requirements.filter(func(row):return row.get("intrinsic_item_effect",false)))
        check(preparations.size()>=2,"Both uses are included in ahead-of-publication resource preparation, "+faction)
        var first=Recording.restore(index,rows[0].start_ms-.001)
        check(Items.samples(first.item_effect_owners,first.state,first.display_ms).is_empty(),"No decoration before actual equipment admission, "+faction)
        var held=Recording.restore(index,index.presentation_end_ms)
        var samples:Array=Items.samples(held.item_effect_owners,held.state,held.display_ms)
        check(samples.size()==2 and samples.all(func(sample):return not sample.has("condition_uuid") and not sample.has("native_constructor_inputs")),"Ordinary held decorations require no fake condition, creation UUID or cast ancestry, "+faction)
        var again=Recording.restore(index,index.presentation_end_ms)
        check(again.item_effect_owners==held.item_effect_owners,"Seek/loop reconstructs the same real admission and private owner clocks, "+faction)
        if samples.size()!=2:continue
        var actor:String=samples[0].actor_uuid
        check(Items.interested({}, {"set":{"senses":held.state.senses}},held.appearance_cache),"A sensory-only reveal can admit an already-known weapon effect, "+faction)
        var cut:Dictionary=held.state.duplicate();cut.actors=held.state.actors.duplicate()
        cut.actors[actor]=held.state.actors[actor].duplicate(true)
        cut.actors[actor].visual_loadout.layers=cut.actors[actor].visual_loadout.layers.filter(func(layer):return layer.item_uuid!=ITEM)
        var owners:Dictionary=held.item_effect_owners.duplicate()
        Items.observe(owners,cut,held.display_ms+1,held.appearance_cache)
        check(Items.samples(owners,cut,held.display_ms+1).is_empty(),"Contract: unequip retires both decorations without changing the item body, "+faction)
        check(Items.samples(held.item_effect_owners,held.state,held.display_ms).size()==2,"Later membership does not mutate earlier owner cuts, "+faction)
        Items.observe(owners,held.state,held.display_ms+2,held.appearance_cache)
        var resumed:Array=Items.samples(owners,held.state,held.display_ms+2)
        check(resumed.size()==2 and resumed[0].start_ms==samples[0].start_ms,"Contract: re-equip resumes existing item clocks without inventing a new cast, "+faction)
    print(JSON.stringify({"checks":checks,"failures":failures,"scope":"Original two-faction equipment admission, two test-authored native uses and Studio receiver rows, seek/loop; explicit unequip/re-equip value-contract cuts. No new server event, production artwork or full-character weapon attachment."}));quit(0 if failures.is_empty() else 1)
