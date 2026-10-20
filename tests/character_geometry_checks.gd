extends SceneTree
const Characters = preload("res://presentation/characters.gd")
const Geometry = preload("res://presentation/character_geometry.gd")
const Media = preload("res://presentation/media_warmup.gd")
const Protocol = preload("res://sdk/protocol.gd")
const BodySources = preload("res://presentation/body_sources.gd")
var checks = 0
var failures: Array = []
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures.append(label); print("GEOMETRY_FAIL ",label)
func _initialize() -> void: run.call_deferred()
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
        var equipment:Dictionary=Media.Authoring.body("equipment",actor,{},cache).actor
        check(equipment.enabled and equipment.clip=="Taunt","Immediate equipment closure uses the actual authored Taunt, not all animations: "+actor.name)
        var closure:Dictionary=Characters.sheet_paths(actor,["Idle",equipment.clip],cache,looks)
        check(closure.ok,"Exact Idle plus equipment geometry closure resolves: "+actor.name)
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
    var resting = Media.plan(state,[],cache)
    check(resting.errors.is_empty() and resting.required==expected_rest,"Initial demand is exactly actual Idle plus immediate authored equipment geometry, never the whole library")
    check(var_to_bytes(state)==held,"Geometry/source preparation preserves original canonical actor/item state")
    var packet = {"sources":sources,"outfits":outfits,"checks":checks,"failures":failures,"state":state_path,"rest_required":resting.required.keys()}
    var output = FileAccess.open("res://generated/character_geometry_cases.json",FileAccess.WRITE)
    output.store_string(JSON.stringify(packet,"  ")); output.close()
    print("CHARACTER_GEOMETRY_CHECKS ",JSON.stringify({"checks":checks,"failures":failures,"numeric_sources":sources.size()}))
    quit(0 if failures.is_empty() else 1)
