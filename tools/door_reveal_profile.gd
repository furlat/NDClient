extends SceneTree
## Door reveal profile: the Gallery journal through the live Play path (no
## external playback), each recorded operation released only once the previous
## one has finished playing and the display has settled, as a click would.
## Writes the recorded frames from each release to the end of its playback.
## Usage: godot --path . --script res://tools/door_reveal_profile.gd -- --recording <journal> [--out res://.captures/door.json] [--settle-ms 1500] [--last 2]
const Player=preload("res://play.tscn")
const Session=preload("res://presentation/session.gd")
class GatedSession extends Session:
    var released:int=1
    var held:Array=[]
    func take_prepared()->Array:
        held.append_array(super.take_prepared())
        var result:Array=[]
        while not held.is_empty() and int(held[0].get("sequence",0))<=released:result.append(held.pop_front())
        return result
var out:String="res://.captures/door_reveal_profile.json"
var settle_ms:float=1500.0
var last:int=2
func _initialize()->void:run.call_deferred()
func run()->void:
    var args:=OS.get_cmdline_user_args()
    for i in args.size()-1:
        if args[i]=="--out":out=args[i+1]
        if args[i]=="--settle-ms":settle_ms=args[i+1].to_float()
        if args[i]=="--last":last=args[i+1].to_int()
    var scene=Player.instantiate()
    var session=GatedSession.new();scene.session=session
    scene.profile.recording=true
    root.add_child(scene)
    var deadline:int=Time.get_ticks_msec()+180000
    while (scene.world_revision<0 or not session.recording_ready) and session.issue.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
    var releases:Array=[]
    while session.released<mini(last,session.latest_sequence) and Time.get_ticks_msec()<deadline and scene.media_issue.is_empty():
        # Settled: nothing playing or queued, every received operation shown.
        var idle_since:int=Time.get_ticks_msec()
        while Time.get_ticks_msec()-idle_since<settle_ms and Time.get_ticks_msec()<deadline:
            await process_frame
            if scene.timeline.busy() or scene.pending_world!=null:idle_since=Time.get_ticks_msec()
        session.released+=1
        releases.append({"sequence":session.released,"frame":Engine.get_process_frames(),"usec":Time.get_ticks_usec()})
        scene.profile.recorded.clear()
        while (session.held.any(func(m):return int(m.get("sequence",0))<=session.released) or scene.timeline.sequence<session.released or scene.timeline.busy()) and Time.get_ticks_msec()<deadline:await process_frame
        for i in 30:await process_frame
        releases.back().frames=scene.profile.recorded.duplicate()
        print("DOOR_PROFILE_RELEASED ",session.released," frames=",releases.back().frames.size())
    var file=FileAccess.open(out,FileAccess.WRITE)
    file.store_string(JSON.stringify({"releases":releases,"errors":scene.presentation_errors,"media_issue":scene.media_issue}))
    file.close()
    print("DOOR_PROFILE_DONE ",out," errors=",scene.presentation_errors," issue=",scene.media_issue)
    scene.queue_free();await process_frame
    quit(0)
