extends RefCounted
## Pygame spell_palette.py's delivered row treatment, resolved on the compiler worker.
## Per-facing luminance ranges are measured data (assets/measured/characters/
## palette_ranges.json, carried by the built body index); a sheet without a
## measurement is measured here the same way, once per catalog cache.
const Catalog=preload("res://source_catalog.gd")
const Sources=preload("res://presentation/body_sources.gd")

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
        var measured:Dictionary=admitted.palette_ranges.get(path,{}).get(str(int(rig.cell_height)),{})
        if not measured.is_empty():
            cache[key]=measured;result.palette_ranges=measured
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
