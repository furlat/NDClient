extends SceneTree
const Recording=preload("res://studio/recording.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
const Lighting=preload("res://presentation/lighting_2d.gd")
const Preparation=preload("res://presentation/world_preparation.gd")
class CountLighting extends "res://presentation/lighting_2d.gd":
    var constructors=0
    func _make_point(parent:Node,source:Dictionary)->PointLight2D:
        constructors+=1
        return super._make_point(parent,source)
var checks=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr(label)
func finish(lighting:RefCounted,work:Dictionary)->void:
    for step in 100:
        if work.complete:return
        lighting.prepare_step(work)
    check(false,"Bounded light preparation completes")
func cancel(work:Dictionary)->Array:
    # Exercise the real world candidate's retirement handoff. The retirement
    # consumer subsequently frees exactly these returned external nodes.
    var owner=Preparation.new();owner.light_preparation=work
    var held=owner.release_handles();owner.free()
    return held
func run()->void:
    var index=Fixtures.read("hide-light")
    check(index.ok,"Real optical-source recording admits")
    if not index.ok:quit(1);return
    var base=Lighting.resolve(index.initialization.state)
    check(not base.sources.is_empty(),"Real initial disclosure supplies an optical emitter")
    if base.sources.is_empty():quit(1);return
    var lighting=CountLighting.new()
    var first=Node2D.new();root.add_child(first);lighting.attach_page(first)
    lighting.sync(index.initialization.state)
    var old_id:String=base.sources[0].item_uuid
    var old:PointLight2D=lighting.nodes[old_id];old.enabled=true
    # Admission fixture: a second identity uses the exact disclosed optics.
    var added:Dictionary=base.sources[0].duplicate();added.item_uuid="candidate-emitter"
    var candidate_sources:Array=base.sources.duplicate();candidate_sources.append(added)
    var desired={"sources":candidate_sources,"issues":[]}
    var work=lighting.begin_preparation(desired);finish(lighting,work)
    check(lighting.preparation_valid(work),"Completed preparation validates its exact page owners")
    check(work.nodes.size()==1 and not work.nodes[0].node.enabled,"Candidate emitter remains disabled")
    check(lighting.nodes[old_id]==old and old.enabled and not lighting.nodes.has(added.item_uuid),"Preparation leaves current emitter and membership untouched")
    check(lighting.sources==base.sources,"Candidate sources are not disclosed before publication")
    var hidden:PointLight2D=work.nodes[0].node
    var second=Node2D.new();root.add_child(second);lighting.attach_page(second)
    var second_old:PointLight2D=lighting._pages[1].nodes[old_id]
    check(not lighting.preparation_valid(work),"New receiving page rejects the stale candidate before publication")
    check(lighting.sources==base.sources and not lighting._pages[1].nodes.has(added.item_uuid),"Rejected page base leaves displayed source membership unchanged")
    var released=cancel(work)
    check(released.size()==1 and released[0].node==hidden and released[0].retire_external,"Cancellation hands off only its private emitter")
    for entry in released:entry.node.free()
    check(is_instance_valid(old) and is_instance_valid(second_old) and old.enabled,"Cancelling one candidate preserves both displayed page owners")
    work=lighting.begin_preparation(desired);finish(lighting,work)
    check(lighting.preparation_valid(work) and work.nodes.size()==2,"Retry prepares the new emitter for every current receiving page")
    var adopted:Array=work.nodes.map(func(row):return row.node)
    var constructed:int=lighting.constructors
    lighting.publish_prepared(work)
    check(lighting.sources==candidate_sources and work.nodes.is_empty(),"Publication transfers sources and candidate ownership together")
    check(lighting.constructors==constructed and lighting.nodes[old_id]==old,"Publication constructs no stable or newly prepared emitter")
    check(lighting.nodes[added.item_uuid]==adopted[0] and lighting._pages[1].nodes[added.item_uuid]==adopted[1],"Publication adopts the exact prepared native nodes")
    lighting.publish_prepared(work)
    check(lighting.constructors==constructed and cancel(work).is_empty(),"Repeated adoption cannot construct or retire an adopted owner")
    var later=added.duplicate();later.item_uuid="cancelled-later-emitter"
    work=lighting.begin_preparation({"sources":candidate_sources+[later],"issues":[]});finish(lighting,work)
    released=cancel(work)
    check(released.size()==2 and released.all(func(entry):return entry.node not in adopted),"Later cancellation releases its own nodes on each page")
    for entry in released:entry.node.free()
    check(adopted.all(func(node):return is_instance_valid(node)),"Previously adopted emitters survive another candidate's cancellation")
    lighting.clear_pages();first.queue_free();second.queue_free();await process_frame
    print("LIGHT_PREPARATION_OWNERSHIP ",JSON.stringify({"checks":checks,"failures":failures,"scope":"Actual disclosed optics, hidden PointLight2D ownership, page-base preflight, transfer and real WorldPreparation retirement handoff. Headless; no rendered illumination claim."}))
    quit(0 if failures.is_empty() else 1)
