extends SceneTree
## Plays one Studio case in real time, twice, and prints every slow frame with
## its largest Player phases, new pipeline compilations and node growth. A cost
## present only in the first pass is first-use work (compilation, construction).
## Usage: --script res://tools/first_use_probe.gd -- [--case=magic_missile-seed3] [--perspective=amber]
const Studio=preload("res://studio/studio.gd")
const Profile=preload("res://frame_profile.gd")
const SLOW_MS:=10.0

var studio
var case_name:="magic_missile-seed3"
var perspective:="amber"

func _initialize()->void:run.call_deferred()

func argument(name:String,fallback:String)->String:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with(name+"="):return arg.trim_prefix(name+"=")
    return fallback

func settled()->bool:
    return not studio.index.is_empty() and studio.loader==null and studio.seeker==null and not studio.installing and studio.requested_seek<0

func wait_settled()->bool:
    var deadline:=Time.get_ticks_msec()+120000
    while not settled() and Time.get_ticks_msec()<deadline:await process_frame
    return settled()

func pipelines()->int:
    var counts:Dictionary=Profile.pipeline_compilations()
    var total:=0
    for value in counts.values():total+=int(value)
    return total

func play_pass(label:String)->void:
    studio._seek(0.0)
    await wait_settled()
    studio.world.profile.recording=true
    studio.loop_enabled=false;studio._play_study()
    var deadline:=Time.get_ticks_msec()+40000
    var last:=Time.get_ticks_usec();var compiled:=pipelines()
    var nodes:=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
    var intervals:=[];var slow:=[]
    while Time.get_ticks_msec()<deadline:
        await process_frame
        var now:=Time.get_ticks_usec();var interval:=(now-last)/1000.0;last=now
        intervals.append(interval)
        var compiled_now:=pipelines();var nodes_now:=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
        if interval>=SLOW_MS:
            var frames:Array=studio.world.profile.frames
            var sample:Dictionary=frames[posmod(studio.world.profile.cursor-1,frames.size())] if not frames.is_empty() else {}
            var phases:Dictionary=sample.get("cpu_ms",{})
            var top:=phases.keys();top.sort_custom(func(a,b):return phases[a]>phases[b])
            var named:={}
            for key in top.slice(0,10):named[key]=snappedf(phases[key],0.01)
            slow.append({"display_ms":snappedf(studio.world.timeline.display_ms,1),"interval_ms":snappedf(interval,0.1),
                "player_ms":snappedf(phases.get("player_process",0.0),0.01),"new_pipelines":compiled_now-compiled,
                "new_nodes":nodes_now-nodes,"top":named})
        compiled=compiled_now;nodes=nodes_now
        if studio.world.timeline.paused and studio.world.timeline.display_ms>0:break
    intervals.sort()
    print("FIRST_USE_PASS ",JSON.stringify({"pass":label,"frames":intervals.size(),"p50":snappedf(intervals[intervals.size()/2],0.1),
        "p95":snappedf(intervals[int(intervals.size()*0.95)],0.1),"max":snappedf(intervals.back(),0.1),"slow":slow.size()}))
    for row in slow:print("FIRST_USE_SLOW ",label," ",JSON.stringify(row))

func run()->void:
    case_name=argument("--case",case_name);perspective=argument("--perspective",perspective)
    root.size=Vector2i(1600,900)
    studio=Studio.new();root.add_child(studio);studio.loop_enabled=false
    await wait_settled()
    var directory:="res://.runtime/studio-cases/%s/%s/journal"%[case_name,perspective]
    studio._load(directory)
    if not await wait_settled():
        print("FIRST_USE_FAIL load ",directory," ",studio.status.text);quit(1);return
    await play_pass("first")
    await play_pass("second")
    quit(0)
