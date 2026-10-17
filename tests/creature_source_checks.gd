extends "res://tests/native_2d_source_checks.gd"
# Reuse the independent native light/CPU-normal oracle, with original creatures,
# through the production lit modular sprite shader.
func creature(path: String,frame: int,row: int,profile: String,mirror: bool) -> Dictionary:
    # Media preparation admits the body metadata before any descriptor read.
    Geometry.BodySources.prepare_descriptor(path,"body",cache)
    # Production binds and displays the registered sheet itself (no display_path
    # indirection remains); its descriptor is indexed by that path only.
    var selected=path
    var source=Geometry.record(selected,"body",cache)
    var cell=Vector2i(source.cell_size[0],source.cell_size[1])
    var material=ShaderMaterial.new();material.shader=Modular
    var node=MeshInstance3D.new();node.mesh=QuadMesh.new()
    var entry={"node":node,"material":material,"scale":2.0,"placement":{"scale_x":-1.0 if mirror else 1.0},"actor_layer":{"slot":"body"}}
    material.set_shader_parameter("sheet",texture(selected))
    material.set_shader_parameter("frame_uv",Vector4(float(frame)/source.frames,float(row)/8,1.0/source.frames,1.0/8))
    material.set_shader_parameter("material_cell_size",Vector2(cell))
    Geometry.bind(entry,selected,cache,texture,true,true,profile)
    var profiles=Geometry.normal_paths(selected,"body",cache)
    var geometry_root: String=ProjectSettings.get_setting("source_data/creature_geometry_root")
    var origin=Vector2i(frame*cell.x,row*cell.y)
    var colour: Image=images[selected].get_region(Rect2i(origin,cell))
    var decoded=Image.create(cell.x,cell.y,false,Image.FORMAT_RGBAF)
    var supported := 0
    var unsupported := 0
    for y in cell.y:
        for x in cell.x:
            var at=origin+Vector2i(x,y)
            var n=Vector3(0,0,1)
            var packed: Color=images[profiles.value[profile]].get_pixelv(at)
            if images[geometry_root.path_join(source.files.support)].get_pixelv(at).r>.5 and images[geometry_root.path_join(source.files.normal_valid)].get_pixelv(at).r>.5 and images[geometry_root.path_join(source.files.depth)].get_pixelv(at).a>.5 and packed.a>.5:
                n=Vector3((packed.r*2-1)*(-1 if mirror else 1),-(packed.g*2-1),packed.b*2-1).normalized()
                if colour.get_pixel(x,y).a>0:supported+=1
            elif colour.get_pixel(x,y).a>0: unsupported+=1
            decoded.set_pixel(x,y,Color(n.x,n.y,n.z,1))
    node.free()
    check(supported>0,source.family+" selected native frame has delivered support")
    if source.family=="stag" and source.source_action=="Die":check(unsupported>0,"Repeated-view Stag Die retains visible unsupported pixels")
    return {"id":"creature-"+source.family+"-"+source.source_action+"-f"+str(frame)+"-r"+str(row)+"-"+profile+("-mirror" if mirror else ""),"material":material,"colour":colour,"normals":decoded,"tint":Color.WHITE,"visible":1.0,"mirror":mirror,"supported":supported,"basis":Basis.IDENTITY}

func run() -> void:
    if DisplayServer.get_name()=="headless":quit(2);return
    root.unfocusable=true;root.position=Vector2i(-16000,-16000)
    var one=Image.create(1,1,false,Image.FORMAT_RGBA8);one.fill(Color.WHITE);white=ImageTexture.create_from_image(one)
    cookie=light_cookie();reference_shader=Shader.new();reference_shader.code=REFERENCE
    DirAccess.make_dir_recursive_absolute("res://.captures/native-2d-source")
    var table: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Geometry.CREATURE_TABLE))
    var selected={}
    var frames_seen={}
    var cells_seen={}
    var named_found={}
    var unadmitted:=0
    for path in table.records:
        var source: Dictionary=table.records[path]
        # The geometry table also lists sheets the current body catalog does not
        # admit (no descriptor); production never binds those, so skip them.
        Geometry.BodySources.prepare_descriptor(path,"body",cache)
        if Geometry.record(path,"body",cache).is_empty():unadmitted+=1;continue
        var named: bool=(source.family in ["goblin-15","wolf","boar","elephant"] and source.source_action=="Idle") or (source.family=="stag" and source.source_action=="Die")
        if named:named_found[source.family]=true
        var frame_count: int=source.frames
        var width: int=source.cell_size[0]
        if named or not frames_seen.has(frame_count) or not cells_seen.has(width):
            selected[path]=true;frames_seen[frame_count]=true;cells_seen[width]=true
    check(named_found.size()==5,"Every named creature source is admitted by the body catalog: "+str(named_found.keys()))
    for path in selected:
        var source: Dictionary=table.records[path]
        for profile in ["original","gentle","reference"]:
            var row=0 if profile=="original" else 3 if profile=="gentle" else 7
            var fixture=creature(path,int(source.frames)-1,row,profile,profile=="reference")
            await check_source(fixture,true)
            if profile=="original":await check_source(fixture,false)
        if source.family=="stag":
            for row in [1,2,4,5,6]:await check_source(creature(path,0,row,"reference",false),true)
        # Finite source fixtures should not retain the entire library in GPU RAM.
        textures.clear();images.clear()
    var report={"checks":checks,"failures":failures,"selected_sources":selected.keys(),"unadmitted_table_records":unadmitted,"cell_widths":cells_seen.keys(),"frame_counts":frames_seen.keys(),"comparisons":comparisons,"scope":"Production lit modular creature sprite vs independent CPU-decoded native-light Canvas reference (linear-alpha composite, one RGB byte, exact alpha). Original visible-body alpha and unsupported flat normals retained; original/gentle/reference, final frames and facing/mirror changes. No new gameplay aliases."}
    FileAccess.open("res://generated/creature_source_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("CREATURE_SOURCE_CHECKS ",JSON.stringify({"checks":checks,"failures":failures,"sources":selected.size()}));quit(0 if failures.is_empty() else 1)
