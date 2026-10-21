extends SceneTree
## Actual item looks resolve through the existing modular weapon sheets.
## Attached fire/enchantment VFX remain separate and are not qualified here.
const Sources=preload("res://presentation/body_sources.gd")
const Builder=preload("res://tools/presentation_build/characters.gd")
const BodyIndex=preload("res://presentation/resources/body_source_index.gd")
const Characters=preload("res://presentation/characters.gd")
const Items=preload("res://presentation/native_items.gd")
const Journal=preload("res://sdk/journal.gd")
const Effects=preload("res://presentation/effect_package.gd")
const Equipment=preload("res://tests/weapon_effect_support.gd")
var checks:int=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("WIELDED_WEAPON_SHEET_FAIL "+label)
func run()->void:
    var cache:Dictionary={}
    var index=Sources.index(cache)
    check(index!=null,"Current built character index loads")
    if index==null:quit(1);return
    for spec in [["weapon.flame_blade","weapon.scimitar","Melee4","Offhand1"],
                 ["weapon.devotees_mace","weapon.mace","Melee9","Offhand2"]]:
        var gear=load("res://authoring/characters/gear/"+spec[0]+".tres")
        check(gear.family==spec[1],spec[0]+": authored sheet family replaces no body")
        if spec[0]=="weapon.flame_blade":
            check(gear.effects.size()==1 and index.item_effects[spec[0]][0].clip=="weapons/equipped/fire/blade_tongues/medium/sustain",spec[0]+": explicit modular fire decoration keeps the existing Scimitar body")
            check(gear.effects.all(func(use):return "created_item_binding" not in Effects.clip(use.clip).get("inputs",[])),spec[0]+": no excluded native weapon-body source is selected")
        else:
            check(gear.effects.size()==1 and index.item_effects[spec[0]][0].clip=="weapons/equipped/radiant/solar_bevel/medium/sustain",spec[0]+": explicit current main-hand candidate keeps the same modular sheet")
        for hand in [["weapon_melee_main",spec[2],"weapon"],["weapon_melee_off",spec[3],"offhand"]]:
            var selected:Dictionary=Sources.equipment({"item_id":spec[0],"visual_variant_id":null},hand[0],cache)
            check(selected.ok and selected.get("value",[]).any(func(layer):return layer.sprite_key==hand[1] and layer.render_layer==hand[2]),
                spec[0]+": actual "+hand[0]+" uses the existing separate weapon sheet")
            check(not selected.get("value",[]).is_empty(),spec[0]+": equipment keeps its sprite body")
    compiled_overlay()
    for seat in ["amber","blue"]:
        var journal=Journal.new()
        var opened:Dictionary=journal.open("res://tests/fixtures/schema16/created-flame-blade/"+seat,true,true)
        check(opened.ok,seat+": original created-item journal reduces")
        if not opened.ok:continue
        var found:bool=false
        for actor in journal.state.actors.values():
            var real_item:String=""
            for equipped in actor.visual_loadout.layers:
                if equipped.item_id=="weapon.flame_blade":real_item=equipped.item_uuid
            if real_item.is_empty():continue
            found=true
            var resolved:Dictionary=Characters.structure(actor,cache,Characters.item_looks(actor,journal.state))
            check(resolved.ok,seat+": actual recorded outfit resolves")
            if resolved.ok:
                check(resolved.value.equipment_layers.any(func(layer):return layer.get("item_uuid")==real_item and layer.slot=="weapon" and layer.category=="Melee4"),
                    seat+": original real item UUID stays attached to the Scimitar sheet")
        check(found,seat+": original journal contains the actually equipped Flame Blade")
        var owners:Dictionary={}
        Items.observe(owners,journal.state,0.0,cache)
        var samples:Array=Items.samples(owners,journal.state,0.0)
        check(owners.size()==1 and samples.size()==1,seat+": exactly one decoration follows the actual equipped item")
        if samples.size()==1:
            var sample:Dictionary=samples[0]
            check(journal.state.items[sample.item_owner_uuid].look.item_id=="weapon.flame_blade" and sample.intrinsic_item_effect \
                and not sample.has("condition_uuid") and not sample.has("item_effect_uuid") \
                and "created_item_binding" not in sample.native_clip.get("inputs",[]),seat+": decoration retains actual item UUID without native-body provenance or invented membership")
    print(JSON.stringify({"checks":checks,"failures":failures,"scope":"Built main/offhand modular sheet selection and both original faction item UUIDs; attached VFX, native pixels and full-character weapon registration are not qualified."}))
    quit(0 if failures.is_empty() else 1)

func compiled_overlay()->void:
    var fixture=load("res://tests/fixtures/wielded_weapon_overlay.tres")
    var scimitar=load("res://authoring/characters/gear/weapon.scimitar.tres")
    var built=BodyIndex.new()
    Equipment.equipment(built,{fixture.id:fixture,scimitar.id:scimitar})
    var cues:Array=built.item_effects.get(fixture.id,[])
    check(cues.size()==2,"Typed item decorations compile into distinct ordered cues")
    if cues.is_empty():return
    check(cues[0].clip==fixture.effects[0].clip and cues[0].attachment=="recipient_weapon" and cues[0].follow,
        "Native source and attachment fields survive the shared typed conversion")
    check(cues[0].source==fixture.resource_path+"::effects/0" and cues[0].source_index==0,
        "Compiled decoration retains its exact authored resource and ordinal")
    check(cues[0].recipient_slots==["weapon"] and cues[0].entity_geometry=={"actor":"recipient","slots":["weapon"]} and cues[0].equipment_slots==["weapon_melee_main"],
        "Optical receiver and equipment-slot inputs survive compilation")
    var sample_cache:Dictionary={Sources.KEY:{"index":built,"loaded":{}}}
    var selected:Dictionary=Sources.equipment({"item_id":fixture.id,"visual_variant_id":null},"weapon_melee_main",sample_cache)
    check(selected.ok and selected.value.any(func(layer):return layer.sprite_key=="Melee4"),
        "Adding an actual delivered coating keeps the Scimitar sprite sheet")
