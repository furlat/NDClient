extends SceneTree
const Characters = preload("res://presentation/characters.gd")
const Geometry = preload("res://presentation/character_geometry.gd")
const Media = preload("res://presentation/media_warmup.gd")
const Authoring = preload("res://presentation/authoring.gd")
const Protocol = preload("res://sdk/protocol.gd")
const BodySources = preload("res://presentation/body_sources.gd")
const Construction = preload("res://presentation/actor_construction.gd")
const NativeBankShadows = preload("res://presentation/canvas_shadows.gd")
var checks = 0
var failures: Array = []
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures.append(label); print("GEOMETRY_FAIL ",label)
func _initialize() -> void: run.call_deferred()
func facing_origins(path:String,cache:Dictionary,rig:Dictionary)->void:
    # Private registration operands on an actual admitted source; no new art,
    # anatomical marker or claim about the selected dragon's facing adapter.
    var original:Dictionary=Geometry.record(path,"body",cache)
    var scalar:Vector2=Geometry.camera_origin(original)
    var facings:Array=rig.facing_rows.keys()
    var current:Dictionary=cache[BodySources.KEY]
    var owner:Array=current.index.source_owners[path]
    var layer:Resource=current.loaded[owner[0]]
    var clip_path:String=layer.clip_sources[owner[1]]
    var clip:Resource=current.loaded[clip_path]
    var untouched:PackedByteArray=var_to_bytes(clip.descriptors)
    var copy:Resource=clip.duplicate(false);copy.descriptors=clip.descriptors.duplicate()
    var descriptor:Dictionary=BodySources.descriptor(path,"body",cache).duplicate()
    var source:Dictionary=original.duplicate();source.optical_camera=original.optical_camera.duplicate()
    var origins:Dictionary={}
    origins[facings[0]]=[scalar.x-3,scalar.y+2];origins[facings[1]]=[scalar.x+4,scalar.y-1]
    source.optical_camera.origins_by_facing=origins;descriptor.geometry=source;copy.descriptors.body=descriptor
    var loaded:Dictionary=current.loaded.duplicate();loaded[clip_path]=copy
    var own:Dictionary=cache.duplicate();own[BodySources.KEY]={"index":current.index,"loaded":loaded}
    var ordinary:Dictionary=Geometry.prepare_binding(path,"body",cache,true,true,"original",1.0,1.0)
    var prepared:Dictionary=Geometry.prepare_binding(path,"body",own,true,true,"original",1.0,1.0)
    var header:Dictionary=BodySources.header(path,cache)
    var sheet_size:=Vector2(header.width,header.height)
    var material:=ShaderMaterial.new();material.shader=Construction.MODULAR_SHADER
    var entry:Dictionary={"material":material,"actor_layer":{"slot":"body"}}
    Construction.bind_source_values(entry,rig,path,0,facings[0],null,sheet_size,{},{},{})
    Geometry.apply_binding_values(entry,prepared)
    check(entry.source_parameters.component_reconstruction_origin==Vector2(scalar.x-3,scalar.y+2),"First actual facing projects its registration when geometry binds after the source frame")
    var version:int=entry.source_version
    Construction.bind_source_values(entry,rig,path,0,facings[1],null,sheet_size,{},{},{})
    check(entry.geometry_binding==prepared.key and entry.source_version>version \
        and entry.source_parameters.component_reconstruction_origin==Vector2(scalar.x+4,scalar.y-1),"Facing changes update the real source ledger without rebinding the unchanged sheet")
    version=entry.source_version
    Construction.bind_source_values(entry,rig,path,0,facings[1],null,sheet_size,{},{},{})
    check(entry.source_version==version,"Unchanged facing and source values retain ordinary material coalescing")
    var future:Dictionary=Geometry.parameters_for_facing(prepared,facings[0])
    check(future.component_reconstruction_origin==Vector2(scalar.x-3,scalar.y+2) \
        and prepared.parameters.component_reconstruction_origin==scalar and prepared.camera_origins.is_read_only(),"Future pose registration is private and leaves prepared scalar/map operands immutable")
    var relative:=Basis(Vector3.RIGHT,-(deg_to_rad(source.optical_camera.elevation_degrees)-PI/6.0))
    var cell:Array=source.get("cell_size",[128,128]);var covered:bool=true
    var units:float=1.0/Construction.Placement.PIXELS_PER_UNIT
    for origin in origins.values():
        for x in [0.0,float(cell[0])]:
            for y in [0.0,float(cell[1])]:
                for depth in source.depth_range:
                    covered=covered and prepared.bounds.has(relative*Vector3(x-origin[0],origin[1]-y,depth)*units)
    check(covered,"Prepared bounds cover both facing registrations at every cell/depth extreme")
    check(not ordinary.has("camera_origins") and is_same(Geometry.parameters_for_facing(ordinary,facings[0]),ordinary.parameters) \
        and ordinary.parameters.component_reconstruction_origin==scalar and var_to_bytes(clip.descriptors)==untouched,"Default scalar registration and the original admitted source remain unchanged")
## Deliberately technical in-memory atlas. These are not producer/Dragon/art
## facts: six labelled cells, eight view URLs, complete coupled optical data.
## The existing real-source controls below remain the separate default oracle.
func technical_native_banks()->Dictionary:
    var facings:Array=["E","SE","S","SW","W","NW","N","NE"]
    var root_path:String="res://.runtime/technical-native-bank"
    var layer_path:String=root_path+"/body.res";var clip_path:String=root_path+"/clip.res"
    var rig_id:String="technical.native-bank";var category:String="TechnicalBody"
    var index=BodySources.Index.new();var layer=BodySources.Layer.new();var clip=BodySources.Clip.new()
    var banks:Dictionary={};var views:Dictionary={};var shapes:Dictionary={};var textures:Dictionary={}
    var palette:Array=[Color.RED,Color.GREEN,Color.BLUE,Color.YELLOW,Color.MAGENTA,Color.CYAN]
    for ordinal in facings.size():
        var facing:String=facings[ordinal];var path:String=root_path+"/"+facing+".png"
        var cell:Array=[8,5] if ordinal>=6 else [6,4]
        var pivot:Array=[2+ordinal%2,3];var origin:Array=[3+ordinal,2]
        var rects:Array=[]
        var colour:Image=Image.create(cell[0]*3,cell[1]*2,false,Image.FORMAT_RGBA8)
        for frame in 6:
            var rect:Array=[(frame%3)*cell[0],(frame/3)*cell[1],cell[0],cell[1]]
            rects.append(rect);colour.fill_rect(Rect2i(rect[0],rect[1],rect[2],rect[3]),palette[frame])
        textures[path]=ImageTexture.create_from_image(colour)
        var files:Dictionary={};var companions:Dictionary={};var roles:Dictionary={path:[path,1,0,0]}
        for field in ["depth","normal","support","normal_valid"]:
            var relative:String=facing+"-"+field+".png";var absolute:String=root_path+"/"+relative
            var image:Image=Image.create(colour.get_width(),colour.get_height(),false,Image.FORMAT_RGBA8)
            image.fill(Color(.5,.5,1,1) if field=="normal" else Color(.5,.5,.5,1) if field=="depth" else Color.WHITE)
            textures[absolute]=ImageTexture.create_from_image(image)
            files[field]=relative;companions[absolute]=true;roles[absolute]=[absolute,0,0,0]
        var layout:Dictionary={"cell":cell,"pivot":pivot,"frame_rects":rects,"sheet_size":[colour.get_width(),colour.get_height()]}
        var normal:String=root_path+"/"+files.normal
        var geometry:Dictionary={"status":"ready","role":"body","slots":["body"],"_source_root":root_path,
            "files":files,"cell_size":cell,"frames":6,"depth_range":[-2,2],"depth_byte_range":[32,224],
            "optical_camera":{"origin":origin,"elevation_degrees":30.0},"optical_ground_pixels":0.0}
        var records:Dictionary={}
        for profile in ["original","gentle","reference"]:
            records[profile]={"source_id":StringName(path+"/"+profile),"roles":roles,
                "native_body_cell":cell,"native_body_colour":path}
        banks[path]={"path":path,"geometry":geometry,"source_layout":layout,"companions":companions,
            "normal_paths":{"original":normal},"normal_sets":{path:{"original":normal}},
            "source_records":records,"native_record":{"source_id":StringName(path+"/native"),"roles":{}}}
        views[facing]=path;shapes[path]={"path":path,"cell":cell,"pivot":pivot}
        layer.headers[path]={"width":colour.get_width(),"height":colour.get_height()}
        index.source_owners[path]=[layer_path,"Grid"]
    clip.descriptors={"body":{"banks":banks}}
    layer.rig_id=rig_id;layer.category=category;layer.clip_sources={"Grid":clip_path}
    layer.bank_paths_by_slot={"body":{"Grid":views}}
    var rig:Dictionary={"native_banks":true,"cell_width":12,"cell_height":12,"origin_y_from_ground":3,
        "generated_shadow":true,"slot_order":["body"],"slot_categories":{"body":[category]},
        "facing_rows":{"E":0,"SE":1,"S":2,"SW":3,"W":4,"NW":5,"N":6,"NE":7},
        "clips":{"Grid":{"frames":6,"fps":12.0,"bank_shapes":shapes}}}
    index.root_rig="technical.other-root";index.rigs={rig_id:rig}
    index.creature_rigs={"technical.native-bank":rig_id};index.layers={rig_id:{category:layer_path}}
    var loaded:Dictionary={layer_path:layer,clip_path:clip};loaded.make_read_only()
    var admission:Dictionary={"index":index,"loaded":loaded};admission.make_read_only()
    var cache:Dictionary={BodySources.KEY:admission}
    var actor:Dictionary={"uuid":"technical-actor","creature_content_ref":"technical.native-bank",
        "appearance":{},"presentation_layers":[]}
    var original:PackedByteArray=var_to_bytes([index.rigs,index.source_owners,layer.headers,clip.descriptors])
    var prepared:Dictionary=Characters.prepare_layers({"equipment_layers":[{"slot":"body","category":category,"source_path":layer_path}]},rig,cache)
    check(prepared.ok,"Technical native body admits its one exact typed category/clip owner")
    if not prepared.ok:return {}
    var actual:Dictionary=prepared.value[0]
    var closure:Dictionary=Characters.sheet_paths(actor,["Grid"],cache)
    check(closure.ok,"Technical selected clip admits all eight views and complete coupled companions")
    if not closure.ok:return {}
    for facing in facings:
        var selected:String=Characters.source_path(actual,"Grid",facing)
        check(selected==root_path+"/"+facing+".png" and closure.value.has(selected),"Exact technical view URL is selected: "+facing)
        check(is_same(BodySources.descriptor(selected,"body",cache),banks[selected]),"Exact typed descriptor is borrowed: "+facing)
    check(Characters.source_path(actual,"Grid","unknown").is_empty(),"An absent native view cannot borrow another facing")
    var path:String=views.E;var layout:Dictionary=banks[path].source_layout
    check(Construction.source_uv(rig,layout,2,"E",Vector2(18,8))==Vector4(2.0/3.0,0,1.0/3.0,.5)
        and Construction.source_uv(rig,layout,3,"E",Vector2(18,8))==Vector4(0,.5,1.0/3.0,.5),"Hand-authored frame2→3 crosses an atlas row without changing cell size or selecting unused cells")
    var scale:float=2.0;var units:float=scale/Construction.Placement.PIXELS_PER_UNIT
    var shape:Dictionary=Construction.layer_shape(rig,scale,layout)
    check(shape.mesh_size==Vector2(12,8)/Construction.Placement.PIXELS_PER_UNIT
        and shape.mesh_center==Vector3(units,units,0),"Hand-authored contact(2,3) controls the exact scale2 quad centre and extent")
    var node:=MeshInstance3D.new();var material:=ShaderMaterial.new();material.shader=Construction.MODULAR_SHADER
    var entry:Dictionary={"node":node,"material":material,"actor_layer":{"slot":"body"},"scale":scale,
        "native_shapes":Construction.prepare_native_shapes(rig,scale),"native_shape_rig":rig,"native_shape_scale":scale}
    for ordinal in facings.size():
        var facing:String=facings[ordinal];var selected:String=Characters.source_path(actual,"Grid",facing)
        var view_binding:Dictionary=Construction.realize_private_binding(Construction.prepare_binding(rig,entry.actor_layer,selected,cache,true,true,"original",scale,1.0),textures)
        var admitted:bool=Construction.apply_source_shape(entry,rig,selected,banks[selected].source_layout)
        Construction.bind_source_values(entry,rig,selected,3,facing,view_binding.sheet,view_binding.sheet_size,textures,{},{})
        Geometry.apply_binding(entry,view_binding.geometry)
        check(admitted and entry.texture_path==root_path+"/"+facing+".png"
            and entry.source_parameters.sheet==textures[root_path+"/"+facing+".png"]
            and entry.source_parameters.frame_uv==Vector4(0,.5,1.0/3.0,.5)
            and entry.source_parameters.component_reconstruction_origin==Vector2(3+ordinal,2),"Actual technical view binding publishes its own texture, cross-row UV and optical origin: "+facing)
    check(Construction.apply_source_shape(entry,rig,path,layout),"Selected technical cell adopts its actually prepared painted quad")
    var binding:Dictionary=Construction.prepare_binding(rig,entry.actor_layer,path,cache,true,true,"original",scale,1.0)
    var realised:Dictionary=Construction.realize_private_binding(binding,textures)
    Construction.bind_source_values(entry,rig,path,3,"E",realised.sheet,realised.sheet_size,textures,{},{})
    Geometry.apply_binding(entry,realised.geometry)
    check(entry.cell==Vector2(6,4) and entry.pivot==Vector2(2,3)
        and entry.source_parameters.component_reconstruction_origin==Vector2(3,2)
        and entry.source_parameters.component_units==units
        and entry.source_parameters.component_depth==textures[root_path+"/E-depth.png"]
        and entry.source_parameters.component_normal==textures[root_path+"/E-normal.png"],"Coupled original geometry receives the selected cell/contact/origin, scale and exact independent texture operands")
    var expected_point:=Vector3(-2.5*units,1.5*units,-1.5*units)
    check(node.custom_aabb.has_point(expected_point),"Prepared geometry bounds include an independently hand-computed optical point inside the source domain")
    var version:int=entry.source_version;var revision:int=entry.source_binding_revision
    var previous_mesh:QuadMesh=entry.node.mesh;entry.geometry_binding=["must invalidate"]
    check(Construction.apply_source_shape(entry,rig,views.SE,banks[views.SE].source_layout)
        and entry.node.mesh!=previous_mesh and entry.node.mesh.size==previous_mesh.size
        and entry.source_parameters.source_quad_size==Vector2(12,8)/Construction.Placement.PIXELS_PER_UNIT
        and entry.source_version>version and entry.source_binding_revision>revision and not entry.has("geometry_binding"),
        "Equal-size bank with a different contact updates native mesh, structural revision and expanded-bound invalidation")
    version=entry.source_version;revision=entry.source_binding_revision
    Construction.apply_source_shape(entry,rig,views.SE,banks[views.SE].source_layout)
    check(entry.source_version==version and entry.source_binding_revision==revision,"Unchanged native bank keeps ordinary material coalescing")
    var wrong_scale:Dictionary=entry.duplicate();wrong_scale.scale=1.0
    var altered:Dictionary=banks[views.SE].source_layout.duplicate();altered.pivot=[0,0]
    check(not Construction.source_shape_ready(wrong_scale,rig,views.SE,banks[views.SE].source_layout)
        and not Construction.source_shape_ready(entry,rig.duplicate(),views.SE,banks[views.SE].source_layout)
        and not Construction.source_shape_ready(entry,rig,views.SE,altered)
        and not Construction.source_shape_ready(entry,rig,"unprepared.png",layout),"Wrong actor scale, rig owner, undeclared contact or missing source refuses the prepared-shape proof")
    check(entry.source_version==version and entry.node.mesh.size==previous_mesh.size,"Refused/passive shape checks leave the displayed mesh and material unchanged")
    var missing:Resource=clip.duplicate(false);missing.descriptors={"body":{"banks":banks.duplicate()}}
    missing.descriptors.body.banks[path]=banks[path].duplicate();missing.descriptors.body.banks[path].source_layout={}
    var missing_cache:Dictionary={BodySources.KEY:{"index":index,"loaded":{layer_path:layer,clip_path:missing}}}
    check(not Characters.sheet_paths(actor,["Grid"],missing_cache).ok,"Missing admitted native layout cannot certify source readiness")
    missing.descriptors.body.banks[path]=banks[path].duplicate()
    missing.descriptors.body.banks[path].source_records=banks[path].source_records.duplicate()
    missing.descriptors.body.banks[path].source_records.original=banks[path].source_records.original.duplicate()
    missing.descriptors.body.banks[path].source_records.original.native_body_cell=[7,4]
    check(not Characters.sheet_paths(actor,["Grid"],missing_cache).ok,"A caster-cell contribution inconsistent with its actual admitted bank cannot certify readiness")
    var source_records:Array=closure.source_records.original
    var first_use:Dictionary={}
    for source in source_records:
        for demand in source.roles:first_use[demand]=30.0 if source.native_body_cell==[8,5] else 0.0
    var schedule:Dictionary=Media._source_cut_schedule(source_records,first_use,{}, {"previous":[],"current":[]})
    var complete:Dictionary=Media._source_family(source_records,{})
    var early:Dictionary=Media.native_cells_at(schedule,0,complete.native_cells)
    var due:Dictionary=Media.native_cells_at(schedule,30,complete.native_cells)
    check(early=={Vector2i(6,4):true} and due=={Vector2i(6,4):true,Vector2i(8,5):true},"Native caster demand follows actual selected first-use cuts and deduplicates equal cells")
    var shadows:=NativeBankShadows.new()
    var exhausted:Dictionary={"used_usec":5,"limit_usec":5}
    check(not shadows.prepare_source_cells(due,exhausted) and exhausted.used_usec==5
        and not shadows.source_cells_ready(early),"Exhausted allowance cannot allocate a native caster grid, and passive readiness cannot create one")
    var allowance:Dictionary={"used_usec":0,"limit_usec":1000000}
    check(not shadows.prepare_source_cells(due,allowance) and shadows.source_cells_ready(early)
        and not shadows.source_cells_ready({Vector2i(8,5):true}),"One preparation call realizes only one actual selected grid/RID")
    var charged:int=allowance.used_usec
    check(shadows.prepare_source_cells({},allowance) and allowance.used_usec==charged
        and not shadows.source_cells_ready({Vector2i(8,5):true}),"Withdrawn empty demand performs no allocation or leftover stepping")
    allowance={"used_usec":0,"limit_usec":1000000}
    check(shadows.prepare_source_cells(due,allowance) and shadows.source_cells_ready(due),"A later actual demanded unit completes the remaining selected grid")
    shadows.close()
    node.free()
    check(var_to_bytes([index.rigs,index.source_owners,layer.headers,clip.descriptors])==original,"All native-bank controls preserve their owned admitted metadata")
    return {"scope":"Technical in-memory API/metadata/mesh/material admission only; not Dragon/producer/raster/art evidence",
        "facings":facings,"frames":6,"cross_row_frames":[2,3],"source_urls":views.values(),"early_cells":[[6,4]],"due_cells":[[6,4],[8,5]],"canonical_actor_scale_unchanged":true}

func run() -> void:
    var state_path:String="res://tests/fixtures/schema16/character_sources.json"
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--state="):state_path=argument.trim_prefix("--state=")
    var parsed = Protocol.parse_json(FileAccess.get_file_as_bytes(state_path))
    check(parsed.ok,"Actual equipped fighter and sorcerer state parses")
    if not parsed.ok: quit(1); return
    var state: Dictionary = parsed.value
    var held:PackedByteArray=var_to_bytes(state)
    var cache = {}
    var index:Resource=BodySources.index(cache)
    check(index!=null,"Actual typed body-source index is admitted")
    if index==null:quit(1);return
    var rigs:Dictionary=Characters.rigs(cache)
    var sources = {}
    var outfits = []
    var expected_rest:Dictionary={}
    check(state.actors.size()==2,"Original Crypt state retains both equipped modular characters")
    for actor in state.actors.values():
        var resolved = Characters.resolve(actor,state,cache)
        check(resolved.ok and resolved.value!=null,"Existing equipped outfit resolves: "+actor.name)
        if not resolved.ok or resolved.value==null: continue
        var rig:Dictionary=rigs[resolved.value.rig]
        var prepared:Dictionary=Characters.prepare_layers(resolved.value,rig,cache)
        check(prepared.ok,"Exact selected typed layer sources prepare: "+actor.name)
        if not prepared.ok:continue
        var layers:Array=prepared.value
        outfits.append({"name":actor.name,"row":resolved.value,"layers":layers})
        var looks:Dictionary=Characters.item_looks(actor,state)
        var sheet_result:Dictionary=Characters.sheet_paths(actor,["Idle","Run","Attack1"],cache,looks)
        check(sheet_result.ok,"Actual native item variants share geometry source demand: "+actor.name)
        if not sheet_result.ok:continue
        var demanded:Dictionary=sheet_result.value
        for layer in layers:
            for clip in ["Idle","Run","Attack1"]:
                if not layer.paths.has(clip): continue
                var path: String = layer.paths[clip]
                var record = Geometry.record(path,layer.slot,cache)
                if layer.slot == "shadow":
                    check(record.is_empty() and Geometry.paths(path,layer.slot,cache).is_empty(),"Shadow never supplies optical geometry")
                    continue
                check(not record.is_empty() and record.category==layer.category,"Companion matches actual selected component: "+layer.slot+"/"+path)
                check(record.source_action==path.get_file().get_basename(),"Exact source action, not an assumed causal clip: "+path)
                check(Geometry.paths(path,layer.slot,cache).size()==6 and Geometry.paths(path,layer.slot,cache).keys().all(func(p):return demanded.has(p)),"Original geometry, both masks and all normal profiles share causal media demand: "+path)
                var normals:Dictionary=Geometry.normal_paths(path,layer.slot,cache).value
                for profile in Geometry.PROFILES:
                    var selected:Dictionary=Geometry.paths(path,layer.slot,cache,profile)
                    check(normals.has(profile) and selected.size()==4 and selected.has(normals.get(profile,"")),"One actual normal profile retains depth/support/valid masks: "+path+"/"+profile)
                    for other in normals.values():
                        check(selected.has(other)==(other==normals.get(profile)),"Normal-profile demand never includes another profile: "+profile+"/"+other)
                sources[path] = layer.slot
        var head = layers.filter(func(layer):return layer.slot=="head")
        var helmet = layers.filter(func(layer):return layer.slot=="helmet")
        check(head.size()==1 and helmet.size()==1,"Current head retention survives equipped helmet: "+actor.name)
        check(actor.life_state=="alive" and actor.conditions.is_empty(),"Original rest control has no terminal or condition pose: "+actor.name)
        var equipment:Dictionary=Authoring.body("equipment",actor,{},cache).actor
        check(equipment.enabled and equipment.clip=="Taunt","Actual equipment events retain their selected authored Taunt: "+actor.name)
        # This initialization has no equipment event or actor track. Taunt is
        # demanded by its actual track, never by every resting alive actor.
        var closure:Dictionary=Characters.sheet_paths(actor,["Idle"],cache,looks)
        check(closure.ok,"Exact resting Idle geometry closure resolves: "+actor.name)
        if closure.ok:expected_rest.merge(closure.value)
    for category in ["Chest3","Chest7","Shield1","Shield5","NakedBody3"]:
        var slot = "chest" if category.begins_with("Chest") else "body" if category.begins_with("Naked") else "offhand"
        for clip in ["Idle","Run","Attack1"]:
            var layer:Resource=BodySources.layer(index.root_rig,category,cache)
            check(layer!=null and layer.paths_by_slot.get(slot,{}).has(clip),"Actual imported independent swap owns its clip: "+category+"/"+clip)
            if layer==null or not layer.paths_by_slot.get(slot,{}).has(clip):continue
            var swap_path:String=layer.paths_by_slot[slot][clip]
            BodySources.prepare_descriptor(swap_path,slot,cache)
            check(not Geometry.record(swap_path,slot,cache).is_empty(),"Delivered independent swap remains supported: "+swap_path)
            sources[swap_path] = slot
    check(Geometry.record("/media/not-a-delivered-sheet.png","body",cache).is_empty(),"Unknown source has clean flat fallback")
    var body_layer:Resource=BodySources.layer(index.root_rig,"NakedBody",cache)
    var body_path:String=body_layer.paths_by_slot.body.Idle
    BodySources.prepare_descriptor(body_path,"body",cache)
    check(not Geometry.record(body_path,"body",cache).is_empty() and Geometry.record(body_path,"effect",cache).is_empty(),"A valid admitted body cannot be reassigned to an effect role")
    facing_origins(body_path,cache,rigs[index.root_rig])
    var resting = Media.plan(state,[],cache)
    check(resting.errors.is_empty() and resting.required==expected_rest,"Initial rest demand is exactly actual Idle geometry; actual equipment tracks retain their own later demand")
    check(var_to_bytes(state)==held,"Geometry/source preparation preserves original canonical actor/item state")
    var native_bank_control:Dictionary=technical_native_banks()
    var packet = {"native_bank_control":native_bank_control,"sources":sources,"outfits":outfits,"checks":checks,"failures":failures,"state":state_path,"rest_required":resting.required.keys()}
    var output = FileAccess.open("res://generated/character_geometry_cases.json",FileAccess.WRITE)
    output.store_string(JSON.stringify(packet,"  ")); output.close()
    print("CHARACTER_GEOMETRY_CHECKS ",JSON.stringify({"checks":checks,"failures":failures,"numeric_sources":sources.size()}))
    quit(0 if failures.is_empty() else 1)
