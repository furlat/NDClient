extends SceneTree
## Required/optional closure identity only; explicit source packets, no GPU or
## authored-source/visual claim. Actual journal parity is checked separately.
const Player=preload("res://play.gd")
const Media=preload("res://presentation/media_warmup.gd")
var checks=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr(label)
func closure(path:String)->Dictionary:
    return {"character":{path:true},"environment":{},"fixtures":{},"errors":[],"gpu_only":{},"cpu_required":{path:true}}
func run()->void:
    var player=Player.new()
    player.timeline.accept({"kind":"initialization","sequence":0,"state":{"actors":{},"tiles":{},"objects":{},"senses":{},"audience":{"controlled":[]}}})
    player._reset_media_epoch()
    var current={"id":"current"};var next={"id":"next"}
    player.timeline.current=current;player.timeline.queue=[next]
    player.media_group_plans={"current":closure("res://fixture-current.png"),"next":closure("res://fixture-next.png")}
    player._prepare_media()
    var demands:int=player.media_warmup.demand_runs+player.media_warmup.demand_noops
    for i in 10:
        player.replay_media_groups=[current];player._prepare_media()
        player._release_replay_media();player._prepare_media()
    check(player.media_warmup.demand_runs+player.media_warmup.demand_noops==demands,"Repeated current-only replay preparation does not rebuild demand")
    check(not player.media_plan.required.has("res://fixture-next.png"),"Upcoming source is optional")
    var key:Array=player.media_plan_key.duplicate(true)
    player.replay_media_groups=[current,next];player._prepare_media()
    check(player.media_plan_key==key,"Crossed-group case keeps same current/upcoming metadata identity")
    check(player.media_plan.required.has("res://fixture-next.png"),"Crossed source becomes required despite unchanged metadata identity")
    player._release_replay_media();player._prepare_media()
    check(not player.media_plan.required.has("res://fixture-next.png"),"Cancellation releases crossed required pins")
    player.component_renderer.native_spells.required_images={"res://fixture-optical.png":true};player._prepare_media()
    check(player.media_plan.required.has("res://fixture-optical.png"),"New native optical demand invalidates unchanged group identity")
    player.component_renderer.native_spells.required_images={};player._prepare_media()
    check(not player.media_plan.required.has("res://fixture-optical.png"),"Retired native optical demand releases required pins")
    Media.close(player.media_warmup);player.component_renderer.close(player);player.context_menu.free();player.free()
    var report={"checks":checks,"failures":failures,"scope":"Production required/optional source-closure identity; no texture decoding or native pixel claim"}
    FileAccess.open("res://generated/replay_media_demand_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("REPLAY_MEDIA_DEMAND ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
