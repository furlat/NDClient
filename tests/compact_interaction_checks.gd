extends SceneTree
# Compact admitted values -> native selection/visible HUD footprint. No backend
# gameplay or rendered-pixel claim; sources stay borrowed and unmodified.
const Interaction = preload("res://presentation/interaction.gd")
const Choices = preload("res://sdk/choices.gd")
const UI = preload("res://presentation/ui_catalog.gd")
const FixtureWorld = preload("res://tests/ui_fixture_world.gd")
var checks = 0
var failures: Array = []

class ClickPlayer extends "res://play.gd":
    var requests: Array = []
    var submitted: Array = []
    func _init() -> void: session = Session.new() # Off-tree interaction fixture owns its native response boundary.
    func command_ready() -> bool: return true
    func _request_selection(auto_confirm: bool) -> void:
        requests.append({"selection":target_selection.duplicate(true),"auto":auto_confirm})
    func _submit(intent: Dictionary) -> void: submitted.append(intent.duplicate(true))

class FootprintHUD extends "res://play_hud.gd":
    var outlines: Array = []
    func pointer_over_controls(_point: Vector2 = Vector2.INF) -> bool: return false
    func _ready() -> void:
        super._ready()
        set_process(false)
    func _target_outline(position: Array, colour: Color) -> void:
        outlines.append({"position":position.duplicate(),"colour":colour})

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures.append(label); print("COMPACT_INTERACTION_FAIL ",label)

func row(behavior: String, target_type: String, set_index: int, index: int=0) -> Dictionary:
    var value = {"template_name":behavior,"behavior_id":behavior,"provided_by_id":behavior,
        "target_type":target_type,"target_set":set_index,"availability_status":"available",
        "can_afford":true,"display_name":behavior,"cost_type":"actions"}
    if index!=0: value.discovery_index=index
    return value

func _initialize() -> void: run.call_deferred()
func run() -> void:
    var attack = row("action.attack","entity",0)
    attack.performs_attack=true; attack.weapon_slot="MELEE_MAIN"
    var move = row("action.move","position_path",1,1)
    move.variant_facets=[{"key":"movement","value":"walking"}]
    var opened = row("action.open","object",2,2)
    opened.interaction_affordance={"surface":"world"}
    var dash = row("action.dash","self",3,3)
    var choices = {"entity_uuid":"hero","discovery_generation":0,"remaining_movement":15,
        "subjects":[{"uuid":"wall","kind":"object"},{"uuid":"goblin","kind":"creature"}],
        "positions":[[2,3],[4,5],[6,7]],"target_sets":[
            [{"kind":"subject","subject":0,"position":0,"index":91},{"kind":"subject","subject":1,"position":0,"index":7}],
            [{"kind":"position","position":1,"index":23,"path_cost":10},
             {"kind":"position","position":2,"index":45,"path_cost":5,"safe_path_cost":20,"is_path_hazardous":true}],
            [{"kind":"subject","subject":0,"index":33}], [{"kind":"self","index":0}]],
        "entity_actions":[attack],"position_actions":[move],"object_actions":[opened],"self_actions":[dash],
        "world_interactions":[{"subject_uuid":"wall","behavior_id":"action.open","label":"Open"}]}
    var original = choices.duplicate(true)
    check(Interaction.actions(choices)==[attack,move,dash,opened],"Family order remains entity/position/self/object with borrowed rows")
    check(is_same(Interaction.actions(choices)[0],attack),"Action lookup retains admitted row ownership")
    var pool = Choices.action_options(choices,attack)
    check(Interaction.target(choices,pool,[2,3],"wall").index==91,"Wall identity wins despite shared creature contact")
    check(Interaction.target(choices,pool,[2,3],"goblin").index==7,"Creature resolves independently at the same coordinate")
    check(Interaction.target(choices,pool,[2,3]).is_empty(),"Position-only targeting does not invent a subject selection")
    check(Interaction.target(choices,Choices.action_options(choices,opened),[],"wall").index==33,"Subject without a contact still selects by identity")
    check(Interaction.main_attack(choices,"goblin","MELEE_MAIN").selection.target_indices==[7],"Default omitted costs preserve main-attack native index")
    check(Interaction.main_attack(choices,"goblin","RANGED_MAIN").is_empty(),"Attack preference still selects exact native weapon")
    var option: Dictionary = choices.world_interactions[0]
    var admitted = Interaction.admitted(choices,option)
    check(admitted.size()==1 and admitted[0].selection==Interaction.selection(opened,[33]),"Sparse world affordance/facets resolves exact admitted open action")
    check(Interaction.same_option(option,{"subject_uuid":"wall","behavior_id":"action.open","label":"Open","variant_facets":[]}),"Omitted and empty optional facets mean the same world verb")
    check(Interaction.world_options(choices,"wall")==[option],"Missing default_priority retains native priority100")
    var actor_hit = {"kind":"actor","id":"goblin","position":[2,3]}
    var object_hit = {"kind":"prop","id":"wall","position":[2,3]}
    var ground_hit = {"kind":"ground","position":[4,5]}
    check(Interaction.idle_intent(choices,{},actor_hit,false,"MELEE_MAIN","action.move").value.selection.target_indices==[7],"Ordinary hover and click share the actual melee attack choice")
    check(Interaction.idle_intent(choices,{},actor_hit,false,"RANGED_MAIN","action.move").is_empty(),"Unavailable weapon preference cannot promise an attack cursor")
    check(Interaction.idle_intent(choices,{},object_hit,false,"MELEE_MAIN","action.move").kind=="interaction","Ordinary object hover resolves the same default open verb")
    check(Interaction.idle_intent(choices,{},object_hit,true,"MELEE_MAIN","action.move").value.selection.target_indices==[91],"Force attack overrides object default using exact admitted target")
    check(Interaction.idle_intent(choices,{"objects":{"wall":{"contained_items":[]}}},object_hit,false,"MELEE_MAIN","action.move").kind=="storage","Storage cursor and ordinary open-storage click share precedence")
    check(Interaction.idle_intent(choices,{},ground_hit,false,"MELEE_MAIN","action.move").value.selection.target_indices==[23],"Movement cursor preview resolves same actual walking destination")
    var distant = choices.duplicate(true)
    distant.world_interactions=[{"subject_uuid":"distant","behavior_id":"action.open","label":"Open","contact_positions":[[4,5]]}]
    var approach_intent = Interaction.idle_intent(distant,{}, {"kind":"prop","id":"distant","position":[8,8]},false,"MELEE_MAIN","action.move")
    check(approach_intent.kind=="approach" and approach_intent.value.selection.target_indices==[23],"Distant-object hover previews the same actual safe approach as its ordinary click")
    var approach = Interaction.approach(choices,{"contact_positions":[[4,5],[6,7]]})
    check(approach.selection.target_indices==[23],"Approach uses binding-local position and rejects unaffordable hazardous safe path")
    check(Interaction.approach(choices,{}).is_empty(),"Missing contact positions does not invent an approach")

    var player = ClickPlayer.new()
    player.available_actions=choices
    player.select_action(dash)
    check(player.requests[-1].selection.action_index==3 and player.requests[-1].selection.target_indices==[0],"Sparse self action keeps native zero target")
    check(player.requests[-1].auto,"Existing self confirm behavior is preserved")
    player.cancel_selection(); player.requests.clear()
    player.choose_target([4,5])
    check(player.requests.is_empty() and player.submitted[-1].selection.target_indices==[23],"Unselected movement submits its admitted destination without a Preview roundtrip")
    player.cancel_selection(); player.requests.clear()
    player.choose_target([2,3],"goblin")
    check(player.requests.size()==1 and player.requests[0].selection==Interaction.selection(attack,[7]),"Unselected attack keeps discovery index zero and target index seven")

    var missile = row("spell.magic_missile","multi_entity",0)
    player.available_actions={"entity_uuid":"hero","discovery_generation":0,"subjects":choices.subjects,"positions":choices.positions,"target_sets":[pool],"entity_actions":[missile]}
    player.select_action(missile); player.requests.clear()
    var preview = {"can_confirm":true,"next_target_set":0,"subjects":[{"uuid":"other","kind":"creature"}],
        "positions":[[9,10],[11,12],[13,14]],"target_sets":[[{"kind":"subject","subject":0,"position":0,"index":82}]],
        "next_positions":[1],"affected_positions":[2],"area_preview":"computed"}
    player.selection_preview=preview
    player.choose_target([9,10],"other"); player.choose_target([9,10],"other")
    check(player.requests.size()==2 and player.requests[-1].selection.target_indices==[82,82],"Compound continuation resolves Preview-local ref0 and preserves repeats")
    check(not player.requests[-1].auto,"Multi-entity action keeps explicit confirmation")
    player.choose_target([11,12])
    check(player.requests[-1].selection.extra_target_positions==[[11,12]],"Next position references resolve only within Preview")
    player.confirm_selection()
    check(player.submitted[-1].selection.target_indices==[82,82] and player.submitted[-1].selection.extra_target_positions==[[11,12]],"Confirmation submits exact ordered compound selection")
    player.selection_preview={"can_confirm":false,"next_target_set":0,"target_sets":[[]],"area_preview":"deferred"}
    var requests: int = player.requests.size()
    player.choose_target([2,3],"goblin")
    check(player.requests.size()==requests,"Explicit empty continuation cannot fall back to initial eligibility")
    check(player.selection_preview.area_preview=="deferred" and not player.selection_preview.has("affected_positions"),"Unknown deferred footprint stays distinct from computed-empty")
    player.selection_preview={}
    player.choose_target([2,3],"goblin")
    check(player.requests[-1].selection.target_indices==[82,82,7],"Before a Preview arrives, initial pool uses Choices domains")

    # Returned raw preview publication preserves omitted fields and resolves only
    # the small visible affected footprint; stale replies remain rejected.
    player.session.status={"boundary":{"state_revision":"rev","input_actor_uuid":player.available_actions.entity_uuid}}
    player.selection_serial=7
    player.action_revision="rev"
    player.timeline.state={"current_actor_uuid":player.available_actions.entity_uuid}
    player.pending_request={"kind":"preview","serial":7,"revision":"rev","generation":0,"auto_confirm":false,
        "actor_uuid":player.available_actions.entity_uuid,"selection":player.target_selection.duplicate(true)}
    player.action_request=4
    player.session.responses[4]={"ok":true,"value":{"preview":preview}}
    player._poll_actions()
    check(is_same(player.selection_preview,preview) and player.preview_positions==[[13,14]],"Raw admitted Preview is borrowed; visible footprint resolves own table")
    check(not player.selection_preview.has("reason"),"Publication does not default-expand sparse Preview")
    player.pending_request.serial=6; player.action_request=5
    player.session.responses[5]={"ok":true,"value":{"preview":{"can_confirm":false,"next_target_set":0,"target_sets":[[]]}}}
    player._poll_actions()
    check(is_same(player.selection_preview,preview),"Late selection serial cannot replace current Preview")

    var sparse = row("action.dash","self",0)
    var discovery = {"entity_uuid":"hero","discovery_generation":0,"self_actions":[sparse],"target_sets":[[{"kind":"self","index":0}]]}
    var groups = UI.families(discovery,{})
    check(groups.Base.size()==1 and is_same(groups.Base[0].rows[0],sparse),"Missing affordance defaults to action bar without copying row")
    check(UI.action_text(sparse)=="action.dash","Omitted description/facets/costs produce exact sparse label")
    var world = FixtureWorld.new(); world.timeline.state={"current_actor_uuid":"hero","tiles":{}}
    world.available_actions=discovery; world.camera=Camera3D.new();world.add_child(world.camera);root.add_child(world)
    var hud = FootprintHUD.new();hud.world=world;root.add_child(hud)
    hud._select_row(sparse)
    check(world.issued.size()==1,"HUD executes admitted sparse default-index action")
    var replacement = discovery.duplicate(true)
    world.available_actions=replacement
    hud._select_row(sparse)
    check(world.issued.size()==1,"Same-generation replacement rejects the formerly borrowed sparse row")
    hud._select_row(replacement.self_actions[0])
    check(world.issued.size()==2,"Replacement sparse row executes through current response ownership")
    world.issued.clear();world.available_actions=discovery;hud._select_row(sparse)
    player.available_actions=discovery;player.requests.clear();player.select_action(sparse)
    check(player.requests.size()==1,"Player accepts currently borrowed sparse action")
    player.available_actions=replacement;player.select_action(sparse)
    check(player.requests.size()==1,"Player independently rejects same-generation old-response row")
    world.timeline.state.current_actor_uuid="another"
    hud._select_row(sparse)
    check(world.issued.size()==1,"HUD rejects painted choices after actor changes")
    world.timeline.state.current_actor_uuid="hero"
    world.available_actions={"entity_uuid":"hero","discovery_generation":1,"self_actions":[]}
    hud._select_row(sparse)
    check(world.issued.size()==1,"HUD rejects stale sparse generation zero")
    world.selected_action={};world.hover_preview=preview
    for position in [[9,10],[11,12],[13,14]]: world.timeline.state.tiles["%d,%d" % position]={"position":position,"elevation_steps":0}
    hud._update_ground_preview()
    check(world.ground_overlay.marks.keys()==["9,10","11,12","13,14"],"Ground UI marks contacts, next points and affected points in Preview-local coordinates")
    world.selected_action=missile; world.selection_preview=preview
    world.timeline.state.tiles["20,21"]={"position":[20,21],"elevation_steps":0}
    world.hover_preview={"positions":[[20,21]],"affected_positions":[0],"area_preview":"computed","next_positions":[],"next_target_set":0,"target_sets":[[]]}
    hud._update_ground_preview()
    check(world.ground_overlay.marks.keys()==["9,10","11,12","20,21"],"Prospective empty continuation preserves selected-prefix legal subjects and extra positions while replacing affected area")
    world.selected_action={}
    world.hover_preview={"can_confirm":false,"next_target_set":0,"target_sets":[[]],"area_preview":"deferred"}
    hud._update_ground_preview()
    check(world.ground_overlay.marks.is_empty(),"Deferred AoE draws no invented footprint")
    check(choices==original,"Interaction and HUD leave shared source domains unchanged")
    native_number_cases(player,choices)
    content_ref_cases()
    hud.free();world.free();player.context_menu.free();player.free()
    var report={"checks":checks,"failures":failures,"boundary":"compact values to native selections and HUD footprint coordinates; no gameplay/pixel claim"}
    var file=FileAccess.open("res://generated/compact_interaction_checks.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
    print("COMPACT_INTERACTION_CHECKS ",checks," passed=",checks-failures.size()," failed=",failures.size())
    quit(0 if failures.is_empty() else 1)

func native_number_cases(player: ClickPlayer, choices: Dictionary) -> void:
    # Use the same native parser as trusted live discovery, not manually cast
    # fixtures: world picking still supplies integer cell coordinates.
    var native: Dictionary = JSON.parse_string(JSON.stringify(choices))
    var snapshot = native.duplicate(true)
    check(typeof(native.positions[1][0])==TYPE_FLOAT and native.positions[1]!=[4,5],"Native JSON reproduces float-array versus integer-picked coordinate boundary")
    check(Interaction.same_position(native.positions[1],[4,5]),"Coordinate equality compares numeric values")
    check(not Interaction.same_position(null,[4,5]) and not Interaction.same_position([4,5],null) and not Interaction.same_position(null,null),"Missing contacts never become a coordinate match")
    check(not Interaction.same_position(native.positions[1],[4,6]) and not Interaction.same_position([],[]),"Different or absent coordinates stay unmatched")
    var native_move: Dictionary = native.position_actions[0]
    var target = Interaction.target(native,Choices.action_options(native,native_move),[4,5])
    check(not target.is_empty() and target.index==23,"Hover/direct lookup resolves native JSON positions from integer picks")
    var approach = Interaction.approach(native,{"contact_positions":[[4,5],[6,7]]})
    check(not approach.is_empty() and approach.selection.target_indices[0]==23,"Approach accepts numeric-equal contacts without changing hazard/cost selection")
    player.cancel_selection();player.requests.clear();player.available_actions=native
    player.choose_target([4,5])
    check(player.requests.is_empty() and player.submitted[-1].selection.target_indices[0]==23 and player.submitted[-1].discovery_generation==native.discovery_generation,"Integer movement click directly submits the exact native index and generation")
    player.cancel_selection();player.requests.clear()
    player.select_action(native_move);player.requests.clear();player.choose_target([4,5])
    check(player.requests.is_empty() and player.submitted[-1].selection.target_indices[0]==23,"Selected movement also directly submits integer clicks into float domains")
    check(native==snapshot and typeof(native.positions[1][0])==TYPE_FLOAT,"Coordinate selection does not normalize or mutate the admitted response")
    var submitted: int = player.submitted.size()
    player._execute_admitted({"action":native_move,"selection":Interaction.selection(native_move,[target.index],false)})
    check(player.submitted.size()==submitted+1 and not player.submitted[-1].selection.prefer_safe,"Direct movement preserves explicit hazardous-route preference")
    submitted=player.submitted.size()
    player._execute_admitted({"action":native_move.duplicate(true),"selection":Interaction.selection(native_move,[target.index])})
    check(player.submitted.size()==submitted,"A formerly borrowed or copied row cannot bypass current discovery ownership")
    player._execute_admitted({"action":native_move,"selection":{"action_index":native_move.discovery_index,"target_indices":[target.index],"extra_target_positions":[[8,9]],"prefer_safe":true}})
    check(player.submitted.size()==submitted and player.requests.size()==1,"Additional position selection retains Preview instead of assuming completeness")

    var compound: Dictionary = JSON.parse_string(JSON.stringify({"entity_uuid":"hero","discovery_generation":0,
        "entity_actions":[row("spell.fixture_path","multi_entity",0)],"positions":[[2,3]],
        "target_sets":[[{"kind":"position","position":0,"index":7}]]}))
    var preview: Dictionary = JSON.parse_string('{"can_confirm":true,"next_target_set":0,"positions":[[9,10],[11,12]],"target_sets":[[{"kind":"position","position":0,"index":82}]],"next_positions":[1]}')
    var preview_before = preview.duplicate(true)
    player.cancel_selection();player.available_actions=compound;player.select_action(compound.entity_actions[0]);player.requests.clear()
    player.selection_preview=preview
    player.choose_target([9,10]);player.choose_target([9,10]);player.choose_target([11,12])
    check(player.requests.size()==3,"Integer compound clicks match native Preview bindings and extra positions")
    if not player.requests.is_empty():
        var selection: Dictionary = player.requests[-1].selection
        check(selection.target_indices.size()==2 and selection.target_indices[0]==82 and selection.target_indices[1]==82,"Float-backed Preview preserves repeated native target indices")
        check(selection.extra_target_positions==[[11,12]],"Preview-local float extra position submits the exact integer picked coordinate")
    var count: int = player.requests.size()
    player.choose_target([9,11])
    check(player.requests.size()==count,"Unadvertised neighboring coordinate remains rejected")
    check(preview==preview_before and typeof(preview.positions[0][0])==TYPE_FLOAT,"Compound interaction leaves Preview domains immutable")

func content_ref_cases() -> void:
    # Actual authored owner/icon metadata, with the integer version retained by
    # canonical state and a native-JSON copy as delivered by trusted choices.
    var cache = {}
    var choice: Dictionary = UI.authored(cache).choices[0]
    var canonical: Dictionary = choice.owner.duplicate()
    canonical.content_version=int(canonical.content_version)
    var native: Dictionary = JSON.parse_string(JSON.stringify(canonical))
    var state = {"content":[{"ref":canonical,"presentation":{"icon_key":"fixture.base"}}]}
    var action = row(canonical.content_id,"self",0)
    action.configured_action_ref=native
    var snapshot = action.duplicate(true)
    check(typeof(native.content_version)==TYPE_FLOAT and typeof(canonical.content_version)==TYPE_INT and native!=canonical,"Native configured reference reproduces strict dictionary numeric mismatch")
    check(UI.action_key(action,state,cache)=="fixture.base","Native configured reference resolves the canonical base icon")
    action.variant_facets=[{"key":choice.facet,"value":choice.value,"label":choice.label}]
    for field in choice.requirements:
        action.variant_facets.append({"key":field,"value":choice.requirements[field],"label":field})
    check(UI.action_key(action,state,cache,true)==choice.icon_key,"Native configured owner retains the actual authored variant icon")
    action.erase("configured_action_ref")
    check(UI.action_key(action,state,cache,true)==choice.icon_key,"Canonical fallback owner matches authored native-JSON variant metadata")
    check(Interaction.same_content_ref(null,null) and not Interaction.same_content_ref(null,native) and not Interaction.same_content_ref(canonical,null),"Only jointly absent optional references compare equal")
    for field in ["pack_id","definition_kind","content_id","content_version","definition_contract_hash"]:
        var changed = canonical.duplicate()
        changed[field]=canonical[field]+1 if field=="content_version" else str(canonical[field])+".different"
        check(not Interaction.same_content_ref(changed,native),"Different content identity field is never aliased: "+field)
    var option = {"subject_uuid":"wall","behavior_id":"action.open","configured_action_ref":canonical}
    var native_option: Dictionary = JSON.parse_string(JSON.stringify(option))
    check(Interaction.same_option(option,native_option),"World rediscovery compares configured identity by value across number representations")
    var opened = row("action.open","object",0)
    opened.configured_action_ref=native;opened.interaction_affordance={"surface":"world"}
    var discovery = {"object_actions":[opened],"subjects":[{"kind":"object","uuid":"wall"}],"target_sets":[[{"kind":"subject","subject":0,"index":17}]]}
    var admitted = Interaction.admitted(discovery,option)
    check(admitted.size()==1 and admitted[0].selection.target_indices==[17],"Mixed configured-reference representations preserve exact world action admission")
    check(native==snapshot.configured_action_ref and typeof(native.content_version)==TYPE_FLOAT,"Content matching leaves raw query metadata untouched")
