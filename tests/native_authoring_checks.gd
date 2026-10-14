extends SceneTree
## Selected native authoring, reload isolation and the untouched migration reference.
const Catalog = preload("res://source_catalog.gd")
const ConditionResource = preload("res://presentation/resources/condition_presentation.gd")
const CatalogResource = preload("res://presentation/resources/catalog.gd")
const ActionResource = preload("res://presentation/resources/body_action.gd")
var checks = 0
var failures: Array = []

func check(value: bool, label: String) -> void:
    checks += 1
    if not value: failures.append(label); print("NATIVE_AUTHORING_FAIL ", label)

func _initialize() -> void:
    var cache = {}
    var recipes = Catalog.read_file("catalog/condition_recipes.json", cache)
    var hidden: Dictionary = recipes["condition.hidden"]
    check(cache.get("native_authoring_errors", []).is_empty(), "Native selections resolve without source errors")
    check(is_equal_approx(hidden.persistent.alphaMultiplier, 0.55), "Selected Hidden Resource supplies partial opacity")
    check(hidden.persistent.activityPoses.map(func(pose): return pose.clip) == ["CrouchIdle", "CrouchRun"], "Selected Resource distinguishes real stationary and moving crouch")
    var root: String = ProjectSettings.get_setting("source_data/authoring_root")
    var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(root.path_join("catalog/condition_recipes.json")))
    check(legacy["condition.hidden"].persistent.alphaMultiplier == 1.0 and not legacy["condition.hidden"].persistent.has("activityPoses"), "Original JSON reference is unchanged")
    var coloured_legacy:Dictionary=legacy.duplicate(true)
    coloured_legacy["condition.hidden"].persistent.bodyColor={"tintRgb":0x225577,"brightness":0.5,"saturation":0.3}
    check(Catalog.NativeAuthoring.overlay("catalog/condition_recipes.json",coloured_legacy,{})["condition.hidden"].persistent.bodyColor==null,
        "An explicitly neutral native filter clears inherited legacy colour operations")
    check(Catalog.source_pointer("catalog/condition_recipes.json", "/condition.hidden/persistent/alphaMultiplier", cache) == "res://authoring/presentation/conditions/hidden.tres::body_filter/opacity", "Inspector resolves selected opacity to editable native property")
    check(Catalog.source_pointer("catalog/condition_recipes.json", "/condition.hidden/relationships", cache) == "catalog/condition_recipes.json:/condition.hidden/relationships", "Inherited relationship retains its actual JSON source")
    var rigs = Catalog.read_file("catalog/rigs.json", cache)
    var sources = Catalog.read_file("catalog/resources.json", cache)
    var action:Dictionary=Catalog.read_file("catalog/body_action_recipes.json",cache)["action.hide"]
    check(action.actor.enabled and action.actor.clip=="CrouchIdle" and action.anchors[1].frame==15,
        "Hide selects a finite authored action and its condition effect boundary")
    check(action.effectAudioCue=="hide_transition", "Hide selects its transition sound at the action effect")
    check(Catalog.source_pointer("catalog/body_action_recipes.json","/action.hide/actor/clip",cache)=="res://authoring/presentation/actions/hide.tres::clip",
        "Action source preview links to the selected native clip property")
    var legacy_actions:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(root.path_join("catalog/body_action_recipes.json")))
    check(not legacy_actions["action.hide"].actor.enabled,
        "Native Hide action leaves the original migration JSON unchanged")
    for name in ["CrouchIdle", "CrouchRun"]:
        var clip: Dictionary = rigs["neuroclient.modular"].clips.get(name, {})
        check(not clip.is_empty(), "Adopted source clip available: " + name)
        if clip.is_empty(): continue
        check(clip.frames == 15 and clip.fps == 12, "Crouch has real frame count and explicitly adopted rate: " + name)
        for path in clip.sheets.values():
            check(sources.has(path) and FileAccess.file_exists(Catalog.media_path(sources[path])), "Registered source exists: " + path)
    check(cache.get("native_authoring_errors", []).is_empty(), "All native source definitions are valid")
    var directory = "res://.runtime/native-authoring-reload"
    DirAccess.make_dir_recursive_absolute(directory)
    var path = directory.path_join("hidden.tres")
    var index_path = directory.path_join("catalog.tres")
    var selected: ConditionResource = ResourceLoader.load("res://authoring/presentation/conditions/hidden.tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
    var index = CatalogResource.new()
    index.condition_recipes["condition.hidden"] = path
    index.body_clips = ResourceLoader.load(Catalog.NativeAuthoring.INDEX).body_clips
    check(ResourceSaver.save(index, index_path) == OK, "Temporary native selection saves through Godot")
    var previous = ProjectSettings.get_setting("source_data/presentation_catalog", Catalog.NativeAuthoring.INDEX)
    ProjectSettings.set_setting("source_data/presentation_catalog", index_path)
    selected.body_filter.opacity = 0.3
    check(ResourceSaver.save(selected, path) == OK, "First authored candidate saves")
    var first_cache = {}
    var first = Catalog.read_file("catalog/condition_recipes.json", first_cache)["condition.hidden"]
    selected.body_filter.opacity = 0.7
    check(ResourceSaver.save(selected, path) == OK, "Edited authored candidate saves")
    var second_cache = {}
    var second = Catalog.read_file("catalog/condition_recipes.json", second_cache)["condition.hidden"]
    check(is_equal_approx(first.persistent.alphaMultiplier, 0.3) and is_equal_approx(second.persistent.alphaMultiplier, 0.7), "Reload reads edited native subresource while displayed recipe stays immutable")
    check(is_equal_approx(hidden.persistent.alphaMultiplier, 0.55), "Another recording's selected source stays unchanged")
    Catalog.validate_native(first_cache)
    var worker_snapshot=Catalog.source_snapshot(first_cache)
    ProjectSettings.set_setting("source_data/presentation_catalog",directory.path_join("not-admitted.tres"))
    var worker=Thread.new()
    worker.start(func():return {"errors":Catalog.validate_native(worker_snapshot),
        "opacity":Catalog.read_file("catalog/condition_recipes.json",worker_snapshot)["condition.hidden"].persistent.alphaMultiplier,
        "clip":Catalog.read_file("catalog/rigs.json",worker_snapshot)["neuroclient.modular"].clips.CrouchRun})
    var worker_result:Dictionary=worker.wait_to_finish()
    check(worker_result.errors.is_empty() and is_equal_approx(worker_result.opacity,0.3) and worker_result.clip.frames==15,
        "Worker uses admitted source snapshot despite subsequent source edits and invalid new catalog selection")
    ProjectSettings.set_setting("source_data/presentation_catalog",index_path)
    for invalid in ["missing_clip", "missing_rig", "held_frame", "invalid_speed"]:
        var pose=selected.activity_poses[0]
        pose.clip="AbsentClip" if invalid=="missing_clip" else "CrouchIdle"
        pose.rig_id="absent.rig" if invalid=="missing_rig" else "neuroclient.modular"
        pose.sampling="hold" if invalid=="held_frame" else "loop"
        pose.frame=15 if invalid=="held_frame" else 0
        pose.playback_speed=NAN if invalid=="invalid_speed" else 1.0
        ResourceSaver.save(selected,path)
        check(not Catalog.validate_native({}).is_empty(), "Invalid selected Resource rejected: "+invalid)
        check(is_equal_approx(first.persistent.alphaMultiplier,0.3), "Invalid candidate leaves previous authored snapshot intact: "+invalid)
    ProjectSettings.set_setting("source_data/presentation_catalog",path)
    check(not Catalog.validate_native({}).is_empty(), "Wrong Resource type cannot silently become an empty catalog")
    ProjectSettings.set_setting("source_data/presentation_catalog",index_path)
    index.condition_recipes["condition.hidden"] = directory.path_join("missing.tres")
    ResourceSaver.save(index, index_path)
    var missing_cache = {}
    Catalog.read_file("catalog/condition_recipes.json", missing_cache)
    check(not missing_cache.get("native_authoring_errors", []).is_empty(), "Missing selected Resource reports an authoring failure instead of claiming legacy success")
    Catalog.validate_native(missing_cache)
    check(not Catalog.validate_native(Catalog.source_snapshot(missing_cache)).is_empty(), "Worker snapshot preserves source rejection instead of silently accepting fallback values")
    index.condition_recipes.clear()
    var action_path=directory.path_join("hide.tres")
    index.action_recipes["action.hide"]=action_path
    ResourceSaver.save(index,index_path)
    var selected_action:ActionResource=ResourceLoader.load("res://authoring/presentation/actions/hide.tres","",ResourceLoader.CACHE_MODE_IGNORE_DEEP)
    ResourceSaver.save(selected_action,action_path)
    var action_cache={}
    check(Catalog.validate_native(action_cache).is_empty(),"Native action candidate admits its real source and terminal marker")
    var action_snapshot=Catalog.source_snapshot(action_cache)
    for invalid in ["missing_clip","missing_rig","late_effect","invalid_speed"]:
        selected_action.clip="AbsentClip" if invalid=="missing_clip" else "CrouchIdle"
        selected_action.rig_id="absent.rig" if invalid=="missing_rig" else "neuroclient.modular"
        selected_action.effect_frame=16 if invalid=="late_effect" else 15
        selected_action.playback_speed=NAN if invalid=="invalid_speed" else 3.0
        ResourceSaver.save(selected_action,action_path)
        check(not Catalog.validate_native({}).is_empty(),"Invalid body action candidate rejected: "+invalid)
        var retained:Dictionary=Catalog.read_file("catalog/body_action_recipes.json",action_snapshot)["action.hide"]
        check(Catalog.validate_native(action_snapshot).is_empty() and retained.actor.clip=="CrouchIdle" and retained.anchors[1].frame==15 and retained.actor.playbackSpeed==3.0,
            "Rejected action source does not replace admitted body/effect clock: "+invalid)
    ProjectSettings.set_setting("source_data/presentation_catalog", previous)
    DirAccess.remove_absolute(path)
    DirAccess.remove_absolute(index_path)
    DirAccess.remove_absolute(action_path)
    var report = {"checks":checks, "failures":failures, "scope":"Native source selection, installed crouch sheets, exact provenance and candidate reload isolation; no pixel-rendering claim."}
    FileAccess.open("res://generated/native_authoring_checks.json", FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
    print("NATIVE_AUTHORING ", JSON.stringify(report))
    quit(0 if failures.is_empty() else 1)
