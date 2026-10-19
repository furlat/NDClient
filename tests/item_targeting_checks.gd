extends SceneTree
## Offered object subjects -> existing inventory Controls -> Preview/Command.
## This fast input-boundary proof does not claim a server outcome or pixels.
const Interaction=preload("res://presentation/interaction.gd")
const Choices=preload("res://sdk/choices.gd")
class Player extends "res://play.gd":
    var requests:Array=[]
    var commands:Array=[]
    var allowed:bool=true
    func _init()->void:session=Session.new()
    func command_ready()->bool:return allowed and not command_busy
    func _request_selection(auto_confirm:bool)->void:
        requests.append({"selection":target_selection.duplicate(true),"auto_confirm":auto_confirm})
        command_busy=auto_confirm
    func _submit(intent:Dictionary)->void:commands.append(intent.duplicate(true))
class HUD extends "res://play_hud.gd":
    # Icon I/O is outside this gesture proof; all production callbacks and
    # inventory/slot Controls, eligibility and selection logic remain actual.
    func _set_button_icon(button:Button,_key:String,help:String,fallback:String)->void:
        button.tooltip_text=help;button.text=fallback.left(3)
    func _ready()->void:
        super._ready()
        set_process(false)
var checks:int=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr("ITEM_TARGET_FAIL "+label)
func click(button:Button)->void:
    var event=InputEventMouseButton.new()
    event.position=button.get_global_rect().get_center();event.global_position=event.position
    event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true
    root.push_input(event,true)
    event=event.duplicate();event.pressed=false;root.push_input(event,true)
func item(id:String,name:String)->Dictionary:
    return {"uuid":id,"look":{"item_id":"","name":name},"profile":{},"state":{},"effects":[]}
func run()->void:
    root.size=Vector2i(1280,900)
    var action={"behavior_id":"fixture.object_enchantment","display_name":"Object enchantment","target_type":"object",
        "discovery_index":4,"discovery_generation":8,"target_set":0,"can_afford":true,"availability_status":"available"}
    var choices={"entity_uuid":"caster","discovery_generation":8,"entity_actions":[],"position_actions":[],"self_actions":[],"object_actions":[action],
        "subjects":[{"kind":"object","uuid":"bag-item"},{"kind":"object","uuid":"held-item"},{"kind":"creature","uuid":"caster"},{"kind":"object","uuid":"floor-item"}],
        "positions":[[2,3]],"target_sets":[[{"kind":"subject","subject":0,"index":19},{"kind":"subject","subject":1,"index":73},
            {"kind":"subject","subject":3,"position":0,"index":108}]]}
    var original:Dictionary=choices.duplicate(true)
    var actor={"uuid":"caster","name":"Caster","controlled_items":["bag-item","held-item","ineligible-item"],
        "visual_loadout":{"layers":[{"slot":"MELEE_MAIN","item_uuid":"held-item"}]}}
    var state={"actors":{"caster":actor},"items":{"bag-item":item("bag-item","Bag item"),"held-item":item("held-item","Held item"),
        "ineligible-item":item("ineligible-item","Ineligible item"),"floor-item":item("floor-item","Floor item")},
        "objects":{"floor-item":{}},"current_actor_uuid":"caster","content":[],"tiles":{}}
    var prefix:Dictionary=Interaction.selection(action,[])
    var held:Dictionary=Interaction.extend_selection(choices,action,prefix,{},[],"held-item",true,state,"object")
    check(held.selection.target_indices==[73] and held.position==null,"Carried/held item selects its exact native index with no invented carrier cell")
    check(Interaction.extend_selection(choices,action,prefix,{},[2,3],"caster",true,state,"creature").is_empty(),"Clicking carrier cannot select an owned item by shared position")
    check(Interaction.extend_selection(choices,action,prefix,{},[],"held-item",true,state,"creature").is_empty(),"Item and creature subject kinds remain distinct")
    check(Interaction.extend_selection(choices,action,prefix,{},[2,3],"",true,state).is_empty(),"A floor cell cannot choose one of its object subjects")
    check(Interaction.subject_targets(choices,action,{},"object").keys()==["bag-item","held-item","floor-item"],"Eligibility preserves all exact offered object UUIDs")
    var preview={"subjects":[{"kind":"object","uuid":"held-item"}],"positions":[],"next_target_set":0,"target_sets":[[{"kind":"subject","subject":0,"index":904}]],"next_positions":[]}
    var next:Dictionary=Interaction.extend_selection(choices,action,held.selection,preview,[],"held-item",true,state,"object")
    check(next.selection.target_indices==[73,904],"Continuation resolves the new Preview-local subject/index domain")
    check(Interaction.extend_selection(choices,action,held.selection,preview,[],"bag-item",true,state,"object").is_empty(),"Discovery eligibility cannot override a narrower Preview continuation")
    var empty:Dictionary=preview.duplicate(true);empty.target_sets=[[]]
    check(Interaction.extend_selection(choices,action,prefix,empty,[],"held-item",true,state,"object").is_empty(),"Computed empty continuation stays empty")
    check(Interaction.object_targeting(choices,action,empty),"An exhausted item prefix does not turn inventory clicks into Equip")
    var player:Player=Player.new();player.available_actions=choices;player.timeline.state=state
    var hud:HUD=HUD.new();hud.world=player;player.hud=hud;root.add_child(hud)
    player.select_action(action)
    await process_frame
    check(hud.panel.visible and hud.inventory_buttons.has("held-item"),"Selecting a generic item-targeted action opens the actual carried inventory")
    check(not hud.inventory_buttons["held-item"].disabled and hud.inventory_buttons["held-item"].has_theme_stylebox_override("normal"),"Eligible carried item receives a target highlight")
    check(hud.inventory_buttons["ineligible-item"].disabled and not hud.inventory_buttons["ineligible-item"].has_theme_stylebox_override("normal"),"Unoffered carried item cannot be selected")
    check(hud.slot_buttons.MELEE_MAIN.get_meta("item_uuid")=="held-item" and not hud.slot_buttons.MELEE_MAIN.disabled,"Held equipment exposes the actual item identity, separately from caster")
    var before:int=player.requests.size()
    click(hud.inventory_buttons["held-item"])
    await process_frame
    check(player.requests.size()==before+1 and player.requests[-1].selection.target_indices==[73],"Native inventory button click requests Preview for the clicked item, not the first target")
    check(player.requests[-1].auto_confirm and not hud.panel.visible,"A complete item gesture preserves normal Preview-confirm behavior and reveals the world")
    check(player.commands.is_empty(),"Item selection never issues Equip or bypasses Preview")
    player.command_busy=false;player.selection_preview={"can_confirm":true}
    player.confirm_selection()
    check(player.commands.size()==1 and player.commands[0].kind=="execute_selection" and player.commands[0].selection==held.selection,"Confirmed command retains the exact response-local selection and item index")
    check(player.commands[0].discovery_generation==8,"Command retains the authoritative discovery generation")
    player.command_busy=false;player.select_action(action)
    await process_frame
    before=player.requests.size();click(hud.slot_buttons.MELEE_MAIN);await process_frame
    check(player.requests.size()==before+1 and player.requests[-1].selection.target_indices==[73],"Equipment-slot click uses the same item Preview route")
    player.command_busy=false;player.select_action(action)
    var hit={"id":"floor-item","kind":"prop","subject_kind":"object","position":[2,3]}
    var intent:Dictionary=player._hover_choice(hit,true)
    check(intent.value.target.index==108 and intent.value.position==[2,3],"World item hover and cursor use the same exact offered object binding")
    player._world_click(hit)
    check(player.requests[-1].selection.target_indices==[108],"World item click uses the shared Preview route")
    player.command_busy=false;player.select_action(action)
    player.available_actions=choices.duplicate(true)
    before=player.requests.size()
    check(not player.choose_item_target("held-item") and player.requests.size()==before,"Stale response ownership cannot spend through an old inventory button")
    check(choices==original and prefix.target_indices.is_empty(),"Inventory gestures leave borrowed choices and earlier selection prefixes immutable")
    hud.free();player.context_menu.free();player.free()
    await process_frame
    print(JSON.stringify({"checks":checks,"failures":failures,"scope":"Subject-aware item Control/Preview/Command boundary; real server and native output require the separate live retry"}))
    quit(0 if failures.is_empty() else 1)
