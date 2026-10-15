extends "res://tests/live_gallery_checks.gd"
# One ordinary Play, original Gallery sorcerer setup, real client-issued Amber
# actions. The launcher advances only Blue's legal turns through its own SDK.
const CASTER_NAME="Expedition sorcerer"
var spell_occurrences:Dictionary={}

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
    root.add_child(scene)
    check(scene.profiling_configured.ok and scene.session.transport.profiling_enabled(),"Transport profiling configured before live start")
    scene.camera.size=profile_view_size;scene.grid_visible=false
    evidence.profile_view_size=profile_view_size;evidence.window_size=[root.size.x,root.size.y]
    evidence.source="Unchanged Gallery sorcerer recipe; actual Play commands for Amber, independent nonrendering SDK Blue; original packets only."
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
    FileAccess.open(evidence.pipeline_trace,FileAccess.WRITE).store_string(JSON.stringify({"clock":"godot_monotonic_usec","dropped":pipeline_dropped,"records":pipeline_trace}))
    check(pipeline_dropped==0 and not pipeline_trace.is_empty(),"Live spell pipeline records were enabled and drained without loss")
    FileAccess.open(scene.game_config.test_result.get_base_dir().path_join("media-demand-trace.json"),FileAccess.WRITE).store_string(JSON.stringify(scene.media_demand_trace))
    evidence.full_profile=FrameProfile.save(scene.profile,root,"gallery-live-spells",true)
    _journal_spell_evidence()
    await finish()
