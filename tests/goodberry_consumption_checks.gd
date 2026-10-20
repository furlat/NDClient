extends SceneTree
## Unchanged legal consumptions, including blocked healing and peer omissions.
const Recording=preload("res://studio/recording.gd")
const Journal=preload("res://sdk/journal.gd")
const Effects=preload("res://presentation/effect_package.gd")
const Constructed=preload("res://presentation/native_constructed_occurrence.gd")
const Operations=preload("res://presentation/operation_results.gd")
const Occurrences=preload("res://presentation/occurrences.gd")
const ROOT="res://tests/fixtures/schema16/scenarios/goodberry-consume"
const CLIP="bg3-36/goodberry/goodberry_eat_native"
const ITEMS=["8a3c72c3-1956-4fc1-9ced-c62fb9299b65","dc58d55a-8eac-4518-b7f5-ac0a1d5f0711","64b6e3a3-6da5-4264-99d1-a89ad6652d0e"]
var checks:int=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("GOODBERRY_CONSUMPTION_FAIL ",label)
func run()->void:
    var phase:Resource=load(Effects.choice(Effects.clip(CLIP)).approaches[0].source_phase)
    var sealed:PackedByteArray=var_to_bytes(phase.to_clip())
    for seat in ["amber","blue"]:
        var directory:String=ROOT.path_join(seat)
        var journal:RefCounted=Journal.new();var opened:Dictionary=journal.open(directory,true)
        var index:Dictionary=Recording.read(directory)
        check(opened.ok and index.ok,seat+": both original canonical fold and ordinary Studio index open")
        if not opened.ok or not index.ok:continue
        var immutable:PackedByteArray=var_to_bytes([index.initialization,index.groups,index.rows])
        var rows:Array=index.rows.filter(func(row):return row.kind=="native_effect" and row.get("component",{}).get("native_cue",{}).get("constructor_input",{}).get("kind")=="item_consumption")
        rows.sort_custom(func(a,b):return a.start_ms<b.start_ms)
        check(rows.size()==3,seat+": exactly three accepted actions produce one finite consumption row each")
        for n in rows.size():
            var row:Dictionary=rows[n];var component:Dictionary=row.component
            if seat=="blue":
                check(component.status=="missing" and component.reason=="item_consumption_charge_not_disclosed" and not component.has("native_constructor_inputs"),seat+": undisclosed charge cannot borrow controlling faction item UUID")
                continue
            check(component.status=="available" and component.ability_id=="action.spell.goodberry.eat" and component.source_event_uuid==str([49,108,161][n]),seat+": exact actual accepted consumption owns the source")
            var evidence:Dictionary=component.native_constructor_evidence
            check(evidence.item_uuid==ITEMS[n] and evidence.actual_healing==[1,0,2][n] and evidence.was_blocked==(n==1),seat+": actual heal/blocked outcome and consumed item stay distinct")
            check(evidence.item_charge_occurrences==[str([43,102,155][n])] and evidence.heal_occurrence==str([48,107,160][n]),seat+": exact independent native charge and heal occurrences are retained")
            var private:Dictionary=Constructed.clip_with_inputs(phase,component.native_constructor_inputs)
            check(private.components[0].input.item_uuids==[ITEMS[n]] and private.components[0].input.healing_admitted==(n!=1),seat+": private source replaces fixture identity and consumes real healing admission")
            check(component.native_cue.live_endpoints==[{"actor":"caster","socket":"hand"},{"actor":"caster","socket":"face"}] and component.target_uuid==component.actor_uuid,seat+": source uses actual consumer hand/face, never creation caster or floor")
            for at in [row.start_ms+250.0,0.0,row.start_ms+250.0]:
                var restored:RefCounted=Recording.restore(index,at)
                check(restored!=null and (at==0.0 or restored.component_samples(index.cache).any(func(sample):return sample.id==component.id)),seat+": ordinary seek/loop restores the exact finite action")
        var end:RefCounted=Recording.restore(index,index.presentation_end_ms+1.0)
        check(end.state==journal.snapshot(),seat+": end equals independently folded original canonical state")
        check(var_to_bytes([index.initialization,index.groups,index.rows])==immutable,seat+": rendering inputs cannot edit source facts")
        # Explicit projection controls reuse the original graph, never replace
        # a server recording or outcome with an invented accepted action.
        if seat=="amber":
            var packet:Dictionary=journal.decode_record(3,FileAccess.get_file_as_bytes(directory.path_join("0000000000000003.json"))).value
            for native in packet.lineages:
                var grouped:Dictionary=Occurrences.group(native);var graph:Dictionary={"nodes":{}}
                for event in grouped.events:graph.nodes[event.lineage_id]=event
                for event in grouped.events:
                    if event.get("fact")==null or event.fact.get("behavior_id")!="action.spell.goodberry.eat" or event.phase!="completion":continue
                    var observed:Dictionary=Operations.item_consumption(event,graph)
                    check(observed.ready,"Actual normalized original ancestry admits one consumed item: "+str(observed.get("reason","ready")))
                    var canceled:Dictionary=event.duplicate();canceled.canceled=true
                    check(not Operations.item_consumption(canceled,graph).ready,"Cancelled action cannot play a review consumption")
                    var no_charge:Dictionary={"nodes":graph.nodes.duplicate()}
                    for key in no_charge.nodes.keys():
                        if no_charge.nodes[key].get("fact")!=null and no_charge.nodes[key].fact.kind=="item_charge":no_charge.nodes.erase(key)
                    check(Operations.item_consumption(event,no_charge).reason=="item_consumption_charge_not_disclosed","Cached inventory or Heal alone cannot invent consumed-item identity")
    check(var_to_bytes(phase.to_clip())==sealed,"Private construction never mutates the sealed Factory source")
    print("GOODBERRY_CONSUMPTION ",JSON.stringify({"checks":checks,"failures":failures,"scope":"Actual three consumed charges and positive/blocked/restored HealFacts, exact accepted action ancestry, canonical seek/loop and own-view identity omissions. No eating body pose, native pixel or user approval claim."}))
    quit(0 if failures.is_empty() else 1)
