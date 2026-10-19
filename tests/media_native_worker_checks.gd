extends SceneTree
## Native Resource metadata has one explicit async owner; queued requests never
## replace its output or let polling/close collect the same worker twice.
const Media=preload("res://presentation/media_warmup.gd")
var checks:int=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr("MEDIA_WORKER_FAIL ",label)
func held(entered:Semaphore,release:Semaphore)->void:
    entered.post();release.wait()
func run()->void:
    var state:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/schema16/character_sources.json"))
    var data:Dictionary=Media.create()
    Media.request_plan(data,["first"],state,[])
    var first:Thread=data.plan_thread
    check(first!=null,"Actual native source metadata owns an asynchronous Thread")
    Media.request_plan(data,["latest"],state,[])
    check(data.plan_thread==first and data.plan_pending.key==["latest"],"A newer request queues without replacing the running resource owner")
    var results:Array=[];var deadline:int=Time.get_ticks_msec()+10000
    while results.size()<2 and Time.get_ticks_msec()<deadline:
        var result:Dictionary=Media.poll_plan(data)
        if not result.is_empty():results.append(result)
        await process_frame
    check(results.size()==2 and results.map(func(row):return row.key)==[["first"],["latest"]],"Both actual native resource closures are collected in order")
    check(results.all(func(row):return row.get("complete",false) and row.value.errors.is_empty()),"Source loading completes with its real output and zero metadata errors")
    check(data.plan_thread==null and not first.is_started(),"Completed metadata detaches its owner and joins once")
    check(Media.poll_plan(data).is_empty(),"Repeated idle polling never reuses a consumed worker handle")
    Media.close(data);Media.close(data)
    check(data.closed and data.plan_thread==null,"Repeated close cannot collect an already consumed worker")
    var canceled:Dictionary=Media.create();var entered:Semaphore=Semaphore.new();var release:Semaphore=Semaphore.new()
    var worker:Thread=Thread.new();canceled.plan_thread=worker;worker.start(held.bind(entered,release));entered.wait()
    canceled.plan_pending={"key":["not_started"]};canceled.optional_pending={"key":["not_started_optional"]}
    var releaser:Thread=Thread.new();releaser.start(func():OS.delay_msec(5);release.post())
    Media.close(canceled);releaser.wait_to_finish()
    check(canceled.closed and not worker.is_started() and canceled.plan_thread==null and canceled.plan_pending.is_empty() and canceled.optional_pending.is_empty(),"Close joins the actual running job and discards unpublished intent without starting another")
    print(JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
