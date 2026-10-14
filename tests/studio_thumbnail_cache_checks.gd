extends SceneTree
## Actual recorded source crops, cache scheduling, and optional native swatches.
const Recording=preload("res://studio/recording.gd")
const Thumbnails=preload("res://studio/thumbnail_cache.gd")
var checks=0
var failures:Array=[]
var evidence:Dictionary={}
var native=false
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("THUMBNAIL_CACHE_FAIL ",label)
func _same_parts(a:Dictionary,b:Dictionary)->bool:
    if a.has("error") or b.has("error") or a.parts.size()!=b.parts.size():return false
    for i in a.parts.size():
        if a.parts[i].image.get_data()!=b.parts[i].image.get_data():return false
    return true
func run()->void:
    native="--native" in OS.get_cmdline_user_args()
    var index=Recording.read("res://.runtime/studio-cases/dash-seed3/amber/journal")
    check(index.ok,"Actual server journal admits")
    if not index.ok:finish();return
    var body:Dictionary=index.rows.filter(func(row):return row.kind=="body" and row.end_ms>row.start_ms)[0]
    var at=(body.start_ms+body.end_ms)*.5
    var thumb=Thumbnails.new();thumb.cache=index.cache
    var key=thumb.request(body,at,0)
    check(thumb.pending.size()==1 and thumb.warm_pending.size()==3,"Only visible view enters immediate work; other three prepare in background")
    thumb.request(body,at,0)
    check(thumb.pending.size()==1 and thumb.warm_pending.size()==3,"Repeated redraw does not duplicate source work")
    var job:Dictionary=thumb.pending[0]
    var legacy=Thumbnails.new();legacy.image_limit=64*1024*1024
    var started=Time.get_ticks_usec()
    var before=legacy._decode(job)
    var cold_before=(Time.get_ticks_usec()-started)/1000.0
    var reads=legacy.source_reads
    started=Time.get_ticks_usec();var before_repeat=legacy._decode(job)
    var repeat_before=(Time.get_ticks_usec()-started)/1000.0
    check(legacy.source_reads>reads,"Actual assembled source exceeds old cache and demonstrates repeated PNG reads")
    started=Time.get_ticks_usec();var first=thumb._decode(job)
    var cold_after=(Time.get_ticks_usec()-started)/1000.0
    reads=thumb.source_reads
    started=Time.get_ticks_usec();var repeated=thumb._decode(job)
    var repeat_after=(Time.get_ticks_usec()-started)/1000.0
    check(thumb.source_reads==reads,"Warm source pose performs no PNG reads")
    check(_same_parts(before,first) and _same_parts(before_repeat,repeated),"Cache policy leaves every original cropped layer byte-identical")
    check(thumb.image_bytes<=thumb.image_limit,"Actual assembled source residency stays within bounded CPU cache")
    evidence={"cold_before_ms":cold_before,"repeat_before_ms":repeat_before,"cold_after_ms":cold_after,"repeat_after_ms":repeat_after,
        "source_parts":first.get("parts",[]).size(),"source_bytes":thumb.image_bytes,"source_budget_bytes":thumb.image_limit,
        "old_repeat_source_reads":legacy.source_reads-reads,"warm_repeat_source_reads":thumb.source_reads-reads}
    legacy.close()
    var visible_key=thumb.request(body,at,2)
    check(thumb.pending.size()==2 and thumb.pending[1].key==visible_key,"Rotation can request a not-yet-warmed view without waiting for background descriptors")
    var queued=thumb.pending.size();thumb._prepare_view()
    check(thumb.pending.size()==queued,"Background preparation never advances ahead of visible source jobs")
    thumb.pending.clear()
    thumb._prepare_view()
    check(not thumb.pending.is_empty() and thumb.pending.size()<=thumb.batch_size and thumb.pending[0].quarter==1,"Idle preparation resolves a bounded batch of authored camera views")
    var quarter_job:Dictionary=thumb.pending[0]
    reads=thumb.source_reads;var quarter=thumb._decode(quarter_job)
    check(not quarter.has("error") and thumb.source_reads==reads,"Another quarter samples cached sheets without decoding them again")
    var labels=index.rows.filter(func(row):return row.kind in ["feedback_text","damage_number"] and row.get("status")!="missing")
    check(not labels.is_empty(),"Recording contains an actual view-independent source label")
    if not labels.is_empty():
        var label:Dictionary=labels[0];var label_at=(label.start_ms+label.end_ms)*.5
        var label_key=thumb.request(label,label_at,0)
        check(thumb.request(label,label_at,3)==label_key,"View-independent labels reuse one source swatch across rotation")
    thumb.reset()
    check(thumb.pending.is_empty() and thumb.warm_pending.is_empty() and thumb.warm_requested.is_empty(),"Changing recording generation cancels all queued old-quarter preparation")
    thumb.cache=index.cache
    var part:Dictionary=index.rows.filter(func(row):return row.kind=="part")[0]
    var descriptors:Array=[]
    for row in [part,body]:
        for q in [3,1,2,0]:descriptors.append({"row":row,"sample_ms":(row.start_ms+row.end_ms)*.5,"quarter":q})
    thumb.queue_prewarm(descriptors)
    check(thumb.pending.is_empty() and thumb.warm_pending.size()==8,"All-row prewarm admits only bounded passive descriptors before idle resolution")
    check(thumb.warm_pending.slice(0,4).all(func(sample):return sample.row.id==body.id) and thumb.warm_pending.slice(0,4).map(func(sample):return sample.quarter)==[0,1,2,3],"Main source row and all its quarters precede optional gear inspection")
    var foreground=thumb.request(body,at,1,false)
    var unresolved=thumb.warm_pending.size();thumb._prepare_view()
    check(thumb.warm_pending.size()==unresolved and thumb.pending[0].key==foreground,"Visible source demand prevents all background resolution")
    thumb.queue_prewarm([{ "row":body,"sample_ms":at+1,"quarter":2}])
    check(thumb.warm_pending.size()==1 and thumb.warm_pending[0].sample_ms==at+1 and thumb.pending[0].key==foreground,"Changing zoom demand replaces obsolete descriptors without canceling foreground work")
    var original_limit=thumb.limit;thumb.limit=3;thumb.queue_prewarm(descriptors)
    check(thumb.warm_pending.size()==3 and thumb.warm_requested.size()==3,"Background descriptor count respects the existing cache limit")
    thumb.limit=original_limit
    thumb.close()
    _prewarm_pause(index,body,at)
    if native:await _native(index,body,at)
    evidence.native_swatches_checked=native
    finish()
func _prewarm_pause(index:Dictionary,body:Dictionary,at:float)->void:
    var thumb=Thumbnails.new();thumb.cache=index.cache;thumb.host=root
    thumb.queue_prewarm([{ "row":body,"sample_ms":at,"quarter":2}])
    var retained=thumb.warm_pending.duplicate(true)
    thumb.prewarm_suspended=true
    thumb.poll()
    check(thumb.warm_pending==retained and thumb.pending.is_empty() and thumb.worker==null,"Renderer preparation pauses background resolution while retaining its exact descriptors")
    var audio=index.rows.filter(func(row):return row.kind=="audio" and row.get("status")!="missing")
    check(not audio.is_empty(),"Actual Dash recording supplies a foreground audio waveform")
    if not audio.is_empty():
        var row:Dictionary=audio[0]
        var key=thumb.request(row,(row.start_ms+row.end_ms)*.5,0,false)
        thumb.set_demand({key:true});thumb.poll()
        check(thumb.textures.has(key) and thumb.errors.is_empty(),"Explicit foreground waveform finishes through poll while background prewarm remains paused")
        check(thumb.warm_pending==retained,"Foreground publication does not discard or resolve the paused background descriptors")
    thumb.prewarm_suspended=false
    thumb._prepare_view()
    check(thumb.warm_pending.is_empty() and thumb.pending.size()==1 and thumb.pending[0].quarter==2,"Resuming prewarm admits the previously retained authored quarter without another request")
    if not thumb.pending.is_empty():
        var prepared=thumb._decode(thumb.pending[0])
        check(not prepared.has("error") and not prepared.parts.is_empty(),"Resumed queued quarter resolves actual source sprite layers")
    thumb.close()
func _native(index:Dictionary,row:Dictionary,at:float)->void:
    var thumb=Thumbnails.new();thumb.cache=index.cache;thumb.host=root
    var keys={0:thumb.request(row,at,0)}
    var started=Time.get_ticks_msec()
    while Time.get_ticks_msec()-started<15000 and (thumb.textures.size()<4 or not thumb.pending.is_empty() or not thumb.warm_pending.is_empty() or not thumb.active.is_empty() or thumb.worker!=null):
        thumb.poll();await process_frame
    check(thumb.errors.is_empty(),"Actual source swatches have no native preparation errors")
    check(thumb.textures.size()==4,"First visible request prepares all four native camera swatches")
    var jobs_before=thumb.pending.size();var reads_before=thumb.source_reads
    for q in 4:
        keys[q]=thumb.request(row,at,q)
        check(thumb.textures.has(keys[q]),"Rotating to prepared view immediately returns its actual swatch: "+str(q))
        if thumb.textures.has(keys[q]):check(thumb.textures[keys[q]].get_image().get_used_rect().has_area(),"Prepared native swatch has real source pixels: "+str(q))
    check(thumb.pending.size()==jobs_before and thumb.source_reads==reads_before,"Cycling every prepared quarter schedules zero reloads")
    evidence.native_prepare_ms=Time.get_ticks_msec()-started
    evidence.native_swatches=thumb.textures.size()
    thumb.close();await process_frame
func finish()->void:
    var report={"checks":checks,"failures":failures,"evidence":evidence,
        "scope":"Actual journal source preparation and bounded camera-quarter cache; native mode additionally checks real original body framebuffer swatches. No new effects or material changes."}
    var path="res://generated/studio_thumbnail_native_checks.json" if native else "res://generated/studio_thumbnail_cache_checks.json"
    FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("STUDIO_THUMBNAIL_CACHE ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
