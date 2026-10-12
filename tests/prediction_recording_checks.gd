extends SceneTree
# Canonical playback remains identical with or without a speculative overlay.
# Gameplay outcomes come only from admitted recordings. Separate named choice
# fixtures test the finite prefix adapter; they are not new gameplay captures.
const Journal=preload("res://sdk/journal.gd")
const Reducer=preload("res://sdk/reducer.gd")
const Compiler=preload("res://presentation/compiler.gd")
const Timeline=preload("res://presentation/timeline.gd")
const Prediction=preload("res://presentation/prediction.gd")
const Recipes=preload("res://presentation/prediction_recipes.gd")
const Tracks=preload("res://presentation/tracks.gd")
const Authoring=preload("res://presentation/authoring.gd")
var checks=0
var failures=[]
var cache={}
var evidence={"recorded_packets":0,"own_commands":0,"canonical_frames":0,"handoffs":0,"corrections":0,"oa":0,"uncommitted_edges":0,"life":0,"recipe_prefixes":0}
var fixture={}
var base="C:/Users/tommaso/AppData/Local/Temp/ndclient-presentation-"
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);print("PREDICTION_RECORDING_FAIL ",label)
func read_data(path:String)->Dictionary:
    var decoded=Journal.Protocol.parse_json(FileAccess.get_file_as_bytes(path))
    check(decoded.ok,path+" parses exactly")
    return decoded.value if decoded.ok else {}
func _initialize()->void:run.call_deferred()
func aligned(a:RefCounted,b:RefCounted,label:String)->void:
    check(a.state==b.state and a.sequence==b.sequence and a.display_ms==b.display_ms,label+" canonical values and clock unchanged by overlay")
    check(a.trace.rows==b.trace.rows and a.trace.order==b.trace.order and a.trace.logs==b.trace.logs,label+" authoritative hierarchy/logs unchanged")
func first_track(groups:Array,actor:String)->Dictionary:
    for group in groups:
        for track in group.actor_tracks:
            if track.actor_uuid==actor and (track.get("motion",false) or track.priority==20):return track
    return {}
func receipt(cursor:Dictionary,number:int,kind:String)->Dictionary:
    var value=cursor.duplicate();value.erase("sequence");value.command_number=number;value.kind=kind
    if kind=="committed":value.cursor=cursor.duplicate()
    return value
func recording(name:String)->void:
    var directory=base+name+"/amber/journal"
    var source=read_data(base+name+"/presentation-result.json")
    if source.is_empty():return
    check(source.ok,"Native "+name+" capture succeeded")
    var command:Dictionary=source.evidence.command
    var journal=Journal.new();check(journal.open(directory,true,false).ok,"Actual "+name+" historical protocol")
    var actual=Timeline.new();var twin=Timeline.new()
    var files=DirAccess.get_files_at(directory);files.sort()
    for file in files:
        if file.length()!=21 or not file.ends_with(".json"):continue
        var root_name="InitializationResponse" if actual.state.is_empty() else "PlayerOperation"
        var decoded=journal.protocol.decode(root_name,FileAccess.get_file_as_bytes(directory.path_join(file)))
        check(decoded.ok,name+" source packet admitted")
        if not decoded.ok:return
        var packet:Dictionary=journal.protocol.normalize(root_name,decoded.value)
        evidence.recorded_packets+=1
        if root_name=="InitializationResponse":
            var initial=Reducer.reduce_initialization(packet.initialization,packet.content_additions)
            check(initial.ok,name+" initialization reduces")
            actual.accept({"kind":"initialization","state":initial.value.duplicate(true),"sequence":0})
            twin.accept({"kind":"initialization","state":initial.value.duplicate(true),"sequence":0});continue
        var compiled=Compiler.compile(actual.state,packet,cache)
        check(compiled.ok,name+" operation compiles")
        if not compiled.ok:return
        for lineage in packet.lineages:
            for node in lineage.events:
                if node.fact==null:continue
                if node.fact.kind=="attack" and node.fact.behavior_id=="reaction.opportunity_attack":evidence.oa+=1
                if node.fact.kind=="step" and not node.fact.committed:evidence.uncommitted_edges+=1
                if node.fact.kind=="life":evidence.life+=1
        var record=Prediction.create()
        var plan={}
        if packet.command_number==command.command_number:
            var track=first_track(compiled.value.groups,command.actor_uuid)
            if not track.is_empty():
                # Already-admitted source programs isolate reconciliation from
                # recipe selection. Shift a delayed motion to test a mistaken
                # early prefix relinquishing to the real preceding reaction.
                track=track.duplicate(true);track.start_ms=0.0
                plan={"actor_tracks":[track],"limit_ms":minf(120.0,track.duration_ms*.4)}
                check(Prediction.begin(record,packet.cursor,command,plan),name+" passive prefix begins")
                evidence.own_commands+=1
                var before=actual.state.duplicate(true)
                var preview=Prediction.overlay(record,{}, {},0,actual.sequence,80)
                check(not preview.is_empty() and preview[command.actor_uuid].get("predicted",false),name+" body samples immediately before any authoritative operation")
                check(not preview[command.actor_uuid].has("trace_track_id"),name+" speculative pose is never an authoritative render witness")
                check(actual.state==before,name+" prefix never mutates reducer state")
                for i in range(20):Prediction.overlay(record,{}, {},0,actual.sequence,80)
                check(record.active.elapsed_ms<=120.0,name+" arbitrary receipt delay stops at bounded prefix")
                if fixture.is_empty():fixture={"plan":plan.duplicate(true),"cursor":packet.cursor.duplicate(true),"command":command.duplicate(true),"state":actual.state.duplicate(true),"groups":compiled.value.groups}
                if name in ["walk","walk-diagonal","walk-fast"]:
                    var selection:Dictionary=command.intent.selection
                    var action={"discovery_actor_uuid":command.actor_uuid,"discovery_index":selection.action_index,"behavior_id":"action.move",
                        "variant_facets":[{"key":"movement","value":"walking"}],"connector_traversal":null,
                        "valid_targets":[{"index":selection.target_indices[0],"path":source.evidence.preview.selected_route.path}]}
                    var adapted=Recipes.prepare(actual.state,action,selection,source.evidence.preview,cache)
                    check(adapted.has("actor_tracks"),name+" actual route/preview with explicitly reconstructed choice envelope creates authored prefix")
                    if adapted.has("actor_tracks"):
                        evidence.recipe_prefixes+=1
                        check(Prediction.compatible(adapted.actor_tracks[0],track)==(name!="walk-fast"),name+" true source speed decides exact prefix compatibility")
        var message={"kind":"operation","sequence":packet.cursor.sequence,"cursor":packet.cursor,"command_number":packet.command_number,"groups":compiled.value.groups}
        # Alternate receipt order around the exact admitted operation message.
        if not record.active.is_empty() and name in ["walk","jump"]:Prediction.receipt(record,receipt(packet.cursor,command.command_number,"committed"))
        Prediction.observe(record,message)
        if not record.active.is_empty() and name not in ["walk","jump"]:Prediction.receipt(record,receipt(packet.cursor,command.command_number,"committed"))
        actual.accept(message);twin.accept(message)
        var n=0
        while actual.busy() and n<2000:
            actual.advance(16);twin.advance(16)
            var samples=actual.actor_samples();var prior=samples.duplicate(true)
            var output=Prediction.overlay(record,samples,actual.current,actual.display_ms-actual.group_start_ms,actual.sequence,16)
            check(samples==prior,name+" overlay leaves canonical samples unchanged")
            if not record.active.is_empty() and record.active.phase=="catching_up":
                var expected=Tracks.samples(record.active.tracks,record.active.elapsed_ms)
                var id:String=command.actor_uuid
                check(output[id].source_seconds==expected[id].source_seconds and output[id].get("position")==expected[id].get("position"),name+" matching prefix holds already displayed pose until source time catches up")
            aligned(actual,twin,name)
            evidence.canonical_frames+=1;n+=1
        check(not actual.busy() and actual.state==compiled.value.final_state,name+" full source operation, including reactions and canceled edge, is retained")
        if not plan.is_empty():
            evidence.handoffs+=record.matched;evidence.corrections+=record.corrected
            check(record.active.is_empty(),name+" overlay completes or yields to actual source")
            if name in ["oa-walk-3","oa-jump-hit"]:check(record.corrected>0,name+" speculative motion relinquishes before real reaction")
            if name=="oa-jump-late-lethal":check(record.matched==1 and actual.state.actors[command.actor_uuid].last_visual_position==[6,6] and actual.state.actors[command.actor_uuid].life_state=="dead","Late lethal reaction keeps completed first-edge handoff and stops at last admitted contact")
        if name=="oa-walk-3" and packet.command_number==command.command_number:
            var selected:Dictionary=command.intent.selection
            var row={"discovery_actor_uuid":command.actor_uuid,"discovery_index":selected.action_index,"behavior_id":"action.move","variant_facets":[],
                "valid_targets":[{"index":selected.target_indices[0]}]}
            # At this point the actor has moved; restore only the original
            # displayed contact to test the actual preview's first-edge warning.
            var state=twin.state.duplicate(true);state.actors[command.actor_uuid].last_visual_position=source.evidence.preview.selected_route.path[0]
            var denied=Recipes.prepare(state,row,selected,source.evidence.preview,cache)
            check(denied.get("reason")=="first_edge_reaction","Actual disclosed first-edge OA suppresses prediction before support/animation lookup")
func lifecycle()->void:
    check(not fixture.is_empty(),"Actual source program available for receipt lifecycle cases")
    if fixture.is_empty():return
    var f=fixture;var r=Prediction.create()
    check(Prediction.begin(r,f.cursor,f.command,f.plan),"Receipt lifecycle starts one command")
    check(not Prediction.begin(r,f.cursor,f.command,f.plan),"Duplicate submission cannot create a second overlay")
    var initial=Prediction.overlay(r,{}, {},0,0,80)
    for kind in ["pending","unknown","expired","indeterminate"]:
        Prediction.receipt(r,receipt(f.cursor,f.command.command_number,kind))
        check(r.active.phase=="pending",kind+" is unresolved rather than rejected")
    for field in ["game_id","game_epoch","audience_id"]:
        var foreign=receipt(f.cursor,f.command.command_number,"rejected");foreign[field]="foreign"
        Prediction.receipt(r,foreign)
        check(r.active.phase=="pending","Same-number rejection from another "+field+" cannot change overlay")
        foreign=receipt(f.cursor,f.command.command_number,"committed");foreign[field]="foreign";foreign.cursor[field]="foreign"
        Prediction.receipt(r,foreign)
        check(r.active.sequence<0,"Same-number committed receipt from another "+field+" cannot match")
    var time=r.active.elapsed_ms
    Prediction.overlay(r,{}, {},0,0,500,true)
    check(r.active.elapsed_ms==time,"Pause holds speculative source time")
    Prediction.receipt(r,receipt(f.cursor,f.command.command_number,"rejected"))
    var returning=Prediction.overlay(r,{}, {},0,0,40)
    var id:String=f.command.actor_uuid
    check(returning[id].source_seconds<initial[id].source_seconds,"Explicit rejection returns along the sampled prefix")
    Prediction.overlay(r,{}, {},0,0,40)
    check(r.active.is_empty() and r.rejected==1,"Rejection finishes bounded visual return without state rollback")
    Prediction.begin(r,f.cursor,f.command,f.plan)
    Prediction.observe(r,{"kind":"operation","cursor":f.cursor,"command_number":null,"sequence":f.cursor.sequence})
    check(r.active.sequence<0,"Unowned operation cannot claim pending command")
    Prediction.observe(r,{"kind":"operation","cursor":f.cursor,"command_number":f.command.command_number,"sequence":f.cursor.sequence})
    Prediction.receipt(r,receipt(f.cursor,f.command.command_number,"rejected"))
    check(r.active.sequence==f.cursor.sequence and r.active.phase=="pending","Admitted command occurrence is not undone by a late contradictory rejection")
    Prediction.observe(r,{"kind":"initialization"})
    check(r.active.is_empty(),"Initialization reset drops old epoch prediction")
    Prediction.begin(r,f.cursor,f.command,f.plan);Prediction.reset(r,"session_closed")
    check(r.active.is_empty(),"Session close removes speculative lifetime")
func held_preparation()->void:
    if fixture.is_empty():return
    var actual=Timeline.new();var twin=Timeline.new();var f=fixture
    for timeline in [actual,twin]:
        timeline.accept({"kind":"initialization","state":f.state.duplicate(true),"sequence":f.cursor.sequence-1})
        timeline.accept({"kind":"operation","groups":f.groups})
    var gates={"media":false,"world":false}
    for timeline in [actual,twin]:
        timeline.media_ready=func(_group):return gates.media
        timeline.world_ready=func(_candidate):return gates.world
    var record=Prediction.create();Prediction.begin(record,f.cursor,f.command,f.plan)
    var before=actual.state.duplicate(true);var trace=actual.trace.duplicate(true)
    for i in range(6):
        actual.advance(100);twin.advance(100)
        Prediction.overlay(record,actual.actor_samples(),actual.current,actual.display_ms-actual.group_start_ms,actual.sequence,100)
    check(actual.waiting_for_media and actual.state==before and actual.trace==trace and actual.display_ms==0,"Media hold leaves canonical state, full trace and clock at prior boundary while prefix is bounded")
    check(record.active.elapsed_ms<=120,"Preparation hold cannot stretch speculative progress")
    gates.media=true
    var attempts=0
    while not actual.waiting_for_world and actual.busy() and attempts<100:
        actual.advance(16);twin.advance(16);attempts+=1
        Prediction.overlay(record,actual.actor_samples(),actual.current,actual.display_ms-actual.group_start_ms,actual.sequence,16)
    check(actual.waiting_for_world,"Real movement reaches prospective world preparation gate")
    before=actual.state.duplicate(true);trace=actual.trace.duplicate(true);var at=actual.display_ms
    for i in range(4):
        actual.advance(100);twin.advance(100)
        Prediction.overlay(record,actual.actor_samples(),actual.current,actual.display_ms-actual.group_start_ms,actual.sequence,100)
    check(actual.state==before and actual.trace==trace and actual.display_ms==at,"World hold prevents future support/state/log publication despite elapsed overlay frames")
    aligned(actual,twin,"Preparation-held overlay")
    gates.world=true
    while actual.busy() and attempts<300:
        actual.advance(100);twin.advance(100);attempts+=1
        Prediction.overlay(record,actual.actor_samples(),actual.current,actual.display_ms-actual.group_start_ms,actual.sequence,100)
    aligned(actual,twin,"Preparation-resumed overlay")
    check(not actual.busy(),"Held source resumes to exact canonical end")
func real_discovery_recipes()->void:
    var directory="res://.runtime/player-runs/20261011T223103.996259Z"
    var state=read_data(directory+"/state.json");var discovery=read_data(directory+"/discovery.json")
    var preview=read_data(base+"jump/presentation-result.json").evidence.preview
    for action in discovery.position_actions:
        if action.behavior_id!="action.jump":continue
        var selection={"action_index":action.discovery_index,"target_indices":[action.valid_targets[0].index]}
        var plan=Recipes.prepare(state,action,selection,preview,cache)
        check(plan.has("actor_tracks"),"Recorded jump discovery and standard confirmed preview expose an authored first-edge prefix")
        if plan.has("actor_tracks"):
            evidence.recipe_prefixes+=1
            check(plan.actor_tracks[0].trajectory=="direct_arc" and plan.actor_tracks[0].from_position==action.valid_targets[0].path[0] and plan.actor_tracks[0].to_position==action.valid_targets[0].path[1],"Jump prefix uses exact disclosed target path")
            check(plan.limit_ms<plan.actor_tracks[0].duration_ms and plan.limit_ms<=120,"Jump remains before first entry")
        var unknown=action.duplicate(true);unknown.behavior_id="unsupported.fixture"
        check(Recipes.prepare(state,unknown,selection,preview,cache).get("reason")=="no_authored_prediction_prefix","Unsupported family remains confirmed-only")
func attack_adapters()->void:
    var directory="res://.runtime/player-runs/20261011T223103.996259Z"
    var original_state=read_data(directory+"/state.json");var discovery=read_data(directory+"/discovery.json")
    var prototype:Dictionary={}
    for action in discovery.entity_actions:
        if action.behavior_id=="action.attack":prototype=action;break
    check(not prototype.is_empty(),"Recorded exact weapon discovery available for named typed attack variants")
    if prototype.is_empty():return
    # Explicit item/slot/damage variations of a real disclosed actor and choice.
    # They test the source recipe selector, never backend combat outcomes.
    for spec in [["weapon.longsword","MELEE_MAIN","Slashing","Attack1",1.0],
            ["weapon.mace","MELEE_MAIN","Bludgeoning","Attack2",1.05],
            ["weapon.greatsword","MELEE_MAIN","Slashing","Attack4",0.95],
            ["weapon.longbow","RANGED_MAIN","Piercing","Attack3",1.0],
            ["weapon.dagger","MELEE_MAIN","Piercing","",1.0]]:
        var state=original_state.duplicate(true);var action=prototype.duplicate(true)
        var actor:Dictionary=state.actors[action.discovery_actor_uuid]
        action.weapon_slot=spec[1];action.damage_types=[spec[2]]
        actor.visual_loadout.active_weapon_set="ranged" if spec[1]=="RANGED_MAIN" else "melee"
        for item in actor.visual_loadout.layers:
            if item.item_uuid==action.source_item_uuid:item.item_id=spec[0];item.slot=spec[1]
        var origin:Array=actor.last_visual_position
        action.valid_targets=[{"index":0,"target_uuid":null,"position":[origin[0]+1,origin[1]]}]
        var selection={"action_index":action.discovery_index,"target_indices":[0]}
        var local_cache={}
        var source=Authoring.load_data("catalog/attack_recipes.json",local_cache).duplicate(true)
        var plan=Recipes.prepare(state,action,selection,{"can_confirm":true},local_cache)
        check(Authoring.load_data("catalog/attack_recipes.json",local_cache)==source,str(spec[0])+" recipe selection does not mutate cached authored arrays")
        if spec[0]=="weapon.dagger":
            check(plan.get("reason")=="no_common_attack_prefix","Dagger outcome-dependent overhead/piercing clips suppress unconfirmed body")
            continue
        check(plan.has("actor_tracks"),str(spec[0])+" outcome-invariant authored attack prefix exists")
        if not plan.has("actor_tracks"):continue
        var track:Dictionary=plan.actor_tracks[0]
        var clip=Authoring.clip(actor,spec[3],local_cache)
        check(track.clip==spec[3] and is_equal_approx(track.duration_ms,float(clip.frames)/clip.fps/spec[4]*1000.0),str(spec[0])+" exact authored clip and playback rate")
        for outcome in ["Hit","Miss","Crit","Crit Miss"]:
            var fact={"behavior_id":"action.attack","weapon_slot":spec[1],"source_item_id":spec[0],"attack_source_kind":"equipped","damage_types":[spec[2]],"attack_outcome":outcome}
            var confirmed=Authoring.attack(fact,actor,local_cache)
            check(track.clip==confirmed.actor.clip and track.hidden_slots==confirmed.actor.hiddenSlots,str(spec[0])+" body and hidden slots agree for actual authored "+outcome+" variant")
            var first=INF
            for anchor in confirmed.anchors:
                if anchor.name in ["contact","release"]:first=minf(first,float(anchor.frame)/clip.fps/confirmed.actor.playbackSpeed*1000.0)
            check(plan.limit_ms<first and plan.limit_ms<=120,str(spec[0])+" prefix cannot reach authored contact/release for "+outcome)
        var first_time=track.duration_ms
        actor.conditions.append({"behavior_id":"condition.spell.haste"})
        var fast=Recipes.prepare(state,action,selection,{"can_confirm":true},local_cache)
        var rate=Authoring.load_data("catalog/action_playback_rates.json",local_cache).get("condition.spell.haste",1.0)
        check(fast.has("actor_tracks") and is_equal_approx(fast.actor_tracks[0].duration_ms,first_time/rate),str(spec[0])+" authored condition playback multiplier is preserved")
        check(Authoring.load_data("catalog/attack_recipes.json",local_cache)==source,str(spec[0])+" repeated selection keeps original source immutable")
func run()->void:
    for name in ["walk","walk-diagonal","walk-fast","jump","attack","oa-walk-3","oa-jump-hit","oa-jump-late-lethal"]:recording(name)
    lifecycle();held_preparation();real_discovery_recipes();attack_adapters()
    check(evidence.handoffs>0 and evidence.corrections>0,"Real programs exercise both continuous handoff and authoritative correction")
    check(evidence.oa>0 and evidence.uncommitted_edges>0 and evidence.life>0,"Real reactions, interrupted edges and death remain in canonical playback")
    var report={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Actual walk/cardinal/diagonal/fast, jump, attack and OA/lethal recordings through twin canonical Timelines; admitted-track reconciliation fixtures, captured route previews with explicitly reconstructed choice envelopes, recorded jump discovery, and typed receipt lifecycle cases. No generated gameplay outcomes or native rendering assertions."}
    FileAccess.open("res://generated/prediction_recording_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("PREDICTION_RECORDING_CHECKS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
