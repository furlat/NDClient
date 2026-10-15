extends SceneTree
## Derive finite source preview Resources from the actual recorded Studio rows.
## One monotone native history per visual phase/view; no accelerated simulation.
const Recording=preload("res://studio/recording.gd")
const Store=preload("res://studio/native_preview_store.gd")
const Packet=preload("res://studio/native_preview_resource.gd")
const Preview=preload("res://studio/native_spell_preview.gd")
const Sources=preload("res://presentation/native_effects.gd")
const Playback=preload("res://presentation/native_spell_playback.gd")
var store=Store.new()
var phases:Dictionary={}
var active:Array=[]
var pending:Array=[]
var failures:Array=[]
var cases:Array=[]
var only:String=""
var recordings:Array[String]=[]
var plan_only:bool=false
var verify_only:bool=false
var force:bool=false
var saved:int=0
var rendered:int=0
var reused:int=0
var started:int=0
var planning_ms:int=0

func _initialize()->void:run.call_deferred()

func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(320,240)
    Engine.max_fps=60;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--only="):only=argument.trim_prefix("--only=")
        if argument.begins_with("--recording="):recordings.append(argument.trim_prefix("--recording="))
        if argument=="--plan-only":plan_only=true
        if argument=="--verify-only":verify_only=true
        if argument=="--force":force=true
    started=Time.get_ticks_msec()
    var inventory:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://generated/studio_spell_case_inventory.json"))
    for item in inventory.cases:
        if not recordings.is_empty() and only.is_empty():continue
        if not only.is_empty() and item.spell_id not in only.split(","):continue
        var rows:int=0
        for perspective in item.perspectives:
            var index:Dictionary=Recording.read(perspective.journal)
            if not index.ok:failures.append({"journal":perspective.journal,"error":index.get("error","")});continue
            for row in index.rows:
                if row.kind!="native_effect" or not row.get("component",{}).get("native_spell",false) or row.get("status")=="missing" or not row.get("visible_here",true):continue
                rows+=1;_add(row,item.spell_id)
        cases.append({"spell":item.spell_id,"rows":rows})
        print("NATIVE_PREVIEW_PLAN ",item.spell_id," rows=",rows," phases=",phases.size())
        await process_frame
    # Explicit journals support subsequent real runs without rebaking/reindexing
    # the whole library. --only may additionally select existing library cases.
    for recording in recordings:
        var index:Dictionary=Recording.read(recording)
        if not index.ok:failures.append({"journal":recording,"error":index.get("error","")});continue
        var rows:int=0
        for row in index.rows:
            if row.kind!="native_effect" or not row.get("component",{}).get("native_spell",false) or row.get("status")=="missing" or not row.get("visible_here",true):continue
            rows+=1;_add(row,str(row.component.get("spell_id","")))
        cases.append({"journal":recording,"rows":rows})
        print("NATIVE_PREVIEW_PLAN ",recording," rows=",rows," phases=",phases.size())
        await process_frame
    planning_ms=Time.get_ticks_msec()-started
    var samples:int=0;var histories:float=0
    for phase in phases.values():
        phase.ticks=phase.ticks.keys();phase.ticks.sort()
        samples+=phase.ticks.size()*4
        if not phase.ticks.is_empty():histories+=float(phase.ticks.back())/phase.descriptor.hz*4
        for quarter in 4:pending.append({"phase":phase,"quarter":quarter})
    print("NATIVE_PREVIEW_PLAN_TOTAL ",JSON.stringify({"phases":phases.size(),"samples":samples,"jobs":pending.size(),"source_seconds_without_held_reuse":histories,"planning_ms":planning_ms}))
    if verify_only:
        var missing:Dictionary={}
        for job in pending:
            for tick in job.phase.ticks:
                if store.lookup(job.phase.descriptor,tick,job.quarter)==null:
                    var path:String=Store.resource_path(job.phase.descriptor.signature,job.quarter,tick)
                    if not missing.has(path):missing[path]=[]
                    missing[path].append(tick)
        for path in missing:failures.append({"resource":path,"missing_ticks":missing[path]})
    elif not plan_only:
        DirAccess.make_dir_recursive_absolute(Store.DIRECTORY)
        while not pending.is_empty() or not active.is_empty():
            while active.size()<8 and not pending.is_empty():
                var job:Dictionary=pending.pop_front()
                if not force and _exists(job):reused+=job.phase.ticks.size();continue
                var node=Preview.new();root.add_child(node)
                var issue:String=node.configure_component(job.phase.component)
                if not issue.is_empty():failures.append(issue);node.close();node.queue_free();continue
                job.merge({"node":node,"at":0,"packet":null,"chunk":-999999,"previous_texture":null,"previous_source":NAN,"previous_bytes":0,"deadline":Time.get_ticks_msec()+15000})
                active.append(job)
            await process_frame
            for i in range(active.size()-1,-1,-1):
                if await _step(active[i]):
                    active[i].node.close();active[i].node.queue_free();active.remove_at(i)
        var manifest_error:Error=store.save_manifest()
        if manifest_error!=OK:failures.append("Saving preview manifest: "+str(manifest_error))
        await process_frame;await RenderingServer.frame_post_draw
    var report={"scope":"Exact source previews on the recorded finite source-age grid, all four views. Not authoritative game state or artistic approval.","plan_only":plan_only,"verify_only":verify_only,"cases":cases,"phases":phases.size(),"samples":samples,"jobs":phases.size()*4,"source_seconds_without_held_reuse":histories,"planning_ms":planning_ms,"elapsed_ms":Time.get_ticks_msec()-started,"saved_resources":saved,"rendered_samples":rendered,"reused_samples":reused,"disk_hits":store.hits,"disk_misses":store.misses,"disk_loads":store.disk_loads,"failures":failures}
    var suffix:String="-"+only.replace(",","-") if not only.is_empty() else ""
    if not recordings.is_empty():suffix+="-recording"
    FileAccess.open("res://.runtime/native-preview-bake"+suffix+("-verify" if verify_only else ("-plan" if plan_only else ""))+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_PREVIEW_BAKE ",JSON.stringify(report))
    quit(0 if failures.is_empty() else 1)

func _add(row:Dictionary,spell:String)->void:
    var component:Dictionary=row.component
    var hz:float=maxf(1,float(row.get("source_fps",component.get("sample_hz",32))))
    var descriptor:Dictionary=store.descriptor(component,hz)
    if not phases.has(descriptor.signature):phases[descriptor.signature]={"descriptor":descriptor,"component":component,"ticks":{},"spells":{}}
    var phase:Dictionary=phases[descriptor.signature];phase.spells[spell]=true
    var start:float=Sources.source_age_ms(component,float(row.start_ms)-float(row.get("source_start_ms",row.start_ms)))
    var end:float=Sources.source_age_ms(component,float(row.end_ms)-.000001-float(row.get("source_start_ms",row.start_ms)))
    if not is_finite(start) or not is_finite(end):failures.append("Unbounded recorded source interval: "+str(row.id));return
    for tick in range(floori(start*hz/1000.0),floori(maxf(start,end)*hz/1000.0)+1):phase.ticks[tick]=true

func _exists(job:Dictionary)->bool:
    for tick in job.phase.ticks:
        if store.lookup(job.phase.descriptor,tick,job.quarter)==null:return false
    return true

func _step(job:Dictionary)->bool:
    var phase:Dictionary=job.phase
    while job.at<phase.ticks.size():
        var tick:int=phase.ticks[job.at]
        var age:float=float(tick)/phase.descriptor.hz
        var source_age:float=Playback.source_time(phase.component.native_cue,age)
        var held:bool=phase.component.get("persistent_owner",false) and job.previous_texture!=null and source_age==job.previous_source
        var texture:Texture2D
        var bytes:int=0
        if held:texture=job.previous_texture;bytes=job.previous_bytes
        else:
            var basis=Basis.from_euler(Vector3(-atan(sqrt(.5)),PI/4+job.quarter*PI/2,0))
            var sampled:Dictionary=job.node.sample(age,basis,Vector3.ZERO,1.0,[],{})
            if not sampled.get("error","").is_empty():failures.append(sampled.error);return true
            if not sampled.ready:
                if Time.get_ticks_msec()>int(job.deadline):failures.append("Native source timeout: "+str(phase.component.source_id)+" at "+str(age));return true
                return false
            var image:Image=Store.image(job.node.texture().get_image())
            texture=ImageTexture.create_from_image(image);bytes=image.get_data_size();rendered+=1
        var chunk:int=floori(float(tick)/Store.CHUNK_FRAMES)
        if chunk!=job.chunk:
            if job.packet!=null:_save(job)
            job.chunk=chunk;job.packet=Packet.new()
            job.packet.signature=phase.descriptor.signature;job.packet.specification=phase.descriptor.specification
            job.packet.dependencies=phase.descriptor.dependencies;job.packet.quarter=job.quarter;job.packet.hz=phase.descriptor.hz
        job.packet.ticks.append(tick);job.packet.textures.append(texture);job.packet.sizes.append(bytes)
        job.packet.texture_bytes+=bytes
        job.previous_texture=texture;job.previous_source=source_age;job.previous_bytes=bytes
        job.at+=1;job.deadline=Time.get_ticks_msec()+15000
        if not held:return false
    if job.packet!=null:_save(job)
    store.record(phase.descriptor)
    print("NATIVE_PREVIEW_SAVED ",phase.spells.keys()," q",job.quarter," ticks=",phase.ticks.size())
    return true

func _save(job:Dictionary)->void:
    var path:String=Store.resource_path(job.phase.descriptor.signature,job.quarter,job.packet.ticks[0])
    if FileAccess.file_exists(path):
        var previous:Resource=ResourceLoader.load(path,"",ResourceLoader.CACHE_MODE_IGNORE)
        if not merge_page(previous,job.packet):
            failures.append("Cannot merge invalid prior preview Resource: "+path);return
    var error:Error=ResourceSaver.save(job.packet,path+".tmp.res",ResourceSaver.FLAG_COMPRESS)
    if error==OK:error=DirAccess.rename_absolute(path+".tmp.res",path)
    if error!=OK:failures.append("Saving preview Resource: "+path+" / "+str(error))
    else:saved+=1

static func merge_page(previous:Resource,packet:Resource)->bool:
    if not previous is Packet or not packet is Packet:return false
    if previous.format_version!=packet.format_version or previous.signature!=packet.signature or previous.quarter!=packet.quarter or previous.hz!=packet.hz:return false
    if packet.ticks.is_empty():return false
    var chunk:int=floori(float(packet.ticks[0])/Store.CHUNK_FRAMES)
    var frames:Dictionary={}
    # A later recording may request another portion of the same page. Preserve
    # earlier exact samples, replacing only ticks that were explicitly rebaked.
    for source in [previous,packet]:
        if source.ticks.size()!=source.textures.size() or source.ticks.size()!=source.sizes.size() or source.ticks.size()>Store.CHUNK_FRAMES:return false
        for index in source.ticks.size():
            var tick:int=source.ticks[index]
            if floori(float(tick)/Store.CHUNK_FRAMES)!=chunk:return false
            frames[tick]={"texture":source.textures[index],"bytes":source.sizes[index]}
    var ticks:Array=frames.keys();ticks.sort()
    packet.ticks.clear();packet.textures.clear();packet.sizes.clear();packet.texture_bytes=0
    for tick in ticks:
        packet.ticks.append(tick);packet.textures.append(frames[tick].texture)
        packet.sizes.append(frames[tick].bytes);packet.texture_bytes+=frames[tick].bytes
    return true
