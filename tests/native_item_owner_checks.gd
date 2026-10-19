extends SceneTree
## Actual recorded creation/equip rows, plus finite membership contract cuts.
const Journal=preload("res://sdk/journal.gd")
const Compiler=preload("res://presentation/compiler.gd")
const Timeline=preload("res://presentation/timeline.gd")
const Items=preload("res://presentation/native_items.gd")
const Sockets=preload("res://presentation/spell_placement.gd")
const Native=preload("res://presentation/native_spell_renderer.gd")
const Recording=preload("res://studio/recording.gd")
const ITEM="d581a8b1-8878-4765-ae96-0d882c6310fc"
class EmptyWorld extends Node:
    var visual_actors:Dictionary={}
    var timeline:RefCounted
var checks:int=0
var failures:Array=[]
var evidence:Array=[]
var actual:Dictionary={}
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("NATIVE_ITEM_OWNER_FAIL "+label)
func run()->void:
    for seat in ["amber","blue"]:inspect(seat)
    if not actual.is_empty():membership_cuts()
    retention_and_registration()
    print(JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
    quit(0 if failures.is_empty() else 1)
func inspect(seat:String)->void:
    var directory:String="res://tests/fixtures/schema16/created-flame-blade/"+seat
    var journal=Journal.new();var opened:Dictionary=journal.open(directory,true,false)
    check(opened.ok,seat+": original journal opens")
    if not opened.ok:return
    var timeline=Timeline.new();var cache:Dictionary={};var requirements:Array=[]
    var origins:Array=[];var tracked:bool=false
    for sequence in 9:
        var raw:PackedByteArray=FileAccess.get_file_as_bytes(directory.path_join("%016d.json"%sequence))
        var decoded:Dictionary=journal.decode_record(sequence,raw)
        check(decoded.ok,seat+": original packet decodes "+str(sequence))
        if not decoded.ok:return
        var before:Dictionary=journal.state
        var folded:Dictionary=journal._consume_admitted(decoded.value,raw,true)
        check(folded.ok,seat+": original packet folds "+str(sequence))
        if not folded.ok:return
        if sequence==0:
            timeline.accept({"kind":"initialization","state":journal.state,"sequence":0});continue
        var compiled:Dictionary=Compiler.compile_recorded(before,folded.normalized,cache,journal.state,folded.transitions)
        check(compiled.ok,seat+": production compiler "+str(sequence))
        if not compiled.ok:return
        for group in compiled.value.groups:
            for event in group.events:
                if event.components.any(func(component):return component.id=="item:"+ITEM+":appearance"):tracked=true
            for commit in group.commits:origins.append_array(commit.get("item_appearance_origins",[]))
            for row in group.get("native_requirements",[]):
                if row.get("native_item",false):requirements.append(row)
        timeline.accept({"kind":"operation","groups":compiled.value.groups})
        timeline.advance(10000.0)
        check(timeline.state==journal.state,seat+": displayed canonical state equals fold "+str(sequence))
    var indexed:Dictionary=Recording.read(directory)
    check(indexed.ok,seat+": shared Studio index opens actual item journal")
    if indexed.ok:
        var tracks:Array=indexed.rows.filter(func(row):return row.get("component",{}).get("native_item",false))
        check(tracks.size()==1,seat+": one native item appearance track exposes the real interval")
        for row in tracks:
            check(row.status==("available" if seat=="amber" else "missing"),seat+": Studio preserves independent origin coverage")
        var replay=Recording.restore(indexed,indexed.presentation_end_ms)
        check(replay.item_appearance_owners.keys()==timeline.item_appearance_owners.keys(),seat+": restored replay has exact item owners")
    var samples:Array=timeline.component_samples(cache).filter(func(row):return row.get("native_item",false))
    check(samples.size()==1,seat+": one exact current held native item")
    check(requirements.size()>=1,seat+": same-clock equip creates an early preparation requirement")
    if samples.is_empty():return
    var sample:Dictionary=samples[0]
    check(sample.item_owner_uuid==ITEM,seat+": actual created item UUID is retained")
    if seat=="amber":
        check(tracked,"Actual created item renderer is registered in the original event trace")
        check(origins.size()==1 and sample.status=="available",seat+": observed creation supplies one native origin")
        check(sample.native_constructor_inputs[0].values.created_item_uuid==ITEM,seat+": constructor uses actual item identity")
        check(not sample.item_origin.lifetime_condition_uuid.is_empty() and Items.lifetime_present(sample.item_origin,timeline.state),seat+": actual condition UUID owns lifetime")
        actual={"owners":timeline.item_appearance_owners.duplicate(true),"state":timeline.state.duplicate(true),"sample":sample,"cache":cache}
    else:
        check(origins.is_empty(),seat+": private inventory admission is not borrowed from Amber")
        check(sample.status=="missing" and sample.reason=="created_item_origin_not_observed",seat+": undisclosed creation provenance remains an explicit gap")
        check(not sample.has("native_constructor_inputs"),seat+": no successful constructor receives invented identities")
    evidence.append({"seat":seat,"origins":origins.size(),"requirements":requirements.size(),"sample_status":sample.status})
func membership_cuts()->void:
    var owners:Dictionary=actual.owners;var state:Dictionary=actual.state;var cache:Dictionary=actual.cache
    var creator:String=owners[ITEM].creator_uuid
    var original_owner:Dictionary=owners[ITEM]
    var before:Dictionary=state.actors[creator].duplicate(true)
    state.actors[creator].visual_loadout.layers=state.actors[creator].visual_loadout.layers.filter(func(layer):return layer.item_uuid!=ITEM)
    check(Items.observe(owners,state,100.0,[],cache),"Unequipping changes the exact owner membership")
    check(Items.samples(owners,state,100.0).is_empty(),"Inventory holdings retain provenance without drawing a weapon")
    check(original_owner.membership!=owners[ITEM].membership,"Earlier owner cuts remain immutable")
    state.actors[creator]=before
    check(Items.observe(owners,state,100.0,[],cache),"Same-clock equip changes the owner membership")
    check(Items.samples(owners,state,100.0).size()==1,"Re-equip restores only the actual item")
    state.actors[creator].conditions=state.actors[creator].conditions.filter(func(condition):return condition.condition_uuid!=owners[ITEM].lifetime_condition_uuid)
    check(Items.observe(owners,state,100.0,[],cache),"Same-clock lifetime removal changes eligibility")
    check(Items.samples(owners,state,100.0).is_empty(),"Lifetime removal hides actual Flame Blade")
    var ground={"actors":{},"items":{},"objects":{"ground-item":{"item":{"item_id":"weapon.devotees_mace"},"placement":{"position":[2,3],"base_height_steps":2}}},"object_members":{"ground-item":true},"senses":{"objects":{"ground-item":{"visual":true}}}}
    var unknown:Dictionary={}
    Items.observe(unknown,ground,0.0,[],cache)
    var rows:Array=Items.samples(unknown,ground,0.0)
    check(rows.size()==1 and rows[0].reason=="created_item_origin_not_observed","Ground-only native item needs no cached inventory record to expose its origin gap")
    var stale:Dictionary=before.duplicate(true);stale.uuid="stale-former-holder";stale.present=true
    ground.actors[stale.uuid]=stale;ground.audience={"controlled":[]};ground.senses.entities={}
    check(Items.membership(ITEM,ground).get("kind")!="held","Cached unseen former holder cannot publish current held membership")
    var visible:Dictionary=stale.duplicate(true);visible.uuid="visible-holder"
    ground.actors[visible.uuid]=visible;ground.senses.entities[visible.uuid]={"visual":true}
    check(Items.membership(ITEM,ground).get("holder_uuid")==visible.uuid,"Current visible holder wins over stale cached former holder")
    ground.senses.entities[stale.uuid]={"visual":true}
    check(Items.membership(ITEM,ground).get("kind")=="ambiguous","Two actual observed holders report ambiguity instead of dictionary-first selection")
    ground.actors={}
    ground.object_members={}
    check(Items.observe(unknown,ground,1.0,[],cache) and Items.samples(unknown,ground,1.0).is_empty(),"Lost ground membership hides appearance while cached look remains")

func retention_and_registration()->void:
    var world=EmptyWorld.new()
    var unbound:Dictionary=Sockets.endpoints(world,{"native_cue":{"role":"attached","attachment":"item"}})
    check(not unbound.ready and unbound.reason=="native_item_registration_not_bound","Ordinary item-attached spell cues retain their explicit unsupported registration")
    world.timeline=Timeline.new()
    var component={"id":"future-item","kind":"native_effect","native_spell":true,"item_owner_uuid":"received-item"}
    world.timeline.current={"id":"pending-equip","native_requirements":[component]}
    var renderer=Native.new();renderer.handles[component.id]={"component":component}
    check(renderer._queued_ids(world).has(component.id),"Already prepared native item survives its queued requirement before owner publication")
    world.free()
