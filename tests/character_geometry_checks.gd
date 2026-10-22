extends SceneTree
const Characters = preload("res://presentation/characters.gd")
const Geometry = preload("res://presentation/character_geometry.gd")
const Media = preload("res://presentation/media_warmup.gd")
const Authoring = preload("res://presentation/authoring.gd")
const Protocol = preload("res://sdk/protocol.gd")
const BodySources = preload("res://presentation/body_sources.gd")
const Construction = preload("res://presentation/actor_construction.gd")
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
    var packet = {"sources":sources,"outfits":outfits,"checks":checks,"failures":failures,"state":state_path,"rest_required":resting.required.keys()}
    var output = FileAccess.open("res://generated/character_geometry_cases.json",FileAccess.WRITE)
    output.store_string(JSON.stringify(packet,"  ")); output.close()
    print("CHARACTER_GEOMETRY_CHECKS ",JSON.stringify({"checks":checks,"failures":failures,"numeric_sources":sources.size()}))
    quit(0 if failures.is_empty() else 1)
