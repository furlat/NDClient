extends SceneTree
## Exact canonical value-row merge against the previous string-key codec.
const Cells=preload("res://sdk/fold_cells.gd")
const Audience=preload("res://sdk/audience.gd")
const Reducer=preload("res://sdk/reducer.gd")
const Protocol=preload("res://sdk/protocol.gd")
const Journal=preload("res://sdk/journal.gd")
const StrictJSON=preload("res://sdk/strict_json.gd")
var checks:int=0
var failures:Array=[]
var cuts:Array=[]
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);print("VALUES_MERGE_FAIL ",label)
func _initialize()->void:run.call_deferred()
func reference(prior:Dictionary,old:Array,points:Array,changed:Array,mask:Dictionary)->Dictionary:
    var held:Dictionary=Cells.values_map(prior,old)
    for row in changed:held[Cells.key(row.position)]=row.value
    return Cells.values(points,held,mask)
func capture(prior:Variant,after:Dictionary,fact:Dictionary,rows:Dictionary,label:String)->void:
    if prior==null:prior={"visible":Cells.EMPTY,"effective_light_levels":Cells.values([],{}),"hazardous_cells":Cells.values([],{})}
    var values:Dictionary=Audience.composed_values(rows)
    check(values.ok,label+": actual source sensory table composes")
    if not values.ok:return
    var cut:Dictionary={"label":label,"old":Cells.mask_points(prior.visible),"points":Cells.mask_points(after.visible),"mask":after.visible,"columns":[]}
    for pair in [["effective_light_levels","light_levels","effective_light_levels_changed"],["hazardous_cells","hazards","hazardous_cells_changed"]]:
        var selected:Dictionary=Cells.selected(values.value[pair[1]],fact.get(pair[2],{}))
        check(selected.ok,label+": actual changed value rows select")
        if not selected.ok:return
        check(prior[pair[0]].cells==prior.visible,label+": actual canonical value column uses prior visibility lattice")
        cut.columns.append({"prior":prior[pair[0]],"changed":selected.value,"expected":after[pair[0]]})
    cuts.append(cut)
func originals()->void:
    var directories:Array=["res://tests/fixtures/schema16/scenarios/gallery/amber"]
    for case in ["door","oa-jump-late-lethal"]:
        for seat in ["amber","blue"]:directories.append("res://tests/fixtures/schema16/scenarios/"+case+"/"+seat)
    for directory in directories:
        var journal:RefCounted=Journal.new()
        var opened:Dictionary=journal.open(str(directory),true,false)
        check(opened.ok,str(directory)+": original producer identity is explicitly selected")
        if not opened.ok:continue
        var protocol:RefCounted=journal.protocol
        var state:Dictionary={};var sequence:int=0
        while FileAccess.file_exists(str(directory).path_join("%016d.json"%sequence)):
            var raw:PackedByteArray=FileAccess.get_file_as_bytes(str(directory).path_join("%016d.json"%sequence))
            var decoded:Dictionary=protocol.decode_recorded("InitializationResponse" if sequence==0 else "PlayerOperation",raw)
            check(decoded.ok,str(directory)+": exact original strictly admits "+str(sequence))
            if not decoded.ok:break
            var packet:Dictionary=decoded.value
            var folded:Dictionary=Reducer.reduce_initialization(packet.initialization,packet.get("content_additions",[])) if sequence==0 else Reducer._reduce_operation_retained(state,packet,true)
            check(folded.ok,str(directory)+": exact native original folds "+str(sequence))
            if not folded.ok:break
            if sequence==0:
                var senses:Array=packet.initialization.nodes.filter(func(node):return node.get("fact")!=null and node.fact.kind=="sensory" and not node.get("canceled",false))
                check(senses.size()==1,str(directory)+": actual initialization has one sensory admission")
                if senses.size()==1:capture(null,folded.value.senses,senses[0].fact,packet.initialization.get("sensory_rows",{}),str(directory)+":0")
            else:
                var prior:Variant=state.senses
                for i in packet.lineages.size():
                    var lineage:Dictionary=packet.lineages[i];var events:Dictionary={}
                    for node in lineage.events:events[int(node.occurrence)]=node
                    for event in folded.transitions.lineages[i].events:
                        var source:Dictionary=events[event.occurrence]
                        if source.get("fact")!=null and source.fact.kind=="sensory" and not source.get("canceled",false):capture(prior,event.delta.set.senses,source.fact,lineage.get("sensory_rows",{}),str(directory)+":"+str(sequence)+":"+str(event.occurrence))
                        if event.delta.set.has("senses"):prior=event.delta.set.senses
            state=folded.value;sequence+=1
func actual_cases()->void:
    for cut in cuts:
        var indices:PackedInt64Array=Cells.value_indices(cut.old,cut.points)
        for column in cut.columns:
            var before:PackedByteArray=var_to_bytes([column.prior,cut.old,cut.points,column.changed,cut.mask])
            var expected:Dictionary=reference(column.prior,cut.old,cut.points,column.changed,cut.mask)
            var actual:Dictionary=Cells.reindexed_values(column.prior,cut.old.size(),cut.points,column.changed,cut.mask,indices)
            check(actual==expected and actual==column.expected,cut.label+": exact original canonical bytes match both old codec and actual produced after-value")
            check(var_to_bytes([column.prior,cut.old,cut.points,column.changed,cut.mask])==before,cut.label+": merge leaves all retained inputs immutable")
func differential_cases()->void:
    var rng:=RandomNumberGenerator.new();rng.seed=178601
    var origins:Array=[-9007199254740000,-2147483650,-7,0,2147483650,9007199254740000]
    for sample in range(384):
        var x0:int=origins[sample%origins.size()];var y0:int=origins[(sample/7)%origins.size()]
        var old:Array=[];var points:Array=[]
        for x in range(8):
            for y in range(8):
                if sample%11!=0 and rng.randi_range(0,3)>0:old.append([x0+x,y0+y])
                if sample%13!=0 and rng.randi_range(0,3)>0:points.append([x0+x-2,y0+y+2])
        var mask:Dictionary=Cells.mask(points);var indices:PackedInt64Array=Cells.value_indices(old,points)
        for column in range(2):
            var bytes:=PackedByteArray()
            for i in old.size():bytes.append(rng.randi_range(0,255))
            # The old codec ignores valid surplus source bytes.
            if sample%5==0:bytes.append_array(PackedByteArray([0,128,255]))
            var prior:Dictionary={"cells":Cells.mask(old),"values":Cells.encoded(bytes)}
            var changed:Array=[]
            for i in range(sample%17):
                var pool:Array=points if i%2==0 and not points.is_empty() else old
                var point:Array=pool[rng.randi_range(0,pool.size()-1)] if not pool.is_empty() else [x0+100,y0-100]
                changed.append({"position":point.duplicate(),"value":rng.randi_range(0,255)})
                if i%3==0:changed.append({"position":point.duplicate(),"value":255})
            changed.append({"position":[x0+100,y0-100],"value":17})
            var before:PackedByteArray=var_to_bytes([prior,old,points,changed,mask,indices])
            var expected:Dictionary=reference(prior,old,points,changed,mask)
            var actual:Dictionary=Cells.reindexed_values(prior,old.size(),points,changed,mask,indices)
            check(actual==expected,"differential "+str(sample)+"/"+str(column)+": exact bytes across full wire coordinates, all byte values, missing/new/removed cells, duplicates and outside patches")
            check(var_to_bytes([prior,old,points,changed,mask,indices])==before,"differential "+str(sample)+"/"+str(column)+": every retained input stays immutable")
            actual.values=""
            check(var_to_bytes([prior,old,points,changed,mask,indices])==before,"differential "+str(sample)+"/"+str(column)+": returned value dictionary is detached")
func fallback_cases()->void:
    var parsed:Dictionary=StrictJSON.new().parse(FileAccess.get_file_as_string("res://tests/fixtures/schema16/fold/v7_anchor_scalars_are_sent_when_they_change.json"))
    check(parsed.ok,"Frozen native sensory control parses without integer precision loss")
    if not parsed.ok:return
    var source:Dictionary=parsed.value.steps[0].expected.duplicate(true)
    var points:Array=Cells.mask_points(source.senses.visible)
    # Labelled canonical-store controls, not new wire observations. A legacy
    # nonmatching column lattice must still use the previous helper fallback.
    for field in ["effective_light_levels","hazardous_cells"]:
        source.senses[field]={"cells":Cells.mask([[0,0],[2,2]]),"values":Cells.encoded(PackedByteArray([3,17]))}
    var step:Dictionary=parsed.value.steps[1].input
    var values:Dictionary=Audience.composed_values(step.sensory_rows)
    var original:PackedByteArray=var_to_bytes(source)
    var folded:Dictionary=Audience.fold(Reducer.copy_target(source),step.fact,values.value)
    check(folded.ok,"Nonmatching column lattice uses the existing accepted helper path")
    if folded.ok:
        for field in ["effective_light_levels","hazardous_cells"]:
            check(folded.value.senses[field]==reference(source.senses[field],[],points,[],Cells.mask(points)),field+": nonmatching-mask fallback is byte-identical to old map codec")
    check(var_to_bytes(source)==original,"Nonmatching column fold preserves its retained canonical input")
    for field in ["effective_light_levels_changed","hazardous_cells_changed"]:
        var invalid:Dictionary=step.fact.duplicate(true);invalid[field]={"start":99,"bits":"AQ=="}
        var owned:Dictionary=Reducer.copy_target(source);var before:PackedByteArray=var_to_bytes(owned)
        var refused:Dictionary=Audience.fold(owned,invalid,values.value)
        check(not refused.ok and refused.error.message=="A row subset names a row outside its table",field+": malformed changed-row subset retains exact prior refusal")
        check(var_to_bytes(owned)==before,field+": malformed subset publishes no partial canonical values")
func benchmark()->Dictionary:
    var old_times:Array=[];var new_times:Array=[]
    for repeat in range(7):
        var started:int=Time.get_ticks_usec()
        for cut in cuts:
            for column in cut.columns:reference(column.prior,cut.old,cut.points,column.changed,cut.mask)
        var old_us:int=Time.get_ticks_usec()-started
        started=Time.get_ticks_usec()
        for cut in cuts:
            var indices:PackedInt64Array=Cells.value_indices(cut.old,cut.points)
            for column in cut.columns:Cells.reindexed_values(column.prior,cut.old.size(),cut.points,column.changed,cut.mask,indices)
        var new_us:int=Time.get_ticks_usec()-started
        if repeat>0:old_times.append(old_us);new_times.append(new_us)
    old_times.sort();new_times.sort()
    return {"actual_sensory_cuts":cuts.size(),"columns_per_cut":2,"old_median_us":old_times[old_times.size()/2],"candidate_median_us":new_times[new_times.size()/2],"old_samples_us":old_times,"candidate_samples_us":new_times,"scope":"Isolated CPU codec only, including shared row mapping and both columns; source rows/points already composed. No live latency or frame claim."}
func run()->void:
    originals();actual_cases();differential_cases();fallback_cases()
    var report:Dictionary={"checks":checks,"failures":failures,"differential_columns":768,"benchmark":benchmark(),
        "scope":"Exact previous canonical value codec and actual60original sensory cuts, shared linear row mapping, full int64-safe coordinate arrays, detached retained values, nonmatching-mask fallback and unchanged malformed-row refusal. No cache/state/framework, GPU output or live latency claim."}
    FileAccess.open("res://.runtime/schema16-values-merge.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("VALUES_MERGE ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
