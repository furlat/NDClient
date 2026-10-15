extends "res://tests/live_gallery_checks.gd"
# One ordinary Play, original Gallery sorcerer setup, real client-issued Amber
# actions. The launcher advances only Blue's legal turns through its own SDK.
const CASTER_NAME="Expedition sorcerer"
var spell_occurrences:Dictionary={}

func _ui_click(point:Vector2)->void:
    var motion=InputEventMouseMotion.new()
    motion.position=point;motion.global_position=point
    scene.get_viewport().push_input(motion,true)
    var button=InputEventMouseButton.new()
    button.position=point;button.global_position=point
    button.button_index=MOUSE_BUTTON_LEFT;button.pressed=true
    scene.get_viewport().push_input(button,true)
    button=button.duplicate();button.pressed=false
    scene.get_viewport().push_input(button,true)

func _gesture_frame(record:Dictionary)->void:
    await RenderingServer.frame_post_draw
    collect_pipeline()
    if not scene.hover_preview.is_empty() and (record.hover_previews.is_empty() or not is_same(record.hover_previews.back().preview,scene.hover_preview)):
        record.hover_previews.append({"time_us":Time.get_ticks_usec(),"frame":Engine.get_process_frames(),"hover_position":scene.hover_hit.get("position"),"preview":scene.hover_preview})
    if not scene.profile.frames.is_empty():
        var frame:Dictionary=scene.profile.frames[posmod(scene.profile.cursor-1,scene.profile.frames.size())]
        record.gesture_frames.append({"frame":frame.frame,"time_us":Time.get_ticks_usec(),"frame_ms":frame.frame_ms,"cpu_ms":frame.cpu_ms.duplicate(),"phase":phase_value(),"pointer":[scene.get_viewport().get_mouse_position().x,scene.get_viewport().get_mouse_position().y],"hover_position":scene.hover_hit.get("position"),"hover_request":scene.hover_request})

func _issue_input(selected:Dictionary,record:Dictionary)->void:
    if not scene.game_config.get("live_fireball_ui",false) or selected.is_empty() or selected.action.behavior_id!="spell.fireball":
        await super._issue_input(selected,record)
        return
    record.input="native_family_target"
    record.gesture_frames=[];record.ui_markers=[];record.hover_previews=[]
    record.sequence_before_selection=scene.timeline.sequence
    if not await until(func():return not scene.hud.bar_pending(),"Native action bar settled before Fireball family click"):return
    var family:Button
    for page in range(12):
        for button in scene.hud.action_buttons:
            if button.get_meta("family",{}).get("rows",[]).any(func(row):return row.behavior_id=="spell.fireball"):
                family=button;break
        if family!=null:break
        var next_page:Button
        for button in scene.hud.bar.find_children("*","Button",true,false):
            if button.text=="›" and button.tooltip_text.begins_with("Spells page "):next_page=button;break
        if next_page==null:break
        record.ui_markers.append({"kind":"spell_page_click","time_us":Time.get_ticks_usec(),"frame":Engine.get_process_frames()})
        _ui_click(next_page.get_global_rect().get_center())
        await _gesture_frame(record)
        if not await until(func():return not scene.hud.bar_pending(),"Native spell page publishes"):return
    check(family!=null and not family.disabled,"Current native action bar offers Fireball family")
    if family==null:return
    record.ui_markers.append({"kind":"family_click","time_us":Time.get_ticks_usec(),"frame":Engine.get_process_frames()})
    _ui_click(family.get_global_rect().get_center())
    await _gesture_frame(record)
    if scene.hud.popup.visible:
        record.input="native_family_level_target"
        var level:Button
        for button in scene.hud.popup_rows:
            var row:Dictionary=button.get_meta("native_row",{})
            if row.get("discovery_index")==selected.action.discovery_index:level=button;break
        check(level!=null and not level.disabled,"Actual level popup offers requested native Fireball row")
        if level==null:return
        record.ui_markers.append({"kind":"level_click","time_us":Time.get_ticks_usec(),"frame":Engine.get_process_frames()})
        _ui_click(level.get_global_rect().get_center())
    if not await until(func():return scene.action_request<0 and not scene.selection_preview.is_empty(),"Actual selected Fireball prefix preview arrives"):return
    # The native bar may choose the available restricted-budget representative
    # of the same level/variant verb. Record that real row, never override it.
    var actual:Dictionary=scene.selected_action
    var matches:bool=actual.get("behavior_id")=="spell.fireball" and actual.get("cast_at_level")==selected.action.get("cast_at_level") and actual.get("variant_facets",[])==selected.action.get("variant_facets",[])
    check(matches,"Native GUI selects actual Fireball at requested level/variant")
    record.selected_native_row={"discovery_index":actual.get("discovery_index"),"cast_at_level":actual.get("cast_at_level"),"restricted_action_budget":actual.get("restricted_action_budget")}
    if not matches:return
    selected.action=actual
    var target:Array=Choices.binding_position(scene.available_actions,selected.target)
    var sweep:Array=[]
    for offset in [[-1,0],[0,-1],[1,0],[0,1],[0,0]]:
        var cell:Array=[target[0]+offset[0],target[1]+offset[1]]
        if Choices.action_options(scene.available_actions,selected.action).any(func(option):return Choices.binding_position(scene.available_actions,option)==cell):
            var point=grid_screen(cell)
            if root.get_visible_rect().has_point(point) and not scene.hud.pointer_over_controls(point) and scene.Interaction.same_position(scene.pick_cell(point).get("position"),cell):sweep.append(cell)
    check(sweep.size()>1,"Fireball sweep uses multiple actually offered and pickable neighboring cells")
    record.sweep_cells=sweep.duplicate(true)
    var sweep_start=Time.get_ticks_usec()
    var previous=-1
    while healthy() and Time.get_ticks_usec()-sweep_start<1000000 and not sweep.is_empty():
        var slot:int=int((Time.get_ticks_usec()-sweep_start)/100000)%sweep.size()
        if slot!=previous:
            var motion=InputEventMouseMotion.new()
            motion.position=grid_screen(sweep[slot]);motion.global_position=motion.position
            scene.get_viewport().push_input(motion,true);previous=slot
            record.ui_markers.append({"kind":"aim","position":sweep[slot],"time_us":Time.get_ticks_usec(),"frame":Engine.get_process_frames()})
        await _gesture_frame(record)
    record.ui_markers.append({"kind":"target_click","position":target,"time_us":Time.get_ticks_usec(),"frame":Engine.get_process_frames()})
    click_grid(target)
    # Ordinary position spells auto-confirm after the real target preview reply.
    # Return to the normal frame observer before that reply; do not consume cast
    # frames waiting for a Confirm button which this native flow never requires.
    var spec:Variant=selected.action.get("position_selection")
    var explicit:bool=selected.action.target_type=="multi_entity" or (spec!=null and spec.kind in ["path","entity_destination"])
    record.confirmation="explicit" if explicit else "native_target_auto_confirm"
    if explicit:
        if not await until(func():return scene.action_request<0 and scene.selection_preview.get("can_confirm",false) and not scene.hud.confirm_button.disabled,"Actual target preview enables native Confirm"):return
        record.ui_markers.append({"kind":"confirm_click","time_us":Time.get_ticks_usec(),"frame":Engine.get_process_frames()})
        _ui_click(scene.hud.confirm_button.get_global_rect().get_center())

func _selected_step(step:Dictionary)->Dictionary:
    var offered:Array=rows().filter(func(row):return row.behavior_id==step.behavior and (not step.has("display_name") or row.display_name==step.display_name))
    offered.sort_custom(func(a,b):
        var aa:int=0 if a.get("cast_at_level")==null else a.cast_at_level
        var bb:int=0 if b.get("cast_at_level")==null else b.cast_at_level
        return aa<bb if aa!=bb else a.discovery_index<b.discovery_index)
    for action in offered:
        var targets:Array=Choices.action_options(scene.available_actions,action)
        if step.has("position"):
            targets=targets.filter(func(target):return Choices.binding_position(scene.available_actions,target)==step.position)
        if step.has("subject_name"):
            targets=targets.filter(func(target):
                var subject:Variant=Choices.binding_subject(scene.available_actions,target)
                return subject!=null and subject.get("name")==step.subject_name)
        if step.get("offered_opponent",false):
            targets=targets.filter(func(target):
                var subject:Variant=Choices.binding_subject(scene.available_actions,target)
                if subject==null or subject.uuid in scene.timeline.state.audience.controlled:return false
                var actor:Dictionary=scene.timeline.state.actors.get(subject.uuid,{})
                return actor.is_empty() or (actor.get("present",false) and actor.get("normal_hp",0)>0))
            # Prefer a disclosed destructible object for the repeated cantrip,
            # using the server's offered eligibility, never an invented target.
            targets.sort_custom(func(a,b):
                var left:Variant=Choices.binding_subject(scene.available_actions,a)
                var right:Variant=Choices.binding_subject(scene.available_actions,b)
                return int(scene.timeline.state.actors.has(left.uuid))<int(scene.timeline.state.actors.has(right.uuid)))
        if not targets.is_empty():
            return {"action":action,"target":targets[0],"recipient_uuid":_subject_uuid(scene.available_actions,targets[0])}
    return {}

func _request_blue(step:Dictionary,ordinal:int)->bool:
    var temporary:String=scene.game_config.blue_request+".pending"
    var file=FileAccess.open(temporary,FileAccess.WRITE)
    file.store_string(JSON.stringify({"id":ordinal,"step":step}));file.close()
    check(DirAccess.rename_absolute(temporary,scene.game_config.blue_request)==OK,"Publish original Blue action request")
    # End the real Amber turn; Blue's SDK executes the requested arcanist action
    # on its next legal turn and otherwise only ends its own turns.
    for turn in 3:
        var completed:bool=await issue({})
        if not command_trace.is_empty():
            command_trace.back().requested_blue_action=step.duplicate(true)
            command_trace.back().profile_role="opponent_spell_and_reaction"
        if not completed:return false
        if FileAccess.file_exists(scene.game_config.blue_result):
            var result:Variant=JSON.parse_string(FileAccess.get_file_as_string(scene.game_config.blue_result))
            if result is Dictionary and result.get("id")==ordinal:
                check(result.receipt.kind=="committed","Original Blue spell is an actual committed command")
                evidence.blue_request={"request":step,"result":result}
                return true
    check(false,"Blue reaches its requested legal action within three initiative cycles")
    return false

func _journal_spell_evidence()->void:
    var counts:Dictionary={}
    var shield:Array=[]
    for name in DirAccess.get_files_at(scene.game_config.journal):
        if not name.ends_with(".json"):continue
        var packet:Variant=JSON.parse_string(FileAccess.get_file_as_string(scene.game_config.journal.path_join(name)))
        if not packet is Dictionary:continue
        for lineage in packet.get("lineages",[]):
            for node in lineage.events:
                var fact:Variant=node.get("fact")
                if fact==null or node.canceled:continue
                if fact.kind=="spell":
                    var behavior:String=fact.get("behavior_id","")
                    counts[behavior]=counts.get(behavior,0)+1
                if fact.kind=="condition" and fact.condition.get("behavior_id")=="condition.spell.shield" and fact.target_entity_uuid==leader:
                    shield.append({"event_uuid":node.uuid,"event_type":fact.event_type,"sequence":packet.cursor.sequence})
    evidence.actual_spell_facts=counts;evidence.actual_shield_facts=shield
    for behavior in ["ray_of_frost","scorching_ray","acid_splash","fireball","magic_missile","chill_touch","fire_bolt"]:
        check(counts.get("spell."+behavior,0)>0,"Original journal contains actual "+behavior+" facts")
    for event_type in ["condition_application","condition_removal"]:
        check(shield.any(func(row):return row.event_type==event_type),"Actual sorcerer Shield "+event_type)
    check(spell_occurrences.get("spell.fire_bolt",0)==2,"Two client-issued Fire Bolt casts provide first/repeated source profiles")

func _run()->void:
    # This is the actual client window, not an invisible Studio renderer. It is
    # unfocusable to leave the user's existing preview/input untouched.
    root.unfocusable=true;root.size=Vector2i(1600,960)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
    profile_view_size=12.0
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--profile-view-size="):profile_view_size=argument.trim_prefix("--profile-view-size=").to_float()
    scene=CapturingPlayer.new();scene.choices_observed=capture_choices;scene.profile.recording=true;scene.capture_media_demand=true
    if "--live-fireball-ui" in OS.get_cmdline_user_args():
        # A native Window polls the physical desktop pointer even for pushed
        # mouse events. The displayed full-size viewport owns this live GUI's
        # local pointer and forwards no input to the user's other window.
        var viewport=SubViewport.new()
        viewport.size=Vector2i(1600,960)
        viewport.own_world_3d=true
        viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
        root.add_child(viewport)
        var display=TextureRect.new()
        display.size=Vector2(1600,960)
        display.texture=viewport.get_texture()
        display.mouse_filter=Control.MOUSE_FILTER_IGNORE
        root.add_child(display)
        viewport.add_child(scene)
        viewport.notify_mouse_entered()
        evidence.render_host="1600x960 native SubViewport, own World3D, one root display blit; user preview remains open/shared GPU"
    else:root.add_child(scene)
    check(scene.profiling_configured.ok and scene.session.transport.profiling_enabled(),"Transport profiling configured before live start")
    scene.camera.size=profile_view_size;scene.grid_visible=false
    evidence.profile_view_size=profile_view_size;evidence.window_size=[root.size.x,root.size.y]
    evidence.source="Unchanged interactive Gallery sorcerer with ordinary AI; actual Fireball native family/level/ground/Confirm events and original live packets." if scene.game_config.get("live_fireball_ui",false) else "Unchanged Gallery sorcerer recipe; actual Play commands for Amber, independent nonrendering SDK Blue; original packets only."
    if not await until(ready,"Sorcerer actual initial choices",120000):await finish();return
    evidence.ready_frame=Engine.get_process_frames();evidence.ready_elapsed_ms=Time.get_ticks_msec()-started
    for id in scene.timeline.state.audience.controlled:
        if scene.timeline.state.actors[id].name==CASTER_NAME:leader=id
    check(not leader.is_empty(),"Original premade sorcerer is controlled by Play")
    var steps:Array=scene.game_config.get("profile_steps",[])
    check(not steps.is_empty(),"Launcher provided the original Gallery requests")
    for ordinal in steps.size():
        stage=ordinal
        if not await until(ready,"Next actual sorcerer command",120000):break
        var step:Dictionary=steps[ordinal]
        if step.actor_name!=CASTER_NAME:
            if not await _request_blue(step,ordinal):break
            continue
        var selected:Dictionary={} if step.behavior=="end_turn" else _selected_step(step)
        if step.behavior!="end_turn" and selected.is_empty():
            evidence.unavailable_request=step
            check(false,"Current actual choices offer requested action/recipient: "+JSON.stringify(step));break
        var position:Array=scene.timeline.state.actors[leader].last_visual_position
        scene.camera_focus=Vector3(position[0],0,position[1]);scene.camera.size=profile_view_size;scene.position_camera()
        var success:bool=await issue(selected)
        if not command_trace.is_empty():
            command_trace.back().request=step.duplicate(true)
            if step.behavior.begins_with("spell."):
                spell_occurrences[step.behavior]=spell_occurrences.get(step.behavior,0)+1
                command_trace.back().spell_occurrence=spell_occurrences[step.behavior]
                command_trace.back().recipient_uuid=selected.get("recipient_uuid","")
        if not success:break
    check(stage==steps.size()-1 and failures.is_empty(),"All original Gallery actions and repeated cantrips completed through Play")
    check(ready() and not scene.timeline.busy() and scene.timeline.state==scene.session.journal.state,"Live spell profile ends at a drained canonical boundary")
    scene.profile.label="spell_profile_idle_settle"
    for frame in 30:await scene.presentation_updated
    scene.profile.label="spell_profile_idle_same_view"
    var deadline=Time.get_ticks_msec()+3000
    while Time.get_ticks_msec()<deadline:await scene.presentation_updated
    scene.set_process(false);scene.session.close();collect_pipeline(true)
    evidence.live_commands=command_trace.size();evidence.spell_commands=spell_occurrences
    evidence.disclosed_tiles=scene.timeline.state.tiles.size();evidence.disclosed_objects=scene.timeline.state.objects.size()
    evidence.command_trace=scene.game_config.test_result.get_base_dir().path_join("live-command-trace.json")
    evidence.pipeline_trace=scene.game_config.test_result.get_base_dir().path_join("client-pipeline-trace.json")
    FileAccess.open(evidence.command_trace,FileAccess.WRITE).store_string(JSON.stringify(command_trace))
    if scene.game_config.get("live_fireball_ui",false):
        for command in command_trace:
            if command.behavior!="spell.fireball":continue
            var captured={"sequence_before":command.get("sequence_before_selection"),"request":command.get("request",{}),"previews":command.get("hover_previews",[])}
            FileAccess.open(scene.game_config.test_result.get_base_dir().path_join("fireball-hover-%d.json"%command.number),FileAccess.WRITE).store_string(JSON.stringify(captured))
    FileAccess.open(evidence.pipeline_trace,FileAccess.WRITE).store_string(JSON.stringify({"clock":"godot_monotonic_usec","dropped":pipeline_dropped,"records":pipeline_trace}))
    check(pipeline_dropped==0 and not pipeline_trace.is_empty(),"Live spell pipeline records were enabled and drained without loss")
    FileAccess.open(scene.game_config.test_result.get_base_dir().path_join("media-demand-trace.json"),FileAccess.WRITE).store_string(JSON.stringify(scene.media_demand_trace))
    FileAccess.open(scene.game_config.test_result.get_base_dir().path_join("media-gate-trace.json"),FileAccess.WRITE).store_string(JSON.stringify(scene.media_gate_trace))
    evidence.full_profile=FrameProfile.save(scene.profile,root,"gallery-live-spells",true)
    if scene.game_config.get("live_fireball_ui",false):
        check(spell_occurrences.get("spell.fireball",0)==2,"Both original Fireball requests complete through native GUI")
    else:_journal_spell_evidence()
    await finish()
