extends SceneTree
const Journal = preload("res://sdk/journal.gd")
const Protocol = preload("res://sdk/protocol.gd")
var failures: Array = []
var checks := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func _init() -> void:
	var path := "user://sdk-journal-check-" + str(Time.get_ticks_usec())
	var strict := Journal.new()
	check(strict.open(path).ok, "open empty current-protocol journal")
	var initial_raw := FileAccess.get_file_as_bytes("res://tests/fixtures/player/initialization.json")
	var operation_raw := FileAccess.get_file_as_bytes("res://tests/fixtures/player/operation.json")
	# Frozen real wire recordings retain their original schema identity. Live
	# admission rejects that identity; only explicit offline replay selects it.
	var old_packet: Dictionary = strict.protocol.parse_json(initial_raw).value
	check(not strict.consume(old_packet, initial_raw).ok, "live journal rejects frozen recording identity")
	var stored := FileAccess.open(path.path_join("0000000000000000.json"), FileAccess.WRITE)
	stored.store_buffer(initial_raw)
	stored.close()
	var journal := Journal.new()
	var opened := journal.open(path, true)
	check(opened.ok, "explicit historical replay selects frozen schema")
	if not opened.ok:
		print(JSON.stringify({"checks":checks,"failures":failures}))
		quit(1)
		return
	var live_reopen := Journal.new()
	check(not live_reopen.open(path).ok, "default reopening does not silently accept historical identity")
	var initial: Dictionary = journal.protocol.decode("InitializationResponse", initial_raw).value
	var operation: Dictionary = journal.protocol.decode("PlayerOperation", operation_raw).value
	check(journal.consume(initial, initial_raw).ok, "accept real initialization")
	var before := journal.snapshot()
	var before_cursor := journal.cursor.duplicate(true)
	var gap := operation.duplicate(true)
	gap.cursor.sequence += 1
	check(not journal.consume(gap, JSON.stringify(gap).to_utf8_buffer()).ok, "reject transport gap")
	check(journal.snapshot() == before and journal.cursor == before_cursor, "gap preserves state")
	var invalid := operation.duplicate(true)
	# An operation can pass wire schema but fail canonical lineage semantics.
	invalid.lineages[0].start_cursor += 1
	var invalid_raw := JSON.stringify(invalid).to_utf8_buffer()
	check(journal.protocol.decode("PlayerOperation", invalid_raw).ok, "invalid reduction still valid schema")
	check(not journal.consume(invalid, invalid_raw).ok, "reducer rejects lineage gap")
	check(journal.snapshot() == before and journal.cursor == before_cursor, "reducer failure preserves snapshot")
	check(not FileAccess.file_exists(path.path_join("0000000000000001.json")), "rejected record not committed")
	var reopened := Journal.new()
	check(reopened.open(path, true).ok and reopened.snapshot() == before, "reopen after rejected record")
	# Captures from a valid event fold still cannot escape a later operation HUD
	# failure, or a durable rename failure. Both leave the published cursor intact.
	var late := operation.duplicate(true)
	late.hud.revision = late.lineages[-1].end_cursor + 1
	var late_raw := JSON.stringify(late).to_utf8_buffer()
	check(journal.protocol.decode("PlayerOperation", late_raw).ok, "late HUD failure passes wire admission")
	var rejected := journal._consume_admitted(late, late_raw, true)
	check(not rejected.ok and not rejected.has("transitions"), "late validation publishes no event captures")
	check(journal.snapshot() == before and journal.cursor == before_cursor, "late failure preserves published state and cursor")
	var blocked_path := path.path_join("0000000000000001.json")
	check(DirAccess.make_dir_absolute(blocked_path) == OK, "create durable commit obstruction")
	var obstructed := journal._consume_admitted(operation, operation_raw, true)
	check(not obstructed.ok and not obstructed.has("transitions"), "failed durable commit publishes no captures")
	check(journal.snapshot() == before and journal.cursor == before_cursor, "failed durable commit preserves state and cursor")
	DirAccess.remove_absolute(blocked_path)
	var accepted := journal._consume_admitted(operation, operation_raw, true)
	check(accepted.ok and accepted.has("transitions"), "corrected resend commits with event-time captures")
	check(FileAccess.get_file_as_bytes(blocked_path) == operation_raw, "captures publish only alongside the durable exact record")
	var held: Dictionary = accepted.transitions.duplicate(true)
	var duplicate := journal._consume_admitted(operation, operation_raw, true)
	check(duplicate.ok and not duplicate.has("transitions"), "duplicate delivery does not republish event captures")
	check(accepted.transitions == held, "duplicate delivery preserves retained captures")
	var after := journal.snapshot()
	check(journal.consume(operation, operation_raw).ok and journal.snapshot() == after, "identical duplicate is idempotent")
	var altered := operation.duplicate(true)
	altered.state_revision += "-changed"
	check(not journal.consume(altered, JSON.stringify(altered).to_utf8_buffer()).ok, "conflicting duplicate rejected")
	check(journal.snapshot() == after, "conflict preserves state")
	check(reopened.replay().ok and reopened.snapshot() == after, "cold replay equals live")
	check(reopened.replay(0).ok and reopened.snapshot() == before, "historical prefix")
	check(not reopened.replay(999).ok and reopened.snapshot() == before, "unavailable prefix preserves prior state")
	var returned := journal.snapshot()
	returned.actors.clear()
	check(journal.snapshot() == after, "caller cannot mutate snapshot")
	var foreign := operation.duplicate(true)
	foreign.cursor.sequence = 2
	foreign.cursor.audience_id = "00000000-0000-4000-8000-000000000001"
	check(not journal.consume(foreign, JSON.stringify(foreign).to_utf8_buffer()).ok, "foreign audience rejected")
	for filename in DirAccess.get_files_at(path): DirAccess.remove_absolute(path.path_join(filename))
	DirAccess.remove_absolute(path)
	print(JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
