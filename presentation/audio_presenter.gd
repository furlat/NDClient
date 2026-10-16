extends RefCounted
const AudioCues=preload("res://presentation/audio_cues.gd")
## Native voices consume the shared display clock. No event/actor scheduling.
## prepare() loads selected originals; sample() never loads a stream from disk.
var streams: Dictionary={}
var voices: Dictionary={}
var prepared_voices: Dictionary={}
var loads: Dictionary={}
var preparation_counts={"loads":0,"voices":0,"sample_constructors":0}
var errors: Array=[]
var last_ms: float=NAN
var sampled_ms: float=NAN
var epoch: int=-1
var consumed: Dictionary={}
var enabled := true
var outcomes: Dictionary={}
const DIAGNOSTIC_LIMIT=512
var counters={"shots":0,"loops":0,"crossed":0,"expired":0,"limited":0,"missing":0,"started":0,"muted":0}

func _record(row: Dictionary, state: String, reason: String="") -> void:
    var id: String=row.id
    if not outcomes.has(id):
        outcomes[id]={"id":id,"cue_id":row.get("cue_id",""),"starts":0}
        while outcomes.size()>DIAGNOSTIC_LIMIT:outcomes.erase(outcomes.keys()[0])
    outcomes[id].state=state;outcomes[id].reason=reason
    outcomes[id].source_ready=streams.has(_key(row))
    outcomes[id].attachment=row.get("attachment","body")
    outcomes[id].bus=row.get("bus","Master")
    outcomes[id].gain_db=row.get("gain_db",0.0)
    outcomes[id].display_ms=sampled_ms

func diagnostics(component_id: String="") -> Dictionary:
    # 'started' means native play was dispatched, never a claim of heard output.
    var rows={}
    for id in outcomes:
        if not component_id.is_empty() and id!=component_id:continue
        var entry:Dictionary=outcomes[id].duplicate()
        var voice:Dictionary=voices.get(id,{})
        entry.native_playing=not voice.is_empty() and voice.node.playing
        entry.paused=not voice.is_empty() and voice.paused
        entry.offset_s=voice.get("offset_s")
        entry.enabled=enabled
        rows[id]=entry
    return {"enabled":enabled,"rows":rows,"counters":counters.duplicate(),"errors":errors.duplicate()}

func set_enabled(value: bool) -> void:
    if enabled==value:return
    enabled=value
    if not enabled:
        for id in voices.keys():
            var row:Dictionary=voices[id].row
            _release(id);_record(row,"skipped","muted")

func _play(voice: Dictionary, offset: float) -> void:
    voice.node.play(offset);voice.started=true
    _record(voice.row,"started")
    outcomes[voice.row.id].starts+=1;counters.started+=1

func _key(row: Dictionary) -> String:
    return str([row.get("clip",""),row.get("loop",false),row.get("loop_start_s",0.0),row.get("loop_end_s",0.0)])

func _error(message: String) -> void:
    if message not in errors: errors.append(message)

static func _read_stream(row:Dictionary,result:Dictionary)->void:
    var path:String=row.clip
    var stream:AudioStream
    if not FileAccess.file_exists(path):result.error="Missing audio source: "+path;return
    match path.get_extension().to_lower():
        "ogg":stream=AudioStreamOggVorbis.load_from_file(path)
        "wav":stream=AudioStreamWAV.load_from_file(path)
        _:result.error="Unsupported audio source: "+path;return
    if stream==null:result.error="Missing audio source: "+path;return
    if row.get("loop",false):
        if stream is AudioStreamOggVorbis:
            stream.loop=true;stream.loop_offset=row.get("loop_start_s",0.0)
        else:
            stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
            stream.loop_begin=int(row.get("loop_start_s",0.0)*stream.mix_rate)
            stream.loop_end=int(row.get("loop_end_s",stream.get_length())*stream.mix_rate)
    result.stream=stream

func ready(components:Array)->bool:
    for row in components:
        if row.get("kind")=="audio" and row.get("status")=="available":
            if not streams.has(_key(row)) or (not prepared_voices.has(row.id) and not voices.has(row.id)):return false
    return true

func prepare(components:Array,host:Node=null,budget:Dictionary={})->Array:
    var started:int=Time.get_ticks_usec()
    var wanted:Dictionary={}
    for row in components:
        if row.get("kind")!="audio" or row.get("status")!="available":continue
        wanted[row.id]=true
        var key:String=_key(row)
        if not streams.has(key):
            if not loads.has(key):
                var output:Dictionary={}
                loads[key]={"result":output,"task":WorkerThreadPool.add_task(_read_stream.bind(row,output),false,"Authored audio stream")}
                preparation_counts.loads+=1
            var job:Dictionary=loads[key]
            if not WorkerThreadPool.is_task_completed(job.task):continue
            WorkerThreadPool.wait_for_task_completion(job.task)
            if job.result.has("error"):_error(job.result.error);continue
            streams[key]=job.result.stream;loads.erase(key)
        if not outcomes.has(row.id):_record(row,"ready")
        if voices.has(row.id) or prepared_voices.has(row.id):continue
        if not budget.is_empty() and budget.used_usec+Time.get_ticks_usec()-started>=budget.limit_usec:continue
        var bus:String=row.get("bus","Master")
        if AudioServer.get_bus_index(bus)<0:
            AudioServer.add_bus();AudioServer.set_bus_name(AudioServer.bus_count-1,bus)
        var node:Node
        match row.get("attachment","body"):
            "ui":node=AudioStreamPlayer.new()
            "screen":node=AudioStreamPlayer2D.new()
            _:node=AudioStreamPlayer3D.new()
        node.stream=streams[key];node.bus=bus;node.autoplay=false
        _gain(node,row.get("gain_db",0.0))
        if host!=null:host.add_child(node)
        prepared_voices[row.id]=node;preparation_counts.voices+=1
    # Retire only unused quiet candidates; active voices keep their own lease.
    for id in prepared_voices.keys():
        if wanted.has(id):continue
        if not budget.is_empty() and budget.used_usec+Time.get_ticks_usec()-started>=budget.limit_usec:break
        prepared_voices[id].free();prepared_voices.erase(id)
    if not budget.is_empty():budget.used_usec+=Time.get_ticks_usec()-started
    return errors

func _gain(node: Node, gain_db: float) -> void:
    node.volume_db=gain_db
    # Native inverse-distance attenuation can otherwise amplify a close source
    # up to the default +3dB, overriding the authored quiet cue gain.
    if node is AudioStreamPlayer3D:node.max_db=gain_db

func _position(node: Node, row: Dictionary) -> bool:
    if row.get("attachment_error","")!="":return false
    if node is AudioStreamPlayer3D:
        if not row.has("world_position"): return false
        node.global_position=row.world_position
    elif node is AudioStreamPlayer2D:
        if not row.has("screen_position"): return false
        node.global_position=row.screen_position
    return true

func _offset(row: Dictionary, age_ms: float) -> float:
    return AudioCues.source_seconds(row,age_ms)

func _start(host: Node, row: Dictionary, age_ms: float, speed: float, paused: bool) -> void:
    if voices.has(row.id): return
    if not enabled:
        if outcomes.get(row.id,{}).get("reason")!="muted":counters.muted+=1
        _record(row,"skipped","muted");return
    if row.get("attachment_error","")!="":
        _record(row,"skipped",row.attachment_error);return
    var key=_key(row)
    if not streams.has(key):
        counters.missing+=1;_record(row,"skipped","source_not_ready");_error("Audio not prepared: "+str(row.get("clip")));return
    var same=0
    for voice in voices.values():
        if voice.row.cue_id==row.cue_id: same+=1
    if voices.size()>=int(row.get("total_voice_limit",24)) or same>=int(row.get("voice_limit",4)):
        counters.limited+=1;_record(row,"skipped","voice_limit");return
    if not prepared_voices.has(row.id):
        counters.missing+=1;_record(row,"skipped","voice_not_prepared");_error("Audio voice not prepared: "+str(row.id));return
    var node:Node=prepared_voices[row.id];prepared_voices.erase(row.id)
    if node.get_parent()==null:host.add_child(node)
    _gain(node,row.get("gain_db",0.0));node.pitch_scale=maxf(.01,speed)
    if not _position(node,row):
        _record(row,"skipped","attachment_unresolved");node.free();return
    var offset=_offset(row,age_ms)
    # Spatial players register with AudioServer on their next physics tick.
    # Pausing before that registration has no native recall, so held seeks own
    # a silent handle and start at the restored source offset only on resume.
    voices[row.id]={"node":node,"row":row,"offset_s":offset,"fade_ms":-1.0,"paused":paused,"speed":speed,"started":false}
    if not paused:_play(voices[row.id],offset)
    else:_record(row,"scheduled","paused")
    counters["loops" if row.get("loop",false) else "shots"]+=1

func _release(id: String) -> void:
    _record(voices[id].row,"finished")
    var node: Node=voices[id].node
    node.stop();prepared_voices[id]=node;voices.erase(id)

func sample(host: Node, components: Array, display_ms: float, speed: float, paused: bool, seek_epoch: int) -> void:
    sampled_ms=display_ms
    var discontinuity=is_nan(last_ms) or seek_epoch!=epoch or display_ms<last_ms
    if discontinuity:
        for id in voices.keys(): _release(id)
        consumed.clear()
    var forward=not discontinuity and display_ms>last_ms and not paused and speed>0
    var held=paused or speed<=0 or (not discontinuity and display_ms==last_ms)
    var active={}
    for row in components:
        if row.get("kind")!="audio" or row.get("status")!="available": continue
        var start: float=row.absolute_start_ms
        var age: float=display_ms-start
        var loop: bool=row.get("loop",false)
        var live=age>=0 and age<float(row.duration_ms)
        if loop and live:
            active[row.id]=row
            if not voices.has(row.id): _start(host,row,age,speed,held)
        elif not loop and forward and start<=display_ms and start>=last_ms and not consumed.has(row.id):
            consumed[row.id]=start
            counters.crossed+=1
            if live: _start(host,row,age,speed,held)
            else:
                counters.expired+=1;_record(row,"skipped","expired")
        elif not loop and not consumed.has(row.id) and not voices.has(row.id):
            if age==0:_record(row,"scheduled","paused" if held else "onset")
            elif age>0 and discontinuity:_record(row,"skipped","seek_inside")
        if live and voices.has(row.id):
            active[row.id]=row
    for id in voices.keys():
        var voice: Dictionary=voices[id]
        var node: Node=voice.node
        if active.has(id):
            var row: Dictionary=active[id]
            if _key(row)!=_key(voice.row):
                _release(id)
                if row.get("loop",false): _start(host,row,display_ms-row.absolute_start_ms,speed,held)
                continue
            voice.row=row;voice.fade_ms=-1.0
            if not _position(node,row):
                _release(id);_record(row,"skipped",row.get("attachment_error","attachment_unresolved"));continue
            var offset=_offset(row,display_ms-row.absolute_start_ms)
            if held:
                node.stream_paused=true
            elif not voice.started:
                _play(voice,offset)
            elif voice.paused!=held or voice.speed!=speed: node.seek(offset)
            voice.offset_s=offset;voice.paused=held;voice.speed=speed
            node.pitch_scale=maxf(.01,speed);node.stream_paused=held;_gain(node,row.get("gain_db",0.0))
            # A spatial play request may still be waiting for its first physics
            # registration, where stream_paused cannot yet take effect. Silence
            # that pending request until it can pause; retain the same playback.
            if held:node.volume_linear=0.0
        else:
            # Removal while paused releases immediately; no zombie owner resumes.
            var fade: float=voice.row.get("fade_out_ms",0)
            if not voice.row.get("loop",false) or held or fade<=0:
                _release(id);continue
            if voice.fade_ms<0: voice.fade_ms=display_ms
            var remaining=1.0-(display_ms-voice.fade_ms)/fade
            if remaining<=0: _release(id)
            else:
                _gain(node,voice.row.get("gain_db",0.0)+linear_to_db(remaining))
                node.pitch_scale=maxf(.01,speed);node.stream_paused=false
    # Only starts exactly on this clock can be considered again next frame.
    # Earlier crossings cannot recur without a seek, which resets this set.
    for id in consumed.keys():
        if consumed[id]<display_ms:consumed.erase(id)
    last_ms=display_ms;epoch=seek_epoch

func close() -> void:
    for id in voices.keys(): _release(id)
    for node in prepared_voices.values():node.free()
    prepared_voices.clear();loads.clear()
    streams.clear();consumed.clear();outcomes.clear();last_ms=NAN;sampled_ms=NAN;epoch=-1
