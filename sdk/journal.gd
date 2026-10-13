extends RefCounted
## Worker-owned raw journal. Durable record first, atomic reducer publication next.
const Protocol = preload("res://sdk/protocol.gd")
const Reducer = preload("res://sdk/reducer.gd")
var protocol := Protocol.new()
var directory := ""
var state: Dictionary = {}
var cursor: Dictionary = {}
# Optional payload-free timing for the transport owner; no work history retained.
var profile_enabled := false
var last_profile: Dictionary = {}

func open(path: String, historical_recording: bool = false, replay_existing: bool = true) -> Dictionary:
	if not directory.is_empty(): return _failure("Journal already opened")
	var code := DirAccess.make_dir_recursive_absolute(path)
	if code != OK: return _failure("Cannot create journal: " + error_string(code))
	directory = path
	# Explicit offline-only compatibility. Never change packet identities or
	# let a live connection silently accept a different protocol.
	if historical_recording and FileAccess.file_exists(_file(0)):
		var first := Protocol.parse_json(FileAccess.get_file_as_bytes(_file(0)))
		if not first.ok: return first
		if not first.value is Dictionary: return _failure("Invalid recording initialization")
		if not protocol.check_identity(first.value.get("protocol",{})).ok:
			var matched := false
			for version in ["pre-compact-choices", "pre-tile-fields", "pre-source-lighting", "pre-container-loot"]:
				var base: String = "res://sdk/recordings/" + str(version) + "/"
				var archived := Protocol.new(base + "player-api-v1.schema.json", base + "protocol-identity.json")
				if archived.check_identity(first.value.get("protocol",{})).ok:
					protocol = archived
					matched = true
					break
			if not matched: return _failure("Unsupported recording protocol")
	return replay() if replay_existing else {"ok":true,"value":null}

func consume(packet: Dictionary, raw: PackedByteArray) -> Dictionary:
	if directory.is_empty(): return _failure("Journal is not open")
	# Decode independently: consumers can also be called by offline tools.
	var admitted := protocol.decode("InitializationResponse" if packet.get("cursor", {}).get("sequence", -1) == 0 else "PlayerOperation", raw)
	if not admitted.ok: return admitted
	if not Protocol._equal(admitted.value, packet): return _failure("Packet differs from journal bytes")
	return _consume_admitted(admitted.value, raw)

func _consume_admitted(packet: Dictionary, raw: PackedByteArray, record_transitions: bool = false) -> Dictionary:
	last_profile = {"sequence":int(packet.get("cursor",{}).get("sequence",-1)), "phase_ms":{}, "reducer_ms":{}} if profile_enabled else {}
	# Internal transport/replay boundary: the caller owns these exact admitted
	# bytes. Public consume() above always decodes and compares independently.
	if directory.is_empty(): return _failure("Journal is not open")
	var identity_check := protocol.check_identity(packet.protocol)
	if not identity_check.ok: return identity_check
	var next: Dictionary = packet.cursor
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
	var normalized: Dictionary = protocol._normalize_admitted("InitializationResponse" if next.sequence == 0 else "PlayerOperation", packet)
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
	state = {}
	cursor = {}
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
		var result := protocol.decode("InitializationResponse" if sequence == 0 else "PlayerOperation", raw)
		if result.ok and int(result.value.cursor.sequence) != sequence: result = _failure("Journal filename/cursor mismatch")
		if result.ok: result = _consume_admitted(result.value, raw)
		if not result.ok:
			state = prior_state
			cursor = prior_cursor
			return result
	if through_sequence >= 0 and (cursor.is_empty() or cursor.sequence != through_sequence):
		state = prior_state
		cursor = prior_cursor
		return _failure("Requested journal cursor is unavailable")
	return {"ok": true, "value": cursor.duplicate(true)}

func snapshot() -> Dictionary:
	return state.duplicate(true)

func _reduced_state(packet: Dictionary, record_transitions: bool = false) -> Dictionary:
	var result: Dictionary
	if packet.cursor.sequence == 0:
		result = Reducer.reduce_initialization(packet.initialization, packet.content_additions)
	else:
		result = Reducer._reduce_operation_retained(state, packet, record_transitions, last_profile.reducer_ms if profile_enabled else null)
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
