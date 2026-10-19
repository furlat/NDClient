extends SceneTree
## Typed item authoring -> shared lookup -> actual recorded modular outfits.
const Candidate=preload("res://presentation/characters.gd")
const Sources=preload("res://presentation/body_sources.gd")
const Catalog=preload("res://source_catalog.gd")
const World=preload("res://presentation/world.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
var failures:Array=[]
var checks=0
var gear:Dictionary={}
var first_outfit_difference:Dictionary={}
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr(label)
func layers(values:Array)->Array:
    var result:Array=[]
    for layer in values:
        result.append({"render_layer":layer.slot,"sprite_key":layer.part,"tint_rgb":float(("0x"+layer.tint.trim_prefix("#")).hex_to_int())})
    return result
func expected(item:Dictionary,slot:String)->Dictionary:
    var selected:Resource=gear.get(item.item_id)
    if selected==null:return {"ok":false}
    var root:Resource=selected
    if selected.slots.is_empty() and selected.hands.is_empty():root=gear.get(selected.family)
    if root==null:return {"ok":false}
    var variant:Variant=item.get("visual_variant_id")
    var hand:String="" if variant==null else variant
    if root.hands.get(slot,{}).has(hand):return {"ok":true,"value":layers(root.hands[slot][hand])}
    var look:Dictionary=root.slots.get(slot,{})
    if look.is_empty():return {"ok":false}
    if variant==null:return {"ok":true,"value":layers(look.layers)}
    if look.get("variants",{}).has(variant):return {"ok":true,"value":layers(look.variants[variant])}
    return {"ok":false}
func compare(item:Dictionary,slot:String,cache:Dictionary)->Dictionary:
    var wanted:Dictionary=expected(item,slot)
    var actual:Dictionary=Sources.equipment(item,slot,cache)
    check(actual.ok==wanted.ok,"Typed source availability: "+str([item,slot]))
    if wanted.ok and actual.ok:
        check(actual.value==wanted.value,"Exact authored sprite/tint/slot selection: "+str([item,slot]))
        var index:Resource=Sources.index(cache)
        var key:Array=[index.gear[item.item_id][0],item.get("visual_variant_id"),slot]
        check(is_same(actual.value,index.equipment[key]),"Runtime borrows the admitted immutable layer array")
    elif not actual.ok:check(not actual.error.message.is_empty(),"Unsupported selection explains its missing source")
    return actual
func run()->void:
    var root_source:Resource=load("res://authoring/characters.tres")
    var held:Dictionary={}
    for id in root_source.sections.gear:
        gear[id]=load(root_source.sections.gear[id])
        held[id]=var_to_bytes([gear[id].slots,gear[id].hands])
    var cache:Dictionary={};var requests:int=0;var success:Dictionary={}
    for id in gear:
        var root:Resource=gear[id]
        if root.slots.is_empty() and root.hands.is_empty():root=gear.get(root.family)
        for slot in Candidate.VISUAL_SLOT.values():
            var variants:Array=[null,"missing-variant"]
            if root!=null:
                for variant in root.slots.get(slot,{}).get("variants",{}):
                    if variant not in variants:variants.append(variant)
                for variant in root.hands.get(slot,{}):
                    if not variant.is_empty() and variant not in variants:variants.append(variant)
            for variant in variants:
                var item={"item_id":id,"visual_variant_id":variant}
                var actual:Dictionary=compare(item,slot,cache);requests+=1
                if success.is_empty() and actual.ok:success={"item":item,"slot":slot,"value":actual.value}
    compare({"item_id":"not-an-item","visual_variant_id":null},"weapon_melee_main",cache)
    check(not success.is_empty(),"Real typed equipment selections exercised")
    if not success.is_empty():
        var worker:Dictionary=Catalog.source_snapshot(cache)
        check(is_same(Sources.equipment(success.item,success.slot,worker).value,success.value),"Preparation workers share the exact physical source")
        var admission:Dictionary=cache[Sources.KEY]
        var replacement:Resource=admission.index.duplicate(true)
        var key:Array=[replacement.gear[success.item.item_id][0],success.item.visual_variant_id,success.slot]
        replacement.equipment[key]=[]
        worker[Sources.KEY]={"index":replacement,"loaded":admission.loaded}
        check(Sources.equipment(success.item,success.slot,worker).value.is_empty(),"A replaced source revision takes effect in its private worker shell")
        check(is_same(Sources.equipment(success.item,success.slot,cache).value,success.value),"Replacing a worker's revision leaves the original source intact")
        replacement.equipment.erase(key);replacement.equipment_errors[key]="Deliberate missing authored selection"
        check(not Sources.equipment(success.item,success.slot,worker).ok,"A removed binding cannot retain the prior successful lookup")
    for id in gear:check(held[id]==var_to_bytes([gear[id].slots,gear[id].hands]),"Source remains unchanged: "+id)
    var recording:Dictionary=Fixtures.read("gallery")
    check(recording.ok,"Original current-schema Gallery compiles")
    if not recording.ok:quit(1);return
    var state:Dictionary=recording.initialization.state.duplicate(true)
    var new_cache:Dictionary=Catalog.source_snapshot(recording.cache);var actors:int=0
    for group in recording.groups:
        for commit in group.group.commits:Fixtures.Recording.Compiler.apply_delta(state,commit.delta)
        for actor in state.actors.values():
            if not World.visible_actor(actor,state):continue
            var resolved:Dictionary=Candidate.resolve(actor,state,new_cache)
            check(resolved.ok,"Actual Gallery actor resolves from admitted authoring")
            if not resolved.ok or resolved.value==null or resolved.value.rig!="neuroclient.modular":continue
            actors+=1
            var wanted:Dictionary={}
            for equipped in actor.visual_loadout.layers:
                var item:Dictionary=equipped.duplicate();item.merge(state.items.get(equipped.item_uuid,{}).get("look",{}),true)
                if not Candidate.VISUAL_SLOT.has(item.slot) or item.get("equipped_visual_policy")=="hidden":continue
                if Candidate.WEAPON_SET.has(item.slot) and Candidate.WEAPON_SET[item.slot]!=actor.visual_loadout.active_weapon_set:continue
                var selection:Dictionary=expected(item,Candidate.VISUAL_SLOT[item.slot])
                check(selection.ok,"Typed authoring independently admits recorded equipment")
                if not selection.ok:continue
                for layer in selection.value:
                    if layer.render_layer not in Candidate.EFFECT_SLOTS:
                        wanted[layer.render_layer]={"slot":layer.render_layer,"category":layer.sprite_key,"tint":int(layer.tint_rgb),"alpha":1.0,"equipment":true,"item_uuid":equipped.item_uuid}
            var actual:Dictionary={}
            for layer in resolved.value.equipment_layers:
                if layer.get("equipment",false):
                    var value:Dictionary=layer.duplicate();value.erase("source_path");actual[layer.slot]=value
            if actual!=wanted and first_outfit_difference.is_empty():
                first_outfit_difference={"actor":actor.uuid,"actual":actual,"expected":wanted}
                print("FIRST_OUTFIT_DIFFERENCE ",JSON.stringify(first_outfit_difference))
            check(actual==wanted,"Actual outfit retains exact sprite/tint/slot/item owner")
    check(actors>100,"Repeated recorded visible outfits exercised")
    print("EQUIPMENT_SELECTION_CHECKS ",JSON.stringify({"checks":checks,"failures":failures,"source_requests":requests,"recorded_actors":actors,"scope":"Independent typed Gear selection, exhaustive item/slot/variant boundaries, immutable Resource sharing/replacement and actual Gallery outfit parity."}))
    quit(0 if failures.is_empty() else 1)
