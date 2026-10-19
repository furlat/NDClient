extends SceneTree
## One native process, fresh real Play/session per authored case; no replayed commands.
const NativeItems=preload("res://presentation/native_items.gd")
const Play=preload("res://play.gd")
const Choices=preload("res://sdk/choices.gd")
const Placement=preload("res://placement.gd")
var scene:Node
var viewport:SubViewport
var batch_path=""
var last_id=""
var last_request_file=""
var checks=0
var failures:Array=[]
var report:Dictionary={}
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->bool:
    checks+=1
    if not ok:failures.append(label);print("LIVE_SPELL_SAFETY_FAIL ",label)
    return ok
func healthy()->bool:
    return scene!=null and scene.session.issue.is_empty() and scene.presentation_errors.is_empty() and scene.media_issue.is_empty()
func until(predicate:Callable,label:String,timeout_ms:int=60000)->bool:
    var deadline=Time.get_ticks_msec()+timeout_ms
    while not predicate.call() and healthy() and Time.get_ticks_msec()<deadline:await process_frame
    return check(predicate.call() and healthy(),label)
func click(point:Vector2)->void:
    var motion=InputEventMouseMotion.new();motion.position=point;motion.global_position=point
    viewport.push_input(motion,true)
    var button=InputEventMouseButton.new();button.position=point;button.global_position=point;button.button_index=MOUSE_BUTTON_LEFT;button.pressed=true
    viewport.push_input(button,true)
    button=button.duplicate();button.pressed=false;viewport.push_input(button,true)
func hover(point:Vector2)->void:
    var motion=InputEventMouseMotion.new();motion.position=point;motion.global_position=point
    viewport.push_input(motion,true)
func actor_screen(id:String)->Vector2:
    var row:Dictionary=scene.timeline.state.actors.get(id,{})
    if row.is_empty() or row.get("last_visual_position")==null:return Vector2(INF,INF)
    var cell:Array=row.last_visual_position
    var base=scene.camera.unproject_position(Vector3(cell[0],.7,cell[1]))
    for entry in scene.visual_actors.get(id,{}).get("entries",[]):
        if entry.get("role")=="body" and entry.node.visible:
            base=scene.camera.unproject_position(entry.node.global_transform*entry.node.mesh.center_offset);break
    for y in range(-35,36,5):
        for x in range(-25,26,5):
            var point=base+Vector2(x,y)
            if scene.pick_actor(point)==id and not scene.hud.pointer_over_controls(point):return point
    return Vector2(INF,INF)
func grid_screen(cell:Array)->Vector2:
    var tile:Dictionary=scene.timeline.state.tiles.get("%d,%d"%[cell[0],cell[1]],{})
    return scene.camera.unproject_position(Vector3(cell[0],float(tile.get("elevation_steps",0))*Placement.HEIGHT_UNIT,cell[1]))
func turn_of(role:String,names:Dictionary)->bool:
    for turn in 32:
        if not await until(func():return scene.command_ready(),"Actual player choices ready"):return false
        var actor:String=scene.available_actions.entity_uuid
        if scene.timeline.state.actors.get(actor,{}).get("name")==names.get(role,role):return true
        var sequence:int=scene.timeline.sequence
        click(scene.hud.end_button.get_global_rect().get_center())
        if not await until(func():return scene.timeline.sequence>sequence and scene.command_ready(),"Native End Turn advances the actual input actor"):return false
    return check(false,"Required actor never received input: "+role)
func select_family(behavior:String)->bool:
    for page in 32:
        if not await until(func():return not scene.hud.bar_pending(),"Action bar prepared"):return false
        for button in scene.hud.action_buttons:
            if button.get_meta("family",{}).get("rows",[]).any(func(row):return row.behavior_id==behavior):
                if not check(not button.disabled,"Actual bar offers "+behavior):return false
                click(button.get_global_rect().get_center());await process_frame
                if scene.hud.popup.visible:
                    var selected:Button
                    for choice in scene.hud.popup_rows:
                        if not choice.disabled and choice.get_meta("native_row",{}).get("behavior_id")==behavior:selected=choice;break
                    if not check(selected!=null,"Variant modal offers "+behavior):return false
                    click(selected.get_global_rect().get_center())
                return true
        var next:Button
        for button in scene.hud.bar.find_children("*","Button",true,false):
            if button.text=="›" and button.tooltip_text.begins_with("Spells page "):next=button;break
        if next==null:break
        click(next.get_global_rect().get_center());await process_frame
    return check(false,"No actual action-bar family for "+behavior)
func target_point(step:Dictionary,names:Dictionary)->Vector2:
    var action:Dictionary=scene.selected_action
    var preview:Dictionary=scene.selection_preview
    var requested:Variant=step.get("target","first_legal")
    if step.has("then") and not scene.target_selection.target_indices.is_empty() and scene.target_selection.extra_target_positions.is_empty():
        var allowed:Array=Choices.preview_positions(preview)
        if allowed.any(func(cell):return Play.Interaction.same_position(cell,step.then)):return grid_screen(step.then)
        # Some native selections offer the destination as another binding,
        # others as a position-only domain. Match the exact authored cell in
        # either public form; do not choose an unrelated first legal target.
        requested=step.then
    if action.get("position_region")!=null:return grid_screen(step.get("aim",step.get("target",[])))
    var domains:Dictionary=scene.selection_preview if not scene.target_selection.target_indices.is_empty() else scene.available_actions
    var options:Array=Choices.next_options(domains) if domains.has("next_target_set") else Choices.action_options(domains,action)
    var recipients:Array=step.get("recipients",[])
    if scene.target_selection.target_indices.size()<recipients.size():requested=recipients[scene.target_selection.target_indices.size()]
    if step.get("target")=="first_legal":
        var order=[names.get("target"),names.get("ally"),names.get("caster")]
        options=options.duplicate()
        options.sort_custom(func(a,b):
            var left:Variant=Choices.binding_subject(domains,a);var right:Variant=Choices.binding_subject(domains,b)
            var li:int=order.find(left.get("name")) if left!=null else -1
            var ri:int=order.find(right.get("name")) if right!=null else -1
            return (order.size() if li<0 else li)<(order.size() if ri<0 else ri))
    for option in options:
        var subject:Variant=Choices.binding_subject(domains,option)
        var wanted:String=requested if requested is String else ""
        if wanted=="self":wanted=step.by
        if subject!=null and (wanted=="first_legal" or subject.get("name")==names.get(wanted,wanted)):
            if subject.get("kind")=="object":
                var inventory_button:Button=scene.hud.inventory_buttons.get(subject.uuid)
                if inventory_button!=null and inventory_button.is_visible_in_tree() and not inventory_button.disabled:
                    return inventory_button.get_global_rect().get_center()
                for slot in scene.hud.slot_buttons.values():
                    if slot.get_meta("item_uuid","")==subject.uuid and slot.is_visible_in_tree() and not slot.disabled:
                        return slot.get_global_rect().get_center()
            var point=actor_screen(subject.uuid)
            if point.is_finite():return point
        var position:Variant=Choices.binding_position(domains,option)
        if position!=null and requested is Array and Play.Interaction.same_position(position,requested):return grid_screen(position)
        if position!=null and step.get("target")=="first_legal" and subject==null:return grid_screen(position)
    return Vector2(INF,INF)
func execute(step:Dictionary,names:Dictionary)->bool:
    if not await turn_of(step.get("by","caster"),names):return false
    var sequence:int=scene.timeline.sequence
    if step.do=="end_turn":
        click(scene.hud.end_button.get_global_rect().get_center())
    else:
        if not await select_family(step.do):return false
        if not await until(func():return scene.timeline.sequence>sequence or (scene.action_request<0 and not scene.selected_action.is_empty() and (scene.selected_action.get("position_region")!=null or not scene.selection_preview.is_empty())),"Actual selected action ready for target input"):return false
        for selection_step in 24:
            if scene.timeline.sequence>sequence or scene.command_busy:break
            if scene.action_request>=0:
                if not await until(func():return scene.action_request<0,"Target preview reply"):return false
            if scene.selection_preview.get("can_confirm",false) and scene.target_selection.target_indices.size()>=step.get("recipients",[]).size() and (not scene.target_selection.target_indices.is_empty() or not scene.target_selection.extra_target_positions.is_empty()):
                if not check(scene.hud.confirm_button.visible and not scene.hud.confirm_button.disabled,"Native Confirm enabled"):return false
                click(scene.hud.confirm_button.get_global_rect().get_center());break
            var point=target_point(step,names)
            if not check(point.is_finite(),"Requested recipient/cell is actually pickable"):
                report.target_input={"behavior":scene.selected_action.get("behavior_id"),"target_indices":scene.target_selection.target_indices,
                    "extra_positions":scene.target_selection.extra_target_positions,"next_positions":Choices.preview_positions(scene.selection_preview),
                    "preview_reason":scene.selection_preview.get("reason"),"can_confirm":scene.selection_preview.get("can_confirm")}
                return false
            hover(point);await process_frame
            click(point);await process_frame
    var success=await until(func():return scene.timeline.sequence>sequence and not scene.timeline.busy() and not scene.command_busy,"Real command reduced and rendered to its boundary",90000)
    report.steps.append({"requested":step,"sequence_before":sequence,"sequence_after":scene.timeline.sequence,"ok":success})
    return success
func opponent(step:Dictionary,names:Dictionary)->bool:
    var sequence:int=scene.timeline.sequence
    var ordinal:int=report.steps.size()+1
    var requested={"behavior":step.do,"actor_name":names[step.by],"subject_name":names.get(step.get("target"),step.get("target")),"recipients":step.get("recipients",[])}
    var file=FileAccess.open(scene.game_config.blue_request,FileAccess.WRITE)
    file.store_string(JSON.stringify({"id":ordinal,"step":requested}));file.close()
    var deadline=Time.get_ticks_msec()+90000
    while healthy() and Time.get_ticks_msec()<deadline:
        if FileAccess.file_exists(scene.game_config.blue_result):
            var result:Variant=JSON.parse_string(FileAccess.get_file_as_string(scene.game_config.blue_result))
            if result is Dictionary and result.get("id")==ordinal:
                if not check(result.receipt.kind=="committed","Actual opponent trigger committed"):return false
                var ok=await until(func():return scene.timeline.sequence>sequence and not scene.timeline.busy(),"Opponent trigger and reaction rendered")
                report.steps.append({"requested":step,"sequence_before":sequence,"sequence_after":scene.timeline.sequence,"ok":ok,"opponent_receipt":result.receipt})
                return ok
        if scene.command_ready():click(scene.hud.end_button.get_global_rect().get_center())
        await process_frame
    return check(false,"Opponent trigger did not complete")
func case_run(request:Dictionary)->Dictionary:
    checks=0;failures=[];report={"id":request.id,"steps":[]}
    print("LIVE_SPELL_CASE_START ",request.id," ",request.scenario.id)
    viewport=SubViewport.new();viewport.size=Vector2i(1600,900);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    root.add_child(viewport)
    var display=TextureRect.new();display.size=Vector2(1600,900);display.texture=viewport.get_texture();display.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(display)
    scene=Play.new();viewport.add_child(scene);viewport.notify_mouse_entered()
    scene.grid_visible=false;scene.camera_focus=Vector3(5,0,7);scene.camera.size=9;scene.position_camera()
    var names={}
    for actor in request.scenario.actors:names[actor.role]=actor.side.capitalize()+" "+str(actor.role).replace("_"," ")
    for step in request.scenario.steps:
        if step.do in ["hold_walk","end_tracked","tail_walk"]:
            check(false,"Use explicit legal commands for live safety fixture, not recorder lifecycle macros");break
        var other:bool=false
        for actor in request.scenario.actors:
            if actor.role==step.get("by","caster"):other=actor.side!="amber"
        if other:
            if not await opponent(step,names):break
        elif not await execute(step,names):break
    report.native_items=[]
    if healthy():
        for owner in scene.timeline.item_appearance_owners.values():
            if not owner.reason.is_empty() or not NativeItems.active(owner,scene.timeline.state):continue
            var id:String="item:"+owner.item_uuid+":appearance"
            var drawn:bool=await until(func():return scene.component_renderer.native_spells.diagnostics.get(id,{}).get("status")=="rendered","Actual native item reaches first draw",30000)
            if drawn:
                var handle:Dictionary=scene.component_renderer.native_spells.handles[id]
                report.native_items.append({"id":id,"item_uuid":owner.item_uuid,"inputs":handle.created_item_input,"construction_ms":handle.construction_phases})
    report.merge({"checks":checks,"failures":failures,"ok":failures.is_empty(),"issue":scene.session.issue,"presentation_errors":scene.presentation_errors,
        "render_trace":scene.timeline.event_trace(2000)})
    if not failures.is_empty():
        report.player_boundary=scene.error_report(str(failures))
        report.preparation={"media":scene.media_gate,"component_ready":scene.component_renderer.ready,
            "pending_world":scene.pending_world.phase if scene.pending_world!=null else "none",
            "native_samples":scene.component_renderer.native_spells.diagnostics.values().map(func(row):return {
                "id":row.get("id"),"status":row.get("status"),"reason":row.get("reason")}).slice(0,8)}
    scene.set_process(false);scene.session.close();scene.queue_free();await process_frame
    display.queue_free();viewport.queue_free();await process_frame
    scene=null;viewport=null
    return report
func run()->void:
    root.unfocusable=true;root.size=Vector2i(1600,900)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--batch="):batch_path=arg.trim_prefix("--batch=")
    if batch_path.is_empty():printerr("Live spell batch requires --batch=<immutable request directory>");quit(1);return
    while true:
        var requests=DirAccess.open(batch_path)
        if requests!=null:
            var files=Array(requests.get_files());files.sort()
            var next:String=""
            for filename in files:
                if str(filename).ends_with(".json") and str(filename)>last_request_file:next=str(filename);break
            if next.is_empty():await process_frame;continue
            last_request_file=next
            var request:Variant=JSON.parse_string(FileAccess.get_file_as_string(batch_path.path_join(next)))
            if request is Dictionary and request.get("id","")!=last_id:
                if request.get("stop",false):quit(0);return
                last_id=request.id
                var result=await case_run(request)
                var pending:String=request.result+".pending"
                var file=FileAccess.open(pending,FileAccess.WRITE);file.store_string(JSON.stringify(result));file.close()
                var published=DirAccess.rename_absolute(pending,request.result)
                if published!=OK:printerr("Native safety result publication failed: ",error_string(published));quit(2);return
                var summary:Dictionary=result.duplicate(false);summary.erase("render_trace")
                print("LIVE_SPELL_SAFETY_CASE ",JSON.stringify(summary))
        await process_frame
