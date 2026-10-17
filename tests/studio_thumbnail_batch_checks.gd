extends SceneTree
## Same native source compositor at one/eight swatches, using real recordings.
const Recording=preload("res://studio/recording.gd")
const Thumbnails=preload("res://studio/thumbnail_cache.gd")
var checks=0
var failures:Array=[]
var evidence:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("THUMBNAIL_BATCH_FAIL ",label)
func render(index:Dictionary,rows:Array,batch:int)->Dictionary:
    var cache=Thumbnails.new();cache.host=root;cache.cache=Thumbnails.Catalog.source_snapshot(index.cache);cache.batch_size=batch
    var keys={}
    for row in rows:
        for fraction in [.25,.7]:
            for quarter in 4:
                var key=cache.request(row,lerpf(row.start_ms,row.end_ms,fraction),quarter,false)
                if not key.is_empty():keys[key]=true
    cache.set_demand(keys)
    var peak=0;var started=Time.get_ticks_msec();var deadline=started+30000
    while keys.keys().any(func(key):return not cache.textures.has(key) and not cache.errors.has(key) and not cache.inactive.has(key)) and Time.get_ticks_msec()<deadline:
        cache.poll();peak=maxi(peak,cache.composites.size());await process_frame
    var elapsed=Time.get_ticks_msec()-started
    check(cache.errors.is_empty(),"Actual source recipes have no native errors at batch "+str(batch))
    check(keys.keys().all(func(key):return cache.textures.has(key) or cache.inactive.has(key)),"Every requested actual swatch settles at batch "+str(batch))
    check(peak<=batch and cache.texture_bytes<=cache.texture_limit and cache.image_bytes<=cache.image_limit,"Native batch stays within view/source/texture bounds "+str(batch))
    var pixels={}
    for key in cache.textures:
        var image:Image=cache.textures[key].get_image()
        pixels[key]={"size":image.get_size(),"format":image.get_format(),"bytes":image.get_data()}
    var result={"pixels":pixels,"elapsed_ms":elapsed,"source_reads":cache.source_reads,"peak_views":peak,"samples":keys.size()}
    cache.close();await process_frame
    return result
func cancel_batch(index:Dictionary,row:Dictionary)->void:
    var cache=Thumbnails.new();cache.host=root;cache.cache=Thumbnails.Catalog.source_snapshot(index.cache)
    for quarter in 4:cache.request(row,(row.start_ms+row.end_ms)*.5,quarter,false)
    var deadline=Time.get_ticks_msec()+15000
    while cache.composites.is_empty() and Time.get_ticks_msec()<deadline:
        cache.poll()
        if cache.composites.is_empty():await process_frame
    check(not cache.composites.is_empty(),"Actual ordinary batch reaches submitted native composition before cancellation")
    cache.reset();cache.cache=Thumbnails.Catalog.source_snapshot(index.cache)
    check(cache.composites.is_empty() and not RenderingServer.frame_post_draw.is_connected(cache._composites_drawn),"Reset retires every pending viewport and its one frame acknowledgement")
    var fresh=cache.request(row,(row.start_ms+row.end_ms)*.6,2,false)
    while not cache.textures.has(fresh) and not cache.errors.has(fresh) and Time.get_ticks_msec()<deadline:
        cache.poll();await process_frame
    check(cache.textures.has(fresh) and cache.textures.size()==1,"Only the replacement generation publishes after resetting a submitted batch")
    cache.close();await process_frame
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(640,480)
    var exercised={}
    for name in ["melee-seed3","hide-light-schema9-seed3","dodge-seed3","condition_owners-seed4","magic_missile-seed3"]:
        var index=Recording.read("res://.runtime/studio-cases/"+name+"/amber/journal")
        check(index.ok,"Actual source recording indexes: "+name)
        if not index.ok:continue
        var rows:Array=[];var kinds={}
        for row in index.rows:
            if row.kind not in ["body","material_flash","condition_material","condition_restore","sprite_layer"] or row.get("status")=="missing" or not row.get("visible_here",true):continue
            if kinds.has(row.kind):continue
            kinds[row.kind]=true;exercised[row.kind]=true;rows.append(row)
        if DisplayServer.get_name()=="headless":
            evidence.append({"case":name,"kinds":kinds.keys()});continue
        var serial=await render(index,rows,1)
        var batched=await render(index,rows,8)
        check(serial.pixels.size()==batched.pixels.size() and serial.pixels.keys().all(func(key):return batched.pixels.has(key)),"One/eight paths publish the same actual source sample keys: "+name)
        var mismatches=[]
        for key in serial.pixels:
            if serial.pixels[key]!=batched.pixels.get(key):mismatches.append(key)
        check(mismatches.is_empty(),"Every final native swatch byte matches the single-composite path: "+name)
        evidence.append({"case":name,"kinds":kinds.keys(),"samples":batched.samples,"serial_ms":serial.elapsed_ms,"batch_ms":batched.elapsed_ms,"serial_source_reads":serial.source_reads,"batch_source_reads":batched.source_reads,"peak_batch_views":batched.peak_views,"pixel_mismatches":mismatches})
        if name=="melee-seed3":await cancel_batch(index,rows[0])
    # Sprite-sheet condition media have no renderer (they show nothing until a
    # native source is authored); no recording may produce them.
    check(exercised.has("body") and exercised.has("material_flash") and exercised.has("condition_restore") and not exercised.has("registered_media"),"Parity set includes real body, impact material and condition restoration; no sprite-sheet media")
    finish()
func finish()->void:
    var report={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Actual source recipes through identical Godot shaders/viewports at batch size one/eight. Pixel-for-pixel comparison; native VFX and blood simulation paths remain unchanged."}
    FileAccess.open("res://generated/studio_thumbnail_batch_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("STUDIO_THUMBNAIL_BATCH ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
