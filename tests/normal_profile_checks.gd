extends SceneTree
const Geometry = preload("res://presentation/character_geometry.gd")
const Media = preload("res://presentation/media_warmup.gd")
const Characters = preload("res://presentation/characters.gd")
const Protocol = preload("res://sdk/protocol.gd")
var checks = 0
var failures: Array = []
var textures = {}
var loads: Array = []

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures.append(label); print("NORMAL_PROFILE_FAIL ",label)

func texture(path: String) -> Texture2D:
    loads.append(path)
    return textures.get(path)

func _initialize() -> void: run.call_deferred()

func run() -> void:
    var cache = {}
    var path = "/media/smallscale/modular/Head15/Idle.png"
    var source = Geometry.record(path,"helmet",cache)
    var before: Dictionary = source.duplicate(true)
    var profiles = Geometry.normal_paths(path,"helmet",cache)
    check(profiles.ok and profiles.value.keys()==["original","gentle","reference"],"Exact original media identity resolves three selectable normal sources")
    if not profiles.ok or profiles.value.is_empty(): quit(1); return
    var sources = Geometry.source_paths(path,"helmet",cache)
    check(sources.ok and sources.value.size()==6,"Only two derived normals extend original depth/normal/mask packet")
    check(cache[Geometry.PROFILE_TABLE].records.size()==3410 and cache[Geometry.PROFILE_TABLE].excluded.size()==478,"Complete delivery includes every eligible identity and explicit exclusions")
    check(Geometry.source_paths("/media/smallscale/modular/Effect1/Idle.png","effect",cache)=={"ok":true,"value":{}},"Excluded effects retain flat fallback without missing-profile failure")
    check(Geometry.source_paths("/media/not-modular.png","body",cache)=={"ok":true,"value":{}},"Other rigs acquire no invented normal profile")
    var broken: Dictionary = cache.duplicate()
    broken[Geometry.PROFILE_TABLE] = cache[Geometry.PROFILE_TABLE].duplicate()
    broken[Geometry.PROFILE_TABLE].records = cache[Geometry.PROFILE_TABLE].records.duplicate()
    broken[Geometry.PROFILE_TABLE].records[path] = profiles.value.duplicate()
    broken[Geometry.PROFILE_TABLE].records[path].original = source.files.normal
    broken[Geometry.PROFILE_TABLE].records[path].erase("reference")
    check(not Geometry.source_paths(path,"helmet",broken).ok,"Missing eligible treatment is an explicit preparation failure")
    var state: Dictionary = Protocol.parse_json(FileAccess.get_file_as_bytes("res://.runtime/player-runs/20261011T223103.996259Z/state.json")).value
    check(not Media.plan(state,[],broken).errors.is_empty(),"Eligible missing profile reaches the real outfit media gate")
    var planned = Media.plan(state,[],cache)
    check(planned.errors.is_empty() and profiles.value.values().all(func(p):return planned.required.has(p) and planned.gpu_only.has(p) and not planned.cpu_required.has(p)),
        "Real caster outfit admits all three current normal maps as GPU-only demand")
    var loader = Media.create()
    var wanted = {}
    for item in sources.value: wanted[item] = item
    Media.demand(loader,wanted,{}, {},sources.value,{})
    for i in range(wanted.size()):
        check(not Media.ready(loader,wanted),"Unuploaded required variant keeps exact packet unready "+str(i))
        var deadline = Time.get_ticks_msec()+20000
        var loaded = {}
        while loaded.is_empty() and Time.get_ticks_msec()<deadline:
            loaded = Media.poll(loader)
            if loaded.is_empty(): await process_frame
        check(loaded.has("image"),"Existing worker decodes delivered source without renderer I/O "+str(i))
        if not loaded.has("image"): Media.close(loader); quit(1); return
        textures[loaded.path] = ImageTexture.create_from_image(loaded.image)
        Media.published(loader,loaded)
    check(Media.ready(loader,wanted) and Media.release_cold_images(loader).size()==6,"Published variant packet is ready and every companion releases its CPU copy")
    var node = MeshInstance3D.new()
    node.mesh = QuadMesh.new()
    var material = ShaderMaterial.new()
    material.shader = load("res://modular.gdshader")
    var entry = {"material":material,"node":node,"placement":{"scale_x":1.0},"scale":1.0,"actor_layer":{"slot":"helmet"}}
    var original_bindings = {}
    for profile in ["original","gentle","reference","original"]:
        Geometry.bind(entry,path,cache,texture,true,true,profile)
        check(material.get_shader_parameter("component_normal")==textures[profiles.value[profile]],"Selected profile binds exact preuploaded normal texture: "+profile)
        var stable = {"depth":material.get_shader_parameter("component_depth"),"support":material.get_shader_parameter("component_support"),
            "valid":material.get_shader_parameter("component_normal_valid"),"range":material.get_shader_parameter("component_depth_range"),
            "origin":material.get_shader_parameter("component_reconstruction_origin"),"bounds":node.custom_aabb,"transform":node.transform}
        if original_bindings.is_empty(): original_bindings = stable
        else: check(stable==original_bindings,"Normal-only switch preserves registration/depth/masks/placement: "+profile)
    check(loads.all(func(p):return textures.has(p)) and loader.decoded==6 and loader.pending.is_empty(),"Profile switches use existing resident sources without new decode requests")
    check(source==before,"Original geometry registration remains unchanged")
    node.free(); Media.close(loader)
    var report = {"checks":checks,"failures":failures,"source":path,"eligible_sources":3410,"excluded_sources":478,
        "scope":"Headless original-profile mapping, actual source worker/readiness and material sampler binding; native receiving-light pixels owned by renderer integration."}
    FileAccess.open("res://generated/normal_profile_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print(JSON.stringify(report)); quit(0 if failures.is_empty() else 1)
