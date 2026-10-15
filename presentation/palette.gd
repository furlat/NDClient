extends RefCounted
## Pygame spell_palette.py's delivered row treatment, resolved on the compiler worker.
const Catalog=preload("res://source_catalog.gd")

static func prepare(layer: Dictionary, rig: Dictionary, clip: String, cache: Dictionary) -> Dictionary:
    var result=layer.duplicate(true)
    var treatment: Dictionary=layer.get("palette",{}) if layer.get("palette")!=null else {}
    if treatment.is_empty(): return result
    var resources=Catalog.read_file("catalog/resources.json",cache)
    var sheet: String=layer.get("sourceSheet",rig.clips[clip].sheets.get(layer.category,""))
    if not resources.has(sheet): return result
    var path: String=resources[sheet]
    var key="__palette_ranges:"+path+":"+str(rig.cell_height)
    if not cache.has(key):
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
    var effect: Dictionary=layer.get("effect",{})
    var palette: Dictionary=effect.get("palette",{}) if effect.get("palette")!=null else {}
    material.set_shader_parameter("effect_palette_enabled",not palette.is_empty())
    if palette.is_empty(): return
    var colors=PackedVector3Array()
    for value in palette.colors: colors.append(rgb(int(value)))
    colors.resize(32)
    material.set_shader_parameter("effect_palette",colors)
    material.set_shader_parameter("effect_palette_count",mini(32,palette.colors.size()))
    material.set_shader_parameter("effect_range",effect.get("palette_ranges",{}).get(facing,Vector2(0,1)))
    material.set_shader_parameter("effect_gamma",palette.get("gamma",1.0))
    material.set_shader_parameter("effect_frame",frame)
    var noise=resources.get(palette.get("noiseSheet"),"")
    material.set_shader_parameter("effect_has_noise",textures.has(noise))
    if textures.has(noise): material.set_shader_parameter("effect_noise",textures[noise])
