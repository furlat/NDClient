extends SceneTree
## Recorded gameplay visibility changes against the frozen full-sort update.
## Canonical Python replay checks remain the independent whole-state oracle.
const Cells=preload("res://sdk/fold_cells.gd")
const Audience=preload("res://sdk/audience.gd")
const Reducer=preload("res://sdk/reducer.gd")
const Journal=preload("res://sdk/journal.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
var checks:int=0
var failures:Array=[]
var cuts:Array=[]
var report_path:String="res://.runtime/performance-recovery-20261022/visible-delta.json"

func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("VISIBLE_DELTA_FAIL ",label)
func _initialize()->void:run.call_deferred()

static func reference(members:Dictionary,added:Array,removed:Array)->Array:
    # Exact pre-patch Audience.fold update; members is a private outer fork.
    for point in removed:members.erase(Cells.key(point))
    for point in added:members[Cells.key(point)]=point
    return Cells.sorted_points(members)

func collect(directory:String)->void:
    var journal=Journal.new();var opened:Dictionary=journal.open(directory,true,false)
    check(opened.ok,directory+": original protocol selected")
    if not opened.ok:return
    var state:Dictionary={};var context:Dictionary={};var sequence:int=0
    while FileAccess.file_exists(directory.path_join("%016d.json"%sequence)):
        var raw:PackedByteArray=FileAccess.get_file_as_bytes(directory.path_join("%016d.json"%sequence))
        var decoded:Dictionary=journal.decode_record(sequence,raw)
        check(decoded.ok,directory+": original record admits "+str(sequence))
        if not decoded.ok:return
        var packet:Dictionary=decoded.value
        var folded:Dictionary=Reducer.reduce_initialization(packet.initialization,packet.get("content_additions",[])) if sequence==0 else Reducer._reduce_operation_retained(state,packet,true,null,context)
        check(folded.ok,directory+": original record folds "+str(sequence))
        if not folded.ok:return
        if sequence>0:
            var before:Variant=state.senses
            for index in range(packet.lineages.size()):
                var lineage:Dictionary=packet.lineages[index]
                var values:Dictionary=Audience.composed_values(lineage.get("sensory_rows",{}))
                check(values.ok,directory+": actual group sensory rows compose")
                if not values.ok:return
                for at in range(lineage.events.size()):
                    var node:Dictionary=lineage.events[at];var fact:Variant=node.get("fact")
                    var captured:Dictionary=folded.transitions.lineages[index].events[at]
                    if fact!=null and fact.kind=="audience":fact=fact.get("sensory")
                    if fact!=null and fact.kind=="sensory" and not node.get("canceled",false):
                        var added:Dictionary=Cells.selected(values.value.cells,fact.get("visible_cells_added",{}))
                        var removed:Dictionary=Cells.selected(values.value.cells,fact.get("visible_cells_removed",{}))
                        check(added.ok and removed.ok,directory+": actual visible rows select")
                        if not added.ok or not removed.ok:return
                        if not added.value.is_empty() or not removed.value.is_empty():
                            var points:Array=Cells.mask_points(before.visible)
                            cuts.append({"label":directory+":"+str(sequence)+":"+str(node.occurrence),"points":points,"members":Cells.point_set(points),"added":added.value,"removed":removed.value,"expected":captured.delta.set.senses.visible})
                    if captured.delta.set.has("senses"):before=captured.delta.set.senses
        state=folded.value;context=folded.sensory_context;sequence+=1

func exact_cut(cut:Dictionary)->void:
    var frozen:PackedByteArray=var_to_bytes(cut)
    var expected_members:Dictionary=cut.members.duplicate()
    var expected:Array=reference(expected_members,cut.added,cut.removed)
    var members:Dictionary=cut.members.duplicate()
    var actual:Array=Cells.updated_points(cut.points,members,cut.added,cut.removed)
    check(actual==expected and members==expected_members,cut.label+": same exact ordered population and membership")
    check(Cells.mask(actual)==cut.expected,cut.label+": same original canonical visible mask")
    check(var_to_bytes(cut)==frozen,cut.label+": prior points, membership and original operands remain immutable")

func boundary_controls()->void:
    # Point-update contract controls reuse one original population; these are
    # not invented sensory packets or additional gameplay recordings.
    for cut in cuts:
        if cut.points.size()<32:continue
        var point:Array=cut.points[0]
        for changes in [[[],[point]],[[point,point],[point,point]],[cut.points,cut.points],[cut.points,[]]]:
            var members:Dictionary=cut.members.duplicate()
            var expected:Array=reference(members,changes[0],changes[1])
            exact_cut({"label":"point update control "+str(checks),"points":cut.points,"members":cut.members,"added":changes[0],"removed":changes[1],"expected":Cells.mask(expected)})
        break

func timed(candidate:bool)->int:
    var started:int=Time.get_ticks_usec()
    for cut in cuts:
        var members:Dictionary=cut.members.duplicate()
        var points:Array=Cells.updated_points(cut.points,members,cut.added,cut.removed) if candidate else reference(members,cut.added,cut.removed)
        Cells.mask(points)
    return Time.get_ticks_usec()-started

func run()->void:
    var directories:Array=[Fixtures.journal("gallery")]
    for case in ["door","oa-jump-late-lethal"]:
        for seat in ["amber","blue"]:directories.append(Fixtures.journal(case,seat))
    for mode in ["human","codex"]:
        for seat in ["amber","blue"]:directories.append("res://tests/fixtures/schema18/summon-control/"+mode+"/"+seat)
    for seat in ["amber","blue"]:directories.append("res://tests/fixtures/schema18/caster-defeat/"+seat)
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--recording="):directories.append(arg.trim_prefix("--recording="))
        elif arg.begins_with("--report="):report_path=arg.trim_prefix("--report=")
    for directory in directories:collect(str(directory))
    check(not cuts.is_empty(),"Actual gameplay originals contain visibility topology changes")
    boundary_controls()
    var populations:Array=[];var small:int=0
    for cut in cuts:
        exact_cut(cut)
        var delta:int=cut.added.size()+cut.removed.size()
        if delta*8<cut.points.size():small+=1
        populations.append({"source":cut.label,"before":cut.points.size(),"added":cut.added.size(),"removed":cut.removed.size()})
    var old_times:Array=[];var new_times:Array=[]
    for repeat in range(7):
        var old_us:int;var new_us:int
        if repeat%2==0:old_us=timed(false);new_us=timed(true)
        else:new_us=timed(true);old_us=timed(false)
        if repeat>0:old_times.append(old_us);new_times.append(new_us)
    old_times.sort();new_times.sort()
    var report:Dictionary={"checks":checks,"failures":failures,"actual_topology_cuts":cuts.size(),"small_delta_cuts":small,"bulk_cuts":cuts.size()-small,"populations":populations,
        "full_sort_samples_us":old_times,"candidate_samples_us":new_times,"full_sort_median_us":old_times[old_times.size()/2],"candidate_median_us":new_times[new_times.size()/2],
        "scope":"Exact original gameplay point populations and masks; timing includes the membership fork, ordered point update and visible-mask encoding. Excludes decoding, value columns, other reducer work, rendering and live latency. Copying/encoding still scales with the held population; this is not an O(delta) claim."}
    DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())
    FileAccess.open(report_path,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("VISIBLE_DELTA_CHECKS ",JSON.stringify({"checks":checks,"failures":failures,"actual_topology_cuts":cuts.size(),"small_delta_cuts":small,"full_sort_median_us":report.full_sort_median_us,"candidate_median_us":report.candidate_median_us,"report":report_path}))
    quit(0 if failures.is_empty() else 1)
