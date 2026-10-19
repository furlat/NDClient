extends SceneTree
## Production preparation-interest boundary over actual installed Factory clips.
## This does not construct/draw effects or claim surprise first-use GPU readiness.
const Startup=preload("res://presentation/native_source_startup.gd")
const Effects=preload("res://presentation/effect_package.gd")
class Probe extends "res://play.gd":
    func _ready()->void:
        set_process(false);set_process_unhandled_input(false);add_child(context_menu)
    func _process(_delta:float)->void:pass
var checks=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("NATIVE_PREPARATION_FAIL ",label)
func keys(rows:Array)->Array:
    return rows.map(func(row):return row.key)
func request(host:Probe,at_ms:float)->Dictionary:
    return host._native_startup_request(at_ms,false)
func select(host:Probe,value:Dictionary)->void:
    host.selection_media.value=value;host.selection_media.revision+=1
func finish(host:Probe)->void:
    host.queue_free();await process_frame
    print(JSON.stringify({"checks":checks,"failures":failures,"scope":"Actual preparation interest/deadlines only; native draw and first-use timing require the serialized live lane."}))
    quit(0 if failures.is_empty() else 1)
func run()->void:
    var host=Probe.new();root.add_child(host)
    var before:Dictionary=Startup._state.duplicate(true)
    var empty=request(host,0.0)
    check(empty.plan.is_empty() and empty.required.is_empty(),"No selection, owner or received cue requests zero package programs")
    check(Startup._state==before,"Planning interest neither starts native constructors nor changes program readiness")
    var cast:Dictionary=Effects.clip("spells/fire_bolt/default/cast")
    var travel:Dictionary=Effects.clip("spells/fire_bolt/default/travel")
    var haste:Array=Effects.conditions("condition.spell.haste")
    check(not cast.is_empty() and not travel.is_empty() and not haste.is_empty(),"Tests use actual installed Fire Bolt and Haste package data")
    if cast.is_empty() or travel.is_empty() or haste.is_empty():await finish(host);return
    var selected={"id":"spell.haste","staging":{"cues":[]},"lifecycle":{"owner_ids":["condition.spell.haste"]}}
    select(host,{"native_selection":selected})
    var selected_request=request(host,0.0)
    var selected_keys:Array=[]
    for lifecycle in haste:selected_keys.append(Effects.key(Effects.clip(lifecycle.condition.phases.application)))
    check(keys(selected_request.plan)==selected_keys,"Selection admits only its own exact lifecycle programs")
    check(selected_request.required.is_empty() and Startup.status(selected_request).ready,"Selecting a spell prepares optional interest without blocking movement")
    select(host,{"native_selection":{},"native_action_clips":[cast]})
    var selected_action=request(host,0.0)
    check(keys(selected_action.plan)==[Effects.key(cast)] and selected_action.required.is_empty(),"Selected action programs receive the same optional lead without becoming mandatory")
    select(host,{})
    host.timeline.condition_owners={"haste-owner":{"id":"haste-owner","actor_uuid":"caster","condition":{"condition_uuid":"haste-owner","behavior_id":"condition.spell.haste","state":{}}}}
    host.timeline.resource_revision+=1
    var active=request(host,1000.0)
    check(keys(active.required)==selected_keys,"An actual observed owner requires its application program immediately")
    check(active.plan.all(func(item):return is_inf(item.due_ms) and item.due_ms<0),"Observed-owner readiness does not wait for another event or a full-catalog warmup")
    host.timeline.condition_owners={};host.timeline.resource_revision+=1
    host.timeline.group_start_ms=1000.0;host.timeline.display_ms=1070.0
    var adapted:Dictionary=cast.duplicate(false);adapted.opacity_uniform="authored_test_alpha"
    var current={"id":"current","duration_ms":400.0,"components":[{"native_spell":true,"status":"available","native_clip":cast,"native_cue":{"opacity_uniform":"authored_test_alpha"},"start_ms":250.0,"preparation_at_ms":120.0}]}
    var future={"id":"future","duration_ms":500.0,"components":[],"native_requirements":[{"native_spell":true,"status":"available","native_clip":travel,"native_cue":{},"start_ms":250.0,"preparation_at_ms":20.0}]}
    host.timeline.current=current;host.timeline.queue=[future]
    var timeline_before:PackedByteArray=var_to_bytes([host.timeline.state,current,future,host.timeline.display_ms])
    var early=request(host,1119.0)
    check(early.plan.size()==2 and early.required.is_empty(),"Received future components are optional until their actual preparation cue")
    check(keys(early.plan).has(Effects.key(adapted)) and not keys(early.plan).has(Effects.key(cast)),"Warm identity includes the exact opacity adaptation used by the renderer")
    check(not cast.has("opacity_uniform"),"Preparing an authored adaptation does not mutate the shared Factory clip")
    var first=request(host,1120.0)
    check(keys(first.required)==[Effects.key(adapted)],"Current cue is due at group start plus preparation_at_ms, before its later visible start")
    var later=request(host,1420.0)
    check(keys(later.required).has(Effects.key(travel)),"Queued cue deadline includes the full preceding group duration")
    check(var_to_bytes([host.timeline.state,current,future,host.timeline.display_ms])==timeline_before,"Interest planning publishes no future world, owner or timeline state")
    check(Startup._state==before,"Request/status checks do not create draw owners or claim GPU programs ready")
    host.timeline.current={};host.timeline.queue=[];host.timeline.resource_revision+=1
    check(request(host,2000.0).plan.is_empty(),"Retired selection/owner/queue interest cannot retain the entire package as startup demand")
    await finish(host)
