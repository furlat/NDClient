extends SceneTree
const Characters = preload("res://presentation/characters.gd")
const Geometry = preload("res://presentation/character_geometry.gd")
const Media = preload("res://presentation/media_warmup.gd")
const Protocol = preload("res://sdk/protocol.gd")
var checks = 0
var failures: Array = []
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures.append(label); print("GEOMETRY_FAIL ",label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
    var parsed = Protocol.parse_json(FileAccess.get_file_as_bytes("res://.runtime/player-runs/20261011T223103.996259Z/state.json"))
    check(parsed.ok,"Actual equipped fighter and sorcerer state parses")
    if not parsed.ok: quit(1); return
    var state: Dictionary = parsed.value
    var cache = {}
    var index: Dictionary = Characters._read("catalog-index.json",cache)
    var rigs: Dictionary = Characters._read(index.rigs,cache)
    var rig: Dictionary = rigs["neuroclient.modular"]
    var sources = {}
    var outfits = []
    for actor in state.actors.values():
        var resolved = Characters.resolve(actor,state,cache)
        check(resolved.ok,"Existing equipped outfit resolves: "+actor.name)
        if not resolved.ok: continue
        var layers: Array = Characters.layers(resolved.value,rig,cache)
        outfits.append({"name":actor.name,"row":resolved.value,"layers":layers})
        var demanded: Dictionary = Characters.sheet_paths(actor,["Idle","Run","Attack1"],cache).value
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
                sources[path] = layer.slot
        var head = layers.filter(func(layer):return layer.slot=="head")
        var helmet = layers.filter(func(layer):return layer.slot=="helmet")
        check(head.size()==1 and helmet.size()==1,"Current head retention survives equipped helmet: "+actor.name)
    for category in ["Chest3","Chest7","Shield1","Shield5","NakedBody3"]:
        var slot = "chest" if category.begins_with("Chest") else "body" if category.begins_with("Naked") else "offhand"
        for clip in ["Idle","Run","Attack1"]:
            var path = "/media/smallscale/modular/"+category+"/"+clip+".png"
            check(not Geometry.record(path,slot,cache).is_empty(),"Delivered independent swap remains supported: "+path)
            sources[path] = slot
    check(Geometry.record("/media/not-a-delivered-sheet.png","body",cache).is_empty(),"Unknown source has clean flat fallback")
    check(Geometry.record("/media/smallscale/modular/NakedBody/Idle.png","effect",cache).is_empty(),"A valid body cannot be reassigned to an effect role")
    var resting = Media.plan(state,[],cache)
    check(resting.errors.is_empty() and resting.required.keys().all(func(path):return "/Idle/" in path or path.ends_with("/Idle.png")),"Initial demand only prepares actual rest, never the whole delivered library")
    var packet = {"sources":sources,"outfits":outfits,"checks":checks,"failures":failures}
    var output = FileAccess.open("res://generated/character_geometry_cases.json",FileAccess.WRITE)
    output.store_string(JSON.stringify(packet,"  ")); output.close()
    print("CHARACTER_GEOMETRY_CHECKS ",JSON.stringify({"checks":checks,"failures":failures,"numeric_sources":sources.size()}))
    quit(0 if failures.is_empty() else 1)
