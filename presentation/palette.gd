extends RefCounted
## Pygame spell_palette.py's delivered row treatment, resolved on the compiler worker.
const Catalog=preload("res://source_catalog.gd")
const Sources=preload("res://presentation/body_sources.gd")

static func _stats_file(path:String,rig:Dictionary)->String:
    if not path.begins_with("/media/"):return ""
    return "res://.derived/palette-ranges/"+path.trim_prefix("/media/").get_basename()+"-"+str(int(rig.cell_height))+".json"

static func _source_stamp(path:String)->Dictionary:
    var absolute=Catalog.media_path(path)
    var file=FileAccess.open(absolute,FileAccess.READ)
    return {"mtime":FileAccess.get_modified_time(absolute),"size":file.get_length()} if file!=null else {}

static func _saved_ranges(file:String,stamp:Dictionary,rig:Dictionary)->Dictionary:
    if file.is_empty() or stamp.is_empty() or not FileAccess.file_exists(file):return {}
    var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(file))
    if not parsed is Dictionary or parsed.get("schema")!=1 \
            or int(parsed.get("source",{}).get("mtime",-1))!=stamp.mtime \
            or int(parsed.get("source",{}).get("size",-1))!=stamp.size \
            or parsed.get("facing_rows")!=rig.facing_rows or parsed.get("cell_height")!=rig.cell_height:return {}
    var ranges={}
    for facing in rig.facing_rows:
        var values:Variant=parsed.get("ranges",{}).get(facing)
        if not values is Array or values.size()!=2:return {}
        ranges[facing]=Vector2(values[0],values[1])
    return ranges

static func _save_ranges(file:String,stamp:Dictionary,rig:Dictionary,ranges:Dictionary,owner:int)->void:
    if file.is_empty() or stamp.is_empty():return
    var values={}
    for facing in ranges:values[facing]=[ranges[facing].x,ranges[facing].y]
    if DirAccess.make_dir_recursive_absolute(file.get_base_dir())!=OK:return
    # Each metadata worker owns its temporary file. Publishing exact small
    # operands atomically lets later workers/runs skip sheet decoding/sorting.
    var temporary=file+".%d.%d.tmp"%[OS.get_process_id(),owner]
    var output=FileAccess.open(temporary,FileAccess.WRITE)
    if output==null:return
    output.store_string(JSON.stringify({"schema":1,"source":stamp,"cell_height":rig.cell_height,
        "facing_rows":rig.facing_rows,"ranges":values}))
    output.close()
    if DirAccess.rename_absolute(temporary,file)!=OK:DirAccess.remove_absolute(temporary)

static func prepare(layer: Dictionary, rig: Dictionary, clip: String, cache: Dictionary) -> Dictionary:
    var result=layer.duplicate(true)
    var treatment: Dictionary=layer.get("palette",{}) if layer.get("palette")!=null else {}
    if treatment.is_empty(): return result
    var sheet: String=layer.get("sourceSheet",rig.clips[clip].sheets.get(layer.category,""))
    var admitted=Sources.index(cache)
    var path:String="" if admitted==null else admitted.sheets.get(sheet,{}).get("default","")
    if path.is_empty():return result
    var key="__palette_ranges:"+path+":"+str(rig.cell_height)
    if not cache.has(key):
        var file=_stats_file(path,rig)
        var stamp=_source_stamp(path) if not file.is_empty() else {}
        var saved=_saved_ranges(file,stamp,rig)
        if not saved.is_empty():
            cache[key]=saved;result.palette_ranges=saved
            return result
        var image=Image.load_from_file(Catalog.media_path(path))
        var ranges={}
        if image!=null and not image.is_empty():
            image.convert(Image.FORMAT_RGBA8)
            for facing in rig.facing_rows:
                var samples=PackedFloat32Array()
                var y0=int(rig.facing_rows[facing])*int(rig.cell_height)
                var row=image.get_region(Rect2i(0,y0,image.get_width(),int(rig.cell_height)))
                # Native bounds omit only transparent padding. Keep the exact
                # original alpha threshold, luminance samples and percentiles.
                var used=row.get_used_rect()
                if used.has_area():
                    var bytes:PackedByteArray=row.get_region(used).get_data()
                    for i in range(0,bytes.size(),4):
                        if bytes[i+3]>128: samples.append(bytes[i]*.2126+bytes[i+1]*.7152+bytes[i+2]*.0722)
                samples.sort()
                ranges[facing]=Vector2(_percentile(samples,.03),_percentile(samples,.98))/255.0
            _save_ranges(file,stamp,rig,ranges,image.get_instance_id())
        cache[key]=ranges
    result.palette_ranges=cache[key]
    return result

static func _percentile(values: PackedFloat32Array, fraction: float) -> float:
    if values.is_empty(): return 0.0
    var at=(values.size()-1)*fraction
    return lerpf(values[floori(at)],values[ceili(at)],at-floorf(at))

static func rgb(value: int) -> Vector3:
    return Vector3((value>>16)&255,(value>>8)&255,value&255)/255.0

static func bind(material: ShaderMaterial, layer: Dictionary, facing: String, frame: int, textures: Dictionary, resources: Dictionary) -> void:
    var values=parameters(layer,facing,frame,textures,resources)
    for name in values:material.set_shader_parameter(name,values[name])

static func parameters(layer: Dictionary, facing: String, frame: int, textures: Dictionary, resources: Dictionary) -> Dictionary:
    var result={}
    var effect: Dictionary=layer.get("effect",{})
    var palette: Dictionary=effect.get("palette",{}) if effect.get("palette")!=null else {}
    result["effect_palette_enabled"]=not palette.is_empty()
    if palette.is_empty(): return result
    var colors=PackedVector3Array()
    for value in palette.colors: colors.append(rgb(int(value)))
    colors.resize(32)
    result["effect_palette"]=colors
    result["effect_palette_count"]=mini(32,palette.colors.size())
    result["effect_range"]=effect.get("palette_ranges",{}).get(facing,Vector2(0,1))
    result["effect_gamma"]=palette.get("gamma",1.0)
    result["effect_frame"]=frame
    var noise=resources.get(palette.get("noiseSheet"),"")
    result["effect_has_noise"]=textures.has(noise)
    if textures.has(noise): result["effect_noise"]=textures[noise]

    return result
