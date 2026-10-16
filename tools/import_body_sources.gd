extends SceneTree
## Offline metadata import. Original artwork and approved presentation are read
## unchanged; runtime consumers never execute these joins or freshness checks.
const Catalog=preload("res://source_catalog.gd")
const Index=preload("res://presentation/resources/body_source_index.gd")
const Layer=preload("res://presentation/resources/body_source_layer.gd")
var cache:Dictionary={}
var geometry:Dictionary={}
var creatures:Dictionary={}
var profiles:Dictionary={}
var headers:Dictionary={}
var errors:Array=[]
var output:String="res://.derived/body-sources"

func _initialize()->void:run.call_deferred()
func read(path:String)->Variant:return JSON.parse_string(FileAccess.get_file_as_string(path))
func _header(path:String)->Dictionary:
    if headers.has(path):return headers[path]
    var file=FileAccess.open(Catalog.media_path(path),FileAccess.READ)
    if file==null:
        headers[path]={"error":"Cannot inspect authored PNG: "+path};return headers[path]
    var bytes:PackedByteArray=file.get_buffer(24)
    if bytes.size()!=24:
        headers[path]={"error":"Invalid authored PNG dimensions: "+path};return headers[path]
    headers[path]={"width":(int(bytes[16])<<24)|(int(bytes[17])<<16)|(int(bytes[18])<<8)|int(bytes[19]),
        "height":(int(bytes[20])<<24)|(int(bytes[21])<<16)|(int(bytes[22])<<8)|int(bytes[23])}
    return headers[path]

func _geometry(path:String,slot:String)->Dictionary:
    if slot=="shadow":return {}
    var modular:bool=path.begins_with("/media/smallscale/modular/")
    if not modular and slot!="body":return {}
    var table:Dictionary=geometry if modular else creatures
    var identity:String=path
    if not modular and not path.begins_with("/media/"):
        var root:String=ProjectSettings.get_setting("source_data/creature_geometry_root")
        if not path.begins_with(root+"/"):return {}
        identity=table.colour_sources.get(path.trim_prefix(root+"/"),"")
    var source:Dictionary=table.records.get(identity,{})
    if not source.has("files") or slot not in source.slots:return {}
    var result:Dictionary=source.duplicate()
    if not result.has("optical_camera"):result.optical_camera=table.get("optical_camera",{})
    result._source_root=_root(source)
    return result

func _root(source:Dictionary)->String:
    return ProjectSettings.get_setting("source_data/creature_geometry_root" if source.has("normal_profiles") else "source_data/character_geometry_root")

func _display(path:String,slot:String,components:Dictionary)->String:
    if slot!="body":return path
    path=components.get(path,{}).get("source_layers",{}).get("body",path)
    var source:Dictionary=_geometry(path,slot)
    return _root(source).path_join(source.colour_path) if source.has("colour_path") else path

func _role_record(paths:Dictionary,cpu:Dictionary)->Dictionary:
    var roles:Dictionary={}
    for path in paths:roles[path]=[Catalog.media_path(path),int(cpu.has(path)),0,0]
    return {"roles":roles}

func _descriptor(path:String,slot:String)->Dictionary:
    var source:Dictionary=_geometry(path,slot)
    var companions:Dictionary={};var normals:Dictionary={};var optical:Dictionary={};var sockets:Dictionary={}
    if not source.is_empty():
        var root:String=_root(source)
        for file in source.files.values():companions[root.path_join(file)]=true
        if source.has("normal_profiles"):
            for profile in ["original","gentle","reference"]:normals[profile]=root.path_join(source.normal_profiles[profile])
        else:
            var selected:Dictionary=profiles.records[path]
            normals.original=root.path_join(selected.original)
            var derived:String=ProjectSettings.get_setting("source_data/normal_profiles_root")
            for profile in ["gentle","reference"]:normals[profile]=derived.path_join(selected[profile])
        for file in normals.values():companions[file]=true
        if source.has("reference"):
            optical={"colour":path,"depth":root.path_join(source.files.depth),"support":root.path_join(source.files.support),
                "solid":root.path_join(source.reference).get_base_dir().path_join("solid-valid.png")}
            var identity:String=source.get("media",path)
            if identity.begins_with("/media/"):
                var file:String="res://.derived/surface-sockets/"+identity.trim_prefix("/media/").get_basename()+".json"
                if FileAccess.file_exists(file):
                    var baked:Dictionary=read(file)
                    sockets={"valid":true,"size":baked.size,"samples":baked.samples}
    var role_refs:Dictionary={}
    for profile in ["original","gentle","reference"]:
        var selected:Dictionary={path:true}
        for companion in companions:
            if companion not in normals.values() or companion==normals.get(profile):selected[companion]=true
        role_refs[profile]=_role_record(selected,{path:true})
    var native_paths:Dictionary={};var native_cpu:Dictionary={}
    for channel in optical:
        var file:String=optical[channel]
        if channel=="colour":continue
        if channel=="solid" or not sockets.get("valid",false):
            native_paths[file]=true
            if not sockets.get("valid",false):native_cpu[file]=true
    return {"path":path,"geometry":source,"companions":companions,
        "normal_paths":normals,"normal_sets":{} if normals.is_empty() else {path:normals},
        "optical_paths":optical,"sockets":sockets,"source_records":role_refs,
        "native_record":_role_record(native_paths,native_cpu)}

func _equipment(index:Resource)->void:
    var items:Dictionary=Catalog.read_file("items/index.json",cache)
    var visuals:Dictionary=Catalog.read_file(items.item_visuals,cache)
    var appearances:Dictionary=Catalog.read_file(items.item_appearances,cache)
    var roots:Dictionary={};var bindings:Dictionary={};var hand_layers:Dictionary={}
    for category in visuals.categories:
        if not roots.has(category.base_category):roots[category.base_category]=category
        for binding in category.factory_presentation_bindings:
            var key:Array=[binding.factory_identity,binding.equipment_slot]
            if not bindings.has(key):bindings[key]=[]
            if category not in bindings[key]:bindings[key].append(category)
    for hand in appearances.hands:
        var key:Array=[hand.category,hand.variant,hand.slot]
        if not hand_layers.has(key):hand_layers[key]=hand.layers
    for name in roots:
        var root:Dictionary=roots[name]
        if root.mechanical_factory_identity==null:continue
        for slot in ["weapon_melee_main","weapon_melee_off","weapon_ranged_main","weapon_ranged_off","helmet","body_armor","gauntlets","boots","cloak","backpack"]:
            var matches:Array=bindings.get([root.mechanical_factory_identity,slot],[])
            var variants:Dictionary={null:true}
            for category in matches:
                for variant in category.variants:variants[variant.visual_variant_id]=true
            for key in hand_layers:
                if key[0]==name and key[2]==slot:variants[key[1]]=true
            for variant_id in variants:
                var key:Array=[name,variant_id,slot]
                if hand_layers.has(key):index.equipment[key]=hand_layers[key];continue
                if matches.size()!=1:
                    index.equipment_errors[key]="No unique authored equipment binding "+name+"/"+slot;continue
                var category:Dictionary=matches[0]
                if variant_id==null:index.equipment[key]=category.base_presentation.equipment_layers;continue
                for variant in category.variants:
                    if variant.visual_variant_id==variant_id:index.equipment[key]=variant.equipment_layers;break

func run()->void:
    var start:int=Time.get_ticks_usec()
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--output="):output=argument.trim_prefix("--output=")
    var catalog:Dictionary=Catalog.read_file("catalog-index.json",cache)
    var rigs:Dictionary=Catalog.read_file(catalog.rigs,cache)
    var resources:Dictionary=Catalog.read_file(catalog.resources,cache)
    var components:Dictionary=Catalog.read_file(catalog.sheet_components,cache)
    geometry=read("res://generated/character_geometry.json")
    creatures=read("res://generated/creature_geometry.json")
    profiles=read("res://generated/normal_profiles.json")
    var index=Index.new()
    index.revision="%d-%d"%[int(Time.get_unix_time_from_system()),Time.get_ticks_usec()]
    index.root_rig=Catalog.read_file(catalog.root_rig,cache)
    index.creature_rigs=Catalog.read_file(catalog.creature_rigs,cache)
    var directory:String=output.path_join(index.revision)
    DirAccess.make_dir_recursive_absolute(directory)
    _equipment(index)
    var layers:int=0;var descriptors:int=0
    for rig_id in rigs:
        var rig:Dictionary=rigs[rig_id]
        var imported:Dictionary=rig.duplicate(true)
        imported.generated_shadow=true
        index.layers[rig_id]={}
        var categories:Dictionary={}
        for slot in rig.slot_order:
            for category in rig.slot_categories[slot]:
                if not categories.has(category):categories[category]=[]
                categories[category].append(slot)
        for category in categories:
            var resource=Layer.new();resource.rig_id=rig_id;resource.category=category
            var path:String=directory.path_join(rig_id+"--"+category+".res")
            for clip in rig.clips:
                var source_sheet:String=rig.clips[clip].sheets.get(category,"")
                if source_sheet.is_empty():continue
                resource.clips[clip]={}
                for slot in categories[category]:
                    var raw:String=resources[source_sheet]
                    var colour:String=_display(raw,slot,components)
                    var descriptor:Dictionary=_descriptor(colour,slot)
                    for profile in descriptor.source_records:descriptor.source_records[profile].source_id=StringName(path+"::"+clip+"/"+slot+"/"+profile)
                    descriptor.native_record.source_id=StringName(path+"::"+clip+"/"+slot+"/native")
                    resource.clips[clip][slot]=descriptor;descriptors+=1
                    if slot=="body" and descriptor.geometry.get("optical_ground_pixels")==null:imported.generated_shadow=false
                    var all:Dictionary={colour:true};all.merge(descriptor.companions)
                    for value in descriptor.optical_paths.values():all[value]=true
                    for file in all:
                        resource.headers[file]=_header(file)
                        if not index.source_owners.has(file):index.source_owners[file]=[path,clip]
                    if not index.source_owners.has(raw):index.source_owners[raw]=[path,clip]
                    if not index.sheets.has(source_sheet):index.sheets[source_sheet]={}
                    index.sheets[source_sheet][slot]=colour
                    index.sheets[source_sheet].default=raw
            var saved:int=ResourceSaver.save(resource,path)
            if saved!=OK:errors.append("Cannot save body layer: "+path)
            index.layers[rig_id][category]=path;layers+=1
        index.rigs[rig_id]=imported
    # Preserve explicit sprite/noise sourceSheet references outside body rigs.
    # They remain passive original PNGs, each with its own physical descriptor.
    var loose:int=0
    for sheet in resources:
        if index.sheets.has(sheet):continue
        var colour:String=resources[sheet]
        index.sheets[sheet]={"default":colour}
        if not colour.to_lower().ends_with(".png") or index.source_owners.has(colour):continue
        var resource=Layer.new();resource.category=sheet
        var descriptor:Dictionary=_descriptor(colour,"accent")
        var path:String=directory.path_join("accent--%04d.res"%loose)
        for profile in descriptor.source_records:descriptor.source_records[profile].source_id=StringName(path+"/"+profile)
        descriptor.native_record.source_id=StringName(path+"/native")
        resource.clips={"source":{"*":descriptor}};resource.headers[colour]=_header(colour)
        if ResourceSaver.save(resource,path)!=OK:errors.append("Cannot save sprite accent: "+sheet)
        index.source_owners[colour]=[path,"source"];loose+=1
    if not errors.is_empty():printerr(errors);quit(1);return
    var target:String=directory.path_join("index.res")
    if ResourceSaver.save(index,target)!=OK:printerr("Cannot save body index");quit(1);return
    # Existing admitted revisions keep their physical Resource paths. Publish
    # only the new selector, after every immutable metadata file is complete.
    var staged:String=output.path_join("current.next")
    var marker=FileAccess.open(staged,FileAccess.WRITE)
    if marker==null:printerr("Cannot stage body source selector");quit(1);return
    marker.store_string(target+"\n");marker.close()
    var replaced:int=DirAccess.rename_absolute(staged,output.path_join("current"))
    if replaced!=OK:printerr("Cannot publish body source selector: ",replaced);quit(1);return
    var report:Dictionary={"revision":index.revision,"layers":layers,"descriptors":descriptors,
        "source_paths":index.source_owners.size(),"headers":headers.size(),"loose_pngs":loose,"elapsed_ms":(Time.get_ticks_usec()-start)/1000.0}
    FileAccess.open(output.path_join("import.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("BODY_SOURCE_IMPORT ",JSON.stringify(report));quit()
