extends SceneTree
## Real restored Fireball after-values through the passive preparation worker.
const Recording=preload("res://studio/recording.gd")
const Cases=preload("res://studio/case_library.gd")
const Preparation=preload("res://presentation/world_preparation.gd")
class Probe extends "res://play.gd":
    func _ready()->void:
        set_process(false);set_process_unhandled_input(false);add_child(context_menu)
    func _process(_delta:float)->void:pass
var checks:int=0
var failures:Array=[]
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr("RESIDUE_PREPARATION_FAIL ",label)
func _initialize()->void:run.call_deferred()
func run()->void:
    var cases:Array=Cases.read().filter(func(row):return row.id=="spell.fireball/area")
    check(cases.size()==1 and cases[0].ready,"Real current Fireball case is available")
    if cases.size()!=1 or not cases[0].ready:await finish();return
    var index:Dictionary=Recording.read(cases[0].journals.amber)
    check(index.get("ok",false),"Actual Fireball original bytes compile")
    if not index.get("ok",false):await finish();return
    var timeline=Recording.restore(index,index.presentation_end_ms*.55)
    var shown:Dictionary=timeline.presentation_state()
    var canonical:Dictionary=timeline.state.tiles
    var expected:Dictionary={};var staged_residue:Array=[]
    for key in canonical:
        if Preparation.Blood.residue(canonical[key]).is_empty():continue
        expected[key]=canonical[key]
        if Preparation.Blood.residue(shown.tiles.get(key,{})).is_empty():staged_residue.append(key)
    check(not expected.is_empty(),"Seek owns actual server residue values")
    var source:Dictionary=Preparation.Catalog.source_snapshot(index.cache)
    var input:Dictionary={"state":shown,"canonical_tiles":canonical,"actor_state":timeline.state,
        "changes":{"full":true,"tiles":{},"objects":{},"senses":true,"order":[]},
        "cache":source,"retained":{},"ground":{},"quarter":0,"basis":Basis.IDENTITY,
        "environment_options":{"depth":true,"normals":true},"background":true,"global_rows":true,
        "visibility":{},"visible_cells":{},"initial":true,"world_changed":true}
    var output:Dictionary={}
    var task:int=WorkerThreadPool.add_task(Preparation.derive_static.bind(input,output))
    WorkerThreadPool.wait_for_task_completion(task)
    check(output.get("complete",false),"Actual restore world projects completely")
    if output.get("complete",false):
        var prepared:Dictionary=output.static_result
        check(prepared.blood_index.updates==expected,"Prepared index keeps exact canonical rows")
        check(prepared.blood_rows.size()==expected.size(),"Every indexed residue has its prepared field")
        for key in expected:
            check(prepared.blood_rows.has(key),"Canonical field prepared: "+key)
            if not prepared.blood_rows.has(key):continue
            var row:Dictionary=prepared.blood_rows[key]
            check(is_same(row.tile,expected[key]) and is_same(row.value,Preparation.Blood.residue(expected[key])),"Field operands borrow exact admitted value: "+key)
    var host=Probe.new();host.external_playback=true;root.add_child(host)
    host.install_playback(timeline)
    check(host.component_renderer.epoch==host.timeline.initialization_revision,"Fresh paused playback installs its component epoch before any world prepares")
    host.component_renderer.blood.tiles=expected
    host.component_renderer.ensure_epoch(host)
    check(is_same(host.component_renderer.blood.tiles,expected),"First sample cannot retire fields adopted for the installed epoch")
    host.queue_free();await process_frame
    print("RESIDUE_PREPARATION_OBSERVATION ",JSON.stringify({"canonical":expected.size(),"staged_without_residue":staged_residue}))
    await finish()
func finish()->void:
    await process_frame;await process_frame
    print("RESIDUE_PREPARATION ",JSON.stringify({"checks":checks,"failures":failures}))
    quit(0 if failures.is_empty() else 1)
