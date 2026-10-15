extends SceneTree
## Real Gallery source closure: actual outfit slots, preserved pixels/budget.
const Recording=preload("res://studio/recording.gd")
const RecordingMedia=preload("res://studio/recording_media.gd")
const Media=preload("res://presentation/media_warmup.gd")
const Support=preload("res://presentation/native_scene_support.gd")
const Geometry=preload("res://presentation/character_geometry.gd")
const Characters=preload("res://presentation/characters.gd")
const Catalog=preload("res://source_catalog.gd")
var checks:int=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr(label)
func run()->void:
    var descriptor:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://generated/studio_gallery_spell_case.json"))
    var bundle=Recording.compare_case(Recording.read_case(descriptor))
    check(bundle.get("ok",false),"Actual Gallery recording admits")
    if not bundle.get("ok",false):quit(1);return
    var index=Recording.view_index(bundle,"amber")
    var original:PackedByteArray=var_to_bytes([index.initialization,index.groups])
    var plan:Dictionary=RecordingMedia.plan(index)
    check(plan.errors.is_empty(),"Exact recorded source closure has no missing assets")
    var geometry:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Geometry.TABLE))
    var expected:Dictionary={};var slots:Dictionary={}
    for path in plan.paths:
        var record:Dictionary=geometry.records.get(path,{})
        if not record.has("reference"):continue
        # Independent oracle: the registered source packet names its channels
        # and allowed slots. It does not repeat MediaWarmup's slot resolution.
        var root_path:String=ProjectSettings.get_setting("source_data/character_geometry_root")
        var paths:Array=[path,root_path.path_join(record.files.depth),root_path.path_join(record.files.support),root_path.path_join(record.reference).get_base_dir().path_join("solid-valid.png")]
        for slot in record.slots:slots[slot]=true
        for required in paths:
            expected[required]=true
            check(plan.paths.has(required),"Recorded closure includes exact optical packet: "+required)
            check(plan.cpu_required.has(required) and not plan.gpu_only.has(required),"Required socket pixels cannot be released as GPU-only: "+required)
    check(slots.has("chest") and slots.has("legs") and slots.has("head") and slots.has("weapon"),"Actual recording covers distinct modular slots, not only body")
    check(expected.size()>200,"Actual recording exercises the complete modular optical closure")
    var live=Media.create();live.encounter_override=plan;Media.adopt_required(live,1)
    Media.demand(live,plan.priority)
    check(live.preload_selected.size()==plan.paths.size() and live.preload_skipped==0,"Actual complete source set fits the unchanged configured budget")
    # Publish passive residency receipts at exact header byte sizes. GPU pixels
    # are qualified by ordinary native replay; this checks roles and accounting.
    for path in plan.paths:
        var estimate:Dictionary=plan.estimates[path]
        Media.published(live,{"path":path,"cpu_bytes":estimate.cpu_bytes,"gpu_bytes":estimate.gpu_bytes,"energy":1.0,"emission_centroid":Vector2.ZERO})
    Media.demand(live,plan.priority)
    var initial_decoded:int=live.decoded;var resident_count:int=live.resident.size();var max_pending:int=0
    var groups:Array=index.groups.map(func(row):return row.group)
    for at in groups.size():
        var first:Dictionary=plan.group_plans[groups[at].id]
        var next:Dictionary=plan.group_plans[groups[at+1].id] if at+1<groups.size() else {}
        var wanted:Dictionary=first.character.duplicate();wanted.merge(first.environment)
        var environment:Dictionary=first.environment.duplicate();var fixtures:Dictionary=first.fixtures.duplicate()
        var cpu:Dictionary=first.cpu_required.duplicate();var gpu:Dictionary=first.gpu_only.duplicate()
        for field in ["character","environment"]:wanted.merge(next.get(field,{}))
        environment.merge(next.get("environment",{}));fixtures.merge(next.get("fixtures",{}))
        cpu.merge(next.get("cpu_required",{}));gpu.merge(next.get("gpu_only",{}))
        for path in cpu:gpu.erase(path)
        for path in wanted:wanted[path]=Catalog.media_path(path)
        Media.demand(live,wanted,environment,fixtures,gpu,cpu)
        Media.release_cold_images(live,-1)
        check(Media.ready(live,first.character),"Every exact recorded current group stays ready after optional CPU releases: "+str(at))
        check(expected.keys().all(func(path):return live.resident[path].cpu_bytes>0),"All recorded socket owners retain their actual CPU pixels: "+str(at))
        max_pending=maxi(max_pending,live.pending.size())
    check(max_pending==0 and live.decoded==initial_decoded and live.resident.size()==resident_count,"Changing real group roles never requeues already admitted optical sources")
    check(Media.prune(live).is_empty(),"Exact retained source set does not require eviction under configured budget")
    check(var_to_bytes([index.initialization,index.groups])==original,"Source preparation preserves canonical recording and compiled groups")
    var capped=Media.create();capped.encounter_override=plan;capped.budget_bytes=0;Media.adopt_required(capped,1);Media.demand(capped,plan.priority)
    check(capped.preload_selected.size()==plan.priority.size() and capped.preload_skipped==plan.paths.size()-plan.priority.size(),"Zero optional budget still selects only mandatory sources")
    var report={"checks":checks,"failures":failures,"groups":groups.size(),"sources":plan.paths.size(),"cpu_sources":plan.cpu_required.size(),"optical_sources":expected.size(),"slots":slots.keys(),"estimated_bytes":plan.estimate_summary.bytes,"maximum_pending_after_role_changes":max_pending,"scope":"Real Gallery metadata and exact residency accounting; no mocked ready verdict or fabricated game facts. Native normal-clock hold qualification is separate."}
    Media.close(live);Media.close(capped)
    FileAccess.open("res://.runtime/native-optical-media-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_OPTICAL_MEDIA_CHECKS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
