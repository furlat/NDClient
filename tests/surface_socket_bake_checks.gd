extends SceneTree
# Every baked finite source sample against original Godot Image byte channels.
const Samples=preload("res://presentation/surface_socket_samples.gd")
const Geometry=preload("res://presentation/character_geometry.gd")
var checks:int=0
var failures:Array=[]
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("SOCKET_BAKE_FAIL ",label)
func _initialize()->void:run.call_deferred()
func run()->void:
    var report:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Samples.ROOT+"bake-report.json"))
    var selected:Array=report.baked_sources
    var subset:Dictionary={}
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--source-list="):
            subset=JSON.parse_string(FileAccess.get_file_as_string(argument.trim_prefix("--source-list=")))
            selected=subset.sources
    var began:int=Time.get_ticks_msec()
    var cache:Dictionary={}
    var sources:int=0
    var pixels:int=0
    var seed:Dictionary={}
    for identity in selected:
        check(identity in report.baked_sources,"Independent byte witness is a published source")
        var file=Samples.file_for(identity,{"media":identity})
        var baked:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(file))
        var path:String=baked.source
        var table:String=Geometry.TABLE if path.begins_with("/media/smallscale/modular/") else Geometry.CREATURE_TABLE
        if not cache.has(table):cache[table]=JSON.parse_string(FileAccess.get_file_as_string(table))
        var record:Dictionary=cache[table].records[path]
        var root_path:String=Geometry._root(record)
        check(Samples.prepare(path,record,root_path,cache),"Current real source prepares: "+path)
        var images={}
        for channel in baked.optical:
            var image=Image.new();var status=image.load(baked.optical[channel].path)
            check(status==OK,"Original optical image loads: "+baked.optical[channel].path)
            images[channel]=image
        check(images.depth.get_width()==int(baked.size[0]) and images.depth.get_height()==int(baked.size[1]),"Sidecar layout equals original source")
        for key in baked.samples:
            var parts=key.split(",");var point=Vector2i(int(parts[0]),int(parts[1]))
            var depth:Color=images.depth.get_pixelv(point)
            var expected:Array=[roundi(depth.r*255),roundi(depth.a*255),roundi(images.support.get_pixelv(point).r*255),roundi(images.solid.get_pixelv(point).r*255)]
            var actual:Array=[]
            for byte in Samples.sample(path,record,point,cache):actual.append(int(byte))
            check(actual==expected,"Exact original byte tuple "+path+"/"+key)
            pixels+=1
        check(Samples.sample(path,record,Vector2i(-1,-1),cache).is_empty(),"Out-of-source point retains fallback")
        var absent=Vector2i.ZERO
        while baked.samples.has("%d,%d"%[absent.x,absent.y]):absent.x+=1
        check(Samples.sample(path,record,absent,cache).is_empty(),"Unbaked arbitrary probe retains fallback")
        sources+=1
        if seed.is_empty():seed={"path":path,"record":record,"root":root_path,"baked":baked}
    check(sources==int(report.sources) and pixels==int(report.samples) if subset.is_empty() else sources==selected.size(),"Requested source/sample coverage qualified")
    var missing:Dictionary=seed.record.duplicate(true);missing.media="/media/__socket-bake-test__/missing.png"
    check(not Samples.prepare(missing.media,missing,seed.root,{}),"Missing real sidecar is rejected without forced cache flags")
    var stale:Dictionary=seed.baked.duplicate(true)
    stale.source="/media/__socket-bake-test__/stale.png";stale.optical.depth.mtime-=1
    var target=Samples.file_for(stale.source,{"media":stale.source})
    DirAccess.make_dir_recursive_absolute(target.get_base_dir())
    FileAccess.open(target,FileAccess.WRITE).store_string(JSON.stringify(stale))
    var metadata:Dictionary=seed.record.duplicate(true);metadata.media=stale.source
    check(not Samples.prepare(stale.source,metadata,seed.root,{}),"Actual mismatched optical timestamp rejects stale scalar sidecar")
    check(Samples.sample(stale.source,metadata,Vector2i.ZERO,{}).is_empty(),"Stale source supplies no invented sample")
    DirAccess.remove_absolute(target)
    DirAccess.remove_absolute(target.get_base_dir())
    var result={"checks":checks,"failures":failures,"sources":sources,"samples":pixels,"elapsed_seconds":(Time.get_ticks_msec()-began)/1000.0,"selection":subset,"scope":"All finite byte tuples in requested sources versus original Godot Image pixels; metadata preparation, missing/stale sidecar and unsampled point fallback; no GPU/gameplay claim"}
    var artifact="res://.runtime/surface-socket-bake-checks.json" if subset.is_empty() else "res://.runtime/surface-socket-full-library-byte-checks.json"
    FileAccess.open(artifact,FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("SURFACE_SOCKET_BAKE_CHECKS ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
