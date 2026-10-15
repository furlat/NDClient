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

func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("PREPARATION_ADMISSION_FAIL ",label)

static func complete_projection(result:Dictionary)->void:
    result.merge({"complete":true,"wanted":{},"ground":{},"actors":{}})

func run()->void:
    create_timer(15).timeout.connect(func():printerr("Preparation admission fixture deadline");quit(2))
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
    host._step_world_preparation()
    check(candidate.task<0 and candidate.phase=="cookie_resources" and not candidate.prepared
        and candidate.native_actors.is_empty() and candidate.entries.is_empty(),
        "Zero allowance still acknowledges completed passive projection without constructing or publishing native state")
    host.pending_world=null;candidate.free()
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
