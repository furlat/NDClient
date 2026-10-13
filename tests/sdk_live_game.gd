extends SceneTree
## Slow integration lane: two real SDK seats play a native encounter to terminal.
const Transport = preload("res://sdk/transport.gd")
const Journal = preload("res://sdk/journal.gd")
const Choices = preload("res://sdk/choices.gd")
var seats: Array = []
var issue := ""
var started := Time.get_ticks_msec()
var output := ""
var commands: Array = []
var reconnects := 0
var casts: Dictionary = {}
var end_after_offense: Dictionary = {}

func _init() -> void:
	_run.call_deferred()

func _process(_delta: float) -> bool:
	for seat in seats:
		for event in seat.transport.drain():
			match event.kind:
				"connected": seat.connected = event.result
				"response": seat.responses[event.request_id] = event.result
				"failure": issue = str(event.result)
				"completed": seat.completed = true; seat.final_cursor = event.value.cursor
				"consumed": seat.consumed = event.value.cursor
				"reconnecting": reconnects += 1
	if Time.get_ticks_msec() - started > 240000: issue = "Live encounter deadline exceeded"
	return false

func _request(seat: Dictionary, operation: String, arguments: Dictionary = {}) -> Dictionary:
	var id: int = seat.transport.request(operation, arguments)
	while not seat.responses.has(id) and issue.is_empty(): await process_frame
	if not issue.is_empty(): return {"ok":false,"error":{"message":issue}}
	var result: Dictionary = seat.responses[id]
	seat.responses.erase(id)
	if not result.ok: issue = operation + ": " + str(result.error)
	return result

func _consume(packet: Dictionary, raw: PackedByteArray, journal: RefCounted, path: String) -> Dictionary:
	var duplicate: bool = not journal.cursor.is_empty() and packet.cursor.sequence <= journal.cursor.sequence
	var result: Dictionary = journal.consume(packet, raw)
	if not result.ok: return result
	if duplicate: return result
	var file := FileAccess.open(path.path_join("states/%016d.json" % int(packet.cursor.sequence)), FileAccess.WRITE)
	if file == null: return {"ok":false,"error":{"kind":"test","message":"Cannot write state evidence"}}
	file.store_string(JSON.stringify(journal.snapshot(), "", true, true))
	file.close()
	return result

func _uuid() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	bytes[6] = (bytes[6] & 15) | 64
	bytes[8] = (bytes[8] & 63) | 128
	var value := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [value.substr(0,8),value.substr(8,4),value.substr(12,4),value.substr(16,4),value.substr(20,12)]

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("Pass -- <private-client-config.json>")
		quit(1)
		return
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	output = config.output
	for credential in config.seats:
		var path := output.path_join(credential.id)
		DirAccess.make_dir_recursive_absolute(path.path_join("states"))
		var journal := Journal.new()
		var opened := journal.open(path.path_join("journal"))
		if not opened.ok:
			issue = str(opened)
			break
		var transport := Transport.new()
		var seat := {"id":credential.id,"transport":transport,"journal":journal,"responses":{},"connected":null,"completed":false,"consumed":null,"final_cursor":null,"path":path}
		seats.append(seat)
		var result := transport.start(config.url,credential.token,_consume.bind(journal,path))
		if not result.ok:
			issue = str(result)
			break
		while seat.connected == null and issue.is_empty(): await process_frame
		if not issue.is_empty(): break
		if not seat.connected.ok:
			issue = str(seat.connected)
			break
		var current: Dictionary = seat.connected.value.status
		while current.published_cursor == null and issue.is_empty():
			var ready := await _request(seat,"status")
			if ready.ok: current = ready.value.status
		if not issue.is_empty(): break
		await _request(seat,"attach",{"acquisition_id":_uuid(),"expected_attachment_epoch":current.attachment_epoch})
		await _request(seat,"follow")
		await _request(seat,"health")
		# Bootstrap may precede native initialization and have no content yet.
		# Get the revision from the actual admitted initial record after consumption.
		while seat.consumed == null and issue.is_empty(): await process_frame
		if not issue.is_empty(): break
		var initial: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path.path_join("journal/0000000000000000.json")))
		await _request(seat,"content",{"revision":initial.content_revision})
	var forced := false
	while issue.is_empty():
		var complete := true
		for seat in seats:
			if not seat.completed: complete = false
		if complete: break
		for seat in seats:
			if seat.completed: continue
			var response := await _request(seat,"status")
			if not response.ok: break
			var current: Dictionary = response.value.status
			var actor: Variant = current.boundary.input_actor_uuid
			if actor == null or current.boundary.lifecycle != "waiting_for_human" or current.acknowledged_cursor == null or current.acknowledged_cursor.sequence < current.catch_up_cursor.sequence: continue
			var revision: String = current.boundary.state_revision
			var discovered := await _request(seat,"choices",{"actor_uuid":actor,"state_revision":revision,"force_attack":false,"correlation_id":_uuid()})
			if not discovered.ok: break
			var available: Dictionary = discovered.value.choices
			var selected: Dictionary = {}
			var finish_turn: bool = end_after_offense.get(actor, false)
			end_after_offense.erase(actor)
			var case_name: String = config.get("case", "ranged")
			var affordable: Array = []
			for family in ["entity_actions", "position_actions", "self_actions", "object_actions"]:
				for row in available[family]:
					if row.can_afford and not Choices.action_options(available,row).is_empty(): affordable.append(row)
			if not finish_turn and seat.id == "amber" and case_name in ["magic_missile", "fireball_six_goblins"]:
				var wanted := "spell.fireball" if case_name == "fireball_six_goblins" else "spell.magic_missile"
				for row in affordable:
					if row.behavior_id == wanted and casts.get(actor, 0) < (1 if case_name == "fireball_six_goblins" else 3):
						if selected.is_empty() or row.cast_at_level < selected.cast_at_level: selected = row
				if selected.is_empty():
					for row in affordable:
						if row.behavior_id == "spell.fire_bolt": selected = row; break
			for row in affordable:
				if not finish_turn and selected.is_empty() and row.performs_attack and row.behavior_id == "action.attack" and row.weapon_slot == ("MELEE_MAIN" if case_name == "melee" else "RANGED_MAIN"):
					selected = row
					break
			if selected.is_empty() and not finish_turn:
				for row in available.position_actions:
					if row.behavior_id == "action.move" and row.can_afford and not Choices.action_options(available,row).is_empty():
						selected = row
						break
			var intent := {"kind":"end_turn"}
			var previews: Array = []
			if not selected.is_empty():
				var targets: Array = Choices.action_options(available,selected).duplicate()
				# Test driver policy only: prefer a legal coordinate near the fixture's
				# centre. Shared SDK sets remain untouched; Preview computes effects.
				if selected.behavior_id in ["action.move","spell.fireball"]:
					targets.sort_custom(func(a,b):
						var pa: Array = Choices.binding_position(available,a)
						var pb: Array = Choices.binding_position(available,b)
						return abs(pa[0]-7)+abs(pa[1]-7) < abs(pb[0]-7)+abs(pb[1]-7))
				var primary: Dictionary = targets[0]
				var selection: Dictionary = Choices.selection_for(selected,[primary])
				var confirmed := false
				for _input in 16:
					var preview := await _request(seat,"preview",{"actor_uuid":actor,"state_revision":revision,"discovery_generation":available.discovery_generation,"correlation_id":_uuid(),"selection":selection})
					if not preview.ok: break
					var offered: Dictionary = preview.value.preview
					previews.append({"selection":selection.duplicate(true),"preview":offered})
					if offered.can_confirm and (selected.behavior_id != "spell.magic_missile" or selection.target_indices.size() >= 3):
						if selected.behavior_id=="spell.fireball" and (offered.area_preview!="computed" or Choices.preview_positions(offered,true).is_empty()):
							issue="Selected Fireball did not compute its subjective area";break
						confirmed = true
						break
					var continuation: Array = Choices.next_options(offered)
					var landings: Array = Choices.preview_positions(offered)
					if not continuation.is_empty():
						var next_target: Dictionary = continuation[0]
						# Exercise original ordered selection indexes, including repeated targets.
						var first_subject: Variant = Choices.binding_subject(available,primary)
						for candidate in continuation:
							var subject: Variant = Choices.binding_subject(offered,candidate)
							if subject==null or first_subject==null: continue
							if (subject.uuid!=first_subject.uuid if selection.target_indices.size()==1 else subject.uuid==first_subject.uuid):
								next_target=candidate;break
						selection.target_indices.append(next_target.index)
					elif not landings.is_empty(): selection.extra_target_positions.append(landings[0])
					else: break
				if not confirmed:
					issue = "Native ordered preview did not complete"
					break
				intent = {"kind":"execute_selection","discovery_generation":available.discovery_generation,"selection":selection}
			var command := {"command_number":current.next_command_number,"actor_uuid":actor,"state_revision":revision,"intent":intent}
			var result := await _request(seat,"submit_command",command)
			if not result.ok: break
			var duplicate := await _request(seat,"submit_command",command)
			if not duplicate.ok: break
			while result.value.receipt.kind == "pending" and issue.is_empty():
				result = await _request(seat,"receipt",{"number":command.command_number})
			if not result.ok: break
			if result.value.receipt.kind != "committed":
				issue = "Command failed: " + str(result.value)
				break
			commands.append({"seat":seat.id,"behavior":selected.get("behavior_id", "end_turn"),"command":command,"previews":previews,"receipt":result.value.receipt,"duplicate_receipt":duplicate.value.receipt})
			if selected.get("behavior_id", "") in ["spell.magic_missile", "spell.fireball"]: casts[actor] = casts.get(actor, 0) + 1
			if not selected.is_empty() and selected.behavior_id != "action.move": end_after_offense[actor] = true
			await _request(seat,"wait_for_cursor",{"cursor":result.value.receipt.cursor,"timeout":30})
			if not forced:
				await _request(seat,"reconnect")
				forced = true
			print("Committed ",commands.size()," ",seat.id," ",intent.kind)
			if commands.size() > 100:
				issue = "Encounter command bound exceeded"
				break
	var summaries: Array = []
	for seat in seats:
		seat.transport.close()
		var snapshot: Dictionary = seat.journal.snapshot()
		var cursor: Dictionary = seat.journal.cursor.duplicate(true)
		var replay := Journal.new()
		var result := replay.open(seat.path.path_join("journal"))
		if issue.is_empty() and (not result.ok or replay.snapshot() != snapshot or replay.cursor != cursor): issue = "Cold replay differs: " + seat.id + " " + str(result)
		summaries.append({"id":seat.id,"terminal":seat.completed,"cursor":cursor,"replay_matches":result.ok and replay.snapshot()==snapshot})
	var evidence := {"ok":issue.is_empty(),"failure":issue,"commands":commands,"seats":summaries,"reconnects":reconnects,"elapsed_ms":Time.get_ticks_msec()-started}
	var file := FileAccess.open(output.path_join("godot-result.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence,"  "))
	file.close()
	print(JSON.stringify({"ok":issue.is_empty(),"failure":issue,"commands":commands.size(),"reconnects":reconnects,"seats":summaries}))
	quit(0 if issue.is_empty() else 1)
