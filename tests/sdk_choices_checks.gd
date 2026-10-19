extends SceneTree
# Named semantic cases mirror sdk/python/tests/test_choices.py; public admission
# and consumer lookups are the boundary, not a reconstruction of rich targets.
const Protocol = preload("res://sdk/protocol.gd")
const Choices = preload("res://sdk/choices.gd")
const UUID = "00000000-0000-4000-8000-000000000001"
const OTHER = "00000000-0000-4000-8000-000000000002"
var checks = 0
var failures: Array = []
var recording = ""
var protocol = Protocol.new()

static func action(index: int, target_set: int, target_type: String="multi_entity") -> Dictionary:
    return {"template_name":"Rule","behavior_id":"spell.rule","provided_by_id":"spell.rule",
        "target_type":target_type,"availability_status":"available","can_afford":true,"display_name":"Rule",
        "cost_type":"actions","discovery_index":index,"discovery_generation":1,"target_set":target_set}

static func discovery() -> Dictionary:
    var unavailable = action(3,3,"object")
    unavailable.availability_status = "source_unaffordable"; unavailable.can_afford = false
    return {"discovery_generation":1,"entity_uuid":UUID,
        "subjects":[{"uuid":UUID,"kind":"creature","name":"Hero"},{"uuid":OTHER,"kind":"object","name":"Wall"}],
        "positions":[[-2,3],[4,5]],"target_sets":[
            [{"kind":"subject","index":0,"subject":0,"position":0,"secondary_set":1},
             {"kind":"subject","index":1,"subject":1,"position":1,"secondary_set":2},
             {"kind":"subject","index":2,"subject":0,"secondary_set":3}],
            [{"kind":"subject","index":3,"subject":1}],
            [{"kind":"subject","index":3,"subject":0}],[],[{"kind":"self","index":0}],
            [{"kind":"subject","index":0,"subject":0},{"kind":"subject","index":1,"subject":1}]],
        "entity_actions":[action(0,0),action(1,5)],"self_actions":[action(2,4,"self")],"object_actions":[unavailable]}

static func envelope(choices: Dictionary) -> Dictionary:
    return {"game_id":"fixture","game_epoch":UUID,"audience_id":UUID,"kind":"choices",
        "state_revision":"r","correlation_id":UUID,"force_attack":false,"choices":choices}

# JSON numbers compare by exact numeric value, without inserting defaults or
# tolerances: native JSON stores integer tokens as Float64, strict JSON as int.
static func difference(a: Variant,b: Variant,path: String="$") -> String:
    if typeof(a) in [TYPE_INT,TYPE_FLOAT] and typeof(b) in [TYPE_INT,TYPE_FLOAT]:
        return "" if a==b else path+": "+str(a)+" != "+str(b)
    if typeof(a)!=typeof(b): return path+": types "+str(typeof(a))+" != "+str(typeof(b))
    if a is Dictionary:
        if a.size()!=b.size(): return path+": property count differs"
        for key in a:
            if not b.has(key): return path+": missing "+str(key)
            var issue=difference(a[key],b[key],path+"."+str(key))
            if not issue.is_empty(): return issue
        return ""
    if a is Array:
        if a.size()!=b.size(): return path+": array length differs"
        for i in a.size():
            var issue=difference(a[i],b[i],path+"["+str(i)+"]")
            if not issue.is_empty(): return issue
        return ""
    return "" if a==b else path+": values differ"

func check(value: bool, label: String) -> void:
    checks += 1
    if not value: failures.append(label); print("SDK_CHOICES_FAIL ",label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--choices="): recording=argument.trim_prefix("--choices=")
    var value = discovery()
    var before = value.duplicate(true)
    check(protocol.validate("PlayerChoices",value).ok,"Delivered compact fixture admits through public structural+reference validation")
    var rows = Choices.all_actions(value)
    check(rows.size()==4 and rows.map(func(row):return row.discovery_index)==[0,1,2,3],"Family concatenation preserves native discovery order")
    var primaries = Choices.action_options(value,rows[0])
    var left = Choices.secondary_options(value,rows[0],primaries[0])
    var right = Choices.secondary_options(value,rows[0],primaries[1])
    check(left[0].index==3 and right[0].index==3,"Secondary indices are scoped to their primary branches")
    check(Choices.binding_subject(value,left[0]).uuid==OTHER and Choices.binding_subject(value,right[0]).uuid==UUID,"Same secondary index may identify different branch subjects")
    check(Choices.secondary_options(value,rows[0],primaries[2]).is_empty(),"Explicit empty secondary set does not inherit")
    var repeated = Choices.action_options(value,rows[1])
    check(is_same(Choices.secondary_options(value,rows[1],repeated[0]),repeated),"Absent secondary reference borrows primary set")
    check(Choices.selection_for(rows[1],[repeated[0],repeated[1],repeated[0]]).target_indices==[0,1,0],"Ordered repetitions survive command construction")
    var self_option = Choices.action_options(value,rows[2])[0]
    check(Choices.binding_subject(value,self_option)==null and Choices.binding_position(value,self_option)==null,"Self binding fabricates no subject or coordinate")
    check(Choices.selection_for(rows[2],[self_option]).target_indices==[0],"Self native selection index zero is retained")
    check(Choices.action_options(value,rows[3]).is_empty(),"Unavailable action retains its empty set")
    for field in ["distance","path_cost","safe_path_cost","path","safe_path","extra_target_uuids","secondary_set","position"]:
        check(Choices.binding_value(self_option,field)==null,"Omitted nullable binding value: "+field)
    check(Choices.binding_value(self_option,"is_path_hazardous")==false,"Omitted path hazard is false")
    check(Choices.binding_value(self_option,"opportunity_attack_exposures")==[] and Choices.binding_value(self_option,"safe_path_opportunity_attack_exposures")==[],"Omitted exposure lists are empty")
    var inverse = Choices.position_eligibility(value)
    check(inverse.keys()==["-2,3","4,5"] and is_same(inverse["-2,3"][0].action,rows[0]) and is_same(inverse["-2,3"][0].binding,primaries[0]),"Inverse eligibility includes primary contact bindings only and borrows exact rows")
    check(value==before and is_same(Choices.action_options(value,rows[0]),value.target_sets[0]),"Lookups preserve wire structure and share the original set")
    var paths = value.duplicate(true)
    paths.target_sets[0][0].path=[0,1];paths.target_sets[0][0].safe_path=[]
    check(Choices.binding_path(paths,paths.target_sets[0][0])==[[-2,3],[4,5]],"Selected path resolves ordered position references")
    check(Choices.binding_path(paths,paths.target_sets[0][0],true)==[] and Choices.binding_path(paths,paths.target_sets[0][1])==null,"Explicit empty path differs from omitted path")
    var extras = [[9,-7]]
    var selection = Choices.selection_for(rows[1],repeated,extras,false)
    extras[0][0]=99
    check(selection.extra_target_positions==[[9,-7]] and not selection.prefer_safe,"Command copies supplied coordinates and retains route preference")
    var zero = {"discovery_generation":1,"entity_uuid":UUID,"target_sets":[[],[{"kind":"self","index":0,"secondary_set":0}]],"self_actions":[action(0,1,"self")]}
    check(protocol.validate("PlayerChoices",zero).ok and Choices.secondary_options(zero,zero.self_actions[0],zero.target_sets[1][0])==[],"Secondary set zero is an explicit empty set")
    for mutation in ["subject","position","path","exposure","secondary","target_set","duplicate","nested","collision","available_empty","unavailable_nonempty","source_affordable","other_unaffordable","duplicate_action","wrong_generation","wrong_ordinal"]:
        var bad = discovery()
        var primary: Dictionary = bad.target_sets[0][0]
        match mutation:
            "subject","position": primary[mutation]=999
            "path": primary.path=[999]
            "exposure": primary.opportunity_attack_exposures=[{"reactor_uuid":UUID,"reactor_name":"Hero","from_position":0,"to_position":999}]
            "secondary": primary.secondary_set=999
            "target_set": bad.entity_actions[0].target_set=999
            "duplicate": bad.target_sets[0].append(primary.duplicate())
            "nested": bad.target_sets[1][0].secondary_set=3
            "collision": bad.target_sets[1][0].index=0
            "available_empty": bad.entity_actions[0].target_set=3
            "unavailable_nonempty": bad.entity_actions[0].availability_status="no_valid_targets"
            "source_affordable": bad.object_actions[0].can_afford=true
            "other_unaffordable": bad.entity_actions[0].can_afford=false
            "duplicate_action": bad.self_actions[0].discovery_index=0
            "wrong_generation": bad.entity_actions[0].discovery_generation=2
            "wrong_ordinal": bad.entity_actions[0].discovery_index=5
        var snapshot = bad.duplicate(true)
        check(not protocol.validate("PlayerChoices",bad).ok,"Public choices rejects "+mutation)
        check(bad==snapshot,"Failed admission preserves input: "+mutation)
    for invalid in [true,"0",-1,0.5,9007199254740992]:
        var bad = discovery();bad.target_sets[0][0].subject=invalid
        check(not protocol.validate("PlayerChoices",bad).ok,"Public references are never coerced: "+str(invalid))
    var free_aim=discovery()
    free_aim.entity_actions[0].target_set=3
    free_aim.entity_actions[0].position_region={"range_feet":30}
    check(protocol.validate("PlayerChoices",free_aim).ok,"An available free-aim row legitimately has no enumerated target")
    free_aim.object_actions[0].position_region={"range_feet":30}
    check(protocol.validate("PlayerChoices",free_aim).ok,"Unavailable free-aim rows retain their authoritative source affordability")
    var aimed=Choices.selection_for(free_aim.entity_actions[0],[],[[6,7],[6,8]],false,5)
    check(aimed.target_indices==[] and aimed.extra_target_positions==[[6,7],[6,8]] and aimed.cast_at_level==5,"Free aim, ordered wall points and explicit upcast survive command construction")
    var preview = {"can_confirm":true,"subjects":[{"uuid":OTHER,"kind":"object"}],"positions":[[99,-7]],
        "target_sets":[[{"kind":"subject","index":3,"subject":0,"position":0}]],"next_target_set":0,"next_positions":[0],"area_preview":"computed"}
    check(protocol.validate("PlayerSelectionPreview",preview).ok,"Preview admits its independent domains")
    check(Choices.binding_position(preview,Choices.next_options(preview)[0])==[99,-7] and Choices.binding_subject(preview,Choices.next_options(preview)[0]).uuid==OTHER,"Preview reference zero resolves only within Preview")
    check(Choices.preview_positions(preview)==[[99,-7]] and Choices.preview_positions(preview,true)==[],"Computed empty affected area stays distinct from next positions")
    var deferred=preview.duplicate(true);deferred.area_preview="deferred"
    check(protocol.validate("PlayerSelectionPreview",deferred).ok and deferred.area_preview!=preview.area_preview,"Deferred is not a computed empty area")
    for field in ["next_target_set","next_positions","affected_positions"]:
        var bad=preview.duplicate(true);bad[field]=999 if field=="next_target_set" else [999]
        check(not protocol.validate("PlayerSelectionPreview",bad).ok,"Preview rejects own-domain invalid "+field)
    if not recording.is_empty():
        var raw = FileAccess.get_file_as_bytes(recording)
        var strict = protocol.decode("ChoicesResponse",raw)
        var trusted = protocol.decode_server_choices(raw)
        check(strict.ok and trusted.ok,"Actual compact server choices admit through both paths")
        if strict.ok and trusted.ok:
            var issue=difference(strict.value,trusted.value)
            check(issue.is_empty(),"Actual strict/native JSON values match without normalization or expansion: "+issue)
            var snapshot = trusted.value.duplicate(true)
            for row in Choices.all_actions(trusted.value.choices):
                for option in Choices.action_options(trusted.value.choices,row):
                    Choices.binding_subject(trusted.value.choices,option)
                    Choices.binding_position(trusted.value.choices,option)
                    Choices.binding_path(trusted.value.choices,option)
            check(snapshot==trusted.value,"Every actual primary lookup leaves sparse wire data unchanged")
    var report={"checks":checks,"failures":failures,"recording":recording,"scope":"Schema16 free aim/upcast, bounded public references and borrowed sparse lookups; independent native indices, secondary branches, repeats and Preview domains. No expanded target trees or gameplay simulation."}
    FileAccess.open("res://generated/sdk_choices_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
