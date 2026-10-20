extends SceneTree
## Original independent faction journals prove the creation join. The small
## counterfactuals below exercise consumed-value policy, never new wire facts.
const Creation=preload("res://presentation/creation_inputs.gd")
const Conditions=preload("res://presentation/conditions.gd")
const Journal=preload("res://sdk/journal.gd")
const Compiler=preload("res://presentation/compiler.gd")
const Occurrences=preload("res://presentation/occurrences.gd")
const Authoring=preload("res://presentation/authoring.gd")
const Build=preload("res://tools/presentation_build/abilities.gd")
const CONDITION="condition.spell.flame_blade"
const SOURCE="res://authoring/abilities/conditions/condition.spell.flame_blade.tres"
const ROOT="res://tests/fixtures/schema16/created-flame-blade"
var checks:int=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("CREATED_ITEM_IDENTITY_FAIL "+label)
func run()->void:
    var resource:Resource=load(SOURCE)
    check(resource.creation_source_id=="spell.flame_blade" and resource.creation_item_id=="weapon.flame_blade","Typed source declares the actual creation source and ordinary item kind")
    var built:Dictionary=Build.documents({"conditions":{CONDITION:resource}},{"conditions":{CONDITION:SOURCE}})
    var recipe:Dictionary=built.docs["catalog/condition_recipes.json"][CONDITION]
    check(recipe.persistent.creationIdentity=={"source_behavior_id":"spell.flame_blade","item_id":"weapon.flame_blade"},"Typed fields export the exact shared source descriptor")
    for seat in ["amber","blue"]:read_case(seat,recipe)
    print(JSON.stringify({"checks":checks,"failures":failures,"scope":"Original two-seat cast/condition/item/equip prefixes plus explicit immutable-value policy controls; Amber creation ancestry is positive, Blue unparented equipment is unavailable; no native pixels or weapon body replacement claimed."}))
    quit(0 if failures.is_empty() else 1)

func read_case(seat:String,recipe:Dictionary)->void:
    var directory:String=ROOT.path_join(seat)
    var journal:RefCounted=Journal.new()
    var opened:Dictionary=journal.open(directory,true,false)
    check(opened.ok,seat+" original journal opens read-only")
    if not opened.ok:return
    var cache:Dictionary={}
    var recipes:Dictionary=Authoring.load_data("catalog/condition_recipes.json",cache).duplicate(false)
    recipes[CONDITION]=recipe;cache["catalog/condition_recipes.json"]=recipes
    var owners:Dictionary={};var witnessed:int=0
    var files:PackedStringArray=DirAccess.get_files_at(directory);files.sort()
    for file in files:
        if not file.ends_with(".json") or not file.get_basename().is_valid_int():continue
        var sequence:int=int(file.get_basename())
        var raw:PackedByteArray=FileAccess.get_file_as_bytes(directory.path_join(file))
        var decoded:Dictionary=journal.decode_record(sequence,raw)
        check(decoded.ok,seat+" actual packet decodes "+str(sequence))
        if not decoded.ok:return
        var before:Dictionary=journal.state
        var folded:Dictionary=journal._consume_admitted(decoded.value,raw,true)
        check(folded.ok,seat+" actual packet reduces "+str(sequence))
        if not folded.ok:return
        if sequence==0:
            Conditions.observe(owners,journal.state.actors,0.0,true);continue
        var original:PackedByteArray=var_to_bytes(folded.normalized)
        var compiled:Dictionary=Compiler.compile_recorded(before,folded.normalized,cache,journal.state,folded.transitions)
        check(compiled.ok,seat+" actual packet compiles "+str(sequence))
        if not compiled.ok:return
        var presented:Dictionary=Compiler.Reducer._retained_target(before)
        for index in folded.normalized.lineages.size():
            var group:Dictionary=compiled.value.groups[index]
            var lineage:Dictionary=Occurrences.group(folded.normalized.lineages[index])
            var graph:Dictionary={"nodes":{},"actor_inputs":{},"condition_cues":{}}
            for node in lineage.events:graph.nodes[node.lineage_id]=node
            var captures:Array=folded.transitions.lineages[index].events
            for row in captures:
                var event:String=str(row.event_uuid)
                graph.actor_inputs[event]=row.actor_inputs
                graph.condition_cues[event]=[]
                for change in row.get("condition_rows",[]):
                    if change.row.get("field")!="condition" or change.after==null or change.before!=null:continue
                    graph.condition_cues[event].append({"actor_uuid":change.actor_uuid,"condition":change.after,
                        "phase":"application","recipe":recipe if change.after.behavior_id==CONDITION else {}})
            var projected:Dictionary=Creation.lifetime_bindings(lineage.events,graph,group.commits)
            for commit in group.commits:
                var expected:Dictionary=projected.get(str(commit.get("event_uuid","")),{})
                check(commit.get("creation_bindings",{})==expected,seat+" compiler preserves the independent native join at its own commit "+str(commit.get("event_uuid","trailing")))
                Compiler.apply_delta(presented,commit.delta)
                var changed:bool=Conditions.observe(owners,commit.delta.get("actors",{}),float(commit.at_ms),false,
                    commit.get("condition_rows",[]),{},commit.get("creation_bindings",{}))
                for condition in expected:
                    witnessed+=1
                    var binding:Dictionary=expected[condition]
                    check(changed,seat+" new binding metadata changes the existing resource owner revision")
                    check(not Conditions.observe(owners,{},float(commit.at_ms),false,[],{},{condition:binding}),seat+" unchanged binding metadata does not repeat resource invalidation")
                    check(owners.has(condition) and owners[condition].creation_binding==binding,seat+" ordinary owner retains the exact published binding/gap")
                    if seat=="blue":
                        check(not binding.ready and binding.reason=="creation_item_ancestry_not_disclosed",seat+" visible unparented item does not borrow Amber inventory/creation lineage")
                        continue
                    check(binding.ready,seat+" actual same-cast lifetime and inventory admissions bind")
                    if not binding.ready:continue
                    var identity:Dictionary=binding.identity
                    check(identity=={"created_item_uuid":"d581a8b1-8878-4765-ae96-0d882c6310fc",
                        "lifetime_condition_uuid":"6d9deee5-15e6-48bb-9ab2-4f6ccec060e8","caster_uuid":"885464ab-168d-486f-8b85-09689c3b4d3b"},seat+" identity consists solely of original public UUIDs")
                    check(commit.event_uuid==binding.evidence.item_occurrence and binding.evidence.condition_occurrence!=commit.event_uuid,
                        seat+" created identity publishes on inventory admission, after the condition's own earlier cut")
                    check(binding.evidence.source_lineage!=binding.evidence.item_lineage and not binding.evidence.item_native_parent.is_empty(),seat+" actual cast/item lineage and earlier native parent remain independent")
                    var owner:Dictionary=owners[condition]
                    check(owner.start_ms<=float(commit.at_ms),seat+" binding preserves the earlier lifetime owner's clock")
                    var samples:Array=Conditions.native_samples(owners.duplicate(),float(commit.at_ms),cache)
                    check(samples.any(func(sample):return sample.get("condition_uuid")==condition and sample.get("creation_binding",{})==binding),seat+" existing native condition samples forward the original binding "+JSON.stringify({"lifecycles":Conditions.NativePersistent.lifecycles(owner.condition).size(),"samples":samples.map(func(sample):return {"kind":sample.kind,"owner":sample.get("condition_uuid"),"binding":sample.get("creation_binding",{})})}))
                    check(not presented.actors[identity.caster_uuid].visual_loadout.layers.any(func(layer):return layer.item_uuid==identity.created_item_uuid),seat+" inventory admission has not published the later equipped layer")
            if not projected.is_empty() and seat=="amber":negative_controls(lineage,graph,group,owners,presented,cache,seat)
        check(var_to_bytes(folded.normalized)==original and FileAccess.get_file_as_bytes(directory.path_join(file))==raw,seat+" projection/compiler preserve original native packets")
    check(witnessed==1,seat+" exactly one actual lifetime binding or explicit public gap is retained")

func negative_controls(lineage:Dictionary,graph:Dictionary,group:Dictionary,owners:Dictionary,state:Dictionary,cache:Dictionary,seat:String)->void:
    var condition:String="6d9deee5-15e6-48bb-9ab2-4f6ccec060e8"
    var bound:Dictionary=owners[condition].creation_binding
    var caster:String=bound.identity.caster_uuid
    var component:Dictionary={"condition_uuid":condition,"creation_binding":bound}
    var weapon:Dictionary={"ready":true,"binding":{"item_uuid":bound.identity.created_item_uuid,"holder_uuid":caster,"item_id":"weapon.flame_blade"}}
    var packet:Dictionary=Creation.lifetime_packet(component,state,weapon)
    check(packet.ready and packet.identity==bound.identity and packet.weapon.lifetime_present and packet.weapon.item_in_caster_holdings,seat+" exact present lifetime and actual equipped item supply identity/weapon operands")
    var foreign:Dictionary=weapon.duplicate(true);foreign.binding.item_uuid="unit-foreign-item"
    check(not Creation.lifetime_packet(component,state,foreign).ready,seat+" counterfactual foreign current item cannot receive the original lifetime")
    foreign=weapon.duplicate(true);foreign.binding.holder_uuid="unit-foreign-holder"
    check(not Creation.lifetime_packet(component,state,foreign).ready,seat+" counterfactual transferred item cannot borrow the caster's lifetime")
    check(not Creation.lifetime_packet(component,state,{"ready":false,"reason":"not_displayed"}).ready,seat+" undisplayed geometry cannot activate created-item effects")
    var no_identity:Dictionary=component.duplicate(false);no_identity.erase("creation_binding")
    check(not Creation.lifetime_packet(no_identity,state,weapon).ready,seat+" an initial/unobserved lifetime cannot invent creation identity")
    var copied:Dictionary=graph.duplicate(true)
    for node in copied.nodes.values():
        if node.get("fact")!=null and node.fact.get("behavior_id")=="spell.flame_blade":node.canceled=true
    var missing:Dictionary=Creation.lifetime_bindings(lineage.events,copied,group.commits)
    check(missing.values().all(func(bindings):return bindings.values().all(func(value):return not value.ready)),seat+" canceled-source value control cannot produce a creation binding")
    copied=graph.duplicate(true)
    for node in copied.nodes.values():
        if node.get("fact")!=null and node.fact.get("behavior_id")=="spell.flame_blade":node.phase="execution"
    missing=Creation.lifetime_bindings(lineage.events,copied,group.commits)
    check(missing.values().all(func(bindings):return bindings.values().all(func(value):return not value.ready)),seat+" requested/uncompleted-source value control is not completion evidence")
    copied=graph.duplicate(true);copied.actor_inputs={}
    missing=Creation.lifetime_bindings(lineage.events,copied,group.commits)
    check(missing.values().all(func(bindings):return bindings.values().all(func(value):return not value.ready)),seat+" cached ItemRecord without actual controlled inventory before-value proves no creation")
    var before_owner:Dictionary=owners[condition]
    var retired:Dictionary=state.duplicate(false);retired.actors=state.actors.duplicate(false)
    retired.actors[caster]=state.actors[caster].duplicate(false)
    retired.actors[caster].conditions=state.actors[caster].conditions.filter(func(member):return member.condition_uuid!=condition)
    check(not Creation.lifetime_packet(component,retired,weapon).ready,seat+" consumed-value lifetime removal hides the original identity without creating an activation")
    var local:Dictionary=owners.duplicate(true)
    Conditions.observe(local,{caster:retired.actors[caster]},1000.0)
    check(not is_inf(local[condition].end_ms) and local[condition].creation_binding==bound,seat+" retirement preserves original identity but ends its existing UUID owner")
    Conditions.observe(local,{},1001.0,false,[],{},{condition:bound})
    check(local[condition].end_ms==1000.0,seat+" late creation metadata never revives an ended condition")
    check(before_owner==owners[condition] and is_inf(owners[condition].end_ms),seat+" retirement controls preserve the actual earlier owner")
