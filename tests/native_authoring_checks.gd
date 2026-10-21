extends SceneTree
## Selected native authoring (now the abilities source, built into
## build/presentation/abilities), reload isolation and the untouched
## migration reference.
const Catalog = preload("res://source_catalog.gd")
const Document = preload("res://presentation/resources/ability_document.gd")
const AbilityDocuments = preload("res://presentation/ability_documents.gd")
const Builder = preload("res://tools/presentation_build/abilities.gd")
const Common = preload("res://tools/presentation_build/common.gd")
const Characters = preload("res://presentation/characters.gd")
const BodySources = preload("res://presentation/body_sources.gd")
var checks = 0
var failures: Array = []

func check(value: bool, label: String) -> void:
    checks += 1
    if not value: failures.append(label); print("NATIVE_AUTHORING_FAIL ", label)

## Writes one record table of a candidate abilities build.
func save_table(root: String, path: String, data: Variant) -> bool:
    var document := Document.new()
    if data is Dictionary:document.data = data
    var file := root.path_join("docs").path_join(path.get_basename() + ".res")
    DirAccess.make_dir_recursive_absolute(file.get_base_dir())
    return ResourceSaver.save(document if data is Dictionary else data, file) == OK

func _initialize() -> void:
    var cache = {}
    var recipes = Catalog.read_file("catalog/condition_recipes.json", cache)
    var hidden: Dictionary = recipes["condition.hidden"]
    check(cache.get("native_authoring_errors", []).is_empty(), "Native selections resolve without source errors")
    check(is_equal_approx(hidden.persistent.alphaMultiplier, 0.55), "Selected Hidden source supplies partial opacity")
    check(hidden.persistent.activityPoses.map(func(pose): return pose.clip) == ["CrouchIdle", "CrouchRun"], "Selected source distinguishes real stationary and moving crouch")
    var entry: Resource = load("res://authoring/abilities/conditions/condition.hidden.tres")
    check(entry != null and entry.look.steps[0].kind == "body_adjust" and is_equal_approx(entry.look.steps[0].alpha, 0.55) and entry.poses.size() == 2,
        "The abilities source holds Hidden's look and its crouch poses")
    check(hidden.persistent.bodyColor == null, "An explicitly neutral native filter clears inherited legacy colour operations")
    check(Catalog.source_pointer("catalog/condition_recipes.json", "/condition.hidden/persistent/alphaMultiplier", cache) == "res://authoring/abilities/conditions/condition.hidden.tres::look/steps/0/alpha", "Inspector resolves selected opacity to its authored property")
    check(Catalog.source_pointer("catalog/condition_recipes.json", "/condition.hidden/relationships", cache) == "catalog/condition_recipes.json:/condition.hidden/relationships", "Inherited relationship retains its actual source pointer")
    var rigs = Characters.rigs(cache)
    var sources:Dictionary = BodySources.index(cache).sheets
    var action:Dictionary=Catalog.read_file("catalog/body_action_recipes.json",cache)["action.hide"]
    check(action.actor.enabled and action.actor.clip=="CrouchIdle" and action.anchors[1].frame==15,
        "Hide selects a finite authored action and its condition effect boundary")
    check(action.effectAudioCue=="hide_transition", "Hide selects its transition sound at the action effect")
    check(Catalog.source_pointer("catalog/body_action_recipes.json","/action.hide/actor/clip",cache)=="res://authoring/abilities/actions/action.hide.tres::body/clip",
        "Action source preview links to the authored clip property")
    var hide_entry: Resource = load("res://authoring/abilities/actions/action.hide.tres")
    check(hide_entry != null and hide_entry.body.clip == "CrouchIdle" and hide_entry.unported.anchors[1].name == "effect" and hide_entry.unported.anchors[1].frame == 15 and hide_entry.body.rig == "neuroclient.modular",
        "The abilities source holds Hide's crouch body and effect marker")
    for name in ["CrouchIdle", "CrouchRun"]:
        var clip: Dictionary = rigs["neuroclient.modular"].clips.get(name, {})
        check(not clip.is_empty(), "Adopted source clip available: " + name)
        if clip.is_empty(): continue
        check(clip.frames == 15 and clip.fps == 12, "Crouch has real frame count and explicitly adopted rate: " + name)
        for path in clip.sheets.values():
            check(sources.has(path) and FileAccess.file_exists(str(sources.get(path,{}).get("default",""))), "Registered source exists: " + path)
    check(cache.get("native_authoring_errors", []).is_empty(), "All native source definitions are valid")
    # Reload isolation: a candidate abilities build in a temporary folder.
    var directory = "res://.runtime/native-authoring-reload"
    var build_root = directory.path_join("abilities")
    var conditions: Dictionary = recipes.duplicate(true)
    var actions: Dictionary = Catalog.read_file("catalog/body_action_recipes.json", cache).duplicate(true)
    var previous = ProjectSettings.get_setting("source_data/abilities_build", AbilityDocuments.ROOT)
    # The candidate build keeps the current native spell records.
    DirAccess.make_dir_recursive_absolute(build_root.path_join("native_spells"))
    var marker := FileAccess.open(build_root.path_join("native_spells/current"), FileAccess.WRITE)
    marker.store_string(FileAccess.get_file_as_string(AbilityDocuments.ROOT.path_join("native_spells/current")));marker.close()
    check(save_table(build_root, "catalog/body_action_recipes.json", actions), "Candidate action table saves through Godot")
    conditions["condition.hidden"].persistent.alphaMultiplier = 0.3
    check(save_table(build_root, "catalog/condition_recipes.json", conditions), "First built candidate saves")
    ProjectSettings.set_setting("source_data/abilities_build", build_root)
    Catalog.invalidate_source_indexes()
    var first_cache = {}
    var first = Catalog.read_file("catalog/condition_recipes.json", first_cache)["condition.hidden"]
    conditions["condition.hidden"].persistent.alphaMultiplier = 0.7
    check(save_table(build_root, "catalog/condition_recipes.json", conditions), "Edited built candidate saves")
    Catalog.invalidate_source_indexes()
    var second_cache = {}
    var second = Catalog.read_file("catalog/condition_recipes.json", second_cache)["condition.hidden"]
    check(is_equal_approx(first.persistent.alphaMultiplier, 0.3) and is_equal_approx(second.persistent.alphaMultiplier, 0.7), "Reload reads the rebuilt record while the displayed recipe stays immutable")
    check(is_equal_approx(hidden.persistent.alphaMultiplier, 0.55), "Another recording's selected source stays unchanged")
    Catalog.validate_native(first_cache)
    var worker_snapshot=Catalog.source_snapshot(first_cache)
    ProjectSettings.set_setting("source_data/abilities_build",directory.path_join("not-built"))
    Catalog.invalidate_source_indexes()
    var worker=Thread.new()
    worker.start(func():return {"errors":Catalog.validate_native(worker_snapshot),
        "opacity":Catalog.read_file("catalog/condition_recipes.json",worker_snapshot)["condition.hidden"].persistent.alphaMultiplier,
        "clip":Characters.rigs(worker_snapshot)["neuroclient.modular"].clips.CrouchRun})
    var worker_result:Dictionary=worker.wait_to_finish()
    check(worker_result.errors.is_empty() and is_equal_approx(worker_result.opacity,0.3) and worker_result.clip.frames==15,
        "Worker uses admitted source snapshot despite subsequent rebuilds and a missing new build")
    ProjectSettings.set_setting("source_data/abilities_build",build_root)
    var valid_pose: Dictionary = conditions["condition.hidden"].persistent.activityPoses[0].duplicate()
    for invalid in ["missing_clip", "missing_rig", "held_frame"]:
        var pose: Dictionary = valid_pose.duplicate()
        pose.clip="AbsentClip" if invalid=="missing_clip" else "CrouchIdle"
        pose.rigId="absent.rig" if invalid=="missing_rig" else "neuroclient.modular"
        pose.sampling="hold" if invalid=="held_frame" else "loop"
        pose.frame=15.0 if invalid=="held_frame" else 0.0
        conditions["condition.hidden"].persistent.activityPoses[0]=pose
        save_table(build_root, "catalog/condition_recipes.json", conditions)
        Catalog.invalidate_source_indexes()
        check(not Catalog.validate_native({}).is_empty(), "Invalid built pose rejected: "+invalid)
        check(is_equal_approx(first.persistent.alphaMultiplier,0.3), "Invalid candidate leaves previous authored snapshot intact: "+invalid)
    conditions["condition.hidden"].persistent.activityPoses[0]=valid_pose
    # Invalid source values are the build's to reject (the old overlay checked them at load).
    for invalid in ["missing_clip", "missing_rig", "held_frame", "invalid_speed"]:
        var candidate: Resource = entry.duplicate(true)
        var pose: Dictionary = candidate.poses[0].duplicate()
        pose.clip="AbsentClip" if invalid=="missing_clip" else "CrouchIdle"
        pose.rig="absent.rig" if invalid=="missing_rig" else "neuroclient.modular"
        pose.sampling="hold" if invalid=="held_frame" else "loop"
        pose.frame=15 if invalid=="held_frame" else 0
        pose.playback_speed=NAN if invalid=="invalid_speed" else 1.0
        candidate.poses[0]=pose
        var report: Dictionary = Common.report()
        Builder._validate_rigs({"conditions": {"condition.hidden": candidate}}, report)
        check(not report.errors.is_empty(), "The build rejects an invalid source pose: "+invalid)
    check(save_table(build_root, "catalog/condition_recipes.json", Gradient.new()), "A wrong resource type saves in place of the table")
    Catalog.invalidate_source_indexes()
    check(not Catalog.validate_native({}).is_empty(), "Wrong Resource type cannot silently become an empty catalog")
    DirAccess.remove_absolute(AbilityDocuments.file("catalog/condition_recipes.json"))
    Catalog.invalidate_source_indexes()
    var missing_cache = {}
    Catalog.read_file("catalog/condition_recipes.json", missing_cache)
    check(not missing_cache.get("native_authoring_errors", []).is_empty(), "A missing built table reports an authoring failure instead of claiming legacy success")
    Catalog.validate_native(missing_cache)
    check(not Catalog.validate_native(Catalog.source_snapshot(missing_cache)).is_empty(), "Worker snapshot preserves source rejection instead of silently accepting fallback values")
    save_table(build_root, "catalog/condition_recipes.json", recipes.duplicate(true))
    Catalog.invalidate_source_indexes()
    var action_cache={}
    check(Catalog.validate_native(action_cache).is_empty(),"Native action candidate admits its real source and terminal marker")
    var action_snapshot=Catalog.source_snapshot(action_cache)
    for invalid in ["missing_clip","missing_rig","late_effect"]:
        var candidate: Dictionary = actions.duplicate(true)
        var hide: Dictionary = candidate["action.hide"]
        hide.actor.clip="AbsentClip" if invalid=="missing_clip" else "CrouchIdle"
        hide.rigId="absent.rig" if invalid=="missing_rig" else "neuroclient.modular"
        hide.anchors[1].frame=16.0 if invalid=="late_effect" else 15.0
        save_table(build_root, "catalog/body_action_recipes.json", candidate)
        Catalog.invalidate_source_indexes()
        check(not Catalog.validate_native({}).is_empty(),"Invalid built body action rejected: "+invalid)
        var retained:Dictionary=Catalog.read_file("catalog/body_action_recipes.json",action_snapshot)["action.hide"]
        check(Catalog.validate_native(action_snapshot).is_empty() and retained.actor.clip=="CrouchIdle" and retained.anchors[1].frame==15 and retained.actor.playbackSpeed==3.0,
            "Rejected action source does not replace admitted body/effect clock: "+invalid)
    for invalid in ["missing_clip","missing_rig","late_effect","invalid_speed"]:
        var candidate: Resource = hide_entry.duplicate(true)
        candidate.body.clip="AbsentClip" if invalid=="missing_clip" else "CrouchIdle"
        candidate.body.rig="absent.rig" if invalid=="missing_rig" else "neuroclient.modular"
        candidate.body.markers["effect"]=16.0 if invalid=="late_effect" else 15.0
        candidate.body.playback_speed=NAN if invalid=="invalid_speed" else 3.0
        var report: Dictionary = Common.report()
        Builder._validate_rigs({"actions": {"action.hide": candidate}}, report)
        check(not report.errors.is_empty(), "The build rejects an invalid source action: "+invalid)
    # Actual typed body source controls, independent of the current build.
    # These are publication/inspection operands, not recorded render evidence.
    var source:Resource=load("res://authoring/abilities/actions/action.earth_elemental.soil_clogged_slam.tres")
    var body_source:Dictionary=Builder.R.action_recipe(source)
    check(body_source.actor.enabled and body_source.actor.clip==source.body.clip and body_source.rigId==source.body.rig,
        "The real intrinsic body emits its exact selected clip and rig")
    check(body_source._resource_source==source.resource_path and body_source._source_fields["actor/clip"]==source.resource_path+"::body/clip" \
        and body_source._source_fields.rigId==source.resource_path+"::body/rig",
        "New typed body fields preserve their editable source without imported overlay metadata")
    var markerless:Dictionary=Catalog.source_snapshot(action_snapshot)
    markerless.erase("native_references_validated")
    markerless["catalog/body_action_recipes.json"]={source.id:Builder.provenance(body_source,source.resource_path)}
    check(source.body.markers.is_empty() and not body_source.has("anchors") and Catalog.validate_native(markerless).is_empty(),
        "The actual selected markerless body validates without inventing anchors or changing its source duration")
    var before:Dictionary=source.unported.duplicate(true)
    var imported:Resource=source.duplicate(true)
    imported.unported={"actor":{"clip":"PreservedRawClip"},"_source_fields":{"actor/clip":"exact-original-source:/actor/clip"}}
    var retained:Dictionary=Builder.R.action_recipe(imported)
    retained=Builder.provenance(retained,source.resource_path)
    check(retained.actor.clip=="PreservedRawClip" and retained._source_fields["actor/clip"]=="exact-original-source:/actor/clip" \
        and source.unported==before,"A retained raw field and source are not relabeled as a typed override")
    for mode in ["missing_disposition","authored","disabled","empty_clip"]:
        var candidate:Resource=source.duplicate(true);candidate.disposition="authored" if mode=="authored" else ""
        if mode=="disabled":candidate.body.enabled=false
        if mode=="empty_clip":candidate.body.clip="";candidate.body.rig=""
        var admission:Dictionary=Common.report()
        Builder._validate({"actions":{candidate.id:candidate}},admission)
        var omissions:Array=admission.errors.filter(func(error):return "selected enabled body requires an explicit disposition" in error)
        check(omissions.size()==(1 if mode=="missing_disposition" else 0),"Publication rejects only the actual omitted enabled body decision: "+mode)
    var spell_source:Resource=load("res://authoring/abilities/spells/spell.fog_cloud.tres")
    var spell_body:Dictionary=Builder.raw_recipe(spell_source)
    check(spell_body._source_fields["cast/actionClip"]==spell_source.resource_path+"::body/clip" \
        and spell_body.cast.actionClip==spell_source.body.clip,"Shared spell cast body retains the exact typed source key")
    ProjectSettings.set_setting("source_data/abilities_build", previous)
    Catalog.invalidate_source_indexes()
    for path in ["catalog/condition_recipes.json", "catalog/body_action_recipes.json"]:
        DirAccess.remove_absolute(build_root.path_join("docs").path_join(path.get_basename() + ".res"))
    DirAccess.remove_absolute(build_root.path_join("native_spells/current"))
    var report = {"checks":checks, "failures":failures, "scope":"Native source selection, installed crouch sheets, exact provenance and candidate reload isolation; no pixel-rendering claim."}
    FileAccess.open("res://generated/native_authoring_checks.json", FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
    print("NATIVE_AUTHORING ", JSON.stringify(report))
    quit(0 if failures.is_empty() else 1)
