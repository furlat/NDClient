extends SceneTree
const Preparation=preload("res://presentation/world_preparation.gd")
class Probe extends "res://play.gd":
    var uploads:Array=[]
    func _ready()->void:
        set_process(false);set_process_unhandled_input(false);add_child(context_menu)
        camera=Camera3D.new();add_child(camera)
    func _process(_delta:float)->void:pass
    func _ground_flush_visibility(entry:Dictionary,indices:Array)->void:
        uploads.append({"entry":entry,"indices":indices})

var checks:int=0
var failures:Array=[]
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("REVEAL_SCENERY_FAIL ",label)
func _initialize()->void:run.call_deferred()
func floor_entry(scene:Node,ids:Array)->Dictionary:
    var node=MeshInstance3D.new();node.mesh=QuadMesh.new();scene.add_child(node)
    var material=ShaderMaterial.new();material.shader=scene.ENVIRONMENT_SHADER;node.material_override=material
    var rows:Array=[];var indices:Dictionary={};var packets:Dictionary={};var values:Array=[]
    for i in ids.size():
        var row={"id":ids[i],"kind":"terrain","material":"stone","position":[i,0],"base_height_steps":0}
        rows.append(row);indices[ids[i]]=i;values.append(0.0)
        var data=PackedFloat32Array();data.resize(20);packets[ids[i]]={"data":data}
    return {"id":ids[0]+":0:terrain","placement":rows[0],"role":"terrain","layer":0,"node":node,
        "material":material,"batch_rows":rows,"ground_indices":indices,"ground_packets":packets,"scenery_values":values}
func delta(scene:Node,remove:Array,add:Array)->Dictionary:
    var prepared=Preparation.new();prepared.host=scene
    prepared.membership={"scenery":{"add":{},"remove":{},"new_consumers":{},"entry_add":[],"entry_remove":[]}}
    prepared._queue_scenery(remove,false);prepared._queue_scenery(add,true)
    while prepared.scenery_cursor<prepared.scenery_jobs.size():prepared._prepare_scenery_step()
    var result:Dictionary=prepared.membership.scenery;prepared.free();return result
func sight(scene:Node,current:Dictionary,changes:Dictionary)->void:
    scene.prepared_scenery={"visibility":current,"visible_cells":{},"base":scene.scenery_visibility,
        "changes":changes,"revision":scene.timeline.world_revision,"generation":scene.world_generation,
        "quarter":scene.world_quarter,"epoch":scene.timeline.initialization_revision}
    scene._sync_scenery()
func run()->void:
    var scene=Probe.new();root.add_child(scene)
    scene.timeline.state={"tiles":{},"objects":{},"senses":{"visible":[],"objects":{}}}
    scene.timeline.initialization_revision=1;scene.timeline.world_revision=1
    scene.world_quarter=0;scene.scenery_quarter=0;scene.world_generation=1;scene.scenery_generation=1
    var floor:Dictionary=floor_entry(scene,["a","b"])
    scene.static_entries=[floor];scene.scenery_index_count=1
    scene.world_prepare_epoch=scene.timeline.initialization_revision
    scene.world_visual_rows=floor.batch_rows;scene.world_row_cache={"visual_slots":{"a":0,"b":1}}
    scene.ground_groups={"stone":{"entries":[floor]}}
    var initial:Dictionary=delta(scene,[],[floor])
    check(scene.scenery_consumers.is_empty() and floor.scenery_values==[0.0,0.0],"Preparing consumer membership changes no displayed index or visibility")
    scene._publish_scenery_membership(initial)
    check(scene.scenery_consumers.is_empty() and scene.scenery_batches==[floor] and initial.add.is_empty(),"Floor target ownership stays in the existing canonical row/material/batch directories")
    check(initial.new_consumers.is_empty(),"Reindexing a prepared floor packet does not invent style changes for every row")
    sight(scene,{"b":true},{"b":true})
    check(floor.scenery_values==[0.0,1.0] and scene.uploads.size()==1 and scene.uploads[0].indices==[1],"Only the changed target's actual packed slot is written")
    scene.uploads=[]
    sight(scene,{"b":true},{})
    check(scene.uploads.is_empty(),"Unchanged prepared visibility emits no packed upload")
    var new_rows:Array=[{"id":"b","kind":"terrain","material":"stone","position":[1,0],"base_height_steps":0},
        {"id":"c","kind":"terrain","material":"stone","position":[2,0],"base_height_steps":0}]
    var replacement:Dictionary=delta(scene,[],[])
    check(scene._scenery_ground_entry("a")==floor and scene._scenery_ground_entry("c").is_empty(),"A prepared floor replacement leaves the old published row owner live")
    floor.batch_rows=new_rows;floor.ground_indices={"b":0,"c":1};floor.scenery_values=[1.0,0.0]
    var data=PackedFloat32Array();data.resize(20);floor.ground_packets={"b":{"data":data},"c":{"data":data.duplicate()}}
    scene.world_visual_rows=new_rows;scene.world_row_cache.visual_slots={"b":0,"c":1}
    scene._publish_scenery_membership(replacement)
    check(scene.scenery_consumers.is_empty() and scene.scenery_batches==[floor] and replacement.add.is_empty() and replacement.remove.is_empty(),"A retained floor replacement emits zero per-tile consumer adoption work")
    sight(scene,{"c":true},{"b":false,"c":true})
    check(floor.scenery_values==[0.0,1.0] and scene.uploads.size()==1 and scene.uploads[0].indices==[0,1],"Reordered packed rows use their newly published indices")
    var order=Preparation.Order.key(floor.placement,floor.role,floor.layer,0,true)
    floor.static_slot=0;floor.order_slot=0;floor.order_key=order
    var prepared=Preparation.new();prepared.host=scene;prepared.quarter=0
    prepared.result={"background":true,"needs_order":false}
    prepared.membership={"entry_replacements":{},"fixture_replacements":{},"slot_updates":[],"order_replacements":[],"representatives":{},"entries_changed":false}
    var row:Dictionary=floor.placement.duplicate();row.authoritative_residue=true
    prepared._collect_replacement({"entries":[floor]},{"entries":[floor]},row)
    check(not prepared.result.needs_order and not prepared.membership.entries_changed,"A metadata-only retained ground representative keeps the prepared total order")
    row=row.duplicate();row.base_height_steps=2
    prepared._collect_replacement({"entries":[floor]},{"entries":[floor]},row)
    check(prepared.result.needs_order and prepared.membership.entries_changed,"A real order-key change remains explicit preparation")
    prepared.free()
    var report={"checks":checks,"failures":failures,"scope":"Prepared direct scenery membership and packed visibility, private candidate isolation, removal/reordering and ground order-key ownership. No native pixel/performance claim."}
    FileAccess.open("res://generated/reveal_scenery_publication_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("REVEAL_SCENERY_PUBLICATION_CHECKS ",JSON.stringify(report))
    scene.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
