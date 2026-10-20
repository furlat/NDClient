extends "res://tests/native_spell_variant_render_checks.gd"
## Complete actual option journals through the ordinary player and reducer.
const Fixtures=preload("res://tests/recording_fixtures.gd")
const Media=preload("res://studio/recording_media.gd")
const Journal=preload("res://sdk/journal.gd")
const OUT="res://.runtime/production-option-runtime"
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(800,600)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    DirAccess.make_dir_recursive_absolute(OUT)
    for ability in ["charisma","constitution","dexterity","intelligence","wisdom"]:
        for seat in ["amber","blue"]:
            var directory:String=Fixtures.journal("enhance-ability-"+ability,seat)
            var journal:RefCounted=Journal.new();var opened:Dictionary=journal.open(directory,true)
            var index:Dictionary=Recording.read(directory)
            check(opened.ok and index.ok,ability+"/"+seat+": unchanged option journal independently folds and compiles")
            if not opened.ok or not index.ok:continue
            index.media_preload=Media.plan(index)
            var rows:Array=index.rows.filter(func(row):return row.kind=="native_effect" and row.get("component",{}).get("lifecycle_key")=="condition_enhance_ability_"+ability+"_persistent")
            check(not rows.is_empty(),ability+"/"+seat+": real option selects its exact delivered condition form")
            if rows.is_empty():continue
            var immutable:PackedByteArray=var_to_bytes([index.initialization,index.groups,index.rows])
            for quarter in 4:await original_view(index,rows[0],journal.snapshot(),ability,seat,quarter)
            check(var_to_bytes([index.initialization,index.groups,index.rows])==immutable,ability+"/"+seat+": native playback leaves all original source cuts unchanged")
    var report:Dictionary={"checks":checks,"failures":failures,"evidence":evidence,
        "scope":"Five genuine Enhance Ability forms, independent original faction reducers/four views, exact delivered condition UUID/form clocks, actual held movement and source pixels, real removal/restoration, reverse seek/loop/private cleanup. No invented gameplay or human visual approval."}
    FileAccess.open(OUT+"/result.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("PRODUCTION_OPTION_RUNTIME ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
func original_view(index:Dictionary,row:Dictionary,final:Dictionary,ability:String,seat:String,quarter:int)->void:
    var component:Dictionary=row.component;var owner:Dictionary=row.owner
    var label:String=ability+"/"+seat+"/q"+str(quarter)
    var application:float=float(owner.start_ms)+100.0
    var movements:Array=index.rows.filter(func(value):return value.kind=="body" \
        and value.get("track",{}).get("actor_uuid")==owner.actor_uuid \
        and value.track.get("trajectory")=="path" and value.start_ms>=owner.start_ms and value.end_ms<owner.end_ms)
    check(not movements.is_empty(),label+": actual target moves while the option membership is active")
    if movements.is_empty():return
    var held:float=lerpf(movements[0].start_ms,movements[0].end_ms,.5)
    var view:=SubViewport.new();view.size=Vector2i(800,600);view.own_world_3d=true
    view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    var world=Play.new();world.external_playback=true;world.external_clock=true;world.quarter=quarter
    world.catalog_cache=Play.Catalog.source_snapshot(index.cache);world.media_warmup.budget_bytes=0
    world.media_warmup.encounter_override=index.media_preload;world.playback_end_ms=index.presentation_end_ms
    world.component_renderer.audio.set_enabled(false);view.add_child(world)
    var previous:WeakRef
    for cut in [{"at":application,"phase":"application"},{"at":held,"phase":"held movement"}]:
        world.install_playback(Recording.restore(index,cut.at))
        if not await settle(world,component.id):break
        var native:RefCounted=world.component_renderer.native_spells
        check(native.handles.has(component.id),label+": actual "+cut.phase+" owns its delivered native occurrence")
        if not native.handles.has(component.id):break
        var handle:Dictionary=native.handles[component.id]
        check(handle.component.condition_uuid==owner.id and handle.component.actor_uuid==owner.actor_uuid \
            and handle.component.lifecycle_key=="condition_enhance_ability_"+ability+"_persistent",label+": exact real recipient/condition and selected form are retained")
        check(world.timeline.condition_owners[owner.id].start_ms==owner.start_ms,label+": source age follows the original membership clock")
        if previous!=null:check(previous.get_ref()==null,label+": a real replay reset releases the previous private source")
        previous=weakref(handle.root)
        world.camera_focus=Play.Placement.contact(world.visual_actors[owner.actor_uuid].row)
        world.camera.size=3;world.initial_focus=true;world.position_camera();world.grid_visible=false
        world.wall_mode="hidden";world.update_wall_visibility();await frame();await frame()
        world.set_process(false)
        var shown:Image=view.get_texture().get_image();handle.root.hide();await frame();await frame()
        var count:int=changed(shown,view.get_texture().get_image())
        check(count>0,label+": "+cut.phase+" source changes actual framebuffer pixels")
        evidence.append({"ability":ability,"seat":seat,"quarter":quarter,"phase":cut.phase,"at_ms":cut.at,
            "owner_uuid":owner.id,"clip":handle.clip.id,"changed_pixels":count,"construction_ms":handle.construction_phases})
        if cut.phase=="held movement":shown.save_png(OUT+"/"+label.replace("/","-")+".png")
        world.set_process(true)
    world.install_playback(Recording.restore(index,index.presentation_end_ms))
    if await settle(world):
        check(world.timeline.state==final,label+": actual removal reaches the independent original final state")
        check(not world.timeline.condition_owners.has(owner.id),label+": actual membership retires rather than looping forever")
        check(world.component_renderer.native_spells.handles.values().all(func(handle):return handle.component.get("condition_uuid")!=owner.id),label+": real removal releases the option's native source")
    world.install_playback(Recording.restore(index,held))
    if await settle(world,component.id):check(world.timeline.condition_owners[owner.id].start_ms==owner.start_ms,label+": reverse seek and loop restore the real original membership clock")
    check(world.presentation_errors.is_empty() and world.media_issue.is_empty() and not world.publication_failed,label+": no presentation error across original seek/loop")
    world.component_renderer.native_spells.close(world)
    check(world.component_renderer.native_spells.handles.is_empty(),label+": private native owners close")
    view.queue_free();await frame();await frame()
