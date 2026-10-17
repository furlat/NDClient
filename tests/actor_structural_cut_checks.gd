extends SceneTree
## Ordered constructor boundaries through Timeline, and actual compiler inputs.
const Recording=preload("res://studio/recording.gd")
const Timeline=preload("res://presentation/timeline.gd")
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
            if commit.delta.get("set",{}).has("senses") and commit.delta.set.senses.get("light_sources",{})!=state.senses.get("light_sources",{}):
                check(light_timeline.replay_plan(commit.at_ms).boundary,"Actual optical source change retains its prepared world boundary")
                light_edges+=1
            for id in commit.delta.get("actors",{}):
                var old:Dictionary=state.actors.get(id,{})
                var after:Dictionary=commit.delta.actors[id]
                for field in ["creature_content_ref","appearance","visual_loadout","present","spatial_disposition","remains_disposition","life_state"]:
                    if old.get(field)!=after.get(field):only_motion=false
                if old.get("last_visual_position")!=after.get("last_visual_position"):
                    if old.get("last_visual_position")==null or after.get("last_visual_position")==null:only_motion=false
                    else:moves+=1
            Timeline.Compiler.apply_delta(state,commit.delta)
        if moves>0 and only_motion and value.staged_actors.is_empty() and not value.components.any(func(row):return row.kind=="sprite_layer") and not value.actor_tracks.any(func(row):return row.has("visual_loadout")):
            check(value.actor_structure_times.is_empty(),"Actual ordinary movement adds no actor construction boundary")
            ordinary_moves+=moves
    if primary:
        check(sprite_edges>0,"Actual recording covers authored temporary layers")
        check(ordinary_moves>0,"Actual recording covers ordinary movement without structural cuts")
    print("ACTOR_STRUCTURE_RECORDING ",JSON.stringify({"sprite_edges":sprite_edges,"light_edges":light_edges,"ordinary_moves":ordinary_moves}))
    return light_edges
func run()->void:
    var index=Recording.read("res://.runtime/player-runs/20261015T213323.878907Z/journal")
    check(index.ok,"Current baseline recording admits")
    if not index.ok:quit(1);return
    var actor:Dictionary=index.initialization.state.actors[index.initialization.state.audience.controlled[0]]
    pending_state(index,actor);temporary_layers(index,actor);fractional_clock(index);staged_actor(index,actor);recorded(index)
    var lights=Recording.read("res://.runtime/studio-cases/hide-light-schema9-seed3/amber/journal")
    check(lights.ok,"Actual light-source recording admits")
    if lights.ok:check(recorded(lights,false)>0,"Actual recording covers disclosed optical source changes")
    print("ACTOR_STRUCTURAL_CUTS ",JSON.stringify({"checks":checks,"failures":failures,"scope":"Private actor cut state, transient selectors, staged admission and cumulative replay; real compiler source edges and ordinary movement. No native graphics qualification."}))
    quit(0 if failures.is_empty() else 1)
