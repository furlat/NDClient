extends SceneTree
## Real Studio rows -> the actual native source thumbnail path. This is an
## explicit Forward+ lane; headless checks only admission/provenance, not pixels.
const Recording=preload("res://studio/recording.gd")
const Thumbnails=preload("res://studio/thumbnail_cache.gd")
const Preview=preload("res://studio/native_spell_preview.gd")
const Play=preload("res://play.gd")
const Playback=preload("res://presentation/native_spell_playback.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
const Spells=preload("res://presentation/native_spell_authoring.gd")
const CAPTURES="res://.captures/native-spell-thumbnails"
const REPORT="res://.runtime/native-spell-thumbnail-checks.json"
var checks:int=0
var failures:Array=[]
var evidence:Array=[]
var finished:bool=false
var report_path:String=REPORT

func _initialize()->void:
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--report="):report_path=argument.trim_prefix("--report=")
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(640,480)
    create_timer(240).timeout.connect(func():check(false,"Native thumbnail fixture completes within its finite budget");finish())
    run.call_deferred()

func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("NATIVE_THUMBNAIL_FAIL ",label)

func image_stats(image:Image)->Dictionary:
    var coloured:int=0
    var covered:int=0
    var minimum:=Vector2i(image.get_width(),image.get_height())
    var maximum:=Vector2i(-1,-1)
    var peak:float=0.0
    for y in image.get_height():
        for x in image.get_width():
            var pixel:Color=image.get_pixel(x,y)
            var energy:float=maxf(pixel.r,maxf(pixel.g,pixel.b))
            peak=maxf(peak,energy)
            # Additive native sources legitimately carry RGB at zero alpha.
            if energy>1.0/255.0:
                coloured+=1;minimum=minimum.min(Vector2i(x,y));maximum=maximum.max(Vector2i(x,y))
            if pixel.a>1.0/255.0:covered+=1
    return {"size":[image.get_width(),image.get_height()],"coloured":coloured,"covered":covered,"peak":peak,
        "bounds":[minimum.x,minimum.y,maximum.x,maximum.y]}

func age_for(row:Dictionary)->float:
    var cue:Dictionary=row.component.native_cue
    if cue.role=="flight":return (float(cue.launch)+float(cue.contact))*.5
    # Sample the actual native opening, not an arbitrary recording interval.
    return minf(float(cue.end)*.4,.25)

func channels(index:Dictionary,spell:String)->void:
    var parents:Dictionary={}
    for row in index.rows:parents[row.id]=row
    var count:int=0
    for row in index.rows:
        if row.kind not in ["native_light","native_material"]:continue
        var component:Dictionary=row.component
        var identity:String=component.get("spell_id",component.get("native_hit",{}).get("spell_id",""))
        if identity!=spell:continue
        count+=1
        check(parents.has(row.parent),spell+": renderer channel retains its actual component parent")
        if not parents.has(row.parent):continue
        var parent:Dictionary=parents[row.parent]
        check(row.source_event_uuid==parent.source_event_uuid and row.group_id==parent.group_id,spell+": channel retains event/group provenance")
        check(row.start_ms==parent.start_ms and row.end_ms==parent.end_ms,spell+": channel uses the phase's exact display interval")
        check(row.coverage.rendered=="not_witnessed",spell+": indexed availability is not rendered evidence")
        if row.kind=="native_light":
            check(component.native_light.has("path") and not component.native_light.path.is_empty(),spell+": light channel names the actual native source node")
            for marker in row.markers:
                check(marker.at_ms>=row.start_ms-.001 and marker.at_ms<=row.end_ms+.001,spell+": light keys lie within their own sampled native phase")
        else:
            check(row.preview_scope=="composed_actor" and row.get("preview_status")=="available" and not component.preview_reason.is_empty(),spell+": body channel exposes its actual composed source thumbnail and scope")
            check(row.recipient_uuid==component.actor_uuid and not row.get("recipient_name","").is_empty(),spell+": native material names its actual disclosed recipient")
    check(count>0,spell+": Studio exposes renderer-driven native channels")

func thumbnail(row:Dictionary,index:Dictionary,quarter:int,sample_ms:float=-1.0)->void:
    var source_name:String=str(row.component.get("spell_id",row.component.get("spatial_content_id","")))
    var label:String=source_name+"-"+row.component.native_cue.role+"-q"+str(quarter)
    var thumb=Thumbnails.new();thumb.host=root;thumb.cache=Thumbnails.Catalog.source_snapshot(index.cache)
    thumb.recording=index
    var age:float=age_for(row);var at:float=row.start_ms+age*1000.0 if sample_ms<0.0 else sample_ms
    age=(at-float(row.get("source_start_ms",row.start_ms)))/1000.0
    var composed:bool=Thumbnails._composed_row(row)
    var reference:Node3D;var view:SubViewport
    if composed and DisplayServer.get_name()!="headless":
        view=SubViewport.new();view.size=Vector2i(640,480);view.own_world_3d=true
        view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
        reference=Play.new();reference.external_playback=true;reference.external_clock=true
        reference.catalog_cache=Play.Catalog.source_snapshot(index.cache);reference.media_warmup.budget_bytes=0
        reference.component_renderer.audio.set_enabled(false);reference.native_startup_background=false
        reference.playback_end_ms=index.presentation_end_ms;view.add_child(reference)
        reference.install_playback(Recording.restore(index,at));reference.timeline.paused=true
        var prepare_until:int=Time.get_ticks_msec()+20000
        while not reference.playback_prepared() and Time.get_ticks_msec()<prepare_until:await process_frame
        check(reference.playback_prepared(),label+": actual recorded reference prepares before the composed source request")
        reference.claim_receiving();reference._publish_receiving()
        thumb.reference_world=reference;thumb.set_displayed_world(reference)
    var key:String=thumb.request(row,at,quarter,false)
    check(not key.is_empty() and not thumb.errors.has(key),label+": admitted phase can request its native source")
    if DisplayServer.get_name()=="headless":thumb.close();return
    var deadline:int=Time.get_ticks_msec()+20000
    var started:bool=false
    while not thumb.textures.has(key) and not thumb.errors.has(key) and Time.get_ticks_msec()<deadline:
        await process_frame
        thumb.poll()
        if not started and not thumb.active.is_empty():
            check(not thumb.textures.has(key),label+": source construction cannot publish its first blank draw")
            started=true
        await RenderingServer.frame_post_draw
    check(thumb.errors.is_empty() and thumb.textures.has(key),label+": thumbnail completes from a submitted native draw; "+str(thumb.errors))
    if thumb.textures.has(key):
        var image:Image=thumb.textures[key].get_image()
        var stats:Dictionary=image_stats(image)
        if composed:
            var rendered:Dictionary=thumb.composed_pane.world.component_renderer.native_spells.diagnostics.get(row.component.id,{}) if not thumb.composed_pane.is_empty() else {}
            check(rendered.get("status")=="rendered" and rendered.get("input_bindings",{}).get("unavailable",{}).is_empty(),label+": submitted recorded context contains the exact admitted native source")
            if row.component.get("spatial_effect_uuid")!=null:
                var owner:Node3D=thumb.composed_pane.world
                var identity:String=str(row.component.spatial_effect_uuid)
                var actual:Array=owner.displayed_components.filter(func(component):return component.id==row.component.id)
                check(owner.quarter==quarter and not owner.rotation_pending(),label+": field capture uses the actually published requested view")
                check(owner.timeline.spatial_effect_owners.has(identity) and actual.size()==1,label+": field capture restores the same genuine spatial owner and private source occurrence")
                if actual.size()==1:
                    check(actual[0].actor_uuid==null and actual[0].target_uuid==null and actual[0].spatial_effect_uuid==identity,label+": field preview invents no actor or recipient owner")
                    check(actual[0].native_constructor_inputs==row.component.native_constructor_inputs and actual[0].resolved_area_positions==row.component.resolved_area_positions,label+": composed source consumes the exact recorded construction and current cell cut")
                check(thumb.native_composites.is_empty() and not thumb.composed_pane.is_empty(),label+": field source uses the one production pane instead of an isolated empty-input preview")
            check(stats.coloured>0 and stats.peak>1.0/255.0,label+": full recorded context publishes nonblank pixels; scene pixels are not isolated-effect evidence")
        else:check(stats.coloured>0 and stats.coloured<image.get_width()*image.get_height(),label+": isolated source contains pixels and transparent background")
        image.save_png(CAPTURES+"/"+label+".png")
        evidence.append({"source":row.component.native_clip.id,"age_seconds":age,"sample_ms":at,"spatial_effect_uuid":row.component.get("spatial_effect_uuid"),"quarter":quarter,"pixels":stats,
            "scope":"recorded_composed_context" if composed else "isolated_source"})
    thumb.close()
    if is_instance_valid(view):view.queue_free()
    await process_frame

func tail_and_rotation(row:Dictionary)->void:
    var component:Dictionary=row.component
    var cue:Dictionary=component.native_cue
    var label:String=component.spell_id+" flight"
    check(cue.get("stop_emission_at_contact",false),label+": native tail is explicitly emission-controlled")
    if DisplayServer.get_name()=="headless":return
    var preview=Preview.new();root.add_child(preview)
    check(preview.configure_component(component).is_empty(),label+": direct source preview constructs")
    var age:float=minf(float(cue.end)-.001,float(cue.contact)+.1)
    var basis:=Basis.from_euler(Vector3(-atan(sqrt(.5)),PI/4,0))
    var deadline:int=Time.get_ticks_msec()+20000
    var ready:bool=false
    var before_contact_emitted:bool=false
    var first:bool=true
    while not ready and Time.get_ticks_msec()<deadline:
        await process_frame
        var sampled:Dictionary=preview.sample(age,basis,Vector3.ZERO,1,[],{})
        if first:check(not sampled.ready,label+": a cold tail is not ready before source history is drawn");first=false
        check(sampled.error.is_empty(),label+": source history samples without resource errors")
        if not preview.handle.is_empty() and preview.sampled<float(cue.contact):
            for emitter in preview.handle.emitters:before_contact_emitted=before_contact_emitted or emitter.emitting
        ready=sampled.ready
        await RenderingServer.frame_post_draw
    check(ready,label+": cold tail reconstructs within the finite source-readiness budget")
    if ready:
        # A recorded (seekable) approach draws the tail directly; only a
        # simulation must replay its earlier source history.
        check(before_contact_emitted or preview.handle.get("seekable",false),label+": seeking to tail still emits the earlier source history")
        check(preview.handle.emitters.all(func(emitter):return not emitter.emitting),label+": emission is stopped at actual contact while existing particles drain")
        check(absf(preview.handle.age-Playback.source_time(cue,age))<.00001,label+": tail reaches the phase's exact mapped source clock")
        var history:Dictionary=image_stats(preview.texture().get_image())
        check(history.coloured>0,label+": early tail contains surviving native source pixels")
        for quarter in [1,2,3,0]:
            basis=Basis.from_euler(Vector3(-atan(sqrt(.5)),PI/4+quarter*PI/2,0))
            await process_frame
            var rotated:Dictionary=preview.sample(age,basis,Vector3.ZERO,1,[],{})
            check(not rotated.ready,label+": changed view waits for its own submitted draw q"+str(quarter))
            await RenderingServer.frame_post_draw
            await process_frame
            rotated=preview.sample(age,basis,Vector3.ZERO,1,[],{})
            check(rotated.ready,label+": same source age publishes after the new view draws q"+str(quarter))
            check(absf(preview.handle.age-Playback.source_time(cue,age))<.00001,label+": rotation preserves particle/source age q"+str(quarter))
            await RenderingServer.frame_post_draw
        evidence.append({"source":component.native_clip.id,"tail_seconds":age,"tail_pixels":history,"emitted_before_contact":before_contact_emitted})
    preview.close();preview.queue_free();await process_frame

func body_thumbnail(row:Dictionary,cache:Dictionary,quarter:int)->void:
    var label:String=str(row.component.native_hit.spell_id)+"-body-q"+str(quarter)
    var thumb=Thumbnails.new();thumb.host=root;thumb.cache=Thumbnails.Catalog.source_snapshot(cache)
    var at:float=row.start_ms+minf(60.0,(row.end_ms-row.start_ms)*.25)
    var immutable=var_to_bytes(row)
    var key:String=thumb.request(row,at,quarter,false)
    check(not key.is_empty() and thumb.errors.is_empty(),label+": actual recipient source can be requested")
    if DisplayServer.get_name()=="headless":thumb.close();return
    var baseline:Dictionary=row.duplicate(false);baseline.id=row.id+":untreated-source";baseline.kind="condition_material";baseline.component={}
    var plain:String=thumb.request(baseline,at,quarter,false)
    var deadline:int=Time.get_ticks_msec()+20000
    while (not thumb.textures.has(key) or not thumb.textures.has(plain)) and thumb.errors.is_empty() and Time.get_ticks_msec()<deadline:
        await process_frame;thumb.poll();await RenderingServer.frame_post_draw
    check(thumb.errors.is_empty() and thumb.textures.has(key) and thumb.textures.has(plain),label+": composed recipient and untreated source complete from submitted draws; "+str(thumb.errors))
    if thumb.textures.has(key) and thumb.textures.has(plain):
        var image:Image=thumb.textures[key].get_image();var reference:Image=thumb.textures[plain].get_image()
        var same_alpha:bool=image.get_size()==reference.get_size();var changed:int=0
        if same_alpha:
            for y in image.get_height():
                for x in image.get_width():
                    var treated:Color=image.get_pixel(x,y);var original:Color=reference.get_pixel(x,y)
                    if not is_equal_approx(treated.a,original.a):same_alpha=false
                    if treated!=original:changed+=1
        check(same_alpha,label+": native source retains the actual assembled recipient coverage")
        check(changed>0,label+": selected native material changes actual recipient pixels")
        image.save_png(CAPTURES+"/"+label+".png")
        evidence.append({"kind":"composed_native_material","recipient_uuid":row.recipient_uuid,"sample_ms":at,"quarter":quarter,"changed_pixels":changed,"same_body_alpha":same_alpha,"pixels":image_stats(image)})
    check(var_to_bytes(row)==immutable,label+": source sampling leaves recorded authoring, pose and clocks unchanged")
    thumb.close();await process_frame

func spatial_thumbnail()->void:
    var index:Dictionary=Fixtures.read("chromatic-orb")
    check(index.ok,"Spatial thumbnail admits the untouched original Chromatic Orb journal")
    if not index.ok:return
    var source_bytes:PackedByteArray=var_to_bytes([index.initialization,index.groups,index.rows])
    var rows:Array=index.rows.filter(func(row):return row.kind=="native_effect" and row.get("component",{}).get("spatial_content_id")=="spatial_effect.spell.acid_surface" \
        and row.component.get("spatial_effect_uuid")!=null and row.component.get("status")=="available" \
        and not row.component.get("native_constructor_inputs",[]).is_empty() and float(row.end_ms)>float(row.start_ms))
    check(not rows.is_empty(),"Original public Acid owner exposes a supported source with real constructor operands")
    if rows.is_empty():return
    var row:Dictionary=rows[0]
    check(row.component.actor_uuid==null and row.component.target_uuid==null,"Spatial regression is a real field without an actor preview substitute")
    check(Thumbnails._composed_row(row),"Input-bearing spatial source reaches the shared production composed-preview path")
    check(row.get("preview_scope")=="recorded_composed_context" and row.coverage.rendered=="not_witnessed","Studio exposes the composed field method without promoting source presence to output evidence")
    var at:float=(float(row.start_ms)+minf(float(row.end_ms),float(index.presentation_end_ms)))*.5
    var restored:RefCounted=Recording.restore(index,at)
    var samples:Array=restored.component_samples(index.cache).filter(func(component):return component.id==row.component.id)
    check(samples.size()==1 and restored.spatial_effect_owners.has(str(row.component.spatial_effect_uuid)),"Exact original field sample restores the real owner before preview admission")
    await thumbnail(row,index,1,at)
    check(var_to_bytes([index.initialization,index.groups,index.rows])==source_bytes,"Composed field preparation and drawing preserve every original cut, source and inspection row")

func run()->void:
    if DisplayServer.get_name()!="headless":
        DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=120
    DirAccess.make_dir_recursive_absolute(CAPTURES)
    var phase_count:int=0
    for spec in [{"behavior":"spell.fire_bolt","case":"fire-bolt","sequence":8},
        {"behavior":"spell.magic_missile","case":"magic-missile","sequence":2}]:
        var index:Dictionary=Fixtures.read(spec.case)
        var selected_source:Dictionary=Spells.selection(spec.behavior,index.get("cache",{}))
        check(index.ok and not selected_source.is_empty(),spec.behavior+": original current journal and typed native source admit through Studio Recording")
        if not index.ok:print(index);continue
        if selected_source.is_empty():continue
        var spell:String=selected_source.id
        var groups:Array=index.groups.filter(func(wrapped):return int(wrapped.group.operation_sequence)==spec.sequence)
        check(not groups.is_empty(),spell+": source rows belong to the exact original cast operation")
        var group_ids:Array=groups.map(func(wrapped):return wrapped.group.id)
        channels(index,spell)
        var selected:Dictionary={}
        for row in index.rows:
            if row.kind!="native_effect" or not row.component.get("native_spell",false) or row.component.spell_id!=spell or row.group_id not in group_ids:continue
            if not selected.has(row.component.native_cue.role):selected[row.component.native_cue.role]=row
        check(selected.size()==3 and selected.has("cast") and selected.has("flight") and selected.has("impact"),spell+": real recording exposes all three actual native phases")
        for cue in Spells.event_cues(selected_source):
            check(selected.has(cue.role) and selected[cue.role].component.native_cue.staged_clip==cue.clip,spell+": thumbnail names the exact current typed "+cue.role+" source")
        var immutable=var_to_bytes(selected)
        var materials:Array=index.rows.filter(func(row):return row.kind=="native_material" and row.component.get("native_hit",{}).get("spell_id")==spell and row.group_id in group_ids)
        check(not materials.is_empty(),spell+": actual cast has a recipient material source")
        if not materials.is_empty():
            for quarter in 4:await body_thumbnail(materials[0],index.cache,quarter)
        for phase in ["cast","flight","impact"]:
            if not selected.has(phase):continue
            phase_count+=1
            for quarter in 4:await thumbnail(selected[phase],index,quarter)
        if selected.has("flight"):await tail_and_rotation(selected.flight)
        check(var_to_bytes(selected)==immutable,spell+": preparation/sampling/rotation do not mutate the indexed authoring or event rows")
    check(phase_count==6,"Both real spells expose the six reviewed native phase sources")
    await spatial_thumbnail()
    finish()

func finish()->void:
    if finished:return
    finished=true
    var report={"checks":checks,"failed":failures.size(),"failures":failures,"native":DisplayServer.get_name()!="headless","evidence":evidence,
        "scope":"Real Studio journal rows; Fire Bolt and Magic Missile cast/flight/impact native source thumbnails, four views, cold tail history, unchanged authoring, truthful body/light inspection channels; one actual actor-free Acid owner through the production composed pane with its exact original constructor and cell cut."}
    FileAccess.open(report_path,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_SPELL_THUMBNAIL ",JSON.stringify({"checks":checks,"failed":failures.size(),"failures":failures,"report":report_path}));quit(0 if failures.is_empty() else 1)
