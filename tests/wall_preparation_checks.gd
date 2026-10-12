extends SceneTree
# Passive worker geometry against exhaustive physical-member eligibility.
# Real source rows plus explicit support/height/member after-value fixtures.
const Reveal=preload("res://presentation/wall_reveal.gd")
const World=preload("res://presentation/world.gd")
const Journal=preload("res://sdk/journal.gd")
var checks=0
var failures=[]
var cases=[]
var cache={}
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);print("WALL_PREPARATION_FAIL ",label)
func verify(tiles:Dictionary,rows:Array,label:String)->void:
    var tiles_before=tiles.duplicate(true);var rows_before=rows.duplicate(true)
    var owners={}
    for source in rows:
        if source.kind not in ["wall","cliff"]:continue
        for member in source.get("wall_members",[source]):owners[member.id]=member
    for q in range(4):
        var task=WorkerThreadPool.add_task(func():worker_result=Reveal.prepare_geometry(tiles,rows,q))
        WorkerThreadPool.wait_for_task_completion(task)
        var geometry:Dictionary=worker_result
        var ids:Array=geometry.candidates.keys();ids.sort()
        var expected_ids:Array=owners.keys();expected_ids.sort()
        check(ids==expected_ids,label+" q%d every original wall/cliff member precomputed"%q)
        check(geometry.targets.size()==tiles.size(),label+" q%d exact prospective support set"%q)
        check(not geometry.has("visible") and not geometry.has("wall_mode"),label+" q%d geometry independent of mutable visibility/mode"%q)
        for id in owners:
            var expected=[]
            for cell in tiles:
                if Reveal.occludes(owners[id],tiles[cell],q):expected.append(cell)
            var actual:Array=geometry.candidates[id].targets.map(func(value):return value.cell)
            expected.sort();actual.sort()
            check(actual==expected,label+" q%d %s exhaustive finite-wall eligibility"%[q,id])
            var cached:Dictionary=geometry.candidates[id]
            Reveal.targets(owners[id],geometry,q)
            check(is_same(cached,geometry.candidates[id]),label+" q%d %s publication uses prepared candidate"%[q,id])
        check(tiles==tiles_before and rows==rows_before,label+" q%d worker leaves immutable source values untouched"%q)
    cases.append({"case":label,"tiles":tiles.size(),"members":owners.size(),"quarters":4})
var worker_result={}
func recording(path:String,sequence:int,label:String)->void:
    var journal=Journal.new();var opened=journal.open(path,true,false)
    check(opened.ok,label+" actual recorded protocol admitted")
    if not opened.ok:return
    var loaded=journal.replay(sequence)
    check(loaded.ok,label+" authoritative recorded prefix reduced")
    if not loaded.ok:return
    var derived=World.rows(journal.state,cache)
    check(derived.unresolved.is_empty(),label+" actual source rows resolve")
    verify(journal.state.tiles,derived.visual_rows,label)
func typed_boundaries()->void:
    var tiles={}
    for x in range(-3,4):
        for y in range(-3,4):tiles["%d,%d"%[x,y]]={"position":[x,y],"elevation_steps":0}
    var east={"id":"east","kind":"wall","position":[0,0],"boundaries":["east"],"base_height_steps":0,"top_height_steps":3}
    var south=east.duplicate(true);south.id="south";south.boundaries=["south"]
    var corner=east.duplicate(true);corner.id="corner";corner.wall_members=[east,south]
    var cliff=east.duplicate(true);cliff.id="cliff";cliff.kind="cliff";cliff.position=[1,0];cliff.base_height_steps=-2;cliff.top_height_steps=2
    var rows=[corner,cliff,{"kind":"terrain","id":"floor"}]
    verify(tiles,rows,"joined native members and finite cliff")
    var previous=Reveal.prepare_geometry(tiles,rows,0);var unchanged=previous.duplicate(true)
    var target_tiles=tiles.duplicate()
    target_tiles.erase("0,1")
    target_tiles["1,1"]={"position":[1,1],"elevation_steps":8}
    target_tiles["-1,-1"]={"position":[-1,-1],"elevation_steps":-3}
    target_tiles["4,0"]={"position":[4,0],"elevation_steps":1}
    verify(target_tiles,rows,"candidate staged support addition removal and elevation")
    check(previous==unchanged,"Later preparation never mutates an active prior geometry/bucket/candidate result")
    var shifted=east.duplicate(true);shifted.position=[2,0];shifted.top_height_steps=5
    verify(target_tiles,[shifted,cliff],"corner separates original member moves and other member removed")
    verify({},[],"initialization empty reset")
func _initialize()->void:
    recording("res://.runtime/player-runs/20261011T225557.695498Z/journal",0,"Crypt initial")
    recording("res://.runtime/gallery-route/journal",101,"Gallery terminal")
    typed_boundaries()
    var report={"checks":checks,"failures":failures,"cases":cases,
        "scope":"Pure existing-worker wall preparation using actual disclosed Crypt/Gallery rows plus named finite cliff, joined-member and staged support after-values; exhaustive occludes oracle all four quarters, source immutability, no runtime opacity/visibility policy in worker."}
    FileAccess.open("res://generated/wall_preparation_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("WALL_PREPARATION_CHECKS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
