extends SceneTree
## Original membership proof plus explicit client-contract after-value controls.
## The existing coating is test staging, not production art or elemental damage.
const Items=preload("res://presentation/native_items.gd")
const Weapons=preload("res://presentation/native_weapon_inputs.gd")
const Placement=preload("res://presentation/spell_placement.gd")
const Support=preload("res://tests/dynamic_weapon_support.gd")
const Builder=preload("res://tools/presentation_build/characters.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
const Recording=preload("res://studio/recording.gd")
const Journal=preload("res://sdk/journal.gd")
const Construction=preload("res://presentation/actor_construction.gd")
const NativeActions=preload("res://presentation/native_action_authoring.gd")
const ITEM="4df65b6b-e8c4-42e6-928d-26e74b579ea1"
const EFFECT="f13a6583-c3c4-42d8-9fb9-eeff69686626"
class State extends RefCounted:
    var state:Dictionary={}
class Playback extends Node:
    var clip:String="Taunt"
    var sample_seconds:float=0.0
class World extends Node3D:
    var timeline:RefCounted=State.new()
    var visual_actors:Dictionary={}
    var rigs:Dictionary={"contract-rig":{"cell_width":128,"cell_height":128,"origin_y_from_ground":32,"facing_rows":{"SW":0},"clips":{"Idle":{"frames":1,"fps":1.0},"Taunt":{"frames":1,"fps":1.0}},"pose_sockets":{"hand":{"Idle":{"SW":[Vector2(72,64)]}}}}}
    var rig_config:Dictionary={"TILE_W":128,"FACING_CYCLE":["SW"]}
    var quarter:int=0
    var playbacks:Dictionary={}
    var camera:Node3D
    var source_images:Dictionary={}
    var catalog_cache:Dictionary={}
var checks:int=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("DYNAMIC_ITEM_EFFECT_FAIL "+label)
func dynamic(samples:Array)->Array:
    return samples.filter(func(sample):return sample.get("dynamic_item_effect",false))
func effect_state(state:Dictionary,members:Array)->Dictionary:
    var result:Dictionary=state.duplicate(false);result.items=state.items.duplicate(false)
    result.items[ITEM]=state.items[ITEM].duplicate(false);result.items[ITEM].effects=members
    return result
func row(before:Array,after:Array,field:String="item_effects")->Dictionary:
    return {"actor_uuid":"","item_uuid":ITEM,"before":before,"after":after,"field":field}
func staged_contracts(state:Dictionary,compiled:Dictionary)->void:
    var original:PackedByteArray=var_to_bytes(state)
    var member:Dictionary=state.items[ITEM].effects[0]
    var owners:Dictionary={}
    Items.observe(owners,state,100.0,compiled,"original-observed-event")
    var samples:Array=Items.samples(owners,state,100.0)
    var observed:Array=dynamic(samples)
    check(samples.size()==3 and observed.size()==2,"Two selected uses and an independent intrinsic use share the real held item")
    if observed.size()!=2:return
    check(observed[0].id!=observed[1].id and observed.all(func(sample):return sample.native_item and not sample.intrinsic_item_effect and sample.item_effect_uuid==EFFECT and sample.item_effect_member==member),"Dynamic IDs combine actual item, authored locator and exact public effect UUID")
    check(observed.all(func(sample):return not sample.has("condition_uuid") and not sample.has("native_constructor_inputs")),"Membership never fabricates an actor condition or source constructor provenance")
    var saved:Dictionary=owners.duplicate(false)
    var duration:Dictionary=member.duplicate(false);duration.duration={"duration_type":"rounds","remaining_rounds":3}
    var timed:Dictionary=effect_state(state,[duration])
    Items.observe(owners,timed,200.0,compiled,"duration-event",[row([member],[duration],"item_effect_duration")])
    check(dynamic(Items.samples(owners,timed,200.0)).all(func(sample):return sample.start_ms==100.0 and sample.item_effect_member==duration),"Duration-only metadata updates preserve both original owner clocks")
    check(saved[observed[0].id].member==member and saved[observed[0].id].start_ms==100.0,"Later membership updates do not mutate earlier owner cuts")
    var holder:String=observed[0].actor_uuid
    var unequipped:Dictionary=timed.duplicate(false);unequipped.actors=timed.actors.duplicate(false)
    unequipped.actors[holder]=timed.actors[holder].duplicate(false)
    unequipped.actors[holder].visual_loadout=timed.actors[holder].visual_loadout.duplicate(false)
    unequipped.actors[holder].visual_loadout.layers=timed.actors[holder].visual_loadout.layers.filter(func(layer):return layer.item_uuid!=ITEM)
    Items.observe(owners,unequipped,250.0,compiled)
    check(Items.samples(owners,unequipped,250.0).is_empty(),"Unequip hides item appearances without substituting the body")
    Items.observe(owners,timed,300.0,compiled)
    check(dynamic(Items.samples(owners,timed,300.0)).all(func(sample):return sample.start_ms==100.0),"Re-equip preserves dynamic membership clocks")
    var unknown:Dictionary=timed.duplicate(false);unknown.actors={}
    Items.observe(owners,unknown,350.0,compiled)
    check(Items.samples(owners,unknown,350.0).is_empty() and owners[observed[0].id].member_present,"Cached item data without disclosed presence hides, rather than inventing removal")
    var from_cache:Dictionary={};Items.observe(from_cache,unknown,350.0,compiled)
    check(from_cache.is_empty(),"Cached item metadata alone cannot admit a new dynamic owner")
    var disclosed:Dictionary={}
    Items.observe(disclosed,unknown,355.0,compiled,"unknown-holder-row",[row([],[duration])])
    check(disclosed.size()==2 and disclosed.values().all(func(owner):return owner.member_present and owner.start_ms==355.0 and owner.location.is_empty()) and Items.samples(disclosed,unknown,355.0).is_empty(),"An explicit unknown-holder row admits only hidden membership and its original clock")
    Items.observe(disclosed,timed,360.0,compiled)
    var shown:Array=dynamic(Items.samples(disclosed,timed,360.0))
    check(shown.size()==2 and shown.all(func(sample):return sample.start_ms==355.0),"Later actual equipment disclosure preserves the explicit unknown-holder membership clock")
    var unseen_transient:Dictionary={}
    Items.observe(unseen_transient,effect_state(unknown,[]),365.0,compiled,"unknown-holder-transient",[row([],[duration]),row([duration],[])])
    var unseen_ended:Array=Items.transient_memberships(unseen_transient,365.0)
    check(unseen_ended.size()==2 and unseen_ended.all(func(owner):return owner.location.is_empty() and owner.member.effect_uuid==EFFECT and owner.start_ms==owner.end_ms and owner.end_event_uuid=="unknown-holder-transient"),"Unknown-holder apply/remove retains exact transient membership without inventing equipment")
    var unseen_history:Dictionary={};var unseen_spans:Array=[]
    Recording._observe_item_history(unseen_history,unseen_spans,unseen_transient,effect_state(unknown,[]),365.0,"1:unknown-holder-transient",compiled)
    check(unseen_spans.size()==2 and unseen_spans.all(func(value):return value.kind=="item_effect_membership" and value.item_uuid==ITEM and value.effect_uuid==EFFECT and value.status=="state_only" and not value.has("component")),"Studio can inspect explicit unknown-holder transients without an optical component")
    Items.observe(owners,timed,400.0,compiled)
    check(dynamic(Items.samples(owners,timed,400.0)).all(func(sample):return sample.start_ms==100.0),"Re-disclosure resumes the same known membership without a new cast")
    # Explicit control on derived public values, not a fabricated wire replay.
    Items.observe(owners,timed,500.0,compiled,"ordered-control",[row([duration],[]),row([],[duration])])
    check(dynamic(Items.samples(owners,timed,500.0)).all(func(sample):return sample.start_ms==500.0),"Remove/reapply inside one original-row boundary restarts the exact dynamic lifetime")
    check(Items.samples(owners,timed,500.0).filter(func(sample):return sample.intrinsic_item_effect).all(func(sample):return sample.start_ms==100.0),"Dynamic removal/reapplication does not restart intrinsic art")
    var other:Dictionary=duration.duplicate(false);other.effect_uuid="contract-other-effect"
    var two:Dictionary=effect_state(timed,[duration,other])
    Items.observe(owners,two,600.0,compiled,"two-members",[row([duration],[duration,other])])
    var doubled:Array=dynamic(Items.samples(owners,two,600.0))
    check(doubled.size()==4 and doubled.filter(func(sample):return sample.item_effect_uuid==EFFECT).all(func(sample):return sample.start_ms==500.0),"Multiple effects on one item get independent per-use owners; existing members keep their clocks")
    Items.observe(owners,timed,700.0,compiled,"remove-other",[row([duration,other],[duration])])
    check(dynamic(Items.samples(owners,timed,700.0)).size()==2,"Removing one effect retires only that effect's two uses")
    var none:Dictionary=effect_state(timed,[])
    Items.observe(owners,none,800.0,compiled,"remove-original",[row([duration],[])])
    check(dynamic(Items.samples(owners,none,800.0)).is_empty() and Items.samples(owners,none,800.0).size()==1,"Whole empty membership removes dynamic decorations while preserving intrinsic art")
    Items.observe(owners,timed,900.0,compiled,"reapply-original",[row([],[duration])])
    check(dynamic(Items.samples(owners,timed,900.0)).all(func(sample):return sample.start_ms==900.0),"An actually removed/reapplied membership cannot resume its previous clock")
    var transient:Dictionary={}
    Items.observe(transient,none,950.0,compiled,"transient-control",[row([],[duration]),row([duration],[])])
    var ended:Array=Items.transient_memberships(transient,950.0)
    check(ended.size()==2 and ended.all(func(owner):return owner.member.effect_uuid==EFFECT and owner.start_ms==owner.end_ms and owner.end_event_uuid=="transient-control"),"Apply/remove retains zero-duration membership and exact removal evidence without a fake draw")
    check(dynamic(Items.samples(transient,none,950.0)).is_empty(),"A transient final-absent effect never becomes a production optical sample")
    var history:Dictionary={};var spans:Array=[]
    Recording._observe_item_history(history,spans,transient,none,950.0,"1:transient-control",compiled)
    var inspections:Array=spans.filter(func(value):return value.kind=="item_effect_membership")
    check(inspections.size()==2 and inspections.all(func(value):return value.item_uuid==ITEM and value.effect_uuid==EFFECT and value.parent=="1:transient-control" and value.member==duration and value.start_ms==950.0 and value.end_ms==950.0),"Studio retains both exact zero-duration memberships under their actual removal event")
    check(inspections.all(func(value):return value.status=="state_only" and not value.has("component") and value.coverage.rendered=="not_witnessed"),"Transient inspection has no invented optical component or framebuffer witness")
    Recording._observe_item_history(history,spans,transient,none,950.0,"1:transient-control",compiled)
    Recording._observe_item_history(history,spans,transient,none,950.0,"1:unrelated-control",compiled)
    check(spans.filter(func(value):return value.kind=="item_effect_membership").size()==2,"Same-commit indexing is idempotent; an unrelated same-clock event cannot relabel or duplicate membership")
    var wrong:Dictionary=member.duplicate(false);wrong.damage_type="Fire"
    var unmatched:Dictionary={};Items.observe(unmatched,effect_state(state,[wrong]),100.0,compiled)
    check(dynamic(Items.samples(unmatched,effect_state(state,[wrong]),100.0)).is_empty(),"Exact typed damage selector cannot select a different public material")
    wrong=member.duplicate(false);wrong.behavior_id="contract.unselected.behavior"
    unmatched={};Items.observe(unmatched,effect_state(state,[wrong]),100.0,compiled)
    check(dynamic(Items.samples(unmatched,effect_state(state,[wrong]),100.0)).is_empty(),"A matching element alone cannot infer a behavior binding")
    check(Items.interested({}, {"items":{ITEM:state.items[ITEM]}},compiled),"An item-only change can admit its first dynamic owner")
    check(var_to_bytes(state)==original,"Original authoritative item/body/effect values remain immutable")
    weapon_binding(state,observed[0])
    retirement(state,compiled)
func retirement(state:Dictionary,compiled:Dictionary)->void:
    var original:PackedByteArray=var_to_bytes(state)
    var member:Dictionary=state.items[ITEM].effects[0]
    var owners:Dictionary={};Items.observe(owners,state,1000.0,compiled,"retirement-base")
    var bounded:bool=true;var same_clock:bool=true;var immutable:bool=true
    var first:Dictionary={}
    for ordinal in 32:
        var added:Dictionary=member.duplicate(false);added.effect_uuid="retirement-contract-"+str(ordinal)
        if ordinal==0:first=added
        var start:float=1001.0+float(ordinal)*2.0
        var during:Dictionary=effect_state(state,[member,added])
        Items.observe(owners,during,start,compiled,"retirement-apply-"+str(ordinal),[row([member],[member,added])])
        Items.observe(owners,state,start+1.0,compiled,"retirement-remove-"+str(ordinal),[row([member,added],[member])])
        var snapshot:Dictionary=owners.duplicate(false)
        Items.samples(owners,state,start+1.0)
        same_clock=same_clock and owners.size()==5
        Items.samples(owners,state,start+1.001)
        bounded=bounded and owners.size()==3 and owners.values().all(func(owner):return owner.start_ms==1000.0)
        immutable=immutable and snapshot.size()==5 and snapshot.values().filter(func(owner):return owner.get("dynamic",false) and not owner.get("member_present",false)).size()==2
    check(same_clock,"Each short-lived effect remains inspectable at its exact removal clock")
    check(bounded,"Thirty-two unique ended memberships retire at later samples; two active uses and intrinsic clock remain bounded")
    check(immutable,"Retiring the live owner table does not erase immutable earlier owner snapshots")
    var reapplied:Dictionary=effect_state(state,[member,first])
    Items.observe(owners,reapplied,2000.0,compiled,"retirement-reapply",[row([member],[member,first])])
    var current:Array=dynamic(Items.samples(owners,reapplied,2000.0))
    check(current.size()==4 and current.filter(func(sample):return sample.item_effect_uuid==first.effect_uuid).all(func(sample):return sample.start_ms==2000.0),"Reapplication after retirement creates the correct new clock for that exact item/effect")
    var unseen:Dictionary=reapplied.duplicate(false);unseen.actors={}
    Items.observe(owners,unseen,2050.0,compiled)
    check(Items.samples(owners,unseen,2090.0).is_empty() and owners.size()==5 and owners.values().filter(func(owner):return owner.get("dynamic",false)).all(func(owner):return owner.member_present),"Later samples retain active but undisclosed memberships without drawing or expiring them")
    Items.observe(owners,reapplied,2091.0,compiled)
    check(dynamic(Items.samples(owners,reapplied,2091.0)).filter(func(sample):return sample.item_effect_uuid==EFFECT).all(func(sample):return sample.start_ms==1000.0),"Re-disclosing active memberships after retirement preserves their original clocks")
    var transient:Dictionary=member.duplicate(false);transient.effect_uuid="retirement-transient-contract"
    Items.observe(owners,reapplied,2100.0,compiled,"retirement-transient",[row([member,first],[member,first,transient]),row([member,first,transient],[member,first])])
    var history:Dictionary={};var spans:Array=[]
    Recording._observe_item_history(history,spans,owners,reapplied,2100.0,"1:retirement-transient",compiled)
    Items.samples(owners,reapplied,2100.0)
    check(Items.transient_memberships(owners,2100.0).size()==2 and spans.filter(func(value):return value.kind=="item_effect_membership").size()==2,"Studio captures same-clock transient membership before its later sample retirement")
    Items.samples(owners,reapplied,2100.001)
    check(owners.size()==5 and Items.transient_memberships(owners,2100.001).is_empty() and spans.filter(func(value):return value.kind=="item_effect_membership").size()==2,"Later sampling releases transient owners while offline inspection keeps its exact records")
    check(var_to_bytes(state)==original,"Repeated retirement leaves original authoritative item and effect data unchanged")
func weapon_binding(state:Dictionary,component:Dictionary)->void:
    var world:World=World.new();root.add_child(world);world.timeline.state=state
    var node:Node3D=Node3D.new();world.add_child(node)
    var holder:String=component.actor_uuid
    world.visual_actors[holder]={"valid":true,"entries":[{"role":"body","node":node,"actor_layer":{"slot":"weapon","item_uuid":ITEM,"effect":{}}}]}
    var result:Dictionary=Weapons.resolve(world,component)
    check(result.ready and result.binding.item_uuid==ITEM and result.binding.holder_uuid==holder and result.binding.effect_uuid==EFFECT,"Native binding carries the real item, current holder and effect UUID")
    check(result.ready and result.binding.binding_origin=="observed_item_effect" and result.binding.contribution_uuid==EFFECT and not result.binding.has("applied_source_event_cursor"),"Actual contribution is preserved; null applied-source provenance remains absent")
    var other:String=state.actors.keys().filter(func(id):return id!=holder)[0]
    var mismatch:Dictionary=component.duplicate(false);mismatch.actor_uuid=other;mismatch.target_uuid=other
    check(not Weapons.resolve(world,mismatch).ready,"A different claimed holder cannot borrow the original actor's weapon surface")
    world.camera=Node3D.new();world.add_child(world.camera)
    var playback:Playback=Playback.new();world.add_child(playback);world.playbacks[holder]=playback
    world.visual_actors[holder].row={"id":holder,"rig":"contract-rig","facing":"SW","position":[0,0],"base_height_steps":0,"scale":1.0}
    var shape:Dictionary=Construction.layer_shape(world.rigs["contract-rig"],128.0/float(world.rig_config.TILE_W))
    var entry:Dictionary=world.visual_actors[holder].entries[0]
    entry.pivot=shape.pivot;entry.scale=shape.scale;node.basis=world.camera.basis;node.position=Placement.Placement.contact(world.visual_actors[holder].row)
    world.visual_actors[holder].entries[0].actor_layer.paths={"Idle":"contract:missing-colour"}
    var unavailable:Dictionary=Placement.endpoints(world,component)
    check(not unavailable.ready and unavailable.get("unavailable",false) and not unavailable.get("pending",false) and unavailable.reason=="native_spell_hand_socket_missing","Missing authored weapon grip is unavailable rather than a fatal program error or substitute anchor")
    playback.clip="Idle"
    var pending:Dictionary=Placement.endpoints(world,component)
    check(not pending.ready and pending.get("pending",false) and not pending.get("unavailable",false) and pending.reason=="native_spell_source_colour_not_prepared","Actual asynchronous socket-source preparation remains pending rather than permanently unavailable")
    world.free()
func replay_callback_checks(index:Dictionary)->void:
    var chosen:Dictionary={}
    for entry in index.groups:
        for local in entry.group.get("actor_source_times",[]):
            var at:float=float(entry.start_ms)+float(local)
            if at<=0.0 or at>=index.presentation_end_ms:continue
            var timeline:RefCounted=Recording.restore(index,at-.001)
            var plan:Dictionary=timeline.replay_plan(at+.001)
            if not plan.boundary or not timeline.replay_prepare(plan):continue
            if timeline.pending_world.world_revision==timeline.world_revision:
                chosen={"timeline":timeline,"plan":plan};break
        if not chosen.is_empty():break
    check(not chosen.is_empty(),"Original recording exposes a genuine source-only replay boundary")
    if not chosen.is_empty():
        var timeline:RefCounted=chosen.timeline;var plan:Dictionary=chosen.plan
        var candidate:Dictionary=timeline.pending_world
        var calls:Array=[]
        timeline.world_published=func(actual):calls.append({"candidate":actual,"clock":timeline.display_ms,"pending_cleared":timeline.pending_world.is_empty()});return true
        check(timeline.replay_publish(plan) and calls.size()==1 and is_same(calls[0].candidate,candidate) and calls[0].clock==plan.display_ms and calls[0].pending_cleared,"Replay transfers its exact prepared source owner once after atomic publication and cancellation")
        check(not timeline.replay_publish(plan) and calls.size()==1,"A consumed replay plan cannot publish its source owner twice")
        timeline.world_published=Callable()
    var world_case:Dictionary={}
    var classifier:RefCounted=Recording.Timeline.new()
    for entry in index.groups:
        for commit in entry.group.commits:
            var at:float=float(entry.start_ms)+float(commit.at_ms)
            if at<=0.0 or not classifier._world_delta(commit.delta):continue
            var timeline:RefCounted=Recording.restore(index,at-.001)
            var plan:Dictionary=timeline.replay_plan(at+.001)
            if not plan.boundary or not timeline.replay_prepare(plan):continue
            if timeline.pending_world.world_revision>timeline.world_revision:
                world_case={"timeline":timeline,"plan":plan};break
        if not world_case.is_empty():break
    check(not world_case.is_empty(),"Original recording exposes a real world-membership replay boundary")
    if not world_case.is_empty():
        var timeline:RefCounted=world_case.timeline;var plan:Dictionary=world_case.plan
        var calls:Array=[];var gate:Dictionary={"ready":false}
        timeline.replay_cancel_preparation()
        timeline.world_ready=func(_candidate):return gate.ready
        timeline.world_published=func(actual):calls.append(actual);return false
        check(not timeline.replay_prepare(plan) and not timeline.replay_publish(plan) and calls.is_empty(),"Unready world candidates cannot publish or call the ownership hook")
        gate.ready=true
        check(timeline.replay_prepare(plan),"The actual world boundary can become ready without changing its plan")
        var candidate:Dictionary=timeline.pending_world
        check(timeline.replay_publish(plan) and calls.size()==1 and is_same(calls[0],candidate),"A world callback returning false preserves successful normal world publication")
        check(not timeline.replay_publish(plan) and calls.size()==1,"A full-world replay plan cannot transfer ownership twice")
    var idle:RefCounted=Recording.restore(index,index.presentation_end_ms)
    var calls:Array=[];idle.world_published=func(candidate):calls.append(candidate);return true
    var plan:Dictionary=idle.replay_plan(index.presentation_end_ms+.01)
    check(not plan.boundary and idle.replay_prepare(plan) and idle.replay_publish(plan) and calls.is_empty(),"A no-boundary replay advance has no prepared owner callback")

func conditional_impact_checks(compiled:Dictionary)->void:
    # Explicit value controls, not a fabricated original replay or poison
    # damage proof. The ordinary coating/hit/removal recording is separate.
    var gear:Resource=load("res://authoring/characters/gear/weapon.longsword.tres")
    check(gear.impact_effects.size()==6 and gear.impact_effects.all(func(cue):return not cue.item_effect_behavior_id.is_empty()),"Plain Longsword has six actual-membership contacts, without inheriting intrinsic Ember Fire")
    var use:Resource=gear.impact_effects[0]
    check(use.clip=="weapons/contact/poison/medium" and use.item_effect_behavior_id=="condition.consumable.weapon_coat.basic_poison" \
        and use.item_effect_damage_type=="Poison" and not use.follow,"Candidate uses exact Basic Poison membership and finite recipient contact")
    var staged:Resource=Support.BodyIndex.new()
    Builder._equipment({"index":staged},{gear.id:gear})
    var index:Resource=compiled[Support.Sources.KEY].index.duplicate(false)
    index.item_impact_effects=staged.item_impact_effects
    var cache:Dictionary={Support.Sources.KEY:{"index":index,"loaded":compiled[Support.Sources.KEY].loaded}}
    var cues:Array=index.item_impact_effects[gear.id]
    check(cues.size()==6 and cues[0].item_effect_behavior_id==use.item_effect_behavior_id \
        and cues[0].item_effect_damage_type=="Poison","Current builder preserves exact membership selectors on finite contact cues")
    var attack:Dictionary={"kind":"attack","behavior_id":"action.attack","source_entity_uuid":"contract-wielder", \
        "target_entity_uuid":"contract-recipient","source_item_id":"weapon.longsword","source_item_uuid":"contract-coated-sword", \
        "weapon_slot":"MELEE_MAIN","attack_source_kind":"equipped","attack_outcome":"Hit","damage_types":["Slashing"]}
    var member:Dictionary={"effect_uuid":"contract-basic-poison-owner","contribution_uuid":"contract-poison-contribution", \
        "behavior_id":"condition.consumable.weapon_coat.basic_poison","damage_type":"Poison", \
        "duration":{"duration_type":"rounds","remaining_rounds":10}}
    check(Items.impact_binding(attack,cache).is_empty(),"Uncoated successful attack cannot borrow poison contact from an item look or damage type")
    attack.item_effects=[member]
    var original:PackedByteArray=var_to_bytes([attack,cues])
    var selected:Dictionary=Items.impact_binding(attack,cache)
    check(selected.get("effect_cues",[]).size()==1 and selected.effect_cues[0].item_effect_members==[member] \
        and selected.effect_cues[0].item_effect_source_item_uuid==attack.source_item_uuid,"Contact keeps its attack-time exact item and all matching public effect evidence")
    check(not selected.effect_cues[0].has("condition_uuid") and not selected.effect_cues[0].has("item_effect_owner") \
        and attack.damage_types==["Slashing"],"Membership-qualified contact invents no condition owner, Poisoned result or applied Poison damage")
    var phases:Array=NativeActions.phases(selected,attack,{}, {},{"event.start":0.0,"body.impact":100.0},cache)
    check(phases.size()==1 and phases[0].native_cue.item_effect_members==[member] \
        and phases[0].native_cue.item_effect_source_item_uuid==attack.source_item_uuid \
        and is_equal_approx(phases[0].start_ms,100.0),"Existing finite phase compiler retains exact member evidence on the authored contact clock")
    var after_retirement:Dictionary=attack.duplicate(false);after_retirement.item_effects=[]
    check(Items.impact_binding(after_retirement,cache).is_empty() and not Items.impact_binding(attack,cache).is_empty(),"A later retired-membership attack has no contact; earlier attack replay retains its own snapshot")
    var critical:Dictionary=attack.duplicate(false);critical.attack_outcome="Crit"
    check(Items.impact_binding(critical,cache).effect_cues.size()==1,"Critical contact remains one authored use, independently of damage amount")
    for outcome in ["Miss","Crit Miss",null]:
        var wrong:Dictionary=attack.duplicate(false);wrong.attack_outcome=outcome
        check(Items.impact_binding(wrong,cache).is_empty(),"Missing or missed contact does not render an admitted coating: "+str(outcome))
    for field in ["behavior_id","damage_type"]:
        var foreign:Dictionary=member.duplicate(false);foreign[field]="contract-other"
        var wrong:Dictionary=attack.duplicate(false);wrong.item_effects=[foreign]
        check(Items.impact_binding(wrong,cache).is_empty(),"Foreign attack-time "+field+" cannot satisfy this authored poison selector")
    for field in ["source_item_uuid","source_item_id"]:
        var missing:Dictionary=attack.duplicate(false);missing.erase(field)
        check(Items.impact_binding(missing,cache).is_empty(),"Exact attack item identity remains required: "+field)
    for kind in ["natural","unarmed"]:
        var wrong:Dictionary=attack.duplicate(false);wrong.attack_source_kind=kind
        check(Items.impact_binding(wrong,cache).is_empty(),"Coating cannot lend a weapon contact to "+kind+" attacks")
    var different_item:Dictionary=attack.duplicate(false);different_item.source_item_id="weapon.roster.ember_longsword"
    check(Items.impact_binding(different_item,cache).is_empty(),"Gear-family look reuse cannot inherit the plain sword's conditional poison cue")
    var other:Dictionary=member.duplicate(false);other.effect_uuid="contract-second-owner";other.contribution_uuid="contract-second-contribution"
    var stacked:Dictionary=attack.duplicate(false);stacked.item_effects=[member,other]
    var stack_binding:Dictionary=Items.impact_binding(stacked,cache)
    check(stack_binding.effect_cues.size()==1 and stack_binding.effect_cues[0].item_effect_members==[member,other],"Multiple matching contributions retain exact evidence without multiplying the authored contact")
    var unconditional:Dictionary=cues[0].duplicate(false)
    unconditional.erase("item_effect_behavior_id");unconditional.erase("item_effect_damage_type")
    unconditional.source_index=1;unconditional.source="test-only-unconditional-contact"
    index.item_impact_effects={gear.id:[cues[0],unconditional]}
    check(Items.impact_binding(after_retirement,cache).effect_cues==[unconditional] \
        and Items.impact_binding(attack,cache).effect_cues.size()==2,"Conditional membership never suppresses a separately authored unconditional contact")
    check(var_to_bytes([attack,cues])==original,"Selecting/compiling contact evidence leaves original facts and shared authored cues immutable")

func run()->void:
    var compiled:Dictionary=Support.cache()
    var fixture:Resource=load("res://tests/fixtures/dynamic_weapon_overlay.tres")
    var cues:Array=Items.definitions(compiled)[fixture.id]
    check(cues.size()==3 and cues[0].item_effect_behavior_id=="item.property.additional_damage" and cues[0].item_effect_damage_type=="Radiant" and not cues[2].has("item_effect_behavior_id"),"Typed selectors compile into the existing item cue index; empty retains intrinsic semantics")
    var report:Dictionary={"errors":[],"warnings":[]}
    Builder._check_item_effect_selector(fixture.effects[0],"test",report)
    check(report.errors.is_empty(),"Explicit public behavior/type selectors pass offline admission")
    var invalid:Resource=fixture.effects[0].duplicate(false);invalid.item_effect_behavior_id=""
    Builder._check_item_effect_selector(invalid,"test",report)
    check(report.errors.size()==1,"Damage-only selection is rejected offline rather than guessed at runtime")
    report.errors=[];Builder._check_item_effect_selector(fixture.effects[0],"test",report,true)
    check(report.errors.is_empty(),"Finite contact may select exact attack-time membership without claiming applied rider damage")
    report.errors=[];Builder._check_item_effect_selector(invalid,"test",report,true)
    check(report.errors.size()==1,"Impact damage-type selector still requires the explicit member behavior")
    conditional_impact_checks(compiled)
    var journal:RefCounted=Journal.new();var opened:Dictionary=journal.open(Fixtures.journal("divine-arm","party"),true)
    check(opened.ok,"Original single-seat Divine Arm journal folds without changing its wire data")
    if opened.ok:
        var state:Dictionary=journal.state
        check(state.items.has(ITEM) and state.items[ITEM].effects.size()==1 and state.items[ITEM].effects[0].effect_uuid==EFFECT and state.items[ITEM].effects[0].damage_type=="Radiant","Original Devotee Mace membership discloses its exact real Radiant effect")
        staged_contracts(state,compiled)
        var index:Dictionary=Recording.read(Fixtures.journal("divine-arm","party"),{},{},compiled)
        check(index.ok,"Studio indexes the same original journal with test-only dynamic staging")
        if index.ok:
            replay_callback_checks(index)
            var timeline:RefCounted=Recording.restore(index,index.presentation_end_ms)
            check(timeline.state==state,"Original Studio endpoint equals independent canonical Journal replay")
            var current:Array=dynamic(Items.samples(timeline.item_effect_owners,timeline.state,timeline.display_ms))
            check(current.size()==2 and current.all(func(sample):return sample.item_effect_uuid==EFFECT and sample.item_owner_uuid==ITEM),"Normal ordered Timeline publication admits both selected uses of the actual effect")
            var restored:RefCounted=Recording.restore(index,index.presentation_end_ms)
            check(restored.item_effect_owners==timeline.item_effect_owners,"Seek/loop rebuild the same observed item lifetimes and clocks")
            restored.component_samples(index.cache)
            var removed_state:Dictionary=effect_state(restored.state,[])
            Items.observe(restored.item_effect_owners,removed_state,restored.display_ms,index.cache,"timeline-retirement-control",[row(restored.state.items[ITEM].effects,[])])
            restored.state=removed_state
            restored.component_samples(index.cache)
            var revision:int=restored.resource_revision
            var count:int=restored.item_effect_owners.size()
            restored.display_ms+=.001;restored.component_samples(index.cache)
            check(restored.item_effect_owners.size()==count-2 and restored.resource_revision==revision+1,"Timeline resource revision observes sample-time dynamic owner retirement exactly once")
            var rows:Array=index.rows.filter(func(value):return value.kind=="native_effect" and value.get("component",{}).get("dynamic_item_effect",false))
            var commits:Dictionary={}
            for entry in index.groups:
                for commit in entry.group.commits:
                    if commit.has("event_uuid"):commits[str(commit.event_uuid)]=float(entry.start_ms)+float(commit.at_ms)
            var spans:Dictionary={}
            for value in rows:
                if not spans.has(value.component.id):spans[value.component.id]=[]
                spans[value.component.id].append(value)
            check(rows.size()==4 and spans.size()==2 and rows.all(func(value):return value.component.item_effect_uuid==EFFECT and value.preview_scope=="actual_item_in_scene"),"Two dynamic uses each expose both real equipped intervals through existing Studio tracks: "+str(rows.map(func(value):return [value.id,value.start_ms,value.end_ms])))
            for owner_spans in spans.values():
                owner_spans.sort_custom(func(a,b):return a.start_ms<b.start_ms)
                check(owner_spans.size()==2 and owner_spans[0].start_ms==commits["237"] and owner_spans[0].end_ms==commits["239"] and owner_spans[1].start_ms==commits["240"],"Studio intervals follow the original equip237→unequip239→equip240 commit boundaries")
                check(owner_spans.all(func(value):return value.component.start_ms==current[0].start_ms),"Original unequip/re-equip intervals retain the same membership source clock")
            var row_ids:Dictionary={}
            for value in index.rows:row_ids[value.id]=value
            var ingress:Array=index.rows.filter(func(value):return value.kind=="event" and value.event.event_uuid=="236")
            check(ingress.size()==1,"Original item-record ingress is retained under its own occurrence")
            if ingress.size()==1:
                var member_rows:Array=ingress[0].get("actor_rows",[]).filter(func(value):return value.get("item_uuid")==ITEM and value.actor_field=="item_effects")
                check(member_rows.size()==1 and member_rows[0].effect_uuids_after==[EFFECT] and member_rows[0].effect_members_after[0].effect_uuid==EFFECT,"Raw SDK item-record before/after identity reaches the original Studio row")
                if member_rows.size()==1:
                    var linked:Array=member_rows[0].inspection_links.filter(func(id):return row_ids[id].kind=="native_effect" and row_ids[id].get("component",{}).get("dynamic_item_effect",false))
                    check(linked.size()==4 and linked.all(func(id):return row_ids[id].component.item_owner_uuid==ITEM and row_ids[id].component.item_effect_uuid==EFFECT),"Dynamic item-record inspection links only the exact real item/effect's selected use spans")
            var linked_events:Dictionary={}
            for event_row in index.rows:
                if event_row.kind!="event":continue
                for actor_row in event_row.get("actor_rows",[]):
                    if actor_row.get("item_uuid")!=ITEM or actor_row.actor_field not in ["inventory","layer"]:continue
                    var uses:Array=rows.filter(func(value):return value.component.actor_uuid==actor_row.actor_uuid)
                    check(uses.size()==4 and uses.all(func(value):return value.id in actor_row.inspection_links),"Actual item/holder actor row links both dynamic uses across all four eligible Studio spans")
                    linked_events[str(event_row.event.event_uuid)]=true
            check(["236","237","240"].all(func(occurrence):return linked_events.has(occurrence)),"Original inventory admission and both positive equips expose their dynamic item bindings in Studio")
    var output:Dictionary={"checks":checks,"failures":failures,"scope":"Original Divine Arm party journal with test-only selected prepared art; exact dynamic membership/ordered owner contracts, authoritative endpoint/Studio/seek. Extra effects, removal/reapply/duration/visibility controls are derived-value contracts, not fabricated server recordings. No GPU output, production art or elemental damage attribution."}
    print(JSON.stringify(output));quit(0 if failures.is_empty() else 1)
