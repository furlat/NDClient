extends SceneTree
## Exercise real preparation/retirement ownership at a spent frame allowance.
## Actual playback wait counts remain the separate performance acceptance.
const Player=preload("res://play.gd")
const Preparation=preload("res://presentation/world_preparation.gd")
var checks:int=0
var failures:Array=[]

class Host extends Player:
    func _ready()->void:
        set_process(false);set_process_unhandled_input(false);external_playback=true
        add_child(context_menu);camera=Camera3D.new();add_child(camera)
    func _process(_delta:float)->void:pass

class PendingHUD extends Control:
    var host:Host
    var slices:int=0
    var prior_optional:int=-1
    func bar_pending()->bool:return true
    func prepare_bar()->void:
        var allowance:Dictionary=host._preparation_budget()
        if allowance.used_usec>=allowance.limit_usec:return
        slices+=1;prior_optional=allowance.optional_order.size()
        allowance.used_usec=allowance.limit_usec

func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("PREPARATION_ADMISSION_FAIL ",label)

static func complete_projection(result:Dictionary)->void:
    result.merge({"complete":true,"wanted":{},"ground":{},"actors":{},"packets":{},
        "source_files":{},"light_resolution":{"sources":[]},"worker_ms":0.0})

static func complete_error(result:Dictionary)->void:
    result.merge({"complete":false,"error":"Authored actor source is unavailable."})

static func blocked_projection(result:Dictionary,gate:Semaphore)->void:
    gate.wait()
    complete_projection(result)

func passive_worker_handoffs(host:Host)->void:
    for stage in ["sort_wait","atlas_prefix_wait","failed_projection"]:
        var candidate=Preparation.new();host.add_child(candidate);candidate.host=host
        candidate.phase=stage
        candidate.atlas_prefix={"worker_ms":3.0}
        candidate.order_records=[];candidate.sorted_indices=[]
        var work:Callable=complete_error if stage=="failed_projection" else complete_projection
        candidate.task=WorkerThreadPool.add_task(work.bind(candidate.result))
        while not WorkerThreadPool.is_task_completed(candidate.task):await process_frame
        candidate.step(0)
        var expected:String="failed" if stage=="failed_projection" else "order_release" if stage=="sort_wait" else "atlas_prefix_bind"
        check(candidate.task<0 and candidate.phase==expected and not candidate.prepared
            and candidate.native_actors.is_empty() and candidate.entries.is_empty(),
            "Spent allowance acknowledges completed "+stage+" without scene construction or publication")
        if stage=="atlas_prefix_wait":check(candidate.result.worker_ms==3.0,"Completed atlas work retains its measured worker time")
        if stage=="failed_projection":check(candidate.media_issue=="Authored actor source is unavailable."
            and candidate.presentation_errors==[candidate.media_issue],"Spent allowance exposes the worker's real preparation error")
        candidate.free()
    var blocked=Preparation.new();host.add_child(blocked);blocked.host=host
    var gate=Semaphore.new()
    blocked.task=WorkerThreadPool.add_task(blocked_projection.bind(blocked.result,gate))
    blocked.step(0)
    check(blocked.task>=0 and blocked.phase=="projection" and blocked.result.is_empty(),
        "Spent allowance never joins an unfinished worker")
    gate.post();WorkerThreadPool.wait_for_task_completion(blocked.task);blocked.task=-1;blocked.free()

func completed_lanes(host:Host)->void:
    var candidate=Preparation.new();host.add_child(candidate);candidate.host=host
    candidate.phase="cookie_resources";candidate.result={"light_resolution":{"sources":[{}]}}
    candidate.light_preparation={"complete":true}
    candidate.step(0)
    check(candidate.phase=="cookie_resources" and candidate.cookie_source_cursor==0,
        "Spent allowance cannot start a real cookie operation")
    candidate.cookie_source_cursor=1
    candidate.step(0)
    check(candidate.phase=="ground" and candidate.entries.is_empty() and candidate.membership.is_empty(),
        "Completed cookie/light/actor/object lanes hand off without constructing world membership at zero allowance")
    candidate.phase="sampling";candidate.result={"blood_rows":{}}
    candidate.step(0)
    check(candidate.prepared and candidate.phase=="ready" and host.timeline.state.is_empty(),
        "An already prepared empty sampling lane completes without another frame or publishing canonical state")
    candidate.free()

func retained_lights(host:Host)->void:
    var parent=Node2D.new();host.add_child(parent)
    var lighting=host.source_lighting
    lighting.attach_page(parent)
    var source={"item_uuid":"disclosed-torch","anchor_item_uuid":"disclosed-torch","item_id":"equipment.portable_torch",
        "actor_uuid":"","position":Vector3.ZERO,"base_height_steps":0,"outer":8.0,"very":0.0,"bright":4.0,
        "very_bright_radius_feet":0.0,"bright_radius_feet":20.0,"dim_radius_feet":20.0}
    var resolved={"sources":[source],"issues":[]}
    var first:Dictionary=lighting.begin_preparation(resolved)
    while not first.complete:lighting.prepare_step(first)
    check(first.nodes.size()==1 and not first.nodes[0].node.enabled,
        "Changed optical membership prepares one hidden native light")
    lighting.publish_prepared(first)
    var node:PointLight2D=lighting.nodes[source.item_uuid]
    var retained:Dictionary=lighting.begin_preparation({"sources":lighting.sources,"issues":[]})
    check(retained.complete and retained.nodes.is_empty() and lighting.preparation_valid(retained),
        "Unchanged published optical sources need no cookie or light-node preparation")
    lighting.publish_prepared(retained)
    check(is_same(node,lighting.nodes[source.item_uuid]) and parent.get_child_count()==1,
        "Retained publication preserves the exact native light without duplicated nodes")
    var other=Node2D.new();host.add_child(other);lighting.attach_page(other)
    check(not lighting.preparation_valid(retained),
        "A changed receiving-page owner still rejects the old retained preparation")
    lighting.clear_pages();parent.queue_free();other.queue_free()

func media_retirement_lane()->void:
    var host=Host.new();root.add_child(host)
    host.timeline.state={"actors":{}}
    host.media_plan_epoch=host.timeline.initialization_revision
    host.media_empty_key=[host.media_plan_epoch,[],host.timeline.revision]
    host.media_empty_plan={"character":{},"environment":{},"fixtures":{},"errors":[]}
    host.media_warmup.budget_bytes=0
    var physical:Dictionary=host.MediaWarmup.physical(host.media_warmup)
    physical.budget_bytes=0
    # Typed publication acknowledgement, as in the residency accounting suite.
    # No decode/upload is needed to test which owner retires this cold source.
    host.MediaWarmup.published(host.media_warmup,{"path":"cold","cpu_bytes":8,"gpu_bytes":8})
    host.source_images.cold=Image.create(1,1,false,Image.FORMAT_RGBA8)
    var budget:Dictionary=host._preparation_budget();budget.used_usec=budget.limit_usec
    host._prepare_media()
    check(host.media_metadata_ready and host.media_warmup.resident.has("cold") and host.source_images.has("cold"),
        "Demand admission updates exact pins without running an unbudgeted retirement slice")
    check(budget.used_usec>=budget.limit_usec and budget.phase_usec.has("source_publication") and physical.evicted==0,
        "Required source publication is charged to the spent allowance without running eviction")
    host._prepare_optional_work()
    check(not physical.resident.has("cold") and not host.source_images.has("cold") and physical.evicted==1,
        "Existing over-budget cleanup still releases a cold source when the optional allowance is spent")
    check(budget.minimum_cleanup==1 and budget.used_usec>=budget.limit_usec,
        "Forced retirement is charged to the same frame instead of a second independent slice")
    host.free()

func run()->void:
    create_timer(15).timeout.connect(func():printerr("Preparation admission fixture deadline");quit(2))
    media_retirement_lane()
    var ui_host=Host.new();root.add_child(ui_host)
    var ui=PendingHUD.new();ui.host=ui_host;ui_host.add_child(ui);ui_host.hud=ui
    var ui_budget:Dictionary=ui_host._preparation_budget()
    ui_host._prepare_optional_work()
    check(ui.slices==1 and ui.prior_optional==0 and ui_budget.optional_order.is_empty(),
        "Pending visible UI receives the remaining shared allowance before any optional upload or effect owner")
    check(ui_budget.used_usec==ui_budget.limit_usec,
        "UI progress does not create a second allowance or expand the host budget")
    ui_host._prepare_optional_work()
    check(ui.slices==1,"Already spent required/UI allowance cannot be consumed again by another same-frame UI call")
    ui_host.free()
    var host=Host.new();root.add_child(host)
    var budget:Dictionary=host._preparation_budget()
    budget.used_usec=budget.limit_usec
    check(is_same(budget,host._preparation_budget()) and host._preparation_budget().used_usec==2000,
        "Repeated preparation consumers share the same spent native-frame allowance")
    var candidate=Preparation.new();host.add_child(candidate)
    candidate.host=host;candidate.initial=true;candidate.epoch=host.timeline.initialization_revision;candidate.quarter=host.quarter
    candidate.task=WorkerThreadPool.add_task(complete_projection.bind(candidate.result))
    while not WorkerThreadPool.is_task_completed(candidate.task):await process_frame
    budget=host._preparation_budget();budget.used_usec=budget.limit_usec
    host.pending_world=candidate
    candidate.boundary={"display_ms":1000.0}
    check(host._world_preparation_due(16.0),"Initial world keeps preparation priority before playback")
    candidate.initial=false;host.timeline.display_ms=100.0
    check(not host._world_preparation_due(16.0),"Later impact world leaves the first preparation turn available to earlier effects")
    host.timeline.display_ms=984.0
    check(host._world_preparation_due(16.0),"World due within this playback step keeps priority before its authoritative boundary")
    candidate.initial=true;host.timeline.display_ms=0.0
    host._step_world_preparation()
    check(candidate.task<0 and candidate.phase=="light_nodes" and not candidate.prepared
        and candidate.native_actors.is_empty() and candidate.entries.is_empty(),
        "Zero allowance still acknowledges completed passive projection without constructing or publishing native state")
    host.pending_world=null;candidate.free()
    await passive_worker_handoffs(host)
    completed_lanes(host)
    retained_lights(host)
    budget=host._preparation_budget();budget.used_usec=budget.limit_usec
    var a=Node3D.new();var b=Node3D.new();host.add_child(a);host.add_child(b)
    var a_id:int=a.get_instance_id();var b_id:int=b.get_instance_id()
    host.retiring_views=[{"nodes":[a,b],"entries":{},"atlas_cleanup":{}}];host.retiring_node_count=2
    host._dispose_views(budget)
    check(host.retiring_node_count==2 and is_instance_id_valid(a_id) and is_instance_id_valid(b_id),
        "Optional retirement cannot start a second independent slice after other work spends the frame")
    host._dispose_views(budget,true)
    check(host.retiring_node_count==1 and int(is_instance_id_valid(a_id))+int(is_instance_id_valid(b_id))==1
        and budget.minimum_cleanup==1,"Explicit memory-blocking cleanup advances exactly one real native destruction unit")
    host._dispose_views(budget,true)
    check(host.retiring_node_count==1,"Repeated same-frame cleanup cannot multiply the forced minimum")
    var first_owners:Array=[]
    for frame in 4:
        var prior_frame:int=Engine.get_process_frames()
        while Engine.get_process_frames()==prior_frame:await process_frame
        var fresh:Dictionary=host._preparation_budget()
        check(fresh.used_usec==0 and fresh.optional_order.is_empty(),"A later Engine frame receives one fresh allowance")
        host._prepare_optional_work()
        first_owners.append(fresh.optional_order[0])
    check(first_owners==[0,1,2,3],"All four existing optional owners receive the first turn across consecutive frames")
    check(host.retiring_node_count==0 and host.retiring_views.is_empty(),"Existing optional cleanup drains its retained native owner without a new queue")
    check(host.timeline.state.is_empty() and host.timeline.current.is_empty() and host.timeline.queue.is_empty(),
        "Admission and cleanup never invent timeline state, events or clocks")
    host.queue_free();await process_frame;await process_frame
    var report={"checks":checks,"failures":failures,"scope":"Shared frame allowance, passive completion polling, actual native cleanup and optional-owner fairness. No frame-time claim."}
    FileAccess.open("res://.runtime/preparation-admission-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("PREPARATION_ADMISSION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
