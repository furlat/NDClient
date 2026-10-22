extends SceneTree
## Whole installed package and actual typed spell owners; no backend or GPU fixture.
const Common=preload("res://tools/presentation_build/common.gd")
const Build=preload("res://tools/presentation_build/abilities.gd")
const Records=preload("res://tools/presentation_build/ability_records.gd")
const Spells=preload("res://presentation/native_spell_authoring.gd")
const Effects=preload("res://presentation/effect_package.gd")
const NativeInputs=preload("res://presentation/native_inputs.gd")
var checks=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("HANDOVER_FAIL "+label)
## A deliberate unavailable independent owner is not a successful handover.
## Keep this exact refusal separate from every real delegated output owner.
func arcane_anchor_refusal(condition:Resource,spell:Resource,item_uses:Array)->void:
    check(condition.id=="condition.spell.arcane_sword" and condition.status=="partial" \
        and not condition.play_package_lifecycle and condition.disposition!="state_only" \
        and condition.lifecycle_selections.is_empty() and condition.effects.is_empty() \
        and condition.responses.is_empty() and item_uses.is_empty() \
        and Effects.conditions(condition.id).is_empty(),
        "Arcane Sword's missing independent anchor selects no substitute condition/item/native lifecycle")
    var selected:Dictionary=Records.spell_selection(spell,"arcane_sword",{})
    var cues:Array=selected.get("staging",{}).get("cues",[])
    check(spell.id=="spell.arcane_sword" and Array(spell.excluded_cues)==[0] and cues.size()==1 \
        and Spells.event_cues(selected).is_empty() and Spells.effect_clips(selected).is_empty(),
        "The partial independent blade cue is explicitly excluded rather than falsely handed to the caster condition")
    if cues.size()!=1:return
    var refusal:Dictionary=NativeInputs.new().endpoint_packet(null,{}, {"native_cue":cues[0]}, {}, {})
    check(refusal.rows.is_empty() and refusal.reason=="review_endpoint_position_not_bound",
        "Retained Arcane review coordinates remain unavailable as gameplay blade anchors")

func run()->void:
    var report:Dictionary=Common.report();var source:Dictionary=Common.load_root("res://authoring/abilities.tres",report)
    var entries:Dictionary=source.entries;var package:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/vfx/index.json"))
    var baseline:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/schema16/condition_handover_baseline.json"))
    var body:Dictionary={};var owners:Dictionary={};var families:int=0
    for selection in package.selections:
        var lifecycle:Dictionary=selection.get("condition",{})
        if lifecycle.is_empty():continue
        families+=1
        for owner in lifecycle.get("owner_ids",[]):
            owners[owner]=true
            if lifecycle.get("body_channel_included",false):body[owner]=true
    check(families==155,"All 155 delivered families participate in the same owner policy")
    for owner in owners:
        if owner.begins_with("spatial_effect."):continue
        var condition:Resource=entries.conditions.get(owner)
        check(condition!=null,"Every delivered owner has an explicit typed presentation decision: "+owner)
        if condition==null:continue
        if not condition.play_package_lifecycle:
            var item_uses:Array=entries.contexts.item_attachments.effects.filter(func(use):return use.item_effect_behavior_id==owner)
            if owner=="condition.spell.arcane_sword":arcane_anchor_refusal(condition,entries.spells["spell.arcane_sword"],item_uses)
            else:check(not condition.effects.is_empty() or not condition.responses.is_empty() or (condition.disposition=="state_only" and not item_uses.is_empty()),"Disabled package lifecycle retains its actual authored native/finite/item owner: "+owner)
            if not item_uses.is_empty():check(condition.disposition=="state_only" and condition.effects.is_empty() and condition.look==null,"An item-effect delegate adds no duplicate actor treatment: "+owner)
            for index in condition.responses.size():check(not Effects.for_cue(Records.cue_from_effect(condition.responses[index],index),owner,condition.responses[index].role).is_empty(),"Delegated finite response retains a real selected source: "+owner)

    var migrated:int=0;var candidates:Dictionary={}
    for id in entries.spells:
        var entry:Resource=entries.spells[id]
        if entry.native_staging:candidates[id]=true
        if baseline.existing.has(id):
            var previous:Dictionary=baseline.existing[id]
            var previous_cues:Array=previous.owner_cues.map(func(cue):return int(cue))
            # The saved baseline remains historical. The complete Ensnaring
            # body lifecycle now also owns its former cast-application probe.
            if id=="spell.ensnaring_strike":previous_cues=[0,1,3]
            check(entry.owner_kind==previous.owner_kind and Array(entry.owner_ids)==previous.owner_ids and Array(entry.owner_cues)==previous_cues,"Existing explicit handover and reviewed application correction are preserved: "+id)
        var applicable:Array=[]
        for owner in entry.applies_conditions:
            if body.has(owner):applicable.append(owner)
        var attached:Array=[]
        for index in entry.effects.size():
            var effect:Resource=entry.effects[index]
            if effect.constructor_input.get("kind")=="observed_event":
                check(index not in entry.owner_cues,"Finite actual-event cues retain their occurrence rather than a held condition: "+id+":"+str(index))
                continue
            if effect.role=="attached" and effect.attachment.begins_with("recipient_") and index not in entry.excluded_cues and (not entry.explicit_event_cues or index in entry.event_cues):attached.append(index)
        if entry.delivery=="summon" or not entry.summons.is_empty():
            if id=="spell.flaming_sphere":
                check(entry.owner_kind=="condition" and Array(entry.owner_cues)==[1] \
                    and entry.effects[0].attachment=="caster_ground" and 0 not in entry.excluded_cues,
                    "Actual aura owns only the effect body; finite caster preparation keeps its own event")
            else:check(entry.owner_kind.is_empty(),"Transitive summon rider conditions cannot suppress the summon-creation cast: "+id)
            continue
        if not applicable.is_empty() and not attached.is_empty() and not baseline.existing.has(id):
            migrated+=1
            # A real aura can have a ground owner as well as recipient body
            # members. Both must be publicly applied; body ownership alone is
            # not the complete authored owner set.
            # Finite exact-option/result sources may intentionally retain the
            # event. Only explicitly authored held cues must hand over.
            if not entry.owner_cues.is_empty():
                check(entry.owner_kind=="condition" and Array(entry.owner_ids).all(func(owner):return owner in entry.applies_conditions) and Array(entry.owner_cues).all(func(index):return index in attached),"Declared held cues retain actual applied owners, independent of finite result alternatives: "+id)
            else:check(attached.all(func(index):return entry.effects[index].lifecycle.is_empty()),"Finite receiving cues cannot smuggle an unowned held lifecycle: "+id)
        if entry.owner_kind!="condition":continue
        for owner in entry.owner_ids:
            check(owner in entry.applies_conditions or owner in baseline.existing.get(id,{}).get("owner_ids",[]),"No condition owner was guessed from a spell name: "+id+":"+owner)
        var selected:Dictionary=Records.spell_selection(entry,id.trim_prefix("spell."),{})
        var carried:Array=Spells.owned_cues(selected)
        check(carried==Array(entry.owner_cues) or (carried.is_empty() and Array(entry.owner_ids).all(func(owner):return entries.conditions.has(owner) and not entries.conditions[owner].play_package_lifecycle)),"Actual body channels or explicit item/native delegates determine held-cue suppression: "+id)
        var event_clips:Array=Spells.effect_clips(selected)
        var old_only:Dictionary={}
        for cue in entry.owner_cues:
            check(cue>=0 and cue<entry.effects.size() and entry.effects[cue].role=="attached","Handover leaves cast/projectile/impact/area cues intact: "+id+":"+str(cue))
            old_only[entry.effects[cue].clip]=true
        for index in entry.effects.size():
            if index not in entry.owner_cues:old_only.erase(entry.effects[index].clip)
        check(event_clips.all(func(clip):return not old_only.has(clip.id)),"First-use preparation does not warm superseded body cues: "+id)
    check(migrated>0,"Actual compatible handover candidates are checked without freezing a historical migration count")
    var haste:Resource=entries.spells["spell.haste"]
    check(Array(haste.owner_ids)==["condition.spell.haste"] and Array(haste.owner_cues)==[0,1,2],"Haste has one actual body owner, independent of its later lethargy marker")
    var ownership:Dictionary=Build.condition_owners(entries.spells,entries.conditions,candidates)
    check(not entries.conditions["condition.charmed"].inherit_spell_finish and not ownership.owners.has("condition.charmed"),"Actual Charmed source explicitly keeps its own finish instead of borrowing a spell")
    var altered:Dictionary=entries.conditions.duplicate();var explicit:Resource=altered["condition.charmed"].duplicate()
    explicit.inherit_spell_finish=true;explicit.owner_spell="";altered["condition.charmed"]=explicit
    check(Build.condition_owners(entries.spells,altered,candidates).conflicts.has("condition.charmed"),"An opted-in shared Charmed source refuses an ambiguous first-spell finish")
    explicit.owner_spell="spell.hypnotic_pattern"
    check(Build.condition_owners(entries.spells,altered,candidates).owners.get("condition.charmed")=="spell.hypnotic_pattern","An explicit typed shared-condition owner resolves the controlled ambiguity")
    check(ownership.owners.get("condition.spell.haste")=="spell.haste","Summon transitive capabilities do not steal Haste's owner finish")
    check(report.errors.is_empty(),"Actual typed roots load without errors")
    print(JSON.stringify({"checks":checks,"failures":failures,"families":families,"owners":owners.size(),"new_handovers":migrated,"condition_conflicts":ownership.conflicts}));quit(0 if failures.is_empty() else 1)
