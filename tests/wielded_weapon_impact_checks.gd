extends SceneTree
## Original hit and explicit presentation-contract boundaries; no wire edits.
const Recording=preload("res://studio/recording.gd")
const Support=preload("res://tests/weapon_effect_support.gd")
const Items=preload("res://presentation/native_items.gd")
const Components=preload("res://presentation/components.gd")
const Effects=preload("res://presentation/effect_package.gd")
const Journal=preload("res://sdk/journal.gd")
const Timeline=preload("res://presentation/timeline.gd")
var checks:int=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("WEAPON_IMPACT_FAIL "+label)
func run()->void:
    for faction in ["amber","blue"]:
        var cache:Dictionary=Support.cache(true)
        var index:Dictionary=Recording.read("res://tests/fixtures/schema16/weapon-impact/"+faction,{},{},cache)
        check(index.ok,"Original "+faction+" successful-hit journal indexes")
        if not index.ok:continue
        var rows:Array=index.rows.filter(func(row):return row.get("component",{}).get("native_weapon_impact",false))
        check(rows.size()==1,"One authored impact for the attack, independent of damage/life descendants, "+faction)
        if rows.size()!=1:continue
        var row:Dictionary=rows[0];var component:Dictionary=row.component
        var parent:Array=index.rows.filter(func(value):return value.id==row.parent and value.kind=="event")
        check(parent.size()==1 and parent[0].event.kind=="attack","Studio nests the impact beneath its actual attack, "+faction)
        var fact:Dictionary=attack_fact("res://tests/fixtures/schema16/weapon-impact/"+faction)
        check(component.weapon_impact.source_item_uuid==fact.source_item_uuid and component.weapon_impact.target_entity_uuid==fact.target_entity_uuid and component.weapon_impact.occurrence==component.source_event_uuid,"Impact retains exact event-time item/recipient/occurrence, "+faction)
        var bodies:Array=index.rows.filter(func(value):return value.kind=="body" and value.source_event_uuid==component.source_event_uuid)
        check(bodies.size()==1 and is_equal_approx(row.start_ms,bodies[0].group_start_ms+bodies[0].track.impact_ms),"Impact begins at authored melee contact, "+faction)
        check(row.label=="Weapon impact" and row.source=="res://tests/fixtures/wielded_weapon_impact.tres::impact_effects/0","Studio exposes the exact weapon impact Resource, "+faction)
        check(is_equal_approx(row.end_ms-row.start_ms,Effects.clip("spells/fire_bolt/default/impact").seconds*1000.0),"Finite source has its actual authored lifetime, "+faction)
        check(not component.has("item_effect_owner") and not component.has("condition_uuid"),"Contact uses the attack occurrence, not an invented persistent owner, "+faction)
        for at in [row.start_ms-.001,row.start_ms+20,row.end_ms+.001]:
            var restored=Recording.restore(index,at)
            var active:Array=restored.component_samples(index.cache).filter(func(value):return value.get("native_weapon_impact",false))
            check(active.size()==(1 if at>=row.start_ms and at<row.end_ms else 0),"Seek reconstructs the finite impact interval at "+str(at)+", "+faction)
        var held=Recording.restore(index,row.start_ms+20)
        check(held.state==Recording.restore(index,row.start_ms+20).state,"Loop/seek retains the same canonical state, "+faction)
        var anchored:Array=held.component_samples(index.cache).filter(func(value):return value.id==component.id)
        check(anchored.size()==1 and anchored[0].impact.status=="available" and anchored[0].impact_actor_uuid==fact.target_entity_uuid,"Actual recipient contact stays anchored independently of its later body membership, "+faction)
        check(fact.damage_types==["Slashing"] and not component.weapon_impact.has("damage_type"),"Test fire art does not fabricate elemental damage, "+faction)
        for outcome in ["Miss","Crit Miss",null]:
            var value:Dictionary=fact.duplicate();value.attack_outcome=outcome
            check(Items.impact_binding(value,index.cache).is_empty(),"Contract: miss/unresolved attack has no on-hit impact")
        for kind in ["natural","unarmed"]:
            var value:Dictionary=fact.duplicate();value.attack_source_kind=kind
            check(Items.impact_binding(value,index.cache).is_empty(),"Contract: natural/unarmed attack cannot borrow held weapon impact")
        var unknown:Dictionary=fact.duplicate();unknown.erase("source_item_uuid")
        check(Items.impact_binding(unknown,index.cache).is_empty(),"Contract: absent exact item identity cannot select a weapon impact")
        var immune:Dictionary=fact.duplicate();immune.damage_types=[]
        check(not Items.impact_binding(immune,index.cache).is_empty(),"Contract: successful contact does not require positive damage")
        var critical:Dictionary=fact.duplicate();critical.attack_outcome="Crit"
        check(not Items.impact_binding(critical,index.cache).is_empty(),"Contract: critical contact uses the same authored on-hit arm")
        var canceled_group={"components":[],"actor_tracks":[]}
        var canceled={"id":component.source_event_uuid,"fact":fact,"canceled":true}
        var result:Dictionary=Components.compile(canceled_group,{"events":[canceled]}, {},index.cache)
        check(result.ok and canceled_group.components.is_empty(),"Contract: canceled attacks emit no impact")
    contact_contracts()
    print(JSON.stringify({"checks":checks,"failures":failures,"scope":"Original two-faction hit, exact item/contact/Studio hierarchy, finite seek/loop; explicit miss, cancellation, identity and zero-damage contact contracts. No extra attack/damage or production artwork."}));quit(0 if failures.is_empty() else 1)

func contact_contracts()->void:
    # Small value contracts, separate from the unchanged journals above.
    var attack={"id":"50","fact":{"kind":"attack","target_entity_uuid":"recipient"},"children_lineages":["early","contact","reaction","later"]}
    var graph={"nodes":{
        "early":{"id":"10","fact":{"kind":"actor_change"}},
        "contact":{"id":"20","fact":{"kind":"damage"}},
        "reaction":{"id":"40","fact":{"kind":"attack"},"children_lineages":["nested"]},
        "nested":{"id":"35","fact":{"kind":"damage"}},
        "later":{"id":"45","fact":{"kind":"actor_change"}}},
        "actor_inputs":{},"times":{"10":100.0,"20":100.0,"35":100.0,"40":100.0,"45":200.0,"50":200.0}}
    for id in ["10","20","35","45"]:graph.actor_inputs[id]={"recipient":{"last_visual_position":[4,7],"appearance":{"revision":id}}}
    graph.actor_inputs["50"]={"recipient":{"last_visual_position":null}}
    var selected:Dictionary=Components._attack_impact_actor(attack,graph,100.0)
    check(selected.occurrence=="20" and selected.actor.appearance.revision=="20","Contact keeps newer disclosed appearance, excluding independent nested attacks and later cuts")
    graph.actor_inputs.erase("10");graph.actor_inputs.erase("20")
    check(Components._attack_impact_actor(attack,graph,100.0).is_empty(),"A later-only disclosure or nested attack cannot invent this attack's visible recipient")
    var tracks=[{"actor_uuid":"recipient","start_ms":0.0,"from_position":[4,7],"target_position":[3,7]},
        {"actor_uuid":"recipient","start_ms":200.0,"from_position":[4,7],"target_position":[5,7]},
        {"actor_uuid":"attacker","start_ms":0.0,"from_position":[3,7],"target_position":[4,7]}]
    var direction:Array=Timeline.component_direction({"actor_tracks":tracks},{"start_ms":300.0,"impact_at_ms":100.0,"actor_uuid":"attacker","impact_actor_uuid":"recipient"},{})
    check(direction==[[4,7],[3,7]],"Delayed impact keeps recipient facing at actual contact, not later cue start or attacker facing")

func attack_fact(directory:String)->Dictionary:
    var journal=Journal.new();journal.open(directory,true,false)
    for sequence in 3:
        var decoded:Dictionary=journal.decode_record(sequence,FileAccess.get_file_as_bytes(directory.path_join("%016d.json"%sequence)))
        for lineage in decoded.value.get("lineages",[]):
            for node in lineage.events:
                var fact:Variant=node.get("fact")
                if fact!=null and fact.kind=="attack" and fact.get("attack_outcome") in ["Hit","Crit"]:return fact
    return {}
