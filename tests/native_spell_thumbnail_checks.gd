extends SceneTree
## Real Studio rows -> the actual native source thumbnail path. This is an
## explicit Forward+ lane; headless checks only admission/provenance, not pixels.
const Recording=preload("res://studio/recording.gd")
const Thumbnails=preload("res://studio/thumbnail_cache.gd")
const Preview=preload("res://studio/native_spell_preview.gd")
const Playback=preload("res://presentation/native_spell_playback.gd")
const CAPTURES="res://.captures/native-spell-thumbnails"
const REPORT="res://.runtime/native-spell-thumbnail-checks.json"
var checks:int=0
var failures:Array=[]
var evidence:Array=[]
var finished:bool=false

func _initialize()->void:
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
            check(row.preview_scope=="live_composed_actor" and not component.preview_reason.is_empty(),spell+": missing dedicated body thumbnail is explicit, not a misleading source swatch")
    check(count>0,spell+": Studio exposes renderer-driven native channels")

func thumbnail(row:Dictionary,cache:Dictionary,quarter:int)->void:
    var label:String=row.component.spell_id+"-"+row.component.native_cue.role+"-q"+str(quarter)
    var thumb=Thumbnails.new();thumb.host=root;thumb.cache=Thumbnails.Catalog.source_snapshot(cache)
    var age:float=age_for(row)
    var key:String=thumb.request(row,row.start_ms+age*1000.0,quarter,false)
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
        check(stats.coloured>0 and stats.coloured<image.get_width()*image.get_height(),label+": preview contains source pixels and transparent background")
        image.save_png(CAPTURES+"/"+label+".png")
        evidence.append({"source":row.component.native_clip.id,"age_seconds":age,"quarter":quarter,"pixels":stats})
    thumb.close();await process_frame

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
        check(before_contact_emitted,label+": seeking to tail still emits the earlier source history")
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

func run()->void:
    if DisplayServer.get_name()!="headless":
        DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=120
    DirAccess.make_dir_recursive_absolute(CAPTURES)
    var phase_count:int=0
    for spec in [{"spell":"fire_bolt","path":"res://.runtime/compact-magic-missile-20261013/amber/journal"},
        {"spell":"magic_missile","path":"res://.runtime/studio-cases/magic_missile-seed3/amber/journal"}]:
        var index:Dictionary=Recording.read(spec.path)
        check(index.ok,spec.spell+": real journal admits through Studio Recording")
        if not index.ok:print(index);continue
        channels(index,spec.spell)
        var selected:Dictionary={}
        for row in index.rows:
            if row.kind!="native_effect" or not row.component.get("native_spell",false) or row.component.spell_id!=spec.spell:continue
            if not selected.has(row.component.native_cue.role):selected[row.component.native_cue.role]=row
        check(selected.size()==3 and selected.has("cast") and selected.has("flight") and selected.has("impact"),spec.spell+": real recording exposes all three actual native phases")
        var immutable=var_to_bytes(selected)
        for phase in ["cast","flight","impact"]:
            if not selected.has(phase):continue
            phase_count+=1
            for quarter in 4:await thumbnail(selected[phase],index.cache,quarter)
        if selected.has("flight"):await tail_and_rotation(selected.flight)
        check(var_to_bytes(selected)==immutable,spec.spell+": preparation/sampling/rotation do not mutate the indexed authoring or event rows")
    check(phase_count==6,"Both real spells expose the six reviewed native phase sources")
    finish()

func finish()->void:
    if finished:return
    finished=true
    var report={"checks":checks,"failed":failures.size(),"failures":failures,"native":DisplayServer.get_name()!="headless","evidence":evidence,
        "scope":"Real Studio journal rows; Fire Bolt and Magic Missile cast/flight/impact native source thumbnails, four views, cold tail history, unchanged authoring, truthful body/light inspection channels."}
    FileAccess.open(REPORT,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_SPELL_THUMBNAIL ",JSON.stringify({"checks":checks,"failed":failures.size(),"failures":failures,"report":REPORT}));quit(0 if failures.is_empty() else 1)
