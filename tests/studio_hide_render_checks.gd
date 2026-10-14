extends SceneTree
## Actual admitted Hide recording through the production Studio host and atlas.
const Studio=preload("res://studio/studio.gd")
const Geometry=preload("res://presentation/character_geometry.gd")
const Pose=preload("res://presentation/condition_pose.gd")
var checks=0
var failures:Array=[]
var evidence:Array=[]
var actor_id=""
const CAPTURES="res://.captures/studio/hide-native"
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("HIDE_RENDER_FAIL ",label)
func ready(studio:Control)->bool:
    return not studio.index.is_empty() and studio.loader==null and studio.seeker==null and not studio.installing and studio.requested_seek<0 and not studio.world.rotation_pending() and studio.world.component_renderer.ready
func settle(studio:Control)->bool:
    var deadline=Time.get_ticks_msec()+150000
    while not ready(studio) and Time.get_ticks_msec()<deadline:await process_frame
    check(ready(studio),"Requested recorded scene publishes: "+studio.status.text)
    if not ready(studio):return false
    await process_frame;await RenderingServer.frame_post_draw
    check(studio.world.presentation_errors.is_empty() and studio.world.media_issue.is_empty(),"Cold adopted media has no presentation/readiness error")
    return true
func seek(studio:Control,row:Dictionary,at:float)->bool:
    studio.selected_row=row;studio.tracks.reveal(row.id);studio._seek(at)
    if not await settle(studio):return false
    var exact=is_equal_approx(studio.world.timeline.display_ms,at)
    check(exact,"Requested source time actually publishes: "+str(at)+" / "+studio.status.text)
    return exact
func capture(studio:Control,label:String)->Image:
    await process_frame;await RenderingServer.frame_post_draw
    var image=studio.viewport.get_texture().get_image()
    image.save_png(CAPTURES.path_join(label+".png"))
    return image
func source_capture(studio:Control,row:Dictionary,label:String)->void:
    var cache=studio.tracks.thumbnails
    var key=cache.request(row,studio.world.timeline.display_ms,studio.world.quarter)
    var deadline=Time.get_ticks_msec()+30000
    while not cache.textures.has(key) and not cache.errors.has(key) and Time.get_ticks_msec()<deadline:await process_frame
    check(cache.textures.has(key),"Actual assembled source thumbnail publishes "+label)
    if cache.textures.has(key):
        var image:Image=cache.textures[key].get_image()
        check(image.get_used_rect().has_area(),"Actual source thumbnail contains original body pixels "+label)
        image.save_png(CAPTURES.path_join(label+"-source.png"))
func actor_rect(studio:Control)->Rect2i:
    var rect=Rect2()
    var first=true
    for entry in studio.world.visual_actors.get(actor_id,{}).get("entries",[]):
        if not entry.node.visible or entry.role=="shadow":continue
        var mesh:QuadMesh=entry.node.mesh
        for x in [-.5,.5]:
            for y in [-.5,.5]:
                var point=entry.node.global_transform*(mesh.center_offset+Vector3(mesh.size.x*x,mesh.size.y*y,0))
                var screen=studio.world.camera.unproject_position(point)
                if first:rect=Rect2(screen,Vector2.ZERO);first=false
                else:rect=rect.expand(screen)
    return Rect2i(rect.grow(2)).intersection(Rect2i(Vector2i.ZERO,studio.viewport.size))
func inspect_badge(studio:Control)->void:
    var labels=studio.world.component_renderer.numbers.values().filter(func(label):return label.text=="−Hidden" or label.text=="-Hidden")
    check(labels.size()==1,"Recorded removal owns one actual text badge")
    if labels.is_empty():return
    var label:Label3D=labels[0]
    var actual=await capture(studio,"authoritative-removal")
    # Same native text, camera and background, with only world geometry absent.
    # Near-opaque native glyph samples must survive ordinary composition.
    # At a fractional text edge, background changes can contribute one RGB byte.
    var geometry=[]
    for node in studio.world.find_children("*","GeometryInstance3D",true,false):
        if node==label:continue
        geometry.append([node,node.layers]);node.layers=0
    var reference=await capture(studio,"removal-badge-isolated")
    for item in geometry:item[0].layers=item[1]
    var colours={}
    for y in reference.get_height():
        for x in reference.get_width():
            var c=reference.get_pixel(x,y)
            if c.r>.25 and c.r>c.g*1.5 and c.b>c.g*1.5:
                var key=c.to_rgba32();colours[key]=colours.get(key,0)+1
    check(not colours.is_empty(),"Isolated native removal glyph has visible coloured pixels")
    if colours.is_empty():return
    var opaque=colours.keys()[0]
    for key in colours:
        if colours[key]>colours[opaque]:opaque=key
    var old_priority=label.render_priority;var old_outline=label.outline_render_priority
    label.render_priority=0;label.outline_render_priority=-1
    var old=await capture(studio,"removal-badge-old-order")
    label.render_priority=old_priority;label.outline_render_priority=old_outline
    var current_errors=0;var old_errors=0;var pixels=0;var changed_glyph_samples=0;var max_glyph_byte_error=0
    for y in reference.get_height():
        for x in reference.get_width():
            var c=reference.get_pixel(x,y)
            if c.r>.25 and c.r>c.g*1.5 and c.b>c.g*1.5 and actual.get_pixel(x,y)!=old.get_pixel(x,y):changed_glyph_samples+=1
            if c.to_rgba32()!=opaque:continue
            pixels+=1
            var current=actual.get_pixel(x,y)
            max_glyph_byte_error=maxi(max_glyph_byte_error,maxi(abs(current.r8-c.r8),maxi(abs(current.g8-c.g8),abs(current.b8-c.b8))))
            if current.to_rgba32()!=opaque:current_errors+=1
            if old.get_pixel(x,y).to_rgba32()!=opaque:old_errors+=1
    check(pixels>10,"Native text oracle contains near-opaque glyph samples")
    check(changed_glyph_samples>0,"Actual recorded scene reproduces glyph occlusion with original transparent ordering")
    check(max_glyph_byte_error<=1,"Foreground feedback has no covered glyph samples beyond one native fractional-edge RGB byte")
    evidence.append({"label":"removal-badge-order","opaque_glyph_pixels":pixels,"old_order_changed_glyph_samples":changed_glyph_samples,"old_order_covered_opaque_pixels":old_errors,"foreground_changed_glyph_pixels":current_errors,"maximum_glyph_rgb_byte_error":max_glyph_byte_error})
    await capture(studio,"authoritative-removal")
func inspect_actor(studio:Control,row:Dictionary,expected_clip:String,alpha:float,label:String)->void:
    var world=studio.world
    check(world.visual_actors.has(actor_id),"Assembled actor exists "+label)
    if not world.visual_actors.has(actor_id):return
    var playback=world.playbacks[actor_id]
    check(playback.clip==expected_clip,"Native Graphs uses actual source clip "+label)
    var visual:Dictionary=world.visual_actors[actor_id]
    var rig:Dictionary=world.rigs[visual.row.rig]
    var frame=mini(int(playback.sample_seconds*rig.clips[playback.clip].fps),int(rig.clips[playback.clip].frames)-1)
    var sample=world.displayed_samples.get(actor_id,{})
    var expected_seconds=0.0
    if not sample.is_empty():
        expected_seconds=sample.source_seconds
        if Studio.Play.Graphs.character_loops(rig,expected_clip):expected_seconds=fposmod(expected_seconds,float(rig.clips[expected_clip].frames)/rig.clips[expected_clip].fps)
    elif row.has("selected_pose"):
        var pose:Dictionary=row.selected_pose
        var owner=world.displayed_components.filter(func(c):return c.kind=="condition" and c.condition_uuid==pose.condition_uuid)
        check(owner.size()==1,"Displayed owner supplies idle clock "+label)
        if not owner.is_empty():expected_seconds=Pose.source_seconds(pose,rig.clips[expected_clip],owner[0].age_ms)
    else:
        expected_seconds=fposmod(world.timeline.display_ms/1000.0,float(rig.clips[expected_clip].frames)/rig.clips[expected_clip].fps)
    check(frame==mini(int(expected_seconds*rig.clips[expected_clip].fps),int(rig.clips[expected_clip].frames)-1),"Source row clock and viewport frame agree "+label)
    var atlas=world.native_light_atlas.viewport.get_texture().get_image()
    var count=0;var gear=0;var opaque=0;var coverage_mismatches=0;var max_alpha_error=0.0
    for entry in visual.entries:
        if not entry.node.visible or entry.role=="shadow":continue
        count+=1
        if entry.actor_layer.slot!="body":gear+=1
        var material:ShaderMaterial=entry.material
        check(is_equal_approx(float(material.get_shader_parameter("condition_alpha")),alpha),"Same condition opacity reaches body/gear "+entry.actor_layer.slot+" "+label)
        check(entry.texture_path==entry.actor_layer.paths[expected_clip],"Displayed layer uses adopted original sheet "+entry.actor_layer.slot+" "+label)
        var uv:Vector4=material.get_shader_parameter("frame_uv")
        var original:Image=world.source_images[entry.texture_path]
        var start=Vector2i(roundi(uv.x*original.get_width()),roundi(uv.y*original.get_height()))
        check(start.x==frame*128,"Actual sheet frame registration "+entry.actor_layer.slot+" "+label)
        var profiles=Geometry.normal_paths(entry.texture_path,entry.actor_layer.slot,world.catalog_cache)
        if not profiles.value.is_empty():
            check(material.get_shader_parameter("component_normal")==world.textures[profiles.value[world.character_light_profile]],"Matching delivered normal profile bound "+entry.actor_layer.slot+" "+label)
            check(material.get_shader_parameter("has_component_geometry"),"Original geometry remains enabled "+entry.actor_layer.slot+" "+label)
        var receivers=world.native_light_atlas.receivers.filter(func(r):return is_same(r.entry,entry))
        check(receivers.size()==1,"One actual native receive cell "+entry.actor_layer.slot+" "+label)
        if receivers.is_empty():continue
        var receiver:Dictionary=receivers[0]
        var layer_alpha=float(material.get_shader_parameter("layer_alpha"))
        for y in 128:
            for x in 128:
                var source=original.get_pixel(start.x+x,start.y+y)
                var received=atlas.get_pixel(receiver.position.x+x,receiver.position.y+y)
                var expected=source.a*layer_alpha*alpha
                if (expected>0)!=(received.a>0):coverage_mismatches+=1
                max_alpha_error=maxf(max_alpha_error,absf(expected-received.a))
                if source.a==1:opaque+=1
    check(count>1 and gear>0 and opaque>0,"Assembled body and equipment contribute original pixels "+label)
    check(coverage_mismatches==0,"Native atlas preserves every source alpha support pixel "+label)
    check(max_alpha_error<=1.0/255.0,"Native body/gear alpha equals source×condition opacity within one storage byte "+label)
    evidence.append({"label":label,"time_ms":world.timeline.display_ms,"quarter":world.quarter,"clip":playback.clip,"frame":frame,"parts":count,"gear":gear,"condition_alpha":alpha,"alpha_max_error":max_alpha_error,"alpha_coverage_mismatches":coverage_mismatches,"source_profile":world.character_light_profile})
func has_hidden(world:Node)->bool:
    return world.timeline.state.actors.get(actor_id,{}).get("conditions",[]).any(func(c):return c.behavior_id=="condition.hidden")
func inspect_hidden_state(studio:Control,expected:bool,label:String)->void:
    check(has_hidden(studio.world)==expected,"Canonical Hidden state matches displayed boundary "+label)
    check(studio.world.displayed_components.any(func(c):return c.kind=="condition" and c.get("actor_uuid")==actor_id and c.condition.behavior_id=="condition.hidden")==expected,"Persistent condition owner matches displayed boundary "+label)
    if not expected:
        check(not studio.world.component_renderer.numbers.values().any(func(n):return n.text=="+Hidden"),"No premature Hidden badge "+label)
func inspect_transition(studio:Control,hidden:Dictionary,poses:Array)->void:
    var events=studio.index.rows.filter(func(r):return r.kind=="event" and r.event.get("behavior_id")=="action.hide" and r.get("visible_here",true))
    check(events.size()==1,"Actual recording has one visible Hide action event")
    if events.is_empty():return
    var event:Dictionary=events[0]
    var bodies=studio.index.rows.filter(func(r):return r.kind=="body" and r.source_event_uuid==event.event.event_uuid and r.track.actor_uuid==actor_id)
    check(bodies.size()==1,"Hide owns one finite body track distinct from its condition")
    if bodies.is_empty():return
    var body:Dictionary=bodies[0]
    var authoring=Studio.Recording.Compiler.Authoring
    var recipe=authoring.action({"kind":"action","behavior_id":"action.hide"},studio.index.cache)
    var clip:Dictionary=authoring.load_data("catalog/rigs.json",studio.index.cache)[body.track.rig].clips[body.track.clip]
    var actor:Dictionary=studio.index.initialization.state.actors[actor_id]
    var rate=float(recipe.actor.playbackSpeed)*authoring.playback_rate(actor,studio.index.cache)
    var expected_duration=float(clip.frames)/float(clip.fps)*1000.0/rate
    var effect_time=float(body.group_start_ms)+float(body.track.contact_ms)
    check(body.track.clip=="CrouchIdle" and clip.frames==15 and clip.fps==12,"Hide action uses the actual complete adopted crouch source")
    check(is_equal_approx(body.end_ms-body.start_ms,expected_duration),"Finite Hide duration follows selected native authoring speed")
    check(is_equal_approx(effect_time,body.end_ms) and is_equal_approx(hidden.start_ms,effect_time),"Hidden child commits at the authored final source frame")
    check(body.start_ms>0,"Studio includes visible normal idle before the first action")
    var previous_body_end=0.0
    for row in studio.index.rows:
        if row.kind=="body" and row.track.actor_uuid==actor_id and row.end_ms<=body.start_ms:
            previous_body_end=maxf(previous_body_end,row.end_ms)
    var initial_time=lerpf(previous_body_end,body.start_ms,.5)
    var action_time=lerpf(body.start_ms,body.end_ms,.45)
    if await seek(studio,body,initial_time):
        inspect_hidden_state(studio,false,"normal idle")
        inspect_actor(studio,{},"Idle",1.0,"transition-normal-idle")
        await capture(studio,"transition-normal-idle")
    var action_image:Image
    var action_bounds:Rect2i
    if await seek(studio,body,action_time):
        inspect_hidden_state(studio,false,"Hide action")
        inspect_actor(studio,body,body.track.clip,1.0,"transition-hide-action")
        action_image=await capture(studio,"transition-hide-action")
        action_bounds=actor_rect(studio)
        await source_capture(studio,body,"transition-hide-action")
    if await seek(studio,body,effect_time-1.0):
        inspect_hidden_state(studio,false,"last action frame before effect")
        inspect_actor(studio,body,body.track.clip,1.0,"transition-before-effect")
        await capture(studio,"transition-before-effect")
    var active=poses.filter(func(r):return r.start_ms<=effect_time and r.end_ms>effect_time)
    check(not active.is_empty(),"Actual condition has an indexed pose at its effect boundary")
    if not active.is_empty() and await seek(studio,active[0],effect_time):
        inspect_hidden_state(studio,true,"exact effect")
        inspect_actor(studio,active[0],active[0].selected_pose.clip,.55,"transition-hidden-condition")
        await capture(studio,"transition-hidden-condition")
    var audio_rows=studio.index.rows.filter(func(r):return r.kind=="audio" and r.component.get("cue_id")=="hide_transition")
    check(audio_rows.size()==1 and audio_rows[0].component.get("status")=="available" and is_equal_approx(audio_rows[0].start_ms,effect_time),"Actual Hide effect owns one available selected audio cue")
    # Native forward playback must cross the same boundary; seeking alone must
    # not conceal early condition publication or skip the finite body action.
    if await seek(studio,body,initial_time):
        var deadline=Time.get_ticks_msec()+30000
        var frames={"idle":0,"action":0,"hidden":0};var violations=0;var first_hidden=-1.0;var mismatch_frames=[]
        var audio=studio.world.component_renderer.audio
        var shot_count=int(audio.counters.shots);var crossed_count=int(audio.counters.crossed)
        var bus=AudioServer.get_bus_index("SFX")
        var probe=AudioEffectCapture.new();probe.buffer_length=3.0
        var effect_index=AudioServer.get_bus_effect_count(bus) if bus>=0 else -1
        if bus>=0:AudioServer.add_bus_effect(bus,probe);probe.clear_buffer()
        var voice_first=-1.0
        studio._toggle_play()
        while studio.world.timeline.display_ms<effect_time+220 and Time.get_ticks_msec()<deadline:
            await process_frame;await RenderingServer.frame_post_draw
            var world=studio.world
            var at=float(world.timeline.display_ms)
            if audio.voices.values().any(func(v):return v.row.cue_id=="hide_transition" and v.started and not v.paused) and voice_first<0:voice_first=at
            var expected=at>=effect_time
            var before_violations=violations
            if has_hidden(world)!=expected:violations+=1
            if expected and first_hidden<0:first_hidden=at
            # A zero-duration earlier operation can share the action's start
            # time while admission is held. Source ownership starts on activation;
            # the strict interior still requires the real finite body track.
            var action_active=world.displayed_samples.get(actor_id,{}).get("source_event_uuid")==event.event.event_uuid
            var phase="hidden" if expected else ("idle" if at<body.start_ms or (at==body.start_ms and not action_active) else "action")
            frames[phase]+=1
            if phase!="hidden" and world.playbacks[actor_id].clip!=("Idle" if phase=="idle" else body.track.clip):violations+=1
            for entry in world.visual_actors[actor_id].entries:
                if entry.role!="shadow" and entry.node.visible and not is_equal_approx(float(entry.material.get_shader_parameter("condition_alpha")),.55 if expected else 1.0):violations+=1
            if violations>before_violations and mismatch_frames.size()<30:
                var alpha=[]
                for entry in world.visual_actors[actor_id].entries:
                    if entry.role!="shadow" and entry.node.visible:alpha.append(entry.material.get_shader_parameter("condition_alpha"))
                mismatch_frames.append({"at":at,"effect":effect_time,"phase":phase,"hidden":has_hidden(world),"clip":world.playbacks[actor_id].clip,"alpha":alpha,"waiting_for_world":world.timeline.waiting_for_world,"waiting_for_media":world.timeline.waiting_for_media,"current":world.timeline.current.get("id"),"commit_index":world.timeline.commit_index})
        studio.world.timeline.paused=true
        var mixed=probe.get_buffer(probe.get_frames_available()) if bus>=0 else PackedVector2Array()
        var peak=0.0
        for frame in mixed:peak=maxf(peak,maxf(absf(frame.x),absf(frame.y)))
        if bus>=0:AudioServer.remove_bus_effect(bus,effect_index)
        check(int(audio.counters.shots)-shot_count==1 and int(audio.counters.crossed)-crossed_count==1 and voice_first>=effect_time,"Actual native Hide cue starts once, at its effect boundary")
        check(mixed.size()>0 and peak>0.000001,"Effect-owned Hide cue produces actual native mixed audio")
        evidence.append({"label":"hide-effect-audio","effect_ms":effect_time,"first_voice_ms":voice_first,"started_shots":int(audio.counters.shots)-shot_count,"crossings":int(audio.counters.crossed)-crossed_count,"mixed_frames":mixed.size(),"mixed_peak":peak})
        check(studio.world.timeline.display_ms>=effect_time+220,"Native forward playback crosses Hide effect")
        check(frames.values().all(func(n):return n>0),"Native playback renders normal idle, finite action and Hidden stages")
        check(violations==0 and first_hidden>=effect_time,"Forward state/source/opacity obey the same authored effect boundary")
        evidence.append({"label":"hide-action-boundary","source_event_uuid":event.event.event_uuid,"action_start_ms":body.start_ms,"action_end_ms":body.end_ms,"effect_ms":effect_time,"source_clip":body.track.clip,"source_frames":clip.frames,"source_fps":clip.fps,"playback_speed":rate,"forward_frames":frames,"first_hidden_frame_ms":first_hidden,"violations":violations,"mismatch_frames":mismatch_frames})
    if action_image!=null and await seek(studio,body,action_time):
        inspect_hidden_state(studio,false,"reverse to action")
        var restored=await capture(studio,"transition-reverse-action")
        check(action_bounds.has_area() and action_image.get_region(action_bounds).get_data()==restored.get_region(action_bounds).get_data(),"Reverse seek restores exact opaque Hide-action actor pixels")
    if await seek(studio,body,initial_time):inspect_hidden_state(studio,false,"reverse to normal idle")
func run()->void:
    if not Array(OS.get_cmdline_user_args()).any(func(arg):return arg.begins_with("--recording=")):
        push_error("Use --recording=<actual Hide amber journal>");quit(2);return
    DirAccess.make_dir_recursive_absolute(CAPTURES)
    DisplayServer.window_set_size(Vector2i(1280,720))
    var studio=Studio.new();root.add_child(studio)
    if not await settle(studio):await finish(studio);return
    var parents=studio.index.rows.filter(func(r):return r.kind=="condition" and r.owner.condition.behavior_id=="condition.hidden")
    check(not parents.is_empty(),"Actual Hidden lifetime exists")
    if parents.is_empty():await finish(studio);return
    var hidden:Dictionary=parents[0];actor_id=hidden.owner.actor_uuid
    var poses=studio.index.rows.filter(func(r):return r.kind=="condition_pose" and r.owner.id==hidden.owner.id)
    await inspect_transition(studio,hidden,poses)
    if "--transition-only" in OS.get_cmdline_user_args():await finish(studio);return
    var idles=poses.filter(func(r):return r.activity=="idle")
    var moves=poses.filter(func(r):return r.activity=="move")
    check(not idles.is_empty() and not moves.is_empty(),"Actual index contains sustained idle and movement crouch")
    if idles.is_empty() or moves.is_empty():await finish(studio);return
    var idle:Dictionary=idles[0];var move:Dictionary=moves[0]
    var idle_time=idle.start_ms+minf(250,(idle.end_ms-idle.start_ms)*.5)
    var move_time=lerpf(move.start_ms,move.end_ms,.6)
    for q in 4:
        if not await seek(studio,idle,idle_time):break
        studio.world.request_view(q)
        if not await settle(studio):break
        inspect_actor(studio,idle,"CrouchIdle",.55,"idle-q"+str(q))
        await capture(studio,"idle-q"+str(q))
        if q==0:
            await source_capture(studio,idle,"idle-q0")
            studio.world.set_normals_visible(true)
            await capture(studio,"idle-q0-normals")
            studio.world.set_normals_visible(false)
        if not await seek(studio,move,move_time):break
        inspect_actor(studio,move,"CrouchRun",.55,"move-q"+str(q))
        await capture(studio,"move-q"+str(q))
        if q==0:await source_capture(studio,move,"move-q0")
    var badges=studio.index.rows.filter(func(r):return r.kind=="feedback_text" and r.component.get("text")=="+Hidden")
    check(not badges.is_empty(),"Application has authored +Hidden text feedback")
    if not badges.is_empty():
        var badge:Dictionary=badges[0]
        if await seek(studio,badge,badge.start_ms+minf(80,(badge.end_ms-badge.start_ms)*.25)):
            check(studio.world.component_renderer.numbers.has(badge.component.id) and studio.world.component_renderer.numbers[badge.component.id].text=="+Hidden","Actual native feedback label is present")
            check(not studio.world.displayed_components.any(func(c):return c.kind=="material_flash" and c.get("actor_uuid")==actor_id),"Hidden feedback creates no body-colour flash")
            root.get_texture().get_image().save_png(CAPTURES.path_join("application-badge-ui.png"))
            await capture(studio,"application-badge")
    var attacks=studio.index.rows.filter(func(r):return r.kind=="body" and r.track.actor_uuid==actor_id and r.track.get("activity")=="attack")
    check(not attacks.is_empty(),"Actual attack is present in the admitted recording")
    if not attacks.is_empty():
        var attack:Dictionary=attacks[0]
        if await seek(studio,attack,lerpf(attack.start_ms,attack.end_ms,.35)):
            inspect_actor(studio,attack,attack.track.clip,.55,"attack-before-removal")
            await capture(studio,"attack-before-removal")
        if await seek(studio,hidden,hidden.end_ms+25):
            inspect_actor(studio,{},"Idle",1.0,"authoritative-removal")
            check(not studio.world.timeline.state.actors[actor_id].conditions.any(func(c):return c.behavior_id=="condition.hidden"),"Canonical removal owns return to normal opacity")
            await inspect_badge(studio)
    if await seek(studio,move,move_time):
        studio.world.request_view(0);await settle(studio)
        var before=await capture(studio,"reverse-before")
        var bounds=actor_rect(studio)
        check(bounds.has_area(),"Reverse comparison has actual assembled actor bounds")
        if await seek(studio,idle,idle_time) and await seek(studio,move,move_time):
            var after=await capture(studio,"reverse-after")
            check(before.get_region(bounds).get_data()==after.get_region(bounds).get_data(),"Reverse seek restores exact relevant assembled actor pixels")
        studio.selected_row=move
        studio.select_perspective("blue")
        if await settle(studio):
            check(studio.active_perspective=="blue","Requested independent faction actually publishes")
            check(not studio.world.visual_actors.has(actor_id) or not studio.world.visual_actors[actor_id].entries.any(func(entry):return entry.node.visible),"Unseen Blue faction has no target actor pixels")
            check(not studio.world.displayed_components.any(func(c):return c.get("actor_uuid")==actor_id and c.kind=="feedback_text"),"Unseen Blue faction has no private Hidden badge")
            await capture(studio,"blue-unseen")
            var unseen_time=float(studio.world.timeline.display_ms)
            var blue_row:Dictionary=studio.index.rows[0]
            var blue_start=float(studio.index.groups[0].start_ms)
            check(blue_start>0,"Independent Blue recording retains its initialization lead-in")
            if blue_start>0 and await seek(studio,blue_row,blue_start*.5):
                check(studio.world.visual_actors.has(actor_id) and studio.world.visual_actors[actor_id].entries.any(func(entry):return entry.node.visible),"Blue sees the actual initialized Amber visual contact before Hide")
                inspect_hidden_state(studio,false,"Blue initialization")
                inspect_actor(studio,{},"Idle",1.0,"blue-before-hide")
                await capture(studio,"blue-before-hide")
                if await seek(studio,blue_row,unseen_time):
                    check(not studio.world.visual_actors.has(actor_id) or not studio.world.visual_actors[actor_id].entries.any(func(entry):return entry.node.visible),"Blue's own admitted visibility boundary removes actor again after reverse seek")
                    check(not studio.world.displayed_components.any(func(c):return c.get("actor_uuid")==actor_id and c.kind=="feedback_text"),"Blue visibility transition never acquires private Hidden feedback")
                    await capture(studio,"blue-unseen-restored")
    var displayed=studio.world
    var clock=displayed.timeline.display_ms
    var old_recipe=displayed.catalog_cache["catalog/condition_recipes.json"]["condition.hidden"].duplicate(true)
    var previous=ProjectSettings.get_setting("source_data/presentation_catalog",Studio.Recording.Compiler.Authoring.Catalog.NativeAuthoring.INDEX)
    ProjectSettings.set_setting("source_data/presentation_catalog","res://.runtime/not-an-authored-catalog.tres")
    # Exercise the real index-to-thumbnail handoff, not a manually seeded cache.
    # Reindexing must retain admitted authoring while future selection is invalid.
    var selected=studio.tracks.selection
    studio.tracks.set_index(studio.index);studio.tracks.reveal(selected)
    var thumbnails=studio.tracks.thumbnails
    var key=thumbnails.request(idle,idle_time,0)
    var thumbnail_deadline=Time.get_ticks_msec()+30000
    while not thumbnails.textures.has(key) and not thumbnails.errors.has(key) and Time.get_ticks_msec()<thumbnail_deadline:
        thumbnails.poll();await process_frame
    check(thumbnails.textures.has(key) and thumbnails.errors.is_empty(),"Admitted crouch thumbnail decodes while a new selected catalog is missing")
    if thumbnails.textures.has(key):
        var reference=Image.load_from_file(CAPTURES.path_join("idle-q0-source.png"))
        check(thumbnails.textures[key].get_image().get_data()==reference.get_data(),"Already indexed native source remains byte-identical despite rejected future authoring")
    check(studio.world==displayed and studio.world.timeline.display_ms==clock and studio.tracks.selection==selected,"Thumbnail reindex preserves selected row and displayed clock")
    studio._load(studio.active_directory)
    var rejection_deadline=Time.get_ticks_msec()+30000
    while studio.loader!=null and Time.get_ticks_msec()<rejection_deadline:await process_frame
    ProjectSettings.set_setting("source_data/presentation_catalog",previous)
    check(studio.world==displayed and studio.world.timeline.display_ms==clock and "rejected" in studio.status.text.to_lower(),"Invalid selected native Resource rejects reload without publishing a candidate")
    check(studio.world.catalog_cache["catalog/condition_recipes.json"]["condition.hidden"]==old_recipe,"Rejected candidate preserves the displayed native recipe")
    await finish(studio)
func finish(studio:Control)->void:
    check(studio.world.presentation_errors.is_empty(),"Final renderer errors remain empty")
    studio.queue_free();await process_frame;await process_frame
    var report={"checks":checks,"failures":failures,"evidence":evidence,"captures":CAPTURES,"renderer":RenderingServer.get_current_rendering_method(),"scope":"Actual recorded normal idle -> finite authored Hide action -> effect-owned Hidden state, in forward playback and reverse seek; cold source demand, shared Graphs, original body+gear atlas alpha/normal registration, four sustained views, native feedback/removal, faction visibility and isolated reload. Lighting unchanged; alpha allows native HDR storage error <=1/255 with exact support. CrouchIdle is existing crouched source, not a newly invented standing-to-crouching animation."}
    FileAccess.open("res://generated/studio_hide_render_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("STUDIO_HIDE_RENDER ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
