extends SceneTree
## Production Play/Timeline/WorldPreparation admission with real texture/image
## publications. Fixed source metadata replaces disk/network discovery only.
const Player=preload("res://play.gd")
const Preparation=preload("res://presentation/world_preparation.gd")
const Media=preload("res://presentation/media_warmup.gd")
const WorldRows=preload("res://presentation/world.gd")
const EnvironmentMedia=preload("res://presentation/environment_media.gd")
const CURRENT="/fixture/current-view.png"
const OTHER="/fixture/other-view.png"
const FLAME="/fixture/current-flame.png"
var checks:int=0
var failures:Array=[]

class Host extends Player:
    func _ready()->void:
        set_process(false);set_process_unhandled_input(false)
        attach_media_sources();add_child(context_menu)
        camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;add_child(camera)
        generated_shadows.attach(self)
        timeline.media_ready=_media_ready;timeline.world_ready=_world_ready
    func _process(_delta:float)->void:pass
    func _prepare_media(_first:Dictionary={})->void:pass # Fixed admitted plan below.
    func _native_startup_ready(_at_ms:float)->bool:return true # No spells in this fixture.

func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("LIVE_ENVIRONMENT_ADMISSION_FAIL ",label)

func resource(path:String)->Dictionary:
    return {"path":path,"native_size":[2,2],"pivot":[1,2],"scale":1.0,"roles":[]}

func source_cache(fixture:bool)->Dictionary:
    var prop={"body_by_pose":{"n":"other","e":"current","s":"other","w":"other"}}
    if fixture:prop.lit_animation="test.flame"
    return {"res://build/presentation/environment/world.res":{"terrain":{},"props":{"test.prop":prop},"wall_corner_faces":{}},
        "res://build/presentation/environment/index.res":{"doors":{},"props":{},"traps":{}},
        "res://build/presentation/environment/resources.res":{"resources":{"current":resource(CURRENT),"other":resource(OTHER),"flame":resource(FLAME)},
            "animations":{"test.flame":{"frames":["flame"],"fps":1.0}}},
        "res://build/presentation/environment/texture_layouts.res":{"layouts":{}}}

func state_before()->Dictionary:
    return {"actors":{},"tiles":{},"objects":{},"spatial_commit_cursors":{},"combat_log_appends":[],
        "senses":{"visible":[],"objects":{},"light_sources":{},"spatial_effects":{}}}

func group(fixture:bool)->Dictionary:
    var object={"placement":{"kind":"cell","position":[0,0],"base_height_steps":0,"orientation":"east"},
        "item":{"item_id":"test.prop","is_lit":fixture}}
    var sight={"visible":[[0,0]],"objects":{"new":{"visual":true}},"light_sources":{},"spatial_effects":{}}
    var event={"id":"1:cut","event_uuid":"cut","sequence":1,"source_index":0,
        "components":[],"status":"state_only","reasons":[],"committed":false,"completed":false,
        "_log":null,"_admit_ms":10.0,"_end_ms":10.0}
    # The unavailable cue tests Timeline crossing only, not audio asset quality.
    var audio={"id":"cut-audio","kind":"audio","status":"missing","start_ms":10.0,"duration_ms":1.0}
    return {"id":"fixture-cut","operation_sequence":1,"operation_end":true,"duration_ms":20.0,
        "actor_tracks":[],"events":[event],"components":[audio],"native_requirements":[],
        "commits":[{"at_ms":10.0,"event_uuid":"cut","delta":{"objects":{"new":object},"set":{"senses":sight}}}]}

func publication(host:Host,path:String,image:Image,cpu:bool,facts:bool=false)->void:
    host.textures[path]=ImageTexture.create_from_image(image)
    if cpu:host.source_images[path]=image
    else:host.source_images.erase(path)
    var loaded={"path":path,"cpu_bytes":image.get_data_size() if cpu else 0,"gpu_bytes":image.get_data_size()}
    if facts:
        host.fixture_frame_energy[path]=1.0;host.fixture_frame_centroids[path]=Vector2(1,1)
        loaded.energy=1.0;loaded.emission_centroid=Vector2(1,1)
    Media.published(host.media_warmup,loaded)

func held_snapshot(host:Host)->PackedByteArray:
    return var_to_bytes([host.timeline.state,host.timeline.trace,host.timeline.crossed_audio,host.timeline.component_sample_ms,
        host.timeline.display_ms,host.timeline.sequence,host.timeline.commit_index])

func bounded_prepare(host:Host,frames:int)->void:
    for frame in frames:
        host._step_world_preparation()
        if host.pending_world.prepared or not host.pending_world.media_issue.is_empty():return
        await process_frame

func exercise(fixture:bool)->void:
    var host=Host.new();host.catalog_cache=source_cache(fixture)
    host.rig_config={"TILE_W":128.0,"FACING_CYCLE":["SW"]};host.rigs={};host.resources={}
    root.add_child(host)
    host.timeline.accept({"kind":"initialization","state":state_before(),"sequence":0})
    host.world_revision=host.timeline.world_revision;host.world_prepare_epoch=host.timeline.initialization_revision
    host.world_quarter=0;host.quarter=0;host.world_generation=1;host.media_metadata_ready=true
    WorldRows.update_rows(host.timeline.state,host.catalog_cache,host.world_row_cache,{"full":true})
    # The already displayed empty world completed its real startup admission.
    # The received operation below is not part of that historical boot lease.
    Media.adopt_required(host.media_warmup,host.timeline.initialization_revision)
    Media.demand(host.media_warmup,{})
    check(Media.boot_ready(host.media_warmup),"Already displayed world has completed its empty startup source cut")
    var action:Dictionary=group(fixture)
    host.timeline.accept({"kind":"operation","groups":[action],"sequence":1})
    var target:Dictionary=host.timeline.preview_world()
    check(not target.is_empty() and target.display_ms==10.0,"Real Timeline forecasts exact environment cut")
    var paths:Dictionary={CURRENT:true,OTHER:true}
    var fixtures:Dictionary={}
    if fixture:paths[FLAME]=true;fixtures[FLAME]=true
    Media.demand(host.media_warmup,paths,paths,fixtures)
    host.media_environment_required=paths
    host.media_group_plans[action.id]={"character":{},"environment":paths,"errors":[],
        "environment_timeline":{"initial":paths,"changes":[]}}
    host.media_plan_key=[host.timeline.initialization_revision,[action.id],0]
    var image=Image.create(2,2,false,Image.FORMAT_RGBA8);image.fill(Color.WHITE)
    publication(host,CURRENT,image,fixture)
    if fixture:publication(host,FLAME,image,true)
    check(not Media.ready(host.media_warmup,paths),"Other quarter deliberately remains unready")
    host.timeline.advance(0)
    if host.timeline.waiting_for_media:
        printerr("LIVE_ENVIRONMENT_GATE_DIAGNOSTIC ",JSON.stringify({"gate":host.media_gate,"issues":host.presentation_errors,
            "native":host.component_renderer.readiness,"source_issue":host.media_issue,"metadata":host.media_metadata_ready,
            "world_revision":host.world_revision,"epoch":host.world_prepare_epoch,"timeline_epoch":host.timeline.initialization_revision}))
    check(not host.timeline.waiting_for_media and not host.timeline.current.is_empty(),
        "Actual Play media callback starts live action without the unused quarter")
    var candidate=Preparation.new();host.add_child(candidate);host.pending_world=candidate
    candidate.configure(host,target)
    await bounded_prepare(host,30)
    check(candidate.media_issue.is_empty() and not candidate.prepared,"Missing exact constructor operand leaves a pending owner")
    var blocked:String="missing_fixture_facts" if fixture else "missing_environment_image"
    check(candidate.blocked_source.get("status")==blocked,"Actual constructor reports exact missing CPU/fact operand")
    var before:PackedByteArray=held_snapshot(host)
    host.timeline.advance(10)
    check(host.timeline.waiting_for_world and held_snapshot(host)==before,
        "Exact missing operand holds canonical state, event trace, audio crossing and clock")
    check(host.static_entries.is_empty() and candidate.entries.all(func(entry):return not entry.node.is_visible_in_tree()),
        "Unready future native resources cannot publish displayed membership")
    publication(host,FLAME if fixture else CURRENT,image,true,fixture)
    await bounded_prepare(host,180)
    check(candidate.media_issue.is_empty() and candidate.prepared,"Exact operand arrival completes actual native world preparation")
    check(not host.textures.has(OTHER) and not Media.ready(host.media_warmup,paths),"Other view stays unloaded after current-view preparation")
    if candidate.prepared:
        host.timeline.advance(10)
        check(not host.timeline.waiting_for_world and host.timeline.display_ms==10.0 and host.timeline.state.objects.has("new"),
            "Same authoritative cut publishes while another camera view remains missing")
        check(host.timeline.trace.rows.get("1:cut",{}).get("committed",false),"Event commits only with its prepared world cut")
        check(host.timeline.component_samples(host.catalog_cache).any(func(row):return row.id=="cut-audio"),
            "Audio cue first becomes eligible at the admitted cut")
    var published_revision:int=host.world_revision
    host.world_revision=-1
    check(not host._media_ready(action) and not host.media_gate.environment,"Initial world retains exhaustive environment admission")
    host.world_revision=published_revision;host.external_playback=true
    check(not host._media_ready(action) and not host.media_gate.environment,"Replay retains exhaustive environment admission")
    check(not host._prepared_world_sources_ready({"replay":true,"replay_groups":[action]}),
        "Replay world-prefix gate cannot use the live selected-source exception")
    host.external_playback=false
    var old_quarter:int=host.quarter;var old_transform:Transform3D=host.camera.transform
    host.request_view(1)
    check(host.pending_view==null and host.quarter==old_quarter and host.camera.transform==old_transform,
        "Rotation cannot construct or replace the view while its exhaustive source gate is missing")
    check(candidate.media_issue.is_empty() and host.presentation_errors.is_empty(),"No missing-source fallback or presentation error")
    host.queue_free();await process_frame;await process_frame

func run()->void:
    create_timer(25).timeout.connect(func():printerr("LIVE_ENVIRONMENT_ADMISSION_DEADLINE");quit(2))
    await exercise(false);await exercise(true)
    var report={"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),
        "scope":"Actual Play media/world callbacks, Timeline event/audio fence and native WorldPreparation with in-memory authored fixture and real ImageTextures. Missing other-view sources stay optional for live cuts; exact CPU originals and fixture metrics remain required; boot/replay/rotation retain full admission. No latency or framebuffer claim."}
    FileAccess.open("res://generated/live_environment_admission_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("LIVE_ENVIRONMENT_ADMISSION_CHECKS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
