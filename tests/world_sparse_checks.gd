extends SceneTree
# Actual admitted Gallery prefixes plus named renderer after-values; cache output
# must equal the uncached source adapter and subjective visibility on every case.
const World = preload("res://presentation/world.gd")
const Journal = preload("res://sdk/journal.gd")
const Reducer = preload("res://sdk/reducer.gd")
var checks = 0
var failures = []
var cache = {}
var retained = {}
var previous = {}
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok: failures.append(label); print("WORLD_SPARSE_FAIL ",label)
func compare(state:Dictionary,label:String)->void:
    var before=state.duplicate(true)
    var changes={"full":previous.is_empty(),"tiles":{},"objects":{},"senses":previous.get("senses")!=state.get("senses")}
    for field in ["tiles","objects"]:
        for id in state[field]:
            if not previous.get(field,{}).has(id) or not is_same(previous[field][id],state[field][id]):changes[field][id]=true
        for id in previous.get(field,{}):
            if not state[field].has(id):changes[field][id]=true
    var actual=World.update_rows(state,cache,retained,changes)
    previous=state
    check(actual==World.rows(state,cache),label+" original row/corner equality")
    var expected=World.visibility(state)
    var sparse=World.current_ids(state,retained.boundaries)
    check(sparse.keys().all(func(id):return expected.get(id,false)) and expected.keys().all(func(id):return bool(expected[id])==sparse.has(id)),label+" exact subjective grants")
    check(retained.boundaries==World.boundary_index(state),label+" exact live boundary index")
    check(state==before,label+" canonical after-values unchanged")
func _initialize()->void:
    var journal=Journal.new()
    var directory="res://.runtime/gallery-route/journal"
    var opened=journal.open(directory,true,false)
    check(opened.ok,"Original Gallery protocol selected explicitly")
    if not opened.ok:quit(1);return
    var state={};var count=0;var stages=0
    var files=DirAccess.get_files_at(directory);files.sort()
    for file in files:
        if not file.ends_with(".json") or file.length()!=21:continue
        var name="InitializationResponse" if count==0 else "PlayerOperation"
        var decoded=journal.protocol.decode(name,FileAccess.get_file_as_bytes(directory.path_join(file)))
        check(decoded.ok,"Admitted original wire "+file)
        if not decoded.ok:break
        var packet:Dictionary=journal.protocol.normalize(name,decoded.value)
        if count>0:
            for lineage in packet.lineages:
                var staged=Reducer.stage_lineage(state,lineage)
                check(staged.ok,"Real staged support input admitted")
                if staged.ok:compare(staged.value,"staged %s/%s"%[count,stages]);stages+=1
        var reduced=Reducer.reduce_initialization(packet.initialization,packet.content_additions) if count==0 else Reducer.reduce_operation(state,packet)
        check(reduced.ok,"Real reducer prefix "+str(count))
        if not reduced.ok:break
        state=reduced.value;compare(state,"prefix "+str(count));count+=1
    check(count==102,"Complete102packet original Gallery corpus")
    # A removed boundary and newly disclosed support preserve total record count.
    var altered=state.duplicate();altered.tiles=state.tiles.duplicate();altered.objects=state.objects.duplicate()
    var removed=""
    for id in state.objects:
        if state.objects[id].item.get("boundary_structure")!=null:removed=id;break
    check(not removed.is_empty(),"Native boundary available for equal-count removal fixture")
    if not removed.is_empty():
        altered.objects.erase(removed)
        var tile:Dictionary=state.tiles.values()[0].duplicate(true)
        tile.tile_uuid="renderer-fixture-admitted-support";tile.position=[1000,1000]
        altered.tiles["1000,1000"]=tile
        compare(altered,"remove boundary plus disclose one support")
    # Sight-only transitions retain exact original torch after-values.
    var torch=""
    for row in World.rows(state,cache).rows:
        if row.get("lit_animation","")!="":torch=row.id;break
    if torch.is_empty():
        for id in state.objects:
            if state.objects[id].item.get("is_lit",false):torch=id;break
    check(not torch.is_empty(),"Actual source-backed lit fixture exists")
    if not torch.is_empty():
        altered=state.duplicate();altered.senses=state.senses.duplicate(true)
        if not altered.senses.objects.has(torch):altered.senses.objects[torch]={}
        altered.senses.objects[torch].visual=false;compare(altered,"fixture sight lost")
        altered=altered.duplicate();altered.senses=altered.senses.duplicate(true)
        altered.senses.objects[torch].visual=true;compare(altered,"same fixture sight restored")
    var report={"checks":checks,"failures":failures,"packets":count,"staged_lineages":stages,"scope":"Dirty-identity Gallery SDK prefixes/staged support versus uncached source adapter; named equal-count boundary removal and fixture sight-only renderer cases."}
    var out=FileAccess.open("res://generated/world_sparse_checks.json",FileAccess.WRITE);out.store_string(JSON.stringify(report,"  "));out.close()
    print("WORLD_SPARSE_CHECKS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
