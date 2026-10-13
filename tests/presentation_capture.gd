extends SceneTree
const Transport = preload("res://sdk/transport.gd")
const Journal = preload("res://sdk/journal.gd")
const JSONCodec = preload("res://sdk/strict_json.gd")
const Choices = preload("res://sdk/choices.gd")
var seats: Array = []
var issue := ""
var started := Time.get_ticks_msec()

func _init() -> void:
    _run.call_deferred()

func _process(_delta: float) -> bool:
    for seat in seats:
        for event in seat.transport.drain():
            if event.kind == "connected": seat.connected = event.result
            elif event.kind == "response": seat.responses[event.request_id] = event.result
            elif event.kind == "failure": issue = str(event.result)
            elif event.kind == "consumed": seat.consumed = event.value.cursor
    if Time.get_ticks_msec()-started > 150000: issue = "Capture deadline exceeded"
    return false

func request(seat: Dictionary, operation: String, arguments: Dictionary = {}) -> Dictionary:
    var id = seat.transport.request(operation,arguments)
    while not seat.responses.has(id) and issue.is_empty(): await process_frame
    if not issue.is_empty(): return {"ok":false,"error":{"message":issue}}
    var answer: Dictionary = seat.responses[id];seat.responses.erase(id)
    if not answer.ok: issue = operation+": "+str(answer)
    return answer

func consume(packet: Dictionary, raw: PackedByteArray, journal: RefCounted, path: String) -> Dictionary:
    var duplicate = not journal.cursor.is_empty() and packet.cursor.sequence <= journal.cursor.sequence
    var answer = journal.consume(packet,raw)
    if not answer.ok or duplicate: return answer
    var file = FileAccess.open(path.path_join("states/%016d.json" % packet.cursor.sequence),FileAccess.WRITE)
    file.store_string(JSON.stringify(journal.snapshot(),"",true,true));file.close()
    return answer

func uuid() -> String:
    var value = Crypto.new().generate_random_bytes(16).hex_encode()
    return "%s-%s-4%s-a%s-%s" % [value.substr(0,8),value.substr(8,4),value.substr(13,3),value.substr(17,3),value.substr(20,12)]

func _run() -> void:
    var config: Dictionary = JSONCodec.new().parse(FileAccess.get_file_as_string(OS.get_cmdline_user_args()[0])).value
    for credential in config.seats:
        var path: String = config.output.path_join(credential.id)
        DirAccess.make_dir_recursive_absolute(path.path_join("states"))
        var journal = Journal.new();var opened = journal.open(path.path_join("journal"))
        if not opened.ok: issue = str(opened);break
        var transport = Transport.new()
        var seat = {"id":credential.id,"path":path,"journal":journal,"transport":transport,"connected":null,"responses":{},"consumed":null}
        seats.append(seat)
        var connected = transport.start(config.url,credential.token,consume.bind(journal,path))
        if not connected.ok: issue = str(connected);break
        while seat.connected == null and issue.is_empty(): await process_frame
        if not issue.is_empty(): break
        var status: Dictionary = seat.connected.value.status
        while status.published_cursor == null and issue.is_empty():
            var response = await request(seat,"status")
            if response.ok: status = response.value.status
        if not issue.is_empty(): break
        await request(seat,"attach",{"acquisition_id":uuid(),"expected_attachment_epoch":status.attachment_epoch})
        await request(seat,"follow")
        while seat.consumed == null and issue.is_empty(): await process_frame
    var evidence = {"case":config.case,"facts":{},"opportunity_attacks":0,"uncommitted_steps":0,"life":[],"direct_arc_steps":0,"committed_steps":0,"canceled_nodes":0}
    if issue.is_empty():
        var seat: Dictionary = seats[0]
        var status_result = await request(seat,"status")
        if status_result.ok:
            var status: Dictionary = status_result.value.status
            var actor: String = status.boundary.input_actor_uuid
            var revision: String = status.boundary.state_revision
            var discovered = await request(seat,"choices",{"actor_uuid":actor,"state_revision":revision,"force_attack":false,"correlation_id":uuid()})
            if discovered.ok:
                var choices: Dictionary = discovered.value.choices
                var selected = {}
                for family in ["entity_actions","position_actions"]:
                    for row in choices[family]:
                        if row.behavior_id != config.behavior or not row.can_afford: continue
                        if config.behavior == "action.attack" and row.weapon_slot != "MELEE_MAIN": continue
                        for target in Choices.action_options(choices,row):
                            if config.behavior == "action.attack" or Choices.binding_position(choices,target) == config.target:
                                selected = {"action_index":row.discovery_index,"target_indices":[target.index],"extra_target_positions":[],"prefer_safe":false}
                                break
                        if not selected.is_empty(): break
                    if not selected.is_empty(): break
                if selected.is_empty(): issue = "Native discovery did not offer requested presentation action"
                else:
                    var preview = await request(seat,"preview",{"actor_uuid":actor,"state_revision":revision,
                        "discovery_generation":choices.discovery_generation,"correlation_id":uuid(),"selection":selected})
                    if preview.ok and preview.value.preview.can_confirm:
                        evidence.preview = preview.value.preview
                        var command = {"command_number":status.next_command_number,"actor_uuid":actor,"state_revision":revision,
                            "intent":{"kind":"execute_selection","discovery_generation":choices.discovery_generation,"selection":selected}}
                        var submitted = await request(seat,"submit_command",command)
                        while submitted.ok and submitted.value.receipt.kind == "pending" and issue.is_empty():
                            submitted = await request(seat,"receipt",{"number":command.command_number})
                        if submitted.ok and submitted.value.receipt.kind == "committed":
                            evidence.command = command
                            await request(seat,"wait_for_cursor",{"cursor":submitted.value.receipt.cursor,"timeout":30})
                        elif submitted.ok: issue = "Native command did not commit: "+str(submitted)
                    elif preview.ok: issue = "Native preview cannot confirm"
    for seat in seats:
        if issue.is_empty():
            var status = await request(seat,"status")
            if status.ok: await request(seat,"wait_for_cursor",{"cursor":status.value.status.catch_up_cursor,"timeout":30})
    for seat in seats: seat.transport.close()
    if not seats.is_empty():
        for name in DirAccess.get_files_at(seats[0].path.path_join("journal")):
            if not name.ends_with(".json"): continue
            var packet: Dictionary = JSONCodec.new().parse(FileAccess.get_file_as_string(seats[0].path.path_join("journal").path_join(name))).value
            for lineage in packet.get("lineages",[]):
                for node in lineage.events:
                    if node.fact == null: continue
                    if node.canceled: evidence.canceled_nodes += 1
                    var fact: Dictionary = node.fact
                    evidence.facts[fact.kind] = evidence.facts.get(fact.kind,0)+1
                    if fact.kind == "attack" and fact.behavior_id == "reaction.opportunity_attack": evidence.opportunity_attacks += 1
                    if fact.kind == "step" and not fact.committed: evidence.uncommitted_steps += 1
                    if fact.kind == "life": evidence.life.append(fact.new_state)
                    if fact.kind == "step" and fact.committed: evidence.committed_steps += 1
                    if fact.kind == "step" and fact.trajectory == "direct_arc": evidence.direct_arc_steps += 1
    if issue.is_empty():
        if config.case.begins_with("oa_") and evidence.opportunity_attacks == 0: issue = "Native case did not produce an opportunity attack"
        elif "jump" in config.case and evidence.direct_arc_steps == 0: issue = "Native case did not produce a direct_arc step"
        elif "lethal" in config.case and (evidence.uncommitted_steps == 0 or evidence.life.is_empty()): issue = "Native seed did not produce a lethal interrupted step"
        elif config.case == "attack" and evidence.facts.get("attack",0) == 0: issue = "Native case did not produce an attack"
        elif "lethal" not in config.case and config.case != "attack" and evidence.committed_steps == 0: issue = "Native case did not produce committed movement"
    var file = FileAccess.open(config.output.path_join("presentation-result.json"),FileAccess.WRITE)
    file.store_string(JSON.stringify({"ok":issue.is_empty(),"failure":issue,"evidence":evidence},"  ",true,true));file.close()
    print("PRESENTATION_CAPTURE ",JSON.stringify({"ok":issue.is_empty(),"failure":issue,"facts":evidence.facts,"oa":evidence.opportunity_attacks,"uncommitted":evidence.uncommitted_steps}))
    quit(1 if not issue.is_empty() else 0)
