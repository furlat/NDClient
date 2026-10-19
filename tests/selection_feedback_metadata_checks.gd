extends SceneTree
const Protocol=preload("res://sdk/protocol.gd")
const Reducer=preload("res://sdk/reducer.gd")
const Selection=preload("res://presentation/selection_media.gd")
const NativeSpells=preload("res://presentation/native_spell_authoring.gd")
const Sources=preload("res://presentation/native_presentation_sources.gd")
const Catalog=preload("res://source_catalog.gd")
var checks=0
var failures=[]
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("SELECTION_FEEDBACK_METADATA_FAIL ",label)
func _initialize()->void:run.call_deferred()
func run()->void:
    var directory="";var oracle_path=""
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--recording="):directory=arg.trim_prefix("--recording=")
        if arg.begins_with("--selection-oracle="):oracle_path=arg.trim_prefix("--selection-oracle=")
    if directory.is_empty() or oracle_path.is_empty():printerr("Requires actual journal and frozen selection oracle");quit(2);return
    var oracle=load(oracle_path);var protocol=Protocol.new()
    var decoded=protocol.decode("InitializationResponse",FileAccess.get_file_as_bytes(directory+"/0000000000000000.json"))
    check(decoded.ok,"Actual initialization strictly admits")
    var packet=protocol.normalize("InitializationResponse",decoded.value)
    var state:Dictionary=Reducer.reduce_initialization(packet.initialization,packet.content_additions).value
    state=state.duplicate();state.tiles={}
    var source=var_to_bytes(state)
    var evidence=[]
    for behavior in ["spell.fireball","spell.mage_armor"]:
        var current_cache={};var old_cache={}
        var request={"state":state,"actor_uuid":state.audience.controlled[0],"behavior":behavior,"budget_bytes":17179869184,"profile":"reference"}
        var control={"mutex":Mutex.new(),"cancelled":false}
        var actual=Selection.plan(request,current_cache,control)
        var expected:Dictionary=oracle.plan(request,old_cache,control)
        var damage:bool=NativeSpells.recipe({"behavior_id":behavior},current_cache).get("damage")!=null
        check(damage==(behavior=="spell.fireball"),"Delivered authoring selects damaging/non-damaging branches")
        check(not current_cache.has("catalog/action_media_assets.json"),"Selection never reads the full legacy asset document")
        check(not Catalog.prepared_residue_asset(actual.source_files).is_empty()==damage,"Only damaging selection hands off its admitted feedback operand")
        var current_fields=actual.duplicate();var old_fields=expected.duplicate()
        current_fields.erase("source_files");old_fields.erase("source_files")
        check(current_fields==old_fields,"All final paths/roles/sizes/native metadata/budget/errors remain exactly equal: "+behavior)
        for field in ["paths","cpu_required","gpu_only","environment","source_sizes","source_headers","normal_sets"]:
            check(actual[field].keys()==expected[field].keys(),"Exact field insertion order "+behavior+"/"+field)
        var current_sources:Dictionary=actual.source_files.duplicate()
        var expected_sources:Dictionary=expected.source_files.duplicate()
        expected_sources.erase("catalog/action_media_assets.json")
        # The frozen oracle reads the legacy environment documents; compare the rest.
        for key in current_sources.keys():
            if key.begins_with(Catalog.ENVIRONMENT):current_sources.erase(key)
        for key in ["world.json","assets.json","environment/index.json","res://generated/environment_receiving_normals.json","res://generated/environment_texture_layouts.json"]:expected_sources.erase(key)
        for key in expected_sources.keys():
            if str(key).begins_with("environment/"):expected_sources.erase(key)
        var native_owner:Dictionary=expected_sources.get(Sources.CACHE_KEY,{})
        if not native_owner.is_empty():
            var native_loaded:Dictionary=native_owner.loaded.duplicate();native_loaded.erase("asset:particles.region.blood")
            expected_sources[Sources.CACHE_KEY]=Sources.make_admission(native_owner.index,native_loaded)
        check(current_sources==expected_sources,"No unrelated source file changes: "+behavior)
        check(var_to_bytes(state)==source,"Canonical disclosed input remains immutable")
        evidence.append({"behavior":behavior,"damage":damage,"paths":actual.paths.size(),"prepared_feedback_asset":not Catalog.prepared_residue_asset(actual.source_files).is_empty()})
    var result={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Real admitted initial actor and delivered damaging/non-damaging authoring: same complete selection metadata, exact source path/role order, feedback-only document prewarm and immutable state; no submitted action/outcome prediction/GPU"}
    FileAccess.open("res://.runtime/selection-feedback-metadata-checks.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("SELECTION_FEEDBACK_METADATA_CHECKS ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
