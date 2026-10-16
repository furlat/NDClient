extends SceneTree
# Numeric source geometry and buffer transforms have independent placement
# expectations; no renderer, atlas, resource load or image comparison is needed.
const Ground = preload("res://presentation/ground_data.gd")
const Placement = preload("res://placement.gd")
var checks = 0
var failures: Array = []
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures.append(label); print("GROUND_GEOMETRY_FAIL ",label)
func row(id: String, x: int, z: int = 0, elevation: int = 0) -> Dictionary:
    return {"id":id,"kind":"terrain","material":"stone","position":[x,z],"base_height_steps":elevation}
func _initialize() -> void:
    var receiver = AABB(Vector3(-.5,-.5,0),Vector3(1,1,.1))
    for size in [64,8192]:
        var rows: Array = []
        for i in size: rows.append(row(str(i),i))
        var geometry = Ground.capture_geometry(rows,receiver,0,Basis.IDENTITY)
        var before = var_to_bytes(geometry)
        var moved = row("0",-1,1,2) # Same projected Y, new contact/elevation.
        var patch = Ground.prepare_changes({"0":moved},[],geometry)
        check(not patch.rebuild_required and patch.changed==["0"] and patch.records.size()==1,"One-row same-membership geometry patch at size "+str(size))
        check(var_to_bytes(geometry)==before,"Discarded candidate leaves geometry base unchanged at size "+str(size))
        check(patch.records["0"].transform.origin==Vector3(-1,2*Placement.HEIGHT_UNIT,1),"Prepared contact matches explicit source coordinates")
        var array: Array = geometry.rows
        var unrelated: Dictionary = geometry.records["1"]
        Ground.apply_geometry(geometry,patch)
        check(is_same(array,geometry.rows) and is_same(unrelated,geometry.records["1"]),"Sparse adoption preserves array and unrelated geometry ownership")
        check(geometry.bounds.encloses(patch.records["0"].bounds),"Conservative batch bounds contain the moved receiver")
        check(Ground.prepare_changes({"0":row("0",size+2)},[],geometry).rebuild_required,"Crossing sort neighbors requests an explicit batch rebuild")
        check(Ground.prepare_changes({"new":row("new",0)},[],geometry).rebuild_required,"Adding membership requests batch rebuild")
        check(Ground.prepare_changes({},["1"],geometry).rebuild_required,"Removing membership requests batch rebuild")
        check(Ground.prepare_changes({},[],geometry,true).rebuild_required,"Equal-valued membership reorder requests batch rebuild")
    var ties: Array = []
    for i in 40: ties.append(row("tie-"+str(i),i,-i))
    var tied = Ground.capture_geometry(ties,receiver,0,Basis.IDENTITY)
    check(tied.rows==ties,"Forty equal-Y rows retain exact source insertion order")
    var original = [row("a",0),row("b",1),row("c",2)]
    var geometry = Ground.capture_geometry(original,receiver,0,Basis.IDENTITY)
    var reordered = Ground.prepare_changes({"a":row("a",3),"c":row("c",0)},[],geometry)
    check(reordered.rebuild_required,"Multiple changed neighbors use the candidate geometry together")
    var mutable_packet = {"row":original[0],"data":PackedFloat32Array([1,0,0,0,0,1,0,0,0,0,1,0,1,1,1,1,0,999,888,777]),"y":12345.0}
    var old = {"packets":{"a":mutable_packet},"receiver_bounds":receiver,"capacity":256,"ground_version":4,"address_token":[1,2,3,4]}
    var captured = Ground.capture_previous(old,0,Basis.IDENTITY)
    # Mutable packet values can change after capture without changing any input
    # the worker reads. The owner will merge current visibility/UV on publication.
    mutable_packet.data[17] = -100
    mutable_packet.y = -200
    var prepared = Ground.prepare(original,captured,0,Basis.IDENTITY,{"b":true})
    check(prepared.geometry_changes=={"base_version":4,"changed":["b","c"],"removed":[]},"Immutable capture compares source geometry, never mutable packet channels")
    check(prepared.address_token.is_empty(),"Fresh address bytes cannot inherit an earlier atlas proof")
    check(prepared.values==[0.0,1.0,0.0],"Explicit candidate visibility owns prepared custom channel")
    for i in original.size():
        var packet: PackedFloat32Array = prepared.packets[original[i].id].data
        check(packet[3]==i and packet[7]==0 and packet[11]==0,"Full buffer matches independent contact coordinates "+str(i))
        check(packet[17]==0 and packet[18]==0 and packet[19]==0,"Full preparation contains no borrowed atlas bytes "+str(i))
    print(JSON.stringify({"checks":checks,"failures":failures,"scope":"Sparse immutable floor geometry, stable equal-Y order, explicit affected-batch rebuild, placement transforms and no mutable packet borrowing. No GPU/frame timing claim."}))
    quit(0 if failures.is_empty() else 1)
