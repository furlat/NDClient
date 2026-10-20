extends SceneTree
## Offline paging boundary: exact original cells, eligibility and output reuse.
## These small authored controls require no source-index build or GPU.
const Build=preload("res://tools/presentation_build/environment.gd")
const Catalog=preload("res://source_catalog.gd")
const Media=preload("res://presentation/environment_media.gd")
var checks:int=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("ENVIRONMENT_PAGE_BUILD_FAIL ",label)
func run()->void:
    var folder:String="res://.runtime/environment-page-build-checks"
    DirAccess.make_dir_recursive_absolute(folder)
    var source:String=folder.path_join("source.png")
    var original:Image=Image.create(9,6,false,Image.FORMAT_RGBA8)
    for y in 6:
        for x in 9:original.set_pixel(x,y,Color8(x*19,y*31,(x+y)*13,(x*23+y*7)%256))
    check(original.save_png(source)==OK,"Independent RGBA8 control source saves")
    var original_file:PackedByteArray=FileAccess.get_file_as_bytes(source)
    var report:Dictionary={"errors":[],"warnings":[],"coverage":{}}
    var layout:Dictionary=Build._paginate(source,Vector2i(3,2),folder.path_join("pages"),report,"small partial page",Vector2i(6,4))
    check(report.errors.is_empty(),"Small unchanged-cell build has no errors")
    check(layout.get("verified_cells")==9 and layout.get("pages",[]).size()==3,"Nine original cells produce three four-cell pages")
    if layout.is_empty():quit(1);return
    for index in 9:
        var page:Image=Image.load_from_file(layout.pages[index/4])
        var expected:PackedByteArray=original.get_region(Rect2i((index%3)*3,(index/3)*2,3,2)).get_data()
        var actual:PackedByteArray=page.get_region(Rect2i((index%4%2)*3,(index%4/2)*2,3,2)).get_data()
        check(actual==expected,"Independent row-major source cell %d is byteexact including alpha"%index)
        var region:Dictionary={"path":source,"rect":[(index%3)*3,(index/3)*2,3,2]}
        var selected:Dictionary=Catalog._layout_region(region,{source:layout})
        check(selected.path==layout.pages[index/4] and Image.load_from_file(selected.path).get_region(Rect2i(selected.rect[0],selected.rect[1],3,2)).get_data()==expected,"Catalog selects independently expected saved cell %d"%index)
    var last:Image=Image.load_from_file(layout.pages[-1])
    check(last.get_pixel(5,3)==Color.TRANSPARENT,"Partial final page padding is transparent")
    for y in 4:
        for x in 6:
            if x>=3 or y>=2:check(last.get_pixel(x,y)==Color.TRANSPARENT,"Unoccupied last-page texel remains zero")
    check(FileAccess.get_file_as_bytes(source)==original_file,"Packing never rewrites original source art")
    check(not Build._page_eligible({"size":Vector2i(2048,2048),"bits":8,"colour_type":6}),"Exactly16MiB does not acquire pages")
    check(Build._page_eligible({"size":Vector2i(2048,2049),"bits":8,"colour_type":6}),"LargerRGBA8 source acquires pages")
    check(not Build._page_eligible({"size":Vector2i(26112,1536),"bits":8,"colour_type":0}),"Independent grayscale support stays in its original file")
    check(not Build._page_eligible({"size":Vector2i(26112,1536),"bits":16,"colour_type":6}),"Different numeric encoding is not implicitly converted")
    check(Build._packet_header(source)=={"size":Vector2i(9,6),"bits":8,"colour_type":6},"Eligibility reads actual PNG dimensions and format")
    check(Build._whole_regions(Vector2i(9,6),Vector2i(3,2),[[0,0,3,2],[6,4,3,2]]),"Aligned full source cells pass offline registration guard")
    for value in [[Vector2i(3,2),[[1,0,3,2]]],[Vector2i(3,2),[[9,0,3,2]]],[Vector2i(3,2),[[0,0,2,2]]],[Vector2i.ZERO,[[0,0,3,2]]],[Vector2i(2000,2),[[0,0,2000,2]]]]:
        check(not Build._whole_regions(Vector2i(9,6),value[0],value[1]),"Invalid/cross-cell/out-of-source/oversize registration is rejected offline: "+str(value))
    var stamp:Dictionary=Build._page_stamp(source,Vector2i(3,2))
    var admitted:Dictionary={"stamp":stamp,"layout":layout,"outputs":Build._page_outputs(layout)}
    check(Build._page_cache_matches(admitted,Build._page_stamp(source,Vector2i(3,2)),folder.path_join("pages")),"Unchanged source/cell/output metadata reuses admitted offline pages")
    check(not Build._page_cache_matches(admitted,Build._page_stamp(source,Vector2i(1,2)),folder.path_join("pages")),"Changed cell registration requires fresh packing")
    check(not Build._page_cache_matches(admitted,stamp,folder.path_join("different")),"Changed output owner cannot reuse another page location")
    var changed:Dictionary=stamp.duplicate(true);changed.version+=1
    check(not Build._page_cache_matches(admitted,changed,folder.path_join("pages")),"Builder layout generation change requires fresh packing")
    var file:FileAccess=FileAccess.open(source,FileAccess.READ_WRITE);file.seek_end();file.store_8(0);file.close()
    check(not Build._page_cache_matches(admitted,Build._page_stamp(source,Vector2i(3,2)),folder.path_join("pages")),"Changed actual source file invalidates the offline output reuse stamp")
    file=FileAccess.open(source,FileAccess.WRITE);file.store_buffer(original_file);file.close()
    DirAccess.remove_absolute(layout.pages[-1])
    check(not Build._page_cache_matches(admitted,stamp,folder.path_join("pages")),"Missing derived page requires repacking rather than a broken manifest")
    # A single physical numeric source can have several descriptor roles. These
    # are controlled metadata operands, not fabricated server/world facts.
    var region:Dictionary={"path":source,"rect":[6,4,3,2]}
    var separate:Dictionary={"path":folder.path_join("independent-r8.png"),"rect":[6,4,3,2]}
    var record:Dictionary={"path":"unchanged-colour.png","rect":[0,0,9,6],"pivot":[4,5],"scale":1.25,"frame":8,
        "geometry_region":region,"normal":{"region":region,"original_path":source,"sampling":{"scale":[1,1]}},
        "support":{"region":region,"encoding":"unchanged"},"hit_mask":region,"door_partition":region.merged({"range":[-4,7],"scale":2,"offset":5}),
        "roles":[{"role":"solid","selection":{"kind":"mask","mask":{"region":region,"encoding":"unchanged"},"values":[255]}},
            {"role":"independent","selection":{"kind":"mask","mask":{"region":separate}}}]}
    var before:Dictionary=record.duplicate(true)
    var selected:Dictionary=Catalog.texture_layout(record,{Catalog.ENVIRONMENT+"texture_layouts.res":{"layouts":{source:layout}}})
    var expected_region:Dictionary={"path":layout.pages[2],"rect":[0,0,3,2]}
    for actual in [selected.geometry_region,selected.normal.region,selected.support.region,selected.hit_mask,selected.roles[0].selection.mask.region]:check(actual==expected_region,"Every matching physical descriptor alias selects the same independently addressed page")
    check(selected.door_partition==expected_region.merged({"range":[-4,7],"scale":2,"offset":5}),"Door partition retains its exact range and registration")
    check(selected.roles[1]==record.roles[1] and selected.normal.original_path==source,"Independent mask and normal provenance are not rewritten")
    check(record==before,"Source descriptor and nested source roles remain immutable")
    check(selected.path==record.path and selected.pivot==record.pivot and selected.scale==record.scale and selected.frame==8,"Color, source frame and placement are unchanged")
    var demand:Dictionary={};Media.record_paths(selected,demand,{})
    check(demand.has(expected_region.path) and not demand.has(source) and demand.has(separate.path),"Physical closure uses selected aliases without whole numeric source and retains independent masks")
    record.support.region=separate
    selected=Catalog.texture_layout(record,{Catalog.ENVIRONMENT+"texture_layouts.res":{"layouts":{source:layout}}})
    check(selected.support.region==separate,"Independent support path and rectangle remain unchanged")
    var result:Dictionary={"checks":checks,"failures":failures,"scope":"Offline eligibility, lossless partial pages, source immutability, unchanged-source reuse and every current numeric descriptor alias; no GPU or frame-budget claim."}
    FileAccess.open(folder.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("ENVIRONMENT_PAGE_BUILD_CHECKS ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
