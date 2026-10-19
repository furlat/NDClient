extends SceneTree
# Portrait projection of unchanged native actor records, including serialized
# creature ContentRef.identity_key strings and explicit humanoid choices.
const UI = preload("res://presentation/ui_catalog.gd")
const Journal = preload("res://sdk/journal.gd")
var checks = 0
var failures: Array = []
var missing_source_roles: Array = []
func check(value: bool, label: String) -> void:
    checks += 1
    if not value: failures.append(label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
    var cache = {}
    for directory in ["res://tests/fixtures/schema16/fire-bolt",
        "res://tests/fixtures/schema16/created-flame-blade/amber",
        "res://tests/fixtures/schema16/created-flame-blade/blue"]:
        var journal=Journal.new()
        var opened:Dictionary=journal.open(directory,true,false)
        check(opened.ok,"Actual current-schema portrait recording opens: "+directory)
        if not opened.ok:continue
        var replayed:Dictionary=journal.replay(0)
        check(replayed.ok,"Actual native initialization folds before portrait lookup: "+directory)
        if not replayed.ok:continue
        var state:Dictionary=journal.state
        var before:Dictionary=state.duplicate(true)
        for actor in state.actors.values():
            var sheet:Dictionary=UI.sheet(state,actor.uuid)
            var key = UI.portrait_key(actor,sheet,state,cache)
            var expected:Variant=actor.get("appearance",{}).get("portrait_key",sheet.get("portrait_key"))
            if actor.get("creature_content_ref")!=null:
                var identity:String=str(actor.creature_content_ref).get_slice(":",2).get_slice("@",0)
                expected=UI.authored(cache).maps.creature_portraits.get(identity,"")
                check(not str(expected).is_empty(),"Native creature identity resolves to its actual built portrait binding: "+identity)
            check(key == ("" if expected == null else expected),"actual actor portrait retains native identity: "+actor.name)
            if not key.is_empty():
                var authored:bool=UI.authored(cache).maps.portraits.has(key)
                check(authored,"Actual portrait binding names a shipped image: "+key)
                if authored:check(UI.texture(key,cache,true)!=null,"Portrait resolves through its built image map: "+key)
                if not authored and key not in missing_source_roles: missing_source_roles.append(key)
        check(state==before,"Portrait lookup preserves the canonical recorded state: "+directory)
    var deadline = Time.get_ticks_msec()+30000
    while UI.images_pending(cache) and Time.get_ticks_msec()<deadline:
        UI.poll_images(cache)
        await process_frame
    check(not UI.images_pending(cache) and cache.get("ui_media",{}).get("failed",[]).is_empty(),"Every requested original portrait decodes without errors")
    UI.close_images(cache)
    var report = {"checks":checks,"failures":failures,"missing_source_roles":missing_source_roles}
    DirAccess.make_dir_recursive_absolute("res://.runtime/ui")
    var file = FileAccess.open("res://.runtime/ui/portrait-checks.json",FileAccess.WRITE)
    file.store_string(JSON.stringify(report,"  ")); file.close()
    print(JSON.stringify(report))
    quit(0 if failures.is_empty() else 1)
