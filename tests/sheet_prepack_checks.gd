extends SceneTree
# L8 prepack oracle. For every bundle written by tools/prepack_sheets.gd and
# every channel (colour and companions), reconstruct each cell's readable
# region from the bundle exactly as the runtime will address it and compare
# it with the original PNG byte for byte:
# - readable region = the cell plus the one-texel ring that a fragment at UV
#   1.0, the shadow taps or picking's truncation can reach, with the original
#   repeat_disable clamp at the sheet edge (built here independently, by
#   padding the whole sheet);
# - inside the box every channel is byte-identical;
# - outside the box the original colour alpha is 0, so every consumer
#   (modular, shadow caster, scene support, sockets, picking, outline,
#   palette ranges) discards or skips exactly as it does on the sheet.
# Then it measures disk bytes, GPU bytes (RenderingServer texture memory) and
# load+upload time per bundle against today's PNG decode + ImageTexture upload.
# Run with a GPU driver for real uploads:
#   $G --path . --rendering-method forward_plus --rendering-driver vulkan --script res://tests/sheet_prepack_checks.gd [-- --dir=res://.derived/sheet_bundles_v1 --timing=74]
const SheetBundle=preload("res://presentation/resources/sheet_bundle.gd")
const RUNTIME_CHANNELS=["colour","depth","normal","support","normal_valid","solid"]
var checks:int=0;var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,message:String)->void:
    checks+=1
    if not ok and failures.size()<200:failures.append(message)

static func padded(image:Image)->Image:
    var size:=image.get_size();var result:=Image.create_empty(size.x+2,size.y+2,false,image.get_format())
    result.blit_rect(image,Rect2i(Vector2i.ZERO,size),Vector2i.ONE)
    result.blit_rect(image,Rect2i(0,0,1,size.y),Vector2i(0,1));result.blit_rect(image,Rect2i(size.x-1,0,1,size.y),Vector2i(size.x+1,1))
    result.blit_rect(image,Rect2i(0,0,size.x,1),Vector2i(1,0));result.blit_rect(image,Rect2i(0,size.y-1,size.x,1),Vector2i(1,size.y+1))
    result.set_pixel(0,0,image.get_pixel(0,0));result.set_pixel(size.x+1,0,image.get_pixel(size.x-1,0))
    result.set_pixel(0,size.y+1,image.get_pixel(0,size.y-1));result.set_pixel(size.x+1,size.y+1,image.get_pixel(size.x-1,size.y-1))
    return result

func verify(path:String)->Dictionary:
    var bundle:Resource=ResourceLoader.load(path,"",ResourceLoader.CACHE_MODE_IGNORE)
    var row:Dictionary={"bundle":path,"texels":0,"outside_texels":0,"cells":0}
    if bundle==null:check(false,"Cannot load "+path);return row
    var cell:Vector2i=bundle.cell;var grid:Vector2i=bundle.sheet_size/cell;var colour_pad:Image
    check(bundle.cells.size()==grid.x*grid.y*SheetBundle.STRIDE,path+": one table row per cell")
    for channel in bundle.sources:
        var original:=Image.new()
        if original.load(bundle.sources[channel])!=OK:check(false,path+": cannot decode "+bundle.sources[channel]);continue
        check(original.get_size()==bundle.sheet_size,path+" "+channel+": sheet size")
        var pad:Image=padded(original);if channel=="colour":colour_pad=pad
        var pages:Array=bundle.pages[channel]
        check(pages.size()==bundle.page_count,path+" "+channel+": page count")
        for page in pages:check(page.get_size()==Vector2i(bundle.page_size,bundle.page_size) and page.get_format()==original.get_format(),path+" "+channel+": page size and decoded format")
        for i in grid.x*grid.y:
            var c:PackedInt32Array=bundle.cells.slice(i*SheetBundle.STRIDE,(i+1)*SheetBundle.STRIDE)
            var origin:=Vector2i(i%grid.x,i/grid.x)*cell
            var readable:Image=pad.get_region(Rect2i(origin,cell+Vector2i(2,2)))
            var box:=Rect2i(c[3]+1,c[4]+1,c[5],c[6])
            if c[0]<0:check(c[5]==0 and c[6]==0,path+": empty cell has no box");continue
            check(Rect2i(Vector2i.ZERO,cell+Vector2i(2,2)).encloses(box),path+": box inside readable region")
            var rebuilt:=Image.create_empty(cell.x+2,cell.y+2,false,original.get_format())
            rebuilt.blit_rect(pages[c[0]],Rect2i(c[1],c[2],c[5],c[6]),box.position)
            var same:bool=rebuilt.get_region(box).get_data()==readable.get_region(box).get_data()
            check(same,"%s %s cell %d: packed texels differ inside the box"%[path,channel,i])
            row.texels+=box.get_area()
    if colour_pad==null:return row
    # Outside every box the original colour alpha is 0 over the whole readable region.
    for i in grid.x*grid.y:
        var c:PackedInt32Array=bundle.cells.slice(i*SheetBundle.STRIDE,(i+1)*SheetBundle.STRIDE)
        var readable:Image=colour_pad.get_region(Rect2i(Vector2i(i%grid.x,i/grid.x)*cell,cell+Vector2i(2,2)))
        if c[0]>=0:readable.fill_rect(Rect2i(c[3]+1,c[4]+1,c[5],c[6]),Color(0,0,0,0))
        check(not readable.get_used_rect().has_area(),"%s cell %d: visible texel outside the box"%[path,i])
        row.outside_texels+=(cell.x+2)*(cell.y+2)-(c[5]*c[6] if c[0]>=0 else 0);row.cells+=1
    # The shared mapping function itself, at random readable texels.
    var random:=RandomNumberGenerator.new();random.seed=hash(path)
    for n in 2000:
        var index:int=random.randi_range(0,grid.x*grid.y-1);var t:=Vector2i(random.randi_range(-1,cell.x),random.randi_range(-1,cell.y))
        var expected:Color=colour_pad.get_pixelv(Vector2i(index%grid.x,index/grid.x)*cell+t+Vector2i.ONE)
        var actual:Color=SheetBundle.packed_texel(bundle,"colour",index,t)
        check(actual==expected or (expected.a==0.0 and actual==Color(0,0,0,0)),"%s cell %d texel %s: packed_texel differs"%[path,index,t])
    return row

static func texture_bytes()->int:
    return RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)

func measure(stats:Dictionary)->Dictionary:
    # Today: PNG decode + ImageTexture per runtime channel. Packed: bundle load
    # (all channels, all normal profiles) + one Texture2DArray per runtime channel.
    var bundle:Resource=ResourceLoader.load(stats.bundle,"",ResourceLoader.CACHE_MODE_IGNORE)
    var channels:Array=RUNTIME_CHANNELS.filter(func(channel):return bundle.sources.has(channel))
    var row:Dictionary={"source":stats.source,"pages":bundle.page_count,"channels":channels.size()}
    var held:Array=[];var before:int=texture_bytes();var started:int=Time.get_ticks_usec();var decode:int=0;var png_bytes:int=0
    for channel in channels:
        var at:int=Time.get_ticks_usec();var image:=Image.new();image.load(bundle.sources[channel]);decode+=Time.get_ticks_usec()-at
        png_bytes+=FileAccess.get_size(bundle.sources[channel])
        held.append(ImageTexture.create_from_image(image))
    row.png_decode_ms=decode/1000.0;row.png_total_ms=(Time.get_ticks_usec()-started)/1000.0;row.png_upload_ms=row.png_total_ms-row.png_decode_ms
    await RenderingServer.frame_post_draw;row.png_gpu_bytes=texture_bytes()-before;row.png_disk_bytes=png_bytes
    held.clear();await RenderingServer.frame_post_draw;before=texture_bytes()
    started=Time.get_ticks_usec();var loaded:Resource=ResourceLoader.load(stats.bundle,"",ResourceLoader.CACHE_MODE_IGNORE)
    var load_us:int=Time.get_ticks_usec()-started
    for channel in channels:
        var array:=Texture2DArray.new();array.create_from_images(loaded.pages[channel]);held.append(array)
    row.bundle_load_ms=load_us/1000.0;row.bundle_total_ms=(Time.get_ticks_usec()-started)/1000.0;row.bundle_upload_ms=row.bundle_total_ms-row.bundle_load_ms
    await RenderingServer.frame_post_draw;row.bundle_gpu_bytes=texture_bytes()-before;row.bundle_disk_bytes=FileAccess.get_size(stats.bundle)
    var page_bytes:int=0
    for channel in channels:page_bytes+=loaded.pages[channel][0].get_data_size()*loaded.page_count if loaded.page_count>0 else 0
    row.bundle_page_bytes=page_bytes
    held.clear();await RenderingServer.frame_post_draw
    return row

func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(64,64)
    var directory:String="res://.derived/sheet_bundles_v1";var timing:int=1000000;var limit:int=1000000
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--dir="):directory=argument.trim_prefix("--dir=")
        elif argument.begins_with("--timing="):timing=int(argument.trim_prefix("--timing="))
        elif argument.begins_with("--limit="):limit=int(argument.trim_prefix("--limit="))
    var manifest:Variant=JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("manifest.json")))
    if manifest==null:printerr("No prepack manifest in "+directory);quit(2);return
    var rows:Array=[];var started:int=Time.get_ticks_msec()
    for stats in manifest.bundles.slice(0,limit):rows.append(verify(stats.bundle))
    var verify_ms:int=Time.get_ticks_msec()-started
    var timings:Array=[]
    if DisplayServer.get_name()!="headless":
        for stats in manifest.bundles.slice(0,mini(2,timing)):await measure(stats)
        for stats in manifest.bundles.slice(0,mini(limit,timing)):timings.append(await measure(stats))
    var totals:Dictionary={}
    for row in timings:
        for field in row:
            if typeof(row[field]) in [TYPE_INT,TYPE_FLOAT]:totals[field]=totals.get(field,0)+row[field]
    var texels:int=0;for row in rows:texels+=row.texels
    var report:Dictionary={"checks":checks,"failures":failures,"bundles":rows.size(),"compared_box_texels":texels,"verify_ms":verify_ms,
        "renderer":RenderingServer.get_video_adapter_name(),"timing_totals":totals,"timings":timings,"manifest_errors":manifest.errors}
    var file:=FileAccess.open("res://generated/sheet_prepack_checks.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
    print("SHEET_PREPACK_CHECKS ",JSON.stringify({"checks":checks,"failures":failures.slice(0,10),"bundles":rows.size(),"timed":timings.size(),"totals":totals}))
    quit(0 if failures.is_empty() else 1)
