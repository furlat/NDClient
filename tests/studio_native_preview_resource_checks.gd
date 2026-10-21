extends SceneTree
## Fresh-process disk thumbnails at the real Recording -> TimelineView boundary.
## This measures thumbnail availability, not full Studio Library navigation.
const Fixtures=preload("res://tests/recording_fixtures.gd")
const Effects=preload("res://presentation/effect_package.gd")
const Recording=preload("res://studio/recording.gd")
const TimelineView=preload("res://studio/timeline_view.gd")
const Thumbnails=preload("res://studio/thumbnail_cache.gd")
const Store=preload("res://studio/native_preview_store.gd")
const Packet=preload("res://studio/native_preview_resource.gd")
const Baker=preload("res://tools/bake_studio_spell_previews.gd")
const REPORT="res://.runtime/studio-native-preview-resource-checks.json"
var checks:int=0
var failures:Array=[]
var measurements:Array=[]
var tracks:Control
var finished:bool=false

func _initialize()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(1280,800)
    run.call_deferred()

func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("NATIVE_PREVIEW_RESOURCE_FAIL ",label)

func no_native_work(label:String)->void:
    var cache:RefCounted=tracks.thumbnails
    check(cache.pending.is_empty() and cache.native_composites.is_empty() and cache.active.is_empty(),label+": baked demand starts no native simulation job")
    check(cache.errors.is_empty() and cache.native_store.issues.is_empty(),label+": disk resources have no loading/format errors")
    check(cache.texture_bytes<=cache.texture_limit and cache.native_store.retained_bytes<=Store.MEMORY_LIMIT,label+": resident preview caches remain within their budgets")

func measure(label:String,require_disk:bool=true)->Dictionary:
    var before_hits:int=tracks.thumbnails.native_store.hits
    var before_misses:int=tracks.thumbnails.native_store.misses
    var before_loads:int=tracks.thumbnails.native_store.disk_loads
    var before_descriptor:int=tracks.thumbnails.native_store.descriptor_usec
    var before_resource:int=tracks.thumbnails.native_store.resource_load_usec
    var begin:int=Time.get_ticks_usec()
    var state:Dictionary=tracks.prepare_visible(true)
    var cpu_ms:float=float(Time.get_ticks_usec()-begin)/1000.0
    check(state.ready and state.pending==0 and state.errors.is_empty(),label+": all visible four-view samples load immediately from Resources")
    no_native_work(label)
    await process_frame;await RenderingServer.frame_post_draw
    var available_ms:float=float(Time.get_ticks_usec()-begin)/1000.0
    var record={"label":label,"request_cpu_ms":cpu_ms,"through_post_draw_ms":available_ms,"samples":state.samples,
        "disk_hits":tracks.thumbnails.native_store.hits-before_hits,"disk_misses":tracks.thumbnails.native_store.misses-before_misses,
        "disk_loads":tracks.thumbnails.native_store.disk_loads-before_loads,
        "descriptor_ms":float(tracks.thumbnails.native_store.descriptor_usec-before_descriptor)/1000.0,
        "resource_load_ms":float(tracks.thumbnails.native_store.resource_load_usec-before_resource)/1000.0,
        "available":state.ready,"target_ms":200.0,"within_target":state.ready and available_ms<=200.0,"errors":state.errors}
    measurements.append(record)
    print("NATIVE_PREVIEW_RESOURCE_TIME ",JSON.stringify(record))
    check(state.samples>0,label+": the measured timeline actually requested thumbnails")
    if require_disk:
        check(tracks.thumbnails.native_store.hits>before_hits and tracks.thumbnails.native_store.disk_loads>before_loads,label+": actual persisted source data served the demand")
    check(tracks.thumbnails.native_store.misses==before_misses,label+": no missing/stale baked source was silently simulated")
    return record

func phase_samples(rows:Array)->Dictionary:
    var samples:Dictionary={}
    for row in rows:
        for fraction in [.1,.5,.9]:
            var at:float=lerpf(row.start_ms,row.end_ms,fraction)
            for quarter in 4:
                var key:String=tracks.thumbnails.request(row,at,quarter,false)
                check(not key.is_empty() and tracks.thumbnails.textures.has(key),str(row.component.native_cue.role)+": source phase sample loads at "+str(fraction)+" q"+str(quarter))
                if tracks.thumbnails.textures.has(key):samples[key]=tracks.thumbnails.textures[key]
        for quarter in 4:
            var key:String=tracks.thumbnails.request(row,row.end_ms-.001,quarter,false)
            check(tracks.thumbnails.textures.has(key),str(row.component.native_cue.role)+": final retained-tail source bin is baked q"+str(quarter))
    no_native_work("phase/late-tail coverage")
    return samples

func identity_and_authoring(row:Dictionary)->void:
    var cache:RefCounted=tracks.thumbnails
    var at:float=lerpf(row.start_ms,row.end_ms,.5)
    var original:String=cache.request(row,at,0,false)
    var copy:Dictionary=row.duplicate(true)
    copy.id+="/unrelated-occurrence"
    copy.component.id+="/unrelated-occurrence"
    copy.component.actor_uuid="unrelated-actor"
    copy.component.target_uuid="unrelated-recipient"
    copy.component.source_event_uuid="unrelated-event"
    var before:int=cache.native_store.hits
    var repeated:String=cache.request(copy,at,0,false)
    check(cache.textures.has(original) and cache.textures.has(repeated),"An unrelated recorded occurrence identity reuses the same source artwork")
    check(cache.native_store.hits==before+1,"Event/actor identity changes still hit persisted source data")
    if cache.textures.has(original) and cache.textures.has(repeated):
        check(cache.textures[original].get_image().get_data()==cache.textures[repeated].get_image().get_data(),"Identity-only reuse preserves exact native thumbnail pixels")
    var bookkeeping:Dictionary=row.duplicate(true);bookkeeping.id+="/bookkeeping-only"
    var names:Dictionary={}
    for field in bookkeeping.component.native_cue:names[StringName(str(field))]=bookkeeping.component.native_cue[field]
    names[&"clip"]="different-intake-order";names[&"source_index"]=98765;names[&"role"]=StringName(str(names[&"role"]))
    bookkeeping.component.native_cue=names
    before=cache.native_store.hits
    var equivalent:String=cache.request(bookkeeping,at,0,false)
    check(cache.textures.has(equivalent) and cache.native_store.hits==before+1,"Bookkeeping-only phase order and StringName keys reuse the persisted visual source")
    if cache.textures.has(original) and cache.textures.has(equivalent):
        check(cache.textures[original].get_image().get_data()==cache.textures[equivalent].get_image().get_data(),"Canonical key representation changes preserve exact source pixels")
    no_native_work("occurrence reuse")
    var edited:Dictionary=row.duplicate(true);edited.id+="/changed-scale"
    edited.component.native_cue.scale*=.731
    var invalidated:String=cache.request(edited,at,0,false)
    check(not cache.textures.has(invalidated),"Changed visual cue cannot serve stale persisted artwork")
    check(cache.pending.any(func(job):return job.key==invalidated),"Changed visual cue enters the existing explicit render fallback")
    # Do not render this intentionally unbaked variant or disturb its source.
    cache.reset()

func dependency_revision(row:Dictionary,texture:Texture2D)->void:
    var root_path:String="res://.runtime/native-preview-resource-probe-"+str(OS.get_process_id())
    DirAccess.make_dir_recursive_absolute(root_path)
    var component:Dictionary=row.component.duplicate(true)
    component.native_clip=Effects.occurrence_clip(component).duplicate(true)
    var selected:Dictionary=Effects.choice(component.native_clip)
    var actual:Dictionary=selected.approaches[0] if not selected.approaches.is_empty() else {}
    var source:String=str(actual.get("source_phase",""))
    check(source.ends_with(".tres") and FileAccess.file_exists(source),"Dependency qualification uses this selected phase's actual current native Resource")
    if not source.ends_with(".tres") or not FileAccess.file_exists(source):
        DirAccess.remove_absolute(root_path);return
    var fixture:String=root_path.path_join("source.tres")
    var original:String=FileAccess.get_file_as_string(source)
    FileAccess.open(fixture,FileAccess.WRITE).store_string(original)
    actual.source_phase=fixture
    var store=Store.new()
    var hz:float=maxf(1,float(row.get("source_fps",component.get("sample_hz",32))))
    var descriptor:Dictionary=store.descriptor(component,hz)
    check(descriptor.dependencies.has(fixture),"Actual selected source phase participates in source invalidation")
    var packet=Packet.new()
    packet.signature=descriptor.signature;packet.specification=descriptor.specification;packet.dependencies=descriptor.dependencies
    packet.quarter=0;packet.hz=hz;packet.ticks.append(0);packet.textures.append(texture)
    var bytes:int=texture.get_image().get_data_size();packet.sizes.append(bytes);packet.texture_bytes=bytes
    var path:String=Store.resource_path(descriptor.signature,0,0)
    check(not FileAccess.file_exists(path),"Dependency probe has its own new derived Resource")
    if FileAccess.file_exists(path):
        DirAccess.remove_absolute(fixture);DirAccess.remove_absolute(root_path);return
    check(ResourceSaver.save(packet,path,ResourceSaver.FLAG_COMPRESS)==OK,"Owned dependency probe saves through Godot ResourceSaver")
    check(store.lookup(descriptor,0,0)!=null,"Unchanged selected source can load its saved Resource")
    FileAccess.open(fixture,FileAccess.WRITE).store_string(original+"\n; source revision for owned invalidation qualification\n")
    store.reset()
    var revised:Dictionary=store.descriptor(component,hz)
    check(revised.signature!=descriptor.signature,"An actual source file revision invalidates the prior visual signature")
    check(store.lookup(revised,0,0)==null,"A revised source cannot load the previous saved image")
    store.reset();packet=null
    DirAccess.remove_absolute(path);DirAccess.remove_absolute(fixture);DirAccess.remove_absolute(root_path)

func incremental_pages(textures:Array)->void:
    if textures.size()<2:check(false,"Incremental page qualification has two actual native images");return
    var previous=Packet.new();var current=Packet.new()
    for packet in [previous,current]:packet.signature="owned-page-union";packet.quarter=2;packet.hz=60
    previous.ticks=PackedInt32Array([0,1]);previous.textures.assign([textures[0],textures[0]])
    current.ticks=PackedInt32Array([1,2]);current.textures.assign([textures[1],textures[1]])
    for packet in [previous,current]:
        for texture in packet.textures:packet.sizes.append(texture.get_image().get_data_size())
    check(Baker.merge_page(previous,current),"A later same-source partial bake can merge the existing native Resource page")
    check(current.ticks==PackedInt32Array([0,1,2]) and current.textures.size()==3,"Partial-page extension preserves earlier qualified source ticks")
    check(is_same(current.textures[0],textures[0]) and is_same(current.textures[1],textures[1]) and is_same(current.textures[2],textures[1]),"Only newly baked overlapping ticks replace prior source images")
    check(current.texture_bytes==current.sizes[0]+current.sizes[1]+current.sizes[2],"Merged resource accounts for all retained texture bytes")
    var another=Packet.new();another.signature=current.signature;another.quarter=current.quarter;another.hz=current.hz
    another.ticks=PackedInt32Array([64]);another.textures.assign([textures[1]]);another.sizes.append(textures[1].get_image().get_data_size())
    check(not Baker.merge_page(current,another) and another.ticks==PackedInt32Array([64]),"A different bounded source page cannot consume or rewrite this page")

func run()->void:
    check(DisplayServer.get_name()!="headless","Disk availability qualification uses a native renderer and completed draw")
    if DisplayServer.get_name()=="headless":finish();return
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    var original:Dictionary=Fixtures.case_record("fireball")
    check(original.get("id")=="spell.fireball/area","The exact current independent Fireball original is available")
    if original.is_empty():finish();return
    var begin:int=Time.get_ticks_usec()
    var index:Dictionary=Recording.read(Fixtures.journal("fireball"))
    var indexing_ms:float=float(Time.get_ticks_usec()-begin)/1000.0
    check(index.ok,"Original Fireball journal compiles with the ordinary Studio Recording")
    if not index.ok:finish();return
    var rows:Array=index.rows.filter(func(row):return row.kind=="native_effect" and row.get("component",{}).get("native_spell",false) and row.component.spell_id=="spell.fireball")
    check(rows.size()==3,"Real recording retains cast, flight and area source rows")
    if rows.size()!=3:finish();return
    var immutable:PackedByteArray=var_to_bytes(rows)
    tracks=TimelineView.new();root.add_child(tracks);tracks.set_process(false)
    tracks.size=Vector2(1280,800);tracks.filter="native_effect"
    tracks.set_index(index);tracks.rebuild_rows();tracks.fit()
    check(tracks.thumbnails.textures.is_empty(),"Fresh process begins without resident thumbnail images")
    var fresh:Dictionary=await measure("fresh-process Fireball four-view fit")
    fresh.recording_index_ms=indexing_ms
    var snapshots:Dictionary=phase_samples(rows)
    var coloured:int=0
    for texture in snapshots.values():
        var image:Image=texture.get_image()
        for y in image.get_height():
            for x in image.get_width():
                var pixel:Color=image.get_pixel(x,y)
                if maxf(pixel.r,maxf(pixel.g,pixel.b))>1.0/255.0:coloured+=1
    check(coloured>0,"Persisted real native samples contain source pixels, not placeholder swatches")
    tracks.pixels_per_second*=1.75;tracks.origin_ms=index.presentation_end_ms*.45
    await measure("changed zoom and late source bins",false)
    tracks.set_index(index);tracks.filter="native_effect";tracks.rebuild_rows();tracks.fit()
    await measure("reset/reload disk reuse")
    incremental_pages(snapshots.values())
    identity_and_authoring(rows[0])
    if not snapshots.is_empty():dependency_revision(rows[0],snapshots.values()[0])
    check(var_to_bytes(rows)==immutable,"Requests and invalidation checks preserve real recording rows and authored cues")
    tracks.queue_free();await process_frame;await RenderingServer.frame_post_draw
    finish()

func finish()->void:
    if finished:return
    finished=true
    var report={"checks":checks,"failed":failures.size(),"failures":failures,"measurements":measurements,
        "scope":"Fresh-process real Fireball Recording/Timeline all-view Resource thumbnail availability, retained tails, changed zoom bins, reload, occurrence-identity reuse and visual/source invalidation. This does not measure full Library navigation or grant artistic approval."}
    FileAccess.open(REPORT,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_PREVIEW_RESOURCE ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
