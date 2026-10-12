extends SceneTree
# Derived render cache only. Original authoring remains the source of calibration.
const Catalog = preload("res://source_catalog.gd")
const Placement = preload("res://placement.gd")
const Order = preload("res://grid_order.gd")
const OUT="res://generated/render_cache/"
const PAGE=1024
const BLOCK=1024
var cache={}
var records=[]
var record_ids={}
var colours={"regions":{},"pages":[],"x":0,"y":0,"row_height":0,"last_path":"","last_image":null}
var numeric={"regions":{},"pages":[],"x":0,"y":0,"row_height":0,"last_path":"","last_image":null}

func _initialize() -> void:run.call_deferred()
func matrix3(rows: Array) -> Basis:
    return Basis(Vector3(rows[0][0],rows[1][0],rows[2][0]),Vector3(rows[0][1],rows[1][1],rows[2][1]),Vector3(rows[0][2],rows[1][2],rows[2][2]))
func vec(value: Vector3,w: float=0) -> Color:return Color(value.x,value.y,value.z,w)
func c4(value: Array) -> Color:return Color(value[0],value[1],value[2],value[3])
func pack(region: Dictionary, atlas: Dictionary) -> Array:
    var identity=[region.path,region.rect]
    if atlas.regions.has(identity):return atlas.regions[identity]
    if atlas.last_path!=region.path:
        atlas.last_image=Image.load_from_file(Catalog.media_path(region.path))
        assert(atlas.last_image!=null,"Missing original image: "+region.path)
        atlas.last_image.convert(Image.FORMAT_RGBA8)
        atlas.last_path=region.path
    var rect=Rect2i(region.rect[0],region.rect[1],region.rect[2],region.rect[3])
    assert(rect.size.x<=PAGE and rect.size.y<=PAGE,"Source region exceeds atlas page")
    if atlas.x+rect.size.x>PAGE:atlas.x=0;atlas.y+=atlas.row_height;atlas.row_height=0
    if atlas.pages.is_empty() or atlas.y+rect.size.y>PAGE:
        atlas.pages.append(Image.create(PAGE,PAGE,false,Image.FORMAT_RGBA8))
        atlas.x=0;atlas.y=0;atlas.row_height=0
    var result=[atlas.x,atlas.y,atlas.pages.size()-1,rect.size.x,rect.size.y]
    atlas.pages.back().blit_rect(atlas.last_image,rect,Vector2i(atlas.x,atlas.y))
    atlas.x+=rect.size.x;atlas.row_height=maxi(atlas.row_height,rect.size.y)
    atlas.regions[identity]=result
    return result

func compile_record(row: Dictionary,q: int) -> int:
    var identity=[row.get("source_sprite",""),row.get("kind",""),row.get("material",""),row.get("asset",""),row.get("boundaries",[]),row.get("orientation","east"),row.get("affine",[]),row.get("ground_projection",false),row.get("water_surface",false),q]
    if record_ids.has(identity):return record_ids[identity]
    var record=Catalog.environment(row,q,cache)
    var data=[]
    data.resize(24);data.fill(Color(0,0,0,0))
    var size: Array=record.native_size
    var colour=pack({"path":record.path,"rect":record.get("rect",[0,0,size[0],size[1]])},colours)
    data[0]=Color(size[0],size[1],record.pivot[0],record.pivot[1])
    data[1]=Color(record.scale,colour[2],-1,-1)
    data[2]=Color(colour[0],colour[1],0,0)
    data[5]=Color(0,0,-1,-1)
    var selection={}
    for role in record.get("roles",[]):
        if role.role=="ground_shadow":selection=role.selection;break
    if not selection.is_empty():
        data[5].a=1 if selection.kind=="source_rgba" else 0
        if selection.kind=="source_rgba":
            data[17]=c4(selection.bounds.minimum);data[18]=c4(selection.bounds.maximum)
        else:
            var mask=pack(selection.mask.region,numeric)
            data[4].b=mask[0];data[4].a=mask[1]
            data[5]=Color(mask[3],mask[4],mask[2],0)
            var sampling: Dictionary=selection.mask.sampling
            data[8]=Color(sampling.scale[0],sampling.scale[1],sampling.offset[0],sampling.offset[1])
            var values=[-1,-1,-1,-1]
            for i in range(mini(4,selection.values.size())):values[i]=selection.values[i]
            data[19]=c4(values)
    if record.has("geometry"):
        var geo=pack(record.geometry_region,numeric)
        var normal=pack(record.normal.region,numeric)
        data[1].b=geo[2];data[1].a=normal[2]
        data[2].b=geo[0];data[2].a=geo[1]
        data[3]=Color(geo[3],geo[4],normal[0],normal[1])
        data[4].r=normal[3];data[4].g=normal[4]
        var sampling: Dictionary=record.geometry_sampling
        var ns: Dictionary=record.normal.sampling
        data[6]=Color(sampling.scale[0],sampling.scale[1],sampling.offset[0],sampling.offset[1])
        data[7]=Color(ns.scale[0],ns.scale[1],ns.offset[0],ns.offset[1])
        var g: Dictionary=record.geometry
        data[9]=Color(g.depthRange[0],g.depthRange[1],sampling.pixel_center[0],sampling.pixel_center[1])
        var rotation=Basis(Vector3.UP,q*PI/2)
        if g.basis=="object_local":rotation=Basis(Vector3.UP,-["east","north","west","south"].find(row.get("orientation","east"))*PI/2)
        var basis=rotation*Basis.from_scale(Vector3(1,Placement.HEIGHT_UNIT,1))
        var source=matrix3(g.sourceToLocal)
        var origin=Vector3(g.sourceToLocal[0][3],g.sourceToLocal[1][3],g.sourceToLocal[2][3])
        var pixel=matrix3(g.pixelToRayOrigin)
        var receiver=basis*source*pixel
        data[10]=vec(receiver.x);data[11]=vec(receiver.y)
        data[12]=vec(receiver.z+basis*origin)
        data[13]=vec(basis*source*Vector3(g.rayDirection[0],g.rayDirection[1],g.rayDirection[2]))
        var normals=basis.inverse().transposed()*matrix3(record.normal.normalToLocal)
        data[14]=vec(normals.x);data[15]=vec(normals.y);data[16]=vec(normals.z)
    var affine: Array=row.get("affine",[1,0,0,1])
    var a=Vector2(affine[0],affine[1]);var b=Vector2(affine[2],affine[3])
    if row.get("ground_projection",false):
        a=Placement.project(Placement.rotate_grid(Vector2(a.x/128+a.y/64,a.y/64-a.x/128),q),0,0)
        b=Placement.project(Placement.rotate_grid(Vector2(b.x/128+b.y/64,b.y/64-b.x/128),q),0,0)
    data[20]=Color(a.x,a.y,b.x,b.y)
    data[21]=Color(1 if row.get("water_surface",false) or record.has("water") else 0,0,0,0)
    var result=records.size()
    records.append({"data":data,"shadow":not selection.is_empty(),"hidden":record.get("hidden",false)})
    record_ids[identity]=result
    return result

func save_array(atlas: Dictionary,name: String) -> void:
    var images: Array[Image]=[];images.assign(atlas.pages)
    var texture=Texture2DArray.new()
    assert(texture.create_from_images(images)==OK)
    assert(ResourceSaver.save(texture,OUT+name+".res",ResourceSaver.FLAG_COMPRESS)==OK)
    print(name," pages=",images.size()," regions=",atlas.regions.size())

func run() -> void:
    if DisplayServer.get_name()=="headless":
        push_error("Compile with a native rendering device: Godot's dummy headless renderer does not retain texture-array pixels.")
        quit(2);return
    var started=Time.get_ticks_msec()
    DirAccess.make_dir_recursive_absolute(OUT)
    var map=JSON.parse_string(FileAccess.get_file_as_string("res://generated/unity_map.json"))
    var rows: Array=map.placements
    var ids=rows.map(func(row):return row.id)
    var breakable={}
    for i in range(rows.size()):
        if rows[i].kind!="actor" and Catalog.break_duration(rows[i],cache)>0:breakable[i]=true
    var manifest={"version":1,"block_size":BLOCK,"row_ids":ids,"views":[],"breakable":breakable.keys()}
    for q in range(4):
        var instances=[]
        for index in range(rows.size()):
            var row: Dictionary=rows[index]
            if row.kind=="actor":continue
            var record=compile_record(row,q)
            if records[record].hidden:continue
            var role: String=row.get("sort_role",row.kind if row.kind in ["terrain","wall","cliff"] else "body")
            if records[record].shadow:
                instances.append({"row":index,"record":record,"role":0,"key":Order.key(row,"shadow",int(row.get("layer",0))*10,q)})
            instances.append({"row":index,"record":record,"role":1,"key":Order.key(row,role,int(row.get("layer",0))*10+2,q)})
        instances.sort_custom(func(a,b):return Order.less(a.key,b.key) if a.key!=b.key else a.row<b.row)
        var table=Image.create(256,ceili(instances.size()/256.0),false,Image.FORMAT_RGBAF)
        var keys=PackedFloat64Array()
        keys.resize(instances.size()*Order.WIDTH)
        var blocks=[]
        var bounds=AABB()
        var buffer=PackedFloat32Array()
        var ordered_rows=PackedInt32Array()
        var ordered_roles=PackedByteArray()
        for i in range(instances.size()):
            var instance: Dictionary=instances[i]
            var row: Dictionary=rows[instance.row]
            var p=Placement.contact(row)
            table.set_pixel(i%256,i/256,Color(instance.record,instance.row,instance.role,1 if breakable.has(instance.row) else 0))
            for k in range(Order.WIDTH):keys[i*Order.WIDTH+k]=instance.key[k]
            var tint: Array=row.get("tint",[1,1,1,1])
            buffer.append_array(PackedFloat32Array([1,0,0,p.x,0,1,0,p.y,0,0,1,p.z,tint[0],tint[1],tint[2],tint[3]]))
            # Conservative per-block bounds cover both painted quads and their
            # light receiving positions. No image decode or depth scan at runtime.
            var data: Array=records[instance.record].data
            var radius=maxf(data[0].r,data[0].g)*data[1].r/Placement.PIXELS_PER_UNIT
            radius*=maxf(1,Vector2(data[20].r,data[20].g).length()+Vector2(data[20].b,data[20].a).length())
            var box=AABB(p-Vector3.ONE*radius,Vector3.ONE*radius*2)
            bounds=box if buffer.size()==16 else bounds.merge(box)
            ordered_rows.append(instance.row);ordered_roles.append(instance.role)
            if buffer.size()/16==BLOCK or i==instances.size()-1:
                blocks.append({"base":i+1-buffer.size()/16,"buffer":buffer,"bounds":bounds})
                buffer=PackedFloat32Array()
        assert(ResourceSaver.save(ImageTexture.create_from_image(table),OUT+"instances-"+str(q)+".res",ResourceSaver.FLAG_COMPRESS)==OK)
        var file=FileAccess.open(OUT+"view-"+str(q)+".bin",FileAccess.WRITE)
        file.store_var({"keys":keys,"blocks":blocks,"rows":ordered_rows,"roles":ordered_roles})
        manifest.views.append({"count":instances.size(),"blocks":blocks.size()})
        print("quarter=",q," instances=",instances.size()," blocks=",blocks.size()," records=",records.size())
        await process_frame
    var metadata=Image.create(32,records.size(),false,Image.FORMAT_RGBAF)
    for r in range(records.size()):
        for c in range(24):metadata.set_pixel(c,r,records[r].data[c])
    assert(ResourceSaver.save(ImageTexture.create_from_image(metadata),OUT+"metadata.res",ResourceSaver.FLAG_COMPRESS)==OK)
    save_array(colours,"colour");save_array(numeric,"numeric")
    manifest.records=records.size();manifest.compile_ms=Time.get_ticks_msec()-started
    var file=FileAccess.open(OUT+"manifest.json",FileAccess.WRITE);file.store_string(JSON.stringify(manifest))
    print("GRID_COMPILED ",manifest.compile_ms,"ms")
    quit()
