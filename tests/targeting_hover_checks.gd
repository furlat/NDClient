extends SceneTree
## Current real-server Choices/Preview values drive the actual Play gesture path.
const Choices = preload("res://sdk/choices.gd")
const Interaction = preload("res://presentation/interaction.gd")
const UI = preload("res://presentation/ui_catalog.gd")
const Fixtures = preload("res://tests/recording_fixtures.gd")
const Protocol = preload("res://sdk/protocol.gd")
class QueryPeer extends RefCounted:
    var requests: Dictionary = {}
    var responses: Dictionary = {}
    var status: Dictionary = {}
    var next_id = 0
    func request(operation: String, body: Dictionary = {}) -> int:
        next_id += 1
        requests[next_id] = {"operation":operation,"body":body.duplicate(true)}
        return next_id
    func retire_record(_value: Dictionary) -> void: pass
    func close() -> void: pass
    func matches_choice_boundary(_value:Dictionary)->bool:return true
class PointerHUD extends Control:
    var captured = false
    func pointer_over_controls(_point: Vector2 = Vector2.INF) -> bool: return captured
    func owns_keyboard_focus() -> bool: return captured
    func clear_hover_feedback() -> void: pass
    func show_item_targets() -> void: pass
class GroundHUD extends "res://play_hud.gd":
    func _ready() -> void:
        super._ready()
        set_process(false)
    func pointer_over_controls(_point: Vector2 = Vector2.INF) -> bool: return false
class Player extends "res://play.gd":
    var pointer: Dictionary = {}
    var submitted: Array = []
    func _ready() -> void:
        set_process(false); set_process_unhandled_input(false)
        add_child(context_menu)
        hud = PointerHUD.new(); add_child(hud)
    func _process(_delta: float) -> void: pass
    func command_ready() -> bool: return not command_busy and action_request<0
    func pick_world(_point: Vector2) -> Dictionary: return pointer
    func pick_cell(_point: Vector2) -> Dictionary: return {}
    func _submit(intent: Dictionary) -> void: submitted.append(intent.duplicate(true))
var checks = 0
var failures: Array = []
var scene: Player
var peer: QueryPeer
func check(value: bool, label: String) -> void:
    checks += 1
    if not value: failures.append(label); printerr("TARGETING_HOVER_FAIL ",label)
func action(domain: Dictionary, behavior: String, index: float) -> Dictionary:
    for row in Choices.all_actions(domain):
        if row.behavior_id==behavior and row.get("discovery_index",0)==index: return row
    return {}
func reply(request: int, value: Dictionary, hover: bool = false) -> void:
    peer.responses[request] = {"ok":true,"value":{"preview":value}}
    if hover: update_hover()
    else: scene._poll_actions()
func update_hover() -> void:
    scene.hover_due = 0
    scene._update_hover()
func _initialize() -> void: run.call_deferred()
func run() -> void:
    var fixture = ""
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--case="): fixture = arg.trim_prefix("--case=")
    if fixture.is_empty(): printerr("Pass --case=res://.runtime/targeting-preview-.../checks.json"); quit(2); return
    var evidence: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fixture))
    check(evidence.ok,"Fixture is independently qualified real-server preview-only evidence")
    var domain: Dictionary = evidence.choices
    var fireballs: Array = evidence.records.filter(func(row):return row.behavior=="spell.fireball")
    var missiles: Array = evidence.records.filter(func(row):return row.behavior=="spell.magic_missile")
    scene = Player.new(); peer = QueryPeer.new(); scene.session = peer; root.add_child(scene)
    peer.status = {"boundary":{"state_revision":evidence.before_status.boundary.state_revision,"input_actor_uuid":domain.entity_uuid}}
    scene.action_revision = peer.status.boundary.state_revision
    scene.available_actions = domain
    var folded:Dictionary=Fixtures.canonical(fixture.get_base_dir(),int(evidence.before_status.published_cursor.sequence))
    check(folded.ok,"Original current-schema journal folds through the query boundary")
    if not folded.ok:quit(1);return
    scene.timeline.state=folded.value
    var fireball = action(domain,"spell.fireball",fireballs[0].selection.action_index)
    var fireball_text = UI.action_text(fireball)
    check(fireball_text.contains("8d6 Fire") and fireball_text.contains("DC 15 dexterity save") and fireball_text.contains("Half damage on successful save"),"Real Fireball tooltip preserves native damage dice, save DC/ability and half-save fact")
    check(not fireball_text.contains("%"),"Fireball tooltip invents no target probability")
    scene.select_action(fireball)
    check(fireball.get("position_region")!=null and scene.action_request<0,"Current free-aim row waits for an aimed position before Preview")
    var empty_selection:Dictionary=scene.target_selection.duplicate(true)
    var first_record:Dictionary=evidence.indexed_fireballs[0]
    var second_record:Dictionary=evidence.indexed_fireballs[1]
    var first:Array=Choices.binding_position(domain,Choices.action_options(domain,fireball).filter(func(row):return row.index==first_record.selection.target_indices[0])[0])
    var second:Array=Choices.binding_position(domain,Choices.action_options(domain,fireball).filter(func(row):return row.index==second_record.selection.target_indices[0])[0])
    scene.pointer = {"kind":"ground","position":first}
    update_hover()
    var first_query = scene.hover_request
    check(Protocol._equal(peer.requests[first_query].body.selection,first_record.selection),"Selected Fireball hover queries exact actual candidate prefix")
    check(scene.target_selection.target_indices.is_empty() and scene.submitted.is_empty(),"Prospective hover does not select or spend")
    reply(first_query,first_record.preview,true)
    check(scene.hover_preview==first_record.preview and scene.selection_preview.is_empty(),"Computed Fireball hover and selected-prefix preview stay separate")
    check(Choices.preview_positions(scene.hover_preview,true).size()==49,"Visible Fireball footprint is the actual 49 SDK cells")
    check(scene.hover_cursor==Input.CURSOR_CROSS,"Actual admitted spell candidate has targeting cursor")
    scene.camera = Camera3D.new(); scene.add_child(scene.camera)
    var ground_hud = GroundHUD.new(); ground_hud.world=scene; root.add_child(ground_hud)
    ground_hud._update_ground_preview()
    var stable_marks: Dictionary = scene.ground_overlay.marks.duplicate(true)
    var legal_styles: Dictionary = ground_hud.ground_base_marks.duplicate(true)
    var stable_revision: int = scene.ground_overlay.preview_revision
    var old_cursor_position: Array = scene.hover_intent.value.position
    var old_cursor_cell = "%d,%d" % [old_cursor_position[0],old_cursor_position[1]]
    var eligibility_cells: Array = []
    for position in Interaction.region_positions(domain,fireball,scene.timeline.state):
        if scene.timeline.state.tiles.has("%d,%d"%[position[0],position[1]]):eligibility_cells.append("%d,%d" % [position[0],position[1]])
    check(not eligibility_cells.is_empty() and eligibility_cells.all(func(cell):return stable_marks.has(cell)),"Computed hover retains every legal aim cell from the selected-prefix domain")
    var count = peer.requests.size()
    update_hover()
    check(peer.requests.size()==count,"Unchanged pointer/prefix does not refetch")
    # Launch two different pointer intents, and deliver the old reply last.
    scene.pointer = {"kind":"ground","position":second}
    update_hover()
    var newer = scene.hover_request
    var new_cursor_position: Array = scene.hover_intent.value.position
    var new_cursor_cell = "%d,%d" % [new_cursor_position[0],new_cursor_position[1]]
    check(new_cursor_position==second,"Moving aim uses the exact admitted target position for the cursor")
    var pending_revision = -1
    for frame in range(6):
        update_hover(); ground_hud._update_ground_preview()
        if frame==0: pending_revision=scene.ground_overlay.preview_revision
        var pending_marks: Dictionary = scene.ground_overlay.marks
        check(scene.hover_preview==first_record.preview and without_cursor_outlines(pending_marks,[old_cursor_cell,new_cursor_cell])==without_cursor_outlines(stable_marks,[old_cursor_cell,new_cursor_cell]) and eligibility_cells.all(func(cell):return pending_marks.has(cell)),"Delayed valid aim frame %d preserves every eligibility/fill cell; only old/new cursor outlines may change" % frame)
        check(pending_marks.get(new_cursor_cell,{}).get("colour")==Color("70d6be") and scene.ground_overlay.preview_revision==pending_revision,"Delayed valid aim frame %d keeps its admitted cursor without rebuilding unchanged marks" % frame)
    check(pending_revision==stable_revision+1,"Moving cursor publishes one mark update while the authoritative footprint remains held")
    reply(newer,second_record.preview,true)
    ground_hud._update_ground_preview()
    check(scene.hover_preview==second_record.preview and eligibility_cells.all(func(cell):return scene.ground_overlay.marks.has(cell)),"Latest authoritative footprint replaces atomically without changing selected-prefix eligibility")
    check(ground_hud.ground_base_marks==legal_styles,"Hover fill and cursor overrides do not mutate the selected-prefix legal styles")
    var departed = Choices.preview_positions(first_record.preview,true).filter(func(position):return position not in Choices.preview_positions(second_record.preview,true))
    check(not departed.is_empty(),"Real Fireball aim change leaves cells outside its previous footprint")
    for position in departed:
        var cell = "%d,%d" % [position[0],position[1]]
        check(scene.ground_overlay.marks.get(cell,{}).get("fill_colour",Color.TRANSPARENT)==Color.TRANSPARENT,"Departed affected cell loses fill: "+cell)
    scene.pointer = {"kind":"ground","position":first}
    update_hover()
    scene.pointer = {"kind":"ground","position":second}
    update_hover()
    newer = scene.hover_request
    scene.pointer = {"kind":"ground","position":first}
    update_hover()
    var latest = scene.hover_request
    reply(latest,first_record.preview,true)
    reply(newer,second_record.preview,true)
    check(scene.hover_preview==first_record.preview,"Late reply for earlier pointer cannot repaint latest aim")
    check(scene.target_selection==empty_selection and scene.submitted.is_empty(),"Delayed/reordered footprint updates never select or spend the retained candidate")
    ground_hud.free()
    scene.hud.captured = true
    update_hover()
    check(scene.hover_preview.is_empty() and scene.hover_cursor==Input.CURSOR_ARROW,"GUI capture clears world preview and returns native control cursor")
    scene.hud.captured = false
    scene.pointer = {"kind":"ground","position":[10000,10000]}
    count = peer.requests.size(); update_hover()
    check(scene.hover_cursor==Input.CURSOR_FORBIDDEN and peer.requests.size()==count,"Undisclosed illegal aim gets no invented preview")
    check(scene.hover_preview.is_empty(),"Invalid aim clears the retained prospective footprint")
    var floor_record:Dictionary=fireballs[3]
    var floor_position:Array=floor_record.selection.extra_target_positions[0]
    scene.pointer={"kind":"ground","position":floor_position}
    update_hover()
    check(Protocol._equal(peer.requests[scene.hover_request].body.selection,floor_record.selection),"Unoccupied floor hover sends the exact free-aim coordinate")
    reply(scene.hover_request,floor_record.preview,true)
    check(scene.hover_preview.geometry.center==floor_position and scene.target_selection==empty_selection and scene.submitted.is_empty(),"Empty floor shows its authoritative footprint without selecting or spending")
    scene.pointer = {"kind":"ground","position":first}
    update_hover()
    reply(scene.hover_request,first_record.preview,true)
    scene.choose_target(first)
    check(scene.hover_preview.is_empty() and scene.selection_preview.is_empty() and scene.selection_media_preview==first_record.preview,"Clicked selection query retains only the last authoritative resource preview while visual authority waits for its reply")
    reply(scene.action_request,first_record.preview)
    check(scene.submitted.size()==1 and Protocol._equal(scene.submitted[0].selection,first_record.selection),"Clicked Fireball submits exactly the prospectively queried selection")
    var missile = action(domain,"spell.magic_missile",missiles[0].selection.action_index)
    var missile_text = UI.action_text(missile)
    check(missile_text.contains("1d4+1 Force") and missile_text.contains("3 projectiles") and missile_text.contains("spell slot 1"),"Real Missile tooltip preserves per-projectile dice/count and actual slot cost")
    check(not missile_text.contains("%"),"Missile tooltip invents no target probability")
    scene.auto_confirm_targets=false
    scene.select_action(missile)
    reply(scene.action_request,missiles[0].preview)
    for i in range(1,4):
        var index: float = missiles[i].selection.target_indices[-1]
        var candidate = Choices.next_options(scene.selection_preview).filter(func(row):return row.index==index)[0]
        var subject: Dictionary = Choices.binding_subject(scene.selection_preview,candidate)
        var position: Array = Choices.binding_position(scene.selection_preview,candidate)
        scene.pointer = {"kind":"actor","id":subject.uuid,"position":position}
        update_hover()
        check(Protocol._equal(peer.requests[scene.hover_request].body.selection,missiles[i].selection),"Prospective recipient %d preserves real ordered/repeated prefix" % i)
        reply(scene.hover_request,missiles[i].preview,true)
        scene.choose_target(position,subject.uuid)
        reply(scene.action_request,missiles[i].preview)
    check(scene.target_selection.target_indices==missiles[3].selection.target_indices and scene.submitted.size()==1,"A/B/A prefix retains repeats and never auto-confirms")
    var undo = InputEventKey.new(); undo.pressed=true; undo.physical_keycode=KEY_BACKSPACE
    scene._unhandled_input(undo)
    check(Protocol._equal(peer.requests[scene.action_request].body.selection,missiles[4].selection),"Undo queries the actual A/B continuation")
    reply(scene.action_request,missiles[4].preview)
    scene.confirm_selection()
    check(Protocol._equal(scene.submitted[-1].selection,missiles[4].selection),"Confirm after undo submits exact remaining ordered prefix")
    scene.auto_confirm_targets=true
    scene.select_action(missile)
    reply(scene.action_request,missiles[0].preview)
    var before_auto:int=scene.submitted.size()
    for i in range(1,4):
        var candidate:Dictionary=Choices.next_options(scene.selection_preview).filter(func(row):return row.index==missiles[i].selection.target_indices[-1])[0]
        var subject:Dictionary=Choices.binding_subject(scene.selection_preview,candidate)
        scene.choose_target(Choices.binding_position(scene.selection_preview,candidate),subject.uuid)
        reply(scene.action_request,missiles[i].preview)
        check(scene.submitted.size()==before_auto+(1 if i==3 else 0),"Automatic completion waits for exhausted real continuation at selection %d"%i)
    check(Protocol._equal(scene.submitted[-1].selection,missiles[3].selection),"Automatic completion submits the exact ordered repeated selection once")
    var upcasts:Array=evidence.upcast_records
    var upcast:Dictionary=Interaction.level_rows(missile).filter(func(row):return row.cast_at_level==upcasts[0].selection.cast_at_level)[0]
    check(upcast.num_projectiles==3 and upcasts.size()==5,"Actual upcast retains base count but requires four recipient selections")
    scene.select_action(upcast)
    reply(scene.action_request,upcasts[0].preview)
    var before_upcast:int=scene.submitted.size()
    for i in range(1,upcasts.size()):
        var candidate:Dictionary=Choices.next_options(scene.selection_preview).filter(func(row):return row.index==upcasts[i].selection.target_indices[-1])[0]
        var subject:Dictionary=Choices.binding_subject(scene.selection_preview,candidate)
        scene.choose_target(Choices.binding_position(scene.selection_preview,candidate),subject.uuid)
        check(Protocol._equal(peer.requests[scene.action_request].body.selection,upcasts[i].selection),"Upcast recipient %d preserves selected level and exact prefix"%i)
        reply(scene.action_request,upcasts[i].preview)
        check(scene.submitted.size()==before_upcast+(1 if i==4 else 0),"Upcast auto-confirm waits for the fourth real server target at selection %d"%i)
    check(Protocol._equal(scene.submitted[-1].selection,upcasts[-1].selection),"Completed upcast submits its exact selection once")
    scene.auto_confirm_targets=false
    for selected_record in [first_record,floor_record]:
        scene.select_action(fireball)
        var before_manual:int=scene.submitted.size()
        scene.choose_target(selected_record.preview.geometry.center)
        reply(scene.action_request,selected_record.preview)
        check(scene.submitted.size()==before_manual and scene.selection_preview.can_confirm,"Disabled auto-confirm keeps a complete indexed or free floor aim for review")
        scene.confirm_selection()
        check(scene.submitted.size()==before_manual+1 and Protocol._equal(scene.submitted[-1].selection,selected_record.selection),"Manual Confirm submits the exact reviewed aim once")
    scene.auto_confirm_targets=true
    scene.select_action(missile)
    var cancelled = scene.action_request
    scene.cancel_selection()
    peer.responses[cancelled] = {"ok":false,"error":{"message":"Late cancelled preview","retryable":false}}
    scene._poll_actions()
    check(scene.action_revision==evidence.before_status.boundary.state_revision and scene.notice_text!="Late cancelled preview","Cancelled preview error cannot invalidate current discovery or show stale error")
    for changed in ["actor","authority","revision","generation","prefix","row"]:
        scene.available_actions = domain
        scene.timeline.state.current_actor_uuid = domain.entity_uuid
        scene.action_revision = evidence.before_status.boundary.state_revision
        peer.status.boundary.state_revision = scene.action_revision
        peer.status.boundary.input_actor_uuid = domain.entity_uuid
        scene.select_action(missile)
        var pending = scene.action_request
        match changed:
            "actor": scene.timeline.state.current_actor_uuid = "different-actor"
            "authority": peer.status.boundary.input_actor_uuid = "different-authority"
            "revision": peer.status.boundary.state_revision = "different-revision"
            "generation":
                scene.available_actions = domain.duplicate(true)
                scene.available_actions.discovery_generation += 1
            "prefix": scene.target_selection.target_indices.append(missiles[1].selection.target_indices[0])
            "row": scene.available_actions = domain.duplicate(true)
        reply(pending,missiles[1].preview)
        check(scene.selection_preview.is_empty(),"Changed %s rejects old selection reply before publication" % changed)
    scene.free()
    var report = {"checks":checks,"failures":failures,"ok":failures.is_empty(),"fixture":fixture,"scope":"Actual Play targeting/hover/undo/confirm and current real-server preview data; controlled reply ordering; no game commands or GPU claim"}
    FileAccess.open("res://generated/targeting_hover_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print(JSON.stringify(report)); quit(0 if failures.is_empty() else 1)

func without_cursor_outlines(marks: Dictionary, cursor_cells: Array) -> Dictionary:
    var result = marks.duplicate(true)
    for cell in cursor_cells:
        if not result.has(cell): continue
        result[cell].erase("colour")
        result[cell].erase("width")
        # A cursor-only cell has no eligibility/fill contribution to retain.
        if result[cell].is_empty(): result.erase(cell)
    return result
