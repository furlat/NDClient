extends SceneTree
const Protocol = preload("res://sdk/protocol.gd")
var count := 0
var failures: Array = []
func check(condition: bool, label: String) -> void:
	count += 1
	if not condition: failures.append(label)
func _init() -> void:
	var p = Protocol.new()
	check(p.setup_error.is_empty(), "schema vocabulary: " + p.setup_error)
	for text in ['null','0','-1','1.0','1e2','[]','{}','[true,false,null]','"café😀"','"\\uD83D\\uDE00"','{"x":1,"x":2}']:
		check(p.parse_json(text.to_utf8_buffer()).ok, "valid JSON: " + text)
	for text in ['', '[1,]', '{"x":1,}', '01', '+1', '.5','1.','1e','NaN','Infinity','1e999','true false','"a\nb"','"\\uD800"','"\\uDC00"','"\\uD800\\u0041"','"\\x"','[','{"x" 1}']:
		check(not p.parse_json(text.to_utf8_buffer()).ok, "reject JSON: " + text)
	for bytes in [[0xc0,0x80], [0xed,0xa0,0x80], [0xf4,0x90,0x80,0x80], [0x80], [0xe2,0x82]]:
		check(not p.utf8(PackedByteArray(bytes)).ok, "reject UTF8 " + str(bytes))
	var cursor := {"game_id":"test", "game_epoch":"11111111-1111-1111-1111-111111111111", "audience_id":"22222222-2222-2222-2222-222222222222", "sequence":0}
	check(p.validate("PlayerCursor",cursor).ok, "valid cursor")
	for bad in [-1, 0.5, true, null, "0", 9007199254740992]:
		var value := cursor.duplicate(true)
		value.sequence = bad
		check(not p.validate("PlayerCursor", value).ok, "invalid cursor: " + str(bad))
	cursor.sequence = 9007199254740991
	check(p.decode("PlayerCursor", JSON.stringify(cursor).to_utf8_buffer()).ok, "maximum safe cursor")
	cursor.sequence = 0.0
	var normalized: Dictionary = p.normalize("PlayerCursor", cursor)
	check(typeof(normalized.sequence) == TYPE_INT, "normalize outbound integer")
	var identity: Dictionary = p.identity.duplicate(true)
	check(p.check_identity(identity).ok, "exact identity")
	check(p.check_identity({"schema_digest":identity.schema_digest}).ok,"Current identity permits documented omitted constant defaults")
	check(identity.player_schema_version==18,"Live admission uses the delivered schema18 producer")
	for paths in Protocol.RECORDED_CONTRACTS:
		var archived=Protocol.new(paths[0],paths[1])
		check(archived.setup_error.is_empty(),"Archived producer schema remains readable")
		check(not p.check_identity(archived.identity).ok,"Live admission refuses an archived producer identity")
		check(archived.check_identity({"schema_digest":archived.identity.schema_digest}).ok,"Archived omitted defaults use that recording's own schema version")
		check(not archived.decode_server("BootstrapResponse",'{}'.to_utf8_buffer()).ok,"Archived protocol cannot become a live transport decoder")
	var packed={"x0":-1,"y0":2,"width":1,"height":1,"bits":"AQ=="}
	check(p.validate("CellMask",packed).ok,"Current packed cells admit base64url")
	packed.bits="!bad"
	check(not p.validate("CellMask",packed).ok,"Public packed-cell format rejects invalid base64url")
	identity.schema_digest = "f".repeat(64)
	check(not p.check_identity(identity).ok, "wrong identity")
	check(not p.validate("PlayerCursor", {"game_id":"x"}).ok, "required properties")
	var extra := cursor.duplicate(true)
	extra.extra = true
	check(not p.validate("PlayerCursor", extra).ok, "additional properties")
	check(not p.validate("PlayerCursor", {"game_id":"x","game_epoch":"bad","audience_id":"bad","sequence":0}).ok, "UUID format")
	check(p.parse_json('9007199254740991'.to_utf8_buffer()).value == 9007199254740991, "integer precision")
	var nul: Dictionary = p.parse_json('"a\\u0000b"'.to_utf8_buffer())
	check(not nul.ok, "unsupported escaped NUL rejected instead of silently replaced")
	var upper := cursor.duplicate(true)
	upper.game_epoch = "ABCDEFAB-ABCD-ABCD-ABCD-ABCDEFABCDEF"
	check(p.normalize("PlayerCursor", upper).game_epoch == upper.game_epoch.to_lower(), "UUID canonicalization only in reducer copy")
	# Union admission must still honor constraints on the containing schema.
	p.schema["$defs"].GuardedObject = {"anyOf":[{"type":"object"}],"required":["mode"],"properties":{"mode":{"const":"ok"}},"additionalProperties":false}
	check(p.validate("GuardedObject",{"mode":"ok"}).ok,"Union object retains valid constrained value")
	for value in [{},{"mode":"bad"},{"mode":"ok","extra":true}]:
		check(not p.validate("GuardedObject",value).ok,"Union sibling object constraints survive: "+str(value))
	p.schema["$defs"].GuardedArray = {"anyOf":[{"type":"array"}],"minItems":2,"uniqueItems":true,"items":{"type":"integer"}}
	check(p.validate("GuardedArray",[1,2]).ok,"Union array retains valid constrained value")
	for value in [[1],[1,1],[1,"x"]]:
		check(not p.validate("GuardedArray",value).ok,"Union sibling array constraints survive: "+str(value))
	print(JSON.stringify({"checks":count, "failures":failures}))
	quit(0 if failures.is_empty() else 1)
