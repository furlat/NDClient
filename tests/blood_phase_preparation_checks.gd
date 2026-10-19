extends SceneTree
const Fixtures=preload("res://tests/recording_fixtures.gd")
## Exact current residue versus real received future/overlapping release inputs.
## Filtering changes field invalidation only; the ordered kernel result is fixed.
const Protocol=preload("res://sdk/protocol.gd")
const Reducer=preload("res://sdk/reducer.gd")
const Compiler=preload("res://presentation/compiler.gd")
const Blood=preload("res://presentation/blood.gd")
var checks:int=0
var failures:Array=[]
var unaffected_fields:int=0
var affecting_fields:int=0
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("BLOOD_PHASE_FAIL ",label)
func _initialize()->void:run.call_deferred()
func run()->void:
    var directory:String=Fixtures.journal("gallery")+"/"
    var protocol=Protocol.new();var cache:Dictionary={};var history:Dictionary={}
    var first:Dictionary=protocol.decode("InitializationResponse",FileAccess.get_file_as_bytes(directory+"0000000000000000.json"))
    check(first.ok,"Actual Gallery initialization admits")
    if not first.ok:quit(1);return
    var initial:Dictionary=protocol.normalize("InitializationResponse",first.value)
    var state:Dictionary=Reducer.reduce_initialization(initial.initialization,initial.content_additions).value
    var sequences:Array=[]
    for file in DirAccess.get_files_at(directory):
        if file.ends_with(".json") and file.get_basename().length()==16 and file.get_basename().is_valid_int() and int(file.get_basename())>0:sequences.append(int(file.get_basename()))
    sequences.sort()
    for sequence in sequences:
        var decoded:Dictionary=protocol.decode("PlayerOperation",FileAccess.get_file_as_bytes(directory+"%016d.json"%sequence))
        check(decoded.ok,"Actual operation admits")
        if not decoded.ok:quit(1);return
        var packet:Dictionary=protocol.normalize("PlayerOperation",decoded.value)
        var reduced:Dictionary=Reducer._reduce_operation_retained(state,packet,true)
        check(reduced.ok,"Actual operation reduces")
        if not reduced.ok:quit(1);return
        var compiled:Dictionary=Compiler.compile_recorded(state,packet,cache,reduced.value,reduced.transitions)
        check(compiled.ok,"Actual operation compiles")
        if not compiled.ok:quit(1);return
        for group in compiled.value.groups:
            var fields:Dictionary={};var source:Dictionary={}
            for component in group.components:
                if component.kind!="residue_deposit":continue
                source=component.asset_metadata
                for reveal in component.reveals:
                    var row:Dictionary=reveal.duplicate();row.pattern=component.body_release.pattern;row.id=component.id
                    var key:String=Blood.key(reveal.position)
                    if not fields.has(key):fields[key]=[]
                    fields[key].append(row)
            for key in fields:
                var rows:Array=fields[key]
                var values:Array=[Blood.residue(state.tiles.get(key,{})),Blood.residue(reduced.value.tiles.get(key,{}))]
                for row in rows:values.append_array([row.before,row.after])
                for value in values:
                    if value.is_empty():continue
                    var effective:Array=rows.filter(func(row):return Blood.affects_residue(value,row,row.pattern,source))
                    if effective.is_empty():unaffected_fields+=1
                    else:affecting_fields+=1
                    var stacked:Array=rows.duplicate();stacked.append_array(history.get(key,[]))
                    for all_rows in [rows,stacked]:
                        for age in [-1.,0.,.3,.8,2.]:
                            var active:Array=[]
                            for row in all_rows:
                                var sampled:Dictionary=row.duplicate();sampled.age_seconds=age;active.append(sampled)
                            var filtered:Array=active.filter(func(row):return Blood.affects_residue(value,row,row.pattern,source))
                            var expected:Array=Blood.kernels(value,rows[0].position,active,source)
                            var actual:Array=Blood.kernels(value,rows[0].position,filtered,source)
                            check(actual==expected,"Exact before/after/stacked kernels "+str([sequence,key,age,all_rows.size()]))
                history[key]=rows
        state=reduced.value
    check(unaffected_fields>0 and affecting_fields>0,"Actual recordings exercise inert before-values and authoritative changed after-values")
    var report={"checks":checks,"failures":failures,"unaffected_fields":unaffected_fields,"affecting_fields":affecting_fields,
        "scope":"Exact ordered kernels from actual Gallery before/after residues, negative/landing/settled ages and stacked real release operands. No live latency or framebuffer claim."}
    FileAccess.open("res://.runtime/blood-phase-preparation-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("BLOOD_PHASE_CHECKS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
