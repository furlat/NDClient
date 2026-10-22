extends SceneTree
## Ordered constructor boundaries through Timeline, and actual compiler inputs.
const Recording=preload("res://studio/recording.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
const Timeline=preload("res://presentation/timeline.gd")
const Construction=preload("res://presentation/actor_construction.gd")
const Tracks=preload("res://presentation/tracks.gd")
var checks=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr(label)
func group()->Dictionary:
    return {"id":"actor-cut","operation_sequence":1,"operation_end":true,"duration_ms":30.0,"events":[],
        "actor_tracks":[],"components":[],"staged_actors":{},"staged_at_ms":{},"staged_tiles":{},"commits":[]}
func timeline(index:Dictionary,value:Dictionary)->RefCounted:
    var result=Timeline.new();var init=index.initialization.duplicate();init.state=init.state.duplicate(true)
    var local=value.duplicate();local.erase("preview_start_ms")
    result.accept(init);result.accept({"kind":"operation","groups":[local]});result.world_ready=func(_candidate):return true
    return result
func pending_state(index:Dictionary,actor:Dictionary)->void:
    var value=group();value.actor_structure_times=[10.0]
    var after=actor.duplicate(true);after.appearance.skin_tint=int(after.appearance.skin_tint)^0x101010
    value.commits=[{"at_ms":10.0,"delta":{"actors":{actor.uuid:after}}}]
    var actual=timeline(index,value)
    var gate={"ready":false,"candidate":{}}
    actual.world_ready=func(candidate):gate.candidate=candidate;return gate.ready
    var saved=actual.state.duplicate(true)
    actual.advance(25.0)
    check(actual.waiting_for_world and actual.display_ms==0.0 and actual.state==saved,"Actor-only structure waits without publishing state or time")
    check(not gate.candidate.is_empty() and gate.candidate.state.actors[actor.uuid]==after,"Hidden candidate contains the exact actor after-value")
    gate.ready=true;actual.advance(2.0)
    check(actual.display_ms==10.0 and actual.state.actors[actor.uuid]==after,"Ready actor cut publishes its retained target once")
    actual.advance(2.0)
    check(actual.display_ms==12.0,"Actor boundary resumes without wall-time or old frame remainder")
func temporary_layers(index:Dictionary,actor:Dictionary)->void:
    var value=group();value.actor_structure_times=[5.0,15.0]
    var loadout=actor.visual_loadout.duplicate(true);loadout.active_weapon_set="ranged"
    value.actor_tracks=[{"actor_uuid":actor.uuid,"start_ms":5.0,"duration_ms":10.0,"priority":1,"visual_loadout":loadout}]
    var layer={"id":"hand-effect","kind":"sprite_layer","actor_uuid":actor.uuid,"start_ms":5.0,"duration_ms":10.0,"layer":{"slot":"effect","category":"fixture"}}
    value.components=[layer]
    var actual=timeline(index,value);var captured:Array=[]
    actual.world_ready=func(candidate):captured.append(candidate);return true
    check(actual.preview_world().display_ms==5.0,"Lookahead first prepares the temporary actor onset")
    actual.advance(25.0)
    check(actual.display_ms==5.0 and captured.size()==1,"Temporary outfit/layer onset is its own publication cut")
    if not captured.is_empty():
        check(captured[-1].actor_samples[actor.uuid].visual_loadout==loadout and captured[-1].actor_layers==[layer],"Candidate contains exact onset outfit and sprite-layer source")
    var next=actual.preview_world()
    check(not next.is_empty() and next.display_ms==15.0 and next.actor_layers.is_empty(),"Lookahead advances to layer retirement after an actor-only publication")
    actual.advance(25.0)
    check(actual.display_ms==15.0 and captured.size()==2,"Temporary actor layer retirement also prepares a cut")
    if captured.size()==2:check(captured[-1].actor_samples.is_empty() and captured[-1].actor_layers.is_empty(),"Expiry candidate removes temporary outfit and layer together")
    # The same authored cuts remain private during cumulative replay preparation.
    actual=timeline(index,value);var gate={"ready":false};actual.world_ready=func(_candidate):return gate.ready
    var plan=actual.replay_plan(25.0)
    check(not actual.replay_prepare(plan) and actual.display_ms==0.0,"Explicit replay holds the complete requested actor prefix")
    gate.ready=true
    check(actual.replay_prepare(plan) and actual.replay_publish(plan) and actual.display_ms==25.0,"Replay publishes only its requested cut across actor boundaries")
func fractional_clock(index:Dictionary)->void:
    # Gallery door run234759 repeatedly rebuilt its250ms actor cut when the
    # absolute clock subtraction rounded below that already published cut.
    var value=group();value.duration_ms=1250.0;value.actor_structure_times=[250.0]
    var actual=timeline(index,value)
    actual.display_ms=383.92639393939393
    var admitted:Array=[]
    actual.world_ready=func(candidate):admitted.append(candidate);return true
    actual.advance(300.0)
    check(admitted.size()==1 and actual.display_ms==383.92639393939393+250.0,"Fractional display clock admits the authored actor cut once")
    var before:float=actual.display_ms
    actual.advance(11.0)
    check(admitted.size()==1 and actual.display_ms>before,"Already published fractional actor boundary advances without another constructor")
func staged_actor(index:Dictionary,actor:Dictionary)->void:
    var value=group();value.actor_structure_times=[5.0,30.0]
    var staged=actor.duplicate(true);staged.uuid="staged-fixture"
    value.staged_actors[staged.uuid]=staged;value.staged_at_ms[staged.uuid]=5.0
    var actual=timeline(index,value);var captured:Array=[]
    actual.world_ready=func(candidate):captured.append(candidate);return true
    actual.advance(20.0)
    check(actual.display_ms==5.0 and actual.staged_actors().has(staged.uuid),"First-disclosed actor on existing support prepares before admission")
    if not captured.is_empty():check(captured[-1].staged_actors[staged.uuid]==staged,"Candidate owns the disclosed actor at its actual cue")
    actual.advance(100.0)
    check(actual.display_ms==30.0 and captured.size()==2 and actual.staged_actors().is_empty(),"Group completion prepares staged actor retirement without canonical invention")
func recorded(index:Dictionary,primary:bool=true)->int:
    var state=index.initialization.state.duplicate(true)
    var sprite_edges=0;var light_edges=0;var ordinary_moves=0
    for item in index.groups:
        var value:Dictionary=item.group
        var light_timeline=timeline(index,value)
        check(value.has("actor_structure_times"),"Compiled group carries actor constructor cuts")
        # Effect-only layers are their own cut list: a live host builds them in sampling.
        var layer_cuts:Array=value.actor_structure_times+value.get("actor_effect_times",[])
        for component in value.components:
            if component.kind!="sprite_layer" or component.duration_ms<=0:continue
            if component.start_ms<value.duration_ms:
                check(component.start_ms in layer_cuts,"Actual authored sprite layer prepares at its onset")
                sprite_edges+=1
            var end:float=component.start_ms+component.duration_ms
            if end<=value.duration_ms:check(end in layer_cuts,"Actual authored sprite layer retires at its endpoint")
        var moves=0;var only_motion=true
        for commit in value.commits:
            var previous_lights:Variant=state.get("light_sources",{})
            for id in commit.delta.get("actors",{}):
                var old:Dictionary=state.actors.get(id,{})
                var after:Dictionary=commit.delta.actors[id]
                for field in ["creature_content_ref","appearance","visual_loadout","present","spatial_disposition","remains_disposition","life_state"]:
                    if old.get(field)!=after.get(field):only_motion=false
                if old.get("last_visual_position")!=after.get("last_visual_position"):
                    if old.get("last_visual_position")==null or after.get("last_visual_position")==null:only_motion=false
                    else:moves+=1
            Timeline.Compiler.apply_delta(state,commit.delta)
            if state.get("light_sources",{})!=previous_lights:
                check(light_timeline.replay_plan(commit.at_ms).boundary,"Actual optical source change retains its prepared world boundary")
                light_edges+=1
        if moves>0 and only_motion and value.staged_actors.is_empty() and not value.components.any(func(row):return row.kind=="sprite_layer") and not value.actor_tracks.any(func(row):return row.has("visual_loadout")):
            check(value.actor_structure_times.is_empty(),"Actual ordinary movement adds no actor construction boundary")
            ordinary_moves+=moves
    if primary:
        check(sprite_edges>0,"Actual recording covers authored temporary layers")
        check(ordinary_moves>0,"Actual recording covers ordinary movement without structural cuts")
    print("ACTOR_STRUCTURE_RECORDING ",JSON.stringify({"sprite_edges":sprite_edges,"light_edges":light_edges,"ordinary_moves":ordinary_moves}))
    return light_edges
## Optional genuine terminal original; never synthesize a Life fact/contact.
## The ordinary fixture duties above remain mandatory without this argument.
func terminal_original(directory:String)->void:
    var recorded=Recording.Journal.new();var plain=Recording.Journal.new()
    var opened:Dictionary=recorded.open(directory,true,false);var ordinary:Dictionary=plain.open(directory,true,false)
    check(opened.ok and ordinary.ok,"Terminal original opens independently for recording-on/off")
    if not opened.ok or not ordinary.ok:return
    var files:PackedStringArray=DirAccess.get_files_at(directory);files.sort()
    var cache:Dictionary={};var captures:int=0;var hidden:int=0
    for file in files:
        if not file.ends_with(".json") or file.get_basename().length()!=16 or not file.get_basename().is_valid_int():continue
        var sequence:int=file.get_basename().to_int();var raw:PackedByteArray=FileAccess.get_file_as_bytes(directory.path_join(file))
        var decoded:Dictionary=recorded.decode_record(sequence,raw)
        check(decoded.ok,"Terminal original decodes actual packet "+str(sequence))
        if not decoded.ok:return
        var before:Dictionary=recorded.state
        var folded:Dictionary=recorded._consume_admitted(decoded.value,raw,true)
        var unrecorded:Dictionary=plain._consume_admitted(decoded.value,raw,false)
        check(folded.ok and unrecorded.ok,"Terminal recording-on/off admits actual packet "+str(sequence))
        if not folded.ok or not unrecorded.ok:return
        check(var_to_bytes(recorded.state)==var_to_bytes(plain.state),"Terminal recording-on/off preserves complete canonical value and order "+str(sequence))
        check(not unrecorded.has("transitions"),"Recording-off publishes no presentation captures "+str(sequence))
        if sequence==0:continue
        var immutable:PackedByteArray=var_to_bytes(folded.normalized)
        var compiled:Dictionary=Timeline.Compiler.compile_recorded(before,folded.normalized,cache,recorded.state,folded.transitions)
        check(compiled.ok,"Terminal original compiles its actual packet "+str(sequence))
        if not compiled.ok:return
        for i in folded.normalized.lineages.size():
            var lineage:Dictionary=folded.normalized.lineages[i];var cuts:Dictionary=folded.transitions.lineages[i]
            for terminal in cuts.get("terminal_inputs",{}).values():
                captures+=1
                var nodes:Array=lineage.events.filter(func(node):return str(node.occurrence)==terminal.life_event_uuid)
                check(nodes.size()==1,"Terminal receipt names exactly one actual Life completion")
                if nodes.size()!=1:continue
                var node:Dictionary=nodes[0];var first:int=int(node.occurrence);var owners:Dictionary={}
                for row in lineage.version_rows.occurrences.size():
                    owners[int(lineage.version_rows.occurrences[row])]=int(lineage.version_rows.lineages[row])
                    if str(lineage.version_rows.lineages[row])==terminal.source_lineage:first=mini(first,int(lineage.version_rows.occurrences[row]))
                check(node.fact.kind=="life" and node.fact.new_state=="dead" and node.phase=="completion" and not node.get("canceled",false),"Terminal receipt belongs to actual uncanceled Life→dead")
                check(str(owners[int(node.occurrence)])==terminal.life_lineage,"Life lineage remains its own actual version identity")
                if terminal.source_cut=="immediate_parent_entry":
                    var parents:Array=lineage.events.filter(func(parent):return int(terminal.life_lineage) in parent.get("children_lineages",[]))
                    check(parents.size()==1,"Earlier terminal entry has exactly one actual immediate parent")
                    if parents.size()!=1:continue
                    var parent:Dictionary=parents[0]
                    check(parent.get("fact")==null and parent.phase=="completion" and not parent.get("canceled",false) and parent.children_lineages==[int(terminal.life_lineage)],"Earlier terminal entry is the uncanceled direct no-fact Life wrapper")
                    check(str(parent.occurrence)==terminal.source_event_uuid and str(owners[int(parent.occurrence)])==terminal.source_lineage and str(owners.get(int(node.parent_event)))==terminal.source_lineage and terminal.source_lineage!=terminal.life_lineage,"Life parent_event and wrapper children independently join the distinct entry lineage")
                else:check(terminal.source_cut=="first_real_life_version" and terminal.source_lineage==terminal.life_lineage and terminal.source_event_uuid==terminal.life_event_uuid,"Without an admitted wrapper only the own-Life entry is used")
                check(terminal.source_index==first and first<=int(node.occurrence),"Terminal source index is the actual first version of its explicitly named entry lineage")
                check(terminal.actor.life_state==node.fact.previous_state and terminal.actor.last_visual_position==terminal.position and terminal.contact.visual and terminal.contact.position==terminal.position,"Terminal receipt retains its actual pre-Life visual actor/contact")
                var tracks:Array=compiled.value.groups[i].actor_tracks.filter(func(track):return str(track.get("source_event_uuid"))==terminal.life_event_uuid and track.has("terminal_presentation"))
                check(tracks.size()==1,"Actual Life selects exactly one finite terminal body owner")
                if tracks.size()!=1:continue
                var track:Dictionary=tracks[0]
                check(track.duration_ms>0.0 and track.from_position==terminal.position and track.to_position==terminal.position,"Terminal receipt preserves the actual finite held source point")
                if terminal.actor.get("occupancy_layer")=="ground":check(track.from_elevation_feet==float(terminal.support.elevation_steps)*5.0 and track.to_elevation_feet==track.from_elevation_feet,"Actual ground terminal retains known held elevation")
                var actor:Dictionary=recorded.state.actors[terminal.actor.uuid]
                if actor.last_visual_position!=null:continue
                hidden+=1
                terminal_projection(recorded.state,actor,track)
        check(var_to_bytes(folded.normalized)==immutable,"Terminal compilation preserves unchanged original packet "+str(sequence))
    check(captures>0 and hidden>0,"Explicit terminal original witnesses a real pre-withdrawal capture and canonical null position")

func terminal_projection(state:Dictionary,actor:Dictionary,track:Dictionary)->void:
    var terminal:Dictionary=track.terminal_presentation
    var frozen:PackedByteArray=var_to_bytes(state);var frozen_receipt:PackedByteArray=var_to_bytes(terminal)
    var middle:float=float(track.start_ms)+float(track.duration_ms)*.5
    var samples:Dictionary=Tracks.samples([track],middle)
    var loadouts:Dictionary=Construction.loadouts(samples,[])
    var projected:Dictionary=Construction.actor_with_loadout(actor,loadouts,state)
    check(projected.last_visual_position==terminal.position and actor.last_visual_position==null,"Finite actual terminal owner admits private presentation without canonical repair")
    check(Construction.actor_with_loadout(actor,loadouts).last_visual_position==null,"Missing current cut cannot admit a terminal presentation")
    check(Construction.actor_with_loadout(actor,Construction.loadouts(Tracks.samples([track],float(track.start_ms)-1.0),[]),state).last_visual_position==null,"Before actual terminal onset no private membership exists")
    var end:float=float(track.start_ms)+float(track.duration_ms)
    var held:Dictionary=Tracks.samples([track],end)
    check(track.get("holding_pose",false) and held.has(actor.uuid) and not held[actor.uuid].has("terminal_presentation"),"Actual held terminal pose loses its receipt at the finite endpoint")
    check(Construction.actor_with_loadout(actor,Construction.loadouts(held,[]),state).last_visual_position==null,"Held endpoint cannot retain private terminal membership")
    check(Construction.actor_with_loadout(actor,Construction.loadouts(Tracks.samples([track],middle),[]),state).last_visual_position==terminal.position,"Replaying the actual finite cut re-admits only its original operand")
    for changes in [{"life_state":"alive"},{"present":false},{"spatial_disposition":"absent"},{"remains_disposition":"disintegrated"},{"character_body_id":"different-source"},{"occupancy_layer":"air" if actor.get("occupancy_layer")=="ground" else "ground"}]:
        var changed:Dictionary=actor.duplicate();changed.merge(changes,true)
        check(Construction.actor_with_loadout(changed,loadouts,state).last_visual_position==null,"Terminal membership refuses changed current owner "+JSON.stringify(changes))
    var different:Dictionary=state.duplicate();different.generation="another-generation"
    check(Construction.actor_with_loadout(actor,loadouts,different).last_visual_position==null,"Terminal membership refuses another generation")
    different=state.duplicate();different.observer_uuid="another-observer"
    check(Construction.actor_with_loadout(actor,loadouts,different).last_visual_position==null,"Terminal membership refuses another observer")
    different=state.duplicate();different.tiles=state.tiles.duplicate();different.tiles.erase(Timeline.Compiler.WorldRows.cell_key(terminal.position))
    check(Construction.actor_with_loadout(actor,loadouts,different).last_visual_position==null,"Terminal membership refuses removed support")
    different=state.duplicate();different.tiles=state.tiles.duplicate()
    var key:String=Timeline.Compiler.WorldRows.cell_key(terminal.position);different.tiles[key]=state.tiles[key].duplicate();different.tiles[key].elevation_steps+=1
    check(Construction.actor_with_loadout(actor,loadouts,different).last_visual_position==null,"Terminal membership refuses changed support elevation")
    different=state.duplicate();different.senses=state.senses.duplicate();different.senses.visible=state.senses.visible.duplicate();different.senses.visible.bits=""
    check(Construction.actor_with_loadout(actor,loadouts,different).last_visual_position==null,"Retained terrain cannot replace actual current visible coverage")
    # Explicit test-only fractional clock matching the actual first-Life cut:
    # group122 origin3400, local13/12s. This is not a new producer fact.
    var fractional:Dictionary=track.duplicate();fractional.start_ms=1000.0*13.0/12.0
    var origin:float=3400.0;var begin:float=origin+float(fractional.start_ms)
    var finish:float=origin+(float(fractional.start_ms)+float(fractional.duration_ms))
    var onset:Dictionary=Tracks.samples([fractional],begin-origin,origin,begin)
    check(onset.get(actor.uuid,{}).has("terminal_presentation"),"Fractional absolute onset admits the same terminal member as its prepared cut")
    var prepared:Dictionary=Tracks.samples([fractional],float(fractional.start_ms),origin,begin)
    check(Construction.loadouts(prepared,[])==Construction.loadouts(onset,[]),"Authored and re-subtracted fractional onset agree on prepared constructor membership")
    var endpoint:Dictionary=Tracks.samples([fractional],finish-origin,origin,finish)
    check(endpoint.has(actor.uuid) and not endpoint[actor.uuid].has("terminal_presentation"),"Fractional exact absolute endpoint removes receipt while retaining the ordinary held pose")
    check(Construction.actor_with_loadout(actor,Construction.loadouts(endpoint,[]),state).last_visual_position==null,"Fractional held endpoint cannot re-admit an unprepared terminal owner")
    check(not Tracks.samples([fractional],(begin-1.0)-origin,origin,begin-1.0).has(actor.uuid),"One millisecond before absolute onset remains absent")
    var middle_local:float=float(fractional.start_ms)+float(fractional.duration_ms)*.5
    check(Tracks.samples([fractional],middle_local,origin,origin+middle_local)==Tracks.samples([fractional],middle_local),"Absolute membership operands preserve ordinary local source-frame fractions")
    var ordinary:Dictionary=fractional.duplicate();ordinary.erase("terminal_presentation")
    check(Tracks.samples([ordinary],begin-origin,origin,begin)==Tracks.samples([ordinary],begin-origin),"Ordinary nonreceipt tracks retain literal local membership behavior")
    check(var_to_bytes(state)==frozen and var_to_bytes(terminal)==frozen_receipt,"Terminal admission/refusal leaves canonical state and original capture immutable")

func run()->void:
    var index=Fixtures.read("gallery")
    check(index.ok,"Current baseline recording admits")
    if not index.ok:quit(1);return
    var actor:Dictionary=index.initialization.state.actors[index.initialization.state.audience.controlled[0]]
    pending_state(index,actor);temporary_layers(index,actor);fractional_clock(index);staged_actor(index,actor);recorded(index)
    var lights=Fixtures.read("hide-light")
    check(lights.ok,"Actual light-source recording admits")
    if lights.ok:check(recorded(lights,false)>0,"Actual recording covers disclosed optical source changes")
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--terminal-journal="):terminal_original(argument.trim_prefix("--terminal-journal="))
    print("ACTOR_STRUCTURAL_CUTS ",JSON.stringify({"checks":checks,"failures":failures,"scope":"Private actor cut state, transient selectors, staged admission and cumulative replay; real compiler source edges and ordinary movement. No native graphics qualification."}))
    quit(0 if failures.is_empty() else 1)
