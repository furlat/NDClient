extends SceneTree
## Actual first disclosures and support rows from original schema16 journals.
## No fabricated observations, reordered world updates or imported wire shapes.
const Fixtures=preload("res://tests/recording_fixtures.gd")
const Recording=preload("res://studio/recording.gd")
const Compiler=preload("res://presentation/compiler.gd")
const Timeline=preload("res://presentation/timeline.gd")
const Characters=preload("res://presentation/characters.gd")
const Reducer=preload("res://sdk/reducer.gd")
var checks:int=0
var failures:Array=[]
var evidence={"groups":0,"actors":0,"tiles":0,"precommit_actors":0,"precommit_tiles":0,"resolved_support":0,"sampled_support":0}
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("STAGING_FIXTURE_FAIL ",label)
func _initialize()->void:
    for name in ["gallery","door","invisibility"]:
        for seat in ["amber","blue"]:
            var index:Dictionary=Fixtures.read(name,seat)
            check(index.ok,"Original schema16 staging recording admits: "+name+" / "+seat)
            if not index.ok:continue
            inspect(index,name+" / "+seat)
    check(evidence.actors>0 and evidence.tiles>0,"Actual recordings contain newly disclosed actors and terrain")
    check(evidence.precommit_actors>0 and evidence.precommit_tiles>0,"Actual staging exposes actor/support before their canonical commit")
    check(evidence.resolved_support>0 and evidence.sampled_support>0,"Actual staged sources resolve and sample against authoritative elevation")
    print("PRESENTATION_STAGING_BOUNDARY_FIXTURE ",JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
    quit(0 if failures.is_empty() else 1)
func inspect(index:Dictionary,label:String)->void:
    var before:Dictionary=index.initialization.state
    for item in index.groups:
        # Isolate the original compiled group at its own zero clock. The
        # recording's absolute queue offset is transport metadata; all local
        # authored admissions/commits and native facts remain unchanged.
        var group:Dictionary=item.group.duplicate();group.erase("preview_start_ms")
        var expected:Dictionary=before.duplicate(true)
        for commit in group.commits:Compiler.apply_delta(expected,commit.delta)
        var actual=Timeline.new()
        var initial:Dictionary=index.initialization.duplicate();initial.state=before.duplicate(true)
        actual.accept(initial);actual.accept({"kind":"operation","groups":[group]})
        var cuts:Dictionary={0.0:true}
        for id in group.staged_actors:
            evidence.actors+=1
            check(not before.actors.has(id),label+": staged actor is genuinely absent from the original canonical prefix")
            cuts[float(group.staged_at_ms[id])]=true
        for key in group.staged_tiles:
            evidence.tiles+=1
            check(not before.tiles.has(key),label+": staging never replaces existing canonical support")
            cuts[float(group.staged_tile_at_ms[key])]=true
        var ordered:Array=cuts.keys();ordered.sort()
        for at in ordered:
            # A cut at the terminal commit belongs to canonical state; private
            # staging exists only during the real group's presentation interval.
            if at>=group.duration_ms:continue
            var plan:Dictionary=actual.replay_plan(at)
            actual._apply_world_plan(plan)
            var staged_actors:Dictionary=actual.staged_actors()
            var staged_tiles:Dictionary=actual.staged_tiles()
            var samples:Dictionary=actual.actor_samples()
            for id in staged_actors:
                check(staged_actors[id]==group.staged_actors[id],label+": staged actor is the exact captured first-disclosure row")
                if not actual.state.actors.has(id):
                    evidence.precommit_actors+=1
                    check(not actual.presentation_state().actors.has(id),label+": private actor membership remains separate from canonical state and terrain projection")
                var actor:Dictionary=staged_actors[id]
                if actor.last_visual_position==null:continue
                var key:String=Reducer.Audience.point_key(actor.last_visual_position)
                var support:Dictionary=actual.presentation_state().tiles.get(key,{})
                if support.is_empty():continue
                var resolved:Dictionary=Characters.resolve(actor,actual.presentation_state(),index.cache)
                check(resolved.ok and resolved.value!=null,label+": original authored actor resolves against captured support")
                if not resolved.ok or resolved.value==null:continue
                evidence.resolved_support+=1
                check(resolved.value.base_height_steps==support.elevation_steps,label+": staged source retains exact server elevation")
                if samples.has(id):
                    evidence.sampled_support+=1
                    check(is_equal_approx(samples[id].base_height_steps,support.elevation_steps),label+": actor animation sample uses captured support elevation")
                if group.staged_tiles.has(key):
                    check(group.staged_tile_at_ms[key]<=group.staged_at_ms[id],label+": new support is available by the actor's first presentation")
            for key in staged_tiles:
                check(staged_tiles[key]==group.staged_tiles[key],label+": private terrain is the exact captured world after-value")
                if not actual.state.tiles.has(key):
                    evidence.precommit_tiles+=1
                    check(actual.presentation_state().tiles[key]==staged_tiles[key],label+": support staging does not consume the canonical world commit")
        actual.advance(group.duration_ms+1000.0)
        check(actual.state==expected,label+": canonical final group state remains the exact ordered commit fold")
        before=expected;evidence.groups+=1
