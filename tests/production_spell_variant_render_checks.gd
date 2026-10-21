extends "res://tests/native_spell_variant_render_checks.gd"
## Actual production Resources and unmodified successful-save recordings.
## Reuse the ordinary native playback gate; no private predicate or art alias.
const CASES=[
    {"spell":"ray_of_sickness","folder":"ray-of-sickness","variant":"ray_of_sickness_hit_saved_native","phase":"impact"},
    {"spell":"vicious_mockery","folder":"saved-head-programs","variant":"vicious_mockery_saved_native","phase":"saved"},
    {"spell":"dissonant_whispers","journal":"res://tests/fixtures/schema16/option-identities/dissonant-whispers-saved-modular/","variant":"dissonant_whispers_saved_native","phase":"saved"}]
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(800,600)
    for sample in CASES:
        for seat in ["amber","blue"]:
            var directory:String=str(sample.journal)+seat if sample.has("journal") else "res://tests/fixtures/schema16/root-target-save/"+sample.folder+"/"+seat+"/journal"
            var index:Dictionary=Recording.read(directory)
            check(index.get("ok",false),sample.spell+" / "+seat+" actual production journal compiles")
            if not index.get("ok",false):continue
            var rows:Array=index.rows.filter(func(row):
                var component:Dictionary=row.get("component",{})
                return component.get("native_variant",{}).get("id")==sample.variant and str(component.get("native_clip",{}).get("id","")).ends_with("/"+sample.phase))
            check(rows.size()==1,sample.spell+" / "+seat+" one actual saved receiver phase")
            if rows.size()==1:await inspect_saved(index,rows[0],sample.spell+" / "+seat)
    var report:Dictionary={"checks":checks,"failures":failures,"evidence":evidence,
        "scope":"Production Ray of Sickness, Vicious Mockery and Dissonant Whispers successful-save receiver output, both original seats, seeking/looping/cleanup. User visual approval remains open."}
    FileAccess.open("res://.runtime/production-spell-variant-render-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("PRODUCTION_SPELL_VARIANT_RENDER ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
func inspect_saved(index:Dictionary,row:Dictionary,label:String)->void:
    var component:Dictionary=row.component
    var viewport:SubViewport=SubViewport.new();viewport.size=root.size;viewport.own_world_3d=true
    viewport.audio_listener_enable_3d=false;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
    var world:Node=Play.new();world.external_playback=true;world.external_clock=true;world.media_warmup.budget_bytes=0
    world.catalog_cache=Play.Catalog.source_snapshot(index.cache);world.playback_end_ms=index.presentation_end_ms
    world.component_renderer.audio.set_enabled(false);viewport.add_child(world)
    var middle:float=lerpf(float(row.start_ms),float(row.end_ms),.45)
    var previous:WeakRef
    for at in [maxf(0.0,float(row.start_ms)-2.0),middle,minf(index.presentation_end_ms,float(row.end_ms)+2.0),maxf(0.0,float(row.start_ms)-2.0),middle]:
        world.install_playback(Recording.restore(index,at))
        if not await settle(world,component.id if at==middle else ""):break
        check(world.timeline.display_ms==at and world.timeline.state==Recording.restore(index,at).state,label+" exact original canonical prefix after seek/loop "+str(at))
        if previous!=null:check(previous.get_ref()==null,label+" old private native owner releases at replay replacement")
        var renderer:RefCounted=world.component_renderer.native_spells
        if at!=middle:
            check(renderer.witnesses.all(func(witness):return witness.id!=component.id),label+" finite saved receiver absent outside its interval")
            previous=null;continue
        check(renderer.handles.has(component.id),label+" actual production receiver owns a native source")
        if not renderer.handles.has(component.id):break
        var handle:Dictionary=renderer.handles[component.id]
        check(handle.clip.id==component.native_clip.id,label+" renderer retains the production selected clip")
        var bindings:Dictionary=renderer.diagnostics.get(component.id,{}).get("input_bindings",{})
        check(bindings.unavailable.is_empty(),label+" no unresolved required native inputs")
        world.camera_focus=Play.Placement.contact({"position":component.to_position,"base_height_steps":float(component.get("to_elevation_feet",0.0))/5.0})
        world.camera.size=6;world.initial_focus=true;world.position_camera();world.grid_visible=false
        # The final camera changes measured recipient surfaces. Certify that
        # exact input demand before freezing the unchanged original clock.
        if not await settle(world,component.id):break
        handle=renderer.handles[component.id]
        var capture_bindings:Dictionary=renderer.diagnostics.get(component.id,{}).get("input_bindings",{})
        check(not capture_bindings.is_empty() and capture_bindings.unavailable.is_empty(),label+" final capture camera has every actual receiver input ready")
        check(world.timeline.display_ms==at,label+" final camera readiness preserves the original source clock")
        await frame();await frame();world.set_process(false)
        var visible:Image=viewport.get_texture().get_image();Effects.hide(handle);await frame();await frame()
        var pixels:int=changed(visible,viewport.get_texture().get_image())
        check(pixels>0,label+" actual saved receiver contributes framebuffer pixels")
        evidence.append({"case":label,"at_ms":at,"variant":component.native_variant,"event":component.source_event_uuid,"clip":component.native_clip.id,"pixels":pixels,"capture_bindings":capture_bindings})
        previous=weakref(handle.root);handle.root.show();world.set_process(true)
    world.component_renderer.native_spells.close(world)
    check(world.component_renderer.native_spells.handles.is_empty(),label+" private native owners close")
    check(world.presentation_errors.is_empty() and world.media_issue.is_empty(),label+" no rendering/source errors across seeks and loop")
    viewport.queue_free();await frame();await frame()
