extends SceneTree
## Slow native lane: actual Studio controls, recorded cues and emitted SFX PCM.
const Studio=preload("res://studio/studio.gd")
const Placement=preload("res://placement.gd")
var checks=0
var failures:Array=[]
var evidence:Array=[]
var runtime_gaps:Array=[]
# Received events can have no admitted actor, or no qualified source socket.
# These concrete current gaps stay in the evidence; they are not played coverage.
const ATTACHMENT_GAPS={
    "861682c7-c225-40ad-9e3b-955417655eb1:weapon_swing_heavy":"attachment_socket_unavailable"}
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("STUDIO_AUDIO_FAIL ",label)
func check_admission(row:Dictionary,diagnostics:Dictionary,context:String)->void:
    var diagnostic:Dictionary=diagnostics.rows.get(row.component.id,{})
    var identity=str(row.component.source_event_uuid)+":"+str(row.component.cue_id)
    if diagnostic.get("starts",0)==1:
        check(true,context+": cue starts once: "+row.component.cue_id)
    elif ATTACHMENT_GAPS.has(identity):
        check(diagnostic.get("starts",0)==0 and diagnostic.get("state")=="skipped" and diagnostic.get("reason")==ATTACHMENT_GAPS[identity],context+": known unattached cue remains explicitly skipped")
        runtime_gaps.append({"context":context,"component_id":row.component.id,"cue":row.component.cue_id,"source_ready":diagnostic.get("source_ready",false),"reason":diagnostic.get("reason","")})
    else:check(false,context+": cue did not start once: "+row.component.cue_id)
func settle(studio:Control)->bool:
    var deadline=Time.get_ticks_msec()+90000
    while (studio.index.is_empty() or studio.loader!=null or (not studio.preparing_loop and (studio.seeker!=null or studio.installing or studio.requested_seek>=0))) and Time.get_ticks_msec()<deadline:await process_frame
    var ready=not studio.index.is_empty() and studio.loader==null and (studio.preparing_loop or (studio.seeker==null and not studio.installing and studio.requested_seek<0))
    check(ready,"Actual Studio recording/transport is ready")
    return ready
func collect(studio:Control,capture:AudioEffectCapture,label:String,stop_after_cue:String="",passes:int=0)->Dictionary:
    var peak=0.0;var frames=0;var owners={};var starts={};var attachments={};var contacts={};var deadline=Time.get_ticks_msec()+30000
    var emitted=PackedVector2Array()
    var onsets={}
    while Time.get_ticks_msec()<deadline:
        var audio=studio.world.component_renderer.audio
        for id in audio.voices:
            var voice:Dictionary=audio.voices[id]
            if voice.started and not onsets.has(id):
                var now=float(studio.world.timeline.display_ms)
                onsets[id]={"scheduled_ms":voice.row.absolute_start_ms,"display_ms":now,"source_offset_s":voice.offset_s,"native_position_s":voice.node.get_playback_position(),"source_policy":voice.row.get("attachment_source","rendered_actor"),"world_position":str(voice.node.global_position) if voice.node is AudioStreamPlayer3D else "nonspatial"}
                check(absf(voice.offset_s-(now-voice.row.absolute_start_ms)/1000.0)<.001,"Native one-shot follows its resolved component onset: "+voice.row.cue_id)
            var actor:Dictionary=studio.world.visual_actors.get(voice.row.get("actor_uuid"),{})
            if voice.started and voice.node is AudioStreamPlayer3D and not actor.is_empty():
                attachments[id]={"attachment":voice.row.attachment,"distance_from_ground_contact":voice.node.global_position.distance_to(Placement.contact(actor.row))}
            if voice.started and voice.row.has("source_frame") and not contacts.has(id):
                var contact=float(voice.row.absolute_start_ms)+float(voice.row.source_sync_s)*1000.0
                var now=float(studio.world.timeline.display_ms)
                if now>=contact:
                    var pose:Dictionary=studio.world.timeline.actor_samples().get(voice.row.actor_uuid,{})
                    var ground_distance=INF
                    if not actor.is_empty():
                        for entry in actor.entries:
                            if entry.role!="shadow" and entry.node.visible:
                                ground_distance=entry.node.position.distance_to(Placement.contact(actor.row));break
                    contacts[id]={"contact_ms":contact,"display_ms":now,"source_frame":voice.row.source_frame,
                        "source_sync_s":voice.row.source_sync_s,"offset_s":voice.offset_s,"native_position_s":voice.node.get_playback_position(),
                        "source_seconds":pose.get("source_seconds",-1),"lift_pixels":pose.get("lift_pixels",0),"cue_id":voice.row.cue_id,
                        "native_ground_distance":ground_distance,"native_actor_position":actor.get("row",{}).get("position",[]),
                        "clock_error_s":voice.offset_s-((now-contact)/1000.0+voice.row.source_sync_s)}
        for id in audio.diagnostics().rows:
            var diagnostic:Dictionary=audio.diagnostics(id).rows[id]
            if diagnostic.starts<=0:continue
            var key=str(studio.world.get_instance_id())+":"+id
            owners[key]=int(diagnostic.starts)
            starts[id]=0
            for owner in owners:
                if owner.ends_with(":"+id):starts[id]+=owners[owner]
        var pcm=capture.get_buffer(capture.get_frames_available());frames+=pcm.size()
        emitted.append_array(pcm)
        for sample in pcm:peak=maxf(peak,maxf(absf(sample.x),absf(sample.y)))
        if passes>0 and starts.get(stop_after_cue,0)>=passes:studio.world.timeline.paused=true
        if studio.world.timeline.paused:break
        await process_frame
    check(studio.world.timeline.paused,label+": playback reaches its stop")
    check(studio.world.component_renderer.audio.errors.is_empty(),label+": native presenter has no source errors")
    var pcm_path="res://.captures/studio/audio/"+label.replace("/","-")+".wav"
    DirAccess.make_dir_recursive_absolute("res://.captures/studio/audio")
    var raw=PackedByteArray();raw.resize(emitted.size()*4)
    for i in emitted.size():
        raw.encode_s16(i*4,int(roundf(clampf(emitted[i].x,-1,1)*32767)))
        raw.encode_s16(i*4+2,int(roundf(clampf(emitted[i].y,-1,1)*32767)))
    var wav=AudioStreamWAV.new();wav.format=AudioStreamWAV.FORMAT_16_BITS;wav.stereo=true;wav.mix_rate=int(AudioServer.get_mix_rate());wav.data=raw
    check(wav.save_to_wav(pcm_path)==OK,label+": native SFX PCM saved for audition")
    var result={"label":label,"recording":studio.active_directory,"starts":starts,"onsets":onsets,"attachments":attachments,"contacts":contacts,"peak":peak,"pcm_frames":frames,"pcm_capture":pcm_path,"end_ms":studio.world.timeline.display_ms,"diagnostics":studio.world.component_renderer.audio.diagnostics(),"transport":{"presentation_end_ms":studio.index.presentation_end_ms,"duration_ms":studio.index.duration_ms,"busy":studio.world.timeline.busy(),"paused":studio.world.timeline.paused,"loop_enabled":studio.loop_enabled}}
    evidence.append(result);return result
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(1280,720)
    var studio=Studio.new();root.add_child(studio)
    if not await settle(studio):await finish(studio);return
    check(studio.active_directory=="res://.runtime/studio-cases/walk_diagonal-seed3-v2/amber/journal","Exact real Move recording loaded")
    var bus=AudioServer.get_bus_index("SFX")
    check(bus>=0,"Actual prepared Studio creates SFX bus")
    if not failures.is_empty():await finish(studio);return
    var capture=AudioEffectCapture.new();capture.buffer_length=2
    var effect_index=AudioServer.get_bus_effect_count(bus);AudioServer.add_bus_effect(bus,capture)
    studio.loop_enabled=false
    var rows=studio.index.rows.filter(func(row):return row.kind=="audio" and row.component.get("cue_id")=="footstep")
    check(rows.size()==3,"Move recording contains three authored footsteps")
    if not rows.is_empty():
        capture.clear_buffer();studio._play_study();await settle(studio)
        var whole=await collect(studio,capture,"whole_move")
        check(whole.peak>.00001 and whole.peak<1.0,"Whole real Move emits nonclipping native PCM")
        for row in rows:
            check(whole.starts.get(row.component.id,0)==1,"Whole Move starts each recorded cue once: "+row.component.id)
            var contact:Dictionary=whole.contacts.get(row.component.id,{})
            check(not contact.is_empty() and absf(contact.clock_error_s)<.001,"Native footstep follows its source-frame clock")
            if not contact.is_empty():
                var expected=fposmod(float(row.component.source_frame)+(contact.display_ms-contact.contact_ms)*.012,15)
                check(absf(fposmod(contact.source_seconds*12,15)-expected)<.02,"Actual rendered Move pose has the authored contacting source phase")
        studio._seek(rows[0].start_ms);await settle(studio)
        check(studio.world.component_renderer.audio.voices.is_empty(),"Selecting the exact onset remains silent while paused")
        capture.clear_buffer();studio._toggle_play()
        var selected=await collect(studio,capture,"selected_onset")
        check(selected.starts.get(rows[0].component.id,0)==1,"Play from the selected exact onset starts the first cue")
        check(selected.peak>.00001,"Selected-onset replay emits native PCM")
        studio._seek(rows[0].start_ms+minf(20.0,(rows[0].end_ms-rows[0].start_ms)*.5));await settle(studio)
        capture.clear_buffer();studio._toggle_play()
        var inside=await collect(studio,capture,"inside_old_one_shot")
        check(inside.starts.get(rows[0].component.id,0)==0,"Seeking inside first footstep does not play its historical onset")
        capture.clear_buffer();studio._play_clip(rows[0]);await settle(studio)
        var looped=await collect(studio,capture,"selected_clip_loop",rows[0].component.id,2)
        check(looped.starts.get(rows[0].component.id,0)==2,"Selected cue starts once on each of two real loop passes")
        studio.loop_enabled=false
    for path in ["jump-seed3-v2/amber","melee-seed3/amber","hide-light-schema9-seed3/amber","rage-seed3-v3/amber","movement-oa","action_economy-seed3-v2/amber"]:
        studio._load("res://.runtime/studio-cases/"+path+"/journal")
        if not await settle(studio):break
        studio.loop_enabled=false
        capture.clear_buffer();studio._play_study();await settle(studio)
        var played=await collect(studio,capture,path)
        check(played.peak>.00001 and played.peak<1.0,path+": real Studio emits nonclipping native PCM")
        var cues=studio.index.rows.filter(func(row):return row.kind=="audio" and row.get("status")=="available")
        check(not cues.is_empty(),path+": recorded audio tracks are present")
        for row in cues:
            check_admission(row,played.diagnostics,path)
            if path=="jump-seed3-v2/amber" and row.component.cue_id=="landing":
                var contact:Dictionary=played.contacts.get(row.component.id,{})
                check(not contact.is_empty(),"Actual Jump native voice reaches touchdown")
                if not contact.is_empty():
                    check(absf(contact.clock_error_s)<.001 and is_equal_approx(contact.source_sync_s,.08),"Native landing source clock puts its80ms impact at world touchdown")
                    check(absf(contact.lift_pixels)<.01 and contact.native_ground_distance<.001 and contact.native_actor_position==row.component.source_track.to_position,"Native Jump sprite reaches its destination ground when the landing transient is reached")
                    check(absf(contact.native_position_s-contact.offset_s)<.15,"Native playback clock agrees within its mixer buffer")
            if path=="melee-seed3/amber" and row.component.attachment in ["weapon","target_body"]:
                check(played.attachments.get(row.component.id,{}).get("distance_from_ground_contact",0)>.01,"Melee "+row.component.attachment+" voice uses its authored body/hand anchor above ground contact")
        if path=="hide-light-schema9-seed3/amber":
            var equipment=cues.filter(func(row):return row.component.cue_id=="equipment_handle")
            check(not equipment.is_empty() and cues.any(func(row):return row.component.cue_id=="torch_ignite"),"Previously silent equipment and torch ignition are exercised in real Studio")
            if not equipment.is_empty():
                capture.clear_buffer();studio._play_clip(equipment[0]);await settle(studio)
                var repeated=await collect(studio,capture,"equipment_selected_loop",equipment[0].component.id,2)
                check(repeated.starts.get(equipment[0].component.id,0)==2 and repeated.peak>.00001,"New equipment cue emits once on each selected loop pass")
                studio.loop_enabled=false
                studio._seek(equipment[0].start_ms+20);await settle(studio)
                capture.clear_buffer();studio._toggle_play()
                var skipped=await collect(studio,capture,"equipment_seek_inside")
                check(skipped.starts.get(equipment[0].component.id,0)==0,"Seeking inside new equipment cue never replays its stale onset")
        elif path=="movement-oa":
            for id in ["unarmed_swing","potion_drink","door_open"]:
                check(cues.any(func(row):return row.component.cue_id==id),"Actual movement/OA study exercises "+id)
        elif path=="action_economy-seed3-v2/amber":
            check(cues.any(func(row):return row.component.cue_id=="action_surge" and row.component.clip.contains("/kenney/rpg/cloth")),"Action Surge replacement plays a real physical cloth source")
    studio._load("res://.runtime/studio-cases/hide-light-schema9-seed3/amber/journal")
    if await settle(studio):
        for listening in ["amber","blue"]:
            studio.select_perspective(listening)
            if not await settle(studio):break
            studio.loop_enabled=false;capture.clear_buffer();studio._play_study();await settle(studio)
            var selected=await collect(studio,capture,"listening_"+listening)
            check(selected.peak>.00001,"Selected "+listening+" perspective emits native PCM")
            check(studio.world.component_renderer.audio.enabled,"Only displayed "+listening+" faction is audible")
            for owner in [studio.candidate_world,studio.spare_world]:
                if owner!=null:check(not owner.component_renderer.audio.enabled,"Prepared single-view owner remains silent")
            var source:Dictionary=studio.case_bundle.views[listening]
            for row in source.rows:
                if row.kind=="audio" and row.status=="available":
                    check_admission(row,studio.world.component_renderer.audio.diagnostics(),"listening "+listening)
    AudioServer.remove_bus_effect(bus,effect_index)
    await finish(studio)
func finish(studio:Control)->void:
    studio.queue_free();await process_frame;await process_frame
    var result={"checks":checks,"failures":failures,"evidence":evidence,"runtime_attachment_gaps":runtime_gaps,"audio_driver":AudioServer.get_driver_name(),"scope":"Actual Studio base cues, Move/Jump clocks, equipment seek/loop, Action Surge and separate listening factions; admitted native voice dispatch and captured SFX mixer PCM. Explicit skipped attachments are gaps, not played coverage or physical-speaker audibility."}
    FileAccess.open("res://generated/studio_audio_transport_checks.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("STUDIO_AUDIO_TRANSPORT ",JSON.stringify({"checks":checks,"failures":failures,"captures":evidence.size()}));quit(0 if failures.is_empty() else 1)
