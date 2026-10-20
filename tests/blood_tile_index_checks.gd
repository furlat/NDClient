extends SceneTree
const Fixtures=preload("res://tests/recording_fixtures.gd")
# Original recorded residue after-values versus exhaustive indexing. No new
# residue facts, GPU resources, live commands or alternate reducer path.
const Journal=preload("res://sdk/journal.gd")
const Compiler=preload("res://presentation/compiler.gd")
const Renderer=preload("res://presentation/blood_renderer.gd")
const Blood=preload("res://presentation/blood.gd")
var checks=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr("BLOOD_INDEX_FAIL ",label)
func expected(tiles:Dictionary)->Dictionary:
    var result={}
    for key in tiles:
        if not Blood.residue(tiles[key]).is_empty():result[key]=tiles[key]
    return result
func recorded(directory:String,sequence:int)->void:
    var journal=Journal.new()
    var opened=journal.open(directory,true,false)
    check(opened.ok,"Original recording opens")
    if not opened.ok:return
    var replayed=journal.replay(sequence-1)
    check(replayed.ok,"Original before-residue state replays")
    if not replayed.ok:return
    var before:Dictionary=journal.snapshot()
    var raw=FileAccess.get_file_as_bytes(directory.path_join("%016d.json"%sequence))
    var decoded=journal.protocol.decode("PlayerOperation",raw)
    check(decoded.ok,"Original operation validates")
    if not decoded.ok:return
    var admitted=journal._consume_admitted(decoded.value,raw,true)
    check(admitted.ok,"Original operation reduces")
    if not admitted.ok:return
    var compiled=Compiler.compile_recorded(before,admitted.normalized,{},journal.state,admitted.transitions)
    check(compiled.ok,"Original operation compiles")
    if not compiled.ok:return
    var renderer=Renderer.new()
    var display=before.duplicate(true)
    var revision=0
    renderer.sync_tiles(display.tiles,revision)
    check(renderer.tiles==expected(display.tiles),"Before-state index equals original canonical residues")
    for group in compiled.value.groups:
        for commit in group.commits:
            var delta:Dictionary=commit.delta
            Compiler.apply_delta(display,delta)
            var changed:Dictionary=delta.get("tiles",{})
            if changed.is_empty():continue
            var prior=revision;revision+=1
            renderer.sync_tiles(display.tiles,revision,{"base_revision":prior,"revision":revision,"full":false,"tiles":changed})
            check(renderer.tiles==expected(display.tiles),"Each actual deposit/light after-value matches exhaustive original indexing")
    check(display==journal.state,"No original actor/tile/event after-value was discarded")
    if sequence==3:
        check(renderer.tiles.size()==20,"Actual opportunity-hit deposit retains all twenty receiving cells")
        # Reuse those exact recorded before-values for a backward seek. This is
        # historical removal of presentation, not a fabricated cleaning effect.
        var changed={}
        for key in renderer.tiles:changed[key]=true;display.tiles[key]=before.tiles[key]
        var prior=revision;revision+=1
        renderer.sync_tiles(display.tiles,revision,{"base_revision":prior,"revision":revision,"full":false,"tiles":changed})
        check(renderer.tiles==expected(before.tiles),"Historical before-values remove every former deposit from sparse index")
    else:
        check(not renderer.tiles.is_empty(),"Late original encounter retains its real prior blood")
    var final_tiles:Dictionary=journal.state.tiles.duplicate(true)
    revision+=1
    renderer.sync_tiles(final_tiles,revision,{"base_revision":revision-1,"revision":revision,"full":false,"tiles":{}})
    check(renderer.tiles==expected(final_tiles),"New snapshot owner forces exact full index even with empty sparse keys")
    renderer.sync_tiles(before.tiles,0,{"base_revision":revision,"revision":0,"full":true,"tiles":{}})
    check(renderer.tiles==expected(before.tiles),"Backward/full seek restores exact original before index")
    before.tiles.clear();before.tiles.merge(final_tiles)
    renderer.sync_tiles(before.tiles,revision+3,{"base_revision":revision+2,"revision":revision+3,"full":false,"tiles":{}})
    check(renderer.tiles==expected(final_tiles),"Missed publication falls back to all real residue tiles")
    renderer.sync_tiles(before.tiles,revision+3)
    check(renderer.tiles==expected(final_tiles),"Repeated terminal sample preserves exact index")
func run()->void:
    recorded(Fixtures.journal("dash"),3)
    recorded(Fixtures.journal("gallery"),18)
    var report={"checks":checks,"failures":failures,"scope":"Real opportunity-hit deposit and late light-only operation; exact sparse index, historical deposit removal, snapshot/seek/missed-publication fallback. No GPU claim."}
    FileAccess.open("res://generated/blood_tile_index_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
