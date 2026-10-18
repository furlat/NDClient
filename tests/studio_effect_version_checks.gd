extends SceneTree
## Studio's Inspect → Effect version: switching the approach kind rebuilds the
## displayed spell effects at the current playhead (same Studio, same clock),
## every occurrence plays the requested kind or names why it falls back, and
## the rebuilt preview is ready without a held clock.
##   -- [--recording=<journal>] [--at=<ms>] [--captures=<dir>]
const Studio=preload("res://studio/studio.gd")
const Effects=preload("res://presentation/effect_package.gd")
var checks:int=0
var failures:Array=[]

func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("EFFECT_VERSION_FAIL ",label)

func settle(studio:Control)->bool:
    var deadline=Time.get_ticks_msec()+120000
    while (studio.index.is_empty() or studio.loader!=null or studio.seeker!=null or studio.installing or studio.requested_seek>=0) and Time.get_ticks_msec()<deadline:
        await process_frame
    for frame in 3:await process_frame
    return not studio.index.is_empty() and studio.loader==null and studio.seeker==null and not studio.installing and studio.requested_seek<0

func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(1600,900)
    var directory:String="res://.runtime/studio-spells-20261015/fireball-seed3/amber/journal"
    var at:float=1300.0;var captures:String=""
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--recording="):directory=argument.trim_prefix("--recording=")
        if argument.begins_with("--at="):at=float(argument.trim_prefix("--at="))
        if argument.begins_with("--captures="):captures=argument.trim_prefix("--captures=")
    if not captures.is_empty():DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(captures))
    var studio=Studio.new();root.add_child(studio);studio.loop_enabled=false
    await settle(studio)
    studio._load(directory)
    check(await settle(studio),"Recording installs")
    studio._seek(at)
    check(await settle(studio),"Seek installs")
    check(is_equal_approx(studio.world.timeline.display_ms,at),"Playhead at %.0f ms"%at)
    for kind in ["native","gpu","recorded"]:
        studio.set_effect_version(kind)
        check(await settle(studio),kind+": rebuilt preview installs")
        var world:Node=studio.world
        check(is_equal_approx(world.timeline.display_ms,at),kind+": playhead kept")
        check(world.timeline.paused and not world.timeline.waiting_for_media and not world.timeline.waiting_for_world,kind+": no clock held")
        var renderer:RefCounted=world.component_renderer.native_spells
        var kinds:Dictionary={}
        for id in renderer.handles:
            var handle:Dictionary=renderer.handles[id]
            var chosen:Dictionary=Effects.choice(handle.clip)
            kinds[str(handle.clip.id)]=[handle.effect_kind,handle.effect_reason]
            check(handle.effect_kind==chosen.kind,kind+": occurrence plays the chosen kind "+str(handle.clip.id))
            check(handle.effect_kind==kind or not handle.effect_reason.is_empty(),kind+": occurrence plays it or names its fallback "+str(handle.clip.id))
        check(not renderer.handles.is_empty(),kind+": effects displayed at the playhead")
        var drawn:Array=renderer.diagnostics.values().filter(func(entry):return entry.get("status")=="rendered")
        check(not drawn.is_empty(),kind+": a spell effect drew")
        print("EFFECT_VERSION ",kind," ",JSON.stringify(kinds))
        if not captures.is_empty():studio.viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(captures.path_join(kind+".png")))
    Effects.set_requested("")
    print("STUDIO_EFFECT_VERSION ",JSON.stringify({"checks":checks,"failures":failures}))
    studio.queue_free()
    for frame in 4:await process_frame
    quit(0 if failures.is_empty() else 1)
