extends "res://tests/studio_replay_native_checks.gd"
## Admitted same-contract originals through the real Studio; capture revision
## remains independent of the current engine and rendered-output qualification.
const CaseLibrary=preload("res://studio/case_library.gd")
const Authoring=preload("res://presentation/authoring.gd")
const COHORT=["action.move/ordinary","spell.haste/lifecycle","spell.fire_bolt/hit","spell.fireball/area",
    "action.hide/lifecycle","action.attack/death","interaction.door/entry","spell.shield/reaction"]

func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(1600,900)
    report_path="res://.runtime/schema16-studio-replay.json"
    require_body_geometry="--require-body-geometry" in OS.get_cmdline_user_args()
    require_authored_action_bodies="--require-authored-action-bodies" in OS.get_cmdline_user_args()
    DirAccess.make_dir_recursive_absolute("res://.captures/studio/replay-comparison")
    var records:Array=CaseLibrary.read();var wanted:Array=COHORT.duplicate()
    var all_spells:bool="--all-spells" in OS.get_cmdline_user_args()
    var production_inventory:Array=[];var excluded:Array=[];var subset_requested:bool=false
    if all_spells:
        report_path="res://.runtime/schema16-all-spells-studio.json";wanted=[]
        var inventory:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(CaseLibrary.SERVER_IDS))
        for id in inventory.ids.spell:
            var visibility:String=str(inventory.ids.spell[id].get("visibility",""))
            if visibility in ["developer","internal"]:
                excluded.append({"id":id,"visibility":visibility,"disposition":"nonproduction_definition",
                    "reason":"Native descriptor visibility="+visibility+"; original captures remain unchanged and inspectable."})
            else:wanted.append(id+"/baseline")
        production_inventory=wanted.duplicate()
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--only-case="):
            wanted=Array(argument.trim_prefix("--only-case=").split(",",false));subset_requested=true
    var selected:Array=[];var case_results:Array=[]
    for id in wanted:
        var first_failure:int=failures.size()
        var matching:Array=records.filter(func(row):return row.id==id)
        check(matching.size()==1,"Exactly one original recording for "+id)
        if matching.size()!=1:
            case_results.append({"case":id,"passed":false,"stage":"selection","failures":failures.slice(first_failure)})
            continue
        check(matching[0].ready,id+": real recording ready: "+str(matching[0].get("reason","")))
        if matching[0].ready:selected.append(matching[0])
        else:case_results.append({"case":id,"passed":false,"stage":"recording_admission", "reason":matching[0].get("reason",""),"failures":failures.slice(first_failure)})
    if all_spells:
        evidence.append({"selection":"production_spell_baselines","production_inventory":production_inventory,"excluded":excluded,
            "requested_cases":wanted.duplicate(),"selected":selected.map(func(record):return record.id),"only_case_override":subset_requested,
            "scope":"The complete native production inventory and exclusions are separate from this invocation's actual requested/admitted subset. Only descriptor developer/internal visibility excludes an inventory baseline; no output or artwork approval is inferred."})
    if selected.is_empty():
        evidence.append({"case_results":case_results})
        FileAccess.open(report_path,FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence},"  "))
        print(JSON.stringify({"checks":checks,"failures":failures}));quit(1);return
    var all_failures:Array=failures.duplicate();failures=[]
    var studio=Studio.new();root.add_child(studio);studio.loop_enabled=false
    for record in selected:
        failures=[]
        var checks_before:int=checks;var started:int=Time.get_ticks_msec()
        var completed:bool=await replay_case(studio,record,all_spells)
        check(completed,record.id+": complete bounded case controls")
        var result:Dictionary={"case":record.id,"passed":failures.is_empty(),"stage":"native_replay",
            "checks":checks-checks_before,"failures":failures.duplicate(),"elapsed_ms":Time.get_ticks_msec()-started,
            "perspectives":record.perspectives.map(func(perspective):return perspective.id)}
        case_results.append(result);all_failures.append_array(failures)
        print("SCHEMA16_STUDIO_CASE ",JSON.stringify(result))
    failures=all_failures
    evidence.append({"case_results":case_results,"requested_cases":wanted,
        "scope":"Every requested case retains its actual admission/individual failures; later cases use ordinary Studio loading after a bounded case failure. Engine/script errors remain fatal runner diagnostics."})
    await finish(studio)

func replay_case(studio:Control,record:Dictionary,all_spells:bool)->bool:
    body_geometry_rows={}
    studio.loop_enabled=false
    var initial_perspective:Dictionary=record.perspectives[0]
    var directory:String=initial_perspective.journal
    if studio.active_directory!=directory:studio._load(directory)
    if not await settle(studio,0.0,directory):return false
    check(studio.replay_diagnostics().panes.size()==1,record.id+": one rendered faction")
    verify_prefix(studio,record.id+" initial")
    if not all_spells:
        var duration:float=studio.index.presentation_end_ms
        for fraction in [.55,.9,.15]:
            studio._seek(duration*fraction)
            if not await settle(studio,duration*fraction):return false
            verify_prefix(studio,record.id+" seek "+str(fraction))
            await save_capture(studio,record.id.replace("/","-")+"-"+str(int(fraction*100)))
        var perspectives_ready:bool=true
        for perspective in record.perspectives:
            if perspective.id==initial_perspective.id:continue
            studio.select_perspective(perspective.id)
            if not await settle(studio,-1.0,perspective.journal):
                perspectives_ready=false;break
            verify_prefix(studio,record.id+" independent "+str(perspective.id)+" journal")
        if not perspectives_ready:return false
        studio.select_perspective(initial_perspective.id)
        if not await settle(studio,-1.0,directory):return false
        verify_prefix(studio,record.id+" returned "+str(initial_perspective.id)+" journal")
    var behavior:String=str(record.id).get_slice("/",0)
    var recipe:Dictionary=Authoring.load_data("catalog/body_action_recipes.json",studio.index.cache).get(behavior,{})
    var source_uses:Array=[]
    for index in recipe.get("media",[]).size():
        var media:Dictionary=recipe.media[index]
        if str(media.get("source_id","")).is_empty():continue
        var use:Dictionary={"source_id":str(media.source_id),"attachment":str(media.get("poseSocket",media.get("attachment","ground"))),
            "assignment_source":Authoring.Catalog.source_pointer("catalog/body_action_recipes.json",behavior.replace("~","~0").replace("/","~1")+"/media/"+str(index),studio.index.cache)}
        # A registered two-half source keeps one occurrence for its first
        # rear/front alias. Require that exact selected authored assignment,
        # never another action using the same source and socket.
        if not source_uses.any(func(existing):return existing.source_id==use.source_id and existing.attachment==use.attachment):source_uses.append(use)
    var scenario:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(str(record.descriptor)))
    var item_effects:Array=scenario.get("required_item_effects",[])
    required_grant_sources=scenario.get("required_grant_sources",[])
    required_action_bodies=authored_action_bodies(studio.index,scenario,record.id) if require_authored_action_bodies else []
    await play_once(studio,record.id,source_uses,item_effects)
    if record.id=="action.class.cleric.preserve_life/recipients":
        var observed:Dictionary=evidence.back().get("observed_native",{})
        check(observed.values().filter(func(row):return row.evidence.get("outcome")=="cast").size()==1,"Preserve Life: one native source has a submitted draw witness")
        check(observed.values().filter(func(row):return row.evidence.get("outcome")=="heal").size()==2,"Preserve Life: both actual receiving results have submitted native draw witnesses")
    if record.id=="action.class.fighter.second_wind/healing":
        var observed:Dictionary=evidence.back().get("observed_native",{})
        var heals:Array=observed.values().filter(func(row):return row.clip=="fighter_second_wind_source_v190" and row.evidence.has("heal_occurrence"))
        check(heals.size()==1,"Second Wind: actual observed self-heal has one submitted native draw witness")
    check(studio.world.presentation_errors.is_empty(),record.id+": no native presentation error")
    if not failures.is_empty():return false
    if not all_spells:
        studio.loop_enabled=true;studio._play_study()
        if not await settle(studio):return false
        var wrapped:bool=false;var previous:float=studio.world.timeline.display_ms
        var expected_loop_ms:int=ceili(maxf(0.0,studio.loop_end-studio.loop_start)/studio.world.playback_speed)
        var deadline:int=Time.get_ticks_msec()+expected_loop_ms+30000
        evidence.append({"case":record.id,"kind":"functional_loop_budget","recorded_interval_ms":studio.loop_end-studio.loop_start,
            "playback_speed":studio.world.playback_speed,"expected_playback_ms":expected_loop_ms,"preparation_allowance_ms":30000})
        while not wrapped and Time.get_ticks_msec()<deadline:
            await process_frame
            var now:float=studio.world.timeline.display_ms
            check(now<=studio.loop_end+.001,record.id+": loop never passes Out")
            if now<previous-.1:wrapped=true;verify_prefix(studio,record.id+" automatic loop")
            previous=now
        check(wrapped,record.id+": automatically loops through its real prefix")
        if not studio.world.timeline.paused:studio._toggle_play()
        studio.loop_enabled=false
        await save_capture(studio,record.id.replace("/","-"))
    if studio.world.publication_failed or not studio.world.presentation_errors.is_empty():return false
    return true
