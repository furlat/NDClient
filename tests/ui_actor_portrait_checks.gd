extends SceneTree
# Portrait projection of unchanged native actor records, including serialized
# creature ContentRef.identity_key strings and explicit humanoid choices.
const UI = preload("res://presentation/ui_catalog.gd")
const JSONReader = preload("res://sdk/strict_json.gd")
var checks = 0
var failures: Array = []
var missing_source_roles: Array = []
func check(value: bool, label: String) -> void:
    checks += 1
    if not value: failures.append(label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
    var cache = {}
    for path in [
        "C:/Users/tommaso/AppData/Local/Temp/ndclient-presentation-oa-jump-late-lethal/amber/states/0000000000000000.json",
        "C:/Users/tommaso/AppData/Local/Temp/ndclient-sdk-ranged-exact/amber/states/0000000000000000.json",
        "C:/Users/tommaso/AppData/Local/Temp/ndclient-sdk-spells-verified/amber/states/0000000000000000.json",
        "res://.runtime/player-runs/20261011T222502.988278Z/state.json"]:
        check(FileAccess.file_exists(path),"actual recording exists: "+path)
        if not FileAccess.file_exists(path): continue
        var state: Dictionary = JSONReader.new().parse(FileAccess.get_file_as_string(path)).value
        for actor in state.actors.values():
            var key = UI.portrait_key(actor,UI.sheet(state,actor.uuid),state)
            var expected = actor.appearance.portrait_key
            if expected == null:
                var matching: Array = state.content.filter(func(row):return "%s:%s:%s@%d" % [row.ref.pack_id,row.ref.definition_kind,row.ref.content_id,row.ref.content_version] == actor.creature_content_ref)
                check(not matching.is_empty(),"native creature identity resolves to admitted descriptor")
                if not matching.is_empty(): expected = matching[0].presentation.portrait_key
            check(key == ("" if expected == null else expected),"actual actor portrait retains native identity: "+actor.name)
            if not key.is_empty():
                var authored = UI.authored(cache).resources.has("portrait:"+key)
                check((UI.texture(key,cache,true)!=null)==authored,"portrait resolution matches actual authored role: "+key)
                if not authored and key not in missing_source_roles: missing_source_roles.append(key)
    var deadline = Time.get_ticks_msec()+30000
    while UI.images_pending(cache) and Time.get_ticks_msec()<deadline:
        UI.poll_images(cache)
        await process_frame
    check(not UI.images_pending(cache) and cache.get("ui_media",{}).get("failed",[]).is_empty(),"Every requested original portrait decodes without errors")
    UI.close_images(cache)
    var report = {"checks":checks,"failures":failures,"missing_source_roles":missing_source_roles}
    var file = FileAccess.open("res://.runtime/ui/portrait-checks.json",FileAccess.WRITE)
    file.store_string(JSON.stringify(report,"  ")); file.close()
    print(JSON.stringify(report))
    quit(0 if failures.is_empty() else 1)
