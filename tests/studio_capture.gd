extends SceneTree
## Actual raw SDK prefix -> strict reduction -> shared presentation -> exact final state.
## No scene, transport, substitute events, rendered-pixel or animation-coverage claim.
const Journal = preload("res://sdk/journal.gd")
const Reducer = preload("res://sdk/reducer.gd")
const Compiler = preload("res://presentation/compiler.gd")
var checks := 0
var failures: Array = []

func check(value: bool, label: String) -> void:
    checks += 1
    if not value: failures.append(label); print("STUDIO_CAPTURE_FAIL ",label)

func _initialize() -> void:
    var directory := ""
    var output := ""
    var label := "Recorded Studio case"
    var case_name := ""
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--recording="): directory = argument.trim_prefix("--recording=")
        if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
        if argument.begins_with("--label="): label = argument.trim_prefix("--label=")
        if argument.begins_with("--case="): case_name = argument.trim_prefix("--case=")
    if directory.is_empty() or output.is_empty():
        print("Usage: --recording=<actual journal> --output=<private case.json> [--label=<label>]")
        quit(2); return
    var journal = Journal.new()
    var opened: Dictionary = journal.open(directory,false,false)
    check(opened.ok,"Current-protocol recording opens")
    if not opened.ok: quit(1); return
    var names: Array[String] = []
    var expression = RegEx.new()
    expression.compile("^[0-9]{16}\\.json$")
    for filename in DirAccess.get_files_at(directory):
        if expression.search(filename)!=null: names.append(filename)
    names.sort()
    check(names.size()>1,"Case includes initialization and a real operation")
    var cache := {}
    var display := {}
    var elapsed := 0.0
    var groups: Array = []
    var facts := {}
    var behaviors := {}
    var outcomes := {}
    var conditions: Array = []
    var recipients: Array = []
    var initial_conditions: Array = []
    var steps: Array = []
    var life: Array = []
    for sequence in names.size():
        check(names[sequence]=="%016d.json"%sequence,"Complete original prefix at "+str(sequence))
        var raw = FileAccess.get_file_as_bytes(directory.path_join(names[sequence]))
        var admitted = journal.protocol.decode("InitializationResponse" if sequence==0 else "PlayerOperation",raw)
        check(admitted.ok,"Strict current SDK admits sequence "+str(sequence))
        if not admitted.ok: break
        var packet: Dictionary = journal.protocol.normalize("InitializationResponse" if sequence==0 else "PlayerOperation",admitted.value)
        var replayed = journal.replay(sequence)
        check(replayed.ok,"Public journal replays prefix "+str(sequence))
        if not replayed.ok: break
        if sequence==0:
            display = journal.state.duplicate(true)
            for actor in display.actors.values():
                for condition in actor.get("conditions",[]): initial_conditions.append(condition)
            continue
        var captured = Reducer._reduce_operation_recorded(display,packet)
        check(captured.ok,"Recorded SDK fold accepts sequence "+str(sequence))
        if not captured.ok: break
        check(captured.value==journal.state,"Recorded and public journal states agree")
        var compiled = Compiler.compile_recorded(display,packet,cache,captured.value,captured.transitions)
        check(compiled.ok,"Shared production compiler accepts sequence "+str(sequence))
        if not compiled.ok: break
        for group in compiled.value.groups:
            check(int(group.operation_sequence)==sequence,"Compiled group retains original sequence")
            groups.append({"sequence":sequence,"group_id":group.id,"start_ms":elapsed,"end_ms":elapsed+group.duration_ms})
            elapsed += group.duration_ms
            for commit in group.commits: Compiler.apply_delta(display,commit.delta)
        check(display==journal.state,"All displayed commits equal canonical state at "+str(sequence))
        for lineage in packet.lineages:
            for node in lineage.events:
                if node.canceled or node.fact==null: continue
                var fact: Dictionary = node.fact
                facts[fact.kind] = int(facts.get(fact.kind,0))+1
                if fact.get("behavior_id")!=null:
                    behaviors[fact.behavior_id] = int(behaviors.get(fact.behavior_id,0))+1
                if fact.kind=="attack": outcomes[fact.attack_outcome] = int(outcomes.get(fact.attack_outcome,0))+1
                if fact.kind=="condition": conditions.append({"sequence":sequence,"event_uuid":node.uuid,"event_type":fact.event_type,"target":fact.target_entity_uuid,"condition":fact.condition})
                if fact.kind=="step": steps.append(fact)
                if fact.kind=="life": life.append(fact)
                if fact.kind=="spell" and fact.get("application")!=null:
                    recipients.append({"sequence":sequence,"event_uuid":node.uuid,"behavior":fact.behavior_id,"target":fact.target_entity_uuid,"application":fact.application})
    # These checks qualify recorded outcomes, never infer success from a committed receipt.
    var lifecycle_names = {"dash":"Dashing","dodge":"Dodging","disengage":"Disengaging","hide":"Hidden","rage":"Raging","hold_person":"Paralyzed"}
    if lifecycle_names.has(case_name):
        var name: String = lifecycle_names[case_name]
        for event_type in ["condition_application","condition_removal"]:
            check(conditions.any(func(row):return row.event_type==event_type and row.condition.name==name),name+" has actual "+event_type)
    if case_name in ["prone","poisoned"]:
        var name = "Prone" if case_name=="prone" else "Poisoned"
        check(initial_conditions.any(func(row):return row.name==name),name+" is already active in initialization")
        check(conditions.any(func(row):return row.event_type=="condition_removal" and row.condition.name==name),name+" has an actual removal")
    if case_name=="disengage":
        check(not steps.is_empty() and not behaviors.has("reaction.opportunity_attack"),"Disengaged movement commits without opportunity attack")
    if case_name=="dodge": check(outcomes.get("Miss",0)>0,"An actual missed attack exercises Dodge")
    if case_name=="action_economy":
        check(behaviors.get("action.attack",0)==2 and behaviors.get("action.feature.extra_attack",0)==2 and behaviors.get("action.class.fighter.action_surge",0)==1,"Attack/Extra Attack/Action Surge chain retains four distinct attacks")
    if case_name=="magic_missile":
        var applications = recipients.filter(func(row):return row.behavior=="spell.magic_missile")
        check(applications.size()==3,"Three actual Magic Missile applications remain distinct")
        if applications.size()==3:
            check(applications[0].target==applications[2].target and applications[0].target!=applications[1].target,"Magic Missile preserves actual A/B/A recipients")
    if case_name=="window":
        check(steps.size()==2 and steps[0].trajectory=="connector_transfer" and steps[1].trajectory=="connector_transfer" and steps[0].from_position==steps[1].to_position and steps[0].to_position==steps[1].from_position,"Actual window connector crosses both directions")
    if case_name=="window_break":
        check(facts.get("object_destroyed",0)==1 and steps.any(func(row):return row.trajectory=="connector_transfer"),"Actual insert destruction precedes admitted crossing")
    if case_name=="elevation": check(steps.any(func(row):return row.from_elevation_feet!=row.to_elevation_feet),"Movement commits real support-height changes")
    if case_name.begins_with("oa_"):
        check(behaviors.get("reaction.opportunity_attack",0)>0,"Actual movement triggers opportunity attack")
        if "lethal" in case_name: check(life.any(func(row):return row.new_state=="dead"),"Actual opportunity attack is lethal")
    if case_name=="condition_suppression":
        var changed=conditions.filter(func(row):return row.event_type=="condition_state_changed" and row.condition.name=="Mirror Image")
        check(changed.size()==2,"Real lifecycle probe captures suppression and restoration changes")
        if changed.size()==2:
            check(changed[0].condition.condition_uuid==changed[1].condition.condition_uuid,"Suppression keeps the original condition owner")
            check(not changed[0].condition.state.suppression_provider_uuids.is_empty() and changed[1].condition.state.suppression_provider_uuids.is_empty(),"Exact provider set enters then leaves the same active condition")
    if case_name=="condition_owners":
        var children=conditions.filter(func(row):return row.condition.name=="Paralyzed")
        var parents=conditions.filter(func(row):return row.condition.name in ["Hold Person","Hold Monster"] and row.event_type=="condition_removal")
        check(children.size()==2 and children[0].event_type=="condition_application" and children[1].event_type=="condition_removal","Shared Paralyzed child has one application and one final removal")
        if children.size()==2:check(children[0].condition.condition_uuid==children[1].condition.condition_uuid,"Shared child owner remains stable")
        check(parents.size()==2,"Both actual parent spell owners are removed")
        if parents.size()==2 and children.size()==2:
            check(parents[0].condition.name=="Hold Person" and parents[0].sequence<children[1].sequence and parents[1].sequence==children[1].sequence,"First parent drops while shared child remains until the final parent")
    var report = {"label":label,"recording":directory,"case":case_name,"tags":["actual-server","current-sdk"],
        "operation_prefix":{"first_sequence":0,"last_sequence":names.size()-1},
        "interval":{"start_ms":0,"end_ms":elapsed},"authoring_baseline":"Current tracked authoring; no outcome rewriting",
        "checks":checks,"failures":failures,"groups":groups,
        "observed":{"facts":facts,"behaviors":behaviors,"attack_outcomes":outcomes,
            "conditions":conditions,"initial_conditions":initial_conditions,"spell_applications":recipients,"steps":steps,"life":life},
        "qualification":"Canonical/compiled replay only. Observed outcomes qualify only themselves; visual/audio coverage and missing required outcomes remain separate.",
        "invocation":{"script":"res://tests/studio_capture.gd","arguments":Array(OS.get_cmdline_user_args())}}
    FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("STUDIO_CAPTURE ",JSON.stringify({"checks":checks,"failures":failures,"operations":names.size()-1,"duration_ms":elapsed,"output":output}))
    quit(0 if failures.is_empty() else 1)
