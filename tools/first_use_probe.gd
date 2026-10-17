extends SceneTree
## Plays one Studio case in real time, twice, and prints every slow frame with
## its largest Player phases, new pipeline compilations and node growth. A cost
## present only in the first pass is first-use work (compilation, construction).
## Usage: --script res://tools/first_use_probe.gd -- [--case=magic_missile-seed3] [--perspective=amber]
## [--thumbnails=off] suspends Studio's timeline thumbnails (their own spell
## previews), leaving only the live presentation the game also runs.
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
    while not settled() and Time.get_ticks_msec()<deadline:
        await process_frame
        if studio.tracks!=null:quiet_thumbnails()
    return settled()

func pipelines()->int:
    var counts:Dictionary=Profile.pipeline_compilations()
    var total:=0
    for value in counts.values():total+=int(value)
    return total

func quiet_thumbnails()->void:
    if argument("--thumbnails","on")!="off":return
    for tracks in [studio.tracks,studio.candidate_tracks]:
        if tracks!=null:tracks.thumbnails.suspended=true;tracks.thumbnails.prewarm_suspended=true

func play_pass(label:String)->void:
    quiet_thumbnails()
    studio._seek(0.0)
    await wait_settled()
    studio.world.profile.recording=true
    studio.loop_enabled=false;studio._play_study()
    var deadline:=Time.get_ticks_msec()+40000
    var last:=Time.get_ticks_usec();var compiled:=pipelines();var categories:Dictionary=Profile.pipeline_compilations()
    var nodes:=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
    var intervals:=[];var slow:=[];var fast:=[];var window:={};var window_frames:=0
    var descriptor_usec:=int(studio.tracks.thumbnails.native_store.descriptor_usec)
    var known_views:={}
    for view in root.find_children("*","SubViewport",true,false):known_views[view.get_instance_id()]=true
    var window_from:=float(argument("--window-from","-1"));var window_to:=float(argument("--window-to","-1"))
    while Time.get_ticks_msec()<deadline:
        await process_frame
        quiet_thumbnails()
        var now:=Time.get_ticks_usec();var interval:=(now-last)/1000.0;last=now
        intervals.append(interval)
        var compiled_now:=pipelines();var nodes_now:=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
        var categories_now:Dictionary=Profile.pipeline_compilations();var category_delta:={}
        for key in categories_now:
            if int(categories_now[key])!=int(categories.get(key,0)):category_delta[key]=int(categories_now[key])-int(categories.get(key,0))
        categories=categories_now
        var descriptor_now:=int(studio.tracks.thumbnails.native_store.descriptor_usec)
        var descriptor_ms:=(descriptor_now-descriptor_usec)/1000.0;descriptor_usec=descriptor_now
        if interval>=SLOW_MS:
            var frames:Array=studio.world.profile.frames
            var sample:Dictionary=frames[posmod(studio.world.profile.cursor-1,frames.size())] if not frames.is_empty() else {}
            var phases:Dictionary=sample.get("cpu_ms",{})
            var top:=phases.keys();top.sort_custom(func(a,b):return phases[a]>phases[b])
            var named:={}
            for key in top.slice(0,10):named[key]=snappedf(phases[key],0.01)
            var viewports:=root.find_children("*","SubViewport",true,false)
            var fresh:={}
            for view in viewports:
                if not known_views.has(view.get_instance_id()):
                    var owner_name:String=str(view.get_parent().name) if view.get_parent()!=null else "-"
                    var key:String=owner_name+"/"+str(view.name).rstrip("0123456789")
                    fresh[key]=fresh.get(key,0)+1
            var updating:=viewports.filter(func(view):return view.render_target_update_mode!=SubViewport.UPDATE_DISABLED).size()
            slow.append({"display_ms":snappedf(studio.world.timeline.display_ms,1),"interval_ms":snappedf(interval,0.1),
                "player_ms":snappedf(phases.get("player_process",0.0),0.01),"new_pipelines":compiled_now-compiled,"pipeline_kinds":category_delta,
                "lights":studio.world.light_table.count,"shadow_actors":studio.world.generated_shadows.actors.size(),
                "shadow_rendered":studio.world.generated_shadows.actors.values().filter(func(state):return state.viewport.render_target_update_mode!=SubViewport.UPDATE_DISABLED).size(),
                "new_nodes":nodes_now-nodes,"process_ms":snappedf(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0,0.1),
                "render_setup_ms":snappedf(RenderingServer.get_frame_setup_time_cpu(),0.1),
                "viewports":viewports.size(),"updating_viewports":updating,"new_viewports":fresh,"top":named,
                "studio_thumbnail_descriptor_ms":snappedf(descriptor_ms,0.01)})
        if interval<SLOW_MS and not category_delta.is_empty():
            fast.append({"display_ms":snappedf(studio.world.timeline.display_ms,1),"interval_ms":snappedf(interval,0.1),"pipeline_kinds":category_delta})
        compiled=compiled_now;nodes=nodes_now
        if interval>=SLOW_MS:
            known_views={}
            for view in root.find_children("*","SubViewport",true,false):known_views[view.get_instance_id()]=true
        var shown:float=studio.world.timeline.display_ms
        if shown>=window_from and shown<=window_to and not studio.world.profile.frames.is_empty():
            var frames:Array=studio.world.profile.frames
            var phases:Dictionary=frames[posmod(studio.world.profile.cursor-1,frames.size())].get("cpu_ms",{})
            for key in phases:window[key]=window.get(key,0.0)+phases[key]
            window_frames+=1
        if studio.world.timeline.paused and studio.world.timeline.display_ms>0:break
    intervals.sort()
    print("FIRST_USE_PASS ",JSON.stringify({"pass":label,"frames":intervals.size(),"p50":snappedf(intervals[intervals.size()/2],0.1),
        "p95":snappedf(intervals[int(intervals.size()*0.95)],0.1),"max":snappedf(intervals.back(),0.1),"slow":slow.size()}))
    for row in slow:print("FIRST_USE_SLOW ",label," ",JSON.stringify(row))
    # Compilations in frames that stayed under SLOW_MS (background work).
    for row in fast:print("FIRST_USE_COMPILED ",label," ",JSON.stringify(row))
    var startup:Dictionary=studio.world.native_startup
    print("FIRST_USE_STARTUP ",label," ",JSON.stringify({"completed":startup.get("completed",0),"total":startup.get("total",0),"construction_ms":startup.get("construction_ms",[]).map(func(row):return [row.source,snappedf(row.ms,0.01),row.get("phases",{})])}))
    if window_frames>0:
        var keys:=window.keys();keys.sort_custom(func(a,b):return window[a]>window[b])
        var mean:={}
        for key in keys.slice(0,40):mean[key]=snappedf(window[key]/window_frames,0.01)
        print("FIRST_USE_WINDOW ",label," frames=",window_frames," ",JSON.stringify(mean))

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
