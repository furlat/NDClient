extends "res://tests/native_light_output_checks.gd"
## Actual original numeric sheets versus bounded pages through the production
## spatial materials, camera registration, door partitions and 2D light table.
## The raw oracle disables only address remapping; selected normal policy is shared.
const Descriptors=preload("res://presentation/environment_source.gd")
const MaterialOwner=preload("res://presentation/source_material.gd")
const Demand=preload("res://presentation/environment_media.gd")
class LayoutProbe extends "res://presentation/sprite_sources.gd":
    var phase:int=0
    var age:float=0.0
    func _ready()->void:
        set_process(false);set_process_unhandled_input(false)
        camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL
        camera.size=512.0/Placement.PIXELS_PER_UNIT
        add_child(camera);camera.current=true;position_camera()
    func record_for(row:Dictionary)->Dictionary:
        return Catalog.environment(row,quarter,catalog_cache,phase,age)
    func prepare_records()->void:
        for entry in entries:
            var record:Dictionary=Catalog.door_frame(entry.placement,quarter,catalog_cache) if entry.source_role==2 else record_for(entry.placement)
            var paths:Dictionary={};EnvironmentMedia.record_paths(record,paths,catalog_cache)
            for path in paths:
                if textures.has(path):continue
                var source:Image=Image.load_from_file(Catalog.media_path(path))
                assert(source!=null and not source.is_empty(),"Exact original/page texture required: "+path)
                source_images[path]=source;textures[path]=ImageTexture.create_from_image(source)
    func texture(path:String)->Texture2D:
        assert(textures.has(path),"Only physically prepared source textures are sampled: "+path)
        return textures.get(path)

var samples:Array=[]
func capture_layout()->Image:
    await process_frame;await RenderingServer.frame_post_draw
    return root.get_texture().get_image()
func visible_pixels(image:Image)->int:
    var count:int=0
    for y in image.get_height():
        for x in image.get_width():
            var value:Color=image.get_pixel(x,y)
            if value.r8>0 or value.g8>0 or value.b8>0:count+=1
    return count
func exact_difference(a:Image,b:Image)->Dictionary:
    if a.get_data()==b.get_data():return {"different_pixels":0,"maximum_byte_error":0}
    var count:int=0;var maximum:int=0
    for y in a.get_height():
        for x in a.get_width():
            var p:Color=a.get_pixel(x,y);var q:Color=b.get_pixel(x,y)
            var error:int=maxi(absi(p.r8-q.r8),maxi(absi(p.g8-q.g8),maxi(absi(p.b8-q.b8),absi(p.a8-q.a8))))
            if error>0:count+=1
            maximum=maxi(maximum,error)
    return {"different_pixels":count,"maximum_byte_error":maximum}
func configure(probe:Node,selected_cache:Dictionary,quarter:int,phase:int,age:float)->void:
    probe.catalog_cache=selected_cache;probe.quarter=quarter;probe.phase=phase;probe.age=age;probe.position_camera()
    probe.prepare_records()
    for entry in probe.entries:
        MaterialOwner.initialize(entry);probe.initialize_entry(entry)
        entry.material.render_priority=entry.layer
        # An active destruction has its single authored bank, not an intact frame.
        if phase>0 and entry.source_role==2:entry.node.hide()
func check_sample(probe:Node,row:Dictionary,raw_cache:Dictionary,paged_cache:Dictionary,quarter:int,phase:int,age:float,label:String)->void:
    var raw_record:Dictionary=Catalog.environment(row,quarter,raw_cache,phase,age)
    var paged_record:Dictionary=Catalog.environment(row,quarter,paged_cache,phase,age)
    var raw_descriptor:Dictionary=Descriptors.describe(row,raw_record,1,quarter,Placement.camera_transform(Vector3.ZERO,quarter).basis,true,true)
    var paged_descriptor:Dictionary=Descriptors.describe(row,paged_record,1,quarter,Placement.camera_transform(Vector3.ZERO,quarter).basis,true,true)
    var raw_shape:Dictionary=raw_descriptor.duplicate();var paged_shape:Dictionary=paged_descriptor.duplicate()
    for value in [raw_shape,paged_shape]:value.erase("record");value.erase("texture_parameters");value.parameters=value.parameters.duplicate();value.parameters.erase("geometry_rect");value.parameters.erase("normal_rect");value.parameters.erase("selection_rect");value.parameters.erase("door_depth_rect")
    check(raw_shape==paged_shape,label+": exact native quad, bounds, placement and depth/normal transforms")
    var required:Dictionary={};Demand.record_paths(paged_record,required,paged_cache)
    if row.kind=="door":Demand.record_paths(Catalog.door_frame(row,quarter,paged_cache),required,paged_cache)
    var layouts:Dictionary=Catalog.texture_layouts(paged_cache)
    check(layouts.keys().all(func(path):return not required.has(path)),label+": required physical source closure excludes oversized originals")
    for mode in ["lit","normals"]:
        publish_receiving([light(Vector2(190,180),WARM,.9,56,650.0/cookie.get_width())],.22,0,mode=="normals")
        configure(probe,raw_cache,quarter,phase,age)
        var raw:Image=await capture_layout()
        configure(probe,paged_cache,quarter,phase,age)
        var actual:Image=await capture_layout()
        var comparison:Dictionary=exact_difference(raw,actual)
        check(comparison.different_pixels==0,label+"/"+mode+": exact original RGBA framebuffer including source alpha and receiving")
        var visible:int=visible_pixels(raw)
        samples.append({"case":label,"mode":mode,"source_frame":raw_record.get("frame"),"raw_visible_pixels":visible,"difference":comparison})
        if comparison.different_pixels>0 or (row.asset=="environment.furniture.stone_bench" and phase==1 and age==0):
            var stem:String=label.replace("/","-")+"-"+mode
            raw.save_png("res://.runtime/native-environment-layouts/"+stem+"-original.png")
            actual.save_png("res://.runtime/native-environment-layouts/"+stem+"-paged.png")
func run()->void:
    if DisplayServer.get_name()=="headless":printerr("NATIVE_ENVIRONMENT_TEXTURE_LAYOUT_CHECKS requires native graphics");quit(2);return
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(512,512);root.msaa_3d=Viewport.MSAA_DISABLED
    var environment:WorldEnvironment=WorldEnvironment.new();environment.environment=Environment.new()
    environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color.BLACK
    environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_DISABLED;root.add_child(environment)
    var one:Image=Image.create(1,1,false,Image.FORMAT_RGBA8);one.fill(Color.WHITE);white=ImageTexture.create_from_image(one);cookie=light_cookie()
    DirAccess.make_dir_recursive_absolute("res://.runtime/native-environment-layouts")
    var paged_cache:Dictionary={}
    var raw_cache:Dictionary={Catalog.ENVIRONMENT+"texture_layouts.res":{"version":2,"layouts":{}}}
    var layouts:Dictionary=Catalog.texture_layouts(paged_cache)
    check(layouts.size()==171,"Actual complete generated171-source numeric layout is present")
    var baseline:Dictionary=layouts.duplicate(true)
    for asset in ["environment.furniture.stone_bench","environment.directional_door","environment.door.indoor_door_elegant","environment.door.indoor_door_shabby_battens"]:
        var row:Dictionary={"id":"original-page-source","kind":"prop" if asset.contains("furniture") else "door","asset":asset,"state":"default" if asset.contains("furniture") else "closed","position":[0,0],"base_height_steps":0,"layer":0,"orientation":"east"}
        var probe:Node=LayoutProbe.new();root.add_child(probe);probe.add_environment_entries(row)
        if row.kind=="door":
            for state in ["closed","open.inward","open.outward"]:
                row.state=state
                for quarter in 4:await check_sample(probe,row,raw_cache,paged_cache,quarter,0,0,asset+"/"+state+"/q"+str(quarter))
        var bank:Dictionary=Catalog.bank_data(Catalog.bank_for(row,true,paged_cache),paged_cache)
        check(not bank.is_empty(),"Actual authored finite destruction bank exists: "+asset)
        if not bank.is_empty():
            var frames:Array=[0,1,int(bank.frame_count)/2,int(bank.frame_count)-1]
            if row.kind=="prop":frames.append_array([7,8]) # Both sides of an8-cell numeric page.
            var seen:Dictionary={}
            for frame in frames:
                if frame<0 or frame>=int(bank.frame_count) or seen.has(frame):continue
                seen[frame]=true
                for quarter in 4:await check_sample(probe,row,raw_cache,paged_cache,quarter,1,frame/float(bank.fps),asset+"/break/frame"+str(frame)+"/q"+str(quarter))
            row.destroyed=true
            for quarter in 4:await check_sample(probe,row,raw_cache,paged_cache,quarter,0,0,asset+"/settled/q"+str(quarter))
        check(samples.filter(func(sample):return str(sample.case).begins_with(asset) and sample.raw_visible_pixels>0).size()>0,"Original native output is actually visible for "+asset)
        probe.free()
    check(layouts==baseline,"Native sampling does not mutate admitted source layouts")
    var result:Dictionary={"checks":checks,"failures":failures,"samples":samples,"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),
        "scope":"Strict original-vs-paged RGBA through the production spatial shader: selected receiving normals, bench/page boundary/destruction/endpoints and actual door leaf/frame/partition in all4quarters. No live performance or visual approval claim."}
    FileAccess.open("res://.runtime/native-environment-layouts/result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("NATIVE_ENVIRONMENT_TEXTURE_LAYOUT_CHECKS ",JSON.stringify({"checks":checks,"failures":failures,"samples":samples.size()}))
    quit(0 if failures.is_empty() else 1)
