extends SceneTree
## Original authored cells versus actual selected Catalog rectangles. CPU only.
const Catalog=preload("res://source_catalog.gd")
const EnvironmentMedia=preload("res://presentation/environment_media.gd")
const CASES={"prop.content-slender-monument.break":"environment.furniture.slender_monument","prop.interior-wooden-chair.break":"environment.furniture.wooden_chair","prop.interior-bookshelf.break":"environment.furniture.bookshelf","prop.interior-stone-bench.break":"environment.furniture.stone_bench"}
var checks:int=0
var failures:Array=[]
var images:Dictionary={}
var cache:Dictionary={}
var inspected:int=0
var catalog_samples:int=0
var headers:Dictionary={}
var independent_supports:Dictionary={}
var candidate_banks:Dictionary={}
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("ENVIRONMENT_LAYOUT_FAIL ",label)
func image(path:String)->Image:
    # Keep original numeric sources but at most two small page images.
    if not images.has(path) and path.contains("/pages/"):
        var pages:Array=images.keys().filter(func(key):return str(key).contains("/pages/"))
        if pages.size()>=2:images.erase(pages[0])
    if not images.has(path):images[path]=Image.load_from_file(Catalog.media_path(path))
    return images[path]
func bytes(region:Dictionary)->PackedByteArray:
    var rect:Array=region.rect
    return image(region.path).get_region(Rect2i(rect[0],rect[1],rect[2],rect[3])).get_data()
func check_bank(bank_id:String,asset:String,layouts:Dictionary)->void:
    var bank:Dictionary=Catalog.bank_data(bank_id,cache)
    var before:Dictionary=bank.duplicate(true)
    var prop={"id":"layout-prop","kind":"prop","asset":asset,"state":"default","position":[0,0],"base_height_steps":0,"layer":1,"orientation":"east"}
    check(Catalog.bank_for(prop,true,cache)==bank_id,"Actual authored prop chooses requested destruction bank: "+bank_id)
    var seen_views={};var all_pages={};var expected_final={}
    for quarter in 4:
        for frame in int(bank.frame_count):
            var age:float=frame/float(bank.fps)
            var original:Dictionary=Catalog.receiving_normal(Catalog._environment_source(prop,quarter,cache,1,age),cache)
            var actual:Dictionary=Catalog.environment(prop,quarter,cache,1,age)
            var restored:Dictionary=actual.duplicate(true)
            restored.geometry_region=original.geometry_region
            restored.normal.region=original.normal.region
            var label="%s/q%d/frame%d"%[bank_id,quarter,frame]
            check(restored==original,label+": colour, transform, pivot, source-clock and sampling fields unchanged")
            check(actual.frame==frame,label+": authored frame selection unchanged")
            check(bytes(original.geometry_region)==bytes(actual.geometry_region),label+": exact selected depth bytes")
            check(bytes(original.normal.region)==bytes(actual.normal.region),label+": exact selected receiving-normal bytes")
            if frame>0:seen_views[int(original.geometry_region.rect[1])/int(original.geometry_region.rect[3])]=true
            var required={};EnvironmentMedia.record_paths(actual,required,cache)
            check(required.has(actual.geometry_region.path) and required.has(actual.normal.region.path),label+": complete adapted numeric readiness closure")
            check(layouts.keys().all(func(path):return not required.has(path)),label+": no oversized original remains in demand")
            for region in [actual.geometry_region,actual.normal.region]:
                if str(region.path).contains("/pages/"):
                    all_pages[region.path]=true
                    if frame==int(bank.frame_count)-1:expected_final[region.path]=true
            catalog_samples+=1
    check(seen_views.size()==4,"All four authored source views exercised: "+bank_id)
    check(bank==before,"Selection preserves original bank/source coordinates: "+bank_id)
    var animation:Dictionary=EnvironmentMedia.animation_pages(prop,cache)
    check(animation.errors.is_empty() and animation.paths==all_pages,"Finite destruction closure contains every actually used page: "+bank_id)
    var destroyed:Dictionary=prop.duplicate(true);destroyed.destroyed=true
    var final_paths:Dictionary=EnvironmentMedia.row_paths(destroyed,cache)
    var final_pages={}
    for path in final_paths:
        if all_pages.has(path):final_pages[path]=true
    check(final_pages==expected_final,"Settled after-value retains exactly its final-frame pages: "+bank_id)
    check(layouts.keys().all(func(path):return not final_paths.has(path)),"Settled demand excludes oversized originals: "+bank_id)
    for quarter in 4:
        var last:Dictionary=Catalog.environment(destroyed,quarter,cache)
        check(last.frame==int(bank.frame_count)-1 and final_paths.has(last.geometry_region.path) and final_paths.has(last.normal.region.path),"Settled complete selected-page readiness q%d: %s"%[quarter,bank_id])
    images.clear()
# Independent eligibility oracle reads typed authoring and delivered PNG headers,
# not the generated layout table or the builder's eligibility implementation.
func source_header(path:String)->Dictionary:
    if not headers.has(path):
        var file:FileAccess=FileAccess.open(path,FileAccess.READ)
        if file==null:check(false,"Original numeric source exists: "+path);return {}
        file.big_endian=true;file.seek(16)
        headers[path]={"width":file.get_32(),"height":file.get_32(),"bits":file.get_8(),"type":file.get_8()}
    return headers[path]
func independent_candidates()->Dictionary:
    var source:Resource=load("res://authoring/environment.tres")
    var selection:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/"+source.shared.receiving_normals.normals.quality)).normals
    var candidates:Dictionary={}
    for bank_id in source.sections.art:
        var art:Resource=load(source.sections.art[bank_id])
        if art.kind!="bank":continue
        var bank:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/"+art.art.measurements))
        var paths:Dictionary={}
        for frames in bank.surface_frames_by_pose.values():
            for frame in frames:
                for region in [frame.get("geometry_region",{}),frame.get("normal",{}).get("region",{})]:
                    if region.is_empty():continue
                    paths[region.path]=region.rect
                    if selection.has(region.path):paths[selection[region.path].path]=region.rect
                var support:Dictionary=frame.get("support",{}).get("region",{})
                if not support.is_empty():independent_supports["res://assets/"+support.path]=true
        for path in paths:
            var full:String="res://assets/"+path
            var header:Dictionary=source_header(full)
            if header.is_empty():continue
            if header.width*header.height*4<=16*1024*1024 or header.bits!=8 or header.type!=6:continue
            var cell:Array=[paths[path][2],paths[path][3]]
            check(not candidates.has(full) or candidates[full]==cell,"Actual source has one shared cell registration: "+full)
            candidates[full]=cell;candidate_banks[bank_id]=true
    return candidates
func check_doors(layouts:Dictionary)->void:
    var raw_cache:Dictionary={Catalog.ENVIRONMENT+"texture_layouts.res":{"layouts":{}}}
    for asset in ["environment.directional_door","environment.door.indoor_door_elegant","environment.door.indoor_door_shabby_battens"]:
        var row:Dictionary={"id":"original-door-layout","kind":"door","asset":asset,"state":"closed","position":[0,0],"base_height_steps":0,"layer":1,"orientation":"east"}
        for state in ["closed","open.inward","open.outward"]:
            row.state=state
            for quarter in 4:
                var raw:Dictionary=Catalog.door_frame(row,quarter,raw_cache)
                var selected:Dictionary=Catalog.door_frame(row,quarter,cache)
                check(not raw.is_empty() and not selected.is_empty(),"Actual frame source admitted: %s/%s/q%d"%[asset,state,quarter])
                if raw.is_empty() or selected.is_empty():continue
                check(bytes(raw.geometry_region)==bytes(selected.geometry_region),"Door frame retains original depth bytes: %s/%s/q%d"%[asset,state,quarter])
                check(bytes(raw.normal.region)==bytes(selected.normal.region),"Door frame retains its original-normal policy: %s/%s/q%d"%[asset,state,quarter])
                var restored:Dictionary=selected.duplicate(true)
                restored.geometry_region=raw.geometry_region;restored.normal.region=raw.normal.region
                check(restored==raw,"Frame paint, pivot, orientation, sampling and original normal metadata unchanged: %s/%s/q%d"%[asset,state,quarter])
                var demand:Dictionary={};EnvironmentMedia.record_paths(selected,demand,cache)
                check(layouts.keys().all(func(path):return not demand.has(path)),"Actual door frame physical closure excludes every paged oversized source")
        images.clear()
func run()->void:
    var document:Dictionary=ResourceLoader.load("res://build/presentation/environment/texture_layouts.res").value
    check(document.version==2,"Version-two bounded pages published")
    if document.version!=2:quit(1);return
    var layouts:Dictionary=document.layouts
    var expected:Dictionary=independent_candidates()
    check(expected.size()==171,"Independent current delivered inventory has171 oversized RGBA8 geometry/normal sources")
    check(layouts.size()==expected.size() and expected.keys().all(func(path):return layouts.has(path)),"Generated layouts exactly cover eligible physical sources, not grayscale supports or unrelated color banks")
    for path in expected:check(layouts.has(path) and layouts[path].cell==expected[path],"Generated cell agrees with actual measured source registration: "+path)
    for path in independent_supports:
        if not expected.has(path):check(not layouts.has(path),"Independent grayscale support remains untouched: "+path)
    for bank_id in CASES.keys().slice(0,3):
        var source_path:String="res://assets/art/media/environment/props/"+bank_id.trim_prefix("prop.").trim_suffix(".break")+"/break/geometry/geometry-native.png"
        check(layouts.has(source_path),"Original three depth sources retain their admitted layouts: "+bank_id)
        if layouts.has(source_path):
            check(str(layouts[source_path].pages[0]).get_base_dir()==Catalog.ENVIRONMENT+"pages/"+bank_id.trim_prefix("prop.").replace(".","-")+"/original-depth","Original three depth layout addresses remain unchanged: "+bank_id)
            var normal_source:String=Catalog.environment_file(Catalog.ENVIRONMENT+"receiving_normals.res",cache).normals[source_path].path
            check(layouts.has(normal_source) and str(layouts[normal_source].pages[0]).get_base_dir()==Catalog.ENVIRONMENT+"pages/"+bank_id.trim_prefix("prop.").replace(".","-")+"/selected-normal","Original three selected-normal layout addresses remain unchanged: "+bank_id)
    # The former optional .runtime capture used retired /media and .derived
    # addresses. Current source contracts below are independent of local history.
    var total_pages=0
    for path in layouts:
        var layout:Dictionary=layouts[path]
        var cell=Vector2i(layout.cell[0],layout.cell[1])
        var source_size=Vector2i(layout.source_size[0],layout.source_size[1])
        var columns:int=source_size.x/cell.x;var rows:int=source_size.y/cell.y
        var count=columns*rows
        check(image(path).get_size()==source_size,"Actual original packet layout: "+path)
        check(layout.pages.size()==ceili(float(count)/layout.cells_per_page) and int(layout.verified_cells)==count,"Every source cell admitted including partial final page: "+path)
        for page in layout.pages:
            check(image(page).get_size()==Vector2i(layout.size[0],layout.size[1]),"Fixed unchanged cell/page bounds: "+page)
            check(image(page).get_data().size()<=4718592,"One numeric publication is at most4.5MiB: "+page)
            check(image(path).get_format()==image(page).get_format(),"Numeric encoding unchanged: "+page)
            total_pages+=1
        for row in rows:
            for frame in columns:
                var original={"path":path,"rect":[frame*cell.x,row*cell.y,cell.x,cell.y]}
                check(bytes(original)==bytes(Catalog._layout_region(original,layouts)),"Exact original RGBA cell: "+path+"/%d/%d"%[row,frame])
                for offset in [Vector2i.ZERO,cell-Vector2i.ONE]:
                    var corner={"path":path,"rect":[frame*cell.x+offset.x,row*cell.y+offset.y,1,1]}
                    check(bytes(corner)==bytes(Catalog._layout_region(corner,layouts)),"Exact cell/page-boundary corner: "+str(corner))
                inspected+=1
        check(Catalog._layout_region({"path":path,"rect":[cell.x-1,0,2,1]},layouts).is_empty(),"Cross-cell region rejected")
        check(Catalog._layout_region({"path":path,"rect":[source_size.x,0,1,1]},layouts).is_empty(),"Out-of-source region cannot address padded cells")
        images.clear()
    for bank_id in CASES:check_bank(bank_id,CASES[bank_id],layouts)
    check_doors(layouts)
    var source="res://assets/art/media/environment/props/content-slender-monument/break/geometry/geometry-native.png"
    var legacy={"path":"res://old-monolith.png","source_size":[37632,1536],"size":[5376,10752],"cell":[384,384],"source_columns":98,"columns":14}
    var original={"path":source,"rect":[97*384,3*384,384,384]}
    var legacy_selected=Catalog._layout_region(original,{source:legacy})
    check(legacy_selected=={"path":"res://old-monolith.png","rect":[13*384,27*384,384,384]},"Legacy monolithic final-cell addressing unchanged")
    var old_cache={"res://build/presentation/environment/texture_layouts.res":{"version":1,"layouts":{source:legacy}}}
    var fresh_cache={"res://build/presentation/environment/texture_layouts.res":document}
    var selected_record={"geometry_region":original}
    check(Catalog.texture_layout(selected_record,old_cache).geometry_region==legacy_selected,"Existing cache retains admitted monolith")
    check(Catalog.texture_layout(selected_record,fresh_cache).geometry_region.path!=legacy_selected.path,"Fresh cache selects new pages")
    check(selected_record.geometry_region==original and old_cache["res://build/presentation/environment/texture_layouts.res"].version==1,"Source/prior cache immutable")
    images.clear()
    var result={"checks":checks,"failures":failures,"source_cells_compared":inspected,"catalog_samples":catalog_samples,"page_count":total_pages,"eligible_sources":expected.size(),"eligible_banks":candidate_banks.size(),"max_page_bytes":4718592,"scope":"Exact saved numeric cells/corners, actual four-view/all-frame Catalog selection, finite animation and settled closures, partial final-page and legacy-cache addressing. No GPU/upload-time claim."}
    FileAccess.open("res://.runtime/environment-texture-layout-checks.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("ENVIRONMENT_TEXTURE_LAYOUT_CHECKS ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
