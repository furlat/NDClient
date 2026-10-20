extends SceneTree
## Production typed assignment on original independent server journals. This
## qualifies ownership/contact compilation, not native pixels or art approval.
const Fixtures=preload("res://tests/recording_fixtures.gd")
const Recording=preload("res://studio/recording.gd")
const Items=preload("res://presentation/native_items.gd")
const Effects=preload("res://presentation/effect_package.gd")
const Journal=preload("res://sdk/journal.gd")
const Compare=preload("res://tests/schema16_fold_vectors_checks.gd")
const POISON_ITEM="4b6990e0-3472-4184-9d53-5f4b1aa7e0b0"
const POISON_OWNER="1e58fadf-8a84-45ff-9fcf-93bebbc510f9"
const POISON_CONTRIBUTION="d97024e9-3c3f-4e26-9027-db6dae8b15ea"
var checks:int=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("WEAPON_DELIVERY_FAIL "+label)
func run()->void:
    for seat in ["amber","blue"]:
        var index:Dictionary=Recording.read(Fixtures.journal("ember-weapon-runtime",seat))
        check(index.ok,"Original "+seat+" journal uses ordinary production assignments")
        if not index.ok:continue
        var held:Array=index.rows.filter(func(row):return row.kind=="native_effect" and row.get("component",{}).get("intrinsic_item_effect",false))
        check(held.size()==1,"Exactly one intrinsic Ember use, "+seat)
        if held.is_empty():continue
        var row:Dictionary=held[0]
        check(row.source=="res://authoring/characters/gear/weapon.roster.ember_longsword.tres::effects/0","Studio points to the production Gear use, "+seat)
        var timeline=Recording.restore(index,row.start_ms+.01)
        var samples:Array=Items.samples(timeline.item_effect_owners,timeline.state,timeline.display_ms)
        check(samples.size()==1,"Real equipped item admits one intrinsic owner, "+seat)
        if samples.size()==1:
            var sample:Dictionary=samples[0]
            check(sample.status=="available" and sample.get("unbound_constructor_inputs",[]).is_empty(),"Corrected delivered receiver leaves the built intrinsic cue available, "+seat)
            check(not sample.has("condition_uuid") and not sample.has("item_effect_uuid"),"Intrinsic decoration invents no condition or temporary membership, "+seat)
            check(timeline.state.items[sample.item_owner_uuid].look.item_id=="weapon.roster.ember_longsword","Decoration belongs to the actual disclosed item, "+seat)
        var end=Recording.restore(index,index.presentation_end_ms)
        check(Items.samples(end.item_effect_owners,end.state,end.display_ms).is_empty(),"Unequip/replacement removes Ember appearance from the held plain sword, "+seat)
        check(end.item_effect_owners==Recording.restore(index,index.presentation_end_ms).item_effect_owners,"Seek/loop preserves exact item ownership clocks, "+seat)
        check(not Fixtures.fact_rows("ember-weapon-runtime","movement",seat).is_empty(),"Original actually moves while equipped, "+seat)
        var contacts:Array=index.rows.filter(func(value):return value.get("component",{}).get("native_weapon_impact",false))
        check(contacts.size()==1,"One Fire contact on the Ember hit; none on plain replacement, "+seat)
        if contacts.size()!=1:continue
        var contact:Dictionary=contacts[0];var component:Dictionary=contact.component
        check(contact.source=="res://authoring/characters/gear/weapon.roster.ember_longsword.tres::impact_effects/0" and component.native_clip.id=="weapons/contact/fire/medium","Finite contact uses its actual production resource, "+seat)
        check(component.weapon_impact.source_item_uuid==row.component.item_owner_uuid and component.weapon_impact.occurrence==component.source_event_uuid,"Accepted event retains exact item and occurrence, "+seat)
        check(not component.has("condition_uuid") and not component.has("item_effect_owner"),"Contact is finite event ownership, "+seat)
        check(is_equal_approx(contact.end_ms-contact.start_ms,Effects.clip("weapons/contact/fire/medium").seconds*1000.0),"Contact preserves its native duration, "+seat)
        for at in [contact.start_ms-.01,lerpf(contact.start_ms,contact.end_ms,.5),contact.end_ms+.01]:
            var restored=Recording.restore(index,at)
            var active:Array=restored.component_samples(index.cache).filter(func(value):return value.get("native_weapon_impact",false))
            check(active.size()==(1 if at>=contact.start_ms and at<contact.end_ms else 0),"Finite contact seek boundary "+str(at)+", "+seat)
    for seat in ["amber","blue"]:poison_original(seat)
    print(JSON.stringify({"checks":checks,"failures":failures,"scope":"Current production Ember and conditional Basic Poison assignments on independent original factions. Exact attack-time effect snapshots, two coated contacts, real natural expiry, clean later Crit/Hit, canonical seek/loop and immutable facts. No native pixels, applied Poison damage, Poisoned condition or user visual approval claimed."}))
    quit(0 if failures.is_empty() else 1)

func poison_original(seat:String)->void:
    var label:String="Basic Poison/"+seat
    var journal:RefCounted=Journal.new()
    var opened:Dictionary=journal.open(Fixtures.journal("poison-weapon-contact",seat),true)
    check(opened.ok,label+": complete original journal independently folds")
    if not opened.ok:return
    var final:Dictionary=journal.snapshot()
    var index:Dictionary=Fixtures.read("poison-weapon-contact",seat)
    check(index.ok,label+": ordinary production source indexes the unchanged original")
    if not index.ok:return
    var immutable:PackedByteArray=var_to_bytes([index.initialization,index.groups,index.rows])
    var held:Array=index.rows.filter(func(row):return row.kind=="native_effect" and row.get("component",{}).get("dynamic_item_effect",false))
    check(held.size()==1,label+": one production coating interval follows actual item-effect membership")
    if held.size()==1:
        var coat:Dictionary=held[0].component
        check(coat.native_clip.id=="weapons/equipped/poison/viscous_film/medium/sustain" \
            and coat.item_owner_uuid==POISON_ITEM and coat.item_effect_uuid==POISON_OWNER \
            and coat.item_effect_member.contribution_uuid==POISON_CONTRIBUTION \
            and held[0].source=="res://authoring/characters/gear/weapon.longsword.tres::effects/0",label+": sustain uses the exact actual item/effect/contribution and production Gear source")
        for at in [held[0].start_ms-.01,held[0].start_ms+.01,held[0].end_ms-.01,held[0].end_ms+.01,held[0].start_ms+.01]:
            var restored:RefCounted=Recording.restore(index,maxf(0.0,at))
            var active:Array=restored.component_samples(index.cache).filter(func(value):return value.get("dynamic_item_effect",false))
            check(active.size()==(1 if at>=held[0].start_ms and at<held[0].end_ms else 0),label+": actual membership controls optical sustain through seek and expiry at "+str(at))
    var attacks:Array=Fixtures.fact_rows("poison-weapon-contact","attack",seat)
    var coated:Array=attacks.filter(func(row):return int(row.sequence) in [12,17])
    var later:Array=attacks.filter(func(row):return int(row.sequence) in [63,68])
    var wanted:Array=["100","145"] if seat=="amber" else ["95","139"]
    check(attacks.size()==6 and coated.size()==2 and later.size()==2,label+": original has before/held/expired attack sequence")
    check(coated.map(func(row):return str(int(row.node.occurrence)))==wanted and coated.all(func(row):return row.fact.attack_outcome=="Hit" \
        and row.fact.source_item_uuid==POISON_ITEM and row.fact.source_item_id=="weapon.longsword" and row.fact.weapon_slot=="MELEE_MAIN" \
        and row.fact.item_effects.size()==1 and row.fact.item_effects[0].effect_uuid==POISON_OWNER \
        and row.fact.item_effects[0].contribution_uuid==POISON_CONTRIBUTION \
        and row.fact.item_effects[0].behavior_id=="condition.consumable.weapon_coat.basic_poison" \
        and row.fact.item_effects[0].damage_type=="Poison"),label+": both actual Hits preserve the exact coated item/effect/contribution UUIDs")
    check(later.map(func(row):return row.fact.attack_outcome)==["Crit","Hit"] and later.all(func(row):return row.fact.source_item_uuid==POISON_ITEM \
        and row.fact.get("item_effects",[]).is_empty()),label+": later real Crit and Hit use the same sword without retired membership")
    var retirement:Array=[]
    for event in Fixtures.fact_rows("poison-weapon-contact","actor_change",seat):
        for actor in event.fact.actors:
            for row in actor.rows:
                if row.field=="item_effects" and row.item_uuid==POISON_ITEM and row.effects.is_empty():retirement.append(event)
    check(retirement.size()==1 and int(retirement[0].sequence)==49 \
        and int(retirement[0].node.occurrence)==(322 if seat=="amber" else 309),label+": natural expiry is the actual ordered empty item-effects row")
    var saves:Array=Fixtures.fact_rows("poison-weapon-contact","saving_throw",seat)
    var damage:Array=Fixtures.fact_rows("poison-weapon-contact","damage",seat)
    check(saves.size()==2 and saves.all(func(row):return row.fact.succeeded) \
        and not damage.any(func(row):return row.fact.get("stage")=="applied" and row.fact.get("damage_type")=="Poison" \
            and float(row.fact.get("applied_damage",0))>0),label+": successful coating saves supply no invented positive Poison damage")
    check(final.actors.values().all(func(actor):return actor.conditions.all(func(member):return member.get("behavior_id")!="condition.poisoned")),label+": contact does not create a Poisoned actor condition")
    var contacts:Array=index.rows.filter(func(row):return row.get("component",{}).get("native_weapon_impact",false) \
        and row.component.native_clip.id=="weapons/contact/poison/medium")
    check(contacts.size()==2 and contacts.map(func(row):return row.component.source_event_uuid)==wanted,label+": exactly two finite contacts, only on the actual coated Hits")
    for contact in contacts:
        var component:Dictionary=contact.component
        var source:Array=coated.filter(func(row):return str(int(row.node.occurrence))==component.source_event_uuid)
        check(source.size()==1,label+": contact is owned by an original attack occurrence")
        if source.size()!=1:continue
        check(contact.source=="res://authoring/characters/gear/weapon.longsword.tres::impact_effects/0" \
            and component.weapon_impact.source_item_uuid==POISON_ITEM \
            and component.native_cue.item_effect_source_item_uuid==POISON_ITEM \
            and Compare.difference(component.native_cue.item_effect_members,source[0].fact.item_effects).is_empty(),label+": finite cue keeps this audience's attack-time values, including nullable duration/provenance and normal SDK integer decoding")
        check(not component.has("condition_uuid") and not component.has("item_effect_owner") \
            and not component.weapon_impact.has("damage_type") \
            and is_equal_approx(contact.end_ms-contact.start_ms,Effects.clip("weapons/contact/poison/medium").seconds*1000.0),label+": finite event clock creates neither a held owner nor a damage verdict")
        var middle:float=lerpf(contact.start_ms,contact.end_ms,.5)
        for at in [middle,contact.start_ms-.01,middle,contact.end_ms+.01,middle]:
            var restored:RefCounted=Recording.restore(index,at)
            var active:Array=restored.component_samples(index.cache).filter(func(row):return row.get("native_weapon_impact",false))
            check(active.size()==(1 if at==middle else 0),label+": ordinary seek/back/loop preserves the finite contact interval")
    # Full operation prefixes preserve canonical equality even when ordered
    # events share one presentation time. Neither test nor replay invents a gap.
    for sequence in [17,49,68]:
        var folded:Dictionary=journal.replay(sequence)
        check(folded.ok,label+": independent canonical prefix "+str(sequence))
        if not folded.ok:continue
        var boundary:int=-1
        for n in index.groups.size():
            if index.groups[n].group.operation_sequence==sequence and index.groups[n].group.operation_end:boundary=n
        check(boundary>=0,label+": actual operation boundary "+str(sequence))
        if boundary<0:continue
        var restored:RefCounted=Recording.restore_boundary(index,boundary,index.groups[boundary].group.commits.size())
        check(restored.state==journal.state,label+": canonical exact seek equals the independent audience prefix "+str(sequence))
        if sequence==17:check(journal.state.items[POISON_ITEM].effects.size()==1 and journal.state.items[POISON_ITEM].effects[0].effect_uuid==POISON_OWNER,label+": genuine held item membership is present before expiry")
        else:check(journal.state.items[POISON_ITEM].effects.is_empty(),label+": actual expired membership stays empty at the later boundary")
    check(Recording.restore(index,index.presentation_end_ms+1000.0).state==final,label+": end seek drains to the original independent canonical state")
    check(var_to_bytes([index.initialization,index.groups,index.rows])==immutable,label+": contact inspection/seek never mutates original source cuts or effect snapshots")
