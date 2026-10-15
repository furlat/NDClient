extends SceneTree
## Native audio handles + actual compiler rows. Headless; listening/mix is separate.
const Cues=preload("res://presentation/audio_cues.gd")
const Presenter=preload("res://presentation/audio_presenter.gd")
const Recording=preload("res://studio/recording.gd")
const Conditions=preload("res://presentation/conditions.gd")
var checks=0
var failures:Array=[]
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("AUDIO_FAIL ",label)
func row(cue:String,id:String,start:float,duration:float=-1,ordinal:int=0)->Dictionary:
    var value=Cues.resolve(cue,id,ordinal,start,duration,{"world_position":Vector3(1,2,3)})
    value.absolute_start_ms=start;value.age_ms=0.0
    return value
func _initialize()->void:call_deferred("run")
func run()->void:
    var directory=""
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--recording="):directory=arg.trim_prefix("--recording=")
    if directory.is_empty():print("Usage: --recording=<actual Studio journal>");quit(2);return
    var catalog:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://authoring/audio/cues.json"))
    var all:Array=[]
    for cue in catalog.cues:
        for ordinal in catalog.cues[cue].clips.size():all.append(row(cue,cue+str(ordinal),100,20000,ordinal))
    var presenter=Presenter.new()
    check(presenter.prepare(all).is_empty(),"Every selected real cue loads before sampling")
    for component in all:
        var stream:AudioStream=presenter.streams[presenter._key(component)]
        check(absf(stream.get_length()-component.clip_duration_s)<.001,"Native stream duration matches selected source "+component.clip)
    check(Cues.resolve("condition_apply","missing",0,0).status=="missing","Unselected condition apply remains explicitly missing")
    check(Cues.resolve("condition_loop","unresolved",0,0).reason=="loop_interval_not_resolved","Loop requires an authoritative resolved interval")
    var looping_clock={"loop":true,"clip_duration_s":5.0,"loop_start_s":1.0,"loop_end_s":5.0}
    check(Cues.source_seconds(looping_clock,500)==.5 and Cues.source_seconds(looping_clock,5000)==1 and Cues.source_seconds(looping_clock,9500)==1.5,"Loop source clock preserves intro and wraps only the authored loop interval")
    var invalid_loop=catalog.duplicate(true);invalid_loop.cues.condition_loop.loop_end_s=1.0
    check(Cues.resolve("condition_loop","invalid-loop",0,0,20000,{}, {"audio/cues.json":invalid_loop}).reason=="ogg_loop_end_must_match_source_duration","Unsupported Ogg subrange stays explicit instead of misrepresenting native playback")
    var owner={"id":"condition-owner","actor_uuid":"actor","start_ms":0.0,"end_ms":INF,"initial":false,"condition":{"condition_uuid":"condition-owner","behavior_id":"condition.concentrating","state":{}}}
    var owners={"condition-owner":owner};var binding_cache={}
    var persistent=Conditions.samples(owners,100,binding_cache).filter(func(sample):return sample.kind=="audio")
    check(persistent.size()==1 and persistent[0].status=="missing" and persistent[0].reason=="spell_audio_deferred" and not persistent[0].has("clip") and persistent[0].assignment_source=="audio/bindings.json:/conditions/condition.concentrating/persistent","Concentration audio is explicitly unassigned and cannot prepare a stream")
    check(presenter.prepare(persistent).is_empty() and not presenter.outcomes.has(persistent[0].id),"Disabled concentration assignment never enters native source preparation")
    binding_cache["audio/bindings.json"].conditions["condition.concentrating"].erase("persistent")
    check(Conditions.samples(owners,100,binding_cache).all(func(sample):return sample.kind!="audio"),"Removing the authored persistent binding removes the sound without special condition code")
    var actor={"uuid":"actor","present":true,"spatial_disposition":"present","last_visual_position":[2,3]}
    var body={"attachment":"body","attachment_source":"disclosed_stationary_body","actor_uuid":"actor",
        "presentation_actor":{"uuid":"actor","appearance":{"visual_scale":1.0,"visual_scale_x":1.0}},
        "source_track":{"actor_uuid":"actor","rig":"rig","motion":false,"from_position":[2,3],"to_position":[2,3],"from_elevation_feet":10.0,"to_elevation_feet":10.0}}
    var rig={"body_anchor":{"x":64.0,"y":60.0}}
    var emitter=Cues.disclosed_body(body,actor,rig)
    check(emitter.position==[2,3] and emitter.base_height_steps==2,"Authored body audio can use its disclosed stationary source without a draw handle")
    for change in [{"last_visual_position":null},{"last_visual_position":[9,9]},{"present":false},{"spatial_disposition":"absent"},{"uuid":"different"}]:
        var changed=actor.duplicate(true);changed.merge(change,true)
        check(Cues.disclosed_body(body,changed,rig).is_empty(),"Unknown/moved/removed/wrong actor never supplies an audio origin: "+JSON.stringify(change))
    check(Cues.disclosed_body(body,actor,{}).is_empty(),"No authored rig anchor remains an attachment gap")
    var unknown_space=actor.duplicate(true);unknown_space.erase("spatial_disposition")
    check(Cues.disclosed_body(body,unknown_space,rig).is_empty(),"Missing spatial disclosure cannot grant a body audio origin")
    check(Cues.disclosed_body(body,actor,{"body_anchor":{}}).is_empty(),"Incomplete body anchor remains an attachment gap")
    var moving=body.duplicate(true);moving.source_track.motion=true
    check(Cues.disclosed_body(moving,actor,rig).is_empty(),"Stationary source grant does not infer a moving body")
    var socket=body.duplicate(true);socket.attachment="hand"
    check(Cues.disclosed_body(socket,actor,rig).is_empty(),"Disclosed body source never invents a hand socket")
    check(row("footstep","a",0,-1,0).clip==row("footstep","b",0,-1,3).clip and row("footstep","a",0,-1,1).clip!=row("footstep","a",0,-1,0).clip,"Variation uses occurrence ordinal deterministically")
    var host=Node3D.new();root.add_child(host)
    var shot=row("footstep","shot",100)
    var saved=shot.duplicate(true)
    presenter.sample(host,[],90,1,false,0)
    presenter.sample(host,[shot],110,1,false,0)
    check(presenter.counters.shots==1 and presenter.voices.size()==1,"One forward marker crossing creates one native voice")
    var voice:Dictionary=presenter.voices[shot.id]
    check(voice.node is AudioStreamPlayer3D and voice.node.global_position==Vector3(1,2,3),"World cue uses exact resolved spatial attachment")
    check(is_equal_approx(voice.offset_s,.01),"Late frame begins at current source offset")
    presenter.sample(host,[shot],110,1,false,0)
    check(presenter.counters.shots==1 and (voice.node.stream_paused or not voice.node.playing or voice.node.volume_linear==0),"Unchanged display time holds audio silently without replay")
    presenter.sample(host,[shot],150,1,true,0)
    check(voice.node.stream_paused or not voice.node.playing or voice.node.volume_linear==0,"Paused display silences native voice even before physics registration")
    presenter.sample(host,[shot],170,.5,false,0)
    check(not voice.node.stream_paused and voice.node.pitch_scale==.5 and is_equal_approx(voice.offset_s,.07),"Resume seeks to shared age and uses per-voice rate")
    check(shot==saved,"Sampling never mutates passive component")
    presenter.sample(host,[shot],210,1,false,0)
    check(presenter.voices.is_empty(),"Expired one-shot releases its native owner")
    presenter.sample(host,[shot],170,1,false,1)
    check(presenter.counters.shots==1,"Seek epoch suppresses historical one-shot")
    presenter.sample(host,[],90,1,false,2);presenter.sample(host,[shot],110,1,false,2)
    check(presenter.counters.shots==2,"Explicit loop pass can cross the same marker again")
    presenter.sample(host,[],0,1,false,3);presenter.sample(host,[shot],500,1,false,3)
    check(presenter.counters.expired==1 and presenter.voices.is_empty(),"Fully crossed expired short clip is counted without accumulating late audio")
    var onset=row("footstep","exact-onset",100)
    var starts=int(presenter.counters.started)
    presenter.sample(host,[onset],100,1,true,30)
    check(presenter.diagnostics(onset.id).rows[onset.id].state=="scheduled" and presenter.voices.is_empty(),"Silent exact-onset seek leaves cue scheduled")
    presenter.sample(host,[onset],101,1,false,30)
    check(presenter.counters.started==starts+1 and presenter.diagnostics(onset.id).rows[onset.id].starts==1,"Play from exact selected onset starts the cue once")
    await physics_frame;await physics_frame
    presenter.sample(host,[onset],102,1,true,30);presenter.sample(host,[onset],103,1,false,30)
    check(presenter.counters.started==starts+1,"Pause/resume preserves the already-started native voice")
    presenter.sample(host,[onset],110,1,true,31);presenter.sample(host,[onset],111,1,false,31)
    check(presenter.counters.started==starts+1 and presenter.diagnostics(onset.id).rows[onset.id].reason=="seek_inside","Silent seek inside an old one-shot does not retrigger")
    presenter.sample(host,[onset],100,1,true,32);presenter.sample(host,[onset],101,1,false,32)
    check(presenter.counters.started==starts+2,"A new pass admits the selected onset once again")
    var admitted=row("footstep","admitted",1000)
    presenter.sample(host,[],1000,1,false,3);presenter.sample(host,[admitted],1016,1,false,3)
    check(presenter.voices.has(admitted.id),"New local-zero occurrence at the previous idle clock is admitted once")
    var loop_a=row("condition_loop","owner-a",100,20000)
    var loop_b=row("condition_loop","owner-b",100,20000)
    presenter.sample(host,[loop_a,loop_b],950,1,true,4)
    check(presenter.voices.size()==2 and presenter.voices[loop_a.id].node!=presenter.voices[loop_b.id].node,"Two condition owners use independent voices for the same source")
    check(is_equal_approx(presenter.voices[loop_a.id].offset_s,.85) and not presenter.voices[loop_a.id].node.playing,"Paused nonzero seek restores active loop at exact offset")
    presenter.sample(host,[loop_a,loop_b],9000,2,false,4)
    check(is_equal_approx(presenter.voices[loop_a.id].offset_s,fposmod(8.9,loop_a.clip_duration_s)),"Loop source offset wraps within the real clip")
    var removed=weakref(presenter.voices[loop_a.id].node)
    presenter.sample(host,[loop_b],9000,2,true,4)
    check(removed.get_ref()==null and presenter.voices.size()==1,"Owner removal while paused releases only that owner immediately")
    presenter.sample(host,[],9100,1,false,4)
    check(presenter.voices.has(loop_b.id),"Playing loop removal begins authored fade")
    presenter.sample(host,[],9160,1,false,4)
    check(is_equal_approx(presenter.voices[loop_b.id].node.volume_db,loop_b.gain_db+linear_to_db(.5)),"Loop fade follows display-time amplitude")
    presenter.sample(host,[],9220,1,false,4)
    check(presenter.voices.is_empty(),"Fade completion releases native voice")
    var many:Array=[]
    for i in 8:many.append(row("footstep","limited"+str(i),100))
    presenter.sample(host,[],0,1,false,5);presenter.sample(host,many,110,1,false,5)
    check(presenter.voices.size()==4 and presenter.counters.limited==4,"Authored per-cue voice bound never delays events")
    var separate=Presenter.new();separate.prepare([onset])
    separate.sample(host,[],99,1,false,0);separate.sample(host,[onset],101,1,false,0)
    var peer_voice=separate.voices[onset.id].node
    presenter.set_enabled(false)
    check(presenter.voices.is_empty() and is_instance_valid(peer_voice),"Muting one presenter stops all its voices without touching the other pane")
    presenter.close();presenter.prepare([onset,loop_a])
    check(not presenter.enabled,"Private presenter mute survives close/reprepare")
    for attachment in ["ui","screen","body"]:
        var muted=row("footstep","muted-"+attachment,100)
        muted.attachment=attachment;muted.screen_position=Vector2(4,6)
        presenter.prepare([muted]);presenter.sample(host,[],99,1,false,40);presenter.sample(host,[muted],101,1,false,40)
        check(presenter.voices.is_empty() and presenter.diagnostics(muted.id).rows[muted.id].reason=="muted","Muted "+attachment+" source creates no audible owner")
    presenter.set_enabled(true);presenter.sample(host,[onset],120,1,false,40)
    check(presenter.voices.is_empty(),"Unmuting does not replay elapsed one-shots")
    presenter.set_enabled(false);presenter.sample(host,[loop_a],950,1,false,41)
    presenter.set_enabled(true);presenter.sample(host,[loop_a],960,1,false,41)
    check(presenter.voices.size()==1 and is_equal_approx(presenter.voices[loop_a.id].offset_s,.86),"Audible ownership admits an ongoing loop at its current source offset")
    var unavailable=loop_a.duplicate();unavailable.attachment_error="attachment_unavailable"
    presenter.sample(host,[unavailable],970,1,false,41)
    check(presenter.voices.is_empty() and presenter.diagnostics(loop_a.id).rows[loop_a.id].reason=="attachment_unavailable","Losing an admitted attachment releases the voice instead of keeping a stale origin")
    separate.close()
    presenter.close()
    check(host.get_child_count()==0 and presenter.voices.is_empty() and presenter.streams.is_empty(),"Close releases every native handle and prepared stream")
    var index=Recording.read(directory)
    check(index.ok,"Actual strict SDK recording compiles through production")
    var recorded:Array=[]
    if index.ok:
        for item in index.groups:
            for component in item.group.get("components",[]):
                if component.kind=="audio":
                    var sampled=component.duplicate();sampled.absolute_start_ms=item.start_ms+component.start_ms
                    sampled.world_position=Vector3.ZERO;recorded.append(sampled)
        check(not recorded.is_empty(),"Shared compiler produces actual audio components from real event occurrences")
        check(presenter.prepare(recorded).is_empty(),"Recorded selected cue sources prepare without substitute clips")
        var unique={}
        for component in recorded:
            check(component.source_event_uuid!="" and not unique.has(component.id),"Recorded cue retains unique causal occurrence "+component.id)
            unique[component.id]=true
        if not recorded.is_empty():
            var first:Dictionary=recorded[0]
            presenter.sample(host,[],first.absolute_start_ms-1,1,false,8)
            presenter.sample(host,[first],first.absolute_start_ms+1,1,false,8)
            check(presenter.voices.has(first.id),"Actual recorded component triggers its selected native audio owner")
            var count=presenter.counters.shots
            presenter.sample(host,[first],first.absolute_start_ms+2,1,true,9)
            check(presenter.counters.shots==count,"Recording seek does not replay its historical shot")
    presenter.close();host.free()
    var report={"checks":checks,"failures":failures,"recording":directory,"recorded_audio":recorded.size(),
        "scope":"Headless native stream/voice ownership and actual shared-compiler cue records; no audible mix, spatial acoustics or rendered waveform claim",
        "invocation":{"script":"res://tests/audio_presenter_checks.gd","arguments":Array(OS.get_cmdline_user_args())}}
    FileAccess.open("res://generated/audio_presenter_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("AUDIO_PRESENTER ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
