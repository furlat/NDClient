extends SceneTree
const Recording=preload("res://studio/recording.gd")
const Media=preload("res://presentation/media_warmup.gd")
const Characters=preload("res://presentation/characters.gd")
const Compiler=preload("res://presentation/compiler.gd")
const Player=preload("res://play.gd")
var checks:int=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr(label)
func ready_gate(state:Dictionary,group:Dictionary,plan:Dictionary,schedule:Dictionary,at_ms:float)->void:
    var host=Player.new()
    # The recording wrapper spaces groups on a global Studio clock. This
    # isolated active group starts at zero without changing its local cues.
    group=group.duplicate();group.erase("preview_start_ms")
    host.timeline.state=state.duplicate(true);host.timeline.current=group
    host.media_plan={"required":plan.required,"errors":[]}
    host.media_group_plans[group.id]={"character":plan.required,"character_timeline":schedule}
    host.media_normal_sets=plan.normal_sets
    var initial:Dictionary=host.CharacterGeometry.for_profile(Media.required_at(schedule,0.0),plan.normal_sets,host.character_light_profile)
    for path in initial:host.media_warmup.resident[path]={"gpu_bytes":16,"cpu_bytes":16,"cpu_required":true}
    check(host._character_sources_ready(group,0.0),"Play admits ready windup while later sheets remain cold")
    check(not host._character_sources_ready(group,at_ms),"Play blocks the exact later pose until its sheets publish")
    host.timeline.world_ready=func(_candidate):return true
    host.timeline.media_ready=func(current):return host._character_sources_ready(current,host.timeline.media_target_ms)
    var frozen=var_to_bytes(host.timeline.state)
    host.timeline.advance(at_ms+1.0)
    check(host.timeline.waiting_for_media and host.timeline.display_ms==0.0 and var_to_bytes(host.timeline.state)==frozen,
        "A long frame cannot skip a cold later cue or publish its state")
    var due:Dictionary=host.CharacterGeometry.for_profile(Media.required_at(schedule,at_ms+1.0),plan.normal_sets,host.character_light_profile)
    for path in due:host.media_warmup.resident[path]={"gpu_bytes":16,"cpu_bytes":16,"cpu_required":true}
    check(host._character_sources_ready(group,at_ms+1.0),"Publishing exact due sheets releases the retained source gate")
    host.native_media_paths={"native-required":true}
    check(not host._character_sources_ready(group,0.0),"Native optical CPU/image requirements remain independent of character cue readiness")
    host.native_media_paths={};host.media_condition_paths={"condition-required":true}
    check(not host._character_sources_ready(group,0.0),"Displayed persistent condition paths remain independently pinned and required")
    host.timeline.media_ready=Callable();host.timeline.world_ready=Callable()
    Media.close(host.media_warmup);host.context_menu.free();host.free()
func run()->void:
    var index=Recording.read("res://.runtime/player-runs/20261015T213323.878907Z/journal")
    check(index.ok,"Current-schema live recording admits")
    if not index.ok:quit(1);return
    var state:Dictionary=index.initialization.state.duplicate(true)
    var cache:Dictionary={};var later_hits:int=0;var exact_cues:int=0;var zero_time:int=0
    for item in index.groups:
        var group:Dictionary=item.group
        var frozen_state=var_to_bytes(state);var frozen_group=var_to_bytes(group)
        var baseline:Dictionary=Media.plan(state,[],cache)
        var plan:Dictionary=Media.plan(state,[group],cache)
        var schedule:Dictionary=plan.character_timeline[group.id]
        var initial:Dictionary=Media.required_at(schedule,0.0)
        check(baseline.required.keys().all(func(path):return initial.has(path)),"Current displayed resting/condition sources remain ready at group entry")
        check(schedule.initial.is_read_only() and schedule.changes.all(func(change):return change.paths.is_read_only()),
            "First-use tables publish immutable path sets")
        check(plan.errors.is_empty(),"Actual group source selection has no authoring errors")
        var previous:Dictionary=initial
        for change in schedule.changes:
            check(previous.keys().all(func(path):return change.paths.has(path)),"Later readiness retains preceding source ownership")
            check(change.paths.keys().all(func(path):return plan.required.has(path)),"Every due source remains demanded in the complete group closure")
            previous=change.paths
        for track in group.actor_tracks:
            var actor:Dictionary=track.presentation_actor.duplicate()
            actor.presentation_layers=track.get("effect_layers",[])
            if track.has("visual_loadout"):actor.visual_loadout=track.visual_loadout
            var exact:Dictionary=Characters.sheet_paths(actor,[track.clip],cache)
            check(exact.ok,"Recorded track resolves its exact authored source outfit")
            if not exact.ok:continue
            var at:Dictionary=Media.required_at(schedule,float(track.start_ms))
            check(exact.value.keys().all(func(path):return at.has(path)),"Every source is ready by its actual authored track cue")
            if track.start_ms==0.0:
                zero_time+=1
                check(exact.value.keys().all(func(path):return initial.has(path)),"Zero-time authored sources join the initial readiness cut")
            if track.start_ms>0 and track.clip in ["TakeDamage","Die"]:
                var late:Array=exact.value.keys().filter(func(path):return not initial.has(path))
                if late.is_empty():continue
                later_hits+=1
                check(late.all(func(path):return plan.required.has(path)),"Later hit/death sheets stay queued while windup can start")
                var before:Dictionary=Media.required_at(schedule,float(track.start_ms)-0.00001)
                if late.any(func(path):return not before.has(path)):
                    exact_cues+=1
                    check(late.any(func(path):return not before.has(path) and at.has(path)),"Cold hit/death source becomes required exactly at its authored cue")
                    if exact_cues==1:ready_gate(state,group,plan,schedule,float(track.start_ms))
        check(var_to_bytes(state)==frozen_state and var_to_bytes(group)==frozen_group,
            "Source requirements leave canonical state and authored occurrence clocks unchanged")
        for commit in group.commits:Compiler.apply_delta(state,commit.delta)
    check(later_hits>0 and exact_cues>0,"Real Fireball reaction tracks exercise cold later sheets and exact readiness cuts")
    check(zero_time>0,"Real recording exercises zero-time character cues")
    var fallback={"fallback":true}
    check(is_same(Media.required_at({},5.0,fallback),fallback),"Unassessed old plans retain complete conservative readiness")
    print("CHARACTER_MEDIA_FIRST_USE_CHECKS ",JSON.stringify({"checks":checks,"failures":failures,
        "later_hits":later_hits,"exact_cues":exact_cues,"zero_time":zero_time}))
    quit(0 if failures.is_empty() else 1)
