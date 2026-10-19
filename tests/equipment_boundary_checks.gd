extends SceneTree
## A real commit cannot outrun its actor-structure publication edge at a fractional cue.
const Timeline=preload("res://presentation/timeline.gd")
const Reducer=preload("res://sdk/reducer.gd")
var passed=0
var failures:Array=[]
func _initialize()->void:call_deferred("run")
func check(value:bool,message:String)->void:
    if value:passed+=1
    else:failures.append(message);print("FAIL "+message)
func run()->void:
    var document:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/schema16/fold/v1_a_first_record_carries_the_birth_held_from_then_on.json"))
    for start in [0.0,18095.123456789]:
        for gap in [0.0,0.0000001,0.0000009]:
            var timeline=Timeline.new();timeline.state=document.steps[0].expected.duplicate(true);timeline.display_ms=start;timeline.initialization_revision=1;timeline.world_revision=1;timeline.revision=1;timeline.source_cut_boundaries=false
            var actor_id:String=timeline.state.actors.keys()[0];var before:Dictionary=timeline.state.actors[actor_id];var after:Dictionary=before.duplicate();after.visual_loadout=before.visual_loadout.duplicate();after.visual_loadout.layers=[]
            var cue=1000.0/9.0;var delta=Reducer.Transitions.empty_delta();delta.actors[actor_id]=after
            var group={"id":"equip-fractional","operation_sequence":1,"duration_ms":200.0,"events":[],"actor_tracks":[],"components":[],"commits":[{"at_ms":cue,"delta":delta}],"actor_structure_times":[cue],"actor_source_times":[],"actor_effect_times":[],"staged_actors":{},"staged_tiles":{},"operation_end":true}
            timeline.queue=[group];var prepared:Array=[];var published:Array=[]
            timeline.world_ready=func(candidate):prepared.append(candidate);return true
            timeline.world_published=func(candidate):published.append(candidate);return false
            var forecast=timeline.preview_world()
            check(not forecast.is_empty() and forecast.state.actors[actor_id].visual_loadout.layers.is_empty(),"Exact future outfit is available for preparation before fractional cue")
            check(timeline.state.actors[actor_id]==before,"Preparation forecast cannot publish future equipment")
            timeline.advance(cue-gap)
            check(prepared.size()==1 and published.size()==1,"Due equipment commit uses its prepared structural publication at fractional cue "+str(start)+":"+str(gap))
            check(not prepared.is_empty() and is_same(prepared[0],forecast),"Publication adopts the exact earlier prepared candidate")
            check(timeline.state.actors[actor_id].visual_loadout.layers.is_empty() and absf(timeline.display_ms-start-cue)<0.000001,"New outfit publishes at the authored boundary")
            check(not timeline.waiting_for_world and not timeline.waiting_for_media,"Already prepared equipment does not add a presentation hold")
    print(JSON.stringify({"passed":passed,"failures":failures}));quit(0 if failures.is_empty() else 1)
