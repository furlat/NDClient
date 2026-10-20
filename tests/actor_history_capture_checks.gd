extends SceneTree
## Logical history from unchanged original Blur journals. These assertions do
## not qualify compositor shaders or GPU pixels. Metadata negatives are private
## value controls, never altered recordings or fabricated positive game facts.
const Recording=preload("res://studio/recording.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
const Timeline=preload("res://presentation/timeline.gd")
const Characters=preload("res://presentation/characters.gd")
const Conditions=preload("res://presentation/conditions.gd")
const Tracks=preload("res://presentation/tracks.gd")
var checks:int=0
var failures:Array=[]
var evidence:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("ACTOR_HISTORY_CAPTURE_FAIL ",label)
func run()->void:
    for seat in ["amber","blue"]:inspect_seat(seat)
    print("ACTOR_HISTORY_CAPTURE ",JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence,
        "scope":"Both untouched schema16 Blur cast/attack/move/removal journals, exact logical prefix samples, ordered publication, visibility negatives and bounded retirement. Actual compositor output is a separate native gate."}))
    quit(0 if failures.is_empty() else 1)
func inspect_seat(seat:String)->void:
    var index:Dictionary=Fixtures.read("blur",seat)
    check(index.ok,seat+": unchanged original Blur journal reads")
    if not index.ok:return
    var original:PackedByteArray=var_to_bytes([index.initialization,index.groups,index.rows])
    var spans:Array=index.rows.filter(func(row):return row.kind=="condition" and row.get("owner",{}).get("condition",{}).get("behavior_id")=="condition.spell.blur")
    check(spans.size()==1,seat+": one actual Blur UUID application and removal")
    if spans.size()!=1:return
    var span:Dictionary=spans[0];var actor:String=span.owner.actor_uuid;var owner:String=span.owner.id
    var recipe:Dictionary=Conditions.recipe(span.owner.condition,index.cache)
    check(is_equal_approx(float(recipe.persistent.actorHistory.windowSeconds),.24),seat+": actual typed recipe declares the bounded history window")
    var selected:Dictionary={}
    for item in index.groups:
        for track in item.group.actor_tracks:
            var start:float=float(item.start_ms)+float(track.start_ms)
            if track.actor_uuid==actor and track.get("motion",false) and start>=float(span.start_ms) and start<float(span.end_ms):
                selected={"item":item,"track":track,"start":start};break
        if not selected.is_empty():break
    check(not selected.is_empty(),seat+": original recording contains actual held-owner movement")
    if selected.is_empty():return
    var target:float=float(selected.start)+float(selected.track.duration_ms)*.8
    var timeline:RefCounted=Recording.restore(index,target)
    var delays:Array=[0.0,.08,.16,.24]
    for frame in range(1,15):delays.append(float(frame)/60.0)
    var observed:Dictionary=timeline.history_captures(actor,owner,target,delays)
    check(observed.ready,seat+": held move has authentic prefix captures: "+str(observed.get("reason")))
    if not observed.ready:return
    check(observed.captures.size()>4,seat+": actual frame/cut samples supplement the three delayed endpoints")
    var previous:float=-INF;var positions:Array=[]
    for capture in observed.captures:
        check(capture.actor_uuid==actor and capture.condition_uuid==owner and capture.admitted_at_ms==span.start_ms,seat+": every sample keeps the actual actor, UUID and original admission clock")
        check(capture.sample_ms>previous and capture.sample_ms<=target and capture.sample_ms>=span.start_ms,seat+": history is ordered, unique and never borrowed from future/before admission")
        previous=capture.sample_ms
        check(capture.is_read_only() and capture.departure.is_read_only() and capture.departure.row.is_read_only(),seat+": logical history and physical row operands are immutable")
        var exact:RefCounted=Recording.restore(index,float(capture.sample_ms))
        var expected:Dictionary=exact.actor_samples().get(actor,{})
        var rig:Dictionary=Characters.rigs(index.cache)[capture.rig]
        var canonical:Dictionary=exact.state.actors[actor]
        var rest:Dictionary=Characters.rest_sample(canonical,rig,index.cache).value
        var condition_pose:Dictionary=Conditions.pose(canonical,capture.rig,index.cache,exact.condition_owners)
        var source:Dictionary=Conditions.ConditionPose.body_sample(rest,canonical.life_state,rig,condition_pose,expected,float(capture.sample_ms),0.0)
        var clip:Dictionary=rig.clips[source.clip]
        var seconds:float=Tracks.sample_seconds(source.source_seconds,float(clip.frames)/float(clip.fps),Tracks.character_loops(rig,source.clip))
        check(capture.clip==source.clip and capture.frame==mini(int(seconds*clip.fps),int(clip.frames)-1) and capture.source_seconds==source.source_seconds,seat+": clip/frame/source clock equal the independent original-prefix body sample")
        var position:Array=expected.get("position",canonical.last_visual_position)
        check(capture.departure.row.position==position,seat+": historical world position is the original movement sample, never the current body")
        check(capture.departure.actor.appearance==canonical.appearance,seat+": actual old appearance remains attached to its own sample")
        check(capture.departure.item_looks==Characters.item_looks(capture.departure.actor,exact.state),seat+": item looks come from that original prefix")
        positions.append(capture.departure.row.position)
    check(positions.front()!=positions.back(),seat+": rolling captures retain actual motion instead of painting the same present pose at past times")
    for delay in [.08,.16,.24]:
        var at:float=target-delay*1000.0
        if at>=observed.available_from_ms:check(observed.captures.any(func(capture):return is_equal_approx(capture.sample_ms,at)),seat+": exact authored delay endpoint is retained")
    var captured_bytes:PackedByteArray=var_to_bytes(observed.captures)
    check(not timeline.history_captures(actor,owner,target+1.0,delays).ready,seat+": received but unpublished future history is unavailable")
    check(not timeline.history_captures(actor,"not-an-observed-owner",target,delays).ready,seat+": an unrelated condition identity cannot borrow a body history")
    var cuts_before:PackedByteArray=var_to_bytes(timeline.actor_history_cuts)
    var plan:Dictionary=timeline.replay_plan(target+20.0)
    timeline._world_candidate(plan)
    check(var_to_bytes(timeline.actor_history_cuts)==cuts_before,seat+": speculative world preparation cannot publish future historical cuts")
    var initial:RefCounted=Recording.restore(index,float(span.start_ms)+.001)
    var newborn:Dictionary=initial.history_captures(actor,owner,initial.display_ms,delays)
    check(newborn.ready and not newborn.complete_window and newborn.captures.all(func(capture):return capture.sample_ms>=span.start_ms),seat+": early contours have only observed samples and explicitly incomplete delayed prehistory")
    var published:=Timeline.new();published.appearance_cache=index.cache
    var initialization:Dictionary=index.initialization.duplicate();initialization.state=index.initialization.state.duplicate(true)
    published.accept(initialization);published.accept({"kind":"operation","groups":index.groups.map(func(item):return item.group)})
    for step in 1000:
        if published.display_ms>=target:break
        var next:Dictionary=published.replay_plan(target)
        var accepted:bool=published.replay_prepare(next) and published.replay_publish(next)
        check(accepted,seat+": ordinary prepared prefix publishes atomically")
        if not accepted:break
    var prepared:Dictionary=published.history_captures(actor,owner,target,delays)
    check(prepared.ready and var_to_bytes(prepared.captures)==captured_bytes,seat+": prepared publication and direct original replay retain identical logical histories")
    # Private admission negatives, not alternative recorded game outcomes.
    var retained:Dictionary=timeline.actor_history_cuts[actor]
    var original_cuts:Array=retained.cuts
    check(range(1,original_cuts.size()).all(func(at):return float(original_cuts[at].at_ms)>target-.24*1000.0),seat+": retention keeps only the requested window plus one actual predecessor")
    if original_cuts.size()>1:
        var gap:Array=original_cuts.duplicate()
        var negative:Dictionary=gap[-2].duplicate(false);negative.visible=false;gap[-2]=negative
        retained.cuts=gap
        var disclosed:Dictionary=timeline.history_captures(actor,owner,target,delays)
        var reopened:float=float(original_cuts[-1].at_ms)
        check(disclosed.ready and disclosed.captures.all(func(capture):return capture.sample_ms>=reopened),seat+": after a private visibility-gap negative, only the next actual disclosed cut can reopen history")
    var hidden:Array=original_cuts.duplicate();var hidden_cut:Dictionary=hidden.back().duplicate(false)
    hidden_cut.visible=false;hidden[-1]=hidden_cut;retained.cuts=hidden
    check(not timeline.history_captures(actor,owner,target,delays).ready,seat+": remembered-but-not-currently-visible actor cuts cannot seed the compositor")
    retained.cuts=original_cuts
    timeline.paused=false;timeline.advance(index.presentation_end_ms+1000.0-timeline.display_ms)
    check(timeline.actor_history_cuts.is_empty(),seat+": actual removal and completed fade retire the bounded history owner")
    check(var_to_bytes(observed.captures)==captured_bytes,seat+": later publication/retirement cannot mutate an earlier returned capture")
    check(var_to_bytes([index.initialization,index.groups,index.rows])==original,seat+": every original recording/compiled row remains byte-identical")
    evidence.append({"seat":seat,"actor_uuid":actor,"condition_uuid":owner,"move_at_ms":target,"capture_count":observed.captures.size(),"available_from_ms":observed.available_from_ms})
