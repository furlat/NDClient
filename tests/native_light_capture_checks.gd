extends SceneTree
## Sparse private prefix versus the independently frozen complete snapshot.
const Delta=preload("res://presentation/native_light_delta.gd")
const Full=preload("res://tests/native_light_capture_reference.gd")
const Ground=preload("res://presentation/ground_data.gd")
class Atlas extends RefCounted:
    var receiver_index={};var support_owners={};var source_groups={};var entry_specs={};var published_supports={}
    var receivers=[];var static_receivers=[];var groups={};var prepared_source_bindings={}
    var revision=1;var repack_count=0;var shelf_cursor=Vector3i(6000,3000,8)
    var viewport={"size":Vector2i(8192,4096)};var next_source_order=1;var delta_serial=1;var light_cap=1
    var MAX_SIZE=8192
    func _entry_info(entry:Dictionary)->Dictionary:return entry.info
    func _crop(entry:Dictionary,_world)->Dictionary:return entry.crop
    func floor_address_token(entry:Dictionary)->Array:return [get_instance_id(),repack_count,entry.node.get_instance_id(),entry.ground_version]
class World extends Node3D:
    var camera=Node3D.new()
var checks=0
var failures:Array=[]
var evidence:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("NATIVE_LIGHT_CAPTURE_FAIL ",label)
func fixture()->Dictionary:
    var world=World.new();root.add_child(world);world.add_child(world.camera)
    var atlas=Atlas.new()
    var node=MultiMeshInstance3D.new();node.multimesh=MultiMesh.new();node.multimesh.mesh=QuadMesh.new();world.add_child(node)
    var material=ShaderMaterial.new()
    var rows=[]
    for x in 25:
        for y in 25:rows.append({"id":"%d,%d"%[x,y],"kind":"terrain","material":"stone","position":[x,y],"base_height_steps":0})
    rows.append({"id":"shared-top","kind":"terrain","material":"stone","position":[0,0],"base_height_steps":2})
    var entry={"node":node,"material":material,"cell":Vector2(4,4),"placement":rows[0],"batch_rows":rows,"ground_indices":{},"ground_packets":{},"ground_buffer":PackedFloat32Array(),"ground_version":1,
        "info":{"dynamic":false,"shader":null,"water":false},"crop":{"pixels":Rect2i(0,0,4,4),"uv":Vector4(0,0,1,1)},"scenery_values":[]}
    var id:int=node.get_instance_id()
    var geometry=[node.global_transform,node.multimesh.mesh.size,node.multimesh.mesh.center_offset]
    var signature=[entry.cell,"",[],null,material.get_instance_id(),geometry]
    var group={"id":"ground","rank":0,"users":rows.size(),"material":material,"crop":entry.crop}
    atlas.groups.ground=group
    var source={"entry":entry,"signature":signature,"crop":entry.crop,"order":0,"receivers":{},"by_row":{},"packets":{},"ground_version":1}
    atlas.entry_specs[id]=source
    for i in rows.size():
        var row:Dictionary=rows[i];var row_id:String=row.id
        var position=Vector2i((i%100)*36+5,int(i/100)*36+2050)
        var high:int=int(position.x/1024)+8*int(position.y/1024)
        var data=PackedFloat32Array([1,0,0,row.position[0],0,1,0,row.base_height_steps,0,0,1,row.position[1],1,1,1,1,1,position.x%1024,position.y%1024,high])
        var packet={"row":row,"data":data,"bounds":AABB(Vector3.ZERO,Vector3.ONE),"y":float(row.position[1])}
        entry.ground_indices[row_id]=i;entry.ground_packets[row_id]=packet;entry.ground_buffer.append_array(data);entry.scenery_values.append(1.0)
        var receiver_id:String=str(id)+":"+row_id
        var spec={"id":receiver_id,"row":row,"row_id":row_id,"row_rank":i,"source_id":id,"info":entry.info,"crop":entry.crop,"entry":entry,"material_id":material.get_instance_id()}
        var receiver={"id":receiver_id,"row":row,"row_id":row_id,"index":i,"position":position,"crop":entry.crop,"spec":spec,"join_mask":0,"group":group}
        atlas.receiver_index[receiver_id]=receiver;atlas.receivers.append(receiver);atlas.static_receivers.append(receiver)
        source.receivers[row_id]=receiver;source.by_row[row_id]=spec;source.packets[row_id]=packet
        var cell=Vector2(row.position[0],row.position[1])
        if not atlas.support_owners.has(cell):atlas.support_owners[cell]={}
        atlas.support_owners[cell][receiver_id]=float(row.base_height_steps)
        atlas.published_supports[cell]=maxf(atlas.published_supports.get(cell,-INF),row.base_height_steps)
    for receiver in atlas.receivers:receiver.join_mask=Delta.GroundReceiving.mask(receiver.row,atlas.published_supports)
    return {"atlas":atlas,"world":world,"entry":entry}
func qualify(mode:String)->void:
    var fixture=fixture();var atlas=fixture.atlas;var world=fixture.world;var entry:Dictionary=fixture.entry
    var rows:Array=entry.batch_rows.duplicate()
    match mode:
        "two additions","missing proof":
            for y in [12,13]:rows.append({"id":"new-"+str(y),"kind":"terrain","material":"stone","position":[25,y],"base_height_steps":0})
        "elevation":
            var i:int=entry.ground_indices["12,12"];rows[i]=rows[i].duplicate();rows[i].base_height_steps=3
        "four neighbours":rows=rows.filter(func(row):return row.id!="12,12")
        "shared support":rows=rows.filter(func(row):return row.id!="shared-top")
        "moved":
            var i:int=entry.ground_indices["12,12"];rows[i]=rows[i].duplicate();rows[i].position=[26,26]
    var visibility={}
    for row in rows:visibility[row.id]=true
    var packet=Ground.prepare(rows,{"packets":entry.ground_packets,"receiver_bounds":AABB(Vector3.ZERO,Vector3.ONE),"capacity":768,"ground_version":1,"address_token":atlas.floor_address_token(entry)},0,Basis.IDENTITY,visibility)
    if mode=="missing proof":packet.address_token=[]
    var snapshot:Dictionary=entry.duplicate()
    snapshot.batch_rows=packet.rows;snapshot.ground_packets=packet.packets;snapshot.ground_indices=packet.indices;snapshot.ground_buffer=packet.buffer;snapshot.ground_version=2;snapshot.scenery_values=packet.values
    var prepared={"snapshot":snapshot,"version":0,"signature":atlas.entry_specs[entry.node.get_instance_id()].signature,"info":entry.info,
        "basis":Basis(world.camera.global_basis.x,-world.camera.global_basis.y,world.camera.global_basis.z).transposed(),"screen_size":world.get_viewport().get_visible_rect().size}
    var jobs=[{"entry":entry,"packet":packet,"rows":packet.geometry_changes.changed,"prepared":prepared}]
    var removed:Dictionary={}
    if mode=="source removal":jobs=[];removed[entry.node.get_instance_id()]=true
    var sparse:Dictionary=Delta.begin_candidate(atlas,jobs,removed,world)
    var full:Dictionary=Full.begin_candidate(atlas,jobs,removed,world)
    var turns=0
    while not Delta.capture_candidate(atlas,sparse,world):turns+=1
    var full_turns=0
    while not Full.capture_candidate(atlas,full,world):full_turns+=1
    check(not sparse.has("error") and not full.has("error"),mode+": both snapshots complete without errors")
    Delta.compute_candidate(sparse);Full.compute_candidate(full)
    check(sparse.get("complete",false) and full.get("complete",false),mode+": private plans complete")
    if sparse.get("complete",false) and full.get("complete",false):
        var plan:Dictionary=sparse.plan.duplicate();var expected:Dictionary=full.plan.duplicate()
        for field in ["specs_ms","reservations_ms"]:plan.erase(field);expected.erase(field)
        check(plan==expected,mode+": exact source/support/spec/reservation plan equals frozen full snapshot")
        check(sparse.removed==full.removed and sparse.removed.keys()==full.removed.keys(),mode+": exact removal order equals full snapshot")
        check(sparse.bind_ids==full.bind_ids and sparse.bulk_base_lists==full.bulk_base_lists,mode+": binding/list offsets unchanged")
        for id in sparse.floor_ids:
            check(sparse.source_patches[id].prepared_addresses==full.source_patches[id].prepared_addresses,mode+": complete floor buffer, packet bytes and changed row indices unchanged")
    check(sparse.capture_sparse==(mode!="missing proof"),mode+": address-proof fallback contract")
    if mode not in ["missing proof","source removal"]:check(sparse.passive.receiver_index.size()<30 and turns<full_turns/5,mode+": tiny changed closure avoids whole world capture")
    else:check(sparse.passive.receiver_index.size()==full.passive.receiver_index.size(),mode+": missing proof retains complete snapshot")
    evidence.append({"case":mode,"receivers":sparse.passive.receiver_index.size(),"full_receivers":full.passive.receiver_index.size(),"capture_steps":turns,"full_steps":full_turns})
    world.free()
func run()->void:
    for mode in ["two additions","elevation","four neighbours","shared support","moved","missing proof","source removal"]:qualify(mode)
    var stale_fixture=fixture()
    var stale=Delta.begin_candidate(stale_fixture.atlas,[],{},stale_fixture.world)
    stale_fixture.atlas.delta_serial+=1
    check(Delta.capture_candidate(stale_fixture.atlas,stale,stale_fixture.world) and stale.get("error")=="atlas_changed_during_capture","Changed admitted token rejects private prefix before worker publication")
    stale_fixture.world.free()
    var report={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Independent frozen full prefix; actual GroundData packet/address proof, elevation/movement/removal/shared and four-neighbour supports. No GPU/pixel or live-performance claim."}
    FileAccess.open("res://.runtime/native-light-capture-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_LIGHT_CAPTURE_CHECKS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
