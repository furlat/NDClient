extends SceneTree
## Plays one Studio case in real time and prints the painter-order phases per
## frame: while the recording plays, then while the finished view stays idle,
## with the offset writes of each part. --overlay=N replays the Gallery run's
## recorded ground previews (route, Fireball areas, clear at a move) N times.
## Usage: --script res://tools/draw_order_probe.gd -- [--case=dash-seed3] [--perspective=amber] [--idle=240] [--journal=res://...] [--overlay=N] [--top=N]
const Studio=preload("res://studio/studio.gd")
const Profile=preload("res://frame_profile.gd")
const PHASES:=["draw_order","draw_sort","native_2d_output","ground_overlay_sync","ground_overlay_support_check","ground_overlay_mark_update",
    "static_order","ground_overlay_merge","actor_order","draw_rank_apply","mask_sync"]

var studio

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

func summary(rows:Array)->Dictionary:
    var result:={"frames":rows.size()}
    for name in PHASES:
        var values:=rows.map(func(phases):return float(phases.get(name,0.0)))
        if values.is_empty():continue
        var stats:=Profile.distribution(values)
        result[name]={"mean":snappedf(stats.mean,0.001),"p50":snappedf(stats.p50,0.001),"p95":snappedf(stats.p95,0.001),"max":snappedf(stats.max,0.001)}
    result.dirty_frames=rows.filter(func(phases):return phases.has("draw_rank_apply")).size()
    return result

func latest()->Dictionary:
    var frames:Array=studio.world.profile.frames
    return frames[posmod(studio.world.profile.cursor-1,frames.size())].get("cpu_ms",{}) if not frames.is_empty() else {}

func mark(marks:Dictionary,position:Array,colour:Color,width:float=2.0)->void:
    marks["%d,%d"%[position[0],position[1]]]={"colour":colour,"width":width}

# Ground previews as the HUD builds them (play_hud.gd _sync_ground_preview):
# reachable cells, recorded route and Fireball area previews, cleared at a move.
func overlay_steps()->Array:
    var world=studio.world
    var current:Dictionary=world.actor_rows[0] if not world.actor_rows.is_empty() else {"position":[0,0]}
    var centre:Array=[roundi(current.position[0]),roundi(current.position[1])]
    var tiles:Dictionary=world.timeline.presentation_state().tiles
    var reachable:={}
    for key in tiles:
        var p:Array=tiles[key].position
        if maxi(absi(int(p[0])-centre[0]),absi(int(p[1])-centre[1]))<=6:mark(reachable,p,Color(0.45,0.83,0.76,0.24),1.0)
    var steps:=[]
    for file in ["fireball-hover-4.json","fireball-hover-5.json"]:
        var recorded:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://.runtime/player-runs/20261017T050051.313612Z/"+file))
        for item in recorded.previews:
            var preview:Dictionary=item.preview
            var marks:Dictionary=reachable.duplicate(true) if preview.get("selected_route")!=null else {}
            for position in preview.get("positions",[]):
                mark(marks,position,Color(0.92,0.73,0.36,0.8))
                if preview.get("area_preview")=="computed":marks["%d,%d"%[position[0],position[1]]].fill_colour=Color(0.92,0.59,0.23,0.2)
            mark(marks,current.position,Color("e9c87e"));mark(marks,item.hover_position,Color("70d6be"))
            var route=preview.get("selected_route")
            steps.append({"label":"route" if route!=null else "area","marks":marks,"route":route.path if route!=null else []})
        steps.append({"label":"clear","marks":{},"route":[]})
    return steps

func overlay_bench(cycles:int)->void:
    var steps:=overlay_steps()
    var rows:={}
    for cycle in cycles:
        for step in steps:
            studio.world.ground_overlay.set_preview(step.marks,step.route,Color("70d6be"))
            await process_frame
            var phases:=latest()
            await process_frame
            if not rows.has(step.label):rows[step.label]=[]
            rows[step.label].append(phases)
    for label in rows:print("DRAW_ORDER_OVERLAY ",label," ",JSON.stringify(summary(rows[label])))

func run()->void:
    var case_name:=argument("--case","dash-seed3");var perspective:=argument("--perspective","amber")
    var idle_frames:=int(argument("--idle","240"))
    root.size=Vector2i(1600,900)
    studio=Studio.new();root.add_child(studio);studio.loop_enabled=false
    await wait_settled()
    var directory:=argument("--journal","res://.runtime/studio-cases/%s/%s/journal"%[case_name,perspective])
    studio._load(directory)
    if not await wait_settled():
        print("DRAW_ORDER_PROBE_FAIL load ",directory," ",studio.status.text);quit(1);return
    studio._seek(0.0)
    await wait_settled()
    for i in 30:await process_frame
    studio.world.profile.recording=true
    studio._play_study()
    var playing:=[];var updates_before:int=studio.world.draw_rank_updates
    var deadline:=Time.get_ticks_msec()+60000
    while Time.get_ticks_msec()<deadline:
        await process_frame
        playing.append(latest())
        if studio.world.timeline.paused and studio.world.timeline.display_ms>0:break
    var updates_playing:int=studio.world.draw_rank_updates-updates_before
    for i in 30:await process_frame
    var idle:=[];updates_before=studio.world.draw_rank_updates
    for i in idle_frames:
        await process_frame
        idle.append(latest())
    var updates_idle:int=studio.world.draw_rank_updates-updates_before
    if int(argument("--overlay","0"))>0:await overlay_bench(int(argument("--overlay","0")))
    var heavy:=playing.duplicate();heavy.sort_custom(func(a,b):return float(a.get("draw_sort",0.0))>float(b.get("draw_sort",0.0)))
    for phases in heavy.slice(0,int(argument("--top","6"))):
        var named:={}
        for name in PHASES:if phases.has(name):named[name]=snappedf(phases[name],0.001)
        print("DRAW_ORDER_HEAVY ",JSON.stringify(named))
    print("DRAW_ORDER_PROBE ",JSON.stringify({"case":directory,"actor_entries":studio.world.actor_entries.size(),"statics":studio.world.static_entries.size(),
        "playing":summary(playing),"rank_updates_playing":updates_playing,"idle":summary(idle),"rank_updates_idle":updates_idle}))
    quit(0)
