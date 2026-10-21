extends RefCounted
## Stable original schema16 journals. The catalog names actual recorded cases;
## no legacy wire adaptation, generated event facts or synthetic faction joins.
const Recording=preload("res://studio/recording.gd")
const CaseLibrary=preload("res://studio/case_library.gd")
const CATALOG="res://tests/fixtures/schema16/scenarios/catalog.json"
static func catalog()->Dictionary:
    return JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
static func case_record(id:String)->Dictionary:
    return catalog().get(id,{})
static func journal(id:String,seat:String="amber")->String:
    for perspective in case_record(id).get("perspectives",[]):
        if perspective.id==seat:return perspective.journal
    return ""
static func read(id:String,seat:String="amber")->Dictionary:
    return Recording.read(journal(id,seat))
## Current canonical state is folded from an explicit original journal, never a
## legacy-shaped state export or a reserialized presentation output.
static func canonical(directory:String,sequence:int=0)->Dictionary:
    var recorded=Recording.Journal.new()
    var opened:Dictionary=recorded.open(directory,true,false)
    if not opened.ok:return opened
    var restored:Dictionary=recorded.replay(sequence)
    return {"ok":true,"value":recorded.state} if restored.ok else restored

static func fact_rows(id:String,kind:String,seat:String="amber")->Array:
    var result:Array=[]
    var directory:String=journal(id,seat)
    var files:PackedStringArray=DirAccess.get_files_at(directory);files.sort()
    for file in files:
        if file.get_basename().length()!=16 or not file.get_basename().is_valid_int() or not file.ends_with(".json"):continue
        var packet:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(directory.path_join(file)))
        for lineage in packet.get("lineages",[]):
            for node in lineage.events:
                var fact:Variant=node.get("fact")
                if not node.get("canceled",false) and fact!=null and fact.get("kind")==kind:
                    result.append({"sequence":packet.cursor.sequence,"fact":fact,"node":node})
    return result

static func public_case(id:String)->Dictionary:
    # Build ordinary Studio library metadata around the unchanged originals.
    # No fact, state, cursor or event is generated here.
    var source:Dictionary=case_record(id)
    var value:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(source.scenario))
    value.engine=source.engine;value.status="recorded";value.errors=[];value.journals={}
    for view in source.perspectives:value.journals[view.id]=view.journal
    return CaseLibrary.records({"engine":source.engine,"cases":[value]},{"header":source.engine})[0]

## Exact current immutable producer originals; callers select a real copied
## case/seat explicitly. No historical fallback or wire normalization.
static func current_journal(id:String,seat:String="amber")->String:
    return "res://tests/fixtures/schema16/current-production-0c/"+id+"/"+seat

## Preserve a recorder's genuine failed original independently of any later
## successful refresh of the same legal scenario. Only metadata is assembled.
static func failed_original(directory:String)->Dictionary:
    var actual:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("recording.json")))
    if actual.get("ok",true) or str(actual.get("failure","")).is_empty():return {}
    var value:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("scenario.json")))
    value.engine=actual.engine;value.status="failed";value.reason=actual.failure
    value.errors=actual.get("errors",[]);value.scenario=directory.path_join("scenario.json")
    value.moments=actual.get("moments",[]);value.studio_checked=false;value.journals={}
    for seat in ["amber","blue"]:
        var path:String=directory.path_join(seat)
        if DirAccess.dir_exists_absolute(path.path_join("journal")):path=path.path_join("journal")
        value.journals[seat]=path
    var expected:Dictionary=CaseLibrary._read(CaseLibrary.SERVER_IDS).get("header",{})
    return CaseLibrary.records({"engine":actual.engine,"cases":[value]},{"header":expected})[0]
