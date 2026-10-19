extends SceneTree
## Actual native outfit records select identical constructor, required and optional sources.
const Characters=preload("res://presentation/characters.gd")
const Media=preload("res://presentation/media_warmup.gd")
const Selection=preload("res://presentation/selection_media.gd")
const Encounter=preload("res://presentation/encounter_media.gd")
var checks=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("CHARACTER_SOURCES_FAIL "+label)
func includes(paths:Dictionary,wanted:Dictionary)->bool:
    for path in wanted:
        if not paths.has(path):return false
    return true
func run()->void:
    # Reduced by the frozen Python reference from the actual Crypt initialization.
    var state:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/schema16/character_sources.json"))
    var actor:Dictionary={}
    for value in state.actors.values():
        if value.name=="Draconic Sorcerer":actor=value
    state.actors={actor.uuid:actor};state.audience={"controlled":[actor.uuid],"observers":[actor.uuid],"revision":0};state.objects={}
    var original=var_to_bytes(state);var cache:Dictionary={}
    var looks:Dictionary=Characters.item_looks(actor,state)
    var resolved:Dictionary=Characters.resolve(actor,state,cache)
    check(resolved.ok,"Native actor constructor resolves actual item looks")
    var rig:Dictionary=Characters.rigs(cache)[resolved.value.rig]
    var layers:Dictionary=Characters.prepare_layers(resolved.value,rig,cache)
    var displayed:Dictionary={}
    for layer in layers.value:
        if layer.paths.has("Idle"):displayed[layer.paths.Idle]=true
    var sheets:Dictionary=Characters.sheet_paths(actor,["Idle"],cache,looks)
    check(sheets.ok and includes(sheets.value,displayed),"Source API matches exact displayed outfit including non-default variants")
    var snapshot:Dictionary=Media._snapshot(state)
    check(snapshot.items==state.items and not is_same(snapshot.items,state.items),"Passive source snapshot forks the native item membership index")
    check(is_same(snapshot.items.values()[0],state.items.values()[0]),"Native item after-values retain shared immutable ownership")
    var initial:Dictionary=Media.plan(snapshot,[],cache)
    check(initial.errors.is_empty() and includes(initial.required,displayed),"Required startup demand contains every actual constructor colour sheet")
    var equipment:Dictionary=Media.Authoring.body("equipment",actor,{},cache).actor
    var equipment_sources:Dictionary=Characters.sheet_paths(actor,[equipment.clip],cache,looks)
    check(includes(initial.required,equipment_sources.value),"Immediate equipment control owns its finite authored clip before first click")
    Media.plan(snapshot,[],cache)
    check(cache.__required_actor_closures.misses==0 and cache.__required_actor_closures.hits>0,"Repeated unchanged native outfit borrows its prepared physical source closure")
    var changed:Dictionary=state.duplicate();changed.items=state.items.duplicate()
    var item_id:String=""
    for layer in actor.visual_loadout.layers:
        if layer.slot=="Body":item_id=layer.item_uuid
    var item:Dictionary=changed.items[item_id].duplicate();item.look=item.look.duplicate();item.look.visual_variant_id="81000006";changed.items[item_id]=item
    var changed_looks:Dictionary=Characters.item_looks(actor,changed)
    var next_sources:Dictionary=Characters.sheet_paths(actor,["Idle"],cache,changed_looks)
    check(next_sources.ok and next_sources.value!=sheets.value,"A native item look change can select another sheet while actor/loadout remain identical")
    var next:Dictionary=Media.plan(changed,[],cache)
    check(next.errors.is_empty() and includes(next.required,next_sources.value) and cache.__required_actor_closures.misses>0,"Item-only source changes invalidate the exact equipped look operands")
    var group:Dictionary={"id":"native-item-look","duration_ms":200.0,"commits":[{"at_ms":100.0,"delta":{"items":{item_id:item}}}],"actor_tracks":[],"staged_actors":{},"components":[]}
    var transitioned:Dictionary=Media.plan(snapshot,[group],cache)
    var opening:Dictionary=Media.required_at(transitioned.character_timeline[group.id],0.0)
    var after:Dictionary=Media.required_at(transitioned.character_timeline[group.id],100.0)
    var next_equipment:Dictionary=Characters.sheet_paths(actor,[equipment.clip],cache,changed_looks)
    check(includes(after,next_equipment.value),"Received post-equipment outfit prepares the next equipment gesture's own clip")
    var newly_selected:Dictionary={}
    for path in next_sources.value:
        if not sheets.value.has(path):newly_selected[path]=true
    check(includes(opening,sheets.value) and not includes(opening,newly_selected),"Current source demand retains old outfit until the authored item boundary")
    check(includes(after,next_sources.value),"Item-only commit schedules new physical sources before their actual first use")
    group.actor_tracks=[{"actor_uuid":actor.uuid,"rig":resolved.value.rig,"clip":"Idle","start_ms":0.0,"duration_ms":80.0,"presentation_actor":actor,"presentation_item_looks":looks}]
    var tracked:Dictionary=Media.plan(snapshot,[group],cache)
    check(includes(Media.required_at(tracked.character_timeline[group.id],0.0),sheets.value),"Occurrence's exact native item looks survive later item after-values")
    var selected:Dictionary=Selection.plan({"state":state,"actor_uuid":actor.uuid,"behavior":"action.move","budget_bytes":17179869184}, {}, {"mutex":Mutex.new(),"cancelled":false})
    check(selected.errors.is_empty() and includes(selected.paths,displayed),"Early action preparation selects the same canonical outfit as world construction")
    var optional:Dictionary=Encounter.plan(state,{},{},{})
    check(optional.errors.is_empty() and includes(optional.paths,displayed),"Optional animation families use actual equipped variants")
    check(var_to_bytes(state)==original,"Source preparation never modifies canonical actor/item inputs")
    print(JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
