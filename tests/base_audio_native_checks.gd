extends SceneTree
## Actual original clips through native spatial voices and the SFX mix bus.
const Presenter=preload("res://presentation/audio_presenter.gd")
const Recording=preload("res://studio/recording.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
var checks=0
var failures:Array=[]
var evidence:Array=[]
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);print("BASE_AUDIO_NATIVE_FAIL ",label)
func _initialize()->void:run.call_deferred()
func prepare_ready(presenter:RefCounted,components:Array,host:Node)->bool:
    var deadline:int=Time.get_ticks_msec()+30000
    while Time.get_ticks_msec()<deadline:
        if not presenter.prepare(components,host).is_empty():return false
        if presenter.ready(components):return true
        await process_frame
    return false
func mixed_frames(probe:AudioEffectCapture,count:int)->Dictionary:
    var frames=0;var peak=0.0;var deadline=Time.get_ticks_msec()+3000
    while frames<count and Time.get_ticks_msec()<deadline:
        await process_frame
        var pcm=probe.get_buffer(probe.get_frames_available());frames+=pcm.size()
        for sample in pcm:peak=maxf(peak,maxf(absf(sample.x),absf(sample.y)))
    return {"frames":frames,"peak":peak}
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000)
    var paths=["melee","fire-bolt","oa-jump","oa-jump-lethal","oa-jump-late-lethal","dash","oa-walk","hide-light","rage","move","gallery"]
    var selected={}
    for path in paths:
        var index=Fixtures.read(path)
        check(index.ok,"Read actual cue-producing recording "+path)
        if not index.ok:continue
        for item in index.groups:
            for row in item.group.components:
                if row.kind=="audio" and row.status=="available" and not selected.has(row.cue_id):
                    var cue=row.duplicate();cue.absolute_start_ms=item.start_ms+row.start_ms
                    cue.world_position=Vector3.ZERO;selected[row.cue_id]=cue
    root.audio_listener_enable_3d=true
    var host=Node3D.new();root.add_child(host)
    var camera=Camera3D.new();host.add_child(camera);camera.position=Vector3(0,0,1);camera.make_current()
    var listener=AudioListener3D.new();host.add_child(listener);listener.position=Vector3(0,0,1);listener.make_current()
    await physics_frame;await physics_frame
    var presenter=Presenter.new()
    check(await prepare_ready(presenter,selected.values(),host),"All original selected sources prepare")
    var bus=AudioServer.get_bus_index("SFX")
    if bus<0:
        bus=AudioServer.bus_count;AudioServer.add_bus();AudioServer.set_bus_name(bus,"SFX")
    check(selected.has("footstep"),"Actual movement emits an authored footstep cue")
    if not selected.has("footstep"):presenter.close();host.free();quit(1);return
    var probe=AudioEffectCapture.new();probe.buffer_length=3.0
    AudioServer.add_bus_effect(bus,probe)
    var pending:Dictionary=selected.footstep
    presenter.sample(host,[],pending.absolute_start_ms-1,1,false,100)
    probe.clear_buffer()
    presenter.sample(host,[pending],pending.absolute_start_ms+1,1,false,100)
    presenter.sample(host,[pending],pending.absolute_start_ms+1,1,true,100)
    var held=await mixed_frames(probe,4096)
    check(held.frames>=4096 and held.peak<.000001,"Pause before first physics registration emits no PCM")
    presenter.sample(host,[pending],pending.absolute_start_ms+2,1,false,100)
    var resumed=await mixed_frames(probe,4096)
    check(resumed.peak>.00001 and presenter.diagnostics(pending.id).rows[pending.id].starts==1,"Pending spatial voice resumes audibly with one native play dispatch")
    presenter.close()
    # Drain already mixed frames from the preceding audible case before
    # measuring output owned by the muted case. stop() cannot recall PCM
    # which the native audio server mixed before the mute.
    await mixed_frames(probe,maxi(4096,ceili(AudioServer.get_mix_rate()*AudioServer.get_output_latency()*2)))
    check(await prepare_ready(presenter,selected.values(),host),"Reopened original source/quiet voices prepare")
    for attachment in ["ui","screen","body"]:
        var muted=pending.duplicate();muted.id="muted:"+attachment;muted.attachment=attachment;muted.screen_position=Vector2.ZERO
        presenter.set_enabled(false);check(await prepare_ready(presenter,[muted],host),"Muted occurrence prepares silently");probe.clear_buffer()
        presenter.sample(host,[],muted.absolute_start_ms-1,1,false,101)
        presenter.sample(host,[muted],muted.absolute_start_ms+1,1,false,101)
        var silent=await mixed_frames(probe,4096)
        check(silent.frames>=4096 and silent.peak<.000001 and presenter.voices.is_empty(),"Muted "+attachment+" pane emits no native PCM")
    presenter.set_enabled(true)
    var epoch=0
    for id in selected:
        var cue:Dictionary=selected[id]
        epoch+=1
        check(await prepare_ready(presenter,[cue],host),"Selected occurrence has a prepared silent native owner: "+id)
        presenter.sample(host,[],cue.absolute_start_ms-1,1,false,epoch)
        probe.clear_buffer()
        presenter.sample(host,[cue],cue.absolute_start_ms+1,1,false,epoch)
        var started:int=Time.get_ticks_usec()
        var physics_start:int=Engine.get_physics_frames()
        var process_start:int=Engine.get_process_frames()
        var initial:Dictionary=presenter.diagnostics(cue.id)
        var playing_observations:int=0;var paused_observations:int=0
        var peak=0.0;var frames=0
        while float(Time.get_ticks_usec()-started)/1000.0<mini(1300,int(cue.duration_ms)+100):
            # Drive the native spatial server at its registration cadence.
            # A quantized millisecond wall clock can repeat across headless
            # process frames, which correctly means a held/paused display to
            # the presenter; that is not continuous playback evidence.
            await physics_frame
            var age=float(Time.get_ticks_usec()-started)/1000.0+1.0
            presenter.sample(host,[cue],cue.absolute_start_ms+age,1,false,epoch)
            if presenter.voices.has(cue.id):
                if presenter.voices[cue.id].node.playing:playing_observations+=1
                if presenter.voices[cue.id].node.stream_paused:paused_observations+=1
            var pcm=probe.get_buffer(probe.get_frames_available());frames+=pcm.size()
            for frame in pcm:peak=maxf(peak,maxf(absf(frame.x),absf(frame.y)))
        check(peak>.00001 and frames>0,"Actual spatial source produces native PCM: "+id)
        check(paused_observations==0,"Continuous native source clock has no unintended held samples: "+id)
        check(peak<1.0,"Single authored cue does not clip: "+id)
        var shots=int(presenter.counters.shots)
        presenter.sample(host,[cue],cue.absolute_start_ms+1,1,true,epoch+1000)
        check(presenter.counters.shots==shots and presenter.voices.is_empty(),"Reverse seek is silent for "+id)
        evidence.append({"cue":id,"clip":cue.clip,"source_event_uuid":cue.source_event_uuid,"source_marker":cue.source_marker,"peak":peak,"pcm_frames":frames,
            "duration_ms":cue.duration_ms,"source_sync_s":cue.get("source_sync_s"),"stream_s":presenter.streams[presenter._key(cue)].get_length(),
            "physics_frames":Engine.get_physics_frames()-physics_start,"process_frames":Engine.get_process_frames()-process_start,
            "playing_observations":playing_observations,"paused_observations":paused_observations,"initial":initial,"final":presenter.diagnostics(cue.id)})
    check(presenter.errors.is_empty(),"Native presenter has no errors")
    AudioServer.remove_bus_effect(bus,0);presenter.close();host.free()
    var report={"checks":checks,"failures":failures,"evidence":evidence,"audio_driver":AudioServer.get_driver_name(),"output_latency":AudioServer.get_output_latency(),"scope":"Original sounds selected by actual server journals, native AudioStreamPlayer3D handles, listener and SFX bus PCM; no claim of human listening or final professional mix."}
    FileAccess.open("res://generated/base_audio_native_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("BASE_AUDIO_NATIVE ",JSON.stringify(report))
    quit(0 if failures.is_empty() else 1)
