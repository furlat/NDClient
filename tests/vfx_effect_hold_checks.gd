extends SceneTree
## Plays real Studio journals from their start in real time and measures the
## spell effects on the way: per occurrence construction, frames over 16.7 ms,
## held frames (the clock waiting for media or world while playing) and
## pipeline compiles while playing (first draws). No effect is constructed by
## this script; it only observes the Studio's own Player.
## --captures=<dir> saves the Studio preview 0.2 s after each effect clip
## first draws (for looking at the effects).
##   -- [--recording=<journal>]... [--report=<res path>] [--captures=<dir>]
const Studio=preload("res://studio/studio.gd")
const FrameProfile=preload("res://frame_profile.gd")
const CASES=["res://.runtime/studio-spells-20261015/fireball-seed3/amber/journal",
    "res://.runtime/studio-spells-20261015/shield-seed3/amber/journal",
    "res://.runtime/gallery-sorcerer-20261015-seed3-door/amber/journal"]
var checks:int=0
var failures:Array=[]
var captures:String=""

func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("VFX_HOLD_FAIL ",label)

func settle(studio:Control,directory:String="")->bool:
    var deadline=Time.get_ticks_msec()+120000
    while (studio.index.is_empty() or studio.loader!=null or studio.seeker!=null or studio.installing or studio.requested_seek>=0) and Time.get_ticks_msec()<deadline:
        await process_frame
    var ready:bool=not studio.index.is_empty() and studio.loader==null and studio.seeker==null and not studio.installing and studio.requested_seek<0
    if not directory.is_empty():ready=ready and studio.active_directory==directory
    check(ready,"Studio installed "+directory+": "+studio.status.text)
    if not ready and studio.candidate_world!=null:
        var candidate:Node=studio.candidate_world
        var group:Dictionary=candidate.timeline.current if not candidate.timeline.current.is_empty() else (candidate.timeline.queue[0] if not candidate.timeline.queue.is_empty() else {})
        print("VFX_HOLD_READY ",JSON.stringify({"state":not candidate.timeline.state.is_empty(),"epoch":candidate.world_prepare_epoch==candidate.timeline.initialization_revision,
            "world":candidate.world_revision==candidate.timeline.world_revision,"media":candidate._media_ready(group),"waiting_world":candidate.timeline.waiting_for_world,
            "components":candidate.component_renderer.ready,"spells":candidate.component_renderer.native_spells.ready,"hits":candidate.component_renderer.native_hits.ready,
            "hit_issues":candidate.component_renderer.native_hits.issues,"hit_pending":candidate.component_renderer.native_hits.pending_occurrences.slice(0,3),"rotation":candidate.rotation_pending()}))
        print("VFX_HOLD_INSTALL ",JSON.stringify({"native_startup":candidate.native_startup,"spells":candidate.component_renderer.native_spells.diagnostics,
            "issues":candidate.component_renderer.native_spells.issues,"errors":candidate.presentation_errors.slice(0,4),"media":candidate.media_issue}).substr(0,4000))
    return ready

static func _compiles(before:Dictionary,after:Dictionary)->int:
    var total:int=0
    for key in after:total+=int(after[key])-int(before.get(key,0))
    return total

func measure(studio:Control,directory:String)->Dictionary:
    studio._load(directory)
    if not await settle(studio,directory):return {"directory":directory,"error":"not installed"}
    var world:Node=studio.world
    var renderer:RefCounted=world.component_renderer.native_spells
    var warm_compiles:Dictionary=FrameProfile.pipeline_compilations()
    studio.loop_enabled=false;studio._play_study()
    if not await settle(studio):return {"directory":directory,"error":"not restarted"}
    var start_compiles:Dictionary=FrameProfile.pipeline_compilations()
    var frames:Array=[];var occurrences:Dictionary={};var seen_drawn:Dictionary={};var holds:Array=[];var shots:Dictionary={}
    var previous:Dictionary=start_compiles;var last:int=Time.get_ticks_usec()
    var deadline:int=Time.get_ticks_msec()+240000
    while not world.timeline.paused and Time.get_ticks_msec()<deadline:
        await process_frame
        var now:int=Time.get_ticks_usec()
        var compiles:Dictionary=FrameProfile.pipeline_compilations()
        var first_draws:Array=[]
        for id in renderer.handles:
            var handle:Dictionary=renderer.handles[id]
            if not occurrences.has(id):
                occurrences[id]={"id":id,"clip":str(handle.get("clip",{}).get("id","")),"kind":str(handle.get("effect_kind","recorded" if handle.get("baked",false) else "native")),
                    "construction_ms":float(handle.get("construction_phases",{}).get("total",handle.get("construction_phases",{}).get("baked_instantiate",0.0))),
                    "phases":handle.get("construction_phases",{}),"constructed_at_ms":world.timeline.display_ms}
            if handle.get("rendered_once",false) and not seen_drawn.has(id):
                seen_drawn[id]=true;first_draws.append(id)
                var clip_id:String=str(handle.get("clip",{}).get("id",""))
                if not captures.is_empty() and not shots.has(clip_id):shots[clip_id]=world.timeline.display_ms+200.0
        var held:bool=world.timeline.waiting_for_media or world.timeline.waiting_for_world
        if held:
            # The media gate names what the group still waits for (native effects included).
            var gate:Dictionary=world.media_gate
            var waiting:Array=gate.keys().filter(func(key):return gate[key] is bool and gate[key]==(key=="admitted_world_pending"))
            var reason:String=("world" if world.timeline.waiting_for_world else "media")+" "+str(waiting)+" initial="+str(world.media_initial_ready)+" native_startup="+str(world.native_startup.get("ready",true))+" "+str(world.media_issue)+(" "+str(world.component_renderer.readiness) if "native" in waiting else "")
            if holds.is_empty() or holds[-1].display_ms!=world.timeline.display_ms or holds[-1].reason!=reason:holds.append({"display_ms":world.timeline.display_ms,"reason":reason,"frames":0})
            holds[-1].frames+=1
        var phases:Dictionary=world.profile.frames[(world.profile.cursor-1+world.profile.frames.size())%maxi(1,world.profile.frames.size())].cpu_ms if not world.profile.frames.is_empty() else {}
        var entry:Dictionary={"ms":(now-last)/1000.0,"held":held,"display_ms":world.timeline.display_ms,"compiles":_compiles(previous,compiles),"compile_kinds":compiles.keys().filter(func(key):return int(compiles[key])!=int(previous.get(key,0))).map(func(key):return [key,int(compiles[key])-int(previous.get(key,0))]),"first_draws":first_draws,
            "construct_ms":float(phases.get("native_prepare_construct",0.0))}
        if entry.ms>1000.0/60.0:
            # The Player's largest measured phases of that frame (inclusive).
            var names:Array=phases.keys();names.sort_custom(func(a,b):return phases[a]>phases[b])
            entry.top_phases=names.slice(0,6).map(func(name):return [name,snappedf(float(phases[name]),0.01)])
        frames.append(entry)
        previous=compiles;last=now
        for clip_id in shots.keys():
            if shots[clip_id]>=0 and world.timeline.display_ms>=shots[clip_id]:
                shots[clip_id]=-1.0
                studio.viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(captures.path_join(directory.get_base_dir().get_base_dir().get_file()+"-"+clip_id.replace("/","__")+".png")))
    check(world.timeline.paused and is_equal_approx(world.timeline.display_ms,studio.index.presentation_end_ms),directory+": played to its end")
    var over:Array=frames.filter(func(frame):return frame.ms>1000.0/60.0)
    var result:Dictionary={"directory":directory,"frames":frames.size(),"frames_over_16_7":over.size(),
        "held_frames":frames.filter(func(frame):return frame.held).size(),"holds":holds,
        "compiles_before_play":_compiles(warm_compiles,start_compiles),
        "compiles_while_playing":_compiles(start_compiles,previous),
        "compile_frames":frames.filter(func(frame):return frame.compiles>0).map(func(frame):return {"display_ms":frame.display_ms,"compiles":frame.compiles,"kinds":frame.compile_kinds,"ms":frame.ms,"first_draws":frame.first_draws}),
        "first_draw_compiles":frames.filter(func(frame):return not frame.first_draws.is_empty()).map(func(frame):return frame.compiles).reduce(func(a,b):return a+b,0),
        "max_frame_ms":frames.map(func(frame):return frame.ms).max() if not frames.is_empty() else 0.0,
        "over_16_7":over.map(func(frame):return {"display_ms":frame.display_ms,"ms":frame.ms,"held":frame.held,"compiles":frame.compiles,"construct_ms":frame.construct_ms,"top_phases":frame.get("top_phases",[])}),
        "construct_frames_ms":frames.filter(func(frame):return frame.construct_ms>0).map(func(frame):return frame.construct_ms),
        "occurrences":occurrences.values()}
    print("VFX_HOLD ",JSON.stringify({"case":directory.get_base_dir().get_base_dir().get_file(),"frames":result.frames,"over_16_7":result.frames_over_16_7,"held":result.held_frames,
        "compiles_while_playing":result.compiles_while_playing,"first_draw_compiles":result.first_draw_compiles,"max_frame_ms":result.max_frame_ms,
        "occurrences":result.occurrences.size(),"construction_ms":result.occurrences.map(func(item):return snappedf(item.construction_ms,0.01))}))
    return result

func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(1600,900)
    var directories:Array=[];var report:String="res://.runtime/vfx-effect-hold-checks.json"
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--recording="):directories.append(argument.trim_prefix("--recording="))
        if argument.begins_with("--report="):report=argument.trim_prefix("--report=")
        if argument.begins_with("--captures="):captures=argument.trim_prefix("--captures=")
    if directories.is_empty():directories=CASES
    if not captures.is_empty():DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(captures))
    var studio=Studio.new();root.add_child(studio);studio.loop_enabled=false
    await settle(studio)
    var results:Array=[]
    for directory in directories:results.append(await measure(studio,directory))
    FileAccess.open(report,FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"cases":results},"  "))
    print("VFX_EFFECT_HOLD ",JSON.stringify({"checks":checks,"failures":failures}))
    studio.queue_free()
    for frame in 4:await process_frame
    quit(0 if failures.is_empty() else 1)
