extends SceneTree
## Exact palette operands consumed by rendering, against the original full-sheet scan.
const Palette=preload("res://presentation/palette.gd")
const Catalog=preload("res://source_catalog.gd")
const Sources=preload("res://presentation/body_sources.gd")
var checks=0
var failures:Array=[]
var timings:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr("PALETTE_PREPARE_FAIL ",label)
func percentile(values:PackedFloat32Array,fraction:float)->float:
    if values.is_empty():return 0.0
    var at=(values.size()-1)*fraction
    return lerpf(values[floori(at)],values[ceili(at)],at-floorf(at))
func original(layer:Dictionary,rig:Dictionary,clip:String,cache:Dictionary)->Dictionary:
    var result=layer.duplicate(true)
    var treatment:Dictionary=layer.get("palette",{}) if layer.get("palette")!=null else {}
    if treatment.is_empty():return result
    var resources=Catalog.read_file("catalog/resources.json",cache)
    var sheet:String=layer.get("sourceSheet",rig.clips[clip].sheets.get(layer.category,""))
    if not resources.has(sheet):return result
    var path:String=resources[sheet]
    var key="__palette_ranges:"+path+":"+str(rig.cell_height)
    if not cache.has(key):
        var image=Image.load_from_file(Catalog.media_path(path))
        var ranges={}
        if image!=null and not image.is_empty():
            image.convert(Image.FORMAT_RGBA8)
            var bytes=image.get_data()
            for facing in rig.facing_rows:
                var samples=PackedFloat32Array()
                var y0=int(rig.facing_rows[facing])*int(rig.cell_height)
                for y in range(y0,y0+int(rig.cell_height)):
                    for x in image.get_width():
                        var i=(y*image.get_width()+x)*4
                        if bytes[i+3]>128:samples.append(bytes[i]*.2126+bytes[i+1]*.7152+bytes[i+2]*.0722)
                samples.sort()
                ranges[facing]=Vector2(percentile(samples,.03),percentile(samples,.98))/255.0
        cache[key]=ranges
    result.palette_ranges=cache[key]
    return result
func compare(path:String,rig:Dictionary,clip:String,layer:Dictionary,passes:int)->void:
    var resources={"sheet":path}
    var baseline:Array=[];var candidate:Array=[]
    var before=layer.duplicate(true)
    for pass_index in passes:
        var expected:Dictionary;var actual:Dictionary
        var cache=source_cache(path,Sources.index({}).palette_ranges)
        # Alternate order; both measure the same cold per-document cache boundary.
        for candidate_first in [pass_index%2==0,pass_index%2!=0]:
            var started=Time.get_ticks_usec()
            if candidate_first:
                actual=Palette.prepare(layer,rig,clip,cache)
                candidate.append((Time.get_ticks_usec()-started)/1000.0)
            else:
                expected=original(layer,rig,clip,{"catalog/resources.json":resources})
                baseline.append((Time.get_ticks_usec()-started)/1000.0)
        check(actual==expected,"Complete exact palette operands: "+path+" pass"+str(pass_index))
        for facing in rig.facing_rows:
            check(actual.palette_ranges[facing]==expected.palette_ranges[facing],"Exact facing percentile: "+path+" "+facing)
        check(Palette.prepare(layer,rig,clip,cache)==expected,"Existing cached lookup remains exact")
    check(layer==before,"Source layer remains unchanged: "+path)
    baseline.sort();candidate.sort()
    timings.append({"path":path,"baseline_ms":baseline,"candidate_ms":candidate,
        "baseline_median_ms":baseline[baseline.size()/2],"candidate_median_ms":candidate[candidate.size()/2]})
func source_cache(path:String,measured:Dictionary={})->Dictionary:
    var index=Sources.Index.new()
    index.sheets={"sheet":{"default":path}}
    index.palette_ranges=measured
    return {Sources.KEY:{"index":index,"loaded":{}}}

func measured_resource_checks()->void:
    # The build owns measured metadata. Native admission borrows that immutable
    # Resource; a replacement build supplies a new index, never a runtime hash
    # or .derived JSON cache of the original sheet.
    var media_root=ProjectSettings.get_setting("source_data/media_root")
    var fixture_root="res://.runtime/palette-source-checks"
    DirAccess.make_dir_recursive_absolute(fixture_root)
    ProjectSettings.set_setting("source_data/media_root",ProjectSettings.globalize_path(fixture_root))
    var path="/media/cache-fixture.png"
    var stats=fixture_root+"/palette-index.tres"
    var rig={"cell_height":2,"facing_rows":{"front":0},"clips":{"fixture":{"sheets":{"fixture":"sheet"}}}}
    var layer={"category":"fixture","palette":{"colors":[0xffffff]}}
    var resources={"catalog/resources.json":{"sheet":path}}
    var source=Image.create(2,2,false,Image.FORMAT_RGBA8)
    source.fill(Color8(25,75,125,255))
    check(source.save_png(fixture_root+"/cache-fixture.png")==OK,"Owned persistent source saves")
    var expected=original(layer,rig,"fixture",resources.duplicate(true))
    check(Palette.prepare(layer,rig,"fixture",source_cache(path))==expected,"Unmeasured admitted sheet retains the exact independent full-scan result")
    var admitted:Dictionary=source_cache(path,{path:{"2":expected.palette_ranges}})
    var index=admitted[Sources.KEY].index
    check(ResourceSaver.save(index,stats)==OK,"Build-shaped measured metadata saves as a native Resource")
    var restored=ResourceLoader.load(stats,"",ResourceLoader.CACHE_MODE_IGNORE)
    var restored_cache={Sources.KEY:{"index":restored,"loaded":{}}}
    check(Palette.prepare(layer,rig,"fixture",restored_cache)==expected,"Fresh admission reads exact native measured operands")
    check(is_same(restored_cache[Sources.KEY].index,restored),"Palette lookup keeps its actual admitted metadata owner")
    source=Image.create(7,2,false,Image.FORMAT_RGBA8)
    for y in 2:
        for x in 7:source.set_pixel(x,y,Color8(x*30,y*70,240,255))
    check(source.save_png(fixture_root+"/cache-fixture.png")==OK,"Owned source replacement saves")
    var changed=original(layer,rig,"fixture",resources.duplicate(true))
    check(changed!=expected,"Replacement source has observably different palette operands")
    check(Palette.prepare(layer,rig,"fixture",source_cache(path))==changed,"New unmeasured admission scans the replacement source exactly")
    check(Palette.prepare(layer,rig,"fixture",admitted)==expected,"Existing measured admission is immutable across a later source replacement")
    var replacement=source_cache(path,{path:{"2":changed.palette_ranges}})
    check(Palette.prepare(layer,rig,"fixture",replacement)==changed,"Replacement build metadata supplies the new exact source operands")
    check(Palette.prepare(layer,rig,"fixture",restored_cache)==expected,"A new build never mutates a previously admitted Resource")
    ProjectSettings.set_setting("source_data/media_root",media_root)
    DirAccess.remove_absolute(stats)
    DirAccess.remove_absolute(fixture_root+"/cache-fixture.png")
func run()->void:
    var cache={}
    var rig:Dictionary=Catalog.read_file("catalog/rigs.json",cache)["neuroclient.modular"]
    for pair in [["Magic2","Attack5"],["Slash1","Attack6"],["Slash1","Attack1"]]:
        var layer={"id":"actual-source","category":pair[0],"sourceSheet":"sheet","palette":{"colors":[0xffffff,0x808080]}}
        compare("/media/smallscale/modular/"+pair[0]+"/"+pair[1]+".png",rig,pair[1],layer,3)
    # First row empty; next row contains only rejected alpha; final rows include
    # every edge and the exact128/129 threshold with transparent coloured padding.
    var image=Image.create(19,28,false,Image.FORMAT_RGBA8)
    image.fill(Color(1,.25,.75,0))
    for y in range(7,28):
        for x in 19:
            var alpha=[0,1,128][(x+y)%3] if y<14 else [0,1,128,129,255][(x+y)%5]
            image.set_pixel(x,y,Color8((x*37)%256,(y*53)%256,((x+y)*17)%256,alpha))
    var path="res://.runtime/palette-prepare-thresholds.png"
    check(image.save_png(path)==OK,"Owned threshold image saves")
    var fixture={"cell_height":7.0,"facing_rows":{"empty":0,"below":1,"mixed":2,"edge":3},"clips":{"fixture":{"sheets":{"fixture":"sheet"}}}}
    compare(path,fixture,"fixture",{"category":"fixture","palette":{"colors":[0xffffff]}},1)
    check(Palette.prepare({"category":"fixture"},fixture,"fixture",{})=={"category":"fixture"},"No treatment requires no image or catalog")
    measured_resource_checks()
    var report={"checks":checks,"failures":failures,"timings":timings,"scope":"Exact rendered palette operands against an independent full-sheet scan, real Gallery sheets, alpha/empty-row boundaries, native measured Resource ownership and replacement builds. Retired .derived JSON/freshness policy is not a runtime requirement."}
    FileAccess.open("res://.runtime/palette-prepare-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("PALETTE_PREPARE_CHECKS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
