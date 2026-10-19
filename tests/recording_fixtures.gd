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
