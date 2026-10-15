extends SceneTree
## Original authored cells versus the actual selected Catalog rectangles.
## Headless: no image is uploaded and no rendered-pixel claim is made.
const Catalog=preload("res://source_catalog.gd")
const EnvironmentMedia=preload("res://presentation/environment_media.gd")
const BANK="prop.content-slender-monument.break"
var checks:int=0
var failures:Array=[]
var images:Dictionary={}
var cache:Dictionary={}
var inspected:int=0

func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("ENVIRONMENT_LAYOUT_FAIL ",label)

func image(path:String)->Image:
    # Keep the two original numeric sources but at most two small page images.
    # The exhaustive comparison does not need an entire paged bank resident.
    if not images.has(path) and path.contains("/pages/"):
        var pages:Array=images.keys().filter(func(key):return str(key).contains("/pages/"))
        if pages.size()>=2: images.erase(pages[0])
    if not images.has(path):images[path]=Image.load_from_file(Catalog.media_path(path))
    return images[path]

func bytes(region:Dictionary)->PackedByteArray:
    var rect:Array=region.rect
    return image(region.path).get_region(Rect2i(rect[0],rect[1],rect[2],rect[3])).get_data()

func run()->void:
    var layouts:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://generated/environment_texture_layouts.json"))
    check(layouts.version==2,"The bounded-page bake has been published before this qualification")
    if layouts.version!=2: quit(1);return
    check(layouts.layouts.size()==2,"Only the two selected oversized numeric sheets are adapted")
    for path in layouts.layouts:
        var layout:Dictionary=layouts.layouts[path]
        check(image(path).get_size()==Vector2i(37632,1536),"Actual original packet has the witnessed oversized dimensions: "+path)
        check(layout.pages.size()==49 and layout.cells_per_page==8,"All392 original cells occupy49 whole-cell pages: "+path)
        for page in layout.pages:
            check(image(page).get_size()==Vector2i(1536,768),"Saved page bounds one publication without resizing cells: "+page)
            check(image(page).get_data().size()==4718592,"One actual RGBA8 page is4.5MiB: "+page)
            check(image(path).get_format()==image(page).get_format(),"Numeric source encoding stays unchanged: "+page)
        # Independently walk each original source cell. Comparing the saved
        # selected region validates the adapter as well as the offline writer.
        for row in 4:
            for frame in 98:
                var original={"path":path,"rect":[frame*384,row*384,384,384]}
                var selected:Dictionary=Catalog._layout_region(original,layouts.layouts)
                check(bytes(original)==bytes(selected),"Exact original RGBA cell survives selection: "+path+"/%d/%d" % [row,frame])
                for offset in [Vector2i.ZERO,Vector2i(383,383)]:
                    var corner={"path":path,"rect":[frame*384+offset.x,row*384+offset.y,1,1]}
                    check(bytes(corner)==bytes(Catalog._layout_region(corner,layouts.layouts)),"Exact corner texel survives cell/page boundary: "+str(corner))
                inspected+=1
        check(Catalog._layout_region({"path":path,"rect":[383,0,2,1]},layouts.layouts).is_empty(),"Cross-cell region is rejected, never mapped to another page")
        check(Catalog._layout_region({"path":path,"rect":[37632,0,1,1]},layouts.layouts).is_empty(),"Out-of-source region is rejected")
        images.clear()
    var bank:Dictionary=Catalog.bank_data(BANK,cache)
    var before:Dictionary=bank.duplicate(true)
    var prop={"id":"layout-monument","kind":"prop","asset":"environment.furniture.slender_monument",
        "state":"default","position":[0,0],"base_height_steps":0,"layer":1,"orientation":"east"}
    var seen_views={}
    for quarter in 4:
        for frame in 98:
            var age:float=frame/float(bank.fps)
            var original:Dictionary=Catalog.receiving_normal(Catalog._environment_source(prop,quarter,cache,1,age),cache)
            var actual:Dictionary=Catalog.environment(prop,quarter,cache,1,age)
            var restored:Dictionary=actual.duplicate(true)
            restored.geometry_region=original.geometry_region
            restored.normal.region=original.normal.region
            var label="q%d/frame%d" % [quarter,frame]
            check(restored==original,label+": every other colour, transform, pivot, source-clock and sampling field is unchanged")
            check(actual.frame==frame,label+": original authored frame selection is unchanged")
            check(bytes(original.geometry_region)==bytes(actual.geometry_region),label+": selected Catalog depth cell equals original")
            check(bytes(original.normal.region)==bytes(actual.normal.region),label+": selected Catalog receiving normal cell equals original")
            if frame>0:seen_views[int(original.geometry_region.rect[1])/384]=true
            var required={}
            EnvironmentMedia.record_paths(actual,required,cache)
            check(required.has(actual.geometry_region.path) and required.has(actual.normal.region.path),label+": normal warmup closure owns the complete adapted packets")
            check(layouts.layouts.keys().all(func(path):return not required.has(path)),label+": no oversized original packet remains in the selected demand")
    check(seen_views.size()==4,"All four authored source views were exercised")
    check(bank==before,"Selection does not mutate the original bank or its source coordinates")
    var animation:Dictionary=EnvironmentMedia.animation_pages(prop,cache)
    check(animation.errors.is_empty(),"Actual finite destruction page closure is valid")
    var all_pages={}
    for layout in layouts.layouts.values():
        for path in layout.pages: all_pages[path]=true
    check(animation.paths==all_pages and animation.paths.size()==98,"Active four-view animation admits every used page in both numeric channels")
    var destroyed:Dictionary=prop.duplicate(true);destroyed.destroyed=true
    var final_paths:Dictionary=EnvironmentMedia.row_paths(destroyed,cache)
    var final_pages=final_paths.keys().filter(func(path):return all_pages.has(path))
    check(final_pages.size()==8,"Settled after-value needs only four final-frame pages per channel, not98pages or either monolith")
    check(layouts.layouts.keys().all(func(path):return not final_paths.has(path)),"Settled demand never retains the original oversized numeric sheets")
    check(final_paths.keys().all(func(path):return not str(path).ends_with("/original-depth/geometry-native.png") and not str(path).ends_with("/selected-normal/geometry-native.png")),"Settled demand does not retain obsolete monolithic derived images")
    for quarter in 4:
        var last:Dictionary=Catalog.environment(destroyed,quarter,cache)
        var required:Dictionary=EnvironmentMedia.row_paths(destroyed,cache)
        check(last.frame==97 and required.has(last.geometry_region.path) and required.has(last.normal.region.path),
            "Settled authoritative destruction retains its complete selected-page readiness closure q"+str(quarter))
    # Version-one caches keep their exact old addressing while a fresh catalog
    # can select version-two pages. No mutation of a displayed catalog document.
    var source:String=layouts.layouts.keys()[0]
    var legacy={"path":"res://old-monolith.png","source_size":[37632,1536],"size":[5376,10752],
        "cell":[384,384],"source_columns":98,"columns":14}
    var original={"path":source,"rect":[97*384,3*384,384,384]}
    var legacy_selected=Catalog._layout_region(original,{source:legacy})
    check(legacy_selected=={"path":"res://old-monolith.png","rect":[13*384,27*384,384,384]},"Legacy monolithic manifest keeps exact final-cell coordinates")
    var old_cache={"res://generated/environment_texture_layouts.json":{"version":1,"layouts":{source:legacy}}}
    var fresh_cache={"res://generated/environment_texture_layouts.json":layouts}
    var selected_record={"geometry_region":original}
    check(Catalog.texture_layout(selected_record,old_cache).geometry_region==legacy_selected,"Existing catalog snapshot remains on its admitted monolith")
    check(Catalog.texture_layout(selected_record,fresh_cache).geometry_region.path!=legacy_selected.path,"Fresh catalog snapshot selects new page paths")
    check(selected_record.geometry_region==original and old_cache["res://generated/environment_texture_layouts.json"].version==1,"Source and prior cache documents are immutable under adaptation")
    images.clear()
    var result={"checks":checks,"failures":failures,"source_cells_compared":inspected,
        "catalog_samples":392,"page_count":98,"page_bytes":4718592,
        "scope":"Exact saved numeric cells and corner texels, actual four-view/all-frame Catalog selection, finite animation closure, settled page demand and legacy-cache compatibility. No GPU drawing or upload-time claim."}
    FileAccess.open("res://.runtime/environment-texture-layout-checks.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("ENVIRONMENT_TEXTURE_LAYOUT_CHECKS ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
