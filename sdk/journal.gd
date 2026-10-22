extends RefCounted
## Worker-owned raw journal. Durable record first, atomic reducer publication next.
const Protocol = preload("res://sdk/protocol.gd")
const Reducer = preload("res://sdk/reducer.gd")
var protocol := Protocol.new()
var directory := ""
var state: Dictionary = {}
var cursor: Dictionary = {}
# Derived sensory/disclosure indexes belong to this exact committed state. Candidate
# reductions fork them; failed folds/writes never publish their replacements.
var _sensory_context: Dictionary = {}
# Optional payload-free timing for the transport owner; no work history retained.
var profile_enabled := false
var last_profile: Dictionary = {}
# An offline reader opened without replay: open() already parsed packet 0
# and checked its current protocol. decode_record() admits that parse instead of a second.
var _opened_initialization: Array = []

func open(path: String, _historical_recording: bool = false, replay_existing: bool = true) -> Dictionary:
	if not directory.is_empty(): return _failure("Journal already opened")
	var code := DirAccess.make_dir_recursive_absolute(path)
	if code != OK: return _failure("Cannot create journal: " + error_string(code))
	directory = path
	# An existing recording selects its exact stored producer contract.
	# Old wire9/unknown identities remain refused; no bytes or facts are rewritten.
	if FileAccess.file_exists(_file(0)):
		if not protocol.setup_error.is_empty(): return Protocol.failure(protocol.setup_error)
		if not protocol._current_server_contract and not protocol._archived_server_contract:
			return Protocol.failure("Unknown recorded producer contract")
		var raw := FileAccess.get_file_as_bytes(_file(0))
		var parsed: Dictionary = Protocol.parse_json(raw)
		if not parsed.ok: return parsed
		if not parsed.value is Dictionary or not parsed.value.get("protocol") is Dictionary: return _failure("Recorded initialization has no protocol identity")
		if not protocol.check_identity(parsed.value.protocol).ok:
			for paths in Protocol.RECORDED_CONTRACTS:
				var archived := Protocol.new(paths[0],paths[1])
				if not archived.setup_error.is_empty(): return _failure(archived.setup_error)
				if archived.check_identity(parsed.value.protocol).ok:
					protocol = archived
					break
			var checked: Dictionary = protocol.check_identity(parsed.value.protocol)
			if not checked.ok: return checked
		# The already strict-parsed value belongs to the exact selected producer
		# contract. Preserve decode_recorded's initialization cursor check without
		# reparsing this entire packet (the Opus parse-once handoff).
		if int(parsed.value.get("cursor",{}).get("sequence",-1))!=0:
			return _failure("Initialization sequence must be zero")
		_opened_initialization = [raw, parsed.value]
	return replay() if replay_existing else {"ok":true,"value":null}

## Offline decode of one recorded packet. Packet 0 reuses open()'s parse when
## its bytes are unchanged, preserving decode_recorded()'s producer admission.
func decode_record(sequence: int, raw: PackedByteArray) -> Dictionary:
	if sequence == 0 and not _opened_initialization.is_empty():
		if not protocol.setup_error.is_empty(): return Protocol.failure(protocol.setup_error)
		if not protocol._current_server_contract and not protocol._archived_server_contract:
			return Protocol.failure("Unknown recorded producer contract")
		var opened: Array = _opened_initialization
		_opened_initialization = []
		if opened[0] == raw: return {"ok":true,"value":opened[1]}
	return protocol.decode_recorded("InitializationResponse" if sequence == 0 else "PlayerOperation", raw)

func consume(packet: Dictionary, raw: PackedByteArray) -> Dictionary:
	if directory.is_empty(): return _failure("Journal is not open")
	# Decode independently: consumers can also be called by offline tools.
	var admitted := protocol.decode("InitializationResponse" if packet.get("cursor", {}).get("sequence", -1) == 0 else "PlayerOperation", raw)
	if not admitted.ok: return admitted
	if not Protocol._equal(admitted.value, packet): return _failure("Packet differs from journal bytes")
	return _consume_admitted(admitted.value, raw)

func _consume_admitted(packet: Dictionary, raw: PackedByteArray, record_transitions: bool = false, canonical_server_operation: bool = false) -> Dictionary:
	last_profile = {"sequence":int(packet.get("cursor",{}).get("sequence",-1)), "phase_ms":{}, "reducer_ms":{}} if profile_enabled else {}
	# Internal transport/replay boundary: the caller owns these exact admitted
	# bytes. Public consume() above always decodes and compares independently.
	if directory.is_empty(): return _failure("Journal is not open")
	var identity_check := protocol.check_identity(packet.protocol)
	if not identity_check.ok: return identity_check
	var next: Dictionary = packet.cursor
	_opened_initialization.clear()
	if not cursor.is_empty():
		for key in ["game_id", "game_epoch", "audience_id"]:
			if next[key] != cursor[key]: return _failure("Journal audience/epoch mismatch")
		if next.sequence <= cursor.sequence:
			if FileAccess.get_file_as_bytes(_file(next.sequence)) != raw: return _failure("Conflicting duplicate journal record")
			return {"ok": true, "value": cursor.duplicate(true)}
	if int(next.sequence) != (0 if cursor.is_empty() else int(cursor.sequence) + 1): return _failure("Journal sequence gap")
	var started: int = Time.get_ticks_usec() if profile_enabled else 0
	var saved := _stage(int(next.sequence), raw)
	if profile_enabled: _profile_elapsed("stage", started)
	if not saved.ok: return saved
	started = Time.get_ticks_usec() if profile_enabled else 0
	var normalized: Dictionary = packet
	if profile_enabled: _profile_elapsed("normalize", started)
	started = Time.get_ticks_usec() if profile_enabled else 0
	var reduced := _reduced_state(normalized, record_transitions)
	if profile_enabled: _profile_elapsed("reduce", started)
	if not reduced.ok: return reduced
	started = Time.get_ticks_usec() if profile_enabled else 0
	var target := _file(int(next.sequence))
	if not FileAccess.file_exists(target):
		var code := DirAccess.rename_absolute(target + ".tmp", target)
		if code != OK: return _failure("Cannot commit journal: " + error_string(code))
	state = reduced.value
	_sensory_context = reduced.get("sensory_context",{})
	cursor = packet.cursor.duplicate(true)
	var accepted := {"ok": true, "value": cursor.duplicate(true), "normalized": normalized}
	# Derived records cross the worker boundary only after durable publication.
	if reduced.has("transitions"): accepted.transitions = reduced.transitions
	if profile_enabled: _profile_elapsed("commit", started)
	return accepted

func replay(through_sequence: int = -1) -> Dictionary:
	# Replay is transactional: leave the prior snapshot intact on any bad record.
	var prior_state := state
	var prior_cursor := cursor
	var prior_context := _sensory_context
	state = {}
	cursor = {}
	_sensory_context = {}
	var files: Array[String] = []
	var expression := RegEx.new()
	expression.compile("^[0-9]{16}\\.json$")
	for filename in DirAccess.get_files_at(directory):
		if expression.search(filename) != null: files.append(filename)
	files.sort()
	for filename in files:
		var sequence := filename.trim_suffix(".json").to_int()
		if through_sequence >= 0 and sequence > through_sequence: break
		var raw := FileAccess.get_file_as_bytes(directory.path_join(filename))
		var result := decode_record(sequence,raw)
		if result.ok and int(result.value.cursor.sequence) != sequence: result = _failure("Journal filename/cursor mismatch")
		if result.ok: result = _consume_admitted(result.value, raw)
		if not result.ok:
			state = prior_state
			cursor = prior_cursor
			_sensory_context = prior_context
			return result
	if through_sequence >= 0 and (cursor.is_empty() or cursor.sequence != through_sequence):
		state = prior_state
		cursor = prior_cursor
		_sensory_context = prior_context
		return _failure("Requested journal cursor is unavailable")
	return {"ok": true, "value": cursor.duplicate(true)}

func snapshot() -> Dictionary:
	return state.duplicate(true)

func _reduced_state(packet: Dictionary, record_transitions: bool = false) -> Dictionary:
	var result: Dictionary
	if packet.cursor.sequence == 0:
		result = Reducer.reduce_initialization(packet.initialization, packet.get("content_additions",[]))
	else:
		result = Reducer._reduce_operation_retained(state, packet, record_transitions, last_profile.reducer_ms if profile_enabled else null, _sensory_context)
	return result

func _file(sequence: int) -> String:
	return directory.path_join("%016d.json" % sequence)

func _stage(sequence: int, raw: PackedByteArray) -> Dictionary:
	var target := _file(sequence)
	if FileAccess.file_exists(target):
		return {"ok": true} if FileAccess.get_file_as_bytes(target) == raw else _failure("Conflicting journal file")
	var temporary := target + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return _failure("Cannot write journal: " + error_string(FileAccess.get_open_error()))
	file.store_buffer(raw)
	file.flush()
	var code := file.get_error()
	file.close()
	if code != OK: return _failure("Cannot flush journal: " + error_string(code))
	return {"ok": true}

static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": {"kind": "journal", "message": message, "retryable": false}}

func _profile_elapsed(phase: String, started: int) -> void:
	last_profile.phase_ms[phase] = (Time.get_ticks_usec() - started) / 1000.0
