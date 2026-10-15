extends SceneTree
const Candidate=preload("res://presentation/characters.gd")
const Recording=preload("res://studio/recording.gd")
const Catalog=preload("res://source_catalog.gd")
const World=preload("res://presentation/world.gd")
var failures:Array=[]
var checks=0
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr(label)
func run()->void:
    var cache:Dictionary={}
    var item_index:Dictionary=Catalog.read_file("items/index.json",cache)
    var visuals:Dictionary=Catalog.read_file(item_index.item_visuals,cache)
    var appearances:Dictionary=Catalog.read_file(item_index.item_appearances,cache)
    var held:PackedByteArray=var_to_bytes([visuals,appearances])
    var requests:Array=[]
    for category in visuals.categories:
        for slot in Candidate.VISUAL_SLOT.values():
            for variant in [null,"missing-variant"]+category.variants.map(func(row):return row.visual_variant_id):
                requests.append({"item":{"visual_item_name":category.base_category,"visual_variant_id":variant},"slot":slot})
    for hand in appearances.hands:requests.append({"item":{"visual_item_name":hand.category,"visual_variant_id":hand.variant},"slot":hand.slot})
    requests.append({"item":{"visual_item_name":"not-an-item","visual_variant_id":null},"slot":"weapon_melee_main"})
    for request in requests:
        var expected:Dictionary=original_equipment(request.item,request.slot,visuals,appearances)
        var actual:Dictionary=Candidate._equipment(request.item,request.slot,visuals,appearances,cache)
        check(actual==expected,"All source item/slot/variant selections preserve exact result/error: "+str(request))
        if actual.ok:check(is_same(actual.value,expected.value),"Selection preserves original source array identity")
    var clone:Dictionary=cache.duplicate()
    var replacement:Dictionary=visuals.duplicate(true)
    replacement.categories[0].mechanical_factory_identity=null
    for request in requests.slice(0,20):
        check(Candidate._equipment(request.item,request.slot,replacement,appearances,clone)==original_equipment(request.item,request.slot,replacement,appearances),"Replaced source document invalidates the private worker shell")
        check(Candidate._equipment(request.item,request.slot,visuals,appearances,cache)==original_equipment(request.item,request.slot,visuals,appearances),"Replacing worker source leaves original catalog owner unchanged")
    var new_hands:Dictionary=appearances.duplicate(true)
    new_hands.hands[0].layers=[]
    var hand:Dictionary=new_hands.hands[0]
    var item={"visual_item_name":hand.category,"visual_variant_id":hand.variant}
    check(Candidate._equipment(item,hand.slot,visuals,new_hands,clone)==original_equipment(item,hand.slot,visuals,new_hands),"Changed hand source invalidates cached override")
    # A shallow source shell may replace its immutable category array on
    # reload. This must not bless a cached directory owned by the old array.
    var source_shell:Dictionary=visuals.duplicate()
    var success:Dictionary={}
    for request in requests:
        if original_equipment(request.item,request.slot,visuals,appearances).ok:success=request;break
    var before_reload:Dictionary=Candidate._equipment(success.item,success.slot,source_shell,appearances,clone)
    source_shell.categories=source_shell.categories.duplicate(true)
    for category in source_shell.categories:
        if category.base_category==success.item.visual_item_name:
            category.mechanical_factory_identity=null;break
    var after_reload:Dictionary=Candidate._equipment(success.item,success.slot,source_shell,appearances,clone)
    check(before_reload.ok and not after_reload.ok and after_reload==original_equipment(success.item,success.slot,source_shell,appearances),"Replacing inner source-array owner invalidates a previously successful selection")
    var ambiguous:Dictionary=visuals.duplicate(true)
    var root_category:Dictionary={}
    for category in ambiguous.categories:
        if category.base_category==success.item.visual_item_name:root_category=category;break
    var actual_bindings:Array=[]
    for category in ambiguous.categories:
        if category.factory_presentation_bindings.any(func(binding):return binding.factory_identity==root_category.mechanical_factory_identity and binding.equipment_slot==success.slot):actual_bindings.append(category)
    if not actual_bindings.is_empty():
        var duplicate:Dictionary=actual_bindings[0].duplicate(true)
        duplicate.base_category="Ambiguous test source";ambiguous.categories.append(duplicate)
        var no_hands={"hands":[]}
        var expected_error:Dictionary=original_equipment(success.item,success.slot,ambiguous,no_hands)
        check(not expected_error.ok and Candidate._equipment(success.item,success.slot,ambiguous,no_hands,clone)==expected_error,"Distinct duplicate factory binding retains the original ambiguity error")
    var snapshot:Dictionary=Catalog.source_snapshot(cache)
    check(not snapshot.has("__equipment_index"),"Source-only worker snapshot excludes derived selector state")
    check(var_to_bytes([visuals,appearances])==held,"Original authoring documents remain byte-identical")
    var spec:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://generated/studio_gallery_spell_case.json"))
    var index:Dictionary=Recording.read(spec.perspectives[0].journal)
    check(index.ok,"Real Gallery journal compiles")
    if not index.ok:quit(1);return
    var state:Dictionary=index.initialization.state.duplicate(true)
    var new_cache:Dictionary=Catalog.source_snapshot(index.cache)
    var recorded_actors:int=0
    for group in index.groups:
        for commit in group.group.commits:Recording.Compiler.apply_delta(state,commit.delta)
        for actor in state.actors.values():
            if not World.visible_actor(actor,state):continue
            var actual:Dictionary=Candidate.resolve(actor,state,new_cache)
            check(actual.ok,"Actual Gallery actor still resolves from admitted authoring")
            if not actual.ok or actual.value==null:continue
            recorded_actors+=1
            if actual.value.rig!="neuroclient.modular":continue
            var expected:Dictionary={}
            for equipped in actor.visual_loadout.layers:
                if not Candidate.VISUAL_SLOT.has(equipped.slot) or equipped.equipped_visual_policy=="hidden":continue
                if Candidate.WEAPON_SET.has(equipped.slot) and Candidate.WEAPON_SET[equipped.slot]!=actor.visual_loadout.active_weapon_set:continue
                var selected:Dictionary=original_equipment(equipped,Candidate.VISUAL_SLOT[equipped.slot],visuals,appearances)
                check(selected.ok,"Original selector admits actual equipped source")
                if not selected.ok:continue
                for layer in selected.value:
                    if layer.render_layer not in Candidate.EFFECT_SLOTS:
                        expected[layer.render_layer]={"slot":layer.render_layer,"category":layer.sprite_key,"tint":int(layer.tint_rgb),"alpha":1.0,"equipment":true,"item_uuid":equipped.item_uuid}
            var gear:Dictionary={}
            for layer in actual.value.equipment_layers:
                if layer.get("equipment",false):gear[layer.slot]=layer
            check(gear==expected,"Actual resolved outfit preserves original category/tint/slot/item-owner across recorded commits")
    check(recorded_actors>100,"Actual recording exercises repeated visible actor selections")
    var report={"checks":checks,"failures":failures,"source_requests":requests.size(),"recorded_groups":index.groups.size(),"recorded_actors":recorded_actors,"scope":"Exact frozen pre-index selection semantics, original source-array identity and unchanged inputs; public actor outfits over real Gallery after-values; source replacement and private worker shell invalidation. No native frame-time or image claim."}
    FileAccess.open("res://.runtime/equipment-selection-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("EQUIPMENT_SELECTION_CHECKS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

# Frozen original selector (before the equipment index), independent of lookup implementation.
func original_error(message:String)->Dictionary:
    return {"ok":false,"error":{"kind":"authoring","message":message,"retryable":false}}
func original_equipment(item: Dictionary, slot: String, visuals: Dictionary, appearances: Dictionary) -> Dictionary:
    var root: Dictionary = {}
    for category in visuals.categories:
        if category.base_category == item.visual_item_name: root = category; break
    if root.is_empty() or root.mechanical_factory_identity == null:
        return original_error("No authored item visual " + item.visual_item_name)
    for hand in appearances.hands:
        if hand.category == item.visual_item_name and hand.variant == item.visual_variant_id and hand.slot == slot:
            return {"ok":true, "value":hand.layers}
    var matches: Array = []
    for category in visuals.categories:
        for binding in category.factory_presentation_bindings:
            if binding.factory_identity == root.mechanical_factory_identity and binding.equipment_slot == slot:
                if not category in matches: matches.append(category)
    if matches.size() != 1: return original_error("No unique authored equipment binding " + item.visual_item_name + "/" + slot)
    var category: Dictionary = matches[0]
    if item.visual_variant_id == null: return {"ok":true, "value":category.base_presentation.equipment_layers}
    for variant in category.variants:
        if variant.visual_variant_id == item.visual_variant_id: return {"ok":true, "value":variant.equipment_layers}
    return original_error("No authored item variant " + item.visual_item_name + "/" + str(item.visual_variant_id) + "/" + slot)
