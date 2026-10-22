extends SceneTree
## Required/optional closure identity only; explicit source packets, no GPU or
## authored-source/visual claim. Actual journal parity is checked separately.
const Player=preload("res://play.gd")
const Media=preload("res://presentation/media_warmup.gd")
const Session=preload("res://presentation/session.gd")
var checks=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr(label)
func closure(path:String)->Dictionary:
    return {"character":{path:true},"environment":{},"fixtures":{},"errors":[],"gpu_only":{},"cpu_required":{path:true}}
func run()->void:
    pending_assets_control()
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

func pending_assets_control()->void:
    # Passive source-owner boundary. No fabricated image or graphics receipt.
    var player=Player.new();player.session=Session.new()
    player.timeline.accept({"kind":"initialization","sequence":0,"state":{"generation":1,"observer_uuid":"seat",
        "actors":{},"tiles":{},"objects":{},"senses":{},"audience":{"controlled":[]}}})
    player._reset_media_epoch()
    var group:Dictionary={"id":"assets-pending"};player.timeline.current=group
    var path:String="res://fixture-passive-character.png"
    var record:Dictionary=Media.source_record({path:path},{},{},{path:true})
    var family:Dictionary=Media._source_family([record],{path:16})
    var assets:Dictionary={"generation":1,"observer_uuid":"seat","groups":[group],
        "source_families":{group.id:{player.character_light_profile:[family]}},"source_sizes":{path:16},"source_headers":{},"source_files":{}}
    var message:Dictionary={"stage":"asset_sources","groups":[group],"assets":assets}
    player.session.prepared=[message]
    check(player._receive_prepared_operations(),"Asset-only queue stage is received without canonical Timeline admission")
    player._publish_media_interest(0)
    var physical:Dictionary=Media.physical(player.media_warmup)
    check(player.timeline.current==group and player.timeline.queue.is_empty() and player.timeline.sequence==0,
        "Passive discovery cannot advance an event, canonical sequence or queue")
    check(not player.media_metadata_ready and player.media_group_plans.is_empty() and player.media_warmup.wanted.is_empty(),
        "Character discovery cannot become complete metadata or required readiness")
    check(physical.consumers[player.media_warmup.consumer_id].later_families.size()==1 and not Media.ready(player.media_warmup,{path:true}),
        "Completed character family is optional interest before any image receipt")
    player._adopt_asset_sources(message);player._publish_media_interest(0)
    check(physical.consumers[player.media_warmup.consumer_id].later_families.size()==1,"Duplicate exact discovery cannot multiply its optional lease")
    var unrelated:Dictionary=message.duplicate(true)
    unrelated.assets.generation=2
    player._adopt_asset_sources(unrelated)
    check(is_same(player.media_pending_assets[group.id].owner,group),"Another epoch cannot replace an accepted pending source owner")
    player.timeline.current=group.duplicate();player._publish_media_interest(0)
    check(player.media_pending_assets.is_empty() and physical.consumers[player.media_warmup.consumer_id].later_families.is_empty(),
        "Same string group ID with a different owner withdraws the old discovery")
    player.timeline.current=group;player._adopt_asset_sources(message)
    player.session.issue={"message":"metadata failed"};player._publish_media_interest(0)
    check(player.media_pending_assets.is_empty() and physical.consumers[player.media_warmup.consumer_id].later_families.is_empty(),
        "Session failure withdraws temporary families without declaring completion")
    player.session.issue={};player._adopt_asset_sources(message);player._publish_media_interest(0)
    player.media_group_plans[group.id]={"source_records":{player.character_light_profile:[record]}}
    player.media_metadata_ready=true;player._publish_media_interest(0)
    check(player.media_pending_assets.is_empty() and player.media_warmup.wanted.has(path)
        and physical.consumers[player.media_warmup.consumer_id].later_families.is_empty(),
        "One demand publication promotes the completed plan without losing its required path")
    player.session.close();player.session=null
    Media.close(player.media_warmup);player.component_renderer.close(player);player.context_menu.free();player.free()
