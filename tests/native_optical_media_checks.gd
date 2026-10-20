extends SceneTree
## Real Gallery source closure: actual outfit slots, preserved pixels/budget.
const Recording=preload("res://studio/recording.gd")
const RecordingMedia=preload("res://studio/recording_media.gd")
const Media=preload("res://presentation/media_warmup.gd")
const Support=preload("res://presentation/native_scene_support.gd")
const Geometry=preload("res://presentation/character_geometry.gd")
const Characters=preload("res://presentation/characters.gd")
const Catalog=preload("res://source_catalog.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
var checks:int=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr(label)
func run()->void:
    var descriptor:Dictionary=Fixtures.case_record("gallery")
    var bundle=Recording.compare_case(Recording.read_case(descriptor))
    check(bundle.get("ok",false),"Actual durable schema16 Gallery recording admits: "+str(bundle.get("error",{})))
    if not bundle.get("ok",false):quit(1);return
    var index=Recording.view_index(bundle,"amber")
    var original:PackedByteArray=var_to_bytes([index.initialization,index.groups])
    var plan:Dictionary=RecordingMedia.plan(index)
    check(plan.errors.is_empty(),"Exact recorded source closure has no missing assets")
    var geometry:Dictionary={"records":preload("res://tests/built_body_records.gd").records(index.cache)}
    var expected:Dictionary={};var colours:Dictionary={};var companions:Dictionary={};var metadata_only:Dictionary={};var slots:Dictionary={};var baked:int=0
    for path in plan.paths:
        var record:Dictionary=geometry.records.get(path,{})
        if not record.has("reference"):continue
        # Independent oracle: the registered source packet names its channels
        # and allowed slots. It does not repeat MediaWarmup's slot resolution.
        var root_path:String=Geometry._root(record)
        var paths:Array=[path,root_path.path_join(record.files.depth),root_path.path_join(record.files.support)]
        var solid:String=root_path.path_join(record.reference).get_base_dir().path_join("solid-valid.png")
        for slot in record.slots:slots[slot]=true
        # The native descriptor carries measured socket samples independently
        # of sheet residency. Original colour still owns CPU picking; with
        # those baked operands depth/support/solid never need full-sheet CPU
        # reads for sockets. Keep the exact descriptor/file closure oracle.
        var optical_descriptor:Dictionary=Geometry.BodySources.descriptor(path,str(record.slots[0]),index.cache)
        var measured:bool=optical_descriptor.get("sockets",{}).get("valid",false)
        check(measured and not optical_descriptor.sockets.samples.is_empty(),"Original Gallery optical source has its admitted measured socket samples: "+path)
        if measured:baked+=1
        colours[path]=true
        # A normal is a selected shader input. Solid validity is different:
        # measured socket lookup alone needs no image, while an actual native
        # receiver still requests its exact solid mask through its group plan.
        var selected_normals:Array=optical_descriptor.normal_paths.values().filter(func(normal):return plan.paths.has(normal))
        check(not selected_normals.is_empty(),"Actual colour has its selected normal source in the recorded image closure: "+path)
        paths.append_array(selected_normals)
        var solid_owner:bool=plan.group_plans.values().any(func(group):return group.character.has(solid))
        check(plan.paths.has(solid)==solid_owner,"Solid image residency follows an actual native receiving group, not socket metadata: "+solid)
        if solid_owner:
            paths.append(solid)
        else:
            metadata_only[solid]={"colour":path,"reason":"baked_socket_samples_no_image_consumer"}
            check(not plan.cpu_required.has(solid) and not plan.gpu_only.has(solid) and not plan.priority.has(solid),"Socket-only solid metadata creates no CPU/GPU image role: "+solid)
        for required in paths:
            expected[required]=true
            check(plan.paths.has(required),"Recorded closure includes exact optical packet: "+required)
            if required==path:
                check(plan.cpu_required.has(required) and not plan.gpu_only.has(required),"Original colour retains CPU picking ownership: "+required)
            else:
                companions[required]=true
                check(plan.gpu_only.has(required) and not plan.cpu_required.has(required),"Measured geometry companion is GPU-only, without a full-sheet socket read: "+required)
    check(slots.has("chest") and slots.has("legs") and slots.has("head") and slots.has("weapon"),"Actual recording covers distinct modular slots, not only body")
    check(expected.size()>200,"Actual recording exercises the complete modular optical closure")
    var live=Media.create();live.encounter_override=plan;live.plan_cache=Catalog.source_snapshot(plan.source_files);Media.adopt_required(live,1)
    var physical:Dictionary=Media.physical(live)
    Media.demand(live,plan.priority,plan.environment,plan.fixtures,plan.gpu_only,plan.cpu_required)
    var deadline:int=Time.get_ticks_msec()+30000
    while Media.diagnostics(live).selection_pending and Time.get_ticks_msec()<deadline:
        Media.prepare_optional(live)
        await process_frame
    check(not Media.diagnostics(live).selection_pending,"Existing finite optional metadata selector completes before residency accounting")
    check(physical.preload_selected.size()==plan.paths.size() and physical.preload_skipped==0,"Actual complete physical source set fits the unchanged configured budget")
    # Publish passive residency receipts at exact header byte sizes. GPU pixels
    # are qualified by ordinary native replay; this checks roles and accounting.
    for path in plan.paths:
        var estimate:Dictionary=plan.estimates[path]
        Media.published(live,{"path":path,"cpu_bytes":estimate.cpu_bytes,"gpu_bytes":estimate.gpu_bytes,"energy":1.0,"emission_centroid":Vector2.ZERO})
    Media.demand(live,plan.priority,plan.environment,plan.fixtures,plan.gpu_only,plan.cpu_required)
    var initial_decoded:int=physical.decoded;var resident_count:int=physical.resident.size();var max_pending:int=0
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
        check(colours.keys().all(func(path):return int(physical.resident.get(path,{}).get("cpu_bytes",0))>0),"Original picking colours retain their admitted CPU pixels: "+str(at))
        check(companions.keys().all(func(path):return int(physical.resident.get(path,{}).get("cpu_bytes",-1))==0 and int(physical.resident.get(path,{}).get("gpu_bytes",0))>0),"Requested shader/receiver companions stay GPU-ready after unused CPU copies retire: "+str(at))
        check(metadata_only.keys().all(func(path):return not physical.resident.has(path) and not physical.queued.has(path)),"Baked-only socket metadata never queues or uploads an unused sheet: "+str(at))
        max_pending=maxi(max_pending,physical.pending.size())
    check(max_pending==0 and physical.decoded==initial_decoded and physical.resident.size()==resident_count,"Changing real group roles never requeues already admitted optical sources")
    check(Media.prune(live).is_empty(),"Exact retained source set does not require eviction under configured budget")
    check(var_to_bytes([index.initialization,index.groups])==original,"Source preparation preserves canonical recording and compiled groups")
    var capped=Media.create();capped.encounter_override=plan;capped.plan_cache=Catalog.source_snapshot(plan.source_files);capped.budget_bytes=0;Media.adopt_required(capped,1)
    var capped_physical:Dictionary=Media.physical(capped)
    Media.demand(capped,plan.priority,plan.environment,plan.fixtures,plan.gpu_only,plan.cpu_required)
    deadline=Time.get_ticks_msec()+30000
    while Media.diagnostics(capped).selection_pending and Time.get_ticks_msec()<deadline:
        Media.prepare_optional(capped)
        await process_frame
    check(not Media.diagnostics(capped).selection_pending,"Zero-budget source selection completes through the same bounded metadata owner")
    check(capped_physical.preload_selected.size()==plan.priority.size() and capped_physical.preload_skipped==plan.paths.size()-plan.priority.size(),"Zero optional budget still selects only mandatory sources")
    var report={"checks":checks,"failures":failures,"groups":groups.size(),"sources":plan.paths.size(),"cpu_sources":plan.cpu_required.size(),"optical_sources":expected.size(),"measured_socket_sources":baked,"picking_colours":colours.size(),"gpu_only_optical_companions":companions.size(),"metadata_only_socket_companions":metadata_only,"slots":slots.keys(),"estimated_bytes":plan.estimate_summary.bytes,"maximum_pending_after_role_changes":max_pending,"scope":"Real Gallery descriptors, measured socket operands and exact physical residency accounting; colour CPU picking and selected shader/receiver GPU companions retain independent roles. Baked socket-only solid masks have metadata but no image demand. Passive byte receipts do not qualify native uploads or output; normal-clock native hold qualification is separate."}
    Media.close(live);Media.close(capped)
    FileAccess.open("res://.runtime/native-optical-media-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_OPTICAL_MEDIA_CHECKS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
