extends "res://tests/native_spell_playback_checks.gd"
## Whole imported batch through the real Studio restore and production renderer.
const Effects=preload("res://presentation/effect_package.gd")
const Library=preload("res://studio/case_library.gd")
const Recording=preload("res://studio/recording.gd")
const BASELINES=["acid_splash","chill_touch","eldritch_blast","fire_bolt","fireball","guiding_bolt","ice_knife","magic_missile","poison_spray","produce_flame","ray_of_frost","scorching_ray","sleep","web","bane","command","mage_armor","sanctuary","shield","shocking_grasp","burning_hands","thunderwave","cure_wounds","healing_word","guidance","resistance","light","thaumaturgy","shield_of_faith","true_strike","aid","bless","false_life","sacred_flame"]
## These old independent controls have no current native16 original. Keeping
## them explicit prevents supported baselines from claiming the old whole gate.
const HISTORICAL_CONTROLS=["native-spell-shield-ranged","native-spell-shield-walk"]
var missing_originals:Array=[]
var selected_cases:Array=[]
var results:Array=[]
var sample_fraction:float=.5
func _initialize()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000)
    run.call_deferred()
func run()->void:
    DirAccess.make_dir_recursive_absolute("res://.captures/native-spell-batch")
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    var records:Array=Library.read()
    var only:String=""
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--only="):only=argument.trim_prefix("--only=")
        if argument.begins_with("--sample-fraction="):sample_fraction=float(argument.trim_prefix("--sample-fraction="))
    for short_id in BASELINES:
        var id:String="spell."+short_id
        if not only.is_empty() and short_id not in only.split(",") and id not in only.split(","):continue
        var matches:Array=records.filter(func(record):return record.id==id+"/baseline")
        check(matches.size()==1,id+": exact current baseline is present in the one Library")
        if matches.size()!=1:missing_originals.append(id+"/baseline");continue
        var original:Dictionary=matches[0]
        check(original.ready and original.perspectives.size()==2,id+": both independent original seats remain available")
        if not original.ready:missing_originals.append(original.id);continue
        var item:Dictionary=original.duplicate();item.spell_id=id
        selected_cases.append(item.id);await inspect_spell(item)
    if only.is_empty() or "shield" in only.split(",") or "spell.shield" in only.split(","):
        for control in HISTORICAL_CONTROLS:
            missing_originals.append(control)
            check(false,control+": exact current native16 ranged/OA reaction-and-walk original is missing; baseline interception cannot replace it")
    check(not selected_cases.is_empty(),"Every requested supported subset includes an actual current original")
    finish()
func inspect_spell(item:Dictionary)->void:
    var index=Recording.read(item.perspectives[0].journal)
    check(index.ok,item.spell_id+": actual Studio index loads")
    if not index.ok:return
    var rows:Array=index.rows.filter(func(row):return row.get("component",{}).get("native_spell",false) and row.component.spell_id==item.spell_id and row.kind=="native_effect")
    check(not rows.is_empty(),item.spell_id+": Studio exposes native source tracks")
    if rows.is_empty():return
    var view=SubViewport.new();view.size=Vector2i(960,640);view.own_world_3d=true
    view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    var world=Play.new();world.external_playback=true;world.external_clock=true
    world.catalog_cache=Play.Catalog.source_snapshot(index.cache);world.media_warmup.budget_bytes=0
    view.add_child(world);world.install_playback(Recording.restore(index,0))
    if not await settle(world,item.spell_id+" initial"):
        view.queue_free();await frame();return
    world.camera_focus=Vector3(6,.5,7);world.initial_focus=true;world.camera.size=12
    world.position_camera();world.wall_mode="hidden";world.update_wall_visibility()
    var visited:Dictionary={}
    var counts:Dictionary={}
    var native_pixels:int=0
    for row in rows:
        var component:Dictionary=row.component
        var key:String=str(component.native_clip.id)+":"+str(component.native_cue.role)+":"+str(component.get("persistent_owner",false))+":"+str(row.get("condition_phase",""))
        if visited.has(key):continue
        visited[key]=true
        var at:float=representative_time(row)
        if component.native_cue.role=="flight":at=row.start_ms+(component.native_cue.launch+component.native_cue.contact)*500.0
        if row.end_ms<=row.start_ms:continue
        check(world.try_reset_hidden_playback(Recording.restore(index,at)),item.spell_id+": seek publishes independent owner state")
        if not await settle(world,item.spell_id+" "+key):break
        await frame();await frame()
        var native=world.component_renderer.native_spells
        var active=world.displayed_components.filter(func(sample):return sample.get("native_spell",false) and sample.spell_id==item.spell_id)
        check(not active.is_empty(),item.spell_id+": selected native interval is active "+key)
        for sample in active:
            var status:Dictionary=native.diagnostics.get(sample.id,{})
            check(status.get("status") in ["prepared","rendered"],item.spell_id+": admitted native phase has usable placement "+str(status))
            check(native.handles.has(sample.id),item.spell_id+": occurrence source prepared")
            if native.handles.has(sample.id):
                var handle:Dictionary=native.handles[sample.id]
                check(handle.root.is_visible_in_tree(),item.spell_id+": occurrence submitted to its viewport")
                check(handle.rendered_once,item.spell_id+": source completes native draw")
        counts[key]=active.size()
        world.set_process(false)
        await frame()
        var shown:Image=view.get_texture().get_image()
        for layer in native.groups.values():layer.output.hide()
        await frame()
        var hidden:Image=view.get_texture().get_image()
        var first:PackedByteArray=shown.get_data();var second:PackedByteArray=hidden.get_data()
        var changed:int=0
        for i in range(0,mini(first.size(),second.size()),4):
            if absi(int(first[i])-int(second[i]))>3 or absi(int(first[i+1])-int(second[i+1]))>3 or absi(int(first[i+2])-int(second[i+2]))>3:changed+=1
        native_pixels+=changed
        for layer in native.groups.values():layer.output.show()
        world.set_process(true);await frame()
        shown.save_png("res://.captures/native-spell-batch/"+item.spell_id+"-"+str(visited.size())+".png")
    check(native_pixels>0,item.spell_id+": source contributes actual framebuffer pixels")
    check(world.presentation_errors.is_empty(),item.spell_id+": no renderer errors")
    check(world.try_reset_hidden_playback(Recording.restore(index,0)),item.spell_id+": reverse seek reconstructs start")
    await settle(world,item.spell_id+" reverse")
    results.append({"spell":item.spell_id,"native_pixels":native_pixels,"intervals":counts,"errors":world.presentation_errors.duplicate()})
    print("BATCH_RENDER_CASE ",JSON.stringify(results.back()))
    view.queue_free();await frame();await frame()
func representative_time(row:Dictionary)->float:
    var component:Dictionary=row.component
    var at:float=lerpf(row.start_ms,row.end_ms,sample_fraction)
    # A finite source can already be closed halfway through its particle tail.
    # Sample its authored opening, rather than treating an empty tail as failure.
    if component.native_cue.role=="attached" and not component.get("persistent_owner",false):
        for part in component.native_clip.get("components",[]):
            var source:Dictionary=part.get("input",{})
            var close:float=source.get("settings",{}).get("close",INF)
            var hz:float=source.get("simulation_hz",component.native_clip.get("simulation_hz",144))
            if close>0 and is_finite(close):
                var seconds:float=close/maxf(1,hz)/maxf(.001,component.native_cue.get("source_rate",1))
                at=minf(at,row.start_ms+seconds*500.0)
    return at
func finish()->void:
    var report={"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"cases":results,
        "factory_version":JSON.parse_string(FileAccess.get_file_as_string(Effects.INDEX)).version,
        "selected_current_cases":selected_cases,"missing_original_controls":missing_originals,
        "scope":"Current original baseline cohort through ordinary Studio restore/Play, representative phase samples, native scene pixels, reverse seek and source retirement. Historical ranged/OA Shield originals remain explicit missing controls; supported subset output is not the complete historical gate, all-spell safety or art acceptance."}
    FileAccess.open("res://generated/native_spell_batch_render_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("BATCH_RENDER ",JSON.stringify({"checks":checks,"failures":failures,"missing_original_controls":missing_originals}));quit(0 if failures.is_empty() else 1)
