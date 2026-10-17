extends SceneTree
## Offline L8 prepack: crop every cell of a modular layer-clip to the texels
## the shaders can read and pack the crops into fixed square pages, one
## SheetBundle (.res) per layer-clip holding the colour sheet and every
## companion (depth, normal profiles, support, normal_valid, solid) in the
## same layout. Images keep their decoded PNG format; nothing is converted.
## Runtime behaviour is unchanged: nothing loads these bundles yet.
##   --trace=<json>   pack every /media/smallscale/modular/*.png the file names
##   --list=<file>    pack the media paths listed one per line
##   --sheets=a,b     pack these media paths
##   --out=<dir>      default res://.derived/sheet_bundles_v1
##   --page=<n>       page size, default 128 (every measured cell box fits; the
##                    shelf fill is ~69%, within 3% of the best size measured)
##   --compress       save with ResourceSaver.FLAG_COMPRESS (smaller on disk,
##                    decompressed on load)
const SheetBundle=preload("res://presentation/resources/sheet_bundle.gd")
const Catalog=preload("res://source_catalog.gd")
const GEOMETRY="res://generated/character_geometry.json"
const PROFILES="res://generated/normal_profiles.json"
const OUT="res://.derived/sheet_bundles_v1"
const PAGE_CANDIDATES=[96,112,128,160,256]
func _initialize()->void:run.call_deferred()

static func sheet_paths(text:String)->PackedStringArray:
    var found:Dictionary={};var expression:=RegEx.create_from_string("/media/smallscale/modular/[^\"\\s]+?\\.png")
    for match in expression.search_all(text):found[match.get_string()]=true
    var result:=PackedStringArray(found.keys());result.sort()
    return result

## Channel name -> absolute file for one modular colour sheet, from the same
## geometry and normal-profile tables the body-source importer joins.
static func channel_files(path:String,geometry:Dictionary,profiles:Dictionary)->Dictionary:
    var result:Dictionary={"colour":Catalog.media_path(path)}
    var record:Dictionary=geometry.records.get(path,{})
    var root:String=ProjectSettings.get_setting("source_data/character_geometry_root")
    # Excluded (non-solid accent) layers have no geometry: colour only.
    if record.has("files"):
        for field in ["depth","normal","support","normal_valid"]:result[field]=root.path_join(record.files[field])
        result.solid=root.path_join(record.reference).get_base_dir().path_join("solid-valid.png")
    var normals:Dictionary=profiles.records.get(path,{})
    var normal_root:String=ProjectSettings.get_setting("source_data/normal_profiles_root")
    for profile in normals:
        if profile!="original":result["normal_"+profile]=normal_root.path_join(normals[profile])
    return result

## The (cell + 2)² texels a cell's samplers can address: the cell and the
## one-texel ring a fragment at UV 1.0 (or picking's truncation) reaches,
## with the original repeat_disable clamp at the sheet edge.
static func extended(image:Image,origin:Vector2i,cell:Vector2i)->Image:
    var result:=Image.create_empty(cell.x+2,cell.y+2,false,image.get_format())
    var area:=Rect2i(origin-Vector2i.ONE,cell+Vector2i(2,2)).intersection(Rect2i(Vector2i.ZERO,image.get_size()))
    result.blit_rect(image,area,area.position-origin+Vector2i.ONE)
    if origin.x==0:result.blit_rect(result.duplicate(),Rect2i(1,0,1,cell.y+2),Vector2i(0,0))
    if origin.x+cell.x==image.get_width():result.blit_rect(result.duplicate(),Rect2i(cell.x,0,1,cell.y+2),Vector2i(cell.x+1,0))
    if origin.y==0:result.blit_rect(result.duplicate(),Rect2i(0,1,cell.x+2,1),Vector2i(0,0))
    if origin.y+cell.y==image.get_height():result.blit_rect(result.duplicate(),Rect2i(0,cell.y,cell.x+2,1),Vector2i(0,cell.y+1))
    return result

## Shelf packing, tallest first. Returns per rect [page, x, y] and the page count.
static func pack(sizes:Array,page:int)->Dictionary:
    var order:Array=range(sizes.size()).filter(func(i):return sizes[i].x>0 and sizes[i].y>0)
    order.sort_custom(func(a,b):return sizes[a].y>sizes[b].y or (sizes[a].y==sizes[b].y and (sizes[a].x>sizes[b].x or (sizes[a].x==sizes[b].x and a<b))))
    var places:Array=[];places.resize(sizes.size());places.fill([-1,0,0])
    var pages:int=0;var x:int=page;var y:int=0;var shelf:int=0
    for i in order:
        var size:Vector2i=sizes[i]
        if size.x>page or size.y>page:return {"ok":false}
        if x+size.x>page:x=0;y+=shelf;shelf=0
        if pages==0 or y+size.y>page:pages+=1;x=0;y=0;shelf=0
        places[i]=[pages-1,x,y];x+=size.x;shelf=maxi(shelf,size.y)
    return {"ok":true,"places":places,"pages":pages}

static func bundle(path:String,files:Dictionary,cell:Vector2i,page:int)->Dictionary:
    var images:Dictionary={}
    for channel in files:
        var image:=Image.new()
        if not FileAccess.file_exists(files[channel]) or image.load(files[channel])!=OK or image.is_empty():
            if channel=="colour":return {"error":"Cannot decode "+files[channel]}
            continue
        images[channel]=image
    var colour:Image=images.colour;var size:=colour.get_size()
    if size.x%cell.x!=0 or size.y%cell.y!=0:return {"error":"Sheet is not a cell grid: "+path}
    for channel in images:
        if images[channel].get_size()!=size:return {"error":"Companion size differs: "+files[channel]}
    var grid:=size/cell;var boxes:Array=[];var sizes:Array=[];var ring_cells:int=0;var box_texels:int=0
    for row in grid.y:
        for frame in grid.x:
            var origin:=Vector2i(frame,row)*cell
            var used:Rect2i=extended(colour,origin,cell).get_used_rect()
            var inner:Rect2i=colour.get_region(Rect2i(origin,cell)).get_used_rect()
            if used.has_area() and Rect2i(inner.position+Vector2i.ONE,inner.size)!=used:ring_cells+=1
            boxes.append(Rect2i(used.position-Vector2i.ONE,used.size) if used.has_area() else Rect2i());sizes.append(used.size if used.has_area() else Vector2i.ZERO)
            box_texels+=used.get_area() if used.has_area() else 0
    var packed:Dictionary=pack(sizes,page)
    if not packed.ok:return {"error":"Cell box exceeds page: "+path}
    var result:=SheetBundle.new();result.source=path;result.sheet_size=size;result.cell=cell;result.page_size=page;result.page_count=packed.pages
    for i in boxes.size():
        var place:Array=packed.places[i];var box:Rect2i=boxes[i]
        result.cells.append_array([place[0],place[1],place[2],box.position.x,box.position.y,box.size.x,box.size.y])
    for channel in images:
        var source:Image=images[channel];var layers:Array[Image]=[]
        for p in packed.pages:layers.append(Image.create_empty(page,page,false,source.get_format()))
        for i in boxes.size():
            var place:Array=packed.places[i]
            if place[0]<0:continue
            var origin:=Vector2i(i%grid.x,i/grid.x)*cell
            layers[place[0]].blit_rect(extended(source,origin,cell),Rect2i(boxes[i].position+Vector2i.ONE,boxes[i].size),Vector2i(place[1],place[2]))
        result.pages[channel]=layers;result.sources[channel]=files[channel]
    var alternatives:Dictionary={}
    for candidate in PAGE_CANDIDATES:
        var simulated:Dictionary=pack(sizes,candidate)
        alternatives[str(candidate)]=simulated.pages if simulated.ok else -1
    var formats:Dictionary={};var source_bytes:int=0;var bytes:Dictionary={}
    for channel in images:
        formats[channel]=images[channel].get_format()
        bytes[channel]=images[channel].get_data_size();source_bytes+=FileAccess.get_size(files[channel])
    return {"bundle":result,"stats":{"source":path,"pages":packed.pages,"cells":boxes.size(),"ring_cells":ring_cells,
        "box_texels":box_texels,"fill":float(box_texels)/float(packed.pages*page*page) if packed.pages>0 else 0.0,
        "page_alternatives":alternatives,"formats":formats,"sheet_bytes":bytes,"png_bytes":source_bytes,"channels":images.keys()}}

func run()->void:
    var out:String=OUT;var page:int=128;var flags:int=0;var paths:=PackedStringArray()
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--trace="):paths.append_array(sheet_paths(FileAccess.get_file_as_string(argument.trim_prefix("--trace="))))
        elif argument.begins_with("--list="):paths.append_array(FileAccess.get_file_as_string(argument.trim_prefix("--list=")).split("\n",false))
        elif argument.begins_with("--sheets="):paths.append_array(argument.trim_prefix("--sheets=").split(",",false))
        elif argument.begins_with("--out="):out=argument.trim_prefix("--out=")
        elif argument.begins_with("--page="):page=int(argument.trim_prefix("--page="))
        elif argument=="--compress":flags=ResourceSaver.FLAG_COMPRESS
    var unique:Dictionary={};for path in paths:unique[path]=true
    paths=PackedStringArray(unique.keys());paths.sort()
    var geometry:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(GEOMETRY))
    var profiles:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(PROFILES))
    DirAccess.make_dir_recursive_absolute(out)
    var manifest:Dictionary={"format":"sheet-bundles-v1","page_size":page,"bundles":[],"errors":[]}
    var started:int=Time.get_ticks_msec()
    for path in paths:
        var made:Dictionary=bundle(path,channel_files(path,geometry,profiles),Vector2i(128,128),page)
        if made.has("error"):manifest.errors.append(made.error);printerr(made.error);continue
        var target:String=out.path_join(path.trim_prefix("/media/smallscale/modular/").get_basename().replace("/","--")+".res")
        var error:int=ResourceSaver.save(made.bundle,target,flags)
        if error!=OK:manifest.errors.append("Cannot save "+target);continue
        made.stats.bundle=target;made.stats.bundle_bytes=FileAccess.get_size(target)
        manifest.bundles.append(made.stats)
        print("%s pages=%d fill=%.2f ring_cells=%d bytes=%d" % [path,made.stats.pages,made.stats.fill,made.stats.ring_cells,made.stats.bundle_bytes])
    manifest.elapsed_ms=Time.get_ticks_msec()-started
    var file:=FileAccess.open(out.path_join("manifest.json"),FileAccess.WRITE);file.store_string(JSON.stringify(manifest,"  "));file.close()
    print("bundles=%d errors=%d elapsed_ms=%d" % [manifest.bundles.size(),manifest.errors.size(),manifest.elapsed_ms])
    quit(1 if not manifest.errors.is_empty() else 0)
