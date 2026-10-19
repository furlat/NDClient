extends SceneTree
## Original two-seat server journals, through the production fold/compiler.
const Library=preload("res://studio/case_library.gd")
const Journal=preload("res://sdk/journal.gd")
const Compiler=preload("res://presentation/compiler.gd")
const Occurrences=preload("res://presentation/occurrences.gd")
var checks:int=0
var failures:Array=[]
var evidence:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("CLASS_PROJECTION_FAIL "+label)
func run()->void:
    for id in ["action.class.cleric.preserve_life/recipients","action.class.barbarian.frenzy/lifecycle"]:
        var matching:Array=Library.read().filter(func(row):return row.id==id and row.ready)
        check(matching.size()==1,"Actual recorded case available: "+id)
        if matching.size()!=1:continue
        for seat in ["amber","blue"]:inspect_journal(id,seat,matching[0].journals[seat])
    print(JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
    quit(0 if failures.is_empty() else 1)
func inspect_journal(id:String,seat:String,directory:String)->void:
    var journal=Journal.new();var opened:Dictionary=journal.open(directory,true,false)
    check(opened.ok,id+" "+seat+": original journal opens")
    if not opened.ok:return
    var names:Array=[]
    for name in DirAccess.get_files_at(directory):
        if name.ends_with(".json") and name.get_basename().is_valid_int():names.append(name)
    names.sort()
    var cache:Dictionary={};var components:Array=[];var positive:Dictionary={};var missing_parent:bool=false
    var declarations:int=0;var applications:int=0
    for sequence in names.size():
        var raw:PackedByteArray=FileAccess.get_file_as_bytes(directory.path_join(names[sequence]))
        var decoded:Dictionary=journal.decode_record(sequence,raw)
        check(decoded.ok,id+" "+seat+": decode "+str(sequence))
        if not decoded.ok:break
        var before:Dictionary=journal.state
        var folded:Dictionary=journal._consume_admitted(decoded.value,raw,true)
        check(folded.ok,id+" "+seat+": fold "+str(sequence))
        if not folded.ok:break
        if sequence==0:continue
        for native in folded.normalized.lineages:
            for node in Occurrences.group(native).events:
                if node.canceled or node.fact==null:continue
                if node.fact.kind=="heal" and node.fact.actual_healing>0 and not node.fact.was_blocked:
                    positive[str(node.id)]={"target":node.fact.target_entity_uuid,"amount":node.fact.actual_healing}
                if node.fact.get("behavior_id")=="action.class.cleric.preserve_life":
                    if Occurrences.application(node):applications+=1
                    else:declarations+=1
        var compiled:Dictionary=Compiler.compile_recorded(before,folded.normalized,cache,journal.state,folded.transitions)
        check(compiled.ok,id+" "+seat+": production compile "+str(sequence))
        if not compiled.ok:break
        for group in compiled.value.groups:
            for row in group.components:
                if row.get("ability_id")=="action.class.cleric.preserve_life":components.append(row)
            for row in group.get("native_requirements",[]):
                if row.get("source_id")=="barbarian_frenzy_source_v176" and row.get("status")=="missing" and row.get("unbound_constructor_inputs",[])==["condition_parent_uuid"]:missing_parent=true
    if id.begins_with("action.class.cleric.preserve_life/"):
        var source:Array=components.filter(func(row):return row.native_cue.scope=="source")
        var recipients:Array=components.filter(func(row):return row.native_cue.scope=="recipient")
        check(declarations==1 and applications==3,id+" "+seat+": real server declaration/application distinction is exercised")
        check(source.size()==1,id+" "+seat+": exactly one source invocation")
        check(positive.size()==2 and recipients.size()==positive.size(),id+" "+seat+": exactly one receiver per positive committed heal")
        var seen:Dictionary={}
        for row in recipients:
            var occurrence:String=str(row.source_event_uuid)
            check(positive.has(occurrence) and not seen.has(occurrence),id+" "+seat+": receiver has a unique actual result occurrence")
            seen[occurrence]=true
            if not positive.has(occurrence):continue
            check(row.target_uuid==positive[occurrence].target and row.native_inputs.event_input.actual_healing==positive[occurrence].amount,id+" "+seat+": exact recipient and amount")
            check(row.native_constructor_inputs[0].values.recipient_entity_uuid==row.target_uuid,id+" "+seat+": actual recipient is present before construction")
        evidence.append({"case":id,"seat":seat,"declarations":declarations,"applications":applications,"positive_heals":positive,"source_cues":source.size(),"receiving_cues":recipients.size()})
    else:
        check(missing_parent,id+" "+seat+": real Frenzy keeps its exact missing-parent gap")
        evidence.append({"case":id,"seat":seat,"frenzy_parent_gap":missing_parent})
